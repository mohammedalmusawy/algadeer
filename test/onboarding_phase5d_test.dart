// Phase 5D — شاشة الترحيب الأولى بهوية «منصة الغدير» وتوضيح ليش نسأل الاسم.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/onboarding/user_name_onboarding_page.dart';
import 'package:ghadeer_clinic/theme/ghadeer_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scale in [1.0, 1.35]) {
    testWidgets('الترحيب بعرض ٣٢٠ وخط ×$scale بدون قص', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var finished = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: GhadeerTokens.theme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(scale),
            ),
            child: UserNameOnboardingPage(onFinished: () => finished++),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('onboarding_logo')), findsOneWidget);
      expect(find.text('أهلًا بك في منصة الغدير'), findsOneWidget);
      expect(find.textContaining('يبقى على جهازك'), findsOneWidget);
      // ما نذكر «عيادة الغدير» — التطبيق منصة.
      expect(find.textContaining('عيادة الغدير'), findsNothing);
      await tester.ensureVisible(find.text('تخطي الآن'));
      await tester.tap(find.text('تخطي الآن'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    });
  }
}
