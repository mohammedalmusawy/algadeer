import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/centers/service_center_kind.dart';
import 'package:ghadeer_clinic/centers/service_centers_store.dart';
import 'package:ghadeer_clinic/centers/service_center_models.dart';
import 'package:ghadeer_clinic/centers/service_center_profile_page.dart';
import 'package:ghadeer_clinic/centers/service_centers_page.dart';
import 'package:ghadeer_clinic/home/home_phase1_sections.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const optics = ServiceCenter(
    id: 'sc_optics_1',
    kind: ServiceCenterKind.optics,
    name: 'مركز النور',
    displayOrder: 2,
    phone: '07800000000',
    address: 'الشطرة',
    services: ['فحص نظر'],
  );
  const beauty = ServiceCenter(
    id: 'sc_beauty_1',
    kind: ServiceCenterKind.beauty,
    name: 'مركز الورد',
    displayOrder: 0,
    isActive: false,
  );
  const later = ServiceCenter(
    id: 'sc_optics_2',
    kind: ServiceCenterKind.optics,
    name: 'مركز الأفق',
    displayOrder: 0,
    hours: '٤ عصراً حتى ٨',
  );

  test('الزوار يرون المراكز النشطة المرتبة فقط بعد جاهزية الجدول', () {
    expect(
      serviceCentersForVisitors(
        shared: const [optics, beauty, later],
        sharedReady: false,
        kind: ServiceCenterKind.optics,
      ),
      isEmpty,
    );
    final visible = serviceCentersForVisitors(
      shared: const [optics, beauty, later],
      sharedReady: true,
      kind: ServiceCenterKind.optics,
    );
    expect(visible.map((c) => c.id), ['sc_optics_2', 'sc_optics_1']);
    expect(
      serviceCentersForAdmin(
        shared: const [optics, beauty],
        kind: ServiceCenterKind.beauty,
      ).single.isActive,
      isFalse,
    );
  });

  test('لا تُخترع خدمات أو هاتف عند تحويل المركز لنتيجة بحث', () {
    final result = later.toSearchResult();
    expect(result.canCall, isFalse);
    expect(result.canWhatsApp, isFalse);
    expect(result.phone, isNull);
    expect(result.workingHours, '٤ عصراً حتى ٨');
    expect(parseServiceLines('فحص نظر\nعدسات،إطار'), [
      'فحص نظر',
      'عدسات',
      'إطار',
    ]);
  });

  test('جملة البصريات لا تُخطف كطبيب عيون، والتجميل لا يُخطف كاختصاص', () {
    expect(ServiceCenterQuery.kindFor('العوينات وفحص البصر'), ServiceCenterKind.optics);
    expect(ServiceCenterQuery.kindFor('نظارات'), ServiceCenterKind.optics);
    expect(ServiceCenterQuery.kindFor('طبيب عيون'), isNull);
    expect(ServiceCenterQuery.kindFor('دكتور عيون'), isNull);
    expect(ServiceCenterQuery.kindFor('عيون'), isNull);
    expect(ServiceCenterQuery.kindFor('مراكز التجميل'), ServiceCenterKind.beauty);
    expect(ServiceCenterQuery.kindFor('جراحة تجميلية'), isNull);
    expect(ServiceCenterQuery.kindFor('طبيب تجميل'), isNull);
    expect(ServiceCenterQuery.kindFor('تجميل جلدي'), isNull);
    expect(ServiceCenterQuery.kindFor('تجميل'), isNull);
    expect(ServiceCenterQuery.nameHint('عوينات الرحاب'), 'الرحاب');
    // حرف الجر الملتصق بكلمة القسم لا يبقى ضمن الاسم.
    expect(ServiceCenterQuery.nameHint('اتصل بعوينات الشطرة'), 'الشطره');
    expect(ServiceCenterQuery.nameHint('دز واتساب لعوينات الرحاب'), 'الرحاب');
    expect(ServiceCenterQuery.nameHint('اتصل على مركز التجميل النور'), 'النور');
    expect(ServiceCenterQuery.nameHint('اتصل بعوينات'), isNull);
  });

  test('محلّل النية يفتح القسم لا اختصاص الطبيب', () {
    final resolver = RuleBasedIntentResolver();
    expect(
      resolver.resolve('العوينات').intent,
      AssistantIntent.findOptics,
    );
    expect(
      resolver.resolve('مراكز التجميل').intent,
      AssistantIntent.findBeauty,
    );
    expect(
      resolver.resolve('طبيب عيون').intent,
      isNot(AssistantIntent.findOptics),
    );
    expect(
      resolver.resolve('جراحة تجميلية').intent,
      isNot(AssistantIntent.findBeauty),
    );
  });

  const localOptics = ServiceCenter(
    id: 'sc_optics_local_test',
    kind: ServiceCenterKind.optics,
    name: 'مركز تجريبي — للفحص',
    bio: 'نبذة فحص محلية',
    services: ['فحص نظر محلي'],
    hours: '٩ صباحاً حتى ١ ظهراً',
    address: 'عنوان فحص محلي',
    mapUrl: 'https://maps.example.test/local-optics',
    imageUrl: 'local-test-image',
    contentRevision: 1,
  );
  const localBeauty = ServiceCenter(
    id: 'sc_beauty_local_test',
    kind: ServiceCenterKind.beauty,
    name: 'مركز تجريبي — للفحص',
    services: ['خدمة تجميل محلية'],
    hours: '٤ عصراً حتى ٨',
    address: 'عنوان فحص محلي',
    displayOrder: 0,
    contentRevision: 1,
  );

  test('تعديل المركز التجريبي يبقى بعد إعادة فتح النسخة المحلية', () {
    final edited = localOptics.copyWith(
      bio: 'بعد التعديل',
      hours: '١٠ صباحاً حتى ٢ ظهراً',
    );
    final reopened = ServiceCentersStore.decodeCache(
      jsonEncode([edited.toMap(), localBeauty.toMap()]),
    );
    expect(reopened, hasLength(2));
    expect(reopened.first.bio, 'بعد التعديل');
    expect(reopened.first.hours, '١٠ صباحاً حتى ٢ ظهراً');
    expect(reopened.first.imageUrl, 'local-test-image');
    expect(reopened.first.phone, isEmpty);
    expect(reopened.first.whatsapp, isEmpty);
    expect(reopened.last.kind, ServiceCenterKind.beauty);
    expect(reopened.last.name, 'مركز تجريبي — للفحص');
  });

  testWidgets('مركز الفحص المحلي يظهر في القائمة والبطاقة على الموبايل', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ServiceCentersPage(
          kind: ServiceCenterKind.optics,
          loadCenters: () async => const ServiceCenterSnapshot(
            centers: [localOptics],
            sharedReady: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('مركز تجريبي — للفحص'), findsOneWidget);
    expect(find.textContaining('07'), findsNothing);
    await tester.tap(find.text('مركز تجريبي — للفحص'));
    await tester.pumpAndSettle();
    expect(find.text('فحص نظر محلي'), findsOneWidget);
    expect(find.text('٩ صباحاً حتى ١ ظهراً'), findsOneWidget);
    expect(find.text('عنوان فحص محلي'), findsOneWidget);
    expect(find.text('الموقع'), findsOneWidget);
    expect(find.byKey(const Key('service_center_image')), findsOneWidget);
    expect(find.text('اتصال'), findsNothing);
    expect(find.text('واتساب'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('بطاقة التجميل التجريبية تعرض الخدمة بلا اتصال', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: ServiceCenterProfilePage(center: localBeauty)),
    );
    await tester.pumpAndSettle();
    expect(find.text('مركز تجريبي — للفحص'), findsOneWidget);
    expect(find.text('خدمة تجميل محلية'), findsOneWidget);
    expect(find.text('٤ عصراً حتى ٨'), findsOneWidget);
    expect(find.text('الموقع'), findsOneWidget);
    expect(find.byKey(const Key('service_center_image')), findsOneWidget);
    expect(find.text('اتصال'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('القائمة الفارغة على عرض الموبايل بلا مراكز وهمية', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ServiceCentersPage(
          kind: ServiceCenterKind.optics,
          loadCenters: () async => const ServiceCenterSnapshot(
            centers: [],
            sharedReady: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مراكز عوينات أو فحص بصر مضافة بعد.'), findsOneWidget);
    expect(find.textContaining('078'), findsNothing);
  });

  testWidgets('بطاقة المركز تعرض الاسم وتخفي الاتصال إن لم يوجد رقم', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: ServiceCenterProfilePage(center: later),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('مركز الأفق'), findsOneWidget);
    expect(find.text('لم تُضف خدمات لهذا المركز بعد.'), findsOneWidget);
    expect(find.text('٤ عصراً حتى ٨'), findsOneWidget);
    expect(find.text('اتصال'), findsNothing);
    expect(find.text('واتساب'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الرئيسية تعرض القسمين مع العلاج الطبيعي', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePhase1ServicesGrid(onOpen: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('العوينات وفحص البصر'), findsOneWidget);
    expect(find.text('مراكز التجميل'), findsOneWidget);
    expect(find.text('العلاج الطبيعي والتأهيل الطبي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
