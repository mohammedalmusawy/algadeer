// Phase 5D — رسائل الفراغ والخطأ وانقطاع النت موحّدة وبدون كلام تقني.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/theme/ghadeer_tokens.dart';
import 'package:ghadeer_clinic/widgets/ghadeer_state_message.dart';

Widget _app(Widget child) => MaterialApp(
  theme: GhadeerTokens.theme(),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

void main() {
  test('يميّز انقطاع النت عن باقي الأخطاء', () {
    expect(
      GhadeerStateMessage.isOfflineError(
        'SocketException: Failed host lookup: x.supabase.co',
      ),
      isTrue,
    );
    // البطء مو انقطاع — يطلع «ما گدرنا نحمّل» مو «ماكو إنترنت».
    expect(GhadeerStateMessage.isOfflineError(TimeoutException('t')), isFalse);
    expect(
      GhadeerStateMessage.isOfflineError('PostgrestException(42P01)'),
      isFalse,
    );
    expect(GhadeerStateMessage.isOfflineError(null), isFalse);
  });

  testWidgets('انقطاع النت: رسالة واضحة وزر يعيد المحاولة', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var retried = 0;
    await tester.pumpWidget(
      _app(
        GhadeerStateMessage.loadError(
          error: 'SocketException: Network is unreachable',
          what: 'المختبرات',
          onRetry: () => retried++,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('ماكو اتصال بالإنترنت'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    await tester.tap(find.text('حاول مرة ثانية'));
    expect(retried, 1);
  });

  testWidgets('خطأ خادم: بدون أسماء جداول أو SQL', (tester) async {
    await tester.pumpWidget(
      _app(
        GhadeerStateMessage.loadError(
          error: 'PostgrestException(relation does not exist)',
          what: 'مراكز الأشعة',
          onRetry: () {},
        ),
      ),
    );
    expect(find.text('ما گدرنا نحمّل مراكز الأشعة'), findsOneWidget);
    expect(find.textContaining('Supabase'), findsNothing);
    expect(find.textContaining('sql'), findsNothing);
  });

  testWidgets('فراغ بدون زر + خط كبير بعرض ٣٢٠ بدون قص', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: _app(
          const GhadeerStateMessage(
            icon: Icons.favorite_border_rounded,
            title: 'ما حفظت أي مختبر بعد',
            body: 'دوس على القلب ببطاقة أي مختبر حتى يوصلك هنا بسرعة.',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FilledButton), findsNothing);
  });

  test('النص الخافت يوصل تباين ٤٫٥:١ على الأبيض', () {
    final a = GhadeerTokens.inkFaint.computeLuminance();
    final b = GhadeerTokens.surface.computeLuminance();
    final ratio = (b + 0.05) / (a + 0.05);
    expect(ratio, greaterThanOrEqualTo(4.5));
  });

  test('حد تكبير الخط معقول', () {
    expect(GhadeerTokens.maxTextScale, inInclusiveRange(1.3, 1.5));
  });
}
