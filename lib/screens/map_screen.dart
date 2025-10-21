import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../auth_manager.dart';
import '../services/analyzer_api_client.dart';
import '../services/techhub_api_client.dart';
import '../widgets/websocket_video_player.dart';
import 'camera_crud_popup.dart';

class MapScreen extends StatefulWidget {
  final AuthManager authManager;

  const MapScreen({super.key, required this.authManager});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  // Data
  List<Map<String, dynamic>> _cameras = [];
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _zoneBoundaries;

  // Loading states
  bool _isLoadingCameras = true;
  bool _isLoadingBoundaries = true;
  bool _isLoadingUsers = true;

  // Control states
  bool _showUsers = true;
  bool _showCameras = true;
  bool _showAllCameras = false;
  bool _showGraphics = false;
  bool _showSearch = false;

  // Search states
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Auto refresh
  Timer? _refreshTimer;
  bool _autoRefreshEnabled = true;
  static const Duration _refreshInterval = Duration(
    minutes: 2,
  ); // Actualizar cada 2 minutos

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadZoneBoundaries(), _loadCameras(), _loadUsers()]);
  }

  void _startAutoRefresh() {
    if (!_autoRefreshEnabled) return;

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      if (mounted && _autoRefreshEnabled) {
        _refreshData();
      } else {
        timer.cancel();
      }
    });
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefreshEnabled = !_autoRefreshEnabled;
    });

    if (_autoRefreshEnabled) {
      _startAutoRefresh();
    } else {
      _stopAutoRefresh();
    }
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshData() async {
    // Solo refrescar cámaras y usuarios, no los límites de zona ya que no cambian
    await Future.wait([_loadCameras(), _loadUsers()]);
  }

  Future<void> _loadZoneBoundaries() async {
    try {
      final String geoJsonString = await rootBundle.loadString(
        'lib/assets/geojson/tres_de_febrero_limits.geojson',
      );
      final Map<String, dynamic> geoJson = json.decode(geoJsonString);

      if (mounted) {
        setState(() {
          _zoneBoundaries = geoJson;
          _isLoadingBoundaries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBoundaries = false;
        });
      }
    }
  }

  Future<void> _loadCameras() async {
    try {
      final response = await AnalyzerApiClient.getCameras(
        username: widget.authManager.userName!,
        password: widget.authManager.password!,
      );

      if (mounted) {
        if (response.isSuccess && response.data != null) {
          setState(() {
            _cameras = response.data!;
            _isLoadingCameras = false;
          });
        } else {
          if (mounted) {
            setState(() {
              _isLoadingCameras = false;
            });
          }
        }
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _isLoadingCameras = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCameras = false;
        });
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      final response = await TechHubApiClient.getUsers(
        username: widget.authManager.userName!,
        password: widget.authManager.password!,
      );

      if (mounted) {
        if (response.isSuccess && response.data != null) {
          setState(() {
            _users = response.data!;
            _isLoadingUsers = false;
          });
        } else {
          if (mounted) {
            setState(() {
              _isLoadingUsers = false;
            });
          }
        }
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  Widget _buildCameraIcon(String type, String status) {
    // Normalizar el tipo para que coincida con los archivos
    String normalizedType = type;
    if (type.toUpperCase() == 'LPR') {
      normalizedType = 'Lpr';
    }

    final String iconPath = 'lib/assets/mapIcons/$normalizedType-$status.svg';

    return SvgPicture.asset(iconPath, width: 18, height: 18);
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

  List<Map<String, dynamic>> _separateOverlappingCameras(
    List<Map<String, dynamic>> cameras,
  ) {
    final Map<String, List<Map<String, dynamic>>> groupedCameras = {};

    // Agrupar cámaras por coordenadas (redondeadas a 6 decimales para evitar diferencias mínimas)
    for (final camera in cameras) {
      final lat = camera['latitude'] as double?;
      final lng = camera['longitude'] as double?;

      if (lat != null && lng != null) {
        final key = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
        groupedCameras.putIfAbsent(key, () => []).add(camera);
      }
    }

    final List<Map<String, dynamic>> separatedCameras = [];

    for (final group in groupedCameras.values) {
      if (group.length == 1) {
        // Solo una cámara en esta ubicación, mantener coordenadas originales
        separatedCameras.add(group[0]);
      } else {
        // Múltiples cámaras en la misma ubicación, separarlas en círculo
        final centerLat = group[0]['latitude'] as double;
        final centerLng = group[0]['longitude'] as double;

        // Radio de separación en grados (aproximadamente 10 metros)
        const double radius = 0.0001;

        for (int i = 0; i < group.length; i++) {
          final angle = (2 * math.pi * i) / group.length;
          final offsetLat = radius * math.cos(angle);
          final offsetLng = radius * math.sin(angle);

          final separatedCamera = Map<String, dynamic>.from(group[i]);
          separatedCamera['latitude'] = centerLat + offsetLat;
          separatedCamera['longitude'] = centerLng + offsetLng;

          separatedCameras.add(separatedCamera);
        }
      }
    }

    return separatedCameras;
  }

  bool _matchesSearchQuery(Map<String, dynamic> camera) {
    if (_searchQuery.isEmpty) return true;

    final searchFields = [
      camera['name']?.toString().toLowerCase() ?? '',
      camera['ip']?.toString().toLowerCase() ?? '',
      camera['type']?.toString().toLowerCase() ?? '',
      camera['status']?.toString().toLowerCase() ?? '',
      camera['liable']?.toString().toLowerCase() ?? '',
      camera['zone']?.toString().toLowerCase() ?? '',
      camera['direction']?.toString().toLowerCase() ?? '',
    ];

    return searchFields.any((field) => field.contains(_searchQuery));
  }

  Map<String, Map<String, dynamic>> _calculateZoneStats() {
    final zoneStats = <String, Map<String, dynamic>>{};
    final isBasic2Team = widget.authManager.teamName?.toLowerCase() == 'basic2';

    for (final camera in _cameras) {
      final zone = (camera['zone'] as String?)?.toLowerCase() ?? 'sin zona';

      // Filtrar zonas para basic2
      if (isBasic2Team && zone != 'zona norte' && zone != 'zona sur') {
        continue;
      }

      final status = (camera['status'] as String?)?.toLowerCase() ?? 'offline';
      final lat = camera['latitude'] as double?;
      final lng = camera['longitude'] as double?;

      if (lat != null && lng != null) {
        if (!zoneStats.containsKey(zone)) {
          zoneStats[zone] = {
            'online': 0,
            'warning': 0,
            'offline': 0,
            'maintenance': 0,
            'removed': 0,
            'coordinates': <LatLng>[],
          };
        }

        zoneStats[zone]![status] = (zoneStats[zone]![status] ?? 0) + 1;
        zoneStats[zone]!['coordinates'].add(LatLng(lat, lng));
      }
    }

    // Calcular centro de cada zona promediando coordenadas
    zoneStats.forEach((zone, data) {
      final coordinates = data['coordinates'] as List<LatLng>;
      if (coordinates.isNotEmpty) {
        final avgLat =
            coordinates.map((c) => c.latitude).reduce((a, b) => a + b) /
            coordinates.length;
        final avgLng =
            coordinates.map((c) => c.longitude).reduce((a, b) => a + b) /
            coordinates.length;
        data['center'] = LatLng(avgLat, avgLng);
      }
    });

    return zoneStats;
  }

  Widget _buildZonePieChart(String zone, Map<String, dynamic> stats) {
    final onlineCount = stats['online'] as int? ?? 0;
    final warningCount = stats['warning'] as int? ?? 0;
    final offlineCount = stats['offline'] as int? ?? 0;
    final maintenanceCount = stats['maintenance'] as int? ?? 0;
    final removedCount = stats['removed'] as int? ?? 0;

    final sections = <PieChartSectionData>[];
    final statusData = [
      {'status': 'online', 'count': onlineCount},
      {'status': 'warning', 'count': warningCount},
      {'status': 'offline', 'count': offlineCount},
      {'status': 'maintenance', 'count': maintenanceCount},
      {'status': 'removed', 'count': removedCount},
    ];

    for (final data in statusData) {
      final count = data['count'] as int;
      if (count > 0) {
        sections.add(
          PieChartSectionData(
            value: count.toDouble(),
            color: _getStatusColor(data['status'] as String),
            title: '',
            radius: 22,
            showTitle: false,
          ),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 60,
          width: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 1,
                  centerSpaceRadius: 15,
                  borderData: FlBorderData(show: false),
                ),
              ),
              Text(
                '$onlineCount/$warningCount/$offlineCount',
                style: const TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            zone.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Marker> _buildZoneGraphicsMarkers() {
    if (!_showGraphics) return [];

    final zoneStats = _calculateZoneStats();
    final markers = <Marker>[];

    zoneStats.forEach((zone, stats) {
      final center = stats['center'] as LatLng?;
      if (center != null) {
        markers.add(
          Marker(
            point: center,
            width: 80,
            height: 80,
            child: _buildZonePieChart(zone, stats),
          ),
        );
      }
    });

    return markers;
  }

  Map<String, dynamic>? _getLatestUserLocation(Map<String, dynamic> user) {
    final historyLocation = user['historyLocation'] as List?;

    if (historyLocation == null || historyLocation.isEmpty) {
      return null;
    }

    // Encontrar la ubicación más reciente basada en la fecha
    Map<String, dynamic>? latestLocation;
    DateTime? latestDate;

    for (final location in historyLocation) {
      try {
        final dateStr = location['date'] as String?;
        if (dateStr != null) {
          final date = DateTime.parse(dateStr);
          if (latestDate == null || date.isAfter(latestDate)) {
            latestDate = date;
            latestLocation = location;
          }
        }
      } catch (e) {
        // Ignorar errores de parsing de fecha
      }
    }

    return latestLocation;
  }

  Widget _buildUserIcon(String userName) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(LucideIcons.user, color: Colors.white, size: 16),
    );
  }

  void _showUserInfo(Map<String, dynamic> user, Map<String, dynamic> location) {
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
                  Colors.blue.shade50.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.15),
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
                _buildUserDialogHeader(context, user, isWideScreen),

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

                        // Sección de información general
                        _buildUserInfoSection(
                          'Información del Usuario',
                          LucideIcons.user,
                          Colors.blue,
                          [
                            _buildUserDetailRow(
                              'Nombre Completo',
                              '${user['name'] ?? 'Usuario'} ${user['surname'] ?? ''}'
                                  .trim(),
                              LucideIcons.user,
                              Colors.blue.shade600,
                            ),
                            if (user['email'] != null)
                              _buildUserDetailRow(
                                'Email',
                                user['email'] as String,
                                LucideIcons.mail,
                                Colors.blue.shade600,
                              ),
                            if (user['team'] != null)
                              _buildUserDetailRow(
                                'Equipo',
                                user['team'] as String,
                                LucideIcons.users,
                                Colors.blue.shade600,
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Sección de ubicación
                        _buildUserInfoSection(
                          'Información de Ubicación',
                          LucideIcons.mapPin,
                          Colors.purple,
                          [
                            _buildUserDetailRow(
                              'Coordenadas',
                              '${location['latitude']}, ${location['longitude']}',
                              LucideIcons.mapPin,
                              Colors.purple.shade600,
                            ),
                            _buildUserDetailRow(
                              'Última Actualización',
                              _formatUserDate(location['date']),
                              LucideIcons.clock,
                              Colors.purple.shade600,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Sección de mapa con ubicación
                        _buildUserLocationSection(location, isWideScreen),
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

  // Helper methods for improved user dialog

  Widget _buildUserDialogHeader(
    BuildContext context,
    Map<String, dynamic> user,
    bool isWideScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isWideScreen ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade400, Colors.blue.shade600],
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
              LucideIcons.user,
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
                  'Información del Usuario',
                  style: TextStyle(
                    fontSize: isWideScreen ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user['name'] ?? 'Usuario'} ${user['surname'] ?? ''}'
                      .trim(),
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

  Widget _buildUserInfoSection(
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

  Widget _buildUserDetailRow(
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

  Widget _buildUserLocationSection(
    Map<String, dynamic> location,
    bool isWideScreen,
  ) {
    return _buildUserInfoSection(
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
            child: _buildUserMapSection(location),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMapSection(Map<String, dynamic> location) {
    final lat = double.tryParse(location['latitude'] as String? ?? '');
    final lng = double.tryParse(location['longitude'] as String? ?? '');

    if (lat == null || lng == null) {
      return Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.mapPin, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Ubicación no disponible',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

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
                    initialCenter: LatLng(lat, lng),
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
                          point: LatLng(lat, lng),
                          width: 50,
                          height: 50,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.4),
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
                              LucideIcons.user,
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
                            '${location['latitude']}, ${location['longitude']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap:
                              () => _copyUserLocation(
                                location['latitude'] as String,
                                location['longitude'] as String,
                              ),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
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

  Future<void> _copyUserLocation(String latitude, String longitude) async {
    await Clipboard.setData(ClipboardData(text: '$latitude,$longitude'));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ubicación del usuario copiada al portapapeles'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatUserDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'N/A';
      }

      Duration difference = DateTime.now().difference(date);
      if (difference.inMinutes < 1) {
        return 'Hace menos de 1 minuto';
      } else if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes} minutos';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours} horas';
      } else {
        return 'Hace ${difference.inDays} días';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  List<Map<String, dynamic>> _separateOverlappingUsers(
    List<Map<String, dynamic>> users,
  ) {
    final Map<String, List<Map<String, dynamic>>> groupedUsers = {};

    // Agrupar usuarios por coordenadas (redondeadas a 6 decimales para evitar diferencias mínimas)
    for (final user in users) {
      final latestLocation = _getLatestUserLocation(user);
      if (latestLocation != null) {
        try {
          final lat = double.parse(latestLocation['latitude'] as String);
          final lng = double.parse(latestLocation['longitude'] as String);
          final key = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

          if (!groupedUsers.containsKey(key)) {
            groupedUsers[key] = [];
          }
          groupedUsers[key]!.add({
            'user': user,
            'location': latestLocation,
            'lat': lat,
            'lng': lng,
          });
        } catch (e) {
          // Ignorar usuarios con coordenadas inválidas
        }
      }
    }

    final List<Map<String, dynamic>> separatedUsers = [];

    for (final group in groupedUsers.values) {
      if (group.length == 1) {
        // Solo un usuario en esta ubicación, mantener coordenadas originales
        separatedUsers.add(group[0]);
      } else {
        // Múltiples usuarios en la misma ubicación, separarlos en círculo
        final centerLat = group[0]['lat'] as double;
        final centerLng = group[0]['lng'] as double;

        // Radio de separación en grados (aproximadamente 10 metros)
        const double radius = 0.0001;

        for (int i = 0; i < group.length; i++) {
          final angle = (2 * math.pi * i) / group.length;
          final offsetLat = radius * math.cos(angle);
          final offsetLng = radius * math.sin(angle);

          final separatedUser = Map<String, dynamic>.from(group[i]);
          separatedUser['lat'] = centerLat + offsetLat;
          separatedUser['lng'] = centerLng + offsetLng;

          separatedUsers.add(separatedUser);
        }
      }
    }

    return separatedUsers;
  }

  List<Marker> _buildUserMarkers() {
    // Solo mostrar usuarios si el equipo es "et"
    final isEtTeam = widget.authManager.teamName?.toLowerCase() == 'et';
    if (!_showUsers || _users.isEmpty || !isEtTeam) return [];

    // Preparar lista de usuarios con ubicaciones válidas
    final usersWithLocations = <Map<String, dynamic>>[];
    for (final user in _users) {
      final latestLocation = _getLatestUserLocation(user);
      if (latestLocation != null) {
        try {
          final lat = double.parse(latestLocation['latitude'] as String);
          final lng = double.parse(latestLocation['longitude'] as String);
          usersWithLocations.add({
            'user': user,
            'location': latestLocation,
            'lat': lat,
            'lng': lng,
          });
        } catch (e) {
          // Ignorar usuarios con coordenadas inválidas
        }
      }
    }

    // Separar usuarios que están en las mismas coordenadas
    final separatedUsers = _separateOverlappingUsers(_users);

    return separatedUsers.map((userData) {
      final user = userData['user'] as Map<String, dynamic>;
      final location = userData['location'] as Map<String, dynamic>;
      final lat = userData['lat'] as double;
      final lng = userData['lng'] as double;
      final userName = user['name'] as String? ?? 'Usuario';

      return Marker(
        point: LatLng(lat, lng),
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => _showUserInfo(user, location),
          child: _buildUserIcon(userName),
        ),
      );
    }).toList();
  }

  List<Marker> _buildCameraMarkers() {
    if (!_showCameras || _cameras.isEmpty) return [];

    final isEtTeam = widget.authManager.teamName?.toLowerCase() == 'et';
    final isBasicTeam = widget.authManager.teamName?.toLowerCase() == 'basic';
    final isBasic2Team = widget.authManager.teamName?.toLowerCase() == 'basic2';

    List<Map<String, dynamic>> camerasToShow;

    // Basic2 SIEMPRE solo ve cámaras offline de zona norte y zona sur
    if (isBasic2Team) {
      camerasToShow =
          _cameras.where((camera) {
            final liable = camera['liable']?.toString().toLowerCase() ?? '';
            final status = camera['status'] as String?;
            return (liable == 'zona norte' || liable == 'zona sur') &&
                status?.toLowerCase() == 'offline';
          }).toList();
    } else if (_showAllCameras) {
      // Si está seleccionado "Todas", mostrar todas las cámaras pero solo de la zona del equipo
      if (isEtTeam || isBasicTeam) {
        // ET team: mostrar todas las cámaras
        camerasToShow = _cameras;
      } else {
        // Otros equipos: mostrar todas las cámaras pero solo de su zona
        camerasToShow =
            _cameras.where((camera) {
              final liable = camera['liable'] as String?;
              return liable != null &&
                  widget.authManager.teamName != null &&
                  liable.toUpperCase() ==
                      widget.authManager.teamName!.toUpperCase();
            }).toList();
      }
    } else {
      // Si no está seleccionado "Todas"
      if (isEtTeam || isBasicTeam) {
        // ET team: mostrar todas las cámaras offline
        camerasToShow =
            _cameras.where((camera) {
              final status = camera['status'] as String?;
              return status?.toLowerCase() == 'offline';
            }).toList();
      } else {
        // Otros equipos: mostrar solo cámaras offline de su equipo
        camerasToShow =
            _cameras.where((camera) {
              final liable = camera['liable'] as String?;
              final status = camera['status'] as String?;
              return liable != null &&
                  widget.authManager.teamName != null &&
                  liable.toUpperCase() ==
                      widget.authManager.teamName!.toUpperCase() &&
                  status?.toLowerCase() == 'offline';
            }).toList();
      }
    }

    // Aplicar filtro de búsqueda
    if (_searchQuery.isNotEmpty) {
      camerasToShow = camerasToShow.where(_matchesSearchQuery).toList();
    }

    // Separar cámaras que están en las mismas coordenadas
    final separatedCameras = _separateOverlappingCameras(camerasToShow);

    return separatedCameras
        .where(
          (camera) => camera['latitude'] != null && camera['longitude'] != null,
        )
        .map((camera) {
          return Marker(
            point: LatLng(
              camera['latitude'] as double,
              camera['longitude'] as double,
            ),
            width: 18,
            height: 18,
            child: GestureDetector(
              onTap: () => _showCameraInfo(camera),
              child: _buildCameraIcon(
                camera['type'] as String? ?? 'Fixed',
                camera['status'] as String? ?? 'offline',
              ),
            ),
          );
        })
        .toList();
  }

  void _showCameraInfo(Map<String, dynamic> camera) {
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
                _buildMapDialogHeader(context, camera, isWideScreen),

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
                        _buildMapInfoSection(
                          'Información General',
                          LucideIcons.info,
                          Colors.blue,
                          [
                            _buildMapDetailRow(
                              'Estado',
                              _translateStatus(camera['status'] as String),
                              _getStatusIcon(camera['status'] as String),
                              _getStatusColor(camera['status'] as String),
                            ),
                            _buildMapDetailRow(
                              'Tipo',
                              _translateCameraType(camera['type'] as String),
                              LucideIcons.video,
                              Colors.grey.shade600,
                            ),
                            _buildMapDetailRow(
                              'IP',
                              camera['ip'] as String,
                              LucideIcons.globe,
                              Colors.grey.shade600,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Sección de ubicación
                        _buildMapInfoSection(
                          'Ubicación y Responsabilidad',
                          LucideIcons.mapPin,
                          Colors.purple,
                          [
                            _buildMapDetailRow(
                              'Dirección',
                              camera['direction'] as String? ??
                                  'No especificada',
                              LucideIcons.mapPin,
                              Colors.purple.shade600,
                            ),
                            _buildMapDetailRow(
                              'Zona',
                              camera['zone'] as String? ?? 'No especificada',
                              LucideIcons.map,
                              Colors.purple.shade600,
                            ),
                            _buildMapDetailRow(
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
                          _buildMapLocationSection(camera, isWideScreen),

                        const SizedBox(height: 24),

                        // Sección de acciones
                        _buildCameraActionsSection(camera),
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

  // Helper methods for improved camera dialog

  Widget _buildMapDialogHeader(
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

  Widget _buildMapInfoSection(
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

  Widget _buildMapDetailRow(
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

  Widget _buildMapLocationSection(
    Map<String, dynamic> camera,
    bool isWideScreen,
  ) {
    return _buildMapInfoSection(
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
            child: _buildDetailedMapSection(camera),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedMapSection(Map<String, dynamic> camera) {
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
                              () => _copyLocationFromMapDialog(
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

  Future<void> _copyLocationFromMapDialog(
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

  Widget _buildCameraActionsSection(Map<String, dynamic> camera) {
    // Verificar si el usuario tiene permisos para ver la transmisión
    // basic2 NO tiene permiso para ver transmisión
    final teamName = widget.authManager.teamName?.toLowerCase() ?? '';
    final hasPermission =
        teamName == 'et' || teamName == 'eq com 1' || teamName == 'eq com 2';

    return _buildMapInfoSection(
      'Acciones de la Cámara',
      LucideIcons.settings,
      Colors.indigo,
      [
        if (hasPermission)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showVideoStream(camera);
                  },
                  icon: const Icon(LucideIcons.play),
                  label: const Text('Ver Transmisión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.lock, color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No tienes permisos para ver la transmisión de esta cámara',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    Color? activeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isActive ? (activeColor ?? Colors.orange) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 3,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? Colors.white : Colors.grey.shade700,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: isActive ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    final isEtTeam = widget.authManager.teamName?.toLowerCase() == 'et';
    final isBasic2Team = widget.authManager.teamName?.toLowerCase() == 'basic2';

    return Positioned(
      right: 16,
      top: 16,
      child: Column(
        children: [
          if (isEtTeam) ...[
            _buildControlButton(
              icon: LucideIcons.users,
              label: 'Usuarios',
              isActive: _showUsers,
              onPressed: () => setState(() => _showUsers = !_showUsers),
              activeColor: Colors.blue,
            ),
          ],
          _buildControlButton(
            icon: LucideIcons.search,
            label: 'Buscar',
            isActive: _showSearch,
            onPressed: () => setState(() => _showSearch = !_showSearch),
            activeColor: Colors.teal,
          ),
          _buildControlButton(
            icon: LucideIcons.video,
            label: 'Cámaras',
            isActive: _showCameras,
            onPressed: () => setState(() => _showCameras = !_showCameras),
            activeColor: Colors.green,
          ),
          // Ocultar botón "Todas" para basic2 - solo verán cámaras offline
          if (!isBasic2Team)
            _buildControlButton(
              icon: LucideIcons.eye,
              label: 'Todas',
              isActive: _showAllCameras,
              onPressed: () => setState(() => _showAllCameras = !_showAllCameras),
              activeColor: Colors.purple,
            ),
          if (isEtTeam) ...[
            _buildControlButton(
              icon: LucideIcons.barChart3,
              label: 'Gráficos',
              isActive: _showGraphics,
              onPressed: () => setState(() => _showGraphics = !_showGraphics),
              activeColor: Colors.indigo,
            ),
            const SizedBox(height: 16),
            _buildControlButton(
              icon: LucideIcons.settings,
              label: 'Admin',
              isActive: false,
              onPressed: _openCameraCrud,
              activeColor: Colors.red,
            ),
          ],
          const SizedBox(height: 16),
          _buildControlButton(
            icon: _autoRefreshEnabled ? LucideIcons.pause : LucideIcons.play,
            label: _autoRefreshEnabled ? 'Pausar' : 'Reanudar',
            isActive: _autoRefreshEnabled,
            onPressed: _toggleAutoRefresh,
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 90,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          decoration: InputDecoration(
            hintText: 'Buscar cámaras...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                    : null,
          ),
        ),
      ),
    );
  }

  void _openCameraCrud() {
    showDialog(
      context: context,
      builder: (context) => CameraCrudPopup(authManager: widget.authManager),
    );
  }

  void _showVideoStream(Map<String, dynamic> camera) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => WebSocketVideoPlayer(
            camera: camera,
            authManager: widget.authManager,
            width: double.infinity,
            height: 300,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-34.5979, -58.5853),
              initialZoom: 12.0,
              minZoom: 8.0,
              maxZoom: 17.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.flingAnimation,
              ),
            ),
            children: [
              // Capa base del mapa
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.techhub_mobile',
                maxZoom: 17,

                retinaMode: false,
              ),

              // Límites de zona (si están cargados)
              if (!_isLoadingBoundaries && _zoneBoundaries != null)
                PolygonLayer(polygons: _buildZonePolygons()),

              // Marcadores de cámaras (solo si no se muestran gráficos)
              if (!_isLoadingCameras && !_showGraphics)
                MarkerLayer(markers: _buildCameraMarkers()),

              // Gráficos de zona
              if (!_isLoadingCameras && _showGraphics)
                MarkerLayer(markers: _buildZoneGraphicsMarkers()),

              // Marcadores de usuarios (siempre al final para estar encima, pero no con gráficos)
              if (!_isLoadingUsers && _showUsers && !_showGraphics)
                MarkerLayer(markers: _buildUserMarkers()),
            ],
          ),

          // Panel de control
          _buildControlPanel(),

          // Barra de búsqueda
          if (_showSearch) _buildSearchBar(),

          // Indicador de carga y auto-refresh
          if (_isLoadingCameras || _isLoadingBoundaries || _isLoadingUsers)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cargando...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Indicador de auto-refresh (solo cuando no está cargando inicialmente)
          if (!(_isLoadingCameras || _isLoadingBoundaries || _isLoadingUsers))
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      _autoRefreshEnabled
                          ? Colors.green.shade700.withValues(alpha: 0.9)
                          : Colors.orange.shade700.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _autoRefreshEnabled
                          ? LucideIcons.refreshCw
                          : LucideIcons.pause,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _autoRefreshEnabled
                          ? 'Auto-actualización activa'
                          : 'Auto-actualización pausada',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Polygon> _buildZonePolygons() {
    if (_zoneBoundaries == null) return [];

    final List<Polygon> polygons = [];

    try {
      final features = _zoneBoundaries!['features'] as List?;
      if (features == null) return [];

      for (final feature in features) {
        final geometry = feature['geometry'];
        final geometryType = geometry['type'];

        if (geometryType == 'Polygon') {
          final coordinates = geometry['coordinates'][0] as List;
          final points =
              coordinates
                  .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
                  .toList();

          polygons.add(
            Polygon(
              points: points,
              borderColor: Colors.orange,
              borderStrokeWidth: 2.0,
              color: Colors.orange.withValues(alpha: 0.1),
            ),
          );
        } else if (geometryType == 'MultiPolygon') {
          final coordinatesArray = geometry['coordinates'] as List;

          for (final polygonCoordinates in coordinatesArray) {
            final outerRing = polygonCoordinates[0] as List;
            final points =
                outerRing
                    .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
                    .toList();

            polygons.add(
              Polygon(
                points: points,
                borderColor: Colors.orange,
                borderStrokeWidth: 2.0,
                color: Colors.orange.withValues(alpha: 0.1),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Error procesando GeoJSON
    }

    return polygons;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
