import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/home/app_shell_bottom_nav.dart';
import 'package:ghadeer_clinic/home/app_shell_bridge.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_order_message.dart';
import 'package:ghadeer_clinic/search/conversation/smart_brain_turn_results.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/ghadeer_followup_context.dart';
import 'package:ghadeer_clinic/widgets/clinic_app_bar.dart';
import 'package:ghadeer_clinic/widgets/entity_contact_actions.dart';
import 'package:ghadeer_clinic/models/entity_social_links.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(AppShellBridge.unbindHomeHandlers);

  testWidgets('ClinicAppBar رجوع أعلى اليمين فقط عند canPop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: const ClinicAppBar(title: Text('الرئيسية')),
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: const ClinicAppBar(title: Text('داخلية')),
                        body: const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('clinic_app_bar_back')), findsNothing);
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clinic_app_bar_back')), findsOneWidget);
  });

  testWidgets('PackageWhatsAppAboveShell فوق الشريط بـ 360px بلا تداخل',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ColoredBox(color: Colors.white),
            bottomNavigationBar: PackageWhatsAppAboveShell(
              enabled: true,
              onPressed: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('package_whatsapp_above_shell')), findsOneWidget);
    expect(find.byKey(const Key('app_shell_nav_home')), findsOneWidget);
    expect(find.byKey(const Key('app_shell_nav_favorites')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final wa = tester.getTopLeft(find.byKey(const Key('package_whatsapp_above_shell')));
    final home = tester.getTopLeft(find.byKey(const Key('app_shell_nav_home')));
    expect(wa.dy, lessThan(home.dy));
  });

  testWidgets('تسمية مواقع التواصل مع الإبقاء على الموقع', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: EntityContactActionsRow(
              phone: '07701112233',
              whatsapp: '07701112233',
              social: EntitySocialLinks.empty,
              socialTitle: 'تواصل',
              onCall: _noop,
              onWhatsapp: _noop,
              onLocation: _noop,
            ),
          ),
        ),
      ),
    );
    expect(find.text('مواقع التواصل'), findsOneWidget);
    expect(find.text('الموقع'), findsOneWidget);
    expect(find.text('مواقع'), findsNothing);
  });

  test('مسودة الصيدلية: ترتيب مثل المختبر بلا تكرار منتجات', () {
    const b = PharmacyBundle(
      id: 'immune',
      title: 'باقة دعم المناعة',
      subtitle: 'فيتامينات',
      description: 'وصف الباقة',
      price: 38000,
      oldPrice: 50000,
      supplements: ['Vitamin D3', 'Vitamin C', 'Vitamin D3'],
      note: 'حسب تقييم الصيدلي',
    );
    final msg = PharmacyOrderMessage.buildFromBundle(
      pharmacyName: 'صيدلية رحاب',
      bundle: b,
    );
    final pharmacyAt = msg.indexOf('الصيدلية:');
    final packageAt = msg.indexOf('الباقة:');
    final descAt = msg.indexOf('الوصف:');
    final productsAt = msg.indexOf('المنتجات المشمولة');
    final priceAt = msg.indexOf('السعر الحالي:');
    final askAt = msg.indexOf('يُرجى التواصل');
    expect(pharmacyAt, greaterThanOrEqualTo(0));
    expect(packageAt, greaterThan(pharmacyAt));
    expect(descAt, greaterThan(packageAt));
    expect(productsAt, greaterThan(descAt));
    expect(priceAt, greaterThan(productsAt));
    expect(askAt, greaterThan(priceAt));
    expect(msg, contains('الخصم:'));
    expect('Vitamin D3'.allMatches(msg).length, 1);
  });

  test('dedupe يمنع بطاقة الطبيب نفسها مرتين في رد واحد', () {
    final a = SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: 'د. علي',
      subtitle: 'أطفال',
      doctorId: 'd1',
      score: 90,
    );
    final a2 = SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: 'د. علي',
      subtitle: 'أطفال',
      doctorId: 'd1',
      score: 88,
    );
    final b = SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: 'د. سارة',
      subtitle: 'أطفال',
      doctorId: 'd2',
      score: 80,
    );
    final turn = SmartBrainTurnResults();
    turn.remember([a, a2, b], turn: 3);
    expect(turn.presentedIn(3).map((r) => r.doctorId).toList(), ['d1', 'd2']);
  });

  test('رسالة الحجز تشرح الطريقة وتعرض المتاح دون تأكيد موعد', () {
    final d = SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: 'د. ب',
      subtitle: 'باطنية',
      doctorId: 'b',
      phone: '07701112233',
      whatsapp: '07701112233',
      bookingStatus: 'available',
    );
    final msg = GhadeerFollowUpContext.bookingNotAutomaticMessage(d);
    expect(msg, contains('ما أحجز موعداً تلقائياً'));
    expect(msg, contains('حسب البيانات المسجّلة'));
    expect(msg, contains('اتصال'));
    expect(msg, contains('واتساب'));
  });
}

void _noop() {}
