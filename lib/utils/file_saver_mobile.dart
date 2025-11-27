import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<String> saveFile(Uint8List bytes, String fileName, String format) async {
  try {
    // Obtener directorio de descargas
    Directory? directory;

    if (Platform.isAndroid) {
      // Para Android, intentar usar el directorio de descargas público
      if (await _requestStoragePermission()) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          // Fallback a otra ubicación común
          directory = Directory('/sdcard/Download');
        }
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getDownloadsDirectory();
    }

    // Si no se pudo acceder al directorio público, usar el directorio privado
    if (directory == null || !await directory.exists()) {
      directory = await getApplicationDocumentsDirectory();
      debugPrint('Usando directorio privado de la aplicación');
    }

    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    debugPrint('Archivo guardado en: $filePath');
    return 'Archivo guardado en: $filePath';
  } catch (e) {
    debugPrint('Error guardando archivo: $e');
    // Fallback final: intentar guardar en el directorio privado
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      debugPrint('Archivo guardado en directorio privado: $filePath');
      return 'Archivo guardado en directorio privado: $filePath';
    } catch (e2) {
      throw Exception('No se pudo guardar el archivo: $e2');
    }
  }
}

Future<bool> _requestStoragePermission() async {
  if (Platform.isAndroid) {
    try {
      // Para Android 13+ (API 33+), usar permisos granulares
      if (await _isAndroid13OrHigher()) {
        final status = await Permission.photos.request();
        return status.isGranted;
      } else {
        // Para Android 10-12, usar permiso de almacenamiento
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } catch (e) {
      debugPrint('Error solicitando permisos: $e');
      return false;
    }
  }
  return true;
}

Future<bool> _isAndroid13OrHigher() async {
  if (Platform.isAndroid) {
    try {
      final androidInfo = await _getAndroidVersion();
      return androidInfo >= 33; // API 33 = Android 13
    } catch (e) {
      debugPrint('Error obteniendo versión de Android: $e');
      return false;
    }
  }
  return false;
}

Future<int> _getAndroidVersion() async {
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
