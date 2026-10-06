import 'dart:typed_data';

/// منصات بلا نظام ملفات ولا متصفح: المشاركة هي المسار، والتنزيل غير متاح.
Future<String> savePatientFileBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  if (bytes.isEmpty || mimeType.isEmpty) {
    throw StateError('تنزيل الملف غير متاح على هذا الجهاز: $filename');
  }
  throw StateError('تنزيل الملف غير متاح على هذا الجهاز: $filename');
}
