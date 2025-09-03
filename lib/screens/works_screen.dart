import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../auth_manager.dart';
import '../services/techhub_api_client.dart';
import '../services/api_response.dart';
import '../utils/pdf_download_helper.dart';
import 'create_report_screen.dart';

// Static helper function for PDF generation
String _extractUserNameStatic(Map<String, dynamic> user) {
  final combinations = [
    ['fullName'],
    ['firstName', 'lastName'],
    ['name', 'surname'],
    ['nombre', 'apellido'],
    ['first_name', 'last_name'],
  ];

  for (final combo in combinations) {
    final parts = combo
        .map((field) => user[field]?.toString().trim() ?? '')
        .where((part) => part.isNotEmpty);
    if (parts.length == combo.length) {
      return parts.join(' ');
    }
  }

  final name = user['name']?.toString().trim();
  return name?.isNotEmpty == true ? name! : 'Desconocido';
}

Future<pw.Document> _generateReportPDFStatic(Map<String, dynamic> data) async {
  final report = data['report'] as Map<String, dynamic>;
  final users = data['users'] as List<Map<String, dynamic>>;
  final imageBytes = data['imageBytes'] as List<List<int>>?;

  final pdf = pw.Document();

  // Helper function to get user name
  String getUserName(String? userId) {
    if (userId == null) return 'Desconocido';
    final user = users.firstWhere(
      (user) =>
          user['userId']?.toString() == userId ||
          user['_id']?.toString() == userId,
      orElse: () => <String, dynamic>{},
    );

    return user.isNotEmpty ? _extractUserNameStatic(user) : 'Desconocido';
  }

  // Preparar widgets para el PDF
  final List<pw.Widget> pdfWidgets = [
    // Header del documento
    _buildPDFHeader(report, getUserName),
    pw.SizedBox(height: 20),

    // Información general
    _buildPDFInfoSection('Información General', [
      _buildPDFInfoRow(
        'Usuario',
        getUserName(report['userId']?.toString() ?? ''),
      ),
      _buildPDFInfoRow(
        'Estado',
        _translateStatus(report['status']?.toString()),
      ),
      _buildPDFInfoRow(
        'Tipo de Trabajo',
        report['typeOfWork']?.toString() ?? 'N/A',
      ),
      _buildPDFInfoRow('Fecha de Inicio', _formatTime(report['startTime'])),
      _buildPDFInfoRow('Fecha de Fin', _formatTime(report['endTime'])),
      _buildPDFInfoRow(
        'Conectividad',
        report['connectivity']?.toString() ?? 'N/A',
      ),
    ]),
    pw.SizedBox(height: 20),
  ];

  // Ubicación
  if (report['location'] != null) {
    pdfWidgets.addAll([
      _buildPDFInfoSection('Ubicación', [
        _buildPDFInfoRow(
          'Coordenadas',
          _getLocationText(report['location']) ?? 'N/A',
        ),
      ]),
      pw.SizedBox(height: 20),
    ]);
  }

  // Descripción del trabajo
  if (report['toDo'] != null && report['toDo'].toString().isNotEmpty) {
    pdfWidgets.addAll([
      _buildPDFInfoSection('Trabajo Realizado', [
        pw.Paragraph(
          text: report['toDo'].toString(),
          style: const pw.TextStyle(fontSize: 12),
        ),
      ]),
      pw.SizedBox(height: 20),
    ]);
  }

  // Información técnica
  if (report['connectivity'] == 'Fibra óptica' ||
      report['connectivity'] == 'Enlace') {
    pdfWidgets.addAll([
      _buildPDFTechnicalSection(report),
      pw.SizedBox(height: 20),
    ]);
  }

  // Materiales utilizados
  if (report['supplies'] != null && (report['supplies'] as List).isNotEmpty) {
    pdfWidgets.addAll([
      _buildPDFMaterialsSimpleSection(report['supplies']),
      pw.SizedBox(height: 20),
    ]);
  }

  // Fotos - usar imágenes pre-descargadas
  if (imageBytes != null && imageBytes.isNotEmpty) {
    pdfWidgets.add(_buildPDFPhotosSection(imageBytes));
  }

  // Build PDF content
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) => pdfWidgets,
    ),
  );

  return pdf;
}

// Helper functions for PDF sections
pw.Widget _buildPDFHeader(
  Map<String, dynamic> report,
  String Function(String?) getUserName,
) {
  return pw.Header(
    level: 0,
    child: pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'REMITO DE TRABAJO',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'ID: ${report['_id']?.toString() ?? 'N/A'}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
                ),
              ],
            ),
          ),
          pw.Text(
            DateTime.now().toString().split('.')[0],
            style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _buildPDFTechnicalSection(Map<String, dynamic> report) {
  List<pw.Widget> technicalInfo = [];

  if (report['connectivity'] == 'Fibra óptica') {
    if (report['db'] != null) {
      technicalInfo.add(_buildPDFInfoRow('DB', report['db'].toString()));
    }
    if (report['buffers'] != null) {
      technicalInfo.add(
        _buildPDFInfoRow('Buffers', report['buffers'].toString()),
      );
    }
    if (report['bufferColor'] != null) {
      technicalInfo.add(
        _buildPDFInfoRow('Color Buffer', report['bufferColor'].toString()),
      );
    }
    if (report['hairColor'] != null) {
      technicalInfo.add(
        _buildPDFInfoRow('Color Pelo', report['hairColor'].toString()),
      );
    }
  } else if (report['connectivity'] == 'Enlace') {
    if (report['ap'] != null) {
      technicalInfo.add(_buildPDFInfoRow('AP', report['ap'].toString()));
    }
    if (report['st'] != null) {
      technicalInfo.add(_buildPDFInfoRow('ST', report['st'].toString()));
    }
    if (report['ccq'] != null) {
      technicalInfo.add(_buildPDFInfoRow('CCQ', report['ccq'].toString()));
    }
  }

  if (technicalInfo.isEmpty) {
    return pw.SizedBox();
  }

  return _buildPDFInfoSection('Información Técnica', technicalInfo);
}

pw.Widget _buildPDFMaterialsSimpleSection(List supplies) {
  return _buildPDFInfoSection('Materiales Utilizados', [
    pw.Text(
      'Se utilizaron ${supplies.length} material(es) en este trabajo.',
      style: const pw.TextStyle(fontSize: 12),
    ),
    pw.SizedBox(height: 8),
    pw.Text(
      'Nota: El detalle completo de materiales está disponible en el sistema digital.',
      style: pw.TextStyle(
        fontSize: 10,
        fontStyle: pw.FontStyle.italic,
        color: PdfColors.grey600,
      ),
    ),
  ]);
}

pw.Widget _buildPDFPhotosSection(List<List<int>> imageBytes) {
  final List<pw.Widget> imageWidgets = [];

  // Usar las imágenes pre-descargadas
  for (int i = 0; i < imageBytes.length; i++) {
    try {
      final image = pw.MemoryImage(Uint8List.fromList(imageBytes[i]));
      imageWidgets.add(
        pw.Container(
          width: 120,
          height: 120,
          margin: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Image(image, fit: pw.BoxFit.cover),
        ),
      );
    } catch (e) {
      // Si falla cargar la imagen, continuar con la siguiente
      continue;
    }
  }

  return _buildPDFInfoSection('Imágenes del Trabajo', [
    if (imageWidgets.isNotEmpty) ...[
      pw.Wrap(spacing: 8, runSpacing: 8, children: imageWidgets),
    ] else ...[
      pw.Text(
        'Las imágenes no pudieron cargarse.',
        style: pw.TextStyle(
          fontSize: 10,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.grey600,
        ),
      ),
    ],
  ]);
}

String? _getLocationText(dynamic location) {
  if (location == null) return null;

  try {
    // If location is a string (coordinates)
    if (location is String) {
      return location;
    }

    // If location is a map with address field
    if (location is Map<String, dynamic>) {
      if (location.containsKey('address')) {
        return location['address']?.toString();
      }
      // If it has lat/lng coordinates, format them
      if (location.containsKey('lat') && location.containsKey('lng')) {
        return '${location['lat']}, ${location['lng']}';
      }
      // Return the string representation
      return location.toString();
    }

    return location.toString();
  } catch (e) {
    return location.toString();
  }
}

pw.Widget _buildPDFInfoSection(String title, List<pw.Widget> children) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.orange,
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ],
  );
}

pw.Widget _buildPDFInfoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 120,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
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
      return 'En Progreso';
    case 'completed':
      return 'Completado';
    default:
      return status ?? 'N/A';
  }
}

String _formatTime(dynamic time) {
  if (time == null) return 'N/A';
  try {
    final date = DateTime.parse(time.toString());
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } catch (e) {
    return time.toString();
  }
}

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
      _tasks.clear();
      _reports.clear();
    }

    // Cargar usuarios primero para que estén disponibles cuando se carguen los reportes
    await _loadUsers();

    // Cargar datos iniciales rápido, luego el resto en segundo plano
    await Future.wait([_loadTasksInitial(), _loadReportsInitial()]);

    // Después cargar todo en segundo plano
    _loadAllDataInBackground();
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
      debugPrint('Error loading users: $e');
    }
  }

  String _getUserNameById(String userId) {
    if (!_isUsersLoaded || _users.isEmpty) {
      return 'Cargando...';
    }

    final user = _users.firstWhere(
      (user) =>
          user['_id']?.toString() == userId ||
          user['userId']?.toString() == userId,
      orElse: () => <String, dynamic>{},
    );

    return user.isNotEmpty ? _extractUserName(user) : 'Usuario desconocido';
  }

  String _extractUserName(Map<String, dynamic> user) {
    // Combinaciones comunes de campos
    final combinations = [
      ['fullName'],
      ['firstName', 'lastName'],
      ['name', 'surname'],
      ['nombre', 'apellido'],
      ['first_name', 'last_name'],
    ];

    for (final combo in combinations) {
      final parts = combo
          .map((field) => user[field]?.toString().trim() ?? '')
          .where((part) => part.isNotEmpty);
      if (parts.length == combo.length) {
        return parts.join(' ');
      }
    }

    // Fallback a name simple
    final name = user['name']?.toString().trim();
    return name?.isNotEmpty == true ? name! : 'Usuario desconocido';
  }

  Future<List<List<int>>> _downloadImagesForPDF(List imageUrls) async {
    final List<List<int>> imageBytes = [];

    for (int i = 0; i < imageUrls.length && i < 4; i++) {
      try {
        final response = await http.get(Uri.parse(imageUrls[i].toString()));
        if (response.statusCode == 200) {
          imageBytes.add(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Error downloading image: $e');
      }
    }

    return imageBytes;
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

            if ((typeOfWork?.contains(searchLower) ?? false) ||
                (toDo?.contains(searchLower) ?? false) ||
                (location?.contains(searchLower) ?? false) ||
                (connectivity?.contains(searchLower) ?? false)) {
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

    // Si se cambia a remitos y los usuarios no están cargados, cargarlos
    if (section == 'remitos' && !_isUsersLoaded) {
      _loadUsers();
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

  /// Widget para mostrar la sección de materiales/suministros
  Widget _buildSuppliesSection(List<dynamic> supplies) {
    return _buildInfoSection(
      'Materiales Utilizados',
      LucideIcons.package,
      Colors.orange,
      [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se utilizaron ${supplies.length} material(es) en este trabajo.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Consulte el sistema para ver el detalle completo de materiales.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
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

  bool _hasLocationCoordinates(String? location) {
    if (location == null) return false;

    final locationStr = location.toString();
    if (locationStr.contains(',') && locationStr.contains('-')) {
      final parts = locationStr.split(',');
      if (parts.length == 2) {
        try {
          final lat = double.parse(parts[0].trim());
          final lng = double.parse(parts[1].trim());
          return lat.abs() > 0.0001 && lng.abs() > 0.0001;
        } catch (e) {
          return false;
        }
      }
    }
    return false;
  }

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
                            '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
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

  Future<void> _downloadReportPDF(Map<String, dynamic> report) async {
    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text('Generando PDF...'),
                ],
              ),
            ),
      );

      // Pre-descargar imágenes para evitar bloqueos en el isolate
      List<List<int>>? imageBytes;
      if (report['imagesUrl'] != null &&
          (report['imagesUrl'] as List).isNotEmpty) {
        imageBytes = await _downloadImagesForPDF(report['imagesUrl'] as List);
      }

      // Generar PDF en background para no bloquear UI
      final pdf = await compute(_generateReportPDFStatic, {
        'report': report,
        'users': _users,
        'imageBytes': imageBytes,
      });
      final bytes = await pdf.save();
      final userName = _getUserNameById(report['userId']?.toString() ?? '');
      final fileName =
          'Remito_${userName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar loading

      if (kIsWeb) {
        await PDFDownloadHelper.downloadPDF(bytes: bytes, fileName: fileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF descargado: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Para móvil, usar helper para guardar
        await PDFDownloadHelper.downloadPDF(bytes: bytes, fileName: fileName);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF guardado: $fileName'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Compartir',
                textColor: Colors.white,
                onPressed:
                    () => PDFDownloadHelper.sharePDF(
                      bytes: bytes,
                      fileName: fileName,
                    ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Cerrar loading si está abierto
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generando PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
