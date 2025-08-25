import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../auth_manager.dart';
import '../services/analyzer_api_client.dart';

class CamerasScreen extends StatefulWidget {
  final AuthManager authManager;

  const CamerasScreen({super.key, required this.authManager});

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  List<Map<String, dynamic>> _cameras = [];
  bool _isLoading = true;
  bool _isShowingErrorDialog = false;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final response = await AnalyzerApiClient.getCameras();

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final List<Map<String, dynamic>> allCameras = response.data!;
        final filteredCameras = _filterCameras(allCameras);

        if (mounted) {
          setState(() {
            _cameras = filteredCameras;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showGlobalError(response.error ?? 'Error al cargar las cámaras');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showGlobalError(
          'Error de conexión. Verifique su conexión a internet.',
        );
      }
    }
  }

  List<Map<String, dynamic>> _filterCameras(
    List<Map<String, dynamic>> cameras,
  ) {
    return cameras.where((camera) {
      final cameraTeam = camera['liable'] as String?;
      final status = camera['status'] as String?;
      final userTeam = widget.authManager.teamName;

      final teamMatch = cameraTeam != null && 
                        userTeam != null &&
                        cameraTeam.toUpperCase() == userTeam.toUpperCase();
      final statusMatch = status != null && status.toLowerCase() == 'offline';
      
      return teamMatch && statusMatch;
    }).toList();
  }

  Color _getCameraTypeColor(String type) {
    switch (type) {
      case 'Fixed':
        return Colors.blue.shade600;
      case 'Dome':
        return Colors.green.shade600;
      case 'LPR':
        return Colors.purple.shade600;
      case 'Button':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _translateCameraType(String type) {
    switch (type) {
      case 'Fixed':
        return 'Fija';
      case 'Dome':
        return 'Domo';
      case 'LPR':
        return 'LPR';
      case 'Button':
        return 'Botón';
      default:
        return type;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green.shade600;
      case 'warning':
        return Colors.yellow.shade600;
      case 'offline':
        return Colors.red.shade600;
      case 'maintenance':
        return Colors.orange.shade600;
      case 'removed':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return 'En Línea';
      case 'warning':
        return 'Advertencia';
      case 'offline':
        return 'Fuera de Línea';
      case 'maintenance':
        return 'Mantenimiento';
      case 'removed':
        return 'Retirada';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'online':
      case 'En Línea':
        return LucideIcons.wifi;
      case 'warning':
      case 'Advertencia':
        return LucideIcons.alertTriangle;
      case 'offline':
      case 'Fuera de Línea':
        return LucideIcons.wifiOff;
      case 'maintenance':
      case 'Mantenimiento':
        return LucideIcons.wrench;
      case 'removed':
      case 'Retirada':
        return LucideIcons.trash2;
      default:
        return LucideIcons.info;
    }
  }

  void _showGlobalError(String message) {
    if (_isShowingErrorDialog) return;

    _isShowingErrorDialog = true;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                LucideIcons.alertCircle,
                color: Colors.red.shade400,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text('Error de conexión'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                _isShowingErrorDialog = false;
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                _isShowingErrorDialog = false;
                Navigator.of(context).pop();
                _loadCameras();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        );
      },
    ).then((_) {
      _isShowingErrorDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    if (_cameras.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.video, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay cámaras fuera de línea para tu equipo',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: _cameras.length,
        itemBuilder: (context, index) {
          final camera = _cameras[index];
          return GestureDetector(
            onTap: () => _showCameraDetail(context, camera),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.video,
                          size: 32,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                camera['name'] as String,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                camera['ip'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getCameraTypeColor(
                              camera['type'] as String,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _translateCameraType(camera['type'] as String),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(camera['status'] as String),
                          size: 20,
                          color: _getStatusColor(camera['status'] as String),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _translateStatus(camera['status'] as String),
                          style: TextStyle(
                            fontSize: 14,
                            color: _getStatusColor(camera['status'] as String),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          LucideIcons.info,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCameraDetail(BuildContext context, Map<String, dynamic> camera) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 32,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.orange.shade50.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        camera['name'] as String,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade50, Colors.grey.shade100],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.grey),
                        iconSize: 20,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('IP', camera['ip'] as String),
                _buildInfoRow(
                  'Tipo',
                  _translateCameraType(camera['type'] as String),
                ),
                _buildInfoRow(
                  'Estado',
                  _translateStatus(camera['status'] as String),
                ),
                _buildInfoRow(
                  'Dirección',
                  camera['direction'] as String? ?? 'No especificada',
                ),
                _buildInfoRow(
                  'Zona',
                  camera['zone'] as String? ?? 'No especificada',
                ),
                _buildInfoRow(
                  'Responsable',
                  camera['liable'] as String? ?? 'No asignado',
                ),
                const SizedBox(height: 16),
                if (camera['latitude'] != null && camera['longitude'] != null)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(
                                camera['latitude'] as double,
                                camera['longitude'] as double,
                              ),
                              initialZoom: 16.0,
                              maxZoom: 18.0,
                              minZoom: 5.0,
                              interactionOptions: const InteractionOptions(
                                flags:
                                    InteractiveFlag.all &
                                    ~InteractiveFlag.rotate,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                                userAgentPackageName:
                                    'com.example.techhub_mobile',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      camera['latitude'] as double,
                                      camera['longitude'] as double,
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${camera['latitude']}, ${camera['longitude']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (camera['latitude'] != null && camera['longitude'] != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap:
                            () => _copyLocation(
                              context,
                              camera['latitude'] as double,
                              camera['longitude'] as double,
                            ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.orange.shade400,
                                Colors.orange.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Copiar ubicación',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    IconData icon;
    Color iconColor;

    switch (label.toLowerCase()) {
      case 'ip':
        icon = Icons.router;
        iconColor = Colors.grey;
        break;
      case 'tipo':
        icon = Icons.videocam;
        iconColor = Colors.grey;
        break;
      case 'estado':
        icon = _getStatusIcon(value);
        iconColor = _getStatusColor(value);
        break;
      case 'dirección':
        icon = Icons.signpost;
        iconColor = Colors.grey;
        break;
      case 'zona':
        icon = Icons.location_on;
        iconColor = Colors.grey;
        break;
      case 'responsable':
        icon = Icons.person;
        iconColor = Colors.grey;
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                '$label:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
              maxLines: label == 'Descripción' ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyLocation(
    BuildContext dialogContext,
    double latitude,
    double longitude,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(dialogContext);
    await Clipboard.setData(ClipboardData(text: '$latitude,$longitude'));
    if (!mounted) return;

    navigator.pop();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Ubicación copiada al portapapeles'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
