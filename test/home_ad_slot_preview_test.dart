import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/ads/ad_campaign.dart';
import 'package:ghadeer_clinic/ads/widgets/home_ad_slot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AdCampaign campaign({
    bool active = true,
    DateTime? endsAt,
    String clickUrl = 'https://example.com/offer',
  }) {
    return AdCampaign(
      id: 'local-test-home',
      title: 'إعلان تجريبي محلي',
      body: 'معاينة فقط — بلا حفظ في الإنتاج',
      imageUrl: 'https://example.com/a.jpg',
      clickUrl: clickUrl,
      placement: 'home',
      isActive: active,
      endsAt: endsAt,
      displaySeconds: 0,
      priority: 10,
    );
  }

  testWidgets('حملة وهمية تظهر شارة إعلان على عرض الموبايل', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeAdSlot(testCampaign: campaign()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('إعلان'), findsOneWidget);
    expect(find.textContaining('تجريبي محلي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إيقاف الحملة الوهمية يخفي الفتحة', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeAdSlot(testCampaign: campaign(active: false)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('إعلان'), findsNothing);
  });

  testWidgets('انتهاء الحملة الوهمية يخفي الفتحة', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeAdSlot(
            testCampaign: campaign(
              endsAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('إعلان'), findsNothing);
  });
}
