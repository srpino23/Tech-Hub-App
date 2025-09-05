// Solo para web
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> downloadPDFWeb({
  required List<int> bytes,
  required String fileName,
}) async {
  try {
    final uint8List = Uint8List.fromList(bytes);
    final blob = web.Blob([uint8List.toJS].toJS);
    final url = web.URL.createObjectURL(blob);

    final anchor =
        web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = fileName;

    web.document.body?.appendChild(anchor);
    anchor.click();

    // Limpiar recursos
    web.document.body?.removeChild(anchor);
    web.URL.revokeObjectURL(url);
  } catch (e) {
    throw Exception('Error descargando PDF en web: $e');
  }
}

Future<void> downloadPDFMobile({
  required List<int> bytes,
  required String fileName,
}) async {
  throw UnimplementedError('This should not be called on web');
}

Future<void> sharePDFFile({
  required List<int> bytes,
  required String fileName,
}) async {
  // En web, simplemente descargar
  await downloadPDFWeb(bytes: bytes, fileName: fileName);
}
