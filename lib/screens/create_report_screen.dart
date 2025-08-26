import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../auth_manager.dart';
import '../services/techhub_api_client.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:async';

// Clase universal para manejar archivos en todas las plataformas
class UniversalFile {
  final PlatformFile platformFile;
  final String? name;

  UniversalFile(this.platformFile, {this.name});

  bool get isValid =>
      platformFile.bytes != null && platformFile.bytes!.isNotEmpty;

  String get displayName => name ?? platformFile.name;

  // Getter para obtener los bytes
  Uint8List get bytes => platformFile.bytes ?? Uint8List(0);

  // Getter para obtener el tamaño
  int get size => platformFile.size;

  // Getter para obtener la extensión
  String get extension => platformFile.extension ?? '';

  // Verificar si es una imagen
  bool get isImage {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    return imageExtensions.contains(extension.toLowerCase());
  }

  Widget buildImageWidget({required double width, required double height}) {
    if (isValid && isImage) {
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: Icon(Icons.error, color: Colors.grey[600]),
          );
        },
      );
    } else {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file, color: Colors.grey[600], size: 32),
            const SizedBox(height: 8),
            Text(
              extension.toUpperCase(),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
  }
}

class CreateReportScreen extends StatefulWidget {
  final AuthManager authManager;
  final Function(int)? onNavigateToTab;
  final String? existingReportId; // Para reanudar borradores
  final bool
  isEditingExistingReport; // Para controlar la visibilidad del header

  const CreateReportScreen({
    super.key,
    required this.authManager,
    this.onNavigateToTab,
    this.existingReportId,
    this.isEditingExistingReport = false, // Default to false
  });

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  // Form variables
  String _typeOfWork = 'Preventivo';
  String _connectivity = 'Fibra óptica';
  bool _usingMaterials = false;
  Position? _currentLocation;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;

  // Draft management
  String? _currentReportId;
  bool _isDraftCreated = false;
  Timer? _autoSaveTimer;

  // Connectivity fields
  final _dbController = TextEditingController();
  final _buffersController = TextEditingController();
  final _bufferColorController = TextEditingController();
  final _hairColorController = TextEditingController();
  final _apNameController = TextEditingController();
  final _apIpController = TextEditingController();
  final _stNameController = TextEditingController();
  final _stIpController = TextEditingController();
  final _ccqController = TextEditingController();

  // Materials and inventory
  List<Map<String, dynamic>> _availableMaterials = [];
  final Map<String, int> _materialQuantities = {};
  bool _isLoadingMaterials = false;

  // Images
  final List<UniversalFile> _selectedImages = [];

  // Type of work options
  final List<String> _typeOfWorkOptions = [
    'Preventivo',
    'Recambio',
    'Correctivo',
    'Reubicación',
    'Retiro de sistema',
    'Instalación',
  ];

  // Connectivity options
  final List<String> _connectivityOptions = ['Fibra óptica', 'Enlace'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadMaterials();

    // Si hay un reporte existente, cargar sus datos
    if (widget.existingReportId != null) {
      _currentReportId = widget.existingReportId;
      _isDraftCreated = true;
      _loadExistingReport();
    }

    // Agregar listeners para autoguardado
    _setupFormListeners();
  }

  void _setupFormListeners() {
    _descriptionController.addListener(_onFormChanged);
    _dbController.addListener(_onFormChanged);
    _buffersController.addListener(_onFormChanged);
    _bufferColorController.addListener(_onFormChanged);
    _hairColorController.addListener(_onFormChanged);
    _apNameController.addListener(_onFormChanged);
    _apIpController.addListener(_onFormChanged);
    _stNameController.addListener(_onFormChanged);
    _stIpController.addListener(_onFormChanged);
    _ccqController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _descriptionController.dispose();
    _dbController.dispose();
    _buffersController.dispose();
    _bufferColorController.dispose();
    _hairColorController.dispose();
    _apNameController.dispose();
    _apIpController.dispose();
    _stNameController.dispose();
    _stIpController.dispose();
    _ccqController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final locationService = LocationService(widget.authManager);
      final position = await locationService.getCurrentLocation();

      if (position != null && mounted) {
        setState(() {
          _currentLocation = position;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error obteniendo ubicación: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _loadMaterials() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMaterials = true;
    });

    try {
      final teamId = widget.authManager.teamId;
      if (teamId == null) {
        throw Exception('No se pudo obtener el ID del equipo');
      }

      // Cargar materiales del equipo usando la nueva API
      final teamInventoryResponse = await TechHubApiClient.getInventoryByTeam(
        teamId: teamId,
      );

      if (!teamInventoryResponse.isSuccess) {
        throw Exception(
          teamInventoryResponse.error ?? 'Error cargando inventario del equipo',
        );
      }

      final teamMaterials = teamInventoryResponse.data ?? [];

      // Procesar materiales del equipo
      final materialsWithNames = <Map<String, dynamic>>[];

      for (var teamMaterial in teamMaterials) {
        final materialId = teamMaterial['materialId']?.toString();
        final quantity = teamMaterial['quantity']?.toString() ?? '0';
        var materialName = teamMaterial['materialName']?.toString();

        // El materialName debería venir del inventario del equipo según tu estructura
        if (materialId != null &&
            materialName != null &&
            materialName.isNotEmpty) {
          materialsWithNames.add({
            'materialId': materialId,
            'materialName': materialName,
            'quantity': quantity,
          });
        } else if (materialId != null) {
          // Fallback: si no hay materialName, buscar en inventarios principales
          await _loadMaterialNameFromInventories(
            materialId,
            quantity,
            materialsWithNames,
          );
        }
      }

      if (mounted) {
        setState(() {
          _availableMaterials = materialsWithNames;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error cargando materiales: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMaterials = false;
        });
      }
    }
  }

  Future<void> _loadMaterialNameFromInventories(
    String materialId,
    String quantity,
    List<Map<String, dynamic>> materialsWithNames,
  ) async {
    try {
      // Cargar inventario principal para buscar el nombre
      final mainInventoryResponse = await TechHubApiClient.getInventory();
      final recoveredInventoryResponse =
          await TechHubApiClient.getRecoveredInventory();

      final mainInventory =
          mainInventoryResponse.isSuccess
              ? (mainInventoryResponse.data ?? [])
              : <Map<String, dynamic>>[];
      final recoveredInventory =
          recoveredInventoryResponse.isSuccess
              ? (recoveredInventoryResponse.data ?? [])
              : <Map<String, dynamic>>[];

      String? materialName;

      // Buscar en inventario principal
      for (var mainMaterial in mainInventory) {
        if (mainMaterial['_id']?.toString() == materialId) {
          materialName = mainMaterial['name']?.toString();
          break;
        }
      }

      // Si no se encontró, buscar en inventario recuperado
      if (materialName == null || materialName.isEmpty) {
        for (var recoveredMaterial in recoveredInventory) {
          if (recoveredMaterial['_id']?.toString() == materialId) {
            materialName =
                '${recoveredMaterial['name']?.toString()} (Recuperado)';
            break;
          }
        }
      }

      if (materialName != null && materialName.isNotEmpty) {
        materialsWithNames.add({
          'materialId': materialId,
          'materialName': materialName,
          'quantity': quantity,
        });
      }
    } catch (e) {
      // Si hay error buscando el nombre, agregar con ID como fallback
      materialsWithNames.add({
        'materialId': materialId,
        'materialName': 'Material ID: $materialId',
        'quantity': quantity,
      });
    }
  }

  List<Map<String, dynamic>> get _selectedMaterialsList {
    return _materialQuantities.entries.map((entry) {
      final materialId = entry.key;
      final quantity = entry.value;
      final material = _availableMaterials.firstWhere(
        (m) => m['materialId'].toString() == materialId,
        orElse:
            () => {
              'materialId': materialId,
              'materialName': 'Material desconocido',
            },
      );
      return {
        'materialId': materialId,
        'materialName': material['materialName'],
        'quantity': quantity,
      };
    }).toList();
  }

  List<dynamic> _convertUniversalImagesToFiles() {
    // Convertir UniversalFile a lista de objetos que pueden ser manejados por TechHubApiClient
    return _selectedImages
        .map((file) {
          if (file.isValid) {
            // Retornar PlatformFile que será detectado por runtime type checking en TechHubApiClient
            return file.platformFile;
          }
          return null;
        })
        .where((file) => file != null)
        .toList();
  }

  void _pickImages() async {
    if (_selectedImages.length >= 4) {
      _showError('Máximo 4 archivos permitidos');
      return;
    }

    try {
      // Usar file_picker para seleccionar archivos
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'bmp',
          'webp',
          'pdf',
          'doc',
          'docx',
        ],
        allowMultiple: true,
        withData: true, // Importante: esto carga los bytes del archivo
      );

      if (result != null && result.files.isNotEmpty) {
        // Verificar que no excedamos el límite de 4 archivos
        final remainingSlots = 4 - _selectedImages.length;
        final filesToAdd = result.files.take(remainingSlots).toList();

        for (var platformFile in filesToAdd) {
          if (platformFile.bytes != null && platformFile.bytes!.isNotEmpty) {
            final universalFile = UniversalFile(platformFile);
            if (universalFile.isValid) {
              setState(() {
                _selectedImages.add(universalFile);
              });
            }
          }
        }

        _onFormChanged();

        // Mostrar mensaje si no se pudieron agregar todos los archivos
        if (filesToAdd.length < result.files.length) {
          _showError(
            'Solo se agregaron ${filesToAdd.length} archivos (máximo 4 permitidos)',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error seleccionando archivos: $e');
      }
    }
  }

  Future<void> _submitReport() async {
    // Si no hay borrador, preguntar si quiere crear uno
    if (!_isDraftCreated) {
      return _showCreateDraftDialog();
    }

    // Si hay borrador, finalizar remito
    return _finishReport();
  }

  void _showCreateDraftDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Crear Remito'),
            content: const Text(
              '¿Desea comenzar a crear un nuevo remito? Se guardará como borrador automáticamente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _createDraft();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700], // Primary color
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Crear Borrador'),
              ),
            ],
          ),
    );
  }

  Future<void> _finishReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_currentLocation == null) {
      if (mounted) {
        _showError('Esperando ubicación...');
      }
      return;
    }

    if (_currentReportId == null) {
      if (mounted) {
        _showError('Error: No hay borrador activo');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
    });

    try {
      final teamId = widget.authManager.teamId;

      if (teamId == null) {
        throw Exception('Equipo no válido');
      }

      // Finalizar el reporte con todos los datos usando la nueva API
      final finishResponse = await TechHubApiClient.finishReport(
        reportId: _currentReportId!,
        status: 'completed',
        teamId: teamId,
        supplies:
            _materialQuantities.isNotEmpty
                ? json.encode(_selectedMaterialsList)
                : null,
        toDo: _descriptionController.text,
        typeOfWork: _typeOfWork,
        endTime: DateTime.now().toIso8601String(),
        location:
            '${_currentLocation!.latitude},${_currentLocation!.longitude}',
        connectivity: _connectivity,
        db:
            _connectivity == 'Fibra óptica' && _dbController.text.isNotEmpty
                ? _dbController.text
                : null,
        buffers:
            _connectivity == 'Fibra óptica' &&
                    _buffersController.text.isNotEmpty
                ? _buffersController.text
                : null,
        bufferColor:
            _connectivity == 'Fibra óptica' &&
                    _bufferColorController.text.isNotEmpty
                ? _bufferColorController.text
                : null,
        hairColor:
            _connectivity == 'Fibra óptica' &&
                    _hairColorController.text.isNotEmpty
                ? _hairColorController.text
                : null,
        ap:
            _connectivity == 'Enlace' &&
                    _apNameController.text.isNotEmpty &&
                    _apIpController.text.isNotEmpty
                ? '${_apNameController.text} (${_apIpController.text})'
                : null,
        st:
            _connectivity == 'Enlace' &&
                    _stNameController.text.isNotEmpty &&
                    _stIpController.text.isNotEmpty
                ? '${_stNameController.text} (${_stIpController.text})'
                : null,
        ccq:
            _connectivity == 'Enlace' && _ccqController.text.isNotEmpty
                ? _ccqController.text
                : null,
        images: _convertUniversalImagesToFiles(),
      );

      if (!finishResponse.isSuccess) {
        throw Exception(finishResponse.error ?? 'Error finalizando remito');
      }

      if (mounted) {
        _showSuccess('Remito finalizado exitosamente');

        // Limpiar formulario para próximo uso
        _resetForm();

        // Navegar al inicio (pestaña 0) después de finalizar el remito
        widget.onNavigateToTab?.call(0);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error finalizando remito: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _loadExistingReport() async {
    try {
      if (_currentReportId == null) {
        _showError('Error: No se encontró el ID del borrador.');
        return;
      }

      final response = await TechHubApiClient.getReportById(
        reportId: _currentReportId!,
      );

      if (response.isSuccess && response.data != null) {
        final report = response.data!;
        if (!mounted) return;

        setState(() {
          _descriptionController.text = report.toDo ?? '';
          _typeOfWork = report.typeOfWork ?? _typeOfWorkOptions.first;
          _connectivity = report.connectivity ?? _connectivityOptions.first;

          // Populate connectivity-specific fields
          if (report.connectivity == 'Fibra óptica') {
            _dbController.text = report.db ?? '';
            _buffersController.text = report.buffers ?? '';
            _bufferColorController.text = report.bufferColor ?? '';
            _hairColorController.text = report.hairColor ?? '';
          } else if (report.connectivity == 'Enlace') {
            // Parse AP and ST
            if (report.ap != null) {
              final apParts = _parseApSt(report.ap!);
              _apNameController.text = apParts['name'] ?? '';
              _apIpController.text = apParts['ip'] ?? '';
            }
            if (report.st != null) {
              final stParts = _parseApSt(report.st!);
              _stNameController.text = stParts['name'] ?? '';
              _stIpController.text = stParts['ip'] ?? '';
            }
            _ccqController.text = report.ccq ?? '';
          }

          // Populate materials
          if (report.supplies != null) {
            try {
              List<dynamic> decodedSupplies;
              if (report.supplies is String &&
                  (report.supplies as String).isNotEmpty) {
                decodedSupplies = json.decode(report.supplies as String);
              } else if (report.supplies is List &&
                  (report.supplies as List).isNotEmpty) {
                decodedSupplies = report.supplies as List<dynamic>;
              } else {
                decodedSupplies = [];
              }

              _materialQuantities.clear();
              for (var s in decodedSupplies) {
                _materialQuantities[s['materialId']] = int.parse(
                  s['quantity'].toString(),
                );
              }
              _usingMaterials = _materialQuantities.isNotEmpty;
            } catch (e) {
              // Error decoding supplies: $e
            }
          }

          _isDraftCreated = true; // Confirm draft is loaded
          _startAutoSave(); // Restart auto-save
        });
      } else {
        _showError(
          response.error ?? 'Error cargando borrador: Reporte no encontrado.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error cargando borrador: $e');
      }
    }
  }

  // Helper to parse AP/ST string "Name (IP)"
  Map<String, String> _parseApSt(String apStString) {
    final regex = RegExp(r'^(.*)\s+\((.*)\)');
    final match = regex.firstMatch(apStString);
    if (match != null) {
      return {'name': match.group(1) ?? '', 'ip': match.group(2) ?? ''};
    }
    return {'name': apStString, 'ip': ''}; // Return original string if no match
  }

  Future<void> _createDraft() async {
    try {
      final userId = widget.authManager.userId;
      if (userId == null) {
        throw Exception('Usuario no válido');
      }

      final response = await TechHubApiClient.createReport(
        userId: userId,
        startTime: DateTime.now().toIso8601String(),
      );

      if (response.isSuccess && response.data?.id != null) {
        _currentReportId = response.data!.id!;
        _isDraftCreated = true;

        // Iniciar autoguardado
        _startAutoSave();

        if (mounted) {
          _showSuccess(
            'Borrador creado - Los cambios se guardan automáticamente',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error creando borrador: $e');
      }
    }
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isDraftCreated && _currentReportId != null) {
        _saveDraft();
      }
    });
  }

  Future<void> _saveDraft() async {
    if (_currentReportId == null || !_isDraftCreated) return;

    try {
      final teamId = widget.authManager.teamId;

      await TechHubApiClient.updateReport(
        reportId: _currentReportId!,
        status: 'in_progress',
        teamId: teamId,
        supplies:
            _materialQuantities.isNotEmpty
                ? json.encode(_selectedMaterialsList)
                : null,
        toDo:
            _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : null,
        typeOfWork: _typeOfWork,
        location:
            _currentLocation != null
                ? '${_currentLocation!.latitude},${_currentLocation!.longitude}'
                : null,
        connectivity: _connectivity,
        db:
            _connectivity == 'Fibra óptica' && _dbController.text.isNotEmpty
                ? _dbController.text
                : null,
        buffers:
            _connectivity == 'Fibra óptica' &&
                    _buffersController.text.isNotEmpty
                ? _buffersController.text
                : null,
        bufferColor:
            _connectivity == 'Fibra óptica' &&
                    _bufferColorController.text.isNotEmpty
                ? _bufferColorController.text
                : null,
        hairColor:
            _connectivity == 'Fibra óptica' &&
                    _hairColorController.text.isNotEmpty
                ? _hairColorController.text
                : null,
        ap:
            _connectivity == 'Enlace' &&
                    _apNameController.text.isNotEmpty &&
                    _apIpController.text.isNotEmpty
                ? '${_apNameController.text} (${_apIpController.text})'
                : null,
        st:
            _connectivity == 'Enlace' &&
                    _stNameController.text.isNotEmpty &&
                    _stIpController.text.isNotEmpty
                ? '${_stNameController.text} (${_stIpController.text})'
                : null,
        ccq:
            _connectivity == 'Enlace' && _ccqController.text.isNotEmpty
                ? _ccqController.text
                : null,
      );
    } catch (e) {
      // Silenciar errores de autoguardado para no molestar al usuario
      // Error autoguardando: $e
    }
  }

  void _onFormChanged() {
    // Debounced save - Guardar después de 2 segundos de inactividad
    if (_isDraftCreated) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(seconds: 2), () {
        _saveDraft();
      });
    }
  }

  void _resetForm() {
    _autoSaveTimer?.cancel();

    // Limpiar controladores de texto
    _descriptionController.clear();
    _dbController.clear();
    _buffersController.clear();
    _bufferColorController.clear();
    _hairColorController.clear();
    _apNameController.clear();
    _apIpController.clear();
    _stNameController.clear();
    _stIpController.clear();
    _ccqController.clear();

    // Resetear variables del formulario
    setState(() {
      _typeOfWork = 'Preventivo';
      _connectivity = 'Fibra óptica';
      _usingMaterials = false;
      _materialQuantities.clear();
      _selectedImages.clear();
      _isSubmitting = false;
      _currentReportId = null;
      _isDraftCreated = false;
    });

    // Obtener nueva ubicación
    _getCurrentLocation();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey[800],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar:
          widget.isEditingExistingReport
              ? AppBar(
                elevation: 0,
                backgroundColor: Colors.white,
                automaticallyImplyLeading: false,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.orange.shade50, Colors.white],
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          LucideIcons.arrowLeft,
                          size: 24,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      'Editar Remito',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Borrador',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                centerTitle: false,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(4.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade200.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              )
              : null,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationSection(),
              const SizedBox(height: 24),
              _buildTypeOfWorkSection(),
              const SizedBox(height: 24),
              _buildConnectivitySection(),
              const SizedBox(height: 24),
              _buildDescriptionSection(),
              const SizedBox(height: 24),
              _buildMaterialsSection(),
              const SizedBox(height: 24),
              _buildImagesSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.mapPin,
                  color: const Color(0xFF1E293B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Ubicación del Trabajo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoadingLocation)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.blue[600]!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Obteniendo ubicación GPS...',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_currentLocation != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[50]!, Colors.green[100]!],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.checkCircle2,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Ubicación GPS obtenida',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.navigation,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}, Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.alertTriangle,
                        color: Colors.red[600],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No se pudo obtener la ubicación GPS',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: Icon(LucideIcons.refreshCw, size: 16),
                      label: Text(
                        'Intentar nuevamente',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeOfWorkSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.wrench,
                  color: const Color(0xFF1E293B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Tipo de Trabajo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                _typeOfWorkOptions.map((type) {
                  final isSelected = _typeOfWork == type;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _typeOfWork = type;
                      });
                      _onFormChanged();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFF1E293B)
                                : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected
                                  ? const Color(0xFF1E293B)
                                  : Colors.grey[300]!,
                          width: 1.5,
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF1E293B,
                                    ).withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectivitySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.wifi,
                  color: const Color(0xFF1E293B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Conectividad',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children:
                _connectivityOptions.map((type) {
                  final isSelected = _connectivity == type;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: type == _connectivityOptions.first ? 8 : 0,
                        left: type == _connectivityOptions.last ? 8 : 0,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _connectivity = type;
                          });
                          _onFormChanged();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF1E293B)
                                    : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? const Color(0xFF1E293B)
                                      : Colors.grey[300]!,
                              width: 1.5,
                            ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF1E293B,
                                        ).withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Text(
                            type,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : Colors.grey[700],
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 20),
          if (_connectivity == 'Fibra óptica') ...[
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _dbController,
                    label: 'DB',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    controller: _buffersController,
                    label: 'Buffers',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _bufferColorController,
                    label: 'Color del Buffer',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    controller: _hairColorController,
                    label: 'Color del Pelo',
                  ),
                ),
              ],
            ),
          ] else if (_connectivity == 'Enlace') ...[
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _apNameController,
                    label: 'AP (Nombre)',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    controller: _apIpController,
                    label: 'AP (IP)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _stNameController,
                    label: 'ST (Nombre)',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    controller: _stIpController,
                    label: 'ST (IP)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildInputField(
                    controller: _ccqController,
                    label: 'CCQ (%)',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const Expanded(flex: 1, child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.fileText,
                  color: const Color(0xFF1E293B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Trabajo Realizado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Descripción detallada del trabajo realizado',
              labelStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1E293B),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.all(20),
            ),
            maxLines: 5,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
              height: 1.4,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingrese una descripción del trabajo realizado';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.package,
                  color: const Color(0xFF1E293B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Materiales Utilizados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              setState(() {
                _usingMaterials = !_usingMaterials;
                if (!_usingMaterials) {
                  _materialQuantities.clear();
                }
              });
              _onFormChanged();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    _usingMaterials
                        ? const Color(0xFF1E293B).withValues(alpha: 0.1)
                        : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _usingMaterials
                          ? const Color(0xFF1E293B)
                          : Colors.grey[300]!,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _usingMaterials
                        ? LucideIcons.checkCircle
                        : LucideIcons.circle,
                    color:
                        _usingMaterials
                            ? const Color(0xFF1E293B)
                            : Colors.grey[500],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Se utilizaron materiales',
                      style: TextStyle(
                        color:
                            _usingMaterials
                                ? const Color(0xFF1E293B)
                                : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_usingMaterials) ...[
            const SizedBox(height: 24),
            if (_isLoadingMaterials)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_availableMaterials.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.alertTriangle,
                      color: Colors.orange[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No hay materiales disponibles en el inventario',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children:
                    _availableMaterials.map((material) {
                      final materialId = material['materialId'].toString();
                      final availableQuantity =
                          int.tryParse(material['quantity'].toString()) ?? 0;
                      final selectedQuantity =
                          _materialQuantities[materialId] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              selectedQuantity > 0
                                  ? const Color(
                                    0xFF1E293B,
                                  ).withValues(alpha: 0.05)
                                  : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                selectedQuantity > 0
                                    ? const Color(
                                      0xFF1E293B,
                                    ).withValues(alpha: 0.3)
                                    : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        material['materialName'] ?? 'Material',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Disponible: $availableQuantity',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (availableQuantity > 0) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap:
                                              selectedQuantity > 0
                                                  ? () {
                                                    setState(() {
                                                      _materialQuantities[materialId] =
                                                          selectedQuantity - 1;
                                                      if (_materialQuantities[materialId] ==
                                                          0) {
                                                        _materialQuantities
                                                            .remove(materialId);
                                                      }
                                                    });
                                                    _onFormChanged();
                                                  }
                                                  : null,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  selectedQuantity > 0
                                                      ? Colors.red[50]
                                                      : Colors.grey[100],
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(7),
                                                    bottomLeft: Radius.circular(
                                                      7,
                                                    ),
                                                  ),
                                            ),
                                            child: Icon(
                                              LucideIcons.minus,
                                              size: 16,
                                              color:
                                                  selectedQuantity > 0
                                                      ? Colors.red[600]
                                                      : Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.symmetric(
                                              vertical: BorderSide(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            selectedQuantity.toString(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap:
                                              selectedQuantity <
                                                      availableQuantity
                                                  ? () {
                                                    setState(() {
                                                      _materialQuantities[materialId] =
                                                          selectedQuantity + 1;
                                                    });
                                                    _onFormChanged();
                                                  }
                                                  : null,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  selectedQuantity <
                                                          availableQuantity
                                                      ? Colors.green[50]
                                                      : Colors.grey[100],
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topRight: Radius.circular(
                                                      7,
                                                    ),
                                                    bottomRight:
                                                        Radius.circular(7),
                                                  ),
                                            ),
                                            child: Icon(
                                              LucideIcons.plus,
                                              size: 16,
                                              color:
                                                  selectedQuantity <
                                                          availableQuantity
                                                      ? Colors.green[600]
                                                      : Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Sin stock',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            if (_materialQuantities.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[50]!, Colors.green[100]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.checkCircle2,
                          color: Colors.green[600],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Materiales seleccionados (${_materialQuantities.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._materialQuantities.entries.map((entry) {
                      final materialId = entry.key;
                      final quantity = entry.value;
                      final material = _availableMaterials.firstWhere(
                        (m) => m['materialId'].toString() == materialId,
                        orElse: () => {'materialName': 'Material desconocido'},
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.green[600],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${material['materialName']} x$quantity',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.paperclip,
                  color: const Color(0xFF1E293B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Archivos Adjuntos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedImages.length < 4 ? _pickImages : null,
              icon: Icon(LucideIcons.upload, size: 18),
              label: Text(
                'Seleccionar Archivos (${_selectedImages.length}/4)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _selectedImages.length < 4
                        ? const Color(0xFF1E293B)
                        : Colors.grey[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _selectedImages.length < 4 ? 2 : 0,
                shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.3),
              ),
            ),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.files,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Archivos adjuntados (${_selectedImages.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _selectedImages[index].buildImageWidget(
                                  width: 120,
                                  height: 120,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedImages.removeAt(index);
                                    });
                                    _onFormChanged();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red[600],
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      LucideIcons.x,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isEnabled = !_isSubmitting && _currentLocation != null;
    final buttonText = _isDraftCreated ? 'Finalizar Remito' : 'Crear Remito';
    final buttonIcon =
        _isDraftCreated ? LucideIcons.checkCircle : LucideIcons.plus;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            isEnabled
                ? [
                  BoxShadow(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
                : null,
      ),
      child: ElevatedButton(
        onPressed: isEnabled ? () => _submitReport() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isEnabled ? const Color(0xFF1E293B) : Colors.grey[400],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isEnabled ? 4 : 0,
          shadowColor: const Color(0xFF1E293B).withValues(alpha: 0.3),
        ),
        child:
            _isSubmitting
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Procesando...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(buttonIcon, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      buttonText,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
