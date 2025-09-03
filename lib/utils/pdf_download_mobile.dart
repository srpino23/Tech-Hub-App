// Solo para móvil
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> downloadPDFWeb({
  required List<int> bytes,
  required String fileName,
}) async {
  throw UnimplementedError('This should not be called on mobile');
}

Future<void> downloadPDFMobile({
  required List<int> bytes,
  required String fileName,
}) async {
  try {
    // Intentar guardar en el directorio de descargas público
    Directory? downloadsDir;

    if (Platform.isAndroid) {
      // Para Android, intentar usar el directorio de descargas público
      if (await _requestStoragePermission()) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = Directory('/sdcard/Download');
        }
      }
    }

    // Si no se pudo acceder al directorio público, usar el directorio privado
    if (downloadsDir == null || !await downloadsDir.exists()) {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    final file = File('${downloadsDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    debugPrint('PDF guardado en: ${file.path}');
  } catch (e) {
    debugPrint('Error guardando PDF: $e');
    // Fallback al directorio privado
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    debugPrint('PDF guardado en directorio privado: ${file.path}');
  }
}

Future<bool> _requestStoragePermission() async {
  if (Platform.isAndroid) {
    // Para Android 13+ (API 33+), usar permisos granulares
    if (await _isAndroid13OrHigher()) {
      final status = await Permission.photos.request();
      return status.isGranted;
    } else {
      // Para Android 10-12, usar permiso de almacenamiento
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }
  return true;
}

Future<bool> _isAndroid13OrHigher() async {
  if (Platform.isAndroid) {
    try {
      final androidInfo = await _getAndroidVersion();
      return androidInfo >= 33;
    } catch (e) {
      return false;
    }
  }
  return false;
}

Future<int> _getAndroidVersion() async {
  // Implementación simple para obtener la versión de Android
  // En una implementación real, podrías usar device_info_plus
  try {
    final result = await Process.run('getprop', ['ro.build.version.sdk']);
    if (result.exitCode == 0) {
      return int.tryParse(result.stdout.toString().trim()) ?? 0;
    }
  } catch (e) {
    debugPrint('Error obteniendo versión de Android: $e');
  }
  return 0;
}

Future<void> sharePDFFile({
  required List<int> bytes,
  required String fileName,
}) async {
  try {
    // Guardar temporalmente el PDF
    final directory = await getTemporaryDirectory();
    final tempFile = File('${directory.path}/$fileName');
    await tempFile.writeAsBytes(bytes);

    // Compartir usando el plugin de printing
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: fileName,
    );

    // Limpiar archivo temporal
    await tempFile.delete();
  } catch (e) {
    debugPrint('Error compartiendo PDF: $e');
    // Fallback al método anterior
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: fileName,
    );
  }
}
