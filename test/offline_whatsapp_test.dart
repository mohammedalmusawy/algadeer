import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/utils/contact_launch.dart';

/// بدون نت: طلب واتساب يبلّغ إن الواتساب يحتاج إنترنت ويقترح الاتصال،
/// بدل ما ينفتح الواتساب ويعلّق.
void main() {
  tearDown(() => whatsappInternetCheck = () async => true);

  testWidgets('offline WhatsApp shows the no-internet hint', (tester) async {
    whatsappInternetCheck = () async => false;
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: ghadeerMessengerKey,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => launchClinicWhatsApp('07700000000'),
              child: const Text('واتساب'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('واتساب'));
    await tester.pump();
    await tester.pump();
    expect(find.text(whatsappOfflineMessage), findsOneWidget);
    expect(whatsappOfflineMessage, contains('تتصل'));
  });
}
