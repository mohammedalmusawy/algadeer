// Phase 5C — بطاقة الهوية الموحّدة (المختبر والأشعة): ماكو تداخل ولا overflow
// على شاشات الموبايل الصغيرة، والرجوع أعلى اليمين، والصورة تنفتح بالضغط.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/widgets/entity_contact_actions.dart';
import 'package:ghadeer_clinic/widgets/ghadeer_identity_card.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('بطاقة الهوية سليمة على عرض $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var backs = 0;
      var photoTaps = 0;
      var nameTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: GhadeerIdentityCard(
                  photo: const ColoredBox(color: Colors.grey),
                  onPhotoTap: () => photoTaps++,
                  name: 'مختبر الشفاء التخصصي للتحاليل المرضية والهرمونات',
                  subtitle: 'مختبر تحاليل طبية',
                  snippet: 'نبذة قصيرة عن المختبر وخدماته بالشطرة',
                  favorite: false,
                  onToggleFavorite: () {},
                  onShare: () {},
                  onBack: () => backs++,
                  wrapName: (name) =>
                      GestureDetector(onTap: () => nameTaps++, child: name),
                  below: const GhadeerIdentityInfoBox(
                    icon: Icons.schedule_rounded,
                    label: 'ساعات العمل',
                    text: 'يومياً من 8 صباحاً إلى 9 مساءً',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      final name = find.byKey(const Key('identity_card_name'));
      final photo = find.byKey(const Key('identity_card_photo'));
      final back = find.byType(GhadeerBackButton);
      expect(name, findsOneWidget);
      expect(find.text('ساعات العمل'), findsOneWidget);

      // الكتابة يسار الصورة وما تدخل تحتها.
      expect(
        tester.getTopRight(name).dx,
        lessThanOrEqualTo(tester.getTopLeft(photo).dx),
      );
      // الرجوع على الصورة، أعلى اليمين.
      expect(tester.getCenter(back).dx, greaterThan(width / 2));

      await tester.tap(back);
      await tester.tap(name);
      await tester.tapAt(tester.getCenter(photo) + const Offset(0, 30));
      expect(backs, 1);
      expect(nameTaps, 1);
      expect(photoTaps, 1);
    });
  }
}
