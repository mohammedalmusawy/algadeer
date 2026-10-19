// Phase 5C — إرشاد صورة الطبيب بالمحرّر: نصايح + تنبيه للصورة العرضية
// (بوستر/إعلان) وما يطلع التنبيه للصورة الطولية.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_photo_guide.dart';

// PNG صغيرة: 8×4 (عرضية) و 4×8 (طولية).
final _landscape = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAECAIAAAA8r+mnAAAAD0lEQVR4nGNowAEYqCcBAGDrMAFyJYzIAAAAAElFTkSuQmCC',
);
final _portrait = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAICAIAAABRUclSAAAAD0lEQVR4nGNoQAIMtOMAAMDvMAGNp+ypAAAAAElFTkSuQmCC',
);

Future<void> _pump(WidgetTester tester, Uint8List? bytes) async {
  tester.view.physicalSize = const Size(360, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: DoctorPhotoGuide(
              pickedBytes: bytes,
              preview: const ColoredBox(color: Colors.grey),
            ),
          ),
        ),
      ),
    );
    // نخلي فك الصورة يخلص.
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
}

void main() {
  testWidgets('النصايح تطلع دائماً', (tester) async {
    await _pump(tester, null);
    expect(find.text('مو بوستر أو إعلان بيه كتابة'), findsOneWidget);
    expect(
      find.byKey(const Key('doctor_photo_landscape_warning')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('صورة عرضية ← تنبيه', (tester) async {
    await _pump(tester, _landscape);
    expect(
      find.byKey(const Key('doctor_photo_landscape_warning')),
      findsOneWidget,
    );
  });

  testWidgets('صورة طولية ← بدون تنبيه', (tester) async {
    await _pump(tester, _portrait);
    expect(
      find.byKey(const Key('doctor_photo_landscape_warning')),
      findsNothing,
    );
  });
}
