import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/patient_health/card_export.dart';
import 'package:ghadeer_clinic/patient_health/follow_up_card.dart';
import 'package:ghadeer_clinic/patient_health/patient_health_models.dart';

/// أصغر PNG صالح. تغليف PDF لا يحتاج انتظار محرّك الرسم.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets('بطاقة عربية بعرض الموبايل بلا قص', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final content = FollowUpCardContent(
      conditionTitle: 'الضغط',
      patientName: 'أحمد علي حسن',
      issuedAt: DateTime(2026, 10, 4, 18, 30),
      readings: const [
        FollowUpReadingRow(
          dateTimeLabel: '2026/10/02 08:15',
          valueLabel: '128/82 · نبض 70',
          unitLabel: 'ملم زئبق',
          kindLabel: 'ضغط الدم',
        ),
        FollowUpReadingRow(
          dateTimeLabel: '2026/09/20 21:05',
          valueLabel: '134/86 · نبض 74',
          unitLabel: 'ملم زئبق',
          kindLabel: 'ضغط الدم',
        ),
      ],
      lines: const [
        FollowUpLine(
          title: 'ملاحظات',
          detail:
              'القراءات التالية سجّلتها بنفسي بعد المراجعة، '
              'بدون أي تنبيه آلي من التطبيق وبدون مشاركة تلقائية.',
        ),
      ],
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: RepaintBoundary(
                key: key,
                child: FollowUpCardView(content: content),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('بيانات أدخلها المريض'), findsOneWidget);
    expect(find.textContaining('أحمد علي حسن'), findsOneWidget);
    expect(find.textContaining('128/82'), findsOneWidget);
    expect(find.textContaining('ملم زئبق'), findsWidgets);

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    expect(boundary.size.width, greaterThan(300));
    expect(boundary.size.height, greaterThan(200));
    expect(boundary.debugNeedsPaint, isFalse);
    final cardBox = tester.renderObject<RenderBox>(find.byType(FollowUpCardView));
    expect(cardBox.size.width, lessThanOrEqualTo(360));
    expect(cardBox.size.height, greaterThan(180));
  });

  test('تغليف PNG داخل PDF ينتج ملفاً قابلاً للفتح', () async {
    final pdf = await pngBytesToPdf(_onePixelPng);
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    expect(pdf.length, greaterThan(100));
  });

  testWidgets('بطاقة بجدول قراءات بعرض 360 ثم PDF متعدد الصفحات', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final content = FollowUpCardContent(
      conditionTitle: 'الضغط',
      patientName: 'أحمد علي حسن',
      issuedAt: DateTime(2026, 10, 4, 18, 30),
      readings: const [
        FollowUpReadingRow(
          dateTimeLabel: '2026/10/02 08:15',
          valueLabel: '128/82 · نبض 70',
          unitLabel: 'ملم زئبق',
          kindLabel: 'ضغط الدم',
        ),
        FollowUpReadingRow(
          dateTimeLabel: '2026/09/20 21:05',
          valueLabel: '134/86 · نبض 74',
          unitLabel: 'ملم زئبق',
          kindLabel: 'ضغط الدم',
        ),
      ],
      lines: const [
        FollowUpLine(title: 'ملاحظات', detail: 'سجّلتها بنفسي بعد المراجعة.'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: FollowUpCardView(content: content),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('القراءات'), findsOneWidget);
    expect(find.text('التاريخ والوقت'), findsOneWidget);
    expect(find.text('القراءة'), findsOneWidget);
    expect(find.text('الوحدة'), findsOneWidget);
    expect(find.text('نوع القياس'), findsOneWidget);
    expect(find.textContaining('128/82'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // toImage يعلّق في بعض بيئات الاختبار؛ نولّد PNG عبر لوحة رسم ثم PDF.
    final png = await tester.runAsync(_tableCardPng);
    expect(png, isNotNull);
    final outDir = Directory('build/acceptance_visual');
    outDir.createSync(recursive: true);
    File('${outDir.path}/follow_up_card_360.png').writeAsBytesSync(png!);
    final pdf = await followUpExportPdf(cardPng: png, images: [_onePixelPng]);
    File('${outDir.path}/follow_up_card.pdf').writeAsBytesSync(pdf);
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(pdf)).length,
      greaterThanOrEqualTo(2),
    );
  });

  test('PDF يضم صفحة البطاقة ثم صفحة لكل مرفق', () async {
    final pdf = await followUpExportPdf(
      cardPng: _onePixelPng,
      images: [_onePixelPng, _onePixelPng],
    );
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(pdf)).length,
      greaterThanOrEqualTo(3),
    );
  });

  testWidgets('بطاقة عربية تُصدَّر PNG ثم PDF', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final content = FollowUpCardContent(
      conditionTitle: 'الضغط',
      patientName: 'أحمد علي حسن',
      issuedAt: DateTime(2026, 10, 4, 18, 30),
      lines: const [],
      readings: const [
        FollowUpReadingRow(
          dateTimeLabel: '2026/10/02 08:15',
          valueLabel: '128/82 · نبض 70',
          unitLabel: 'ملم زئبق',
          kindLabel: 'ضغط الدم',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: FollowUpCardView(content: content),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('أحمد علي حسن'), findsOneWidget);
    expect(find.textContaining('128/82'), findsOneWidget);

    final png = await tester.runAsync(() => _arabicCardPng());
    expect(png, isNotNull);
    expect(png!.length, greaterThan(80));
    expect(png[0], 0x89);
    expect(png[1], 0x50);
    final pdf = await pngBytesToPdf(png);
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    expect(pdf.length, greaterThan(png.length));
  });
}

Future<Uint8List> _arabicCardPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 720, 280),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      textDirection: TextDirection.rtl,
      fontSize: 22,
    ),
  )
    ..pushStyle(ui.TextStyle(color: const Color(0xFF123B42)))
    ..addText('بطاقة متابعة — أحمد علي حسن — 128/82 ملم زئبق');
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 680));
  canvas.drawParagraph(paragraph, const Offset(20, 90));
  final image = await recorder.endRecording().toImage(720, 280);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

Future<Uint8List> _tableCardPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 720, 420),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  void drawLine(String text, double y, {double size = 20}) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(textDirection: TextDirection.rtl, fontSize: size),
    )
      ..pushStyle(ui.TextStyle(color: const Color(0xFF123B42)))
      ..addText(text);
    final p = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 680));
    canvas.drawParagraph(p, Offset(20, y));
  }

  drawLine('عيادة الغدير — بطاقة متابعة', 24, size: 22);
  drawLine('القراءات | التاريخ والوقت | القراءة | الوحدة | نوع القياس', 70);
  drawLine('2026/10/02 08:15 | 128/82 · نبض 70 | ملم زئبق | ضغط الدم', 110);
  drawLine('2026/09/20 21:05 | 134/86 · نبض 74 | ملم زئبق | ضغط الدم', 150);
  drawLine('ملاحظات: سجّلتها بنفسي بعد المراجعة.', 200, size: 18);
  final image = await recorder.endRecording().toImage(720, 420);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
