import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/patient_health/attachment_view.dart';
import 'package:ghadeer_clinic/patient_health/follow_up_card.dart';
import 'package:ghadeer_clinic/patient_health/follow_up_card_page.dart';
import 'package:ghadeer_clinic/patient_health/follow_up_insights.dart';
import 'package:ghadeer_clinic/patient_health/follow_up_target_store.dart';
import 'package:ghadeer_clinic/patient_health/patient_health_models.dart';
import 'package:ghadeer_clinic/patient_health/patient_health_repository.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// بطاقة المتابعة: ملخص، رسم، صباح/مساء، توقيت السكر، مدى الطبيب،
/// حقائق الثلاسيميا، قراءة سريعة، وإرسالها للطبيب.
final now = DateTime(2026, 10, 13, 20);

PatientCondition _cond(String id, ConditionKind kind) => PatientCondition(
  id: id,
  userId: 'u',
  kind: kind,
  createdAt: now,
  updatedAt: now,
);

BpReading _bp(int s, int d, DateTime at, {int? pulse}) => BpReading(
  id: 'bp-$s-$d-${at.millisecondsSinceEpoch}',
  userId: 'u',
  conditionId: 'bp',
  systolic: s,
  diastolic: d,
  pulse: pulse,
  measuredAt: at,
);

GlucoseReading _g(double v, GlucoseUnit unit, GlucoseTiming t, DateTime at) =>
    GlucoseReading(
      id: 'g-$v-${at.millisecondsSinceEpoch}',
      userId: 'u',
      conditionId: 'dm',
      value: v,
      unit: unit,
      timing: t,
      measuredAt: at,
    );

FollowUpSelection _sel(
  String id, {
  FollowUpPeriod period = FollowUpPeriod.days30,
}) => FollowUpSelection(conditionId: id, period: period, issuedAt: now);

void main() {
  group('ملخص الضغط', () {
    final snapshot = PatientHealthSnapshot(
      conditions: [_cond('bp', ConditionKind.hypertension)],
      bpReadings: [
        _bp(120, 80, DateTime(2026, 10, 10, 8), pulse: 70),
        _bp(140, 90, DateTime(2026, 10, 11, 21), pulse: 80),
        _bp(130, 85, DateTime(2026, 10, 12, 9)),
        // خارج فترة 30 يوم:
        _bp(200, 120, DateTime(2026, 8, 1, 9)),
        // مستخدم ثاني ما يدخل:
        BpReading(
          id: 'x',
          userId: 'other',
          conditionId: 'bp',
          systolic: 190,
          diastolic: 100,
          measuredAt: DateTime(2026, 10, 12, 10),
        ),
      ],
    );

    test('الكل + صباحاً + مساءً، والأرقام كما هي', () {
      final i = buildFollowUpInsights(
        userId: 'u',
        snapshot: snapshot,
        selection: _sel('bp'),
      );
      final rows = i.summaries.single.rows;
      expect(rows.map((r) => r.label), ['الكل', 'صباحاً', 'مساءً']);
      final all = rows.first;
      expect(all.count, 3);
      expect(all.average, '130/85');
      expect(all.lowest, '120/80');
      expect(all.highest, '140/90');
      expect(all.latest, '130/85');
      expect(rows[1].count, 2);
      expect(rows[2].count, 1);
      expect(i.facts.single.value, contains('75'));
      expect(i.charts.single.points.length, 3);
      expect(i.outOfTargetCount, 0);
    });

    test('بلا مدى من الطبيب ما نعلّم أي قراءة', () {
      final i = buildFollowUpInsights(
        userId: 'u',
        snapshot: snapshot,
        selection: _sel('bp'),
      );
      expect(i.charts.single.points.any((p) => p.outOfTarget), isFalse);
    });

    test('مدى الطبيب يعلّم القراءات اللي برّاه فقط', () {
      final i = buildFollowUpInsights(
        userId: 'u',
        snapshot: snapshot,
        selection: _sel('bp'),
        target: const FollowUpTarget(high: 135, secondHigh: 88),
      );
      expect(i.outOfTargetCount, 1);
      expect(i.charts.single.targetHigh, 135);
    });

    test('إخفاء القراءات يخفي الملخص', () {
      final i = buildFollowUpInsights(
        userId: 'u',
        snapshot: snapshot,
        selection: FollowUpSelection(
          conditionId: 'bp',
          period: FollowUpPeriod.days30,
          issuedAt: now,
          includeMeasurements: false,
        ),
      );
      expect(i.isEmpty, isTrue);
    });
  });

  group('ملخص السكر', () {
    final snapshot = PatientHealthSnapshot(
      conditions: [_cond('dm', ConditionKind.diabetes)],
      glucoseReadings: [
        _g(
          100,
          GlucoseUnit.mgDl,
          GlucoseTiming.fasting,
          DateTime(2026, 10, 9, 7),
        ),
        _g(
          120,
          GlucoseUnit.mgDl,
          GlucoseTiming.fasting,
          DateTime(2026, 10, 10, 7),
        ),
        _g(
          180,
          GlucoseUnit.mgDl,
          GlucoseTiming.afterMeal,
          DateTime(2026, 10, 10, 15),
        ),
        _g(
          6.5,
          GlucoseUnit.mmolL,
          GlucoseTiming.random,
          DateTime(2026, 10, 11, 18),
        ),
      ],
    );

    test('كل وحدة لحالها، ومقسم حسب وقت القياس', () {
      final i = buildFollowUpInsights(
        userId: 'u',
        snapshot: snapshot,
        selection: _sel('dm'),
      );
      expect(i.summaries.length, 2);
      final mg = i.summaries.first;
      expect(mg.unit, glucoseUnitLabel(GlucoseUnit.mgDl));
      expect(mg.rows.first.count, 3);
      expect(mg.rows.first.average, '133.3');
      final fasting = mg.rows.firstWhere(
        (r) => r.label == glucoseTimingLabel(GlucoseTiming.fasting),
      );
      expect(fasting.count, 2);
      expect(fasting.average, '110');
      expect(i.summaries.last.rows.first.latest, '6.5');
      // رسم واحد فقط (وحدة mmol/L بقراءة وحدة ما تكفي لخط).
      expect(i.charts.length, 1);
    });

    test('مدى السكر بوحدة ما ينطبق على وحدة ثانية', () {
      final i = buildFollowUpInsights(
        userId: 'u',
        snapshot: snapshot,
        selection: _sel('dm'),
        target: const FollowUpTarget(low: 4, high: 6, unit: GlucoseUnit.mmolL),
      );
      // القراءات بـ mg/dL ما تنقارن بمدى mmol/L.
      expect(i.outOfTargetCount, 1);
      expect(i.charts.single.targetHigh, isNull);
    });
  });

  test('الثلاسيميا: آخر نقل دم، المعدّل، الموعد القادم', () {
    ThalassemiaEvent e(ThalassemiaEventKind k, DateTime at, [String t = '']) =>
        ThalassemiaEvent(
          id: '${k.name}-${at.millisecondsSinceEpoch}',
          userId: 'u',
          conditionId: 'th',
          kind: k,
          title: t.isEmpty ? 'حدث' : t,
          occurredAt: at,
        );
    final snapshot = PatientHealthSnapshot(
      conditions: [_cond('th', ConditionKind.thalassemia)],
      events: [
        e(ThalassemiaEventKind.transfusion, DateTime(2026, 9, 1, 10)),
        e(ThalassemiaEventKind.transfusion, DateTime(2026, 9, 22, 10)),
        e(ThalassemiaEventKind.transfusion, DateTime(2026, 10, 13, 10)),
        e(
          ThalassemiaEventKind.appointment,
          DateTime(2026, 10, 20, 9),
          'مراجعة الدم',
        ),
      ],
    );
    final i = buildFollowUpInsights(
      userId: 'u',
      snapshot: snapshot,
      selection: _sel('th', period: FollowUpPeriod.all),
    );
    final byLabel = {for (final f in i.facts) f.label: f.value};
    expect(byLabel['آخر نقل دم'], 'اليوم');
    expect(byLabel['المعدّل بين كل نقل والثاني'], '21 يوم');
    expect(byLabel['عدد نقل الدم بالفترة'], '3');
    expect(byLabel['الموعد القادم'], contains('مراجعة الدم'));
  });

  test('isMorningReading: 4 الصبح لحد 11:59', () {
    expect(isMorningReading(DateTime(2026, 1, 1, 4)), isTrue);
    expect(isMorningReading(DateTime(2026, 1, 1, 11, 59)), isTrue);
    expect(isMorningReading(DateTime(2026, 1, 1, 12)), isFalse);
    expect(isMorningReading(DateTime(2026, 1, 1, 3)), isFalse);
  });

  test('التحقق من مدى الطبيب', () {
    expect(
      validateFollowUpTarget(const FollowUpTarget(low: 90, high: 140)),
      isNull,
    );
    expect(
      validateFollowUpTarget(const FollowUpTarget(low: 140, high: 90)),
      isNotNull,
    );
    expect(validateFollowUpTarget(const FollowUpTarget(high: -1)), isNotNull);
  });

  test('مدى الطبيب ينحفظ على الجهاز لكل مرض', () async {
    SharedPreferences.setMockInitialValues({});
    const store = FollowUpTargetStore();
    await store.save(
      'u',
      'dm',
      const FollowUpTarget(low: 80, high: 130, unit: GlucoseUnit.mgDl),
    );
    final back = await store.load('u', 'dm');
    expect(back.low, 80);
    expect(back.high, 130);
    expect(back.unit, GlucoseUnit.mgDl);
    expect((await store.load('u', 'bp')).isEmpty, isTrue);
    await store.save('u', 'dm', const FollowUpTarget());
    expect((await store.load('u', 'dm')).isEmpty, isTrue);
  });

  group('أرسلها لطبيبي', () {
    test('أطباء بأرقام صالحة فقط، والرسالة بلا أرقام صحية', () {
      final list = followUpDoctorContacts(const [
        SmartSearchResult(
          type: SmartSearchResultType.doctor,
          title: 'د. علي',
          subtitle: 'باطنية',
          whatsapp: '07701234567',
        ),
        SmartSearchResult(
          type: SmartSearchResultType.doctor,
          title: 'د. بلا رقم',
          subtitle: 'عيون',
        ),
        SmartSearchResult(
          type: SmartSearchResultType.doctor,
          title: 'أحمد',
          subtitle: 'قلبية',
          phone: '07801234567',
        ),
      ]);
      expect(list.map((d) => d.name), ['أحمد', 'د. علي']);
      expect(
        followUpDoctorMessage(doctorName: 'أحمد', conditionTitle: 'الضغط'),
        startsWith('مرحباً دكتور أحمد،'),
      );
      expect(
        followUpDoctorMessage(doctorName: 'د. علي', conditionTitle: 'الضغط'),
        startsWith('مرحباً د. علي،'),
      );
    });

    testWidgets('اختيار الطبيب يفتح واتساب برسالة جاهزة', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final repo = MemoryPatientHealthRepository('u', PatientFileDatabase());
      await repo.saveConsent(displayName: 'أحمد', at: now);
      await repo.saveCondition(_cond('bp', ConditionKind.hypertension));
      String? openedNumber;
      String? openedText;
      await tester.pumpWidget(
        MaterialApp(
          home: FollowUpCardPage(
            userId: 'u',
            snapshot: await repo.load(),
            repository: repo,
            store: AttachmentByteStore(),
            now: () => now,
            loadDoctors: () async => const [
              SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'د. علي',
                subtitle: 'باطنية',
                whatsapp: '07701234567',
              ),
            ],
            openWhatsApp: (n, t) async {
              openedNumber = n;
              openedText = t;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('follow-up-send-doctor')),
      );
      await tester.tap(find.byKey(const Key('follow-up-send-doctor')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('doctor-pick-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-doctor-open-chat')));
      await tester.pumpAndSettle();
      expect(openedNumber, '07701234567');
      expect(openedText, contains('بطاقة متابعة'));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('قراءة سريعة تنحفظ وتظهر بالملخص والرسم', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final repo = MemoryPatientHealthRepository('u', PatientFileDatabase());
    await repo.saveConsent(displayName: 'أحمد', at: now);
    await repo.saveCondition(_cond('bp', ConditionKind.hypertension));
    await repo.saveBp(_bp(128, 82, DateTime(2026, 10, 12, 8)));
    await tester.pumpWidget(
      MaterialApp(
        home: FollowUpCardPage(
          userId: 'u',
          snapshot: await repo.load(),
          repository: repo,
          store: AttachmentByteStore(),
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('follow-up-chart')), findsNothing);
    await tester.tap(find.byKey(const Key('follow-up-quick-reading')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quick-bp-systolic')), '١٣٦');
    await tester.enterText(find.byKey(const Key('quick-bp-diastolic')), '88');
    await tester.tap(find.byKey(const Key('quick-reading-save')));
    await tester.pumpAndSettle();
    expect((await repo.load()).bpReadings.length, 2);
    expect(find.byKey(const Key('follow-up-chart')), findsOneWidget);
    expect(find.text('ملخص الضغط (ملم زئبق)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('البطاقة مع الملخص والرسم بعرض الموبايل بلا قص', (tester) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final snapshot = PatientHealthSnapshot(
      conditions: [_cond('bp', ConditionKind.hypertension)],
      bpReadings: [
        for (var d = 1; d <= 25; d++)
          _bp(
            120 + d,
            78 + d % 7,
            DateTime(2026, 9, 20 + d % 10, d.isEven ? 8 : 21),
          ),
      ],
    );
    final selection = _sel('bp');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 340,
              child: FollowUpCardView(
                content: buildFollowUpCard(
                  userId: 'u',
                  snapshot: snapshot,
                  selection: selection,
                ),
                insights: buildFollowUpInsights(
                  userId: 'u',
                  snapshot: snapshot,
                  selection: selection,
                  target: const FollowUpTarget(high: 135),
                ),
                conditionKind: ConditionKind.hypertension,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('follow-up-card-header')), findsOneWidget);
    expect(find.byKey(const Key('follow-up-chart')), findsOneWidget);
    expect(find.byKey(const Key('follow-up-out-of-target')), findsOneWidget);
    expect(find.text('بيانات أدخلها المريض'), findsOneWidget);
  });
}
