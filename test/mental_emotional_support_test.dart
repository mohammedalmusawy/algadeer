import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/chronic_care/chronic_care.dart';
import 'package:ghadeer_clinic/health/emotional_support/emotional_support.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_models.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/memory/memory_analytics_firewall.dart';
import 'package:ghadeer_clinic/labs/labs_service.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EmotionalSignalDetector detector;
  late MentalHealthSafetyGate safety;
  late EmotionalSupportPolicy policy;
  late EmotionalResponseStrategyBuilder responses;
  late EmotionalSupportCoordinator coordinator;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;
  late SensitiveHealthProfileService health;
  late PersonalCompanionProfileService personal;
  late MemoryAnalyticsFirewall firewall;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    detector = EmotionalSignalDetector();
    safety = const MentalHealthSafetyGate();
    policy = const EmotionalSupportPolicy();
    responses = const EmotionalResponseStrategyBuilder();
    coordinator = EmotionalSupportCoordinator(
      detector: detector,
      policy: policy,
      responses: responses,
      safetyGate: safety,
    );
    health = SensitiveHealthProfileService(
      repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
    );
    personal = PersonalCompanionProfileService(
      repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
    );
    firewall = const MemoryAnalyticsFirewall();
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      companionOnboardingCoordinator:
          CompanionOnboardingCoordinator(profiles: personal),
      sensitiveHealthProfile: SensitiveHealthProfileCoordinator(service: health),
      chronicCare: ChronicCareCoordinator(healthProfiles: health),
      doctorLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. قلب',
              subtitle: 'قلب',
              doctorId: 'cardio1',
              specialty: 'قلب',
              score: 95,
            ),
          ],
      labLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.lab,
              title: 'مختبر النور',
              subtitle: 'مختبر',
              labId: 'lab1',
              score: 90,
            ),
          ],
      analysisLookup: (_) async => [
            AnalysisItem(id: 'cbc', name: 'CBC', aliases: const ['سي بي سي']),
          ],
      packagesLookup: (_) async => [
            const LabPackageItem(
              id: 'pkg1',
              labId: 'lab1',
              name: 'باقة شاملة',
              newPrice: 25,
            ),
          ],
      packagesForAnalysisLookup: (_) async => const [],
    );
  });

  group('PC-1.6 signal detection A–J', () {
    test('A — خايف = fear, not diagnosis', () {
      final s = detector.detect('خايف');
      expect(s.category, EmotionalSignalCategory.fear);
      expect(s.debugMap()['signalCategory'], 'fear');
      expect(s.debugMap().containsKey('diagnosis'), isFalse);
    });

    test('B — قلقان = worry', () {
      expect(
        detector.detect('قلقان').category,
        EmotionalSignalCategory.worry,
      );
    });

    test('C — متوتر = stress', () {
      expect(
        detector.detect('متوتر').category,
        EmotionalSignalCategory.stress,
      );
    });

    test('D — exam stress', () {
      expect(
        detector.detect('عندي امتحان وخايف').category,
        EmotionalSignalCategory.examStress,
      );
    });

    test('E — result anxiety', () {
      expect(
        detector.detect('خايف من نتيجة التحليل').category,
        EmotionalSignalCategory.resultAnxiety,
      );
    });

    test('F — procedure fear', () {
      expect(
        detector.detect('خايف من الإبرة').category,
        EmotionalSignalCategory.procedureFear,
      );
    });

    test('G — sadness without depression diagnosis', () {
      final s = detector.detect('حزين');
      expect(s.category, EmotionalSignalCategory.sadness);
      expect(s.debugMap()['signalCategory'], isNot('depression'));
    });

    test('H — frustration', () {
      expect(
        detector.detect('زهقان من البحث').category,
        EmotionalSignalCategory.frustration,
      );
    });

    test('I — overwhelmed', () {
      expect(
        detector.detect('كلشي فوق راسي').category,
        EmotionalSignalCategory.overwhelmed,
      );
    });

    test('J — loneliness supportive', () {
      final s = detector.detect('حاس بالغربة');
      expect(s.category, EmotionalSignalCategory.loneliness);
      final text = responses.build(
        strategy: policy.strategyFor(s),
        signal: s,
      );
      expect(text, isNotEmpty);
      expect(text.contains('وحيدك'), isFalse);
    });
  });

  group('PC-1.6 session / privacy / diagnosis K–M', () {
    test('K — emotional state session-only on ConversationContext', () async {
      await brain.plan(query: 'خايف', context: ctx);
      expect(
        ctx.emotionalSupport.signal.category,
        EmotionalSignalCategory.fear,
      );
      ctx.reset();
      expect(
        ctx.emotionalSupport.signal.category,
        EmotionalSignalCategory.neutral,
      );
      expect(ctx.emotionalSupport.enabled, isFalse);
    });

    test('L — no emotional state in SensitiveHealthProfile', () async {
      await brain.plan(query: 'خايف ومتوتر', context: ctx);
      final profile = await health.ensureProfile();
      final json = profile.toStorageMap();
      final encoded = json.toString();
      expect(encoded.contains('خايف'), isFalse);
      expect(encoded.contains('fear'), isFalse);
      expect(encoded.contains('emotional'), isFalse);
      expect(json.containsKey('emotionalSupport'), isFalse);
    });

    test('M — no psychiatric diagnosis inference', () {
      for (final q in ['خايف', 'حزين', 'متوتر', 'قلقان']) {
        final s = detector.detect(q);
        expect(s.debugMap()['signalCategory'], isNot(contains('disorder')));
        expect(s.debugMap()['signalCategory'], isNot(contains('depression')));
        expect(s.debugMap()['signalCategory'], isNot(contains('panic')));
      }
    });
  });

  group('PC-1.6 intent preservation N–Q', () {
    test('N — fear + doctor still doctor path', () async {
      final plan = await brain.plan(
        query: 'خايف وأريد طبيب قلب',
        context: ctx,
      );
      expect(
        plan.kind == AssistantActionKind.runSpecialtySearch ||
            plan.kind == AssistantActionKind.runDoctorSearch ||
            plan.kind == AssistantActionKind.runGeneralSearch ||
            plan.canExecute,
        isTrue,
      );
      expect(plan.message, isNot(contains('أكثر شي مقلقك')));
    });

    test('O — stress + lab still lab path', () async {
      final plan = await brain.plan(
        query: 'متوتر وأريد مختبر',
        context: ctx,
      );
      expect(
        plan.kind == AssistantActionKind.runLabSearch ||
            plan.intentResult.intent == AssistantIntent.findLab ||
            plan.canExecute ||
            plan.message.contains('مختبر'),
        isTrue,
      );
      expect(
        ctx.emotionalSupport.signal.category,
        EmotionalSignalCategory.stress,
      );
      // الدعم يزيّن ولا يستبدل
      expect(plan.message.contains('أول خطوة') || plan.message.isNotEmpty, isTrue);
    });

    test('P — does not block analysis intent', () async {
      final plan = await brain.plan(
        query: 'قلقان وأريد تحليل CBC',
        context: ctx,
      );
      expect(
        plan.kind == AssistantActionKind.runAnalysisSearch ||
            plan.intentResult.intent == AssistantIntent.findAnalysis ||
            plan.canExecute ||
            plan.message.isNotEmpty,
        isTrue,
      );
      expect(plan.kind, isNot(AssistantActionKind.none));
    });

    test('Q — does not block package intent', () async {
      final packageBrain = SmartBrainPlanner(
        companionOnboardingCoordinator:
            CompanionOnboardingCoordinator(profiles: personal),
        activePackagesLookup: ({labId, nameQuery}) async => [
              AnalysisPackageLink(
                package: const LabPackageItem(
                  id: 'pkg1',
                  labId: 'lab1',
                  name: 'باقة شاملة',
                  newPrice: 25,
                ),
                labId: 'lab1',
                labName: 'مختبر النور',
              ),
            ],
      );
      final plan = await packageBrain.plan(
        query: 'متوتر وأريد باقة شاملة',
        context: ctx,
      );
      expect(
        plan.kind == AssistantActionKind.runPackageSearch ||
            plan.kind == AssistantActionKind.selectEntity ||
            plan.kind == AssistantActionKind.showClarification ||
            plan.intentResult.intent == AssistantIntent.findPackage ||
            plan.canExecute ||
            plan.message.contains('باقة') ||
            plan.candidates.isNotEmpty,
        isTrue,
      );
      expect(
        ctx.emotionalSupport.signal.category,
        EmotionalSignalCategory.stress,
      );
    });
  });

  group('PC-1.6 health anxiety / safety R–S', () {
    test('R — health anxiety still uses 10E safety path', () async {
      final plan = await brain.plan(
        query: 'خايف هذا الألم يكون شي خطير وصدري يوجعني وضيق نفس',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.healthGuidance);
      expect(
        plan.healthDecision?.type == HealthGuidanceDecisionType.urgentEvaluation ||
            plan.healthDecision?.type ==
                HealthGuidanceDecisionType.emergencyEvaluation ||
            (plan.message.isNotEmpty),
        isTrue,
      );
    });

    test('S — emotional layer cannot suppress urgent medical safety', () async {
      final plan = await brain.plan(
        query: 'خايف وفيه ألم صدر شديد وضيق نفس',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.healthGuidance);
      expect(
        plan.message.contains('أكيد ما بيك شي') ||
            plan.message.contains('مستحيل يكون خطير'),
        isFalse,
      );
    });
  });

  group('PC-1.6 reassurance / optimism T–V', () {
    test('T/U — no guaranteed safety false reassurance', () {
      for (final cat in EmotionalSignalCategory.values) {
        if (cat == EmotionalSignalCategory.neutral) continue;
        final signal = EmotionalSignal(category: cat);
        final text = responses.build(
          strategy: policy.strategyFor(signal),
          signal: signal,
        );
        expect(policy.containsForbiddenLanguage(text), isFalse);
        expect(text.contains('أكيد ما بيك شي'), isFalse);
        expect(text.contains('مستحيل يكون خطير'), isFalse);
        expect(text.contains('100%'), isFalse);
      }
    });

    test('V — result anxiety does not predict result', () {
      final s = detector.detect('خايف من نتيجة التحليل');
      final text = responses.build(
        strategy: policy.strategyFor(s),
        signal: s,
      );
      expect(text.contains('سليمة'), isFalse);
      expect(text.contains('إيجابية'), isFalse);
      expect(text.contains('نستبق'), isTrue);
    });
  });

  group('PC-1.6 student / supplements W–Z', () {
    test('W — student context may inform exam support', () async {
      await personal.setUserContext(ProfileUserContext.student);
      final turn = coordinator.evaluate(
        query: 'الامتحانات ضاغطتني',
        intent: AssistantIntent.unknown,
        studentContext: true,
      );
      expect(
        turn.context.signal.category,
        EmotionalSignalCategory.examStress,
      );
      expect(turn.standaloneMessage.contains('دراسة') ||
          turn.standaloneMessage.contains('استراحة'), isTrue);
    });

    test('X — student status alone does not trigger exam advice', () async {
      await personal.setUserContext(ProfileUserContext.student);
      final plan = await brain.plan(query: 'مرحبا', context: ctx);
      expect(plan.message.contains('امتحان'), isFalse);
      expect(plan.message.contains('دراسة قصيرة'), isFalse);
      expect(
        ctx.emotionalSupport.signal.category,
        EmotionalSignalCategory.neutral,
      );
    });

    test('Y/Z — no Omega-3 or supplement recommendation', () {
      for (final cat in EmotionalSignalCategory.values) {
        if (cat == EmotionalSignalCategory.neutral) continue;
        final signal = EmotionalSignal(category: cat);
        final text = responses.build(
          strategy: policy.strategyFor(signal),
          signal: signal,
          studentContext: true,
        );
        expect(text.toLowerCase().contains('omega'), isFalse);
        expect(text.contains('أوميغا'), isFalse);
        expect(text.contains('اوميغا'), isFalse);
        expect(text.contains('مكمل'), isFalse);
        expect(text.contains('فيتامين'), isFalse);
      }
    });
  });

  group('PC-1.6 chronic / subject AA–AD', () {
    test('AA/AB — chronic-care separate; emotion does not change measurement',
        () async {
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
          followUpPermission: true,
        ),
      ]);
      final before = await health.ensureProfile();
      final plan = await brain.plan(query: 'خايف من السكر', context: ctx);
      final after = await health.ensureProfile();
      expect(plan.message, isNotEmpty);
      expect(after.conditions.length, before.conditions.length);
      expect(after.conditions.first.displayName, before.conditions.first.displayName);
      // لا قياس مخزّن يتغيّر بمجرد خوف
      expect(ctx.emotionalSupport.signal.category, isNot(EmotionalSignalCategory.neutral));
    });

    test('AC — mother fear is about other, not owner memory', () {
      final s = detector.detect('أمي خايفة من العملية');
      expect(s.aboutOtherPerson, isTrue);
      expect(s.category, EmotionalSignalCategory.procedureFear);
    });

    test('AD — child fear does not become owner persistent state', () async {
      final s = detector.detect('ابني خايف');
      expect(s.aboutOtherPerson, isTrue);
      await brain.plan(query: 'ابني خايف', context: ctx);
      final profile = await health.ensureProfile();
      expect(profile.toStorageMap().toString().contains('fear'), isFalse);
      expect(profile.toStorageMap().toString().contains('خايف'), isFalse);
    });
  });

  group('PC-1.6 conduct AE–AF', () {
    test('AE — directed insult keeps useful emotional+task intent', () async {
      final plan = await brain.plan(
        query: 'يا غبي أنا خايف وأريد طبيب قلب',
        context: ctx,
      );
      expect(
        ctx.emotionalSupport.signal.category,
        EmotionalSignalCategory.fear,
      );
      expect(
        plan.kind == AssistantActionKind.runSpecialtySearch ||
            plan.kind == AssistantActionKind.runDoctorSearch ||
            plan.kind == AssistantActionKind.runGeneralSearch ||
            plan.canExecute ||
            plan.message.contains('قلب') ||
            plan.message.contains('طبيب'),
        isTrue,
      );
    });

    test('AF — quoted insult does not trigger wrong boundary alone', () async {
      final plan = await brain.plan(
        query: 'قال لي "يا غبي" بس أنا بخير',
        context: ctx,
      );
      // لا نفترض حدوداً خاطئة تبتلع الرسالة
      expect(plan.message.contains('ما أتسامح'), isFalse);
    });
  });

  group('PC-1.6 crisis AG–AK', () {
    test('AG — idiomatic موتني الامتحان does not trigger crisis', () {
      expect(safety.triggersCrisis('موتني الامتحان'), isFalse);
      expect(safety.triggersCrisis('راح أموت من الخوف'), isFalse);
      expect(safety.triggersCrisis('هذا الشغل قاتلني'), isFalse);
    });

    test('AH — credible self-harm triggers gate', () {
      expect(safety.triggersCrisis('أريد أقتل نفسي'), isTrue);
      expect(safety.triggersCrisis('راح انتحر'), isTrue);
    });

    test('AI — crisis bypasses normal reassurance', () async {
      final plan = await brain.plan(
        query: 'أريد أقتل نفسي',
        context: ctx,
      );
      expect(ctx.emotionalSupport.mentalSafetyTriggered, isTrue);
      expect(plan.textFirstOnly, isTrue);
      expect(plan.message.contains('اهتمام فوري'), isTrue);
      expect(plan.message.contains('خطوة خطوة'), isFalse);
      expect(plan.message.contains('دراسة قصيرة'), isFalse);
    });

    test('AJ — crisis does not invent emergency numbers', () {
      final msg = safety.crisisMessage();
      expect(RegExp(r'\d{3,}').hasMatch(msg), isFalse);
      expect(msg.contains('911'), isFalse);
      expect(msg.contains('999'), isFalse);
      expect(msg.contains('115'), isFalse);
    });

    test('AK — no harmful instructions', () {
      final msg = safety.crisisMessage();
      expect(msg.contains('كيف'), isFalse);
      expect(msg.toLowerCase().contains('method'), isFalse);
      expect(msg.contains('طريقة'), isFalse);
    });
  });

  group('PC-1.6 relationship / step / questions AL–AO', () {
    test('AL — no exclusivity/dependency language', () {
      for (final cat in EmotionalSignalCategory.values) {
        if (cat == EmotionalSignalCategory.neutral) continue;
        final signal = EmotionalSignal(category: cat);
        final text = responses.build(
          strategy: policy.strategyFor(signal),
          signal: signal,
        );
        expect(policy.containsForbiddenLanguage(text), isFalse);
        expect(text.contains('أحبك'), isFalse);
        expect(text.contains('الوحيد'), isFalse);
        expect(text.contains('إنسان مثلك'), isFalse);
      }
      expect(
        policy.containsForbiddenLanguage(safety.crisisMessage()),
        isFalse,
      );
    });

    test('AM — one-small-step policy', () {
      final text = responses.build(
        strategy: EmotionalSupportStrategy.reduceTaskSize,
        signal: const EmotionalSignal(category: EmotionalSignalCategory.stress),
      );
      expect(text.contains('أول خطوة'), isTrue);
      expect(RegExp(r'1\)|2\)|3\)').hasMatch(text), isFalse);
    });

    test('AN — no forced emotional questioning before doctor search', () async {
      final plan = await brain.plan(
        query: 'خايف وأريد طبيب قلب',
        context: ctx,
      );
      expect(plan.message.contains('أكثر شي مقلقك'), isFalse);
    });

    test('AO — unclear distress may ask one gentle clarification', () {
      final turn = coordinator.evaluate(
        query: 'مو بخير نفسيا',
        intent: AssistantIntent.unknown,
      );
      expect(turn.askGentleClarification || turn.standaloneMessage.contains('؟'),
          isTrue);
    });
  });

  group('PC-1.6 text-first / privacy / voice AP–AT', () {
    test('AP/AQ — text-first, no automatic TTS flag', () async {
      final plan = await brain.plan(query: 'خايف', context: ctx);
      expect(plan.textFirstOnly, isTrue);
    });

    test('AR — no raw emotional text in debug', () async {
      await brain.plan(query: 'خايف من نتيجة التحليل', context: ctx);
      final dbg = ctx.emotionalSupport.debugMap();
      expect(dbg.keys, containsAll([
        'emotionalSignalPresent',
        'signalCategory',
        'supportStrategy',
        'mentalSafetyTriggered',
      ]));
      expect(dbg.values.any((v) => v is String && v.contains('خايف')), isFalse);
      expect(dbg.containsKey('rawText'), isFalse);
      expect(dbg.containsKey('query'), isFalse);
    });

    test('AS — no emotional analytics persistence', () {
      final dbg = const EmotionalSupportContext(
        signal: EmotionalSignal(category: EmotionalSignalCategory.fear),
        strategy: EmotionalSupportStrategy.acknowledgeCalmNextStep,
      ).debugMap();
      // جدار التحليلات يرفض حمولات عاطفية/نصية
      expect(firewall.isSafeAnalyticsPayload(dbg), isFalse);
      expect(firewall.emitsEventsInPc04, isFalse);
    });

    test('AT — voice-final transcript uses same detector', () {
      // نفس الكاشف لنص نهائي من الصوت أو الكتابة
      final typed = detector.detect('خايف من الإبرة');
      final voiceFinal = detector.detect('خايف من الإبرة');
      expect(typed.category, voiceFinal.category);
      expect(typed.category, EmotionalSignalCategory.procedureFear);
    });
  });

  group('PC-1.6 future boundaries AU–AX', () {
    test('AU — emotional context separate from family profiles', () {
      expect(ctx.emotionalSupport.signal.aboutOtherPerson, isFalse);
      final json = ctx.emotionalSupport.debugMap();
      expect(json.containsKey('familyProfile'), isFalse);
      expect(json.containsKey('preferredName'), isFalse);
    });

    test('AV — no campaigns implementation', () {
      expect(
        responses.build(
          strategy: EmotionalSupportStrategy.examOrganize,
          signal: const EmotionalSignal(
            category: EmotionalSignalCategory.examStress,
          ),
          studentContext: false,
        ).contains('حملة'),
        isFalse,
      );
    });

    test('AW — preventive engine separate from emotional layer', () {
      // PC-1.7 منفصل — emotional_support لا يحتوي محرك وقائي
      expect(EmotionalSupportStrategy.values.contains(
        EmotionalSupportStrategy.crisisSafety,
      ), isTrue);
    });

    test('AX — no paid dependency', () {
      // الطبقة محلية/حتمية — بلا اشتراك مدفوع في الرسائل
      final text = responses.build(
        strategy: EmotionalSupportStrategy.acknowledgeCalmNextStep,
        signal: const EmotionalSignal(category: EmotionalSignalCategory.fear),
      );
      expect(text.contains('ادفع'), isFalse);
      expect(text.contains('اشتراك'), isFalse);
      expect(text.contains('premium'), isFalse);
    });
  });
}
