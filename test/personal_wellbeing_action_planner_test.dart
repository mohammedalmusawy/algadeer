import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/personal_memory/personal_memory.dart';
import 'package:ghadeer_clinic/daily_context/daily_context.dart';
import 'package:ghadeer_clinic/follow_up/follow_up.dart';
import 'package:ghadeer_clinic/health/emotional_support/mental_health_safety_gate.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/wellbeing_planner/wellbeing_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PersonalMemoryService mem;
  late FollowUpService followUps;
  late DailyContextCoordinator daily;
  late WellbeingPlannerCoordinator planner;
  late ConversationContext ctx;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mem = PersonalMemoryService(
      repository: LocalPersonalMemoryRepository(prefs: prefs),
    );
    followUps = FollowUpService(
      repository: LocalFollowUpRepository(prefs: prefs),
    );
    daily = DailyContextCoordinator();
    planner = WellbeingPlannerCoordinator(
      personalMemory: mem,
      followUps: followUps,
    );
    ctx = ConversationContext();
    now = DateTime(2026, 9, 16, 12);
  });

  Future<WellbeingPlannerTurnResult> run(String text) async {
    final r = await planner.handle(
      text: text,
      session: ctx.wellbeingPlannerSession,
      dailyContext: ctx.dailyLifeContext,
    );
    ctx.setWellbeingPlannerSession(r.session);
    return r;
  }

  Future<void> seedDaily(String text) async {
    final o = daily.observe(
      text: text,
      context: ctx.dailyLifeContext,
      now: now,
    );
    ctx.setDailyLifeContext(o);
  }

  group('PC-1.16 detection / scopes A–N', () {
    test('A — explicit plan detected', () {
      const i = WellbeingPlanRequestInterpreter();
      expect(i.interpret('أريد أرتب حياتي').isPlanRequest, isTrue);
      expect(i.interpret('ساعدني أبدأ خطوة خطوة').isPlanRequest, isTrue);
    });

    test('B/C — ordinary questions not hijacked', () {
      const i = WellbeingPlanRequestInterpreter();
      expect(i.interpret('شنو فوائد المشي؟').isPlanRequest, isFalse);
      expect(i.interpret('شنو فوائد المشي؟').ordinaryBenefitsQuestion, isTrue);
      expect(i.interpret('عندي صداع').isPlanRequest, isFalse);
      expect(i.interpret('عندي صداع').symptomOnlyHealth, isTrue);
    });

    test('D–J — scopes', () {
      const i = WellbeingPlanRequestInterpreter();
      expect(i.interpret('أريد أرتب حياتي').scope,
          WellbeingPlanScope.generalWellbeing);
      expect(i.interpret('أريد أهتم بنفسيتي').scope,
          WellbeingPlanScope.mentalWellbeing);
      expect(i.interpret('ساعدني أرجع للرياضة').scope,
          WellbeingPlanScope.movement);
      expect(i.interpret('رتبلي خطة لنومي').scope, WellbeingPlanScope.sleepRest);
      expect(
        i.interpret('رتبلي خطة مع امتحان').scope,
        WellbeingPlanScope.studyBalance,
      );
      expect(i.interpret('رتبلي خطة مع دوامي').scope,
          WellbeingPlanScope.workBalance);
      expect(
        i.interpret('أريد أهتم بصحتي ونفسيتي وأرجع للرياضة').scope,
        WellbeingPlanScope.mixedWellbeing,
      );
    });

    test('K/L/M/N — horizons; no exact dates', () async {
      const i = WellbeingPlanRequestInterpreter();
      expect(i.interpret('شنو أسوي هسه؟').horizon, WellbeingPlanHorizon.now);
      expect(i.interpret('رتبلي خطة لليوم').horizon, WellbeingPlanHorizon.today);
      expect(
        i.interpret('رتبلي خطة بسيطة لهذا الأسبوع').horizon,
        WellbeingPlanHorizon.thisWeek,
      );
      final r = await run('رتبلي خطة بسيطة لهذا الأسبوع');
      expect(RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(r.message), isFalse);
      expect(r.message.contains('الساعة 8'), isFalse);
    });
  });

  group('PC-1.16 subject / envelope O–T', () {
    test('O — owner individualized planning', () async {
      final r = await run('أريد أهتم بصحتي');
      expect(r.handled, isTrue);
      expect(r.plan.actions, isNotEmpty);
    });

    test('P/Q/R — mother plan does not use owner context', () async {
      await mem.upsertCandidate(
        const PersonalMemoryCandidate(
          memoryType: PersonalMemoryType.goal,
          canonicalKey: 'goal_walking',
          displayLabel: 'المشي',
          category: 'walking',
        ),
      );
      await seedDaily('أنا اليوم تعبان ونومي قليل');
      final r = await run('رتبلي خطة لأمي');
      expect(r.message.contains('شخص ثاني'), isTrue);
      expect(r.message.contains('1990'), isFalse);
      expect(r.message.contains('سكري'), isFalse);
      expect(r.message.contains('مشي'), isFalse);
    });

    test('S/T — minimal envelope; unrelated memories excluded', () async {
      await mem.upsertCandidate(
        const PersonalMemoryCandidate(
          memoryType: PersonalMemoryType.interest,
          canonicalKey: 'interest_photography',
          displayLabel: 'التصوير',
          category: 'photography',
        ),
      );
      final r = await run('رتبلي خطة أرجع بيها للمشي');
      expect(r.message.contains('تصوير'), isFalse);
      final env = planner.actionPlanner.buildEnvelope(
        request: const WellbeingPlanRequestInterpreter()
            .interpret('رتبلي خطة أرجع بيها للمشي'),
        daily: ctx.dailyLifeContext,
        eligibleWalkingGoal: true,
      );
      expect(env.debugMap().containsKey('photography'), isFalse);
      expect(env.debugMap().containsKey('subjectKind'), isTrue);
    });
  });

  group('PC-1.16 safety U–X', () {
    test('U/W — medical red flag stops plan', () async {
      final r = await run(
        'أريد أرجع للرياضة بس من أمشي يصير ألم صدر شديد',
      );
      expect(r.deferToUrgentSafety, isTrue);
      expect(r.handled, isFalse);
      expect(
        r.plan.actions.any((a) => a.category == WellbeingActionCategory.walking),
        isFalse,
      );
    });

    test('V — mental crisis stops planning', () async {
      final r = await run('أريد أهتم بنفسيتي وأريد أقتل نفسي');
      expect(r.deferToMentalSafety, isTrue);
      expect(
        const MentalHealthSafetyGate().triggersCrisis('أريد أقتل نفسي'),
        isTrue,
      );
    });

    test('X — non-urgent health is not diagnosis', () async {
      await seedDaily('عندي صداع');
      final r = await run('أريد أهتم بصحتي');
      expect(r.message.contains('تشخيص'), isFalse);
      expect(r.message.toLowerCase().contains('migraine'), isFalse);
    });
  });

  group('PC-1.16 budgets / effort Y–AE', () {
    test('Y — default primary <=3', () async {
      final r = await run('أريد أهتم بصحتي ونفسيتي');
      expect(r.plan.primaryCount, lessThanOrEqualTo(3));
    });

    test('Z — high-load <=2', () async {
      await seedDaily('عندي امتحان باچر ونومي قليل ومتوتر');
      final r = await run('شنو أسوي هسه؟');
      expect(r.plan.primaryCount, lessThanOrEqualTo(2));
      expect(r.plan.oneNextStepMode || r.plan.actions.length <= 2, isTrue);
    });

    test('AA — weekly <=5', () async {
      final r = await run('رتبلي خطة بسيطة لهذا الأسبوع');
      expect(r.plan.primaryCount, lessThanOrEqualTo(5));
    });

    test('AB — high-load prefers low effort', () async {
      await seedDaily('ما عندي طاقة ونومي قليل');
      final r = await run('شنو أسوي هسه؟');
      expect(
        r.plan.actions.every(
          (a) =>
              a.effort == WellbeingEffortClass.veryLow ||
              a.effort == WellbeingEffortClass.low,
        ),
        isTrue,
      );
    });

    test('AC/AD/AE — no calorie/metabolic/arbitrary duration', () async {
      final r = await run('أريد أهتم بصحتي');
      expect(r.message.toLowerCase().contains('calorie'), isFalse);
      expect(r.message.contains('سعرات'), isFalse);
      expect(r.message.contains('metabolic'), isFalse);
      expect(RegExp(r'\d+\s*دقيقة بالضبط').hasMatch(r.message), isFalse);
    });
  });

  group('PC-1.16 priority / conflict AF–AK', () {
    test('AF/AG/AH/AI — rest/exam outrank walking', () async {
      await mem.upsertCandidate(
        const PersonalMemoryCandidate(
          memoryType: PersonalMemoryType.goal,
          canonicalKey: 'goal_walking',
          displayLabel: 'المشي',
          category: 'walking',
        ),
      );
      await seedDaily('عندي امتحان باچر ونمت ساعتين');
      final r = await run(
        'عندي امتحان ونومي ملخبط وأريد أبقى أتحرك',
      );
      expect(
        r.plan.actions.any((a) => a.category == WellbeingActionCategory.walking),
        isFalse,
      );
      expect(
        r.message.contains('مشي') && r.message.contains('ما أضغط'),
        isTrue,
      );
    });

    test('AJ/AK — defer follow-up without deletion', () async {
      await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.personalGoal,
        topicKey: 'walking',
        displayTopic: 'المشي',
      );
      final before = await followUps.listActive();
      await seedDaily('عندي امتحان باچر ونومي قليل');
      final r = await run('شنو أسوي هسه؟');
      expect(r.deferFollowUpSurfacing || r.session.active, isTrue);
      expect(await followUps.listActive(), hasLength(before.length));
    });
  });

  group('PC-1.16 sequencing / weekly AL–AQ', () {
    test('AL — no perfect-day checklist', () async {
      final r = await run('أريد أهتم بصحتي ونفسيتي وأرجع للرياضة');
      expect(r.plan.actions.length, lessThan(8));
      expect(r.message.contains('تأمل'), isFalse);
      expect(r.message.contains('يوميات'), isFalse);
    });

    test('AM — one-next-step under overwhelm', () async {
      await seedDaily('متوتر وما عندي طاقة وعندي شغل هواي');
      final r = await run('شنو أسوي هسه؟');
      expect(r.plan.oneNextStepMode || r.plan.actions.length == 1, isTrue);
    });

    test('AN/AO — weekly not minute schedule; no notifications', () async {
      final r = await run('رتبلي خطة بسيطة لهذا الأسبوع');
      expect(r.message.contains('09:00'), isFalse);
      expect(r.message.contains('إشعار فوري'), isFalse);
      expect(r.message.contains('تذكير الساعة'), isFalse);
    });

    test('AP/AQ — daily context reused; no second store', () async {
      await seedDaily('اليوم نومي قليل');
      expect(ctx.dailyLifeContext.signals, isNotEmpty);
      await run('أريد أهتم بنومي');
      // لا مخزن يومي ثانٍ داخل المخطّط
      final src = File('lib/wellbeing_planner/wellbeing_planner_coordinator.dart')
          .readAsStringSync();
      expect(src.contains('DailyLifeContext empty ='), isFalse);
      expect(Directory('lib/daily_context').existsSync(), isTrue);
    });
  });

  group('PC-1.16 goals / follow-up / authorities AR–AY', () {
    test('AR/AS/AT — may include goal; no auto create/complete', () async {
      await mem.upsertCandidate(
        const PersonalMemoryCandidate(
          memoryType: PersonalMemoryType.goal,
          canonicalKey: 'goal_walking',
          displayLabel: 'المشي',
          category: 'walking',
        ),
      );
      final before = await mem.listByType(PersonalMemoryType.goal);
      await run('رتبلي خطة أرجع بيها للمشي');
      final after = await mem.listByType(PersonalMemoryType.goal);
      expect(after.length, before.length);
      expect(after.first.status, isNot(PersonalMemoryStatus.completed));
      expect(planner.mayCreateGoalFromPlan(), isFalse);
    });

    test('AU/AV — plan alone no follow-up; explicit routes', () async {
      expect(planner.mayAuthorizeFollowUpFromPlanAlone(), isFalse);
      final planOnly = await run('سويلي خطة مشي');
      expect(planOnly.deferToFollowUp, isFalse);
      expect(await followUps.listActive(), isEmpty);
      final withFu = await run('سويلي خطة مشي وتابع وياي');
      expect(withFu.deferToFollowUp, isTrue);
    });

    test('AW/AX/AY — authority markers', () {
      expect(Directory('lib/wellness').existsSync(), isTrue);
      expect(Directory('lib/health/preventive').existsSync(), isTrue);
      expect(Directory('lib/health/emotional_support').existsSync(), isTrue);
      final src = File('lib/wellbeing_planner/wellbeing_action_policies.dart')
          .readAsStringSync();
      expect(src.contains('150-300'), isFalse);
      expect(src.contains('150–300'), isFalse);
    });
  });

  group('PC-1.16 plan types AZ–BH', () {
    test('AZ — stress does not auto-trigger exercise', () async {
      await seedDaily('اليوم متوتر');
      final r = await run('أريد أهتم بنفسيتي');
      expect(
        r.plan.actions.every(
          (a) => a.category != WellbeingActionCategory.generalExercise,
        ),
        isTrue,
      );
    });

    test('BA/BB — mental plan no diagnose/treatment claim', () async {
      final r = await run('أريد أهتم بنفسيتي');
      expect(r.message.contains('اكتئاب'), isFalse);
      expect(r.message.contains('علاج نفسي'), isFalse);
      expect(r.message.contains('أشخّص'), isFalse);
    });

    test('BC/BD — physical no meds/supplements', () async {
      final r = await run('أريد أهتم بصحتي');
      expect(r.message.contains('دواء'), isFalse);
      expect(r.message.contains('مكمل'), isFalse);
    });

    test('BE — mixed one coherent plan', () async {
      final r = await run('أريد أهتم بصحتي ونفسيتي وأرجع للرياضة');
      expect(r.handled, isTrue);
      expect(r.message.split('خطة').length, lessThan(4));
      expect(r.plan.actions, isNotEmpty);
    });

    test('BF/BG/BH — rest/study/work adaptation', () async {
      await seedDaily('نومي قليل وعندي امتحان باچر');
      final exam = await run('رتبلي خطة مع دراستي');
      expect(
        exam.plan.actions.any(
          (a) =>
              a.category == WellbeingActionCategory.rest ||
              a.category == WellbeingActionCategory.study,
        ),
        isTrue,
      );
      ctx.setDailyLifeContext(DailyLifeContext.empty);
      await seedDaily('دوامي طويل');
      final work = await run('رتبلي خطة مع دوامي');
      expect(work.plan.actions, isNotEmpty);
    });
  });

  group('PC-1.16 adaptation BI–BN', () {
    test('BI/BJ — reduce / increase', () async {
      await run('أريد أهتم بصحتي ونفسيتي');
      final reduced = await run('هذا هواي، قللها');
      expect(reduced.plan.primaryCount, lessThanOrEqualTo(2));
      final stronger = await run('أريدها أقوى شوي');
      expect(stronger.handled, isTrue);
    });

    test('BK/BL — cannot walk removes action; goal unchanged', () async {
      await mem.upsertCandidate(
        const PersonalMemoryCandidate(
          memoryType: PersonalMemoryType.goal,
          canonicalKey: 'goal_walking',
          displayLabel: 'المشي',
          category: 'walking',
        ),
      );
      await run('رتبلي خطة أرجع بيها للمشي');
      final r = await run('ما أقدر أمشي اليوم');
      expect(
        r.plan.actions.any((a) => a.category == WellbeingActionCategory.walking),
        isFalse,
      );
      final goals = await mem.listByType(PersonalMemoryType.goal);
      expect(goals.single.status, isNot(PersonalMemoryStatus.completed));
      expect(goals.single.canonicalKey, 'goal_walking');
    });

    test('BM — context correction regenerates', () async {
      await seedDaily('عندي امتحان باچر');
      await run('رتبلي خطة مع امتحاني');
      final corrected = daily.observe(
        text: 'لا مو باچر، الامتحان بعد يومين',
        context: ctx.dailyLifeContext,
        now: now,
      );
      ctx.setDailyLifeContext(corrected);
      final r = await run('رتبلي خطة مع امتحاني');
      expect(r.handled, isTrue);
      final exam = ctx.dailyLifeContext.activeSignals(now).where(
            (s) => s.category == DailyContextCategory.exam,
          );
      expect(exam.single.timing, DailyContextTiming.thisWeek);
    });

    test('BN — rejected exercise not reinserted', () async {
      await run('أريد أهتم بصحتي وأرجع للرياضة');
      final r = await run('ما أريد تمارين');
      expect(
        r.plan.actions.any(
          (a) =>
              a.category == WellbeingActionCategory.walking ||
              a.category == WellbeingActionCategory.generalExercise ||
              a.category == WellbeingActionCategory.movement,
        ),
        isFalse,
      );
    });
  });

  group('PC-1.16 explanation / persistence BO–BV', () {
    test('BO/BP — explanation without hidden diagnosis', () async {
      await seedDaily('نومي قليل وعندي امتحان باچر');
      await run('شنو أسوي هسه؟');
      final r = await run('ليش رتبتها هيج؟');
      expect(r.message.contains('نوم'), isTrue);
      expect(r.message.contains('سكري'), isFalse);
      expect(r.message.contains('أشخّص'), isFalse);
      expect(r.message.contains('تشخيص مرض'), isFalse);
    });

    test('BQ–BV — session-level; no tracking stores', () {
      expect(planner.mayPersistPlanHistory(), isFalse);
      expect(planner.mayTrackCompletion(), isFalse);
      expect(planner.mayTrackActivity(), isFalse);
      expect(planner.mayTrackMood(), isFalse);
      expect(planner.mayTrackSleep(), isFalse);
      expect(ctx.wellbeingPlannerSession.debugMap().containsKey('streak'),
          isFalse);
    });
  });

  group('PC-1.16 anti-game / honesty BW–CF', () {
    test('BW–BZ — no gamification / no guilt', () async {
      await run('أريد أهتم بصحتي');
      final missed = await run('ما سويت الخطة اليوم');
      expect(missed.message.contains('فشل'), isFalse);
      expect(missed.message.contains('كسول'), isFalse);
      expect(ctx.wellbeingPlannerSession.debugMap().containsKey('points'),
          isFalse);
      expect(ctx.wellbeingPlannerSession.debugMap().containsKey('badges'),
          isFalse);
    });

    test('CA–CC — no monitoring/scheduler/calendar claims', () async {
      final r = await run('أريد أهتم بصحتي');
      expect(r.message.contains('أراقب تقدمك'), isFalse);
      expect(r.message.contains('أذكرك الساعة'), isFalse);
      expect(r.message.contains('جدولك'), isFalse);
    });

    test('CD–CF — no selling/sponsor', () async {
      final r = await run('أريد أهتم بصحتي');
      expect(r.message.contains('باقة'), isFalse);
      expect(r.message.contains('عرض'), isFalse);
      expect(r.message.contains('راعي'), isFalse);
    });
  });

  group('PC-1.16 wiring / future CG–CP', () {
    test('CG/CH/CI — text-first; same planner', () async {
      final r = await run('أريد أهتم بصحتي');
      expect(r.textFirstOnly, isTrue);
      final a = planner.interpreter.interpret('أريد أهتم بصحتي');
      final b = planner.interpreter.interpret('أريد أهتم بصحتي');
      expect(a.scope, b.scope);
    });

    test('CJ — failure does not break Smart Brain', () async {
      final brain = SmartBrainPlanner(
        wellbeingPlanner: _FailingPlanner(),
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
      expect(
        plan.kind != AssistantActionKind.none || plan.message.isNotEmpty,
        isTrue,
      );
    });

    test('CK–CP — future contract inactive; no campaigns/paid', () {
      final c = planner.futureContract;
      expect(c.isActive, isFalse);
      expect(c.planCheckInEnabled, isFalse);
      expect(c.calendarIntegrationEnabled, isFalse);
      expect(c.appleHealthIntegrationEnabled, isFalse);
      expect(c.wearableIntegrationEnabled, isFalse);
      expect(c.notificationsEnabled, isFalse);
      final src = Directory('lib/wellbeing_planner')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('in_app_purchase'), isFalse);
      expect(src.contains('RevenueCat'), isFalse);
      expect(src.contains('campaign'), isFalse);
    });

    test('Smart Brain handles wellbeing plan', () async {
      final brain = SmartBrainPlanner(
        wellbeingPlanner: planner,
        dailyContext: daily,
      );
      final plan = await brain.plan(
        query: 'أريد أهتم بصحتي ونفسيتي',
        context: ctx,
      );
      expect(plan.textFirstOnly, isTrue);
      expect(plan.message, isNotEmpty);
      expect(ctx.wellbeingPlannerSession.active, isTrue);
    });
  });
}

class _FailingPlanner extends WellbeingPlannerCoordinator {
  _FailingPlanner() : super();

  @override
  bool mayHandle({
    required String query,
    required WellbeingPlannerSession session,
  }) =>
      true;

  @override
  Future<WellbeingPlannerTurnResult> handle({
    required String text,
    required WellbeingPlannerSession session,
    DailyLifeContext? dailyContext,
  }) async {
    throw StateError('planner down');
  }
}
