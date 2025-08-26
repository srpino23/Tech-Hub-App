import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import '../auth_manager.dart';
import '../services/techhub_api_client.dart';
import '../services/api_response.dart';
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

  // Cache para materiales para evitar múltiples llamadas
  final Map<String, Map<String, dynamic>?> _materialsCache = {};
  
  // Cache para usuarios para evitar múltiples llamadas
  List<Map<String, dynamic>> _users = [];
  bool _isUsersLoaded = false;

  // Cache para inventarios completos (solo se cargan una vez)
  List<Map<String, dynamic>>? _mainInventoryCache;
  List<Map<String, dynamic>>? _recoveredInventoryCache;
  bool _inventoriesLoaded = false;

  // Pagination
  int _currentTasksPage = 1;
  int _currentReportsPage = 1;
  bool _hasMoreTasks = true;
  bool _hasMoreReports = true;
  int _tasksTotal = 0;
  int _reportsTotal = 0;
  int _tasksTotalPages = 1;
  int _reportsTotalPages = 1;
  final int _pageSize = 10;
  bool _showPaginationButtons = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    if (refresh) {
      _currentTasksPage = 1;
      _currentReportsPage = 1;
      _hasMoreTasks = true;
      _hasMoreReports = true;
      _tasks.clear();
      _reports.clear();
    }
    await Future.wait([_loadUsers(), _loadTasks(), _loadReports()]);
  }

  Future<void> _loadTasks({bool loadMore = false}) async {
    try {
      if (!mounted) return;

      if (!loadMore && !_hasMoreTasks) return;

      setState(() {
        if (!loadMore) {
          _isLoading = true;
        }
        _isLoadingTasks = true;
      });

      final isET = await _isETTeam();
      
      late ApiResponse<Map<String, dynamic>> response;
      
      if (isET) {
        // ET team can see all tasks
        response = await TechHubApiClient.getAllTasks(
          page: loadMore ? _currentTasksPage + 1 : _currentTasksPage,
          limit: _pageSize,
        );
      } else {
        // Regular teams see only their tasks
        final teamId = await _getTeamId();
        if (teamId == null) {
          throw Exception('No se pudo obtener el ID del equipo');
        }

        response = await TechHubApiClient.getTasksByTeam(
          teamId: teamId,
          page: loadMore ? _currentTasksPage + 1 : _currentTasksPage,
          limit: _pageSize,
        );
      }

      if (!mounted) return;

      if (!response.isSuccess) {
        throw Exception(response.error ?? 'Failed to load tasks');
      }

      final List<Map<String, dynamic>> newTasks = List<Map<String, dynamic>>.from(response.data!['tasks']);
      final Map<String, dynamic> pagination = response.data!['pagination'];
      final int total = pagination['totalItems'];
      final int totalPages = pagination['totalPages'];
      final bool hasNextPage = pagination['hasNextPage'];

      if (mounted) {
        setState(() {
          if (loadMore) {
            _tasks.addAll(newTasks);
            _currentTasksPage++;
          } else {
            _tasks = newTasks;
          }
          _tasksTotal = total;
          _tasksTotalPages = totalPages;
          _hasMoreTasks = hasNextPage;
          _filterTasks();
          _isLoadingTasks = false;
          if (!_isLoadingReports) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
          if (!_isLoadingReports) {
            _isLoading = false;
          }
        });
      }
      if (mounted) {
        _showGlobalError(
          'Error de conexión al cargar tareas. Verifique su conexión a internet.',
        );
      }
    }
  }

  Future<void> _loadReports({bool loadMore = false}) async {
    try {
      if (!mounted) return;

      if (!loadMore && !_hasMoreReports) return;

      setState(() {
        _isLoadingReports = true;
      });

      final isET = await _isETTeam();
      
      late ApiResponse<Map<String, dynamic>> response;
      
      if (isET) {
        // ET team can see all reports
        response = await TechHubApiClient.getAllReports(
          page: loadMore ? _currentReportsPage + 1 : _currentReportsPage,
          limit: _pageSize,
        );
      } else {
        // Regular teams see only their reports
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
          page: loadMore ? _currentReportsPage + 1 : _currentReportsPage,
          limit: _pageSize,
        );
      }

      if (!mounted) return;

      if (!response.isSuccess) {
        throw Exception(response.error ?? 'Failed to load reports');
      }

      final List<Map<String, dynamic>> allReports = List<Map<String, dynamic>>.from(response.data!['reports']);
      final Map<String, dynamic> pagination = response.data!['pagination'];
      final int total = pagination['totalItems'];
      final int totalPages = pagination['totalPages'];
      final bool hasNextPage = pagination['hasNextPage'];

      // Filtrar solo los remitos del usuario actual para equipos no-ET
      List<Map<String, dynamic>> filteredReports;
      
      if (isET) {
        // ET team sees all reports
        filteredReports = allReports;
      } else {
        // Regular teams see only their user's reports
        final userId = widget.authManager.userId;
        filteredReports = allReports.where((report) {
          return report['userId'] != null &&
              report['userId'].toString() == userId.toString();
        }).toList();
      }

      if (mounted) {
        setState(() {
          if (loadMore) {
            _reports.addAll(filteredReports);
            _currentReportsPage++;
          } else {
            _reports = filteredReports;
          }
          _reportsTotal = total;
          _reportsTotalPages = totalPages;
          _hasMoreReports = hasNextPage;
          _filterTasks();
          _isLoadingReports = false;
          if (!_isLoadingTasks) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReports = false;
          if (!_isLoadingTasks) {
            _isLoading = false;
          }
        });
      }
      if (mounted) {
        _showGlobalError(
          'Error de conexión al cargar remitos. Verifique su conexión a internet.',
        );
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

  Future<void> _loadUsers() async {
    if (_isUsersLoaded) return; // Ya están cargados
    
    try {
      final response = await TechHubApiClient.getUsers();
      
      if (response.isSuccess && response.data != null) {
        _users = response.data!;
        _isUsersLoaded = true;
      }
    } catch (e) {
      // Silenciar errores de carga de usuarios para no interrumpir la funcionalidad principal
      debugPrint('Error loading users: $e');
    }
  }

  String _getUserNameById(String userId) {
    final user = _users.firstWhere(
      (user) => user['_id']?.toString() == userId,
      orElse: () => <String, dynamic>{},
    );
    
    if (user.isNotEmpty) {
      final name = user['name']?.toString() ?? '';
      final surname = user['surname']?.toString() ?? '';
      return '$name $surname'.trim();
    }
    
    return 'Usuario desconocido';
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
      _filteredTasks = _tasks.where((task) {
        final matchesStatus = task['status'] == _selectedStatus;
        final matchesSearch = _searchQuery.isEmpty || 
            (task['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (task['toDo']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        return matchesStatus && matchesSearch;
      }).toList();
    } else if (_selectedSection == 'remitos') {
      _filteredTasks = _reports.where((report) {
        final matchesStatus = report['status'] == _selectedStatus;
        final matchesSearch = _searchQuery.isEmpty || 
            (report['typeOfWork']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (report['toDo']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        return matchesStatus && matchesSearch;
      }).toList();
    }
  }

  void _onStatusChanged(String status) {
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
      _filterTasks();
    });

    if (_searchQuery.isNotEmpty) {
      _searchData();
    }
  }

  void _loadMore() {
    if (_selectedSection == 'tareas' && _hasMoreTasks && !_isLoadingTasks) {
      _loadTasks(loadMore: true);
    } else if (_selectedSection == 'remitos' &&
        _hasMoreReports &&
        !_isLoadingReports) {
      _loadReports(loadMore: true);
    }
  }

  void _goToNextPage() {
    if (_selectedSection == 'tareas') {
      if (_currentTasksPage < _tasksTotalPages && !_isLoadingTasks) {
        setState(() {
          _currentTasksPage++;
          _tasks.clear();
        });
        _loadTasks();
      }
    } else {
      if (_currentReportsPage < _reportsTotalPages && !_isLoadingReports) {
        setState(() {
          _currentReportsPage++;
          _reports.clear();
        });
        _loadReports();
      }
    }
  }

  void _goToPreviousPage() {
    if (_selectedSection == 'tareas') {
      if (_currentTasksPage > 1 && !_isLoadingTasks) {
        setState(() {
          _currentTasksPage--;
          _tasks.clear();
        });
        _loadTasks();
      }
    } else {
      if (_currentReportsPage > 1 && !_isLoadingReports) {
        setState(() {
          _currentReportsPage--;
          _reports.clear();
        });
        _loadReports();
      }
    }
  }

  void _goToFirstPage() {
    if (_selectedSection == 'tareas') {
      if (_currentTasksPage != 1 && !_isLoadingTasks) {
        setState(() {
          _currentTasksPage = 1;
          _tasks.clear();
        });
        _loadTasks();
      }
    } else {
      if (_currentReportsPage != 1 && !_isLoadingReports) {
        setState(() {
          _currentReportsPage = 1;
          _reports.clear();
        });
        _loadReports();
      }
    }
  }

  void _goToLastPage() {
    if (_selectedSection == 'tareas') {
      if (_currentTasksPage != _tasksTotalPages && !_isLoadingTasks) {
        setState(() {
          _currentTasksPage = _tasksTotalPages;
          _tasks.clear();
        });
        _loadTasks();
      }
    } else {
      if (_currentReportsPage != _reportsTotalPages && !_isLoadingReports) {
        setState(() {
          _currentReportsPage = _reportsTotalPages;
          _reports.clear();
        });
        _loadReports();
      }
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    return Column(
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
                        : 'Buscar remitos...',
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
          ),
        ),
        // Results info and pagination controls
        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            children: [
              // Pagination mode toggle
              Row(
                children: [
                  Text(
                    'Modo de paginación:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showPaginationButtons = !_showPaginationButtons;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _showPaginationButtons
                                ? Colors.orange.shade100
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              _showPaginationButtons
                                  ? Colors.orange
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showPaginationButtons
                                ? LucideIcons.mousePointer
                                : LucideIcons.arrowDown,
                            size: 14,
                            color:
                                _showPaginationButtons
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showPaginationButtons ? 'Botones' : 'Scroll',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _showPaginationButtons
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                  if (_showPaginationButtons && _searchQuery.isEmpty) ...[
                    Text(
                      'Página ${_selectedSection == 'tareas' ? _currentTasksPage : _currentReportsPage} de ${_selectedSection == 'tareas' ? _tasksTotalPages : _reportsTotalPages}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else if (_filteredTasks.isNotEmpty) ...[
                    Text(
                      'Mostrando ${_filteredTasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
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
        // Pagination buttons (when enabled)
        if (_showPaginationButtons &&
            _searchQuery.isEmpty &&
            _filteredTasks.isNotEmpty)
          _buildPaginationControls(),
      ],
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

    final bool hasMore =
        _selectedSection == 'tareas' ? _hasMoreTasks : _hasMoreReports;
    final bool isLoadingMore =
        isCurrentSectionLoading && _filteredTasks.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => _loadData(refresh: true),
      color: Colors.orange,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child:
            _showPaginationButtons
                ? ListView.builder(
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
                )
                : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (!isLoadingMore &&
                        hasMore &&
                        _searchQuery.isEmpty &&
                        scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 200) {
                      _loadMore();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount:
                        _filteredTasks.length +
                        (hasMore && _searchQuery.isEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _filteredTasks.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.orange,
                            ),
                          ),
                        );
                      }

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
                  // Task type badge
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
                  Expanded(
                    child: Text(
                      _getLocationText(_getTaskLocation(task)) ??
                          'Sin ubicación',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
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
    } else if (title.contains('reubicacion') ||
        title.contains('reubicación')) {
      return 'Reubicación';
    } else if (title.contains('retiro de sistema')) {
      return 'Retiro de Sistema';
    } else if (title.contains('instalacion') ||
        title.contains('instalación')) {
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

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Sin fecha';
    try {
      DateTime date;
      if (dateValue is DateTime) {
        date = dateValue;
      } else if (dateValue is Map && dateValue['\$date'] != null) {
        date = DateTime.parse(dateValue['\$date']);
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Sin fecha';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Hoy';
      } else if (difference.inDays == 1) {
        return 'Ayer';
      } else if (difference.inDays < 7) {
        return 'Hace ${difference.inDays} días';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Sin fecha';
    }
  }

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

  String? _getLocationText(dynamic location) {
    if (location == null) return null;

    final locationStr = location.toString();
    // Check if it's coordinates (contains comma and numbers)
    if (locationStr.contains(',') && locationStr.contains('-')) {
      final parts = locationStr.split(',');
      if (parts.length == 2) {
        try {
          final lat = double.parse(parts[0].trim());
          final lng = double.parse(parts[1].trim());
          return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        } catch (e) {
          return locationStr;
        }
      }
    }
    return locationStr;
  }

  void _showTaskDetail(Map<String, dynamic> task) async {
    // Para esta implementación simplificada, usamos directamente los datos disponibles
    // ya que la nueva API no tiene un endpoint específico para obtener detalles completos
    final taskToShow = task;

    if (!mounted) return;

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
            height:
                MediaQuery.of(context).size.height *
                0.8, // Altura máxima del 80%
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 32,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
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
            child: Column(
              children: [
                // Header fijo
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getTaskTitle(taskToShow),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                ),
                // Contenido scrolleable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTaskInfoRow(
                          'Estado',
                          _translateStatus(_getTaskStatus(taskToShow)),
                        ),
                        _buildTaskInfoRow(
                          'Fecha',
                          _formatDate(_getTaskDate(taskToShow)),
                        ),
                        _buildTaskInfoRow('Tipo', _getTaskType(taskToShow)),
                        _buildTaskInfoRow(
                          'Ubicación',
                          _getLocationText(_getTaskLocation(taskToShow)) ??
                              'Sin ubicación',
                        ),
                        if (_selectedSection == 'remitos') ...[
                          // Información específica de remitos
                          if (taskToShow['connectivity'] != null)
                            _buildTaskInfoRow(
                              'Conectividad',
                              taskToShow['connectivity'].toString(),
                            ),
                          if (taskToShow['startTime'] != null)
                            _buildTaskInfoRow(
                              'Inicio',
                              _formatTime(taskToShow['startTime']),
                            ),
                          if (taskToShow['endTime'] != null)
                            _buildTaskInfoRow(
                              'Fin',
                              _formatTime(taskToShow['endTime']),
                            ),
                          if (taskToShow['toDo'] != null &&
                              taskToShow['toDo'].toString().isNotEmpty)
                            _buildTaskInfoRow('Descripción', taskToShow['toDo'].toString()),

                          // Información específica según tipo de conectividad
                          if (taskToShow['connectivity'] == 'Fibra óptica') ...[
                            if (taskToShow['buffers'] != null)
                              _buildTaskInfoRow('Buffers', taskToShow['buffers'].toString()),
                            if (taskToShow['bufferColor'] != null)
                              _buildTaskInfoRow(
                                'Color Buffer',
                                taskToShow['bufferColor'].toString(),
                              ),
                            if (taskToShow['hairColor'] != null)
                              _buildTaskInfoRow(
                                'Color Pelo',
                                taskToShow['hairColor'].toString(),
                              ),
                            if (taskToShow['db'] != null)
                              _buildTaskInfoRow('DB', taskToShow['db'].toString()),
                          ] else if (taskToShow['connectivity'] == 'Enlace') ...[
                            if (taskToShow['ap'] != null)
                              _buildTaskInfoRow('AP', taskToShow['ap'].toString()),
                            if (taskToShow['st'] != null)
                              _buildTaskInfoRow('ST', taskToShow['st'].toString()),
                            if (taskToShow['ccq'] != null)
                              _buildTaskInfoRow('CCQ', taskToShow['ccq'].toString()),
                          ],

                          // Materiales utilizados
                          if (taskToShow['supplies'] != null &&
                              (taskToShow['supplies'] as List).isNotEmpty)
                            _buildSuppliesSection(taskToShow['supplies']),

                          // Imágenes
                          if (taskToShow['imagesUrl'] != null &&
                              (taskToShow['imagesUrl'] as List).isNotEmpty)
                            _buildImagesSection(taskToShow['imagesUrl']),
                        ] else ...[
                          // Para tareas normales
                          _buildTaskInfoRow(
                            'Descripción',
                            _getTaskDescription(taskToShow),
                          ),
                          // Imágenes de la tarea
                          if (_getTaskImages(taskToShow) != null &&
                              _getTaskImages(taskToShow)!.isNotEmpty)
                            _buildImagesSection(_getTaskImages(taskToShow)!),
                        ],
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

  Widget _buildTaskInfoRow(String label, String value) {
    IconData icon;
    Color iconColor;

    switch (label.toLowerCase()) {
      case 'estado':
        icon = _getStatusIcon(value);
        iconColor = _getStatusColorFromText(value);
        break;
      case 'descripción':
        icon = LucideIcons.fileText;
        iconColor = Colors.grey;
        break;
      case 'ubicación':
        icon = LucideIcons.mapPin;
        iconColor = Colors.grey;
        break;
      case 'fecha':
        icon = LucideIcons.calendar;
        iconColor = Colors.grey;
        break;
      case 'tipo':
        icon = LucideIcons.tag;
        iconColor = Colors.grey;
        break;
      default:
        icon = LucideIcons.info;
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

  String _translateStatus(String? status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'in_progress':
        return 'En Proceso';
      case 'completed':
        return 'Completada';
      default:
        return 'Desconocido';
    }
  }

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

  String _formatTime(dynamic timeValue) {
    if (timeValue == null) return 'N/A';
    try {
      DateTime time;
      if (timeValue is DateTime) {
        time = timeValue;
      } else if (timeValue is String) {
        time = DateTime.parse(timeValue);
      } else if (timeValue is Map && timeValue['\$date'] != null) {
        time = DateTime.parse(timeValue['\$date']);
      } else {
        return 'N/A';
      }

      // Formato con fecha y hora
      final dateStr =
          '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
      final timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      return '$dateStr $timeStr';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildPaginationControls() {
    final currentPage =
        _selectedSection == 'tareas' ? _currentTasksPage : _currentReportsPage;
    final totalPages =
        _selectedSection == 'tareas' ? _tasksTotalPages : _reportsTotalPages;
    final isLoading =
        _selectedSection == 'tareas' ? _isLoadingTasks : _isLoadingReports;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // First page button
          _buildPaginationButton(
            icon: LucideIcons.chevronFirst,
            onPressed: currentPage > 1 && !isLoading ? _goToFirstPage : null,
            tooltip: 'Primera página',
          ),
          const SizedBox(width: 8),
          // Previous page button
          _buildPaginationButton(
            icon: LucideIcons.chevronLeft,
            onPressed: currentPage > 1 && !isLoading ? _goToPreviousPage : null,
            tooltip: 'Página anterior',
          ),
          const SizedBox(width: 16),
          // Page info
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                '$currentPage / $totalPages',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          const SizedBox(width: 16),
          // Next page button
          _buildPaginationButton(
            icon: LucideIcons.chevronRight,
            onPressed:
                currentPage < totalPages && !isLoading ? _goToNextPage : null,
            tooltip: 'Página siguiente',
          ),
          const SizedBox(width: 8),
          // Last page button
          _buildPaginationButton(
            icon: LucideIcons.chevronLast,
            onPressed:
                currentPage < totalPages && !isLoading ? _goToLastPage : null,
            tooltip: 'Última página',
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton({
    required IconData icon,
    VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                onPressed != null ? Colors.orange.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  onPressed != null
                      ? Colors.orange.shade200
                      : Colors.grey.shade200,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color:
                onPressed != null
                    ? Colors.orange.shade700
                    : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  /// Widget para mostrar la sección de materiales/suministros
  Widget _buildSuppliesSection(List<dynamic> supplies) {
    // Cargar todos los materiales una sola vez
    final Future<List<Map<String, dynamic>>> allMaterialsFuture =
        _loadAllSuppliesMaterials(supplies);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.package,
                size: 16,
                color: Colors.orange.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Materiales utilizados:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: allMaterialsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        color: Colors.orange,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Text(
                    'Error al cargar materiales',
                    style: TextStyle(color: Colors.red.shade600, fontSize: 13),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(
                    'No se encontraron materiales',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  );
                }

                final materialsData = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      materialsData.map((materialData) {
                        final materialName =
                            materialData['name'] ?? 'Material desconocido';
                        final quantity = materialData['quantity'] ?? '0';
                        final isRecovered =
                            materialData['isRecovered'] ?? false;
                        final status = materialData['status'] ?? 'nuevo';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(
                                isRecovered
                                    ? LucideIcons.recycle
                                    : LucideIcons.box,
                                size: 14,
                                color:
                                    isRecovered
                                        ? Colors.green.shade600
                                        : Colors.orange.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      materialName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    if (isRecovered && status != 'nuevo')
                                      Text(
                                        'Material $status',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isRecovered)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Reutilizado',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Cant: $quantity',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Widget para mostrar la sección de imágenes
  Widget _buildImagesSection(List<dynamic> imagesUrl) {
    final validImages =
        imagesUrl
            .where((url) => url != null && url.toString().isNotEmpty)
            .take(4) // Máximo 4 imágenes
            .toList();

    if (validImages.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.image, size: 16, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                'Imágenes (${validImages.length}):',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: validImages.length,
              itemBuilder: (context, index) {
                final imageUrl = validImages[index].toString();
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < validImages.length - 1 ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => _showFullScreenImage(context, imageUrl),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Image.network(
                              imageUrl,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              // Optimizaciones de cache para thumbnails
                              cacheWidth: 240, // 2x para alta densidad
                              cacheHeight: 240,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                    strokeWidth: 2,
                                    color: Colors.blue,
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
                            // Overlay para indicar que se puede tocar
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  LucideIcons.expand,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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

  /// Carga los inventarios una sola vez para optimizar las búsquedas
  Future<void> _loadInventories() async {
    if (_inventoriesLoaded) return;

    try {
      // Cargar ambos inventarios en paralelo
      final results = await Future.wait([
        TechHubApiClient.getInventory(),
        TechHubApiClient.getRecoveredInventory(),
      ]);

      final mainResponse = results[0];
      final recoveredResponse = results[1];

      if (mainResponse.isSuccess && mainResponse.data != null) {
        _mainInventoryCache = List<Map<String, dynamic>>.from(
          mainResponse.data!,
        );
      }

      if (recoveredResponse.isSuccess && recoveredResponse.data != null) {
        _recoveredInventoryCache = List<Map<String, dynamic>>.from(
          recoveredResponse.data!,
        );
      }

      _inventoriesLoaded = true;
    } catch (e) {
      // Error loading inventories, will retry next time
    }
  }

  /// Carga todos los detalles de materiales de suministros de una vez
  Future<List<Map<String, dynamic>>> _loadAllSuppliesMaterials(
    List<dynamic> supplies,
  ) async {
    // Cargar inventarios si no están cargados
    await _loadInventories();

    final List<Map<String, dynamic>> materialsData = [];

    for (var supply in supplies) {
      final materialId = supply['materialId']?.toString() ?? '';
      final quantity = supply['quantity']?.toString() ?? '0';

      if (materialId.isEmpty) continue;

      // Buscar en cache primero
      if (_materialsCache.containsKey(materialId)) {
        final cachedMaterial = _materialsCache[materialId];
        if (cachedMaterial != null) {
          materialsData.add({...cachedMaterial, 'quantity': quantity});
        }
        continue;
      }

      // Buscar en inventario recuperado
      Map<String, dynamic>? materialDetails;
      if (_recoveredInventoryCache != null) {
        for (var recoveredMaterial in _recoveredInventoryCache!) {
          if (recoveredMaterial['_id']?.toString() == materialId) {
            materialDetails = {
              'name': recoveredMaterial['name']?.toString() ?? 'Sin nombre',
              'isRecovered': true,
              'status': 'recuperado',
              'originalMaterialId':
                  recoveredMaterial['originalMaterialId']?.toString(),
              'quantity': quantity,
            };
            break;
          }
        }
      }

      // Si no se encontró en recuperado, buscar en inventario principal
      if (materialDetails == null && _mainInventoryCache != null) {
        for (var mainMaterial in _mainInventoryCache!) {
          if (mainMaterial['_id']?.toString() == materialId) {
            materialDetails = {
              'name': mainMaterial['name']?.toString() ?? 'Sin nombre',
              'isRecovered': false,
              'status': 'nuevo',
              'quantity': quantity,
            };
            break;
          }
        }
      }

      // Cachear y agregar resultado
      if (materialDetails != null) {
        _materialsCache[materialId] = Map<String, dynamic>.from(materialDetails)
          ..remove('quantity');
        materialsData.add(materialDetails);
      } else {
        // Material no encontrado
        _materialsCache[materialId] = null;
        materialsData.add({
          'name': 'Material no encontrado (ID: $materialId)',
          'isRecovered': false,
          'status': 'desconocido',
          'quantity': quantity,
        });
      }
    }

    return materialsData;
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
        builder: (context) => CreateReportScreen(
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
}
