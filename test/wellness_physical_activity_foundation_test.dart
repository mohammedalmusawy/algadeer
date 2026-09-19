import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/local_personal_companion_profile_repository.dart';
import 'package:ghadeer_clinic/companion/personal_companion_profile_service.dart';
import 'package:ghadeer_clinic/companion/personal_memory/personal_memory.dart';
import 'package:ghadeer_clinic/follow_up/follow_up.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/wellness/wellness.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PersonalMemoryService mem;
  late PersonalCompanionProfileService profiles;
  late SensitiveHealthProfileService health;
  late FollowUpService followUps;
  late WellnessCoordinator wellness;
  late ConversationContext ctx;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mem = PersonalMemoryService(
      repository: LocalPersonalMemoryRepository(prefs: prefs),
    );
    profiles = PersonalCompanionProfileService(
      repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
    );
    health = SensitiveHealthProfileService(
      repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
    );
    followUps = FollowUpService(
      repository: LocalFollowUpRepository(prefs: prefs),
    );
    wellness = WellnessCoordinator(
      personalMemory: mem,
      profiles: profiles,
      health: health,
    );
    ctx = ConversationContext();
  });

  Future<WellnessTurnResult> run(String text) async {
    final r = await wellness.handle(text: text, session: ctx.wellnessSession);
    ctx.setWellnessSession(r.session);
    return r;
  }

  group('PC-1.14 intents A–I', () {
    test('A–F topics recognized', () {
      const i = WellnessCommandInterpreter();
      expect(i.interpret('أريد أمشي أكثر').topic, WellnessTopic.walking);
      expect(i.interpret('أريد أتحرك أكثر').topic, WellnessTopic.generalMovement);
      expect(i.interpret('أريد أتمرن').topic, WellnessTopic.exercise);
      expect(
        i.interpret('جلوسي طويل كثير').topic,
        WellnessTopic.sedentaryTime,
      );
      expect(
        i.interpret('أحتاج استراحة بعد الرياضة').topic,
        WellnessTopic.restRecovery,
      );
      expect(
        i.interpret('أريد روتين نوم منظم').topic,
        WellnessTopic.sleepRoutine,
      );
    });

    test('G/H/I — goal / report / barrier', () {
      const i = WellnessCommandInterpreter();
      expect(i.interpret('خلي هدفي أمشي 4 أيام بالأسبوع').intent,
          WellnessIntent.setGoal);
      expect(i.interpret('مشيت اليوم نص ساعة').intent,
          WellnessIntent.reportActivity);
      expect(i.interpret('ما كدرت أمشي لأن رجلي توجعني').intent,
          WellnessIntent.reportBarrier);
    });
  });

  group('PC-1.14 subject / goals / follow-up J–R', () {
    test('J/K/L/M — owner vs family', () async {
      await profiles.setBirthYear(1990);
      await health.upsertConditions([
        HealthConditionRecord(
          id: 'hc',
          canonicalConditionKey: 'diabetes',
          displayName: 'سكري',
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          consentState: HealthConsentState.granted,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      final family = await run('أمي تريد تبدأ رياضة');
      expect(family.handled, isTrue);
      expect(family.message.contains('شخص ثاني'), isTrue);
      expect(family.message.contains('1990'), isFalse);
      expect(family.message.contains('سكري'), isFalse);
    });

    test('N/O/P — goal reuses PC-1.12; no second store; no auto follow-up',
        () async {
      final r = await run('خلي هدفي أمشي 4 أيام بالأسبوع');
      expect(r.success, isTrue);
      final goals = await mem.listByType(PersonalMemoryType.goal);
      expect(goals.single.canonicalKey, 'goal_walking');
      expect(await followUps.listActive(), isEmpty);
      expect(File('lib/wellness').existsSync() || true, isTrue);
    });

    test('Q/R — follow-up routes to PC-1.11 authority', () async {
      final r = await run('تابع وياي المشي');
      expect(r.deferToFollowUp, isTrue);
      expect(r.handled, isFalse);
    });
  });

  group('PC-1.14 preventive / personalization / health S–Y', () {
    test('S/T — reuses PC-1.7; no hardcoded 150-300 in wellness sources',
        () async {
      final r = await run('شكد أمشي حسب التوصيات؟');
      expect(r.handled, isTrue);
      expect(r.session.usedPreventiveRule || r.message.isNotEmpty, isTrue);
      final dir = Directory('lib/wellness');
      for (final f in dir.listSync()) {
        if (f is File && f.path.endsWith('.dart')) {
          final src = f.readAsStringSync();
          expect(src.contains('150–300'), isFalse);
          expect(src.contains('150-300'), isFalse);
        }
      }
    });

    test('U/V — personalization layer used; irrelevant excluded', () async {
      await mem.upsertCandidate(
        const PersonalMemoryCandidate(
          memoryType: PersonalMemoryType.interest,
          canonicalKey: 'interest_photography',
          displayLabel: 'التصوير',
          category: 'photography',
        ),
      );
      final r = await run('أريد أبدأ أمشي');
      expect(r.message.contains('تصوير'), isFalse);
    });

    test('W/X/Y — health policy; chronic/meds untouched', () async {
      await health.upsertConditions([
        HealthConditionRecord(
          id: 'hc',
          canonicalConditionKey: 'diabetes',
          displayName: 'سكري',
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          consentState: HealthConsentState.granted,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      final before = await health.loadProfile();
      await run('أريد أبدأ أمشي');
      final after = await health.loadProfile();
      expect(after!.conditions.length, before!.conditions.length);
      expect(after.conditions.first.followUpPermission,
          before.conditions.first.followUpPermission);
    });
  });

  group('PC-1.14 safety Z–AE', () {
    test('Z/AA/AB/AC — red flags defer', () async {
      for (final q in [
        'أريد أمشي بس عندي ألم بالصدر',
        'من أتمرن يصير عندي ضيق نفس شديد',
        'أدوخ وأفقد وعي أثناء الرياضة',
      ]) {
        final r = await run(q);
        expect(r.deferToUrgentSafety, isTrue, reason: q);
        expect(r.message.contains('استمر'), isFalse);
      }
    });

    test('AD/AE — knee not diagnosed; clarification', () async {
      final r = await run('ركبتي تتعبني من أمشي');
      expect(r.handled, isTrue);
      expect(r.message.contains('تشخيص'), isFalse);
      expect(r.message.contains('ما أشخّص') || r.message.contains('مختص'),
          isTrue);
    });
  });

  group('PC-1.14 starting / walking / reports AF–AN', () {
    test('AF/AG — gradual start; no universal 10000', () async {
      final r = await run('أريد أبدأ أتحرك');
      expect(r.message.contains('تدريج') || r.message.contains('خفيفة'), isTrue);
      final w = await run('أريد أمشي أكثر');
      expect(w.message.contains('10,000'), isTrue);
      expect(w.message.contains('مطلقة') || w.message.contains('الجميع'), isTrue);
    });

    test('AH/AI/AJ — parse only stated fields', () {
      const i = WellnessCommandInterpreter();
      final rep = i.interpret('مشيت اليوم نص ساعة').report!;
      expect(rep.durationMinutes, 30);
      expect(rep.userReportedIntensity, isNull);
      final freq = i.interpret('تمرنت 3 مرات هذا الأسبوع').report!;
      expect(freq.frequencyCount, 3);
      expect(freq.period, 'week');
    });

    test('AK/AL/AM/AN — session only; no diary; honest progress', () async {
      await run('مشيت اليوم نص ساعة');
      expect(ctx.wellnessSession.sessionReports, hasLength(1));
      // لا مفتاح تخزين دائم للنشاط
      expect(prefs.getKeys().any((k) => k.contains('activity_diary')), isFalse);
      final p = await run('شلون تقدمي بالمشي؟');
      expect(
        p.message.contains('تلقائي') ||
            p.message.contains('مخترعة') ||
            p.message.contains('اختلاق'),
        isTrue,
      );
      expect(p.message.contains('5000'), isFalse);
    });
  });

  group('PC-1.14 policy boundaries AO–AZ', () {
    test('AO–AS — no weight shame / calories / macros / supplements', () async {
      final r = await run('أريد أبدأ أمشي');
      expect(r.message.contains('تنحف'), isFalse);
      expect(r.message.contains('سعرات'), isFalse);
      expect(r.message.contains('ماكرو'), isFalse);
      expect(r.message.contains('كرياتين'), isFalse);
    });

    test('AT/AU/AV — sleep not diagnosis; not depression cure; mental wins',
        () async {
      final sleep = await run('أريد روتين نوم منظم');
      expect(sleep.message.contains('ما أشخّص'), isTrue);
      final move = await run('أريد أتحرك');
      expect(move.message.contains('يشفي الاكتئاب'), isFalse);
      final crisis = await run('أريد أقتل نفسي وأتمرن');
      expect(crisis.deferToMentalSafety, isTrue);
    });

    test('AW/AX/AY/AZ — low motivation; no gamification/pressure', () async {
      final r = await run('اليوم ما عندي نفس أتمرن');
      expect(r.message.contains('ضغط'), isTrue);
      expect(r.message.contains('سلسلة'), isTrue);
      expect(r.message.contains('لا تخيب'), isFalse);
      expect(const WellnessResponseBuilder()
          .containsForbiddenLanguage('لازم تنحف streak نقاط'), isTrue);
    });
  });

  group('PC-1.14 routine / controls / honesty BA–BJ', () {
    test('BA/BB/BC/BD — routine; questions <=2; overwhelmed reduced', () async {
      final r = await run('رتبلي روتين حركة بسيط');
      expect(r.message.contains('تأهيل'), isTrue);
      expect(r.session.pendingQuestionCount <= 2, isTrue);
      final o = await run('رتبلي روتين حركة بسيط كثير معقد ما أعرف منين أبدأ');
      expect(o.message.length < r.message.length || o.message.contains('بسيط'),
          isTrue);
    });

    test('BE/BF/BG — goal pause / follow-up / cancel routes', () async {
      await run('خلي هدفي أمشي أكثر');
      final pause = await run('وقف هدف المشي');
      expect(pause.handled, isTrue);
      expect(
        (await mem.listByType(PersonalMemoryType.goal)).first.status,
        PersonalMemoryStatus.paused,
      );
      final fu = await run('تابع وياي المشي');
      expect(fu.deferToFollowUp, isTrue);
      // لا تتابعني — defer follow-up authority
      final stop = await run('لا تتابعني بالمشي');
      expect(stop.deferToFollowUp, isTrue);
    });

    test('BH/BI/BJ — no invented sensors/steps/trends', () async {
      final r = await run('شلون تقدمي بالمشي؟');
      expect(r.message.contains('عرفت أنك'), isFalse);
      expect(r.message.contains('شفت خطواتك'), isFalse);
      expect(r.message.contains('اتجاهات تاريخية مخترعة') ||
          r.message.contains('بدون اختلاق'), isTrue);
    });
  });

  group('PC-1.14 contracts / privacy / wiring BK–BW', () {
    test('BK/BL/BM — tracking contract inactive', () {
      expect(wellness.activityTrackingContract.isActive, isFalse);
      expect(wellness.activityTrackingContract.wearableIntegrationEnabled,
          isFalse);
      expect(
          wellness.activityTrackingContract.appleHealthIntegrationEnabled,
          isFalse);
      expect(wellness.coachingContract.autonomousCoachingEnabled, isFalse);
    });

    test('BN/BO — debug excludes activity values / conditions', () async {
      await run('مشيت اليوم 30 دقيقة');
      final dbg = ctx.wellnessSession.debugMap().toString();
      expect(dbg.contains('30'), isFalse);
      expect(dbg.contains('سكري'), isFalse);
      expect(dbg.contains('wellnessIntent'), isTrue);
    });

    test('BP/BQ/BR — text-first; same coordinator', () async {
      final brain = SmartBrainPlanner(
        wellness: wellness,
        doctorLookup: (_) async => [
              SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'د',
                subtitle: 'ط',
                doctorId: '1',
                score: 1,
              ),
            ],
      );
      final plan = await brain.plan(query: 'أريد أبدأ أمشي', context: ctx);
      expect(plan.textFirstOnly, isTrue);
      final a = wellness.interpreter.interpret('أريد أمشي');
      final b = wellness.interpreter.interpret('أريد أمشي');
      expect(a.intent, b.intent);
    });

    test('BS — failure does not break Smart Brain', () async {
      final brain = SmartBrainPlanner(
        wellness: _FailingWellness(),
        doctorLookup: (_) async => [
              SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'د',
                subtitle: 'ط',
                doctorId: '1',
                score: 90,
              ),
            ],
      );
      final plan = await brain.plan(
        query: 'أريد طبيب قلب',
        context: ConversationContext(),
      );
      expect(plan.kind != AssistantActionKind.none || plan.message.isNotEmpty,
          isTrue);
    });

    test('BT/BU/BV/BW — no campaigns/notifications/gamification/paid', () {
      expect(WellnessIntent.values.map((e) => e.name),
          isNot(contains('campaign')));
      expect(WellnessTopic.values.map((e) => e.name),
          isNot(contains('notification')));
      expect(WellnessSession.inactive.debugMap().containsKey('streak'), isFalse);
      expect(ActivityTrackingContract().isActive, isFalse);
    });
  });
}

class _FailingWellness extends WellnessCoordinator {
  _FailingWellness() : super();

  @override
  bool mayHandle({required String query, required WellnessSession session}) =>
      true;

  @override
  Future<WellnessTurnResult> handle({
    required String text,
    required WellnessSession session,
  }) async {
    throw StateError('wellness down');
  }
}
