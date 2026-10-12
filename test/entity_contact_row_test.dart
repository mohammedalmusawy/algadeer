import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/entity_social_links.dart';
import 'package:ghadeer_clinic/widgets/entity_contact_actions.dart';

void main() {
  testWidgets('صف المختبر/الأشعة يظهر اتصال وواتساب بلا حساب على 360',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: EntityContactActionsRow(
                phone: '07800000000',
                whatsapp: '07800000000',
                social: EntitySocialLinks.empty,
                socialTitle: 'مواقع تواصل مختبر النور',
                onCall: _noop,
                onWhatsapp: _noop,
                onLocation: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('اتصال'), findsOneWidget);
    expect(find.text('واتساب'), findsOneWidget);
    expect(find.text('سجّل الدخول'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('بلا رقم لا يظهر اتصال خاطئ', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EntityContactActionsRow(
            phone: '',
            whatsapp: '',
            social: EntitySocialLinks.empty,
            socialTitle: 'مواقع',
          ),
        ),
      ),
    );
    expect(find.text('اتصال'), findsNothing);
    expect(find.text('واتساب'), findsNothing);
    expect(find.text('مواقع التواصل'), findsOneWidget);
  });
}

void _noop() {}
