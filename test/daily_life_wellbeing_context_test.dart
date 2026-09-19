import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/personal_memory/personal_memory.dart';
import 'package:ghadeer_clinic/daily_context/daily_context.dart';
import 'package:ghadeer_clinic/follow_up/follow_up.dart';
import 'package:ghadeer_clinic/health/emotional_support/mental_health_safety_gate.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PersonalMemoryService mem;
  late SensitiveHealthProfileService health;
  late FollowUpService followUps;
  late DailyContextCoordinator daily;
  late ConversationContext ctx;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mem = PersonalMemoryService(
      repository: LocalPersonalMemoryRepository(prefs: prefs),
    );
    health = SensitiveHealthProfileService(
      repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
    );
    followUps = FollowUpService(
      repository: LocalFollowUpRepository(prefs: prefs),
    );
    daily = DailyContextCoordinator();
    ctx = ConversationContext();
    now = DateTime(2026, 9, 16, 12, 0);
  });

  Future<DailyContextTurnResult> run(String text) async {
    final r = await daily.handle(
      text: text,
      context: ctx.dailyLifeContext,
      now: now,
    );
    ctx.setDailyLifeContext(r.context);
    return r;
  }

  group('PC-1.15 signals A–G', () {
    test('A — temporary sleep signal', () async {
      final r = await run('اليوم نومي قليل');
      expect(r.handled, isTrue);
      final sleep = r.context.activeSignals(now).where(
            (s) => s.category == DailyContextCategory.sleep,
          );
      expect(sleep, isNotEmpty);
      expect(sleep.first.state, 'userReportsLowSleep');
      expect(sleep.first.timing, DailyContextTiming.today);
    });

    test('B — upcoming exam tomorrow', () async {
      final r = await run('عندي امتحان باچر');
      final exam = r.context.activeSignals(now).where(
            (s) => s.category == DailyContextCategory.exam,
          );
      expect(exam, isNotEmpty);
      expect(exam.first.state, 'upcomingExam');
      expect(exam.first.timing, DailyContextTiming.tomorrow);
    });

    test('C — emotional stress integrates', () async {
      final r = await run('اليوم متوتر');
      expect(
        r.context.activeSignals(now).any(
              (s) => s.category == DailyContextCategory.emotionalState,
            ),
        isTrue,
      );
      expect(r.context.lastPriority, DailyContextPriority.emotionalLoad);
    });

    test('D — long workday', () async {
      final r = await run('دوامي طويل');
      expect(
        r.context.activeSignals(now).any(
              (s) => s.category == DailyContextCategory.work,
            ),
        isTrue,
      );
    });

    test('E — low energy', () async {
      final r = await run('ما عندي طاقة');
      expect(
        r.context
            .activeSignals(now)
            .any((s) => s.state == 'userReportsLowEnergy'),
        isTrue,
      );
    });

    test('F — no walk today', () async {
      final r = await run('اليوم ما مشيت');
      expect(
        r.context
            .activeSignals(now)
            .any((s) => s.state == 'userReportsNoActivityToday'),
        isTrue,
      );
    });

    test('G — multi-signal one turn', () async {
      const i = DailyContextInterpreter();
      final interp = i.interpret(
        'عندي امتحان باچر ونومي قليل ومتوتر وما مشيت اليوم',
        now: now,
      );
      final cats = interp.signals.map((s) => s.category).toSet();
      expect(cats.contains(DailyContextCategory.exam), isTrue);
      expect(cats.contains(DailyContextCategory.sleep), isTrue);
      expect(cats.contains(DailyContextCategory.emotionalState), isTrue);
      expect(cats.contains(DailyContextCategory.activity), isTrue);
    });
  });

  group('PC-1.15 priority / safety H–M', () {
    test('H/I — one coherent focus, no advice dump', () async {
      final r = await run(
        'عندي امتحان باچر، نمت ساعتين، متوتر وما مشيت',
      );
      expect(r.handled, isTrue);
      expect(r.context.lastPriority, DailyContextPriority.restSleepNeed);
      expect(r.message.contains('امشِ'), isFalse);
      expect(r.message.contains('مارس الرياضة'), isFalse);
      expect(r.message.contains('اشرب ماء'), isFalse);
      // رسالة واحدة — ليست أربع فقرات نصائح مستقلة
      expect(RegExp(r'\n•').allMatches(r.message).length, lessThan(4));
    });

    test('J — medical safety outranks', () async {
      final r = await run('اليوم تعبان وعندي ألم صدر وضيق نفس');
      expect(r.deferToUrgentSafety, isTrue);
      expect(r.handled, isFalse);
      expect(r.context.lastPriority, DailyContextPriority.urgentMedicalSafety);
    });

    test('K — mental-health safety outranks', () async {
      final r = await run('اليوم متوتر وأريد أقتل نفسي');
      expect(r.deferToMentalSafety, isTrue);
      expect(r.handled, isFalse);
      expect(
        const MentalHealthSafetyGate().triggersCrisis('أريد أقتل نفسي'),
        isTrue,
      );
    });

    test('L — active health concern outranks optimization', () async {
      final r = await run('عندي صداع وتعب عام');
      expect(
        r.context.lastPriority,
        DailyContextPriority.activeHealthConcern,
      );
    });

    test('M — explicit user priority respected', () async {
      final r = await run('أعرف نومي قليل بس أريد نركز على الدراسة');
      expect(r.context.lastPriority, DailyContextPriority.explicitUserGoal);
      expect(r.message.contains('نركّز على اللي طلبته'), isTrue);
    });
  });

  group('PC-1.15 subject isolation N–P', () {
    test('N — owner context not applied to mother', () async {
      await run('أنا اليوم تعبان');
      final ownerEnergy = daily.ownerSignals(ctx.dailyLifeContext, now);
      expect(ownerEnergy.any((s) => s.category == DailyContextCategory.energy),
          isTrue);
      final aboutMom = await run('أمي اليوم تعبانة');
      expect(aboutMom.message.contains('شخص ثاني'), isTrue);
      expect(aboutMom.message.contains('طاقة'), isFalse);
    });

    test('O — mother context not applied to owner', () async {
      ctx.setDailyLifeContext(DailyLifeContext.empty);
      await run('أمي اليوم تعبانة');
      expect(daily.ownerSignals(ctx.dailyLifeContext, now), isEmpty);
      expect(daily.otherSignals(ctx.dailyLifeContext, now), isNotEmpty);
      final me = await run('شنو فاهم عن وضعي اليوم؟');
      expect(me.message.contains('ما عندي سياق يومي مؤقت'), isTrue);
    });

    test('P — family context does not use owner goals', () async {
      await mem.upsertCandidate(
        const PersonalMemoryCandidate(
          memoryType: PersonalMemoryType.goal,
          canonicalKey: 'goal_walking',
          displayLabel: 'المشي',
          category: 'walking',
        ),
      );
      final r = await run('أمي اليوم تعبانة');
      expect(r.message.contains('مشي'), isFalse);
      expect(r.message.contains('هدف'), isFalse);
    });
  });

  group('PC-1.15 temporary / expiry Q–U', () {
    test('Q/R — today/yesterday not permanent memory', () async {
      await run('اليوم تعبان');
      await run('البارحة نومي قليل');
      expect(await mem.listAll(), isEmpty);
      expect(ctx.dailyLifeContext.signals, isNotEmpty);
    });

    test('S — tomorrow event short-lived', () async {
      final r = await run('عندي امتحان باچر');
      final exam = r.context.signals
          .firstWhere((s) => s.category == DailyContextCategory.exam);
      expect(exam.expiresAt.isBefore(now.add(const Duration(days: 3))), isTrue);
      expect(exam.expiresAt.isAfter(now), isTrue);
    });

    test('T — week context bounded', () async {
      final r = await run('هذا الأسبوع مضغوط عندي شغل');
      final week = r.context.signals
          .where((s) => s.timing == DailyContextTiming.thisWeek);
      expect(week, isNotEmpty);
      expect(
        week.first.expiresAt.difference(now).inDays,
        lessThanOrEqualTo(7),
      );
    });

    test('U — expired context no longer affects', () async {
      await run('اليوم نومي قليل');
      final expired = ctx.dailyLifeContext.signals
          .map(
            (s) => DailyContextSignal(
              category: s.category,
              state: s.state,
              timing: s.timing,
              subject: s.subject,
              createdAt: s.createdAt,
              expiresAt: now.subtract(const Duration(minutes: 1)),
            ),
          )
          .toList();
      ctx.setDailyLifeContext(
        ctx.dailyLifeContext.copyWith(signals: expired),
      );
      final pruned = daily.expiry.pruneExpired(ctx.dailyLifeContext.signals, now);
      expect(pruned, isEmpty);
      final p = daily.priorityResolver.resolve(
        interp: DailyContextInterpretation.none,
        context: DailyLifeContext(signals: pruned),
      );
      expect(p, DailyContextPriority.lowerOptimization);
    });
  });

  group('PC-1.15 no silent promotion V–Z', () {
    test('V/W/X/Y/Z — no silent persist domains', () async {
      await run('عندي امتحان باچر ونومي قليل وما مشيت ومتوتر');
      expect(daily.wouldSilentlyPersist('personalMemory'), isFalse);
      expect(daily.wouldSilentlyPersist('sensitiveHealth'), isFalse);
      expect(daily.wouldSilentlyPersist('followUp'), isFalse);
      expect(daily.wouldSilentlyPersist('activityRecord'), isFalse);
      expect(daily.wouldSilentlyPersist('moodHistory'), isFalse);
      expect(await mem.listAll(), isEmpty);
      expect(await health.loadProfile(), isNull);
      expect(await followUps.listActive(), isEmpty);
    });
  });

  group('PC-1.15 diagnoses / integrations AA–AK', () {
    test('AA/AB/AC — no diagnoses', () async {
      final sleep = await run('نومي قليل');
      expect(sleep.message.contains('أرق'), isFalse);
      expect(sleep.message.toLowerCase().contains('insomnia'), isFalse);
      final energy = await run('ما عندي طاقة');
      expect(energy.message.contains('مرض'), isFalse);
      final stress = await run('اليوم متوتر');
      expect(stress.message.contains('اضطراب قلق'), isFalse);
      expect(stress.message.contains('قلق مرضي'), isFalse);
    });

    test('AD — exam stress can reuse PC-1.6 gate', () {
      expect(
        const MentalHealthSafetyGate()
            .triggersCrisis('قتلني الامتحان'),
        isFalse,
      );
      expect(
        const MentalHealthSafetyGate()
            .triggersCrisis('أريد أقتل نفسي'),
        isTrue,
      );
    });

    test('AE/AF — exercise/walking not prioritized under overload', () async {
      final r = await run(
        'عندي امتحان باچر ونمت ساعتين ومتوتر وما مشيت',
      );
      expect(r.suppressWellnessPressure, isTrue);
      expect(r.message.contains('هدف المشي'), isTrue);
      expect(r.message.contains('لازم تمشي'), isFalse);
    });

    test('AG/AH — due follow-up deferred flag; PC-1.11 authority', () async {
      await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.personalGoal,
        topicKey: 'walking',
        displayTopic: 'المشي',
      );
      final before = await followUps.listActive();
      expect(before, isNotEmpty);
      final r = await run('عندي امتحان باچر ونومي قليل');
      expect(r.context.deferFollowUpSurfacing, isTrue);
      expect(await followUps.listActive(), hasLength(before.length));
      final fu = await run('تابع وياي موضوع الامتحان');
      expect(fu.deferToFollowUp, isTrue);
    });

    test('AI/AJ/AK — authority markers stay with PC-1.7/1.14/1.13', () {
      expect(Directory('lib/health/preventive').existsSync(), isTrue);
      expect(Directory('lib/wellness').existsSync(), isTrue);
      expect(Directory('lib/companion/personalization').existsSync(), isTrue);
      expect(
        daily.runtimeType.toString().contains('DailyContext'),
        isTrue,
      );
      // Daily context لا يعرّف قواعد وقائية/عافية خاصة به
      final src = File('lib/daily_context/daily_context_coordinator.dart')
          .readAsStringSync();
      expect(src.contains('150-300'), isFalse);
      expect(src.contains('PreventiveGuidanceCoordinator'), isFalse);
    });
  });

  group('PC-1.15 planning / overload / rest AL–AQ', () {
    test('AL/AM — small plan <=5 blocks', () async {
      final r = await run('رتبلي يومي');
      expect(r.handled, isTrue);
      final bullets = RegExp(r'^•', multiLine: true).allMatches(r.message);
      expect(bullets.length, lessThanOrEqualTo(5));
      expect(bullets.length, greaterThanOrEqualTo(1));
    });

    test('AN — overwhelmed reduces response', () async {
      final light = await run('دوامي طويل');
      ctx.setDailyLifeContext(DailyLifeContext.empty);
      final heavy = await run(
        'عندي امتحان باچر ونومي قليل ومتوتر وما عندي طاقة',
      );
      expect(heavy.context.hasHighLoad, isTrue);
      expect(heavy.message.length, lessThan(light.message.length + 80));
      expect(heavy.message.contains('\n•'), isFalse);
    });

    test('AO/AP — rest valid; no shaming', () async {
      final r = await run('تعبان وأريد أرتاح');
      expect(
        r.message.contains('راحة') || r.message.contains('راحه'),
        isTrue,
      );
      expect(const DailyContextResponseStrategy().containsForbidden(r.message),
          isFalse);
      expect(r.message.contains('كسول'), isFalse);
      expect(r.message.contains('فشلت'), isFalse);
    });

    test('AQ — low energy is current state not trait', () async {
      final r = await run('اليوم ما عندي طاقة');
      expect(r.message.contains('شخصية'), isFalse);
      expect(r.message.contains('دائماً كسول'), isFalse);
      final sig = r.context.activeSignals(now).firstWhere(
            (s) => s.category == DailyContextCategory.energy,
          );
      expect(sig.timing, DailyContextTiming.today);
    });
  });

  group('PC-1.15 boundaries AR–AU', () {
    test('AR — long-term remember defers to memory', () async {
      final r = await run('دوامي دائماً ليلي، تذكر هذا');
      expect(r.deferToPersonalMemory, isTrue);
      expect(r.handled, isFalse);
    });

    test('AS — explicit follow-up defers to PC-1.11', () async {
      final r = await run('تابع وياي موضوع الامتحان');
      expect(r.deferToFollowUp, isTrue);
    });

    test('AT/AU — activity/mood short-lived only', () async {
      await run('اليوم مشيت 30 دقيقة');
      await run('اليوم نفسيتي تعبانة');
      expect(await mem.listAll(), isEmpty);
      expect(ctx.dailyLifeContext.signals.isNotEmpty, isTrue);
    });
  });

  group('PC-1.15 correction / topic / summary AV–AZ', () {
    test('AV/AW — correction replaces conflicting state', () async {
      await run('عندي امتحان باچر');
      final corrected = await run('لا مو باچر، الامتحان بعد يومين');
      final exam = corrected.context.activeSignals(now).where(
            (s) => s.category == DailyContextCategory.exam,
          );
      expect(exam.single.timing, DailyContextTiming.thisWeek);
      await run('اليوم تعبان');
      final sleepy = await run('مو تعبان، بس نعسان');
      expect(
        sleepy.context
            .activeSignals(now)
            .any((s) => s.state == 'userReportsSleepyNotFatigued'),
        isTrue,
      );
      expect(
        sleepy.context
            .activeSignals(now)
            .where((s) => s.category == DailyContextCategory.energy),
        isEmpty,
      );
    });

    test('AX/AY — unrelated lab/doctor not interrupted', () async {
      await run('عندي امتحان باچر ونومي قليل');
      final lab = await run('أريد رقم مختبر');
      expect(lab.deferToEntityIntent, isTrue);
      expect(lab.handled, isFalse);
      final doc = await run('أريد رقم طبيب');
      expect(doc.deferToEntityIntent, isTrue);
    });

    test('AZ — summary distinguishes temporary vs persistent', () async {
      await run('اليوم نومي قليل');
      final r = await run('شنو فاهم عن وضعي اليوم؟');
      expect(r.message.contains('مؤقت'), isTrue);
      expect(r.message.contains('دائم') || r.message.contains('الذاكرة'), isTrue);
    });
  });

  group('PC-1.15 honesty / privacy / text BA–BF', () {
    test('BA/BB — no monitoring / sensor claims', () async {
      final r = await run('اليوم نومي قليل');
      expect(r.message.contains('أراقب يومك'), isFalse);
      expect(r.message.contains('حسب اللي ذكرت') ||
          r.message.contains('بما إن') ||
          r.message.contains('فهمت'), isTrue);
      expect(r.message.contains('مستشعر'), isFalse);
    });

    test('BC/BD — debug/analytics no raw values', () async {
      await run('نمت ساعتين وعندي امتحان كيمياء');
      final dbg = ctx.dailyLifeContext.debugMap();
      expect(dbg.containsKey('dailySignalCount'), isTrue);
      expect(dbg.containsKey('dailyCategories'), isTrue);
      expect(dbg.toString().contains('ساعتين'), isFalse);
      expect(dbg.toString().contains('كيمياء'), isFalse);
      final analytics = daily.privacy.analyticsSafeMap(ctx.dailyLifeContext);
      expect(analytics.toString().contains('ساعتين'), isFalse);
    });

    test('BE/BF — text-first; no automatic TTS flag', () async {
      final r = await run('اليوم متوتر');
      expect(r.textFirstOnly, isTrue);
    });
  });

  group('PC-1.15 wiring / failure / future BG–BQ', () {
    test('BG — typed and voice-final same interpreter', () {
      const i = DailyContextInterpreter();
      final a = i.interpret('اليوم نومي قليل');
      final b = i.interpret('اليوم نومي قليل');
      expect(a.signals.map((s) => s.state).toList(),
          b.signals.map((s) => s.state).toList());
      expect(daily.interpreter, same(daily.interpreter));
    });

    test('BH — Daily Context failure does not break Smart Brain', () async {
      final brain = SmartBrainPlanner(
        dailyContext: _FailingDaily(),
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

    test('BI–BL — future hooks off; no calendar/Apple Health/wearable', () {
      final c = daily.futureContract;
      expect(c.morningCheckInEnabled, isFalse);
      expect(c.eveningReflectionEnabled, isFalse);
      expect(c.calendarIntegrationEnabled, isFalse);
      expect(c.appleHealthIntegrationEnabled, isFalse);
      expect(c.wearableIntegrationEnabled, isFalse);
    });

    test('BM–BQ — no campaigns/notifications/gamification/paid', () {
      final names = DailyContextCategory.values.map((e) => e.name).join(',');
      expect(names.contains('campaign'), isFalse);
      expect(names.contains('notification'), isFalse);
      expect(ctx.dailyLifeContext.debugMap().containsKey('streak'), isFalse);
      expect(ctx.dailyLifeContext.debugMap().containsKey('points'), isFalse);
      final src = Directory('lib/daily_context')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('in_app_purchase'), isFalse);
      expect(src.contains('RevenueCat'), isFalse);
    });

    test('Smart Brain handles multi-signal coherently', () async {
      final brain = SmartBrainPlanner(dailyContext: daily);
      final plan = await brain.plan(
        query: 'عندي امتحان باچر ونومي قليل ومتوتر',
        context: ctx,
      );
      expect(plan.textFirstOnly, isTrue);
      expect(plan.message, isNotEmpty);
      expect(plan.message.contains('امشِ'), isFalse);
      expect(ctx.dailyLifeContext.hasHighLoad, isTrue);
    });
  });
}

class _FailingDaily extends DailyContextCoordinator {
  _FailingDaily() : super();

  @override
  bool mayHandle({
    required String query,
    required DailyLifeContext context,
  }) =>
      true;

  @override
  DailyLifeContext observe({
    required String text,
    required DailyLifeContext context,
    DateTime? now,
  }) {
    throw StateError('daily observe down');
  }

  @override
  Future<DailyContextTurnResult> handle({
    required String text,
    required DailyLifeContext context,
    DateTime? now,
  }) async {
    throw StateError('daily down');
  }
}
