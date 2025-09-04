import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/analyzer_api_client.dart';

class CameraCrudPopup extends StatefulWidget {
  const CameraCrudPopup({super.key});

  @override
  State<CameraCrudPopup> createState() => _CameraCrudPopupState();
}

class _CameraCrudPopupState extends State<CameraCrudPopup> {
  // Estados de vista
  bool _showCameras = true; // true = cámaras, false = servidores

  // Estados de filtros
  String? _selectedTypeFilter;
  String? _selectedZoneFilter;
  String? _selectedStatusFilter;
  String _searchQuery = '';

  // Datos
  List<Map<String, dynamic>> _cameras = [];
  List<Map<String, dynamic>> _servers = [];

  // Estados de carga
  bool _isLoadingCameras = true;
  bool _isLoadingServers = true;

  // Filtros disponibles
  final List<String> _cameraTypes = ['Fija', 'Domo', 'LPR', 'Botón'];
  final List<String> _statusOptions = [
    'En Línea',
    'Fuera de Línea',
    'Advertencia',
    'Mantenimiento',
    'Retirada',
  ];
  List<String> _zones = [];
  List<String> _serverNames = [];
  List<String> _responsibles = []; // Lista de responsables únicos

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadCameras(), _loadServers()]);
  }

  Future<void> _loadCameras() async {
    try {
      final response = await AnalyzerApiClient.getCameras();
      if (mounted) {
        if (response.isSuccess && response.data != null) {
          setState(() {
            _cameras = response.data!;
            _isLoadingCameras = false;
            _extractZones();
            _extractResponsibles();
          });
        } else {
          setState(() {
            _isLoadingCameras = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCameras = false;
        });
      }
    }
  }

  Future<void> _loadServers() async {
    try {
      final response = await AnalyzerApiClient.getServers();
      if (mounted) {
        if (response.isSuccess && response.data != null) {
          setState(() {
            _servers = response.data!;
            _isLoadingServers = false;
            _extractServerNames();
          });
        } else {
          setState(() {
            _isLoadingServers = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingServers = false;
        });
      }
    }
  }

  void _extractZones() {
    final zones = <String>{}; // Set para evitar duplicados

    for (final camera in _cameras) {
      final zone = camera['zone'] as String?;
      if (zone != null && zone.isNotEmpty) {
        final cleanZone = zone.trim();
        final normalizedZone = _normalizeString(cleanZone);
        zones.add(normalizedZone);
      }
    }

    setState(() {
      _zones =
          zones.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  void _extractServerNames() {
    final serverNames = <String>{};
    for (final server in _servers) {
      final name = server['name'] as String?;
      if (name != null && name.isNotEmpty) {
        serverNames.add(name);
      }
    }
    setState(() {
      _serverNames = serverNames.toList()..sort();
    });
  }

  void _extractResponsibles() {
    final responsibles = <String>{}; // Set para evitar duplicados

    for (final camera in _cameras) {
      final liable = camera['liable'] as String?;
      if (liable != null && liable.isNotEmpty) {
        final cleanLiable = liable.trim();
        final normalizedLiable = _normalizeString(cleanLiable);
        responsibles.add(normalizedLiable);
      }
    }

    setState(() {
      _responsibles =
          responsibles.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  // Función para obtener el ID del servidor por nombre
  String? _getServerIdByName(String serverName) {
    for (final server in _servers) {
      if (server['name'] == serverName) {
        return server['_id'] as String?;
      }
    }
    return null;
  }

  // Función para encontrar un valor normalizado en una lista
  String? _findValueInList(List<String> list, String? value) {
    if (value == null || value.isEmpty) return null;

    final normalizedValue = _normalizeString(value);

    // Buscar coincidencia exacta
    for (final item in list) {
      if (item == normalizedValue) {
        return item;
      }
    }

    return null; // Si no se encuentra, devolver null
  }

  // Función para normalizar strings
  String _normalizeString(String? value) {
    if (value == null || value.isEmpty) return '';

    final cleanValue = value.trim().toLowerCase();

    // Casos especiales para siglas conocidas
    if (cleanValue == 'com' || cleanValue == 'edla') {
      return cleanValue.toUpperCase();
    }

    // Normalización estándar: capitalizar primera letra de cada palabra
    return cleanValue
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';

          // Casos especiales para preposiciones y artículos
          if (['de', 'del', 'la', 'el', 'y'].contains(word)) {
            return word;
          }

          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ')
        .trim();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedTypeFilter = null;
      _selectedZoneFilter = null;
      _selectedStatusFilter = null;
      _searchQuery = '';
    });
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    List<Map<String, dynamic>> items = _showCameras ? _cameras : _servers;

    return items.where((item) {
      // Filtro de búsqueda
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        bool matchFound = false;

        // Campos comunes para buscar en ambos (cámaras y servidores)
        final commonFields = ['name', 'zone', 'status', 'ip', 'username'];

        // Campos específicos de cámaras
        final cameraFields = ['type', 'direction', 'liable'];

        // Campos específicos de servidores
        final serverFields = ['mainIp', 'ipsRange'];

        // Buscar en campos comunes
        for (String field in commonFields) {
          final value = item[field];
          if (value != null &&
              value.toString().toLowerCase().contains(searchLower)) {
            matchFound = true;
            break;
          }
        }

        // Si es cámara, buscar también en campos específicos de cámara
        if (!matchFound && _showCameras) {
          for (String field in cameraFields) {
            final value = item[field];
            if (value != null &&
                value.toString().toLowerCase().contains(searchLower)) {
              matchFound = true;
              break;
            }
          }

          // Buscar también en coordenadas (latitude, longitude)
          if (!matchFound) {
            final latitude = item['latitude'];
            final longitude = item['longitude'];
            if (latitude != null && latitude.toString().contains(searchLower)) {
              matchFound = true;
            }
            if (!matchFound &&
                longitude != null &&
                longitude.toString().contains(searchLower)) {
              matchFound = true;
            }
          }
        }

        // Si es servidor, buscar también en campos específicos de servidor
        if (!matchFound && !_showCameras) {
          for (String field in serverFields) {
            final value = item[field];
            if (value != null &&
                value.toString().toLowerCase().contains(searchLower)) {
              matchFound = true;
              break;
            }
          }
        }

        if (!matchFound) return false;
      }

      // Filtro por tipo (solo para cámaras)
      if (_showCameras && _selectedTypeFilter != null) {
        final itemType = item['type'] as String?;
        final translatedType = _translateCameraType(itemType);
        if (translatedType != _selectedTypeFilter) return false;
      }

      // Filtro por zona (case-insensitive)
      if (_selectedZoneFilter != null) {
        final itemZone = item['zone'] as String?;
        if (_normalizeString(itemZone) !=
            _normalizeString(_selectedZoneFilter)) {
          return false;
        }
      }

      // Filtro por estado (traducir estados de inglés a español)
      if (_selectedStatusFilter != null) {
        final itemStatus = item['status'] as String?;
        String? translatedStatus;

        switch (itemStatus?.toLowerCase()) {
          case 'online':
            translatedStatus = 'En Línea';
            break;
          case 'offline':
            translatedStatus = 'Fuera de Línea';
            break;
          case 'warning':
            translatedStatus = 'Advertencia';
            break;
          case 'maintenance':
            translatedStatus = 'Mantenimiento';
            break;
          case 'removed':
            translatedStatus = 'Retirada';
            break;
          default:
            translatedStatus = itemStatus;
        }

        if (translatedStatus != _selectedStatusFilter) return false;
      }

      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
      case 'en línea':
        return Colors.green.shade600;
      case 'warning':
      case 'advertencia':
        return Colors.yellow.shade600;
      case 'offline':
      case 'fuera de línea':
        return Colors.red.shade600;
      case 'maintenance':
      case 'mantenimiento':
        return Colors.orange.shade600;
      case 'removed':
      case 'retirada':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _translateStatus(String? status) {
    if (status == null) return 'N/A';

    switch (status.toLowerCase()) {
      case 'online':
        return 'En Línea';
      case 'offline':
        return 'Fuera de Línea';
      case 'warning':
        return 'Advertencia';
      case 'maintenance':
        return 'Mantenimiento';
      case 'removed':
        return 'Retirada';
      default:
        return status;
    }
  }

  String _translateCameraType(String? type) {
    if (type == null) return 'N/A';

    switch (type.toLowerCase()) {
      case 'fixed':
        return 'Fija';
      case 'dome':
        return 'Domo';
      case 'lpr':
        return 'LPR';
      case 'button':
        return 'Botón';
      default:
        return type;
    }
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder:
          (context) =>
              _showCameras ? _buildAddCameraDialog() : _buildAddServerDialog(),
    );
  }

  Widget _buildAddCameraDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final ipController = TextEditingController();
    final directionController = TextEditingController();
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();
    final userController = TextEditingController();
    final passwordController = TextEditingController();

    String? selectedType;
    String? selectedServer;
    String? selectedZone;
    String? selectedResponsible;
    String? selectedStatus =
        'En Línea'; // Estado por defecto para nuevas cámaras

    return StatefulBuilder(
      builder: (context, setDialogState) {
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
                _buildAddDialogHeader(
                  context,
                  'Agregar Cámara',
                  LucideIcons.video,
                  isWideScreen,
                ),

                // Contenido
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isWideScreen ? 32 : 20,
                      0,
                      isWideScreen ? 32 : 20,
                      isWideScreen ? 32 : 20,
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),

                          // Información básica
                          _buildEditTextField(
                            controller: nameController,
                            label: 'Nombre de la Cámara',
                            icon: LucideIcons.video,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'El nombre es requerido';
                              }
                              return null;
                            },
                            isWideScreen: isWideScreen,
                          ),

                          // Tipo de cámara
                          _buildEditDropdown(
                            label: 'Tipo de Cámara',
                            value: selectedType,
                            items:
                                _cameraTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedType = value;
                              });
                            },
                            icon: LucideIcons.settings,
                            isWideScreen: isWideScreen,
                          ),

                          // Servidor
                          _buildEditDropdown(
                            label: 'Servidor',
                            value: selectedServer,
                            items:
                                _serverNames.map((server) {
                                  return DropdownMenuItem(
                                    value: server,
                                    child: Text(server),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedServer = value;
                              });
                            },
                            icon: LucideIcons.server,
                            isWideScreen: isWideScreen,
                          ),

                          // IP
                          _buildEditTextField(
                            controller: ipController,
                            label: 'Dirección IP',
                            icon: LucideIcons.server,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La IP es requerida';
                              }
                              return null;
                            },
                            keyboardType: TextInputType.number,
                            isWideScreen: isWideScreen,
                          ),

                          // Dirección
                          _buildEditTextField(
                            controller: directionController,
                            label: 'Dirección Física',
                            icon: LucideIcons.mapPin,
                            isWideScreen: isWideScreen,
                          ),

                          // Zona
                          _buildEditDropdown(
                            label: 'Zona',
                            value: selectedZone,
                            items:
                                _zones.map((zone) {
                                  return DropdownMenuItem(
                                    value: zone,
                                    child: Text(zone),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedZone = value;
                              });
                            },
                            icon: LucideIcons.map,
                            isWideScreen: isWideScreen,
                          ),

                          // Coordenadas
                          Row(
                            children: [
                              Expanded(
                                child: _buildEditTextField(
                                  controller: latitudeController,
                                  label: 'Latitud',
                                  icon: LucideIcons.mapPin,
                                  keyboardType: TextInputType.number,
                                  isWideScreen: isWideScreen,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildEditTextField(
                                  controller: longitudeController,
                                  label: 'Longitud',
                                  icon: LucideIcons.mapPin,
                                  keyboardType: TextInputType.number,
                                  isWideScreen: isWideScreen,
                                ),
                              ),
                            ],
                          ),

                          // Credenciales
                          _buildEditTextField(
                            controller: userController,
                            label: 'Usuario',
                            icon: LucideIcons.user,
                            isWideScreen: isWideScreen,
                          ),

                          _buildEditTextField(
                            controller: passwordController,
                            label: 'Contraseña',
                            icon: LucideIcons.lock,
                            obscureText: true,
                            isWideScreen: isWideScreen,
                          ),

                          // Responsable
                          _buildEditDropdown(
                            label: 'Responsable',
                            value: selectedResponsible,
                            items:
                                _responsibles.map((responsible) {
                                  return DropdownMenuItem(
                                    value: responsible,
                                    child: Text(responsible),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedResponsible = value;
                              });
                            },
                            icon: LucideIcons.users,
                            isWideScreen: isWideScreen,
                          ),

                          // Estado de la cámara
                          _buildEditDropdown(
                            label: 'Estado',
                            value: selectedStatus,
                            items:
                                _statusOptions.map((status) {
                                  return DropdownMenuItem(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedStatus = value;
                              });
                            },
                            icon: LucideIcons.activity,
                            isWideScreen: isWideScreen,
                          ),

                          const SizedBox(height: 32),

                          // Botones de acción
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.grey.shade700,
                                    padding: EdgeInsets.symmetric(
                                      vertical: isWideScreen ? 18 : 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontSize: isWideScreen ? 16 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (formKey.currentState!.validate()) {
                                      try {
                                        final serverId = _getServerIdByName(
                                          selectedServer!,
                                        );
                                        if (serverId == null) {
                                          _showSnackBar(
                                            context,
                                            'Error: Servidor no encontrado',
                                            isError: true,
                                          );
                                          return;
                                        }

                                        // Mapear el tipo del dropdown al formato de la base de datos
                                        String? mappedType;
                                        switch (selectedType?.toLowerCase()) {
                                          case 'fija':
                                            mappedType = 'Fixed';
                                            break;
                                          case 'domo':
                                            mappedType = 'Dome';
                                            break;
                                          case 'lpr':
                                            mappedType = 'LPR';
                                            break;
                                          case 'botón':
                                            mappedType = 'Button';
                                            break;
                                          default:
                                            mappedType = selectedType;
                                        }

                                        // Mapear el estado del dropdown al formato de la base de datos
                                        String? mappedStatus;
                                        switch (selectedStatus?.toLowerCase()) {
                                          case 'en línea':
                                            mappedStatus = 'online';
                                            break;
                                          case 'fuera de línea':
                                            mappedStatus = 'offline';
                                            break;
                                          case 'advertencia':
                                            mappedStatus = 'warning';
                                            break;
                                          case 'mantenimiento':
                                            mappedStatus = 'maintenance';
                                            break;
                                          case 'retirada':
                                            mappedStatus = 'removed';
                                            break;
                                          default:
                                            mappedStatus = selectedStatus;
                                        }

                                        final cameraData = {
                                          'name': nameController.text,
                                          'type': mappedType,
                                          'direction': directionController.text,
                                          'zone': _normalizeString(
                                            selectedZone,
                                          ),
                                          'longitude':
                                              double.tryParse(
                                                longitudeController.text,
                                              ) ??
                                              0.0,
                                          'latitude':
                                              double.tryParse(
                                                latitudeController.text,
                                              ) ??
                                              0.0,
                                          'username': userController.text,
                                          'password': passwordController.text,
                                          'ip': ipController.text,
                                          'serverId': serverId,
                                          'liable': _normalizeString(
                                            selectedResponsible,
                                          ),
                                          'status': mappedStatus ?? 'online',
                                        };

                                        final response =
                                            await AnalyzerApiClient.addCamera(
                                              cameraData: cameraData,
                                            );

                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }

                                        if (context.mounted &&
                                            response.isSuccess) {
                                          _showSnackBar(
                                            context,
                                            'Cámara agregada exitosamente',
                                          );
                                          // Recargar datos
                                          _loadData();
                                        } else if (context.mounted) {
                                          _showSnackBar(
                                            context,
                                            'Error: ${response.error}',
                                            isError: true,
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                          _showSnackBar(
                                            context,
                                            'Error: $e',
                                            isError: true,
                                          );
                                        }
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: isWideScreen ? 18 : 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                    shadowColor: Colors.orange.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  child: Text(
                                    'Agregar Cámara',
                                    style: TextStyle(
                                      fontSize: isWideScreen ? 16 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildAddServerDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final zoneController = TextEditingController();
    final mainIpController = TextEditingController();
    final ipsRangeController = TextEditingController();
    final userController = TextEditingController();
    final passwordController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 32,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.server, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Agregar Servidor',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: nameController,
                            label: 'Nombre',
                            icon: LucideIcons.server,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'El nombre es requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: zoneController,
                            label: 'Zona',
                            icon: LucideIcons.mapPin,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: mainIpController,
                            label: 'IP Principal',
                            icon: LucideIcons.server,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La IP principal es requerida';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: ipsRangeController,
                            label: 'Rango de IPs',
                            icon: LucideIcons.network,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: userController,
                            label: 'Usuario',
                            icon: LucideIcons.user,
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: passwordController,
                            label: 'Contraseña',
                            icon: LucideIcons.lock,
                            obscureText: true,
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.grey.shade700,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (formKey.currentState!.validate()) {
                                      try {
                                        final serverData = {
                                          'name': nameController.text,
                                          'zone': zoneController.text,
                                          'mainIp': mainIpController.text,
                                          'ipsRange': ipsRangeController.text,
                                          'username': userController.text,
                                          'password': passwordController.text,
                                        };

                                        final response =
                                            await AnalyzerApiClient.addServer(
                                              serverData: serverData,
                                            );

                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }

                                        if (context.mounted &&
                                            response.isSuccess) {
                                          _showSnackBar(
                                            context,
                                            'Servidor agregado exitosamente',
                                          );
                                          // Recargar datos
                                          _loadData();
                                        } else if (context.mounted) {
                                          _showSnackBar(
                                            context,
                                            'Error: ${response.error}',
                                            isError: true,
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                          _showSnackBar(
                                            context,
                                            'Error: $e',
                                            isError: true,
                                          );
                                        }
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Agregar'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildEditTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool isWideScreen = false,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isWideScreen ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            style: TextStyle(fontSize: isWideScreen ? 16 : 14),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue.shade600,
                  size: isWideScreen ? 20 : 18,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade400),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade400, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isWideScreen ? 20 : 16,
                vertical: isWideScreen ? 20 : 16,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    bool isWideScreen = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isWideScreen ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            items: items,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: isWideScreen ? 16 : 14,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue.shade600,
                  size: isWideScreen ? 20 : 18,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isWideScreen ? 20 : 16,
                vertical: isWideScreen ? 20 : 16,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _editItem(Map<String, dynamic> item) {
    if (_showCameras) {
      _showEditCameraDialog(item);
    } else {
      _showEditServerDialog(item);
    }
  }

  void _showEditCameraDialog(Map<String, dynamic> camera) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: camera['name'] ?? '');
    final ipController = TextEditingController(text: camera['ip'] ?? '');
    final directionController = TextEditingController(
      text: camera['direction'] ?? '',
    );
    final latitudeController = TextEditingController(
      text: (camera['latitude'] ?? '').toString(),
    );
    final longitudeController = TextEditingController(
      text: (camera['longitude'] ?? '').toString(),
    );
    final userController = TextEditingController(
      text: camera['username'] ?? '',
    );
    final passwordController = TextEditingController(
      text: camera['password'] ?? '',
    );

    // Normalizar el tipo de cámara para que coincida con las opciones del dropdown
    String? selectedType = _translateCameraType(camera['type'] as String?);

    // Buscar zona y responsable en las listas normalizadas
    String? selectedZone = _findValueInList(_zones, camera['zone'] as String?);
    String? selectedResponsible = _findValueInList(
      _responsibles,
      camera['liable'] as String?,
    );

    // Normalizar el estado actual de la cámara
    String? selectedStatus = _translateStatus(camera['status'] as String?);

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
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
                        isWideScreen
                            ? 800
                            : MediaQuery.of(context).size.width - 32,
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
                      _buildEditDialogHeader(
                        context,
                        'Editar Cámara',
                        LucideIcons.edit,
                        isWideScreen,
                      ),

                      // Contenido
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            isWideScreen ? 32 : 20,
                            0,
                            isWideScreen ? 32 : 20,
                            isWideScreen ? 32 : 20,
                          ),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),

                                // Información básica
                                _buildEditTextField(
                                  controller: nameController,
                                  label: 'Nombre de la Cámara',
                                  icon: LucideIcons.video,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'El nombre es requerido';
                                    }
                                    return null;
                                  },
                                  isWideScreen: isWideScreen,
                                ),

                                // Tipo de cámara
                                _buildEditDropdown(
                                  label: 'Tipo de Cámara',
                                  value: selectedType,
                                  items:
                                      _cameraTypes.map((type) {
                                        return DropdownMenuItem(
                                          value: type,
                                          child: Text(type),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedType = value;
                                    });
                                  },
                                  icon: LucideIcons.settings,
                                  isWideScreen: isWideScreen,
                                ),

                                // IP
                                _buildEditTextField(
                                  controller: ipController,
                                  label: 'Dirección IP',
                                  icon: LucideIcons.server,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'La IP es requerida';
                                    }
                                    return null;
                                  },
                                  keyboardType: TextInputType.number,
                                  isWideScreen: isWideScreen,
                                ),

                                // Dirección
                                _buildEditTextField(
                                  controller: directionController,
                                  label: 'Dirección Física',
                                  icon: LucideIcons.mapPin,
                                  isWideScreen: isWideScreen,
                                ),

                                // Zona
                                _buildEditDropdown(
                                  label: 'Zona',
                                  value: selectedZone,
                                  items:
                                      _zones.map((zone) {
                                        return DropdownMenuItem(
                                          value: zone,
                                          child: Text(zone),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedZone = value;
                                    });
                                  },
                                  icon: LucideIcons.map,
                                  isWideScreen: isWideScreen,
                                ),

                                // Coordenadas
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildEditTextField(
                                        controller: latitudeController,
                                        label: 'Latitud',
                                        icon: LucideIcons.mapPin,
                                        keyboardType: TextInputType.number,
                                        isWideScreen: isWideScreen,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildEditTextField(
                                        controller: longitudeController,
                                        label: 'Longitud',
                                        icon: LucideIcons.mapPin,
                                        keyboardType: TextInputType.number,
                                        isWideScreen: isWideScreen,
                                      ),
                                    ),
                                  ],
                                ),

                                // Credenciales
                                _buildEditTextField(
                                  controller: userController,
                                  label: 'Usuario',
                                  icon: LucideIcons.user,
                                  isWideScreen: isWideScreen,
                                ),

                                _buildEditTextField(
                                  controller: passwordController,
                                  label: 'Contraseña',
                                  icon: LucideIcons.lock,
                                  obscureText: true,
                                  isWideScreen: isWideScreen,
                                ),

                                // Responsable
                                _buildEditDropdown(
                                  label: 'Responsable',
                                  value: selectedResponsible,
                                  items:
                                      _responsibles.map((responsible) {
                                        return DropdownMenuItem(
                                          value: responsible,
                                          child: Text(responsible),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedResponsible = value;
                                    });
                                  },
                                  icon: LucideIcons.users,
                                  isWideScreen: isWideScreen,
                                ),

                                // Estado de la cámara
                                _buildEditDropdown(
                                  label: 'Estado',
                                  value: selectedStatus,
                                  items:
                                      _statusOptions.map((status) {
                                        return DropdownMenuItem(
                                          value: status,
                                          child: Text(status),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedStatus = value;
                                    });
                                  },
                                  icon: LucideIcons.activity,
                                  isWideScreen: isWideScreen,
                                ),

                                const SizedBox(height: 32),

                                // Botones de acción
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey.shade300,
                                          foregroundColor: Colors.grey.shade700,
                                          padding: EdgeInsets.symmetric(
                                            vertical: isWideScreen ? 18 : 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Cancelar',
                                          style: TextStyle(
                                            fontSize: isWideScreen ? 16 : 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (formKey.currentState!
                                              .validate()) {
                                            try {
                                              // Mapear el tipo del dropdown al formato de la base de datos
                                              String? mappedType;
                                              switch (selectedType
                                                  ?.toLowerCase()) {
                                                case 'fija':
                                                  mappedType = 'Fixed';
                                                  break;
                                                case 'domo':
                                                  mappedType = 'Dome';
                                                  break;
                                                case 'lpr':
                                                  mappedType = 'LPR';
                                                  break;
                                                case 'botón':
                                                  mappedType = 'Button';
                                                  break;
                                                default:
                                                  mappedType = selectedType;
                                              }

                                              // Mapear el estado del dropdown al formato de la base de datos
                                              String? mappedStatus;
                                              switch (selectedStatus
                                                  ?.toLowerCase()) {
                                                case 'en línea':
                                                  mappedStatus = 'online';
                                                  break;
                                                case 'fuera de línea':
                                                  mappedStatus = 'offline';
                                                  break;
                                                case 'advertencia':
                                                  mappedStatus = 'warning';
                                                  break;
                                                case 'mantenimiento':
                                                  mappedStatus = 'maintenance';
                                                  break;
                                                case 'retirada':
                                                  mappedStatus = 'removed';
                                                  break;
                                                default:
                                                  mappedStatus = selectedStatus;
                                              }

                                              final cameraData = {
                                                'name': nameController.text,
                                                'type': mappedType,
                                                'direction':
                                                    directionController.text,
                                                'zone': _normalizeString(
                                                  selectedZone,
                                                ),
                                                'longitude':
                                                    double.tryParse(
                                                      longitudeController.text,
                                                    ) ??
                                                    0.0,
                                                'latitude':
                                                    double.tryParse(
                                                      latitudeController.text,
                                                    ) ??
                                                    0.0,
                                                'username': userController.text,
                                                'password':
                                                    passwordController.text,
                                                'ip': ipController.text,
                                                'liable': _normalizeString(
                                                  selectedResponsible,
                                                ),
                                                'status': mappedStatus,
                                              };

                                              final response =
                                                  await AnalyzerApiClient.updateCamera(
                                                    cameraId:
                                                        camera['_id'] as String,
                                                    cameraData: cameraData,
                                                  );

                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                              }

                                              if (context.mounted &&
                                                  response.isSuccess) {
                                                _showSnackBar(
                                                  context,
                                                  'Cámara actualizada exitosamente',
                                                );
                                                // Recargar datos
                                                _loadData();
                                              } else if (context.mounted) {
                                                _showSnackBar(
                                                  context,
                                                  'Error: ${response.error}',
                                                  isError: true,
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                                _showSnackBar(
                                                  context,
                                                  'Error: $e',
                                                  isError: true,
                                                );
                                              }
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Actualizar'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  void _showEditServerDialog(Map<String, dynamic> server) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: server['name'] ?? '');
    final zoneController = TextEditingController(text: server['zone'] ?? '');
    final mainIpController = TextEditingController(
      text: server['mainIp'] ?? '',
    );
    final ipsRangeController = TextEditingController(
      text: server['ipsRange'] ?? '',
    );
    final userController = TextEditingController(
      text: server['username'] ?? '',
    );
    final passwordController = TextEditingController(
      text: server['password'] ?? '',
    );

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
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
                        isWideScreen
                            ? 800
                            : MediaQuery.of(context).size.width - 32,
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
                      _buildEditDialogHeader(
                        context,
                        'Editar Servidor',
                        LucideIcons.server,
                        isWideScreen,
                      ),

                      // Contenido
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            isWideScreen ? 32 : 20,
                            0,
                            isWideScreen ? 32 : 20,
                            isWideScreen ? 32 : 20,
                          ),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),

                                // Información básica
                                _buildEditTextField(
                                  controller: nameController,
                                  label: 'Nombre del Servidor',
                                  icon: LucideIcons.server,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'El nombre es requerido';
                                    }
                                    return null;
                                  },
                                  isWideScreen: isWideScreen,
                                ),

                                _buildEditTextField(
                                  controller: zoneController,
                                  label: 'Zona',
                                  icon: LucideIcons.map,
                                  isWideScreen: isWideScreen,
                                ),

                                _buildEditTextField(
                                  controller: mainIpController,
                                  label: 'IP Principal',
                                  icon: LucideIcons.server,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'La IP principal es requerida';
                                    }
                                    return null;
                                  },
                                  keyboardType: TextInputType.number,
                                  isWideScreen: isWideScreen,
                                ),

                                _buildEditTextField(
                                  controller: ipsRangeController,
                                  label: 'Rango de IPs',
                                  icon: LucideIcons.network,
                                  isWideScreen: isWideScreen,
                                ),

                                _buildEditTextField(
                                  controller: userController,
                                  label: 'Usuario',
                                  icon: LucideIcons.user,
                                  isWideScreen: isWideScreen,
                                ),

                                _buildEditTextField(
                                  controller: passwordController,
                                  label: 'Contraseña',
                                  icon: LucideIcons.lock,
                                  obscureText: true,
                                  isWideScreen: isWideScreen,
                                ),

                                const SizedBox(height: 32),

                                // Botones de acción
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey.shade300,
                                          foregroundColor: Colors.grey.shade700,
                                          padding: EdgeInsets.symmetric(
                                            vertical: isWideScreen ? 18 : 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Cancelar',
                                          style: TextStyle(
                                            fontSize: isWideScreen ? 16 : 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (formKey.currentState!
                                              .validate()) {
                                            try {
                                              final serverData = {
                                                'name': nameController.text,
                                                'zone': zoneController.text,
                                                'mainIp': mainIpController.text,
                                                'ipsRange':
                                                    ipsRangeController.text,
                                                'username': userController.text,
                                                'password':
                                                    passwordController.text,
                                              };

                                              final response =
                                                  await AnalyzerApiClient.updateServer(
                                                    serverId:
                                                        server['_id'] as String,
                                                    serverData: serverData,
                                                  );

                                              if (context.mounted &&
                                                  response.isSuccess) {
                                                _showSnackBar(
                                                  context,
                                                  'Servidor actualizado exitosamente',
                                                );
                                                _loadData();
                                              } else if (context.mounted) {
                                                _showSnackBar(
                                                  context,
                                                  'Error: ${response.error}',
                                                  isError: true,
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                                _showSnackBar(
                                                  context,
                                                  'Error: $e',
                                                  isError: true,
                                                );
                                              }
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: isWideScreen ? 18 : 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 2,
                                          shadowColor: Colors.blue.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        child: Text(
                                          'Actualizar Servidor',
                                          style: TextStyle(
                                            fontSize: isWideScreen ? 16 : 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildActionButtons(bool isWideScreen) {
    final hasFilters =
        _selectedTypeFilter != null ||
        _selectedZoneFilter != null ||
        _selectedStatusFilter != null ||
        _searchQuery.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            isWideScreen
                ? Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        _showCameras ? 'Agregar Cámara' : 'Agregar Servidor',
                        LucideIcons.plus,
                        Colors.green,
                        _showAddItemDialog,
                        isWideScreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (hasFilters)
                      _buildActionButton(
                        'Limpiar Filtros',
                        LucideIcons.filterX,
                        Colors.grey.shade600,
                        _clearAllFilters,
                        isWideScreen,
                      ),
                  ],
                )
                : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(
                        _showCameras ? 'Agregar Cámara' : 'Agregar Servidor',
                        LucideIcons.plus,
                        Colors.green,
                        _showAddItemDialog,
                        isWideScreen,
                      ),
                    ),
                    if (hasFilters) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          'Limpiar Filtros',
                          LucideIcons.filterX,
                          Colors.grey.shade600,
                          _clearAllFilters,
                          isWideScreen,
                        ),
                      ),
                    ],
                  ],
                ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool isWideScreen,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isWideScreen ? 20 : 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: isWideScreen ? 16 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          vertical: isWideScreen ? 18 : 16,
          horizontal: isWideScreen ? 24 : 20,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: color.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildFiltersSection(bool isWideScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
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
                  Colors.blue.withValues(alpha: 0.1),
                  Colors.blue.withValues(alpha: 0.05),
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
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.filter, color: Colors.blue, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Filtro de tipo (solo para cámaras)
                if (_showCameras) ...[
                  _buildFilterDropdown(
                    'Tipo',
                    _selectedTypeFilter,
                    [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ..._cameraTypes.map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      ),
                    ],
                    (value) => setState(() => _selectedTypeFilter = value),
                    isWideScreen,
                  ),
                  const SizedBox(height: 16),
                ],

                // Filtros de zona y estado
                if (isWideScreen)
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildFilterDropdown(
                          'Zona',
                          _selectedZoneFilter,
                          [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todas'),
                            ),
                            ..._zones.map(
                              (zone) => DropdownMenuItem(
                                value: zone,
                                child: Text(
                                  zone,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          (value) =>
                              setState(() => _selectedZoneFilter = value),
                          isWideScreen,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFilterDropdown(
                          'Estado',
                          _selectedStatusFilter,
                          [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ..._statusOptions.map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ),
                            ),
                          ],
                          (value) =>
                              setState(() => _selectedStatusFilter = value),
                          isWideScreen,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildFilterDropdown(
                        'Zona',
                        _selectedZoneFilter,
                        [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todas'),
                          ),
                          ..._zones.map(
                            (zone) => DropdownMenuItem(
                              value: zone,
                              child: Text(
                                zone,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        (value) => setState(() => _selectedZoneFilter = value),
                        isWideScreen,
                      ),
                      const SizedBox(height: 16),
                      _buildFilterDropdown(
                        'Estado',
                        _selectedStatusFilter,
                        [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ..._statusOptions.map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          ),
                        ],
                        (value) =>
                            setState(() => _selectedStatusFilter = value),
                        isWideScreen,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
    bool isWideScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          style: TextStyle(
            fontSize: isWideScreen ? 16 : 14,
            color: Colors.grey.shade800,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isWideScreen ? 16 : 12,
              vertical: isWideScreen ? 12 : 8,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: items,
          onChanged: onChanged,
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildSearchSection(bool isWideScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        style: TextStyle(
          fontSize: isWideScreen ? 16 : 15,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
        ),
        decoration: InputDecoration(
          hintText:
              _showCameras
                  ? 'Buscar cámaras por nombre, IP, zona, estado, tipo...'
                  : 'Buscar servidores por nombre, IP, zona, estado...',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: isWideScreen ? 16 : 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              LucideIcons.search,
              color: Colors.grey.shade500,
              size: isWideScreen ? 22 : 20,
            ),
          ),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.x,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: EdgeInsets.symmetric(
            horizontal: isWideScreen ? 24 : 20,
            vertical: isWideScreen ? 20 : 16,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildSectionSelector(bool isWideScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSectionButton(
              'Cámaras',
              _showCameras,
              LucideIcons.video,
              isWideScreen,
            ),
          ),
          Expanded(
            child: _buildSectionButton(
              'Servidores',
              !_showCameras,
              LucideIcons.server,
              isWideScreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionButton(
    String label,
    bool isSelected,
    IconData icon,
    bool isWideScreen,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _showCameras = label == 'Cámaras'),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isWideScreen ? 20 : 16,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: isWideScreen ? 24 : 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontSize: isWideScreen ? 16 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditDialogHeader(
    BuildContext context,
    String title,
    IconData icon,
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
              icon,
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
                  title,
                  style: TextStyle(
                    fontSize: isWideScreen ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Modifica los datos del dispositivo',
                  style: TextStyle(
                    fontSize: isWideScreen ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
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

  Widget _buildAddDialogHeader(
    BuildContext context,
    String title,
    IconData icon,
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
              icon,
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
                  title,
                  style: TextStyle(
                    fontSize: isWideScreen ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Agrega un nuevo dispositivo al sistema',
                  style: TextStyle(
                    fontSize: isWideScreen ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
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

  Widget _buildDialogHeader(BuildContext context, bool isWideScreen) {
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
              LucideIcons.settings,
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
                  'Administración de Dispositivos',
                  style: TextStyle(
                    fontSize: isWideScreen ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestiona cámaras y servidores',
                  style: TextStyle(
                    fontSize: isWideScreen ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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

  void _deleteItem(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: Text(
              '¿Estás seguro de que quieres eliminar ${item['name'] ?? 'este elemento'}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  try {
                    final response =
                        _showCameras
                            ? await AnalyzerApiClient.deleteCamera(
                              cameraId: item['_id'] as String,
                            )
                            : await AnalyzerApiClient.deleteServer(
                              serverId: item['_id'] as String,
                            );

                    if (context.mounted && response.isSuccess) {
                      _showSnackBar(
                        context,
                        '${item['name'] ?? 'Elemento'} eliminado exitosamente',
                      );
                      // Recargar datos
                      _loadData();
                    } else if (context.mounted) {
                      _showSnackBar(
                        context,
                        'Error: ${response.error}',
                        isError: true,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      _showSnackBar(context, 'Error: $e', isError: true);
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      insetPadding: EdgeInsets.all(isWideScreen ? 32 : 16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth:
              isWideScreen ? 1000 : MediaQuery.of(context).size.width - 32,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blue.shade50.withValues(alpha: 0.2)],
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
            _buildDialogHeader(context, isWideScreen),

            // Contenido
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
                    const SizedBox(height: 24),

                    // Botones de selección de vista mejorados
                    _buildSectionSelector(isWideScreen),

                    const SizedBox(height: 24),

                    // Sección de búsqueda mejorada
                    _buildSearchSection(isWideScreen),

                    const SizedBox(height: 24),

                    // Sección de filtros mejorada
                    _buildFiltersSection(isWideScreen),

                    const SizedBox(height: 24),

                    // Botones de acción mejorados
                    _buildActionButtons(isWideScreen),

                    const SizedBox(height: 24),

                    // Lista mejorada
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child:
                          _isLoadingCameras || _isLoadingServers
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(
                                      color: Colors.blue,
                                      strokeWidth: 3,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Cargando ${_showCameras ? 'cámaras' : 'servidores'}...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : _buildItemsList(isWideScreen),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(bool isWideScreen) {
    final items = _getFilteredItems();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _showCameras ? LucideIcons.video : LucideIcons.server,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay ${_showCameras ? 'cámaras' : 'servidores'} para mostrar',
              style: TextStyle(
                fontSize: isWideScreen ? 18 : 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta ajustar los filtros o agregar un nuevo dispositivo',
              style: TextStyle(
                fontSize: isWideScreen ? 14 : 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildItemCard(item, isWideScreen),
        );
      },
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isWideScreen) {
    final statusColor = _getStatusColor(item['status'] as String? ?? 'offline');
    final statusText = _translateStatus(item['status'] as String?);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isWideScreen ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _showCameras ? LucideIcons.video : LucideIcons.server,
                      color: statusColor,
                      size: isWideScreen ? 24 : 20,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String? ?? 'Sin nombre',
                          style: TextStyle(
                            fontSize: isWideScreen ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Separar las burbujas en pantallas pequeñas para evitar superposición
                        if (isWideScreen)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              if (_showCameras && item['type'] != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _translateCameraType(item['type']),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          )
                        else
                          // En pantallas pequeñas, usar Column para evitar superposición
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              if (_showCameras && item['type'] != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _translateCameraType(item['type']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        if (item['zone'] != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.mapPin,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item['zone'].toString(),
                                  style: TextStyle(
                                    fontSize: isWideScreen ? 14 : 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (item['ip'] != null || item['mainIp'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.server,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item['ip']?.toString() ??
                                      item['mainIp']?.toString() ??
                                      '',
                                  style: TextStyle(
                                    fontSize: isWideScreen ? 14 : 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () => _editItem(item),
                          icon: Icon(
                            LucideIcons.edit,
                            color: Colors.blue.shade600,
                            size: isWideScreen ? 20 : 18,
                          ),
                          tooltip: 'Editar',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () => _deleteItem(item),
                          icon: Icon(
                            LucideIcons.trash2,
                            color: Colors.red.shade600,
                            size: isWideScreen ? 20 : 18,
                          ),
                          tooltip: 'Eliminar',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
