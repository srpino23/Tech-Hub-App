import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/analyzer_api_client.dart';
import '../services/techhub_api_client.dart';

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

  // Datos
  List<Map<String, dynamic>> _cameras = [];
  List<Map<String, dynamic>> _servers = [];
  List<Map<String, dynamic>> _teams = [];

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadCameras(), _loadServers(), _loadTeams()]);
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

  Future<void> _loadTeams() async {
    try {
      final response = await TechHubApiClient.getTeams();
      if (mounted) {
        if (response.isSuccess && response.data != null) {
          setState(() {
            _teams = response.data!;
          });
        }
      }
    } catch (e) {
      // Manejar error silenciosamente
    }
  }

  void _extractZones() {
    final zones = <String>{};
    for (final camera in _cameras) {
      final zone = camera['zone'] as String?;
      if (zone != null && zone.isNotEmpty) {
        // Normalizar zonas a minúsculas para evitar duplicados
        zones.add(zone.toLowerCase());
      }
    }
    setState(() {
      _zones = zones.toList()..sort();
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

  // Función para obtener el ID del servidor por nombre
  String? _getServerIdByName(String serverName) {
    for (final server in _servers) {
      if (server['name'] == serverName) {
        return server['_id'] as String?;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _getFilteredItems() {
    List<Map<String, dynamic>> items = _showCameras ? _cameras : _servers;

    return items.where((item) {
      // Filtro por tipo (solo para cámaras)
      if (_showCameras && _selectedTypeFilter != null) {
        final itemType = item['type'] as String?;
        if (itemType != _selectedTypeFilter) return false;
      }

      // Filtro por zona (case-insensitive)
      if (_selectedZoneFilter != null) {
        final itemZone = item['zone'] as String?;
        if (itemZone?.toLowerCase() != _selectedZoneFilter!.toLowerCase()) {
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
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.video, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Agregar Cámara',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
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
                            icon: LucideIcons.video,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'El nombre es requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Tipo
                          Text(
                            'Tipo',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
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
                            validator: (value) {
                              if (value == null) {
                                return 'Selecciona un tipo';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Servidor
                          Text(
                            'Servidor',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedServer,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
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
                            validator: (value) {
                              if (value == null) {
                                return 'Selecciona un servidor';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: ipController,
                            label: 'IP',
                            icon: LucideIcons.server,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La IP es requerida';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: directionController,
                            label: 'Dirección',
                            icon: LucideIcons.mapPin,
                          ),
                          const SizedBox(height: 16),

                          // Zona
                          Text(
                            'Zona',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedZone,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
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
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: latitudeController,
                                  label: 'Latitud',
                                  icon: LucideIcons.mapPin,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: longitudeController,
                                  label: 'Longitud',
                                  icon: LucideIcons.mapPin,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
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
                          const SizedBox(height: 16),

                          // Responsable
                          Text(
                            'Responsable',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedResponsible,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items:
                                _teams.map((team) {
                                  return DropdownMenuItem(
                                    value: team['name'] as String?,
                                    child: Text(team['name'] as String? ?? ''),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedResponsible = value;
                              });
                            },
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

                                        final cameraData = {
                                          'name': nameController.text,
                                          'type': mappedType,
                                          'direction': directionController.text,
                                          'zone': selectedZone,
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
                                          'liable':
                                              selectedResponsible
                                                  ?.toLowerCase(),
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

    String? selectedType = camera['type'] as String?;
    String? selectedZone = camera['zone'] as String?;
    String? selectedResponsible = camera['liable'] as String?;

    // Normalizar la zona para que coincida con las opciones del dropdown (minúsculas)
    if (selectedZone != null) {
      selectedZone = selectedZone.toLowerCase();
    }

    // Normalizar el tipo de cámara para que coincida con las opciones del dropdown
    if (selectedType != null) {
      // Mapear tipos de la base de datos a los tipos del dropdown
      switch (selectedType.toLowerCase()) {
        case 'fixed':
          selectedType = 'Fija';
          break;
        case 'dome':
          selectedType = 'Domo';
          break;
        case 'lpr':
          selectedType = 'LPR';
          break;
        case 'button':
          selectedType = 'Botón';
          break;
        default:
          // Si no coincide, usar el valor original
          break;
      }
    }

    // Normalizar el responsable: si existe en la lista de equipos, usar el valor de la lista
    if (selectedResponsible != null) {
      final matchingTeam = _teams.firstWhere(
        (team) =>
            (team['name'] as String?)?.toLowerCase() ==
            selectedResponsible!.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (matchingTeam.isNotEmpty) {
        selectedResponsible = matchingTeam['name'] as String?;
      }
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
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
                            Icon(LucideIcons.edit, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Editar Cámara',
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
                                  icon: LucideIcons.video,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'El nombre es requerido';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Tipo
                                Text(
                                  'Tipo',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: selectedType,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
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
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Selecciona un tipo';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                _buildTextField(
                                  controller: ipController,
                                  label: 'IP',
                                  icon: LucideIcons.server,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'La IP es requerida';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                _buildTextField(
                                  controller: directionController,
                                  label: 'Dirección',
                                  icon: LucideIcons.mapPin,
                                ),
                                const SizedBox(height: 16),

                                // Zona
                                Text(
                                  'Zona',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: selectedZone,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
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
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: latitudeController,
                                        label: 'Latitud',
                                        icon: LucideIcons.mapPin,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: longitudeController,
                                        label: 'Longitud',
                                        icon: LucideIcons.mapPin,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
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
                                const SizedBox(height: 16),

                                // Responsable
                                Text(
                                  'Responsable',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: selectedResponsible,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: [
                                    ..._teams.map((team) {
                                      return DropdownMenuItem(
                                        value: team['name'] as String?,
                                        child: Text(
                                          team['name'] as String? ?? '',
                                        ),
                                      );
                                    }),
                                    // Agregar el responsable actual solo si no está en la lista de equipos (case-insensitive)
                                    if (selectedResponsible != null &&
                                        !_teams.any(
                                          (team) =>
                                              (team['name'] as String?)
                                                  ?.toLowerCase() ==
                                              selectedResponsible!
                                                  .toLowerCase(),
                                        ))
                                      DropdownMenuItem(
                                        value: selectedResponsible,
                                        child: Text(selectedResponsible!),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedResponsible = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 24),

                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey.shade300,
                                          foregroundColor: Colors.grey.shade700,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Cancelar'),
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

                                              final cameraData = {
                                                'name': nameController.text,
                                                'type': mappedType,
                                                'direction':
                                                    directionController.text,
                                                'zone': selectedZone,
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
                                                'liable':
                                                    selectedResponsible
                                                        ?.toLowerCase(),
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
                            Icon(LucideIcons.edit, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Editar Servidor',
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
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey.shade300,
                                          foregroundColor: Colors.grey.shade700,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Cancelar'),
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

                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                              }

                                              if (context.mounted &&
                                                  response.isSuccess) {
                                                _showSnackBar(
                                                  context,
                                                  'Servidor actualizado exitosamente',
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 32,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // Header
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
                  Icon(LucideIcons.settings, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Administración',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

            // Contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Botones de selección de vista
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                () => setState(() => _showCameras = true),
                            icon: Icon(LucideIcons.video),
                            label: const Text('Cámaras'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _showCameras
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                              foregroundColor:
                                  _showCameras
                                      ? Colors.white
                                      : Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                () => setState(() => _showCameras = false),
                            icon: Icon(LucideIcons.server),
                            label: const Text('Servidores'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  !_showCameras
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                              foregroundColor:
                                  !_showCameras
                                      ? Colors.white
                                      : Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Filtros
                    Column(
                      children: [
                        // Filtro de tipo (solo para cámaras)
                        if (_showCameras)
                          DropdownButtonFormField<String>(
                            value: _selectedTypeFilter,
                            decoration: InputDecoration(
                              labelText: 'Tipo',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Todos'),
                              ),
                              ..._cameraTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedTypeFilter = value;
                              });
                            },
                          ),
                        if (_showCameras) const SizedBox(height: 12),

                        // Filtros de zona y estado en fila
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedZoneFilter,
                                decoration: InputDecoration(
                                  labelText: 'Zona',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Todas'),
                                  ),
                                  ..._zones.map((zone) {
                                    return DropdownMenuItem(
                                      value: zone,
                                      child: Text(
                                        zone,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedZoneFilter = value;
                                  });
                                },
                                isExpanded: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: _selectedStatusFilter,
                                decoration: InputDecoration(
                                  labelText: 'Estado',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Todos'),
                                  ),
                                  ..._statusOptions.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedStatusFilter = value;
                                  });
                                },
                                isExpanded: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botón agregar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAddItemDialog,
                        icon: Icon(LucideIcons.plus),
                        label: Text(
                          _showCameras ? 'Agregar Cámara' : 'Agregar Servidor',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lista
                    Expanded(
                      child:
                          _isLoadingCameras || _isLoadingServers
                              ? const Center(child: CircularProgressIndicator())
                              : _buildItemsList(),
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

  Widget _buildItemsList() {
    final items = _getFilteredItems();

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showCameras ? LucideIcons.video : LucideIcons.server,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay ${_showCameras ? 'cámaras' : 'servidores'} para mostrar',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(
                item['status'] as String? ?? 'offline',
              ),
              child: Icon(
                _showCameras ? LucideIcons.video : LucideIcons.server,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              item['name'] as String? ?? 'Sin nombre',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estado: ${_translateStatus(item['status'] as String?)}'),
                if (_showCameras && item['type'] != null)
                  Text('Tipo: ${item['type']}'),
                if (item['zone'] != null) Text('Zona: ${item['zone']}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _editItem(item),
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Editar',
                ),
                IconButton(
                  onPressed: () => _deleteItem(item),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
