// Phase 5C — هياكل التحميل: تنرسم بدون overflow على أصغر موبايل، وتحترم
// «تقليل الحركة»، وتعلن «جاري التحميل» لقارئ الشاشة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/widgets/ghadeer_skeleton.dart';

void main() {
  testWidgets('هياكل التحميل سليمة على 320 وتعلن جاري التحميل', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: GhadeerSkeletonList()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('ghadeer_skeleton_list')), findsOneWidget);
    expect(find.bySemanticsLabel('جاري التحميل'), findsOneWidget);
  });

  testWidgets('تقليل الحركة يوقف النبض (pumpAndSettle يخلص)', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: GhadeerSkeletonList())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ghadeer_skeleton_list')), findsOneWidget);
  });
}
