// Phase 5B — الشكل الجديد «الماي الصافي»: الرئيسية والشريط والبطاقات بدون قص.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/home/app_shell_bottom_nav.dart';
import 'package:ghadeer_clinic/home/home_phase1_sections.dart';
import 'package:ghadeer_clinic/theme/ghadeer_tokens.dart';

Widget _app(Widget child) => MaterialApp(
  theme: GhadeerTokens.theme(),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

void main() {
  for (final width in [320.0, 360.0, 430.0]) {
    testWidgets('رأس الرئيسية + البحث بعرض $width بدون قص', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var searched = 0;
      var mic = 0;
      var bell = 0;
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: Column(
              children: [
                HomePhase1Header(
                  onNotifications: () => bell++,
                  onLogoTap: () {},
                  search: HomePhase1SearchRow(
                    onSearchTap: () => searched++,
                    onMicTap: () => mic++,
                  ),
                ),
                HomePhase1AskBanner(onTalk: () {}),
                const HomeSectionTitle('الأقسام'),
                HomePhase1ServicesGrid(onOpen: (_) {}),
                const HomePhase1HealthTip(title: 'رسالة', body: 'نص'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('الغدير'), findsOneWidget);
      await tester.tap(find.text('ابحث عن طبيب أو اختصاص أو خدمة ...'));
      await tester.tap(find.byIcon(Icons.mic_rounded).first);
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      expect(searched, 1);
      expect(mic, 1);
      expect(bell, 1);
    });
  }

  testWidgets('شبكة الأقسام: ٣ أعمدة بالموبايل وكل الأقسام تفتح', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    await tester.pumpWidget(_app(HomePhase1ServicesGrid(onOpen: opened.add)));
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('الأطباء'));
    final second = tester.getTopLeft(find.text('الأشعة'));
    final fourth = tester.getTopLeft(
      find.text('العلاج الطبيعي والتأهيل الطبي'),
    );
    expect(first.dy, second.dy, reason: 'نفس الصف');
    expect(fourth.dy, greaterThan(first.dy), reason: 'الرابع بصف جديد');
    for (final item in HomePhase1ServicesGrid.items) {
      await tester.tap(find.text(item.title));
    }
    expect(opened, HomePhase1ServicesGrid.items.map((e) => e.id).toList());
    expect(tester.takeException(), isNull);
  });

  testWidgets('شريط التنقل: أزرار ٤٨+ وارتفاع أقل من ١٠٠', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(
      _app(
        Align(
          alignment: Alignment.bottomCenter,
          child: AppShellBottomNav(activeIndex: 0, onSelect: (i) => tapped = i),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bar = tester.getSize(find.byType(AppShellBottomNav));
    expect(bar.height, lessThan(100));
    final home = tester.getSize(find.byKey(const Key('app_shell_nav_home')));
    expect(home.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byKey(const Key('app_shell_nav_favorites')));
    expect(tapped, 2);
  });
}
