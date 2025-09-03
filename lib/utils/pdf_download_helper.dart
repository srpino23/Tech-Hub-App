import 'package:flutter/foundation.dart';

// Importaciones condicionales para web
import 'pdf_download_web.dart' if (dart.library.io) 'pdf_download_mobile.dart';

class PDFDownloadHelper {
  static Future<void> downloadPDF({
    required List<int> bytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      await downloadPDFWeb(bytes: bytes, fileName: fileName);
    } else {
      await downloadPDFMobile(bytes: bytes, fileName: fileName);
    }
  }

  static Future<void> sharePDF({
    required List<int> bytes,
    required String fileName,
  }) async {
    await sharePDFFile(bytes: bytes, fileName: fileName);
  }
}
