import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../auth_manager.dart';
import '../services/techhub_api_client.dart';
import '../services/analyzer_api_client.dart';
import '../services/api_response.dart';
import '../utils/pdf_download_helper.dart';
import '../utils/data_helpers.dart';
import '../utils/map_utils.dart';
import 'create_report_screen.dart';

class WorksScreen extends StatefulWidget {
  final AuthManager authManager;

  const WorksScreen({super.key, required this.authManager});

  @override
  State<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends State<WorksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _reports = [];
  List<dynamic> _filteredTasks = [];
  bool _isLoading = true;
  bool _isLoadingTasks = true;
  bool _isLoadingReports = true;
  bool _isShowingErrorDialog = false;
  String _selectedStatus = 'in_progress'; // pending, in_progress, completed
  String _selectedSection = 'remitos'; // tareas, remitos

  // MapController para gestionar el ciclo de vida del mapa
  MapController? _mapController;

  // Cache para usuarios para evitar múltiples llamadas
  List<Map<String, dynamic>> _users = [];
  bool _isUsersLoaded = false;

  // Loading state
  int _tasksTotal = 0;
  int _reportsTotal = 0;
  bool _isLoadingAllTasks = false;
  bool _isLoadingAllReports = false;
  final int _initialLoadSize = 20; // Cargar los primeros 20 elementos rápido

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _recoveredInventory = [];
  bool _isInventoryLoaded = false;
  bool _isRecoveredInventoryLoaded = false;

  // ET team validation
  bool _isETTeamUser = false;

  // New task form
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _taskDescriptionController = TextEditingController();
  final TextEditingController _taskLocationController = TextEditingController();
  String? _selectedTeamId;
  List<Map<String, dynamic>> _teams = [];
  bool _isTeamsLoaded = false;
  bool _isCreatingTask = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Asegurar que el estado inicial sea válido para la sección inicial
    if (_selectedSection == 'tareas' && _selectedStatus == 'in_progress') {
      _selectedStatus = 'pending';
    }

    _checkETTeamStatus();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _taskNameController.dispose();
    _taskDescriptionController.dispose();
    _taskLocationController.dispose();
    MapUtils.safeDisposeMapController(_mapController);
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text != _searchQuery) {
      setState(() {
        _searchQuery = _searchController.text;
      });
      _debounceSearch();
    }
  }

  Timer? _searchDebounce;
  void _debounceSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  void _performSearch() {
    if (_searchQuery.isEmpty) {
      _loadData(refresh: true);
    } else {
      _searchData();
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    // Mantener respaldo de los datos actuales si es refresh
    final List<Map<String, dynamic>> tasksBackup = refresh ? List.from(_tasks) : [];
    final List<Map<String, dynamic>> reportsBackup = refresh ? List.from(_reports) : [];

    if (refresh) {
      _tasks.clear();
      _reports.clear();
    }

    try {
      // Cargar usuarios e inventarios primero para que estén disponibles cuando se carguen los reportes
      await Future.wait([
        _loadUsers(),
        _loadInventory(),
        _loadRecoveredInventory(),
      ]);

      // Cargar datos iniciales rápido, luego el resto en segundo plano
      await Future.wait([_loadTasksInitial(), _loadReportsInitial()]);

      // Después cargar todo en segundo plano
      _loadAllDataInBackground();
    } catch (e) {
      // Si hay error durante refresh, restaurar los datos anteriores
      if (refresh && mounted) {
        setState(() {
          _tasks = tasksBackup;
          _reports = reportsBackup;
          _filterTasks();
        });
      }
      rethrow; // Re-lanzar para que el caller maneje el error
    }
  }

  // Carga inicial rápida de tareas (primeros elementos)
  Future<void> _loadTasksInitial() async {
    try {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _isLoadingTasks = true;
      });

      final isET = await _isETTeam();
      late ApiResponse<Map<String, dynamic>> response;

      if (isET) {
        response = await TechHubApiClient.getAllTasks(
          page: 1,
          limit: _initialLoadSize,
        );
      } else {
        final teamId = await _getTeamId();
        if (teamId == null) {
          throw Exception('No se pudo obtener el ID del equipo');
        }

        response = await TechHubApiClient.getTasksByTeam(
          teamId: teamId,
          page: 1,
          limit: _initialLoadSize,
        );
      }

      if (!mounted) return;

      if (!response.isSuccess) {
        throw Exception(response.error ?? 'Failed to load tasks');
      }

      final List<Map<String, dynamic>> initialTasks =
          List<Map<String, dynamic>>.from(response.data!['tasks']);
      final Map<String, dynamic> pagination = response.data!['pagination'];
      final int total = pagination['totalItems'];

      if (mounted) {
        setState(() {
          _tasks = initialTasks;
          _tasksTotal = total;
          _filterTasks();
          _isLoadingTasks = false;
          if (!_isLoadingReports && _isUsersLoaded) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
          if (!_isLoadingReports && _isUsersLoaded) {
            _isLoading = false;
          }
        });
        _showGlobalError(
          'Error de conexión al cargar tareas. Verifique su conexión a internet.',
        );
      }
    }
  }

  // Carga inicial rápida de reportes (primeros elementos)
  Future<void> _loadReportsInitial() async {
    try {
      if (!mounted) return;

      setState(() {
        _isLoadingReports = true;
      });

      final isET = await _isETTeam();
      late ApiResponse<Map<String, dynamic>> response;

      if (isET) {
        response = await TechHubApiClient.getAllReports(
          page: 1,
          limit: _initialLoadSize,
        );
      } else {
        final teamId = await _getTeamId();
        if (teamId == null) {
          throw Exception('No se pudo obtener el ID del equipo');
        }

        final userId = widget.authManager.userId;
        if (userId == null) {
          throw Exception('No se pudo obtener el ID del usuario');
        }

        response = await TechHubApiClient.getReportsByTeam(
          teamId: teamId,
          page: 1,
          limit: _initialLoadSize,
          userId: widget.authManager.userId,
        );
      }

      if (!mounted) return;

      if (!response.isSuccess) {
        throw Exception(response.error ?? 'Failed to load reports');
      }

      final List<Map<String, dynamic>> initialReports =
          List<Map<String, dynamic>>.from(response.data!['reports']);
      final Map<String, dynamic> pagination = response.data!['pagination'];
      final int total = pagination['totalItems'];

      if (mounted) {
        setState(() {
          _reports = initialReports;
          _reportsTotal = total;
          _filterTasks();
          _isLoadingReports = false;
          if (!_isLoadingTasks && _isUsersLoaded) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReports = false;
          if (!_isLoadingTasks && _isUsersLoaded) {
            _isLoading = false;
          }
        });
        _showGlobalError(
          'Error de conexión al cargar remitos. Verifique su conexión a internet.',
        );
      }
    }
  }

  // Carga completa en segundo plano
  // Esta función inicia la carga progresiva de todos los datos después de mostrar los primeros elementos
  void _loadAllDataInBackground() {
    // Cargar todas las tareas en segundo plano
    _loadAllTasksInBackground();

    // Cargar todos los reportes en segundo plano
    _loadAllReportsInBackground();
  }

  Future<void> _loadAllTasksInBackground() async {
    if (_isLoadingAllTasks || _tasksTotal <= _initialLoadSize) return;

    setState(() {
      _isLoadingAllTasks = true;
    });

    try {
      final isET = await _isETTeam();
      final int totalPages =
          (_tasksTotal / 100).ceil(); // Usar páginas de 100 elementos
      List<Map<String, dynamic>> allTasks = List.from(_tasks);

      for (int page = 1; page <= totalPages; page++) {
        if (!mounted) break;

        late ApiResponse<Map<String, dynamic>> response;

        if (isET) {
          response = await TechHubApiClient.getAllTasks(page: page, limit: 100);
        } else {
          final teamId = await _getTeamId();
          if (teamId == null) continue;

          response = await TechHubApiClient.getTasksByTeam(
            teamId: teamId,
            page: page,
            limit: 100,
          );
        }

        if (response.isSuccess) {
          final List<Map<String, dynamic>> pageTasks =
              List<Map<String, dynamic>>.from(response.data!['tasks']);

          // Evitar duplicados
          for (var task in pageTasks) {
            if (!allTasks.any((existing) => existing['_id'] == task['_id'])) {
              allTasks.add(task);
            }
          }

          // Actualizar UI periódicamente
          if (mounted && page % 2 == 0) {
            // Cada 2 páginas
            setState(() {
              _tasks = allTasks;
              _filterTasks();
            });
          }
        }

        // Pequeña pausa para no sobrecargar
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (mounted) {
        setState(() {
          _tasks = allTasks;
          _filterTasks();
          _isLoadingAllTasks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAllTasks = false;
        });
      }
    }
  }

  Future<void> _loadAllReportsInBackground() async {
    if (_isLoadingAllReports || _reportsTotal <= _initialLoadSize) return;

    setState(() {
      _isLoadingAllReports = true;
    });

    try {
      final isET = await _isETTeam();
      final int totalPages =
          (_reportsTotal / 100).ceil(); // Usar páginas de 100 elementos
      List<Map<String, dynamic>> allReports = List.from(_reports);

      for (int page = 1; page <= totalPages; page++) {
        if (!mounted) break;

        late ApiResponse<Map<String, dynamic>> response;

        if (isET) {
          response = await TechHubApiClient.getAllReports(
            page: page,
            limit: 100,
          );
        } else {
          final teamId = await _getTeamId();
          if (teamId == null) continue;

          response = await TechHubApiClient.getReportsByTeam(
            teamId: teamId,
            page: page,
            limit: 100,
            userId: widget.authManager.userId,
          );
        }

        if (response.isSuccess) {
          final List<Map<String, dynamic>> pageReports =
              List<Map<String, dynamic>>.from(response.data!['reports']);

          // Evitar duplicados
          for (var report in pageReports) {
            if (!allReports.any(
              (existing) => existing['_id'] == report['_id'],
            )) {
              allReports.add(report);
            }
          }

          // Actualizar UI periódicamente
          if (mounted && page % 2 == 0) {
            // Cada 2 páginas
            setState(() {
              _reports = allReports;
              _filterTasks();
            });
          }
        }

        // Pequeña pausa para no sobrecargar
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (mounted) {
        setState(() {
          _reports = allReports;
          _filterTasks();
          _isLoadingAllReports = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAllReports = false;
        });
      }
    }
  }

  Future<String?> _getTeamId() async {
    return widget.authManager.teamId;
  }

  Future<bool> _isETTeam() async {
    final teamName = widget.authManager.teamName;
    return teamName?.toLowerCase() == 'et';
  }

  void _checkETTeamStatus() async {
    _isETTeamUser = await _isETTeam();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUsers() async {
    if (_isUsersLoaded) return; // Ya están cargados

    try {
      setState(() {
        _isLoading = true;
      });

      final response = await TechHubApiClient.getUsers();

      if (response.isSuccess && response.data != null) {
        if (mounted) {
          setState(() {
            _users = response.data!;
            _isUsersLoaded = true;
          });
        }
      }
    } catch (e) {
      // Silenciar errores de carga de usuarios para no interrumpir la funcionalidad principal
    }
  }

  Future<void> _loadInventory() async {
    if (_isInventoryLoaded) return; // Ya está cargado

    try {
      final response = await TechHubApiClient.getInventory();

      if (response.isSuccess && response.data != null) {
        if (mounted) {
          setState(() {
            _inventory = response.data!;
            _isInventoryLoaded = true;
          });
        }
      }
    } catch (e) {
      // Silenciar errores de carga de inventario para no interrumpir la funcionalidad principal
    }
  }

  Future<void> _loadRecoveredInventory() async {
    if (_isRecoveredInventoryLoaded) return; // Ya está cargado

    try {
      final response = await TechHubApiClient.getRecoveredInventory();

      if (response.isSuccess && response.data != null) {
        if (mounted) {
          setState(() {
            _recoveredInventory = response.data!;
            _isRecoveredInventoryLoaded = true;
          });
        }
      }
    } catch (e) {
      // Silenciar errores de carga de inventario recuperado para no interrumpir la funcionalidad principal
    }
  }

  String _getUserNameById(String userId) {
    return !_isUsersLoaded || _users.isEmpty
        ? 'Cargando...'
        : DataHelpers.getUserNameById(userId, _users);
  }

  String _getMaterialNameById(String materialId) {
    if (!_isInventoryLoaded || !_isRecoveredInventoryLoaded) {
      return 'Cargando...';
    }

    // Buscar primero en el inventario principal
    String materialName = DataHelpers.getMaterialNameById(
      materialId,
      _inventory,
    );

    // Si no se encuentra en el inventario principal, buscar en el recuperado
    if (materialName == 'Material desconocido' &&
        _recoveredInventory.isNotEmpty) {
      materialName = DataHelpers.getMaterialNameById(
        materialId,
        _recoveredInventory,
      );

      // Si se encuentra en el inventario recuperado, agregar un prefijo para identificarlo
      if (materialName != 'Material desconocido') {
        materialName = '♻️ $materialName';
      }
    }

    return materialName;
  }

  Future<void> _searchData() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _isSearching = true;
      });

      final isET = await _isETTeam();

      if (!isET) {
        final teamId = await _getTeamId();
        if (teamId == null) {
          throw Exception('No se pudo obtener el ID del equipo');
        }
      }

      // Para la búsqueda, simplemente filtraremos los datos ya cargados localmente
      // ya que la nueva API no tiene endpoints específicos de búsqueda
      // ET team will search through all loaded data, regular teams through their own
      if (mounted) {
        setState(() {
          _filterTasks();
        });
      }
    } catch (e) {
      if (mounted) {
        _showGlobalError('Error al buscar. Verifique su conexión a internet.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSearching = false;
        });
      }
    }
  }

  void _filterTasks() {
    if (_selectedSection == 'tareas') {
      _filteredTasks =
          _tasks.where((task) {
            final matchesStatus = task['status'] == _selectedStatus;
            final matchesSearch =
                _searchQuery.isEmpty ||
                (task['title']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (task['toDo']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false);
            return matchesStatus && matchesSearch;
          }).toList();
    } else if (_selectedSection == 'remitos') {
      _filteredTasks =
          _reports.where((report) {
            final matchesStatus = report['status'] == _selectedStatus;

            if (_searchQuery.isEmpty) {
              return matchesStatus;
            }

            final searchLower = _searchQuery.toLowerCase();
            bool matchesSearch = false;

            // Buscar en campos del reporte
            final typeOfWork = report['typeOfWork']?.toString().toLowerCase();
            final toDo = report['toDo']?.toString().toLowerCase();
            final location = report['location']?.toString().toLowerCase();
            final connectivity =
                report['connectivity']?.toString().toLowerCase();
            final cameraName = report['cameraName']?.toString().toLowerCase();

            if ((typeOfWork?.contains(searchLower) ?? false) ||
                (toDo?.contains(searchLower) ?? false) ||
                (location?.contains(searchLower) ?? false) ||
                (connectivity?.contains(searchLower) ?? false) ||
                (cameraName?.contains(searchLower) ?? false)) {
              matchesSearch = true;
            }

            // Buscar por nombre de usuario
            if (!matchesSearch) {
              final userId = report['userId']?.toString();
              if (userId != null && _isUsersLoaded) {
                final userName = _getUserNameById(userId);
                if (userName.toLowerCase().contains(searchLower)) {
                  matchesSearch = true;
                }
              }
            }

            return matchesStatus && matchesSearch;
          }).toList();
    }
  }

  void _onStatusChanged(String status) {
    // Validar que el estado sea válido para la sección actual
    if (_selectedSection == 'tareas' && status == 'in_progress') {
      // Las tareas no tienen estado "en progreso", mostrar mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las tareas solo pueden estar pendientes o terminadas'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return; // No cambiar el estado
    }

    setState(() {
      _selectedStatus = status;
      _filterTasks();
    });

    if (_searchQuery.isNotEmpty) {
      _searchData();
    }
  }

  void _onSectionChanged(String section) {
    setState(() {
      _selectedSection = section;

      // Si se cambia a tareas y el estado actual es "in_progress", cambiarlo a "pending"
      // ya que las tareas no tienen estado "in_progress"
      if (section == 'tareas' && _selectedStatus == 'in_progress') {
        _selectedStatus = 'pending';
      }

      _filterTasks();
    });

    // Si se cambia a remitos y los usuarios o inventarios no están cargados, cargarlos
    if (section == 'remitos' &&
        (!_isUsersLoaded ||
            !_isInventoryLoaded ||
            !_isRecoveredInventoryLoaded)) {
      if (!_isUsersLoaded) _loadUsers();
      if (!_isInventoryLoaded) _loadInventory();
      if (!_isRecoveredInventoryLoaded) _loadRecoveredInventory();
    }

    if (_searchQuery.isNotEmpty) {
      _searchData();
    }
  }

  void _showGlobalError(String message) {
    // Evitar múltiples diálogos de error simultáneos
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
                _loadData();
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
    if (_isLoading && _tasks.isEmpty && _reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              !_isUsersLoaded ? 'Cargando usuarios...' : 'Cargando datos...',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Search bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              decoration: InputDecoration(
                hintText:
                    _selectedSection == 'tareas'
                        ? 'Buscar tareas...'
                        : 'Buscar remitos por usuario, tipo, ubicación...',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child:
                      _isSearching
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.orange.shade600,
                              ),
                            ),
                          )
                          : Icon(
                            LucideIcons.search,
                            color: Colors.grey.shade500,
                            size: 20,
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
                              _searchController.clear();
                              _loadData(refresh: true);
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
                  borderSide: BorderSide(
                    color: Colors.orange.shade400,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),

        // Section selector (Tareas / Remitos)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildSectionButton(
                  'Tareas',
                  'tareas',
                  LucideIcons.checkSquare,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSectionButton(
                  'Remitos',
                  'remitos',
                  LucideIcons.fileText,
                ),
              ),
            ],
          ),
        ),
        // Status filter buttons
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              if (_selectedSection == 'tareas') ...[
                // Solo mostrar Pendientes y Terminadas para Tareas
                Expanded(
                  child: _buildStatusButton(
                    'Pendientes',
                    'pending',
                    Colors.red,
                    LucideIcons.clock,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusButton(
                    'Terminadas',
                    'completed',
                    Colors.green,
                    LucideIcons.check,
                  ),
                ),
              ] else ...[
                // Mostrar las tres opciones para Remitos
                Expanded(
                  child: _buildStatusButton(
                    'Pendientes',
                    'pending',
                    Colors.red,
                    LucideIcons.clock,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusButton(
                    'En Proceso',
                    'in_progress',
                    Colors.orange,
                    LucideIcons.play,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusButton(
                    'Terminadas',
                    'completed',
                    Colors.green,
                    LucideIcons.check,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Results info and pagination controls
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            children: [
              // Results info
              Row(
                children: [
                  if (_searchQuery.isNotEmpty) ...[
                    if (_isSearching)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange,
                        ),
                      )
                    else
                      Icon(
                        LucideIcons.search,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSearching
                            ? 'Buscando...'
                            : 'Resultados para: "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(
                      _selectedSection == 'tareas'
                          ? LucideIcons.checkSquare
                          : LucideIcons.fileText,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedSection == 'tareas'
                            ? 'Total: $_tasksTotal tareas'
                            : 'Total: $_reportsTotal remitos',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                  if (_filteredTasks.isNotEmpty && _searchQuery.isEmpty) ...[
                    Text(
                      'Mostrando ${_filteredTasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  // Indicador de carga en segundo plano
                  if (_isLoadingAllTasks || _isLoadingAllReports) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.orange.shade400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cargando más...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Tasks list
        Expanded(child: _buildTasksList()),
      ],
      ),
      floatingActionButton: (_selectedSection == 'tareas' && _isETTeamUser) ? FloatingActionButton(
        onPressed: _showNewTaskDialog,
        backgroundColor: Colors.orange,
        tooltip: 'Nueva tarea',
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildSectionButton(String label, String section, IconData icon) {
    final isSelected = _selectedSection == section;
    return GestureDetector(
      onTap: () => _onSectionChanged(section),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
            width: 2,
          ),
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
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(
    String label,
    String status,
    Color color,
    IconData icon,
  ) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () => _onStatusChanged(status),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    // Show loading for specific section when no data
    bool isCurrentSectionLoading =
        _selectedSection == 'tareas' ? _isLoadingTasks : _isLoadingReports;

    if (isCurrentSectionLoading && _filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              _selectedSection == 'tareas'
                  ? 'Cargando tareas...'
                  : 'Cargando remitos...',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_filteredTasks.isEmpty && !isCurrentSectionLoading) {
      String emptyMessage;
      IconData emptyIcon;

      if (_searchQuery.isNotEmpty) {
        emptyMessage =
            _selectedSection == 'tareas'
                ? 'No se encontraron tareas'
                : 'No se encontraron remitos';
        emptyIcon = LucideIcons.searchX;
      } else {
        switch (_selectedStatus) {
          case 'pending':
            emptyMessage =
                _selectedSection == 'tareas'
                    ? 'No hay tareas pendientes'
                    : 'No hay remitos pendientes';
            emptyIcon = LucideIcons.clock;
            break;
          case 'in_progress':
            emptyMessage =
                _selectedSection == 'tareas'
                    ? 'No hay tareas en proceso'
                    : 'No hay remitos en proceso';
            emptyIcon = LucideIcons.play;
            break;
          case 'completed':
            emptyMessage =
                _selectedSection == 'tareas'
                    ? 'No hay tareas terminadas'
                    : 'No hay remitos terminados';
            emptyIcon = LucideIcons.check;
            break;
          default:
            emptyMessage =
                _selectedSection == 'tareas'
                    ? 'No hay tareas'
                    : 'No hay remitos';
            emptyIcon = LucideIcons.clipboard;
        }
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _loadData(refresh: true);
                },
                icon: const Icon(LucideIcons.refreshCw),
                label: const Text('Limpiar búsqueda'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(refresh: true),
      color: Colors.orange,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView.builder(
          itemCount: _filteredTasks.length,
          itemBuilder: (context, index) {
            final task = _filteredTasks[index];
            return GestureDetector(
              onTap: () {
                if (_selectedSection == 'remitos' &&
                    task['status'] != 'completed' &&
                    task['_id'] != null) {
                  _navigateToEditReport(task);
                } else {
                  _showTaskDetail(task);
                }
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildTaskCard(task),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTaskCard(dynamic task) {
    final statusColor = _getStatusColor(_getTaskStatus(task));
    final taskType = _getTaskType(task);
    final taskTypeColor = _getTaskTypeColor(taskType);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator line
        Container(
          width: 4,
          height: 60,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        // Task content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTaskTitle(task),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTaskDescription(task),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Task type badge y botón de eliminar para remitos terminados
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: taskTypeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          taskType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Botones de editar y eliminar para tareas (solo equipo ET)
                      if (_selectedSection == 'tareas' && _isETTeamUser) ...[
                        // Botón de editar (solo si no está completada)
                        if (task['status'] != 'completed') ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _editTask(task),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.blue.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.edit,
                                size: 16,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ],
                        // Botón de eliminar (siempre disponible)
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _deleteTask(task),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.red.shade300,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              LucideIcons.trash2,
                              size: 16,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Location and date row
              Row(
                children: [
                  Icon(
                    LucideIcons.mapPin,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  // Location text
                  Expanded(
                    child: Text(
                      _getLocationText(_getTaskLocation(task)) ?? 'Sin ubicación',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Date on the right
                  Text(
                    _formatDate(_getTaskDate(task)),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              // Camera name in second row (only for reports)
              if (_selectedSection == 'remitos' &&
                  task['cameraName'] != null &&
                  task['cameraName'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      LucideIcons.camera,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task['cameraName'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Helper methods for unified task/report handling
  String? _getTaskStatus(Map<String, dynamic> item) {
    return item['status']?.toString();
  }

  String? _getTaskLocation(Map<String, dynamic> item) {
    return item['location']?.toString();
  }

  DateTime? _getTaskDate(Map<String, dynamic> item) {
    final dateValue = item['date'];
    if (dateValue == null) return null;

    try {
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is Map && dateValue['\$date'] != null) {
        return DateTime.parse(dateValue['\$date']);
      }
    } catch (e) {
      // Error parsing date
    }
    return null;
  }

  List<String>? _getTaskImages(Map<String, dynamic> item) {
    final images = item['imagesUrl'];
    if (images is List) {
      return images.map((e) => e.toString()).toList();
    }
    return null;
  }

  String _getTaskDescription(Map<String, dynamic> item) {
    final toDo = item['toDo']?.toString();
    final typeOfWork = item['typeOfWork']?.toString();

    if (toDo != null && toDo.isNotEmpty) {
      return toDo;
    } else if (typeOfWork != null && typeOfWork.isNotEmpty) {
      return typeOfWork;
    }
    return 'Sin descripción';
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getTaskType(Map<String, dynamic> task) {
    // Check if it's a report (remito)
    if (_selectedSection == 'remitos') {
      final typeOfWork = task['typeOfWork']?.toString() ?? '';
      if (typeOfWork.isNotEmpty) {
        return typeOfWork;
      }
      return 'Remito';
    }

    // Extract task type from title or use a default
    final title = task['title']?.toString().toLowerCase() ?? '';
    if (title.contains('preventivo')) {
      return 'Preventivo';
    } else if (title.contains('recambio')) {
      return 'Recambio';
    } else if (title.contains('correctivo')) {
      return 'Correctivo';
    } else if (title.contains('reubicacion') || title.contains('reubicación')) {
      return 'Reubicación';
    } else if (title.contains('retiro de sistema')) {
      return 'Retiro de Sistema';
    } else if (title.contains('instalacion') || title.contains('instalación')) {
      return 'Instalación';
    }
    return 'General';
  }

  Color _getTaskTypeColor(String taskType) {
    switch (taskType) {
      case 'Preventivo':
        return Colors.green.shade700;
      case 'Recambio':
        return Colors.blue;
      case 'Correctivo':
        return Colors.red.shade700;
      case 'Reubicación':
        return Colors.purple;
      case 'Retiro de Sistema':
        return Colors.brown;
      case 'Instalación':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic dateValue) => DataHelpers.formatDate(dateValue);

  String _getTaskTitle(Map<String, dynamic> task) {
    if (_selectedSection == 'remitos') {
      // Para reportes, mostrar el nombre del propietario real del reporte
      final userId = task['userId']?.toString();
      if (userId != null) {
        return _getUserNameById(userId);
      }
      return 'Usuario desconocido';
    }
    return task['title']?.toString() ?? 'Sin título';
  }

  String? _getLocationText(dynamic location) =>
      DataHelpers.getLocationText(location);

  void _showTaskDetail(Map<String, dynamic> task) async {
    final taskToShow = task;
    if (!mounted) return;

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
                _buildDialogHeader(context, taskToShow, isWideScreen),

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
                              _translateStatus(_getTaskStatus(taskToShow)),
                              _getStatusIcon(
                                _translateStatus(_getTaskStatus(taskToShow)),
                              ),
                              _getStatusColorFromText(
                                _translateStatus(_getTaskStatus(taskToShow)),
                              ),
                            ),
                            _buildDetailRow(
                              'Fecha',
                              _formatDate(_getTaskDate(taskToShow)),
                              LucideIcons.calendar,
                              Colors.grey.shade600,
                            ),
                            _buildDetailRow(
                              'Tipo',
                              _getTaskType(taskToShow),
                              LucideIcons.tag,
                              _getTaskTypeColor(_getTaskType(taskToShow)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Sección de ubicación y mapa
                        _buildLocationSection(taskToShow, isWideScreen),

                        if (_selectedSection == 'remitos') ...[
                          const SizedBox(height: 24),

                          // Sección de conectividad y horarios
                          _buildReportDetailsSection(taskToShow),

                          // Sección de información técnica específica
                          if (taskToShow['connectivity'] == 'Fibra óptica' ||
                              taskToShow['connectivity'] == 'Enlace') ...[
                            const SizedBox(height: 24),
                            _buildTechnicalSection(taskToShow),
                          ],

                          // Sección de materiales
                          if (taskToShow['supplies'] != null &&
                              (taskToShow['supplies'] as List).isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _buildSuppliesSection(taskToShow['supplies']),
                          ],

                          // Sección de imágenes
                          if (taskToShow['imagesUrl'] != null &&
                              (taskToShow['imagesUrl'] as List).isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _buildImagesSection(taskToShow['imagesUrl']),
                          ],
                        ] else ...[
                          const SizedBox(height: 24),

                          // Sección de descripción para tareas
                          _buildInfoSection(
                            'Descripción',
                            LucideIcons.fileText,
                            Colors.green,
                            [
                              _buildDescriptionCard(
                                _getTaskDescription(taskToShow),
                              ),
                            ],
                          ),

                          // Imágenes de la tarea
                          if (_getTaskImages(taskToShow) != null &&
                              _getTaskImages(taskToShow)!.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _buildImagesSection(_getTaskImages(taskToShow)!),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                // Botón para marcar como completada (solo si no está completada)
                if (_getTaskStatus(taskToShow) != 'completed') ...[
                  Container(
                    padding: EdgeInsets.all(isWideScreen ? 32 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _completeTask(taskToShow),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Marcar como Completada',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Método para marcar una tarea como completada
  Future<void> _completeTask(Map<String, dynamic> task) async {
    final taskId = task['_id']?.toString();
    if (taskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el ID de la tarea'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await TechHubApiClient.markTaskCompleted(taskId: taskId);

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarea marcada como completada exitosamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Cerrar el modal
          Navigator.of(context).pop();

          // Recargar los datos para reflejar el cambio
          _loadData(refresh: true);
        }
      } else {
        throw Exception(response.error ?? 'Error desconocido');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al completar la tarea: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // New helper methods for improved dialog

  Widget _buildDialogHeader(
    BuildContext context,
    Map<String, dynamic> taskToShow,
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _selectedSection == 'remitos'
                      ? LucideIcons.fileText
                      : LucideIcons.checkSquare,
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
                      _selectedSection == 'remitos'
                          ? 'Detalles del Remito'
                          : 'Detalles de la Tarea',
                      style: TextStyle(
                        fontSize: isWideScreen ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTaskTitle(taskToShow),
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

          // Botones de descarga e impresión para remitos completados
          if (_selectedSection == 'remitos' &&
              taskToShow['status'] == 'completed') ...[
            const SizedBox(height: 16),
            _buildActionButton(
              icon: LucideIcons.download,
              label: 'Descargar PDF',
              onPressed: () => _downloadReportPDF(taskToShow),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.orange.shade600,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
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

  Widget _buildLocationSection(
    Map<String, dynamic> taskToShow,
    bool isWideScreen,
  ) {
    final locationText =
        _getLocationText(_getTaskLocation(taskToShow)) ?? 'Sin ubicación';
    final hasCoordinates = _hasLocationCoordinates(
      _getTaskLocation(taskToShow),
    );

    return _buildInfoSection('Ubicación', LucideIcons.mapPin, Colors.purple, [
      _buildDetailRow(
        'Ubicación',
        locationText,
        LucideIcons.mapPin,
        Colors.purple.shade600,
      ),

      if (_selectedSection == 'remitos' &&
          _selectedStatus == 'completed' &&
          hasCoordinates) ...[
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildMapSection(_getTaskLocation(taskToShow)!),
          ),
        ),
      ],
    ]);
  }

  Widget _buildReportDetailsSection(Map<String, dynamic> taskToShow) {
    List<Widget> details = [];

    if (taskToShow['connectivity'] != null) {
      details.add(
        _buildDetailRow(
          'Conectividad',
          taskToShow['connectivity'].toString(),
          LucideIcons.wifi,
          Colors.teal.shade600,
        ),
      );
    }

    if (taskToShow['cameraName'] != null &&
        taskToShow['cameraName'].toString().isNotEmpty) {
      details.add(
        _buildDetailRow(
          'Cámara',
          taskToShow['cameraName'].toString(),
          LucideIcons.camera,
          Colors.purple.shade600,
        ),
      );
    }

    if (taskToShow['startTime'] != null) {
      details.add(
        _buildDetailRow(
          'Inicio',
          _formatTime(taskToShow['startTime']),
          LucideIcons.play,
          Colors.green.shade600,
        ),
      );
    }

    if (taskToShow['endTime'] != null) {
      details.add(
        _buildDetailRow(
          'Fin',
          _formatTime(taskToShow['endTime']),
          LucideIcons.square,
          Colors.red.shade600,
        ),
      );
    }

    // Tiempo total trabajado
    if (taskToShow['startTime'] != null && taskToShow['endTime'] != null) {
      details.add(
        _buildDetailRow(
          'Tiempo Total',
          DataHelpers.calculateWorkingTime(
            taskToShow['startTime'],
            taskToShow['endTime'],
          ),
          LucideIcons.clock,
          Colors.blue.shade600,
        ),
      );
    }

    if (taskToShow['toDo'] != null &&
        taskToShow['toDo'].toString().isNotEmpty) {
      details.add(_buildDescriptionCard(taskToShow['toDo'].toString()));
    }

    if (details.isEmpty) return const SizedBox.shrink();

    return _buildInfoSection(
      'Detalles del Trabajo',
      LucideIcons.clipboard,
      Colors.teal,
      details,
    );
  }

  Widget _buildTechnicalSection(Map<String, dynamic> taskToShow) {
    List<Widget> technicalDetails = [];

    if (taskToShow['connectivity'] == 'Fibra óptica') {
      if (taskToShow['buffers'] != null) {
        technicalDetails.add(
          _buildDetailRow(
            'Buffers',
            taskToShow['buffers'].toString(),
            LucideIcons.layers,
            Colors.indigo.shade600,
          ),
        );
      }
      if (taskToShow['bufferColor'] != null) {
        technicalDetails.add(
          _buildDetailRow(
            'Color Buffer',
            taskToShow['bufferColor'].toString(),
            LucideIcons.palette,
            Colors.indigo.shade600,
          ),
        );
      }
      if (taskToShow['hairColor'] != null) {
        technicalDetails.add(
          _buildDetailRow(
            'Color Pelo',
            taskToShow['hairColor'].toString(),
            LucideIcons.palette,
            Colors.indigo.shade600,
          ),
        );
      }
      if (taskToShow['db'] != null) {
        technicalDetails.add(
          _buildDetailRow(
            'DB',
            taskToShow['db'].toString(),
            LucideIcons.barChart3,
            Colors.indigo.shade600,
          ),
        );
      }
    } else if (taskToShow['connectivity'] == 'Enlace') {
      if (taskToShow['ap'] != null) {
        technicalDetails.add(
          _buildDetailRow(
            'AP',
            taskToShow['ap'].toString(),
            LucideIcons.radio,
            Colors.indigo.shade600,
          ),
        );
      }
      if (taskToShow['st'] != null) {
        technicalDetails.add(
          _buildDetailRow(
            'ST',
            taskToShow['st'].toString(),
            LucideIcons.satellite,
            Colors.indigo.shade600,
          ),
        );
      }
      if (taskToShow['ccq'] != null) {
        technicalDetails.add(
          _buildDetailRow(
            'CCQ',
            taskToShow['ccq'].toString(),
            LucideIcons.signal,
            Colors.indigo.shade600,
          ),
        );
      }
    }

    if (technicalDetails.isEmpty) return const SizedBox.shrink();

    return _buildInfoSection(
      'Información Técnica',
      LucideIcons.settings,
      Colors.indigo,
      technicalDetails,
    );
  }

  Widget _buildDescriptionCard(String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.fileText, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Descripción',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _translateStatus(String? status) =>
      DataHelpers.translateStatus(status);

  IconData _getStatusIcon(String statusText) {
    if (statusText.toLowerCase().contains('pendiente')) {
      return LucideIcons.clock;
    } else if (statusText.toLowerCase().contains('proceso')) {
      return LucideIcons.play;
    } else if (statusText.toLowerCase().contains('completada')) {
      return LucideIcons.check;
    }
    return LucideIcons.info;
  }

  Color _getStatusColorFromText(String statusText) {
    if (statusText.toLowerCase().contains('pendiente')) {
      return Colors.red;
    } else if (statusText.toLowerCase().contains('proceso')) {
      return Colors.orange;
    } else if (statusText.toLowerCase().contains('completada')) {
      return Colors.green;
    }
    return Colors.grey;
  }

  String _formatTime(dynamic timeValue) => DataHelpers.formatTime(timeValue);

  /// Widget para mostrar la sección de materiales/suministros
  Widget _buildSuppliesSection(List<dynamic> supplies) {
    final List<Widget> materialWidgets = [];

    // Agregar cada material individualmente
    for (int i = 0; i < supplies.length; i++) {
      final material = supplies[i];
      if (material != null) {
        String materialText = '';
        String? quantity;

        // Extraer información del material según su estructura
        if (material is Map<String, dynamic>) {
          // Si tiene materialId, buscar el nombre en el inventario
          if (material['materialId'] != null) {
            final materialId = material['materialId'].toString();
            materialText = _getMaterialNameById(materialId);
          } else if (material['name'] != null) {
            materialText = material['name'].toString();
          } else if (material['material'] != null) {
            materialText = material['material'].toString();
          } else if (material['description'] != null) {
            materialText = material['description'].toString();
          } else {
            materialText = material.toString();
          }

          // Extraer cantidad si está disponible
          if (material['quantity'] != null) {
            quantity = material['quantity'].toString();
          }
        } else {
          materialText = material.toString();
        }

        materialWidgets.add(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.package,
                  size: 16,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    materialText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                if (quantity != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      quantity,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    return _buildInfoSection(
      'Materiales Utilizados (${supplies.length})',
      LucideIcons.package,
      Colors.orange,
      [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Materiales utilizados en este trabajo:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              ...materialWidgets,
            ],
          ),
        ),
      ],
    );
  }

  /// Widget para mostrar la sección de imágenes
  Widget _buildImagesSection(List<dynamic> imagesUrl) {
    final validImages =
        imagesUrl
            .where((url) => url != null && url.toString().isNotEmpty)
            .take(6) // Aumentamos a 6 imágenes
            .toList();

    if (validImages.isEmpty) return const SizedBox.shrink();

    return _buildInfoSection(
      'Imágenes (${validImages.length})',
      LucideIcons.image,
      Colors.blue,
      [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: validImages.length,
          itemBuilder: (context, index) {
            final imageUrl = validImages[index].toString();
            return GestureDetector(
              onTap: () => _showFullScreenImage(context, imageUrl),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        cacheHeight: 300,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                strokeWidth: 2,
                                color: Colors.blue,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade100,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.imageOff,
                                  color: Colors.grey.shade400,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Error',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // Overlay con gradiente
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.2),
                            ],
                          ),
                        ),
                      ),
                      // Icono de expansión
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            LucideIcons.expand,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Mostrar imagen en pantalla completa
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 40,
                    maxHeight: MediaQuery.of(context).size.height - 100,
                  ),
                  child: InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      // Optimizaciones de cache y rendimiento para pantalla completa
                      cacheWidth: 1200,
                      cacheHeight: 1200,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.imageOff,
                                color: Colors.white,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error al cargar la imagen',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToEditReport(Map<String, dynamic> report) {
    final reportId = report['_id']?.toString();
    if (reportId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el ID del reporte'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => CreateReportScreen(
              authManager: widget.authManager,
              existingReportId: reportId,
              isEditingExistingReport: true,
              onNavigateToTab: (int tabIndex) {
                // Pop back to works screen and refresh data
                Navigator.of(context).pop();
                _loadData(refresh: true);
              },
            ),
      ),
    );
  }

  bool _hasLocationCoordinates(String? location) =>
      DataHelpers.hasLocationCoordinates(location);

  Widget _buildMapSection(String location) {
    final parts = location.split(',');
    final lat = double.parse(parts[0].trim());
    final lng = double.parse(parts[1].trim());

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
                color: Colors.purple.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildOptimizedMapWidget(
              lat: lat,
              lng: lng,
              // No pasar el controlador global para evitar conflictos
            ),
          ),
        ),
      ],
    );
  }

  // Widget optimizado para el mapa que previene problemas de cache
  Widget _buildOptimizedMapWidget({
    required double lat,
    required double lng,
    MapController? mapController,
  }) {
    // Si no se proporciona un controlador, crear uno local para evitar conflictos
    final localController = mapController ?? MapController();

    return Stack(
      children: [
        FlutterMap(
          mapController: localController,
          options: MapUtils.createOptimizedMapOptions(lat: lat, lng: lng),
          children: [
            MapUtils.createOptimizedTileLayer(),
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
                      color: Colors.purple.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.4),
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
                      LucideIcons.mapPin,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: () => _copyLocation(context, lat, lng),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600,
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
    );
  }

  Future<void> _copyLocation(
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

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    final reportId = report['_id']?.toString();
    if (reportId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el ID del reporte'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                LucideIcons.trash2,
                color: Colors.red.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text('Eliminar Remito'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Estás seguro de que quieres eliminar este remito?'),
              const SizedBox(height: 8),
              Text(
                'Esta acción no se puede deshacer y eliminará el remito permanentemente.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Mostrar loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text('Eliminando remito...'),
            ],
          ),
        ),
      );

      // Llamar al API para eliminar
      final response = await TechHubApiClient.deleteReport(reportId: reportId);

      // Cerrar loading
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (response.isSuccess) {
        // Mostrar éxito y recargar datos
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Remito eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData(refresh: true);
        }
      } else {
        // Mostrar error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar loading si está abierto
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadReportPDF(Map<String, dynamic> report) async {
    try {
      // Mostrar loading no bloqueante
      final loadingKey = GlobalKey();
      String currentStep = 'Preparando...';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => StatefulBuilder(
              builder:
                  (context, setState) => AlertDialog(
                    key: loadingKey,
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text(
                          'Generando PDF...',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentStep,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Esto puede tomar unos segundos',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
      );

      // Preparar datos para el PDF
      final imageUrls = report['imagesUrl'] ?? [];

      // Usar el nuevo helper que maneja las plataformas correctamente
      final result = await PDFDownloadHelper.generatePDFInBackground(
        data: {
          'report': report,
          'users': _users,
          'imageUrls': imageUrls,
          'inventory': _inventory,
          'recoveredInventory': _recoveredInventory,
        },
      );

      // Cerrar el diálogo de loading
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result['success'] == true) {
        // Mostrar éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                kIsWeb
                    ? 'PDF descargado: ${result['fileName']}'
                    : 'PDF guardado: ${result['fileName']}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action:
                  kIsWeb
                      ? null
                      : SnackBarAction(
                        label: 'Compartir',
                        textColor: Colors.white,
                        onPressed:
                            () => PDFDownloadHelper.sharePDF(
                              bytes: result['bytes'],
                              fileName: result['fileName'],
                            ),
                      ),
            ),
          );
        }
      } else {
        // Mostrar error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generando PDF: ${result['error']}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Error general - cerrar loading si está abierto
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Load teams for dropdown (from camera liable data)
  Future<void> _loadTeams() async {
    if (_isTeamsLoaded) return;

    try {
      final response = await AnalyzerApiClient.getCameras();
      if (response.isSuccess && response.data != null && mounted) {
        // Extract unique liable values from cameras
        final cameras = List<Map<String, dynamic>>.from(response.data!);
        final uniqueLiables = <String>{};

        for (final camera in cameras) {
          final liable = camera['liable']?.toString();
          if (liable != null && liable.isNotEmpty && liable != 'null') {
            uniqueLiables.add(liable);
          }
        }

        // Convert to team format for dropdown
        final teams = uniqueLiables.map((liable) => {
          '_id': liable,
          'name': liable,
        }).toList();

        if (mounted) {
          setState(() {
            _teams = teams;
            _isTeamsLoaded = true;
          });
        }
      } else {
        // Mostrar error si no se pudieron cargar los equipos
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al cargar equipos: ${response.error ?? "Error desconocido"}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Mostrar error de conexión
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Error de conexión al cargar equipos. Verifique su conexión a internet.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Show new task dialog
  void _showNewTaskDialog() async {
    // Load teams if not loaded
    if (!_isTeamsLoaded) {
      await _loadTeams();
    }

    // Clear form
    _taskNameController.clear();
    _taskDescriptionController.clear();
    _taskLocationController.clear();
    _selectedTeamId = null;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Nueva Tarea',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Task Name
                      TextField(
                        controller: _taskNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la tarea',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Task Description
                      TextField(
                        controller: _taskDescriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripción de la tarea',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Location
                      TextField(
                        controller: _taskLocationController,
                        decoration: InputDecoration(
                          labelText: 'Ubicación',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.location_on),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.map),
                            onPressed: () => _showLocationPickerDialog(context, setState),
                            tooltip: 'Seleccionar en mapa',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Team Dropdown
                      if (_isTeamsLoaded && _teams.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTeamId,
                          decoration: const InputDecoration(
                            labelText: 'Equipo responsable',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.group),
                          ),
                          items: _teams.map((team) {
                            return DropdownMenuItem<String>(
                              value: team['_id']?.toString(),
                              child: Text(team['name']?.toString() ?? 'Equipo sin nombre'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTeamId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor selecciona un equipo';
                            }
                            return null;
                          },
                        )
                      else if (!_isTeamsLoaded)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('Cargando equipos desde el sistema de cámaras...'),
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No se pudieron cargar los equipos',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Los equipos se obtienen automáticamente del sistema de cámaras. Verifica tu conexión a internet.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  setState(() {
                                    _isTeamsLoaded = false;
                                  });
                                  await _loadTeams();
                                  if (mounted) {
                                    setState(() {});
                                  }
                                },
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reintentar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: (_isCreatingTask || !_isTeamsLoaded || _teams.isEmpty)
                      ? null
                      : () => _createNewTask(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: _isCreatingTask
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Crear Tarea'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show location picker dialog with map
  void _showLocationPickerDialog(BuildContext context, StateSetter setState) {
    LatLng selectedLocation = LatLng(-34.6037, -58.3816); // Buenos Aires por defecto
    bool hasSelectedLocation = false;

    // Crear un controlador de mapa separado para evitar conflictos
    final MapController locationPickerController = MapController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Seleccionar Ubicación'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Expanded(
                      child: FlutterMap(
                        mapController: locationPickerController,
                        options: MapOptions(
                          initialCenter: selectedLocation,
                          initialZoom: 10,
                          maxZoom: 18.0,
                          minZoom: 5.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                          keepAlive: false,
                          onTap: (tapPosition, point) {
                            setState(() {
                              selectedLocation = point;
                              hasSelectedLocation = true;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: ['a', 'b', 'c'],
                            maxZoom: 18,
                            minZoom: 5,
                          ),
                          if (hasSelectedLocation)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: selectedLocation,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (hasSelectedLocation)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Ubicación seleccionada: ${selectedLocation.latitude.toStringAsFixed(6)}, ${selectedLocation.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Dispose del controlador antes de cerrar
                    MapUtils.safeDisposeMapController(locationPickerController);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: hasSelectedLocation ? () {
                    _taskLocationController.text = '${selectedLocation.latitude},${selectedLocation.longitude}';
                    // Dispose del controlador antes de cerrar
                    MapUtils.safeDisposeMapController(locationPickerController);
                    Navigator.of(context).pop();
                  } : null,
                  child: const Text('Seleccionar'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Asegurar que el controlador se dispose cuando se cierra el diálogo
      MapUtils.safeDisposeMapController(locationPickerController);
    });
  }

  // Create new task
  Future<void> _createNewTask() async {
    if (_taskNameController.text.trim().isEmpty ||
        _selectedTeamId == null ||
        _taskLocationController.text.trim().isEmpty) {

      String errorMessage = 'Por favor complete todos los campos requeridos:';
      List<String> missingFields = [];

      if (_taskNameController.text.trim().isEmpty) {
        missingFields.add('Nombre de la tarea');
      }
      if (_selectedTeamId == null) {
        missingFields.add('Equipo responsable');
      }
      if (_taskLocationController.text.trim().isEmpty) {
        missingFields.add('Ubicación');
      }

      if (missingFields.isNotEmpty) {
        errorMessage += '\n• ${missingFields.join('\n• ')}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isCreatingTask = true;
    });

    try {
      final response = await TechHubApiClient.createTask(
        team: _selectedTeamId!,
        title: _taskNameController.text.trim(),
        location: _taskLocationController.text.trim(),
        toDo: _taskDescriptionController.text.trim(),
      );

      if (response.isSuccess) {
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarea creada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );

          // Refresh data
          _loadData(refresh: true);
        }
      } else {
        throw Exception(response.error ?? 'Error desconocido');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear la tarea: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingTask = false;
        });
      }
    }
  }

  // Editar tarea (solo para equipo ET y tareas no completadas)
  Future<void> _editTask(Map<String, dynamic> task) async {
    final taskId = task['_id']?.toString();
    if (taskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el ID de la tarea'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Precargar valores actuales
    _taskNameController.text = task['title']?.toString() ?? '';
    _taskDescriptionController.text = task['toDo']?.toString() ?? '';
    _taskLocationController.text = task['location']?.toString() ?? '';
    _selectedTeamId = task['team']?.toString();

    // Mostrar diálogo de edición
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(LucideIcons.edit, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  const Text('Editar Tarea'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre de la tarea
                    const Text(
                      'Nombre de la tarea',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _taskNameController,
                      decoration: InputDecoration(
                        hintText: 'Ingrese el nombre de la tarea',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    const Text(
                      'Descripción',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _taskDescriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ingrese la descripción de la tarea',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Equipo responsable
                    const Text(
                      'Equipo responsable',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTeamId,
                      decoration: InputDecoration(
                        hintText: 'Seleccione un equipo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: _teams.map((team) {
                        return DropdownMenuItem<String>(
                          value: team['_id']?.toString(),
                          child: Text(team['name']?.toString() ?? 'Sin nombre'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTeamId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ubicación
                    const Text(
                      'Ubicación',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _taskLocationController,
                            decoration: InputDecoration(
                              hintText: 'Ingrese la ubicación',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _showLocationPickerDialog(context, setState),
                          icon: Icon(LucideIcons.mapPin, color: Colors.blue.shade600),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _isCreatingTask ? null : () => _updateTask(taskId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isCreatingTask
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Eliminar tarea (solo para equipo ET)
  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final taskId = task['_id']?.toString();
    if (taskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró el ID de la tarea'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: Colors.red.shade600),
              const SizedBox(width: 12),
              const Text('Eliminar Tarea'),
            ],
          ),
          content: const Text(
            '¿Estás seguro de que quieres eliminar esta tarea? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Mostrar loading
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Eliminando tarea...'),
            ],
          ),
        ),
      );

      // Llamar al API para eliminar
      final response = await TechHubApiClient.deleteTask(taskId: taskId);

      // Cerrar loading
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (response.isSuccess) {
        // Mostrar éxito y recargar datos
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarea eliminada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );

          // Mostrar indicador de recarga
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Actualizando lista...'),
                duration: Duration(seconds: 1),
              ),
            );
          }

          // Recargar los datos (sin cerrar modal ya que se elimina desde la tarjeta)
          try {
            await _loadData(refresh: true);
          } catch (e) {
            // Si hay error en refresh, intentar recargar sin refresh para mantener datos existentes
            if (mounted) {
              try {
                await _loadData(refresh: false);
              } catch (e2) {
                // Si también falla, mostrar error
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al recargar datos después de eliminar: $e2'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          }
        }
      } else {
        // Mostrar error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar tarea: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar loading si está abierto
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Actualizar tarea
  Future<void> _updateTask(String taskId) async {
    if (_taskNameController.text.trim().isEmpty ||
        _selectedTeamId == null ||
        _taskLocationController.text.trim().isEmpty) {

      String errorMessage = 'Por favor complete todos los campos requeridos:';
      List<String> missingFields = [];

      if (_taskNameController.text.trim().isEmpty) {
        missingFields.add('Nombre de la tarea');
      }
      if (_selectedTeamId == null) {
        missingFields.add('Equipo responsable');
      }
      if (_taskLocationController.text.trim().isEmpty) {
        missingFields.add('Ubicación');
      }

      if (missingFields.isNotEmpty) {
        errorMessage += '\n• ${missingFields.join('\n• ')}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isCreatingTask = true;
    });

    try {
      final response = await TechHubApiClient.editTask(
        taskId: taskId,
        team: _selectedTeamId!,
        title: _taskNameController.text.trim(),
        location: _taskLocationController.text.trim(),
        toDo: _taskDescriptionController.text.trim(),
      );

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarea actualizada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
          // Recargar los datos
          _loadData(refresh: true);
        }
      } else {
        throw Exception(response.error ?? 'Error desconocido');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar tarea: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingTask = false;
        });
      }
    }
  }
}
