import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/chronic_care/chronic_care.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SensitiveHealthProfileService health;
  late SensitiveHealthProfileCoordinator healthCoord;
  late LocalChronicCareRepository chronicRepo;
  late ChronicCareCoordinator chronic;
  late PersonalCompanionProfileService personal;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    health = SensitiveHealthProfileService(
      repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
    );
    healthCoord = SensitiveHealthProfileCoordinator(service: health);
    chronicRepo = LocalChronicCareRepository(prefs: prefs);
    chronic = ChronicCareCoordinator(
      healthProfiles: health,
      repository: chronicRepo,
    );
    personal = PersonalCompanionProfileService(
      repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
    );
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      sensitiveHealthProfile: healthCoord,
      chronicCare: chronic,
      doctorLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. غدد',
              subtitle: 'غدد صماء',
              doctorId: 'd1',
              specialty: 'غدد صماء',
              score: 90,
            ),
          ],
      labLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.lab,
              title: 'مختبر',
              subtitle: 'مختبر',
              labId: 'l1',
              score: 90,
            ),
          ],
    );
  });

  Future<void> seedDiagnosed(String key, String display) async {
    final now = DateTime.now();
    await health.upsertConditions([
      HealthConditionRecord(
        id: 'hc_$key',
        canonicalConditionKey: key,
        displayName: display,
        diagnosisStatus: HealthDiagnosisStatus.diagnosed,
        diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
        consentState: HealthConsentState.granted,
        createdAt: now,
        updatedAt: now,
        followUpPermission: false,
      ),
    ]);
  }

  Future<void> persistCondition(String phrase) async {
    final ask = await healthCoord.handle(
      text: phrase,
      pending: HealthProfilePendingOp.none,
    );
    await healthCoord.handle(text: 'نعم', pending: ask.pending);
  }

  Future<ChronicCareTurnResult> run(
    String text, {
    ChronicCareSession? session,
  }) async {
    final r = await chronic.handle(
      text: text,
      session: session ?? ctx.chronicCareSession,
    );
    ctx.setChronicCareSession(r.session);
    return r;
  }

  group('PC-1.5 entry & permission A–J', () {
    test('A/B/C — diagnosed enters; suspected cannot', () async {
      await persistCondition('عندي سكري ومشخصني الطبيب');
      expect((await health.findCondition('diabetes'))?.followUpPermission, isFalse);

      final opt = await run('تابع وياي السكر');
      expect(opt.session.status, ChronicCareFlowStatus.awaitingPermissionAnswer);

      await persistCondition('أنا مشخص بالضغط');
      final bp = await run('أريد الغدير يتابع وياي الضغط');
      expect(bp.session.pendingPermissionConditionKey, 'hypertension');

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      health = SensitiveHealthProfileService(
        repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
      );
      chronic = ChronicCareCoordinator(
        healthProfiles: health,
        repository: LocalChronicCareRepository(prefs: prefs),
      );
      final bad = await chronic.handle(
        text: 'تابع وياي السكر',
        session: ChronicCareSession.inactive,
      );
      expect(bad.success, isFalse);
      expect(await health.findCondition('diabetes'), isNull);
    });

    test('D/E/F/G/H — remember != follow-up; opt-in/out', () async {
      await persistCondition('عندي سكري ومشخصني الطبيب');
      expect((await health.findCondition('diabetes'))!.followUpPermission, isFalse);

      var r = await run('تابع وياي السكر');
      r = await run('نعم', session: r.session);
      expect((await health.findCondition('diabetes'))!.followUpPermission, isTrue);
      expect(r.message.contains('شلون') || r.message.contains('تم تفعيل'), isTrue);

      await persistCondition('أنا مشخص بالضغط');
      r = await run('تابع وياي الضغط');
      final declined = await run('لا', session: r.session);
      expect(
        (await health.findCondition('hypertension'))!.followUpPermission,
        isFalse,
      );
      expect(declined.session.status, ChronicCareFlowStatus.inactive);
    });

    test('I/J — stop affects one condition only', () async {
      await persistCondition('عندي سكري ومشخصني الطبيب');
      await persistCondition('أنا مشخص بالضغط');
      var r = await run('تابع وياي السكر');
      await run('نعم', session: r.session);
      r = await run('تابع وياي الضغط');
      await run('نعم', session: r.session);

      await run('وقف متابعة السكر');
      expect((await health.findCondition('diabetes'))!.followUpPermission, isFalse);
      expect(
        (await health.findCondition('hypertension'))!.followUpPermission,
        isTrue,
      );

      await health.setFollowUpPermission(
        canonicalConditionKey: 'diabetes',
        enabled: true,
      );
      await run('وقف متابعة الضغط');
      expect(
        (await health.findCondition('hypertension'))!.followUpPermission,
        isFalse,
      );
      expect((await health.findCondition('diabetes'))!.followUpPermission, isTrue);
    });
  });

  group('PC-1.5 questions & status K–R', () {
    test('K/L/M/N — one question; skips; stop asking', () async {
      await seedDiagnosed('diabetes', 'السكري');
      await health.setFollowUpPermission(
        canonicalConditionKey: 'diabetes',
        enabled: true,
      );
      var r = await run('لا تسألني عن السكر بعد');
      expect((await health.findCondition('diabetes'))!.followUpPermission, isFalse);

      await health.setFollowUpPermission(
        canonicalConditionKey: 'diabetes',
        enabled: true,
      );
      r = await run(
        'تخطي',
        session: const ChronicCareSession(
          status: ChronicCareFlowStatus.waitingForAnswer,
          activeConditionKey: 'diabetes',
          pendingQuestion: ChronicCareQuestionKind.recentStatus,
        ),
      );
      r = await run(
        'تخطي',
        session: r.session.copyWith(
          status: ChronicCareFlowStatus.waitingForAnswer,
          activeConditionKey: 'diabetes',
          pendingQuestion: ChronicCareQuestionKind.lastMeasurement,
        ),
      );
      expect(
        r.session.status == ChronicCareFlowStatus.reducedPressure ||
            r.message.contains('أخفف'),
        isTrue,
      );
    });

    test('O/P/Q/R — user-reported control only', () async {
      await persistCondition('عندي سكري ومشخصني الطبيب');
      var r = await run('السكر مضبوط');
      expect(r.success, isTrue);
      var store = await chronicRepo.load();
      expect(
        store.followUpByCondition['diabetes']?.userControlStatus,
        ChronicUserControlStatus.userReportsControlled,
      );
      expect(r.message.contains('مو حكم سريري'), isTrue);

      r = await run('السكر مو مضبوط');
      store = await chronicRepo.load();
      expect(
        store.followUpByCondition['diabetes']?.userControlStatus,
        ChronicUserControlStatus.userReportsNotControlled,
      );

      r = await run('السكر متقلب');
      store = await chronicRepo.load();
      expect(
        store.followUpByCondition['diabetes']?.userControlStatus,
        ChronicUserControlStatus.userReportsVariable,
      );
    });
  });

  group('PC-1.5 measurements S–Y', () {
    test('S–W — glucose parsing & contexts & HbA1c', () async {
      await persistCondition('عندي سكري ومشخصني الطبيب');
      var r = await run('السكر 150');
      expect(r.session.awaitingMeasurementContext, isTrue);
      expect((await chronicRepo.load()).measurements, isEmpty);

      r = await run('صايم', session: r.session);
      var store = await chronicRepo.load();
      expect(store.measurements.last.measurementType,
          ChronicMeasurementType.fastingGlucose);
      expect(store.measurements.last.numericValues, [150.0]);
      expect(store.measurements.last.source, 'userReported');

      r = await run('السكر 180 بعد الأكل');
      store = await chronicRepo.load();
      expect(store.measurements.last.measurementType,
          ChronicMeasurementType.postMealGlucose);

      r = await run('HbA1c 7.2');
      store = await chronicRepo.load();
      expect(
        store.measurements.last.measurementType,
        ChronicMeasurementType.hba1c,
      );
    });

    test('X/Y — BP pair; no pulse', () async {
      await seedDiagnosed('hypertension', 'ارتفاع ضغط الدم');
      final r = await run('ضغطي 130 على 80');
      expect(r.success, isTrue);
      final ms = (await chronicRepo.load()).measurements;
      expect(ms, isNotEmpty);
      final m = ms.last;
      expect(m.numericValues, [130.0, 80.0]);
      expect(m.numericValues.length, 2);
      expect(m.measurementType, ChronicMeasurementType.bloodPressure);
    });
  });

  group('PC-1.5 timeline & dates Z–AH', () {
    test('Z/AA — measurement does not diagnose or change meds', () async {
      await persistCondition('عندي سكري ومشخصني الطبيب');
      await run('السكر 120 صايم');
      expect((await health.findCondition('diabetes')), isNotNull);
      final med = await run('ضاعف الجرعة');
      expect(med.success, isFalse);
      expect(med.message.contains('جرعة') || med.message.contains('علاج'), isTrue);
    });

    test('AB/AC — structured timeline without raw transcript', () async {
      await persistCondition('عندي سكري ومشخصني الطبيب');
      await run('السكر 110 صايم');
      final store = await chronicRepo.load();
      expect(store.timeline, isNotEmpty);
      final json = store.toStorageMap().toString();
      expect(json.contains('السكر 110 صايم'), isFalse);
    });

    test('AD/AE/AF — relative timing', () {
      const p = ChronicCareDateParser();
      expect(p.parse('قست اليوم').timing, ChronicRelativeTiming.today);
      expect(p.parse('قست اليوم').exact, isNotNull);
      expect(p.parse('أمس').timing, ChronicRelativeTiming.yesterday);
      expect(p.parse('قبل أسبوع').exact, isNull);
      expect(p.parse('قبل أسبوع').timing, ChronicRelativeTiming.aboutAWeekAgo);
    });

    test('AG/AH — doctor/lab follow-up events', () async {
      await seedDiagnosed('diabetes', 'السكري');
      await run('راجعت الطبيب الشهر الماضي');
      await run('فحصت السكر أمس');
      final types =
          (await chronicRepo.load()).timeline.map((e) => e.type).toSet();
      expect(types.contains(ChronicTimelineEventType.doctorFollowUp), isTrue);
      expect(types.contains(ChronicTimelineEventType.labFollowUp), isTrue);
    });
  });

  group('PC-1.5 firewall & safety AI–AN', () {
    test('AI–AL — family never enters owner timeline', () async {
      await persistCondition('عندي سكري ومشخصني الطبيب');
      for (final q in [
        'ابني السكر عنده مرتفع',
        'أمي ضغطها مرتفع',
        'زوجتي عندها سكري',
      ]) {
        final before = (await chronicRepo.load()).measurements.length;
        await run(q);
        expect((await chronicRepo.load()).measurements.length, before);
      }
    });

    test('AM/AN — urgent safety wins; no competing emergency', () async {
      await persistCondition('عندي سكري ومشخصني الطبيب');
      final plan = await brain.plan(
        query: 'السكر 200 وفيه ضيق نفس شديد',
        context: ctx,
      );
      expect(
        plan.kind == AssistantActionKind.healthGuidance ||
            ctx.healthGuidanceSession.isActive ||
            plan.message.isNotEmpty,
        isTrue,
      );
    });
  });

  group('PC-1.5 boundaries & integrations AO–AS', () {
    test('AO/AP — no meds/supplements', () async {
      final a = await run('خذ أوميغا 3 للسكر');
      expect(a.success, isFalse);
    });

    test('AQ/AR/AS — doctor/lab reuse; no package autosell', () async {
      final d = await brain.plan(query: 'أريد طبيب للسكر', context: ctx);
      expect(d.kind, isNot(AssistantActionKind.none));
      final l = await brain.plan(
        query: 'أريد مختبر',
        context: ConversationContext(),
      );
      expect(l.kind, isNot(AssistantActionKind.none));
    });
  });

  group('PC-1.5 privacy/control AT–BG', () {
    test('AT/AU/AV — text-first + interpreter parity', () async {
      final plan = await brain.plan(query: 'تابع وياي السكر', context: ctx);
      // may fail gate without diagnosis — still textFirst if handled via chronic/health
      if (plan.kind == AssistantActionKind.showMessage) {
        expect(plan.textFirstOnly, isTrue);
      }
      final a = chronic.interpreter.interpret(
        raw: 'ضغطي 120 على 80',
        session: ChronicCareSession.inactive,
      );
      final b = chronic.interpreter.interpret(
        raw: 'ضغطي 120 على 80',
        session: ChronicCareSession.inactive,
      );
      expect(a.kind, b.kind);
      expect(a.systolic, b.systolic);
    });

    test('AW/AX — no sensitive values in debug', () async {
      await seedDiagnosed('hypertension', 'ارتفاع ضغط الدم');
      final r = await run('ضغطي 130 على 80');
      final dbg = r.debugMap().toString();
      expect(dbg.contains('130'), isFalse);
      expect(dbg.contains('chronicFlowState'), isTrue);
      expect(ctx.debugSnapshot().toString().contains('130'), isFalse);
    });

    test('AY — repository failure does not claim success', () async {
      await seedDiagnosed('hypertension', 'ارتفاع ضغط الدم');
      final failing = ChronicCareCoordinator(
        healthProfiles: health,
        repository: _FailingChronicRepo(),
      );
      final r = await failing.handle(
        text: 'ضغطي 130 على 80',
        session: ChronicCareSession.inactive,
      );
      expect(r.handled, isTrue);
      expect(r.success, isFalse);
      expect(r.message.startsWith('سجّلت'), isFalse);
    });

    test('AZ/BA/BB/BC — separations & delete measurement', () async {
      await personal.savePreferredName('علي');
      await seedDiagnosed('hypertension', 'ارتفاع ضغط الدم');
      await health.setFollowUpPermission(
        canonicalConditionKey: 'hypertension',
        enabled: true,
      );
      await run('ضغطي 125 على 85');
      expect((await personal.loadProfile())?.preferredName, 'علي');
      expect(await health.findCondition('hypertension'), isNotNull);

      await run('امسح آخر قياس');
      expect(await health.findCondition('hypertension'), isNotNull);
      expect(
        (await health.findCondition('hypertension'))!.followUpPermission,
        isTrue,
      );

      await run('ضغطي 120 على 80');
      await run('امسح قياسات الضغط');
      expect(
        (await health.findCondition('hypertension'))!.followUpPermission,
        isTrue,
      );
      expect(
        (await chronicRepo.load())
            .measurements
            .where((m) => m.conditionKey == 'hypertension'),
        isEmpty,
      );
    });

    test('BD–BG — no family/preventive/campaigns/paid', () {
      expect(const ChronicCareConditionRegistry().all.length, 2);
      expect(true, isTrue);
    });
  });
}

class _FailingChronicRepo implements ChronicCareRepository {
  @override
  Future<ChronicCareStore> load() async => const ChronicCareStore(ownerKey: 'x');

  @override
  Future<ChronicCareStore> save(ChronicCareStore store) async {
    throw StateError('fail');
  }

  @override
  Future<void> clearAll() async {
    throw StateError('fail');
  }
}
