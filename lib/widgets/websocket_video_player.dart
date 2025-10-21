import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../auth_manager.dart';
import '../services/analyzer_api_client.dart';

class WebSocketVideoPlayer extends StatefulWidget {
  final Map<String, dynamic> camera;
  final AuthManager authManager;
  final double width;
  final double height;

  const WebSocketVideoPlayer({
    super.key,
    required this.camera,
    required this.authManager,
    this.width = 300,
    this.height = 200,
  });

  @override
  State<WebSocketVideoPlayer> createState() => _WebSocketVideoPlayerState();
}

class _WebSocketVideoPlayerState extends State<WebSocketVideoPlayer> {
  WebSocket? _socket;
  StreamSubscription? _sub;
  Timer? _hb;
  Timer? _timeout;
  bool _isDisposing = false;

  Uint8List? _frame;
  bool _connecting = false;
  bool _streaming = false;
  bool _error = false;
  String _errorMsg = '';

  // Buffer simple para intentar recomponer JPEG fragmentado cuando falle la validación directa
  final List<int> _buf = <int>[];
  static const int _bufMax = 8 * 1024 * 1024; // 8 MB

  @override
  void initState() {
    super.initState();
    // Autoiniciar conexión al abrir el popup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cameraId =
          widget.camera['_id']?.toString() ?? widget.camera['id']?.toString();
      if (cameraId != null) {
        _startThenConnect(cameraId);
      } else {
        if (!mounted) return;
        setState(() {
          _error = true;
          _errorMsg = 'ID de cámara no encontrado';
          _connecting = false;
        });
      }
    });
  }

  // Eliminado botón de inicio: conexión automática en initState

  Future<void> _startThenConnect(String cameraId) async {
    setState(() {
      _connecting = true;
      _error = false;
      _errorMsg = '';
      _frame = null;
    });
    try {
      final startRes = await AnalyzerApiClient.startStream(
        username: widget.authManager.userName!,
        password: widget.authManager.password!,
        cameraId: cameraId,
      );
      if (!startRes.isSuccess) {
        throw Exception(startRes.message ?? 'No se pudo iniciar el stream');
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || _isDisposing) return;
      await _connect(cameraId);
    } catch (e) {
      if (!mounted || _isDisposing) return;
      setState(() {
        _error = true;
        _errorMsg = e.toString();
        _connecting = false;
        _streaming = false;
      });
    }
  }

  Future<void> _connect(String cameraId) async {
    try {
      final url = AnalyzerApiClient.getWebSocketUrl(cameraId);
      _socket = await WebSocket.connect(url);

      _sub = _socket!.listen(
        (data) async {
          if (!mounted || _isDisposing) return;
          try {
            Uint8List? bytes;
            if (data is List<int>) {
              bytes = Uint8List.fromList(data);
            } else if (data is String) {
              // Puede ser base64 o JSON con campo data
              bytes = _decodeTextPayload(data);
            }
            if (bytes == null) return;

            // Con servidor MJPEG, acumulamos y extraemos frames JPEG por SOI/EOI
            _buf.addAll(bytes);
            if (_buf.length > _bufMax) _buf.clear();

            final merged = _extractJpeg(_buf);
            if (merged != null) {
              _emit(merged);
              _buf.clear();
            }
            if (mounted && !_isDisposing) setState(() {});
          } catch (_) {
            // ignorar chunk inválido
          }
        },
        onDone: () {
          if (!mounted || _isDisposing) return;
          setState(() {
            _streaming = false;
            _connecting = false;
          });
        },
        onError: (e) {
          if (!mounted || _isDisposing) return;
          setState(() {
            _error = true;
            _errorMsg = 'WS error: $e';
            _streaming = false;
            _connecting = false;
          });
        },
        cancelOnError: true,
      );

      _startHeartbeat();
      _timeout = Timer(const Duration(seconds: 15), () {
        if (!mounted || _isDisposing) return;
        if (_connecting && !_streaming) {
          setState(() {
            _error = true;
            _errorMsg = 'Timeout de conexión';
            _connecting = false;
          });
        }
      });
    } catch (e) {
      if (!mounted || _isDisposing) return;
      setState(() {
        _error = true;
        _errorMsg = 'No se pudo conectar: $e';
        _connecting = false;
        _streaming = false;
      });
    }
  }

  Uint8List? _decodeTextPayload(String data) {
    try {
      // JSON con { type: 'frame', data: '<base64>' }
      final obj = json.decode(data);
      if (obj is Map && obj['data'] is String) {
        return Uint8List.fromList(base64.decode(obj['data'] as String));
      }
    } catch (_) {
      // no JSON
    }
    try {
      return Uint8List.fromList(base64.decode(data));
    } catch (_) {
      return null;
    }
  }

  // Eliminado fallback de transcodificación; no es necesario con MJPEG

  Uint8List? _extractJpeg(List<int> data) {
    // Buscar SOI y EOI básicos
    int soi = -1;
    for (int i = 0; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == 0xD8) {
        soi = i;
        break;
      }
    }
    if (soi == -1) return null;
    int eoi = -1;
    for (int i = soi + 2; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == 0xD9) {
        eoi = i + 2;
        break;
      }
    }
    if (eoi == -1) return null;
    return Uint8List.fromList(data.sublist(soi, eoi));
  }

  void _emit(Uint8List bytes) {
    if (!mounted || _isDisposing) return;
    setState(() {
      _frame = bytes;
      if (!_streaming) {
        _streaming = true;
        _connecting = false;
      }
    });
  }

  void _startHeartbeat() {
    _hb?.cancel();
    _hb = Timer.periodic(const Duration(seconds: 30), (t) {
      if (_isDisposing) {
        t.cancel();
        return;
      }
      if (_socket?.readyState == WebSocket.open) {
        try {
          _socket?.add('ping');
        } catch (_) {
          t.cancel();
        }
      } else {
        t.cancel();
      }
    });
  }

  // métricas eliminadas

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final navigator = Navigator.of(context);
          await _cleanupConnection();
          if (navigator.mounted) navigator.pop(result);
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(LucideIcons.video, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.camera['name']?.toString() ?? 'Cámara',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await _cleanupConnection();
                      if (navigator.mounted) navigator.pop();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Container(
              width: widget.width,
              height: widget.height,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _connecting
                          ? Colors.orange
                          : _streaming
                          ? Colors.green
                          : _error
                          ? Colors.red
                          : Colors.grey,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildSurface(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSurface() {
    if (_error) {
      return Center(
        child: Text(
          _errorMsg.isEmpty ? 'Error de transmisión' : _errorMsg,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (_connecting) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_streaming && _frame != null) {
      return Image.memory(
        _frame!,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        fit: BoxFit.cover,
      );
    }
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }

  @override
  void dispose() {
    _isDisposing = true;
    try {
      _timeout?.cancel();
    } catch (_) {}
    try {
      _hb?.cancel();
    } catch (_) {}
    try {
      _sub?.pause();
    } catch (_) {}
    try {
      _socket?.close(WebSocketStatus.normalClosure, 'closing');
    } catch (_) {}
    try {
      _sub?.cancel();
    } catch (_) {}
    _socket = null;
    _sub = null;
    super.dispose();
  }

  Future<void> _cleanupConnection() async {
    _isDisposing = true;
    try {
      _timeout?.cancel();
    } catch (_) {}
    try {
      _hb?.cancel();
    } catch (_) {}
    try {
      _sub?.pause();
    } catch (_) {}
    try {
      await _socket?.close(WebSocketStatus.normalClosure, 'closing');
    } catch (_) {}
    try {
      await _sub?.cancel();
    } catch (_) {}
    _socket = null;
    _sub = null;
  }
}
