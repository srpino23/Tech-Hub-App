import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadZoneBoundaries(), _loadCameras(), _loadUsers()]);
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
      final response = await AnalyzerApiClient.getCameras();

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
      final response = await TechHubApiClient.getUsers();

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

    return SvgPicture.asset(iconPath, width: 16, height: 16);
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

    for (final camera in _cameras) {
      final zone = (camera['zone'] as String?)?.toLowerCase() ?? 'sin zona';
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
            radius: 19,
            showTitle: false,
          ),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 50,
          width: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 1,
                  centerSpaceRadius: 12,
                  borderData: FlBorderData(show: false),
                ),
              ),
              Text(
                '$onlineCount/$warningCount/$offlineCount',
                style: const TextStyle(
                  fontSize: 6,
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
            width: 70,
            height: 70,
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
                  Colors.blue.shade50.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.1),
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
                        '${user['name'] ?? 'Usuario'} ${user['surname'] ?? ''}'
                            .trim(),
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
                _buildUserInfoRow(
                  'Ubicación',
                  '${location['latitude']}, ${location['longitude']}',
                ),
                _buildUserInfoRow(
                  'Última actualización',
                  _formatUserDate(location['date']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserInfoRow(String label, String value) {
    IconData icon;
    Color iconColor;

    switch (label.toLowerCase()) {
      case 'ubicación':
        icon = Icons.location_on;
        iconColor = Colors.red;
        break;
      case 'última actualización':
        icon = Icons.access_time;
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
              softWrap: true,
            ),
          ),
        ],
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

    List<Map<String, dynamic>> camerasToShow;

    if (_showAllCameras) {
      // Si está seleccionado "Todas", mostrar todas las cámaras pero solo de la zona del equipo
      if (isEtTeam) {
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
      if (isEtTeam) {
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
                              initialZoom: 15.0,
                              maxZoom: 16.0,
                              minZoom: 10.0,
                              interactionOptions: const InteractionOptions(
                                flags:
                                    InteractiveFlag.all &
                                    ~InteractiveFlag.rotate &
                                    ~InteractiveFlag.flingAnimation,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                                userAgentPackageName:
                                    'com.example.techhub_mobile',
                                maxZoom: 16,
                                retinaMode: false,
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
    showDialog(context: context, builder: (context) => const CameraCrudPopup());
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

          // Indicador de carga
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

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
