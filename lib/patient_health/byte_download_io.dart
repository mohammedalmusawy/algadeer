import 'dart:io';
import 'dart:typed_data';

Future<String> savePatientFileBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  if (mimeType.isEmpty) {
    throw StateError('نوع الملف ناقص');
  }
  final safe = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final file = File('${Directory.systemTemp.path}/$safe');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
