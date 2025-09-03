// Solo para móvil
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

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
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
}

Future<void> sharePDFFile({
  required List<int> bytes,
  required String fileName,
}) async {
  await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: fileName);
}