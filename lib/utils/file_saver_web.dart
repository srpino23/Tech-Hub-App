import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<String> saveFile(Uint8List bytes, String fileName, String format) async {
  final mimeType = format == 'pdf'
      ? 'application/pdf'
      : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  // Crear blob con los datos
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );

  // Crear URL del objeto
  final url = web.URL.createObjectURL(blob);

  // Crear elemento anchor y simular click
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  web.document.body?.appendChild(anchor);
  anchor.click();
  web.document.body?.removeChild(anchor);

  // Liberar memoria
  web.URL.revokeObjectURL(url);

  return 'Archivo descargado: $fileName';
}
