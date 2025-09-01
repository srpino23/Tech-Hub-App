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

      final teamMatch =
          cameraTeam != null &&
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
        final isWideScreen = MediaQuery.of(context).size.width > 600;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          insetPadding: EdgeInsets.all(isWideScreen ? 32 : 16),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth:
                  isWideScreen ? 800 : MediaQuery.of(context).size.width - 32,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.orange.shade50.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header mejorado
                _buildDialogHeader(context, camera, isWideScreen),

                // Contenido con mejor organización
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isWideScreen ? 32 : 20,
                      0,
                      isWideScreen ? 32 : 20,
                      isWideScreen ? 32 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Espaciado desde el header
                        const SizedBox(height: 24),

                        // Sección de información básica
                        _buildInfoSection(
                          'Información General',
                          LucideIcons.info,
                          Colors.blue,
                          [
                            _buildDetailRow(
                              'Estado',
                              _translateStatus(camera['status'] as String),
                              _getStatusIcon(camera['status'] as String),
                              _getStatusColor(camera['status'] as String),
                            ),
                            _buildDetailRow(
                              'Tipo',
                              _translateCameraType(camera['type'] as String),
                              LucideIcons.video,
                              Colors.grey.shade600,
                            ),
                            _buildDetailRow(
                              'IP',
                              camera['ip'] as String,
                              LucideIcons.globe,
                              Colors.grey.shade600,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Sección de ubicación
                        _buildInfoSection(
                          'Ubicación y Responsabilidad',
                          LucideIcons.mapPin,
                          Colors.purple,
                          [
                            _buildDetailRow(
                              'Dirección',
                              camera['direction'] as String? ??
                                  'No especificada',
                              LucideIcons.mapPin,
                              Colors.purple.shade600,
                            ),
                            _buildDetailRow(
                              'Zona',
                              camera['zone'] as String? ?? 'No especificada',
                              LucideIcons.map,
                              Colors.purple.shade600,
                            ),
                            _buildDetailRow(
                              'Responsable',
                              camera['liable'] as String? ?? 'No asignado',
                              LucideIcons.user,
                              Colors.purple.shade600,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Sección de mapa (si tiene coordenadas)
                        if (camera['latitude'] != null &&
                            camera['longitude'] != null)
                          _buildLocationSection(camera, isWideScreen),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // New helper methods for improved dialog

  Widget _buildDialogHeader(
    BuildContext context,
    Map<String, dynamic> camera,
    bool isWideScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isWideScreen ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.video,
              color: Colors.white,
              size: isWideScreen ? 28 : 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalles de la Cámara',
                  style: TextStyle(
                    fontSize: isWideScreen ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  camera['name'] as String,
                  style: TextStyle(
                    fontSize: isWideScreen ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
              iconSize: isWideScreen ? 24 : 20,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.1),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(Map<String, dynamic> camera, bool isWideScreen) {
    return _buildInfoSection(
      'Mapa de Ubicación',
      LucideIcons.map,
      Colors.green,
      [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildMapSection(camera),
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection(Map<String, dynamic> camera) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.example.techhub_mobile',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            camera['latitude'] as double,
                            camera['longitude'] as double,
                          ),
                          width: 50,
                          height: 50,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.video,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${camera['latitude']}, ${camera['longitude']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap:
                              () => _copyLocationFromMap(
                                context,
                                camera['latitude'] as double,
                                camera['longitude'] as double,
                              ),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade600,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              LucideIcons.copy,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyLocationFromMap(
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: '$latitude,$longitude'));
    if (!mounted) return;

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
