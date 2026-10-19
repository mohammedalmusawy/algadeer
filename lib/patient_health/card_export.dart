import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'attachment_view.dart';
import 'byte_download.dart'
    if (dart.library.html) 'byte_download_web.dart'
    if (dart.library.io) 'byte_download_io.dart';
import 'patient_health_models.dart';

Future<Uint8List> captureCardPng(RenderRepaintBoundary boundary) async {
  final image = await boundary.toImage(pixelRatio: 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) {
    throw StateError('تعذر تجهيز صورة البطاقة');
  }
  return data.buffer.asUint8List();
}

class CardFileDelivery {
  const CardFileDelivery({required this.shared, this.savedPath});

  final bool shared;
  final String? savedPath;
}

class PatientExportFile {
  const PatientExportFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

class AttachmentExportReady {
  const AttachmentExportReady({
    required this.attachment,
    required this.bytes,
  });

  final HealthAttachment attachment;
  final Uint8List bytes;
}

class AttachmentExportFailure implements Exception {
  const AttachmentExportFailure(this.names);

  final List<String> names;

  @override
  String toString() {
    return 'تعذر تحميل هالصور قبل التصدير: ${names.join('، ')}. '
        'ما صدرنا البطاقة حتى ما تنحذف صورة بهدوء.';
  }
}

String safeExportFileName(String fileName, int index) {
  final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  if (safe.isEmpty || safe == '_') return 'ghadeer-attachment-$index.jpg';
  return safe;
}

Future<List<AttachmentExportReady>> loadAttachmentsForExport({
  required Future<Uint8List> Function(String id) load,
  required List<HealthAttachment> selected,
}) async {
  final ready = <AttachmentExportReady>[];
  final failed = <String>[];
  for (final item in selected) {
    try {
      final bytes = await load(item.id);
      if (!looksLikeImageBytes(bytes)) {
        failed.add(item.fileName);
        continue;
      }
      ready.add(AttachmentExportReady(attachment: item, bytes: bytes));
    } catch (_) {
      failed.add(item.fileName);
    }
  }
  if (failed.isNotEmpty) throw AttachmentExportFailure(failed);
  return ready;
}

Future<Uint8List> followUpExportPdf({
  required Uint8List cardPng,
  List<Uint8List> images = const [],
}) async {
  final doc = pw.Document();
  void addContainedImage(Uint8List bytes) {
    final image = pw.MemoryImage(bytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        // هامش علوي أقل يقلّل الفراغ الكبير فوق البطاقة.
        margin: const pw.EdgeInsets.fromLTRB(22, 14, 22, 22),
        build: (context) => pw.Align(
          alignment: pw.Alignment.topCenter,
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
  }

  addContainedImage(cardPng);
  for (final image in images) {
    addContainedImage(image);
  }
  return doc.save();
}

Future<Uint8List> pngBytesToPdf(Uint8List png) {
  return followUpExportPdf(cardPng: png);
}

Future<CardFileDelivery> deliverPatientFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  return deliverPatientFiles([
    PatientExportFile(bytes: bytes, filename: filename, mimeType: mimeType),
  ]);
}

Future<CardFileDelivery> deliverPatientFiles(
  List<PatientExportFile> files,
) async {
  if (files.isEmpty) {
    throw StateError('ماكو ملف للتصدير.');
  }
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final file in files)
            XFile.fromData(
              file.bytes,
              mimeType: file.mimeType,
              name: file.filename,
            ),
        ],
        text: patientShareNotice,
        subject: 'بطاقة متابعة — منصة الغدير',
      ),
    );
    return const CardFileDelivery(shared: true);
  } catch (_) {
    final paths = <String>[];
    for (final file in files) {
      paths.add(
        await savePatientFileBytes(
          bytes: file.bytes,
          filename: file.filename,
          mimeType: file.mimeType,
        ),
      );
    }
    return CardFileDelivery(shared: false, savedPath: paths.join('، '));
  }
}
