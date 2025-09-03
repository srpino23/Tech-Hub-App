import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

// Importaciones condicionales para web
import 'pdf_download_web.dart' if (dart.library.io) 'pdf_download_mobile.dart';

class PDFDownloadHelper {
  static Future<void> downloadPDF({
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      if (kIsWeb) {
        await downloadPDFWeb(bytes: bytes, fileName: fileName);
      } else {
        await downloadPDFMobile(bytes: bytes, fileName: fileName);
      }
    } catch (e) {
      debugPrint('Error en downloadPDF: $e');
      rethrow;
    }
  }

  static Future<void> sharePDF({
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      await sharePDFFile(bytes: bytes, fileName: fileName);
    } catch (e) {
      debugPrint('Error en sharePDF: $e');
      rethrow;
    }
  }

  // Método específico para generar PDF en background (evita problemas con compute en Android)
  static Future<Map<String, dynamic>> generatePDFInBackground({
    required Map<String, dynamic> data,
  }) async {
    try {
      if (kIsWeb) {
        // En web, usar compute normalmente
        return await _generatePDFInBackgroundWeb(data);
      } else {
        // En móvil, ejecutar directamente para evitar problemas con BackgroundIsolateBinaryMessenger
        return await _generatePDFInBackgroundMobile(data);
      }
    } catch (e) {
      return {
        'success': false,
        'bytes': null,
        'fileName': null,
        'error': e.toString(),
      };
    }
  }

  // Implementación para web usando compute
  static Future<Map<String, dynamic>> _generatePDFInBackgroundWeb(
    Map<String, dynamic> data,
  ) async {
    // En web, usar compute normalmente
    return await compute(_generatePDFInBackgroundIsolate, data);
  }

  // Implementación para móvil sin compute
  static Future<Map<String, dynamic>> _generatePDFInBackgroundMobile(
    Map<String, dynamic> data,
  ) async {
    // En móvil, ejecutar directamente para evitar problemas con BackgroundIsolateBinaryMessenger
    return await _generatePDFInBackgroundIsolate(data);
  }

  // Función que se ejecuta en isolate separado (solo para web)
  static Future<Map<String, dynamic>> _generatePDFInBackgroundIsolate(
    Map<String, dynamic> data,
  ) async {
    try {
      final report = data['report'] as Map<String, dynamic>;
      final users = data['users'] as List<Map<String, dynamic>>;
      final imageUrls = data['imageUrls'] as List;
      final inventory = data['inventory'] as List<Map<String, dynamic>>;

      // 1. Descargar imágenes en paralelo con timeout más agresivo
      List<List<int>> imageBytes = [];
      if (imageUrls.isNotEmpty) {
        final limitedUrls =
            imageUrls.take(4).toList(); // Reducir a 4 imágenes máximo
        final futures = limitedUrls.map((url) async {
          try {
            final response = await http
                .get(
                  Uri.parse(url.toString()),
                  headers: {'User-Agent': 'TechHub-Mobile/1.0'},
                )
                .timeout(const Duration(seconds: 5)); // Reducir timeout

            if (response.statusCode == 200) {
              return response.bodyBytes;
            }
          } catch (e) {
            // Silenciar errores de imagen individual
          }
          return null;
        });

        final results = await Future.wait(futures);
        for (final result in results) {
          if (result != null) {
            imageBytes.add(result);
          }
        }
      }

      // 2. Generar PDF
      final pdf = await _generateReportPDFStatic({
        'report': report,
        'users': users,
        'imageBytes': imageBytes,
        'inventory': inventory,
      });

      // 3. Convertir a bytes
      final bytes = await pdf.save();

      // 4. Preparar nombre del archivo
      String userName = 'Usuario';
      try {
        final userId = report['userId']?.toString();
        if (userId != null && users.isNotEmpty) {
          final user = users.firstWhere(
            (user) =>
                user['_id']?.toString() == userId ||
                user['userId']?.toString() == userId,
            orElse: () => <String, dynamic>{},
          );
          if (user.isNotEmpty) {
            userName = _extractUserNameStatic(user);
          }
        }
      } catch (e) {
        // Usar nombre por defecto si falla
      }

      final fileName =
          'Remito_${userName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // 5. Descargar/guardar PDF
      await downloadPDF(bytes: bytes, fileName: fileName);

      return {
        'success': true,
        'bytes': bytes,
        'fileName': fileName,
        'error': null,
      };
    } catch (e) {
      return {
        'success': false,
        'bytes': null,
        'fileName': null,
        'error': e.toString(),
      };
    }
  }

  // Helper function for PDF generation
  static String _extractUserNameStatic(Map<String, dynamic> user) {
    // Usar directamente name y surname si están disponibles
    final name = user['name']?.toString().trim() ?? '';
    final surname = user['surname']?.toString().trim() ?? '';

    if (name.isNotEmpty && surname.isNotEmpty) {
      return '$name $surname';
    } else if (name.isNotEmpty) {
      return name;
    } else if (surname.isNotEmpty) {
      return surname;
    }

    // Fallback a otros campos comunes
    final fullName = user['fullName']?.toString().trim();
    if (fullName?.isNotEmpty == true) {
      return fullName!;
    }

    return 'Desconocido';
  }

  // Función para generar el PDF del reporte
  static Future<pw.Document> _generateReportPDFStatic(
    Map<String, dynamic> data,
  ) async {
    final report = data['report'] as Map<String, dynamic>;
    final users = data['users'] as List<Map<String, dynamic>>;
    final imageBytes = data['imageBytes'] as List<List<int>>?;
    final inventory = data['inventory'] as List<Map<String, dynamic>>;

    final pdf = pw.Document();

    // Helper function to get user name - optimizada
    String getUserName(String? userId) {
      if (userId == null) return 'Desconocido';
      try {
        final user = users.firstWhere(
          (user) =>
              user['userId']?.toString() == userId ||
              user['_id']?.toString() == userId,
          orElse: () => <String, dynamic>{},
        );
        return user.isNotEmpty ? _extractUserNameStatic(user) : 'Desconocido';
      } catch (e) {
        return 'Desconocido';
      }
    }

    // Preparar widgets para el PDF de manera más eficiente
    final List<pw.Widget> pdfWidgets = [
      // Header del documento
      _buildPDFHeader(report, getUserName),
      pw.SizedBox(height: 16), // Reducir espaciado
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
      pw.SizedBox(height: 16),
    ];

    // Agregar secciones condicionales solo si tienen contenido
    final location = report['location'];
    if (location != null) {
      pdfWidgets.addAll([
        _buildPDFInfoSection('Ubicación', [
          _buildPDFInfoRow('Coordenadas', _getLocationText(location) ?? 'N/A'),
        ]),
        pw.SizedBox(height: 16),
      ]);
    }

    final toDo = report['toDo']?.toString();
    if (toDo != null && toDo.isNotEmpty) {
      pdfWidgets.addAll([
        _buildPDFInfoSection('Trabajo Realizado', [
          pw.Paragraph(text: toDo, style: const pw.TextStyle(fontSize: 12)),
        ]),
        pw.SizedBox(height: 16),
      ]);
    }

    final connectivity = report['connectivity']?.toString();
    if (connectivity == 'Fibra óptica' || connectivity == 'Enlace') {
      pdfWidgets.addAll([
        _buildPDFTechnicalSection(report),
        pw.SizedBox(height: 16),
      ]);
    }

    final supplies = report['supplies'];
    if (supplies != null && (supplies as List).isNotEmpty) {
      pdfWidgets.addAll([
        _buildPDFMaterialsSimpleSection(supplies, inventory),
        pw.SizedBox(height: 16),
      ]);
    }

    // Fotos - usar imágenes pre-descargadas
    if (imageBytes != null && imageBytes.isNotEmpty) {
      pdfWidgets.add(_buildPDFPhotosSection(imageBytes));
    }

    // Build PDF content con configuración optimizada
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24), // Reducir márgenes
        build: (pw.Context context) => pdfWidgets,
      ),
    );

    return pdf;
  }

  // Helper functions for PDF sections
  static pw.Widget _buildPDFHeader(
    Map<String, dynamic> report,
    String Function(String?) getUserName,
  ) {
    return pw.Container(
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
    );
  }

  static pw.Widget _buildPDFTechnicalSection(Map<String, dynamic> report) {
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

  static pw.Widget _buildPDFMaterialsSimpleSection(
    List supplies,
    List<Map<String, dynamic>> inventory,
  ) {
    final List<pw.Widget> materialWidgets = [];

    // Helper function para obtener nombre del material por ID
    String getMaterialNameById(String materialId) {
      if (inventory.isEmpty) {
        return 'Material ID: $materialId';
      }

      final material = inventory.firstWhere(
        (material) => material['_id']?.toString() == materialId,
        orElse: () => <String, dynamic>{},
      );

      if (material.isNotEmpty) {
        return material['name']?.toString() ?? 'Material ID: $materialId';
      }

      return 'Material ID: $materialId';
    }

    // Agregar cada material individualmente
    for (int i = 0; i < supplies.length; i++) {
      final material = supplies[i];
      if (material != null) {
        String materialText = '';

        // Extraer información del material según su estructura
        if (material is Map<String, dynamic>) {
          // Si tiene materialId, buscar el nombre en el inventario
          if (material['materialId'] != null) {
            final materialId = material['materialId'].toString();
            materialText = getMaterialNameById(materialId);
          } else if (material['name'] != null) {
            materialText = material['name'].toString();
          } else if (material['material'] != null) {
            materialText = material['material'].toString();
          } else if (material['description'] != null) {
            materialText = material['description'].toString();
          } else {
            materialText = material.toString();
          }

          // Agregar cantidad si está disponible
          if (material['quantity'] != null) {
            materialText += ' (${material['quantity']})';
          }
        } else {
          materialText = material.toString();
        }

        materialWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Text(
              '- $materialText',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        );
      }
    }

    final List<pw.Widget> allWidgets = [
      pw.Text(
        'Se utilizaron ${supplies.length} material(es):',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
    ];

    allWidgets.addAll(materialWidgets);

    return _buildPDFInfoSection('Materiales Utilizados', allWidgets);
  }

  static pw.Widget _buildPDFPhotosSection(List<List<int>> imageBytes) {
    final List<pw.Widget> imageWidgets = [];

    // Usar las imágenes pre-descargadas de manera más eficiente
    for (int i = 0; i < imageBytes.length && i < 3; i++) {
      // Limitar a 3 imágenes máximo
      try {
        final image = pw.MemoryImage(Uint8List.fromList(imageBytes[i]));
        imageWidgets.add(
          pw.Container(
            width: 100, // Reducir tamaño
            height: 100, // Reducir tamaño
            margin: const pw.EdgeInsets.all(3), // Reducir margen
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6), // Reducir radio
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
        pw.Wrap(
          spacing: 6,
          runSpacing: 6,
          children: imageWidgets,
        ), // Reducir espaciado
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

  static String? _getLocationText(dynamic location) {
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

  static pw.Widget _buildPDFInfoSection(
    String title,
    List<pw.Widget> children,
  ) {
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

  static pw.Widget _buildPDFInfoRow(String label, String value) {
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

  static String _translateStatus(String? status) {
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

  static String _formatTime(dynamic time) {
    if (time == null) return 'N/A';
    try {
      final date = DateTime.parse(time.toString());
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return time.toString();
    }
  }
}
