import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'data_helpers.dart';

// Importaciones condicionales para web
import 'pdf_download_web.dart' if (dart.library.io) 'pdf_download_mobile.dart';

// Clase helper para datos del reporte
class _ReportData {
  final Map<String, dynamic> report;
  final List<Map<String, dynamic>> users;
  final List imageUrls;
  final List<Map<String, dynamic>> inventory;

  _ReportData({
    required this.report,
    required this.users,
    required this.imageUrls,
    required this.inventory,
  });
}

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
      rethrow;
    }
  }

  // Método específico para generar PDF en background (evita problemas con compute en Android)
  static Future<Map<String, dynamic>> generatePDFInBackground({
    required Map<String, dynamic> data,
  }) async {
    try {
      return kIsWeb 
        ? await compute(_generatePDFInBackgroundIsolate, data)
        : await _generatePDFInBackgroundIsolate(data);
    } catch (e) {
      return _createErrorResult(e.toString());
    }
  }

  // Función que se ejecuta en isolate separado (solo para web)
  static Future<Map<String, dynamic>> _generatePDFInBackgroundIsolate(
    Map<String, dynamic> data,
  ) async {
    try {
      final extractedData = _extractDataFromMap(data);
      final imageBytes = await _downloadImages(extractedData.imageUrls);
      final pdf = await _generateReportPDFStatic({
        'report': extractedData.report,
        'users': extractedData.users,
        'imageBytes': imageBytes,
        'inventory': extractedData.inventory,
      });

      final bytes = await pdf.save();
      final fileName = _generateFileName(extractedData.report, extractedData.users);
      
      await downloadPDF(bytes: bytes, fileName: fileName);

      return _createSuccessResult(bytes, fileName);
    } catch (e) {
      return _createErrorResult(e.toString());
    }
  }

  // Helper functions for data extraction and processing
  static _ReportData _extractDataFromMap(Map<String, dynamic> data) {
    return _ReportData(
      report: data['report'] as Map<String, dynamic>,
      users: data['users'] as List<Map<String, dynamic>>,
      imageUrls: data['imageUrls'] as List,
      inventory: data['inventory'] as List<Map<String, dynamic>>,
    );
  }

  static Future<List<List<int>>> _downloadImages(List imageUrls) async {
    if (imageUrls.isEmpty) return [];
    
    final limitedUrls = imageUrls.take(4).toList();
    final futures = limitedUrls.map(_downloadSingleImage);
    final results = await Future.wait(futures);
    
    return results.where((result) => result != null && result.isNotEmpty).cast<List<int>>().toList();
  }

  static Future<List<int>?> _downloadSingleImage(dynamic url) async {
    try {
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'User-Agent': 'TechHub-Mobile/1.0',
          'Accept': 'image/*',
        },
      ).timeout(const Duration(seconds: 10));

      return (response.statusCode == 200 && response.bodyBytes.isNotEmpty) 
        ? response.bodyBytes 
        : null;
    } catch (e) {
      return null;
    }
  }

  static String _generateFileName(Map<String, dynamic> report, List<Map<String, dynamic>> users) {
    final userName = _getUserNameFromReport(report, users);
    return 'Remito_${userName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
  }

  static String _getUserNameFromReport(Map<String, dynamic> report, List<Map<String, dynamic>> users) {
    final userId = report['userId']?.toString();
    return _getUserNameFromList(userId, users) == 'Desconocido' ? 'Usuario' : _getUserNameFromList(userId, users);
  }

  static String _getUserNameFromList(String? userId, List<Map<String, dynamic>> users) {
    if (userId == null || users.isEmpty) return 'Desconocido';
    
    try {
      final user = users.firstWhere(
        (user) => user['_id']?.toString() == userId || user['userId']?.toString() == userId,
        orElse: () => <String, dynamic>{},
      );
      return user.isNotEmpty ? _extractUserNameStatic(user) : 'Desconocido';
    } catch (e) {
      return 'Desconocido';
    }
  }

  static Map<String, dynamic> _createSuccessResult(List<int> bytes, String fileName) {
    return {
      'success': true,
      'bytes': bytes,
      'fileName': fileName,
      'error': null,
    };
  }

  static Map<String, dynamic> _createErrorResult(String error) {
    return {
      'success': false,
      'bytes': null,
      'fileName': null,
      'error': error,
    };
  }

  // Helper function for PDF generation
  static String _extractUserNameStatic(Map<String, dynamic> user) => DataHelpers.extractUserName(user);

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
    String getUserName(String? userId) => _getUserNameFromList(userId, users);

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
          DataHelpers.translateStatus(report['status']?.toString()),
        ),
        _buildPDFInfoRow(
          'Tipo de Trabajo',
          report['typeOfWork']?.toString() ?? 'N/A',
        ),
        _buildPDFInfoRow('Fecha de Inicio', DataHelpers.formatTime(report['startTime'])),
        _buildPDFInfoRow('Fecha de Fin', DataHelpers.formatTime(report['endTime'])),
        _buildPDFInfoRow(
          'Tiempo Total',
          DataHelpers.calculateWorkingTime(report['startTime'], report['endTime']),
        ),
        _buildPDFInfoRow(
          'Conectividad',
          report['connectivity']?.toString() ?? 'N/A',
        ),
        if (report['cameraName'] != null && report['cameraName'].toString().isNotEmpty)
          _buildPDFInfoRow(
            'Cámara',
            report['cameraName'].toString(),
          ),
      ]),
      pw.SizedBox(height: 16),
    ];

    // Agregar secciones condicionales solo si tienen contenido
    final location = report['location'];
    if (location != null) {
      pdfWidgets.addAll([
        _buildPDFInfoSection('Ubicación', [
          _buildPDFInfoRow('Coordenadas', DataHelpers.getLocationText(location) ?? 'N/A'),
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
    for (int i = 0; i < imageBytes.length && i < 4; i++) {
      // Limitar a 4 imágenes máximo para mejor distribución
      try {
        // Verificar que los bytes de la imagen sean válidos
        if (imageBytes[i].isNotEmpty) {
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
        }
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

}
