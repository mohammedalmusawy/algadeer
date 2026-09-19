import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/emotional_support/emotional_support.dart';
import 'package:ghadeer_clinic/health/preventive/preventive.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/memory/memory_analytics_firewall.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingCatalog implements PreventiveGuidanceCatalogSource {
  @override
  Future<List<PreventiveGuidanceRule>> loadActiveRules() async {
    throw StateError('catalog fail');
  }

  @override
  Future<PreventiveGuidanceRule?> findById(String ruleId) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalPreventiveGuidanceCatalog catalog;
  late PreventiveGuidanceEligibility eligibility;
  late PreventiveGuidancePlanner planner;
  late PreventiveGuidanceResponseBuilder responses;
  late PreventiveGuidanceInterpreter interpreter;
  late PreventiveGuidanceContextBuilder ctxBuilder;
  late PreventiveGuidanceCoordinator coordinator;
  late PersonalCompanionProfileService personal;
  late SensitiveHealthProfileService health;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;
  late MemoryAnalyticsFirewall firewall;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    catalog = LocalPreventiveGuidanceCatalog();
    eligibility = const PreventiveGuidanceEligibility();
    planner = PreventiveGuidancePlanner(catalog: catalog);
    responses = PreventiveGuidanceResponseBuilder(catalog: catalog);
    interpreter = const PreventiveGuidanceInterpreter();
    ctxBuilder = const PreventiveGuidanceContextBuilder();
    personal = PersonalCompanionProfileService(
      repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
    );
    health = SensitiveHealthProfileService(
      repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
    );
    coordinator = PreventiveGuidanceCoordinator(
      profiles: personal,
      healthProfiles: health,
      catalog: catalog,
    );
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      companionOnboardingCoordinator:
          CompanionOnboardingCoordinator(profiles: personal),
      sensitiveHealthProfile: SensitiveHealthProfileCoordinator(service: health),
      preventiveGuidance: coordinator,
      doctorLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. عام',
              subtitle: 'باطنية',
              doctorId: 'd1',
              specialty: 'باطنية',
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
    firewall = const MemoryAnalyticsFirewall();
  });

  PreventiveGuidanceContext buildCtx({
    PersonalCompanionProfile? profile,
    PreventiveGuidanceTopic topic = PreventiveGuidanceTopic.general,
    EmotionalSignalCategory emotional = EmotionalSignalCategory.neutral,
    Set<String> conditions = const {},
    DateTime? now,
  }) {
    return ctxBuilder.build(
      profile: profile,
      permittedConditions: conditions.isEmpty
          ? const []
          : [
              HealthConditionRecord(
                id: 'hc1',
                canonicalConditionKey: conditions.first,
                displayName: conditions.first,
                diagnosisStatus: HealthDiagnosisStatus.diagnosed,
                diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
                consentState: HealthConsentState.granted,
                createdAt: DateTime(2020),
                updatedAt: DateTime(2020),
              ),
            ],
      emotionalCategory: emotional,
      requestTopic: topic,
      intent: PreventiveIntent.generalPrevention,
      now: now,
    );
  }

  group('PC-1.7 age A–F', () {
    test('A — unknown age → no invented age guidance', () async {
      final c = buildCtx(profile: null, topic: PreventiveGuidanceTopic.ageAppropriate);
      final plan = await planner.plan(context: c);
      final msg = await responses.build(plan: plan, context: c);
      expect(msg.contains('45'), isFalse);
      expect(msg.contains('فحص'), isFalse);
      expect(msg.contains('ما عندي عمرك'), isTrue);
    });

    test('B — age from birthYear dynamic', () async {
      await personal.ensureProfile();
      await personal.setBirthYear(1990);
      final p = await personal.loadProfile();
      final c = buildCtx(profile: p, now: DateTime(2026, 6, 1));
      expect(p!.currentAge(now: DateTime(2026, 6, 1)), 36);
      final plan = await planner.plan(
        context: c.copyTopic(PreventiveGuidanceTopic.ageAppropriate),
      );
      expect(plan.selectedRuleIds, isNotEmpty);
    });

    test('C — age from birthDate dynamic', () async {
      await personal.ensureProfile();
      await personal.setBirthDate(DateTime(1985, 3, 10));
      final p = await personal.loadProfile();
      expect(p!.currentAge(now: DateTime(2026, 3, 10)), 41);
      final plan = await planner.plan(
        context: buildCtx(profile: p, now: DateTime(2026, 3, 10)),
      );
      expect(plan.selectedRuleIds, isNotEmpty);
    });

    test('D — no fixed age persistence', () async {
      await personal.setBirthYear(1980);
      final p = await personal.loadProfile();
      final map = p!.toStorageMap();
      expect(map.containsKey('age'), isFalse);
      expect(map['birthYear'], 1980);
    });

    test('E — age 45 does not blindly trigger every rule', () async {
      await personal.setBirthYear(1981);
      final p = await personal.loadProfile();
      final c = buildCtx(
        profile: p,
        topic: PreventiveGuidanceTopic.diet,
        now: DateTime(2026, 1, 1),
      );
      final plan = await planner.plan(context: c);
      expect(plan.selectedRuleIds.length, lessThanOrEqualTo(3));
      expect(
        plan.selectedRuleIds.every((id) => id.contains('screening')),
        isFalse,
      );
    });

    test('F — rule population applicability respected', () async {
      final rules = await catalog.loadActiveRules();
      final rule = rules.firstWhere(
        (r) => r.ruleId == 'prev_student_sleep_routine',
      );
      final studentCtx = buildCtx(
        profile: PersonalCompanionProfile(
          profileId: 'p',
          ownerKey: 'o',
          userContext: ProfileUserContext.student,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      );
      final nonStudent = buildCtx(profile: null);
      expect(eligibility.isEligible(rule: rule, context: studentCtx), isTrue);
      expect(eligibility.isEligible(rule: rule, context: nonStudent), isFalse);
    });
  });

  group('PC-1.7 activity/diet/salt G–K', () {
    test('G — general physical activity guidance', () async {
      final c = buildCtx(
        profile: PersonalCompanionProfile(
          profileId: 'p',
          ownerKey: 'o',
          birthYear: 1995,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
        topic: PreventiveGuidanceTopic.activity,
      );
      final plan = await planner.plan(context: c);
      expect(
        plan.selectedRuleIds.any((id) => id.contains('activity')),
        isTrue,
      );
    });

    test('H — walking example not mandatory prescription', () async {
      final c = buildCtx(
        profile: PersonalCompanionProfile(
          profileId: 'p',
          ownerKey: 'o',
          birthYear: 1995,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
        topic: PreventiveGuidanceTopic.walking,
      );
      final plan = await planner.plan(context: c);
      final msg = await responses.build(plan: plan, context: c);
      expect(msg.contains('مثال'), isTrue);
      expect(msg.contains('مو جرعة ثابتة'), isTrue);
    });

    test('I — healthy diet guidance', () async {
      final interp = interpreter.interpret('شنو أغير بأكلي؟');
      expect(interp.topic, PreventiveGuidanceTopic.diet);
      final turn = await coordinator.handle(
        text: 'شنو أغير بأكلي؟',
        session: ctx.preventiveSession,
      );
      expect(turn.handled, isTrue);
      expect(turn.message.contains('خضار'), isTrue);
    });

    test('J — salt guidance uses reviewed rule', () async {
      final c = buildCtx(
        profile: PersonalCompanionProfile(
          profileId: 'p',
          ownerKey: 'o',
          birthYear: 1990,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
        topic: PreventiveGuidanceTopic.salt,
      );
      final plan = await planner.plan(context: c);
      expect(plan.selectedRuleIds.contains('prev_salt_general_adult'), isTrue);
    });

    test('K — no unsupported therapeutic diet', () async {
      final turn = await coordinator.handle(
        text: 'شنو أغير بأكلي؟',
        session: ctx.preventiveSession,
      );
      expect(turn.message.contains('خطة وجبات'), isFalse);
      expect(turn.message.contains('سعرات'), isFalse);
    });
  });

  group('PC-1.7 student/employee/supplements L–S', () {
    test('L — student context personalizes requested advice', () async {
      await personal.setUserContext(ProfileUserContext.student);
      final turn = await coordinator.handle(
        text: 'أنا طالب شنو تنصحني؟',
        session: ctx.preventiveSession,
      );
      expect(turn.handled, isTrue);
      expect(
        turn.message.contains('طالب') ||
            turn.message.contains('نوم') ||
            turn.message.contains('دراسة'),
        isTrue,
      );
    });

    test('M — student alone does not trigger unsolicited advice', () async {
      await personal.setUserContext(ProfileUserContext.student);
      final plan = await brain.plan(query: 'مرحبا', context: ctx);
      expect(plan.message.contains('امتحان'), isFalse);
      expect(plan.message.contains('دراسة'), isFalse);
    });

    test('N — exam advice short/contextual', () async {
      await personal.setUserContext(ProfileUserContext.student);
      final turn = await coordinator.handle(
        text: 'شنو نصائحك بفترة الامتحانات؟',
        session: ctx.preventiveSession,
      );
      expect(turn.message.length, lessThan(600));
      expect(turn.ruleIds.length, lessThanOrEqualTo(3));
    });

    test('O/P/Q — no supplement auto recommendation', () async {
      await personal.setUserContext(ProfileUserContext.student);
      await personal.setBirthYear(1975);
      for (final q in [
        'أنا طالب شنو تنصحني؟',
        'شنو تنصحني بهذا العمر؟',
        'شنو نصائحك بفترة الامتحانات؟',
        'شلون أحافظ على صحتي؟',
      ]) {
        final turn = await coordinator.handle(
          text: q,
          session: PreventiveGuidanceSession.inactive,
        );
        expect(responses.containsSupplementRecommendation(turn.message), isFalse);
      }
    });

    test('R — employee movement breaks', () async {
      await personal.setUserContext(ProfileUserContext.employee);
      final c = buildCtx(
        profile: await personal.loadProfile(),
        topic: PreventiveGuidanceTopic.employeeRoutine,
      );
      final plan = await planner.plan(context: c);
      expect(
        plan.selectedRuleIds.contains('prev_employee_movement_breaks'),
        isTrue,
      );
    });

    test('S — self-employed without invented hazards', () async {
      await personal.setUserContext(ProfileUserContext.selfEmployed);
      final turn = await coordinator.handle(
        text: 'شلون أحافظ على صحتي؟',
        session: ctx.preventiveSession,
      );
      expect(turn.message.contains('مصنع'), isFalse);
      expect(turn.message.contains('مواد كيميائية'), isFalse);
    });
  });

  group('PC-1.7 chronic/emotional/priority T–Y', () {
    test('T — chronic retrieval purpose-limited', () async {
      final now = DateTime.now();
      await health.upsertConditions([
        HealthConditionRecord(
          id: 'hc_htn',
          canonicalConditionKey: 'hypertension',
          displayName: 'ضغط',
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          consentState: HealthConsentState.granted,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final turn = await coordinator.handle(
        text: 'شلون أحافظ على صحتي؟ عندي ضغط',
        session: ctx.preventiveSession,
      );
      expect(turn.message.contains('غيّر الدواء'), isFalse);
      expect(turn.message.contains('غيّر دواء'), isFalse);
      expect(turn.message.contains('غيّر جرعة'), isFalse);
    });

    test('U — hypertension does not change medication', () async {
      final turn = await coordinator.handle(
        text: 'نصائح ملح',
        session: ctx.preventiveSession,
      );
      expect(turn.message.contains('غيّر الدواء'), isFalse);
    });

    test('V — diabetes does not create new clinical status', () async {
      final now = DateTime.now();
      await health.upsertConditions([
        HealthConditionRecord(
          id: 'hc_dm',
          canonicalConditionKey: 'diabetes',
          displayName: 'سكري',
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          consentState: HealthConsentState.granted,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final before = await health.ensureProfile();
      await coordinator.handle(
        text: 'شنو الفحوصات الوقائية المناسبة لعمري؟',
        session: ctx.preventiveSession,
      );
      final after = await health.ensureProfile();
      expect(after.conditions.length, before.conditions.length);
      expect(after.conditions.first.controlStatus, isNull);
    });

    test('W — emotional stress reduces overload', () async {
      final c = buildCtx(
        profile: PersonalCompanionProfile(
          profileId: 'p',
          ownerKey: 'o',
          birthYear: 1990,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
        emotional: EmotionalSignalCategory.overwhelmed,
      );
      final plan = await planner.plan(context: c);
      expect(plan.selectedRuleIds.length, lessThanOrEqualTo(1));
    });

    test('X — mental safety outranks preventive', () async {
      final turn = await coordinator.handle(
        text: 'أريد أقتل نفسي وشنو تنصحني؟',
        session: ctx.preventiveSession,
      );
      expect(turn.deferToMentalSafety, isTrue);
      expect(turn.handled, isFalse);
    });

    test('Y — medical urgent outranks preventive', () async {
      final turn = await coordinator.handle(
        text: 'ضيق نفس شديد وشنو تنصحني؟',
        session: ctx.preventiveSession,
      );
      expect(turn.deferToUrgentSafety, isTrue);
    });
  });

  group('PC-1.7 escape/screening/levels Z–AG', () {
    test('Z — doctor request escapes preventive', () async {
      final may = coordinator.mayHandle(
        query: 'زين أريد طبيب',
        session: PreventiveGuidanceSession.inactive,
      );
      expect(may, isFalse);
      final plan = await brain.plan(query: 'زين أريد طبيب', context: ctx);
      expect(
        plan.kind == AssistantActionKind.runGeneralSearch ||
            plan.kind == AssistantActionKind.runDoctorSearch ||
            plan.canExecute,
        isTrue,
      );
    });

    test('AA — lab request escapes', () async {
      final plan = await brain.plan(query: 'أريد مختبر', context: ctx);
      expect(
        plan.intentResult.intent == AssistantIntent.findLab ||
            plan.kind == AssistantActionKind.runLabSearch ||
            plan.canExecute,
        isTrue,
      );
    });

    test('AB/AC — screening rule has evidence metadata', () async {
      final rules = await catalog.loadActiveRules();
      final rule = rules.firstWhere(
        (r) => r.ruleId == 'prev_screening_bp_adult',
      );
      expect(rule.sourceOrganization, isNotEmpty);
      expect(rule.sourceReference, isNotEmpty);
      expect(rule.reviewedAt, isNotNull);
      expect(rule.applicablePopulation, isNotEmpty);
    });

    test('AD — screening not diagnosis', () async {
      await personal.setBirthYear(1980);
      final turn = await coordinator.handle(
        text: 'شنو الفحوصات الوقائية المناسبة لعمري؟',
        session: ctx.preventiveSession,
      );
      expect(turn.message.contains('عندك مرض'), isFalse);
      expect(turn.message.contains('تم تشخيصك'), isFalse);
      expect(turn.message.contains('ناقش'), isTrue);
    });

    test('AE — no universal 45=test X', () async {
      await personal.setBirthYear(1981);
      final c = buildCtx(
        profile: await personal.loadProfile(),
        topic: PreventiveGuidanceTopic.general,
        now: DateTime(2026, 1, 1),
      );
      final plan = await planner.plan(context: c);
      expect(
        plan.selectedRuleIds.where((id) => id.contains('screening')).length,
        lessThanOrEqualTo(1),
      );
    });

    test('AF — personalization levels', () async {
      final rules = await catalog.loadActiveRules();
      final clinician = rules.firstWhere(
        (r) =>
            r.personalizationLevel ==
            PreventivePersonalizationLevel.clinicianRequired,
      );
      expect(clinician.ruleId.contains('screening'), isTrue);
    });

    test('AG — clinician-required does not over-personalize', () async {
      await personal.setBirthYear(1980);
      final turn = await coordinator.handle(
        text: 'شنو الفحوصات الوقائية المناسبة لعمري؟',
        session: ctx.preventiveSession,
      );
      expect(turn.personalizationLevel,
          PreventivePersonalizationLevel.clinicianRequired);
      expect(turn.message.contains('طبيبك'), isTrue);
    });
  });

  group('PC-1.7 response policy/privacy AH–AU', () {
    test('AH — 1–3 suggestions default', () async {
      final turn = await coordinator.handle(
        text: 'شلون أحافظ على صحتي؟',
        session: ctx.preventiveSession,
      );
      expect(turn.ruleIds.length, greaterThan(0));
      expect(turn.ruleIds.length, lessThanOrEqualTo(3));
    });

    test('AI — user can request more', () async {
      await coordinator.handle(
        text: 'شلون أحافظ على صحتي؟',
        session: ctx.preventiveSession,
      );
      final turn = await coordinator.handle(
        text: 'أكمل',
        session: ctx.preventiveSession,
      );
      expect(turn.handled, isTrue);
    });

    test('AJ/AK — text-first no auto TTS', () async {
      final plan = await brain.plan(
        query: 'شلون أحافظ على صحتي؟',
        context: ctx,
      );
      expect(plan.textFirstOnly, isTrue);
    });

    test('AL — voice-final uses same planner', () async {
      final t1 = await coordinator.handle(
        text: 'شكد أمشي؟',
        session: PreventiveGuidanceSession.inactive,
      );
      final t2 = await coordinator.handle(
        text: 'شكد أمشي؟',
        session: PreventiveGuidanceSession.inactive,
      );
      expect(t1.ruleIds, t2.ruleIds);
    });

    test('AM/AN/AO — debug without sensitive values', () async {
      await personal.setBirthYear(1980);
      final turn = await coordinator.handle(
        text: 'انطيني نصائح تناسب عمري',
        session: ctx.preventiveSession,
      );
      final dbg = turn.debugMap();
      expect(dbg.containsKey('exactAge'), isFalse);
      expect(dbg.containsKey('diabetes'), isFalse);
      expect(dbg.containsKey('hypertension'), isFalse);
      expect(dbg['ruleCount'], isNotNull);
      expect(firewall.isSafeAnalyticsPayload(dbg), isTrue);
    });

    test('AP/AQ/AR — no campaigns/notifications/family', () {
      expect(PreventiveGuidanceSession.inactive.debugMap().containsKey('family'),
          isFalse);
    });

    test('AS — no paid dependency', () async {
      final turn = await coordinator.handle(
        text: 'شلون أحافظ على صحتي؟',
        session: ctx.preventiveSession,
      );
      expect(turn.message.contains('اشتراك'), isFalse);
      expect(turn.message.contains('premium'), isFalse);
    });

    test('AT — evidence vs localization separable', () async {
      final rules = await catalog.loadActiveRules();
      final rule = rules.first;
      expect(rule.presentationKey, isNotEmpty);
      expect(rule.evidenceMap()['sourceOrganization'], isNotNull);
    });

    test('AU — catalog failure fails safely', () async {
      final failCoord = PreventiveGuidanceCoordinator(
        catalog: _FailingCatalog(),
        planner: PreventiveGuidancePlanner(catalog: _FailingCatalog()),
        responses: PreventiveGuidanceResponseBuilder(catalog: _FailingCatalog()),
      );
      final turn = await failCoord.handle(
        text: 'شلون أحافظ على صحتي؟',
        session: PreventiveGuidanceSession.inactive,
      );
      expect(turn.message.contains('150–300'), isFalse);
      expect(turn.message.contains('ما أقدر'), isTrue);
    });
  });
}

extension on PreventiveGuidanceContext {
  PreventiveGuidanceContext copyTopic(PreventiveGuidanceTopic topic) {
    return PreventiveGuidanceContext(
      computedAge: computedAge,
      sexSelection: sexSelection,
      userContext: userContext,
      permittedConditionKeys: permittedConditionKeys,
      emotionalCategory: emotionalCategory,
      emotionalOverload: emotionalOverload,
      requestTopic: topic,
      intent: intent,
      catalogAvailable: catalogAvailable,
    );
  }
}
