import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/patient_health/attachment_view.dart';
import 'package:ghadeer_clinic/patient_health/follow_up_card_page.dart';
import 'package:ghadeer_clinic/patient_health/follow_up_reminders.dart';
import 'package:ghadeer_clinic/patient_health/patient_health_models.dart';
import 'package:ghadeer_clinic/patient_health/patient_health_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تذكير القياس اليومي من بطاقة المتابعة: محلي، بلا اسم المرض بالإشعار.
class _FakeScheduler implements ReminderScheduler {
  final scheduled = <int, ReminderTime>{};
  final cancelled = <int>[];
  bool permission = true;

  @override
  bool get isSupported => true;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> scheduleDaily(int id, ReminderTime time) async {
    scheduled[id] = time;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ReminderTime: قراءة وعرض عراقي', () {
    expect(ReminderTime.parse('08:30'), const ReminderTime(8, 30));
    expect(ReminderTime.parse('25:00'), isNull);
    expect(ReminderTime.parse('x'), isNull);
    expect(const ReminderTime(8, 5).label, '8:05 صباحاً');
    expect(const ReminderTime(20, 0).label, '8:00 مساءً');
    expect(const ReminderTime(0, 15).label, '12:15 صباحاً');
    expect(const ReminderTime(12, 0).label, '12:00 مساءً');
  });

  test('أقرب موعد: اليوم إذا بعده ما فات، وإلا باجر', () {
    final now = DateTime(2026, 10, 13, 9, 0);
    expect(
      nextDailyFire(now, const ReminderTime(20, 0)),
      DateTime(2026, 10, 13, 20),
    );
    expect(
      nextDailyFire(now, const ReminderTime(8, 0)),
      DateTime(2026, 10, 14, 8),
    );
    expect(
      nextDailyFire(now, const ReminderTime(9, 0)),
      DateTime(2026, 10, 14, 9),
    );
  });

  test('المعرّف ثابت ومختلف لكل مرض وكل وقت', () {
    final a0 = reminderNotificationId('u', 'bp', 0);
    expect(reminderNotificationId('u', 'bp', 0), a0);
    expect(reminderNotificationId('u', 'bp', 1), isNot(a0));
    expect(reminderNotificationId('u', 'dm', 0), isNot(a0));
    expect(a0, greaterThanOrEqualTo(0));
    expect(a0, lessThan(0x7fffffff));
  });

  test('الإشعار ما يكشف اسم المرض', () {
    for (final word in ['ضغط', 'سكر', 'ثلاسيميا']) {
      expect(reminderNotificationTitle, isNot(contains(word)));
      expect(reminderNotificationBody, isNot(contains(word)));
    }
  });

  test('الحفظ يلغي القديم ويجدول الجديد بلا تكرار ولحد 3', () async {
    final s = _FakeScheduler();
    const store = FollowUpReminderStore();
    await applyFollowUpReminders(
      scheduler: s,
      store: store,
      userId: 'u',
      conditionId: 'bp',
      times: const [
        ReminderTime(20, 0),
        ReminderTime(8, 0),
        ReminderTime(8, 0),
        ReminderTime(14, 0),
        ReminderTime(22, 0),
      ],
    );
    expect(s.scheduled.length, 3);
    expect(await store.load('u', 'bp'), const [
      ReminderTime(8, 0),
      ReminderTime(14, 0),
      ReminderTime(20, 0),
    ]);
    await applyFollowUpReminders(
      scheduler: s,
      store: store,
      userId: 'u',
      conditionId: 'bp',
      times: const [],
    );
    expect(s.scheduled, isEmpty);
    expect(await store.load('u', 'bp'), isEmpty);
  });

  testWidgets('من البطاقة: إضافة تذكير وحفظه', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final now = DateTime(2026, 10, 13, 20);
    final repo = MemoryPatientHealthRepository('u', PatientFileDatabase());
    await repo.saveConsent(displayName: 'أحمد', at: now);
    await repo.saveCondition(
      PatientCondition(
        id: 'bp',
        userId: 'u',
        kind: ConditionKind.hypertension,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final scheduler = _FakeScheduler();
    await tester.pumpWidget(
      MaterialApp(
        home: FollowUpCardPage(
          userId: 'u',
          snapshot: await repo.load(),
          repository: repo,
          store: AttachmentByteStore(),
          now: () => now,
          reminderScheduler: scheduler,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('follow-up-reminders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-add')));
    await tester.pumpAndSettle();
    // منتقي الوقت: نقبل الوقت المقترح (8:00 صباحاً).
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-08:00')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reminder-save')));
    await tester.pumpAndSettle();
    expect(scheduler.scheduled.values, [const ReminderTime(8, 0)]);
    expect(find.textContaining('تذكير: 8:00 صباحاً'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
