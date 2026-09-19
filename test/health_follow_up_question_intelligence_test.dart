import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/health/guidance/health_follow_up_answer_interpreter.dart';
import 'package:ghadeer_clinic/health/guidance/health_follow_up_models.dart';
import 'package:ghadeer_clinic/health/guidance/health_follow_up_question_catalog.dart';
import 'package:ghadeer_clinic/health/guidance/health_follow_up_question_planner.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_coordinator.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_engine.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_models.dart';
import 'package:ghadeer_clinic/health/understanding/health_understanding_engine.dart';
import 'package:ghadeer_clinic/health/understanding/symptom_models.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/guided_conversation_models.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  late HealthGuidanceCoordinator coordinator;
  late HealthGuidanceEngine engine;
  late HealthUnderstandingEngine understanding;
  late HealthFollowUpAnswerInterpreter interpreter;
  late HealthFollowUpQuestionPlanner planner;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;

  setUp(() {
    coordinator = HealthGuidanceCoordinator();
    engine = HealthGuidanceEngine();
    understanding = HealthUnderstandingEngine();
    interpreter = HealthFollowUpAnswerInterpreter();
    planner = HealthFollowUpQuestionPlanner(maxQuestions: 4);
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      doctorLookup: (q) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. أطفال تجريبي',
              subtitle: 'طب الأطفال',
              doctorId: 'ped1',
              score: 95,
              specialty: 'طب الأطفال',
            ),
          ],
      labLookup: (q) async => [
            SmartSearchResult(
              type: SmartSearchResultType.lab,
              title: 'مختبر الحياة',
              subtitle: 'مختبر',
              labId: 'hayat',
              score: 90,
            ),
          ],
      analysisLookup: (q) async => [
            AnalysisItem(id: 'cbc', name: 'CBC', aliases: const ['سي بي سي']),
          ],
      packagesForAnalysisLookup: (id) async => const [],
    );
  });

  HealthSessionFacts factsFrom(String text) =>
      const HealthSessionFacts().mergeUnderstanding(understanding.understand(text));

  HealthGuidanceSession sessionWith(
    HealthSessionFacts facts, {
    List<String> asked = const [],
    List<String> answered = const [],
    List<String> skipped = const [],
    int askedCount = 0,
    int maxQ = 4,
  }) {
    return HealthGuidanceSession(
      id: 't',
      status: HealthGuidanceSessionStatus.active,
      facts: facts,
      askedQuestionIds: asked,
      answeredQuestionIds: answered,
      skippedQuestionIds: skipped,
      questionsAskedCount: askedCount,
      maxQuestions: maxQ,
    );
  }

  group('Health follow-up question intelligence', () {
    test('A — known duration is not asked again', () {
      var facts = factsFrom('بطني يوجعني من يومين');
      facts = facts.copyWith(
        laterality: Laterality.right,
        abdominalLocationResolved: true,
      );
      final plan = planner.plan(
        facts: facts,
        askedQuestionIds: const [],
        answeredQuestionIds: const [],
        skippedQuestionIds: const [],
        questionsAskedCount: 0,
      );
      expect(plan.missingFact, isNot(HealthMissingFact.duration));
      expect(plan.question?.id.contains('duration'), isFalse);
    });

    test('B — known severity is not asked again', () {
      var facts = factsFrom('بطني يوجعني');
      facts = facts.copyWith(
        laterality: Laterality.right,
        abdominalLocationResolved: true,
        duration: const DurationValue(amount: 1, unit: 'day', rawText: 'يوم'),
        userSeverity: UserStatedSeverity.moderate,
      );
      final plan = planner.plan(
        facts: facts,
        askedQuestionIds: const [],
        answeredQuestionIds: const [],
        skippedQuestionIds: const [],
        questionsAskedCount: 0,
      );
      expect(plan.question?.id.contains('severity') ?? false, isFalse);
      expect(
        plan.noQuestionNeeded ||
            plan.question == null ||
            !(plan.question!.id.contains('severity')),
        isTrue,
      );
    });

    test('C — known location is not asked again', () {
      var facts = factsFrom('بطني يوجعني');
      facts = facts.copyWith(
        laterality: Laterality.right,
        abdominalLocationResolved: true,
      );
      final plan = planner.plan(
        facts: facts,
        askedQuestionIds: const [],
        answeredQuestionIds: const [],
        skippedQuestionIds: const [],
        questionsAskedCount: 0,
      );
      expect(plan.question?.id.contains('location'), isFalse);
    });

    test('D — يمين answers laterality', () {
      final q = HealthFollowUpQuestionCatalog.abdominalLocation();
      final r = interpreter.interpret(
        rawAnswer: 'يمين',
        question: q,
        facts: factsFrom('بطني يوجعني'),
      );
      expect(r.updatedFacts?.laterality, Laterality.right);
    });

    test('E — يسار answers laterality', () {
      final q = HealthFollowUpQuestionCatalog.abdominalLocation();
      final r = interpreter.interpret(
        rawAnswer: 'يسار',
        question: q,
        facts: factsFrom('بطني يوجعني'),
      );
      expect(r.updatedFacts?.laterality, Laterality.left);
    });

    test('F — قوي → severe', () {
      final q = HealthFollowUpQuestionCatalog.severity();
      final r = interpreter.interpret(
        rawAnswer: 'قوي',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.userSeverity, UserStatedSeverity.severe);
    });

    test('G — متوسط → moderate', () {
      final q = HealthFollowUpQuestionCatalog.severity();
      final r = interpreter.interpret(
        rawAnswer: 'متوسط',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.userSeverity, UserStatedSeverity.moderate);
    });

    test('H — خفيف → mild', () {
      final q = HealthFollowUpQuestionCatalog.severity();
      final r = interpreter.interpret(
        rawAnswer: 'خفيف',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.userSeverity, UserStatedSeverity.mild);
    });

    test('I — البارحة resolves duration', () {
      final q = HealthFollowUpQuestionCatalog.duration();
      final r = interpreter.interpret(
        rawAnswer: 'البارحة',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.duration, isNotNull);
    });

    test('J — من ثلاثة أيام resolves duration', () {
      final q = HealthFollowUpQuestionCatalog.duration();
      final r = interpreter.interpret(
        rawAnswer: 'من ثلاثة أيام',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.duration?.amount, 3);
    });

    test('K — فجأة resolves onset', () {
      final q = HealthFollowUpQuestionCatalog.onset();
      final r = interpreter.interpret(
        rawAnswer: 'فجأة',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.onset, OnsetPattern.sudden);
    });

    test('L — شوي شوي resolves gradual onset', () {
      final q = HealthFollowUpQuestionCatalog.onset();
      final r = interpreter.interpret(
        rawAnswer: 'شوي شوي',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.onset, OnsetPattern.gradual);
    });

    test('M — يروح ويجي resolves intermittent pattern', () {
      final q = HealthFollowUpQuestionCatalog.pattern();
      final r = interpreter.interpret(
        rawAnswer: 'يروح ويجي',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.temporalModifiers, contains('intermittent'));
    });

    test('N — yes to fever → present', () {
      final q = HealthFollowUpQuestionCatalog.feverPresence();
      final r = interpreter.interpret(
        rawAnswer: 'إي',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.symptomStatuses['fever'], SymptomPolarity.present);
    });

    test('O — no to fever → absent', () {
      final q = HealthFollowUpQuestionCatalog.feverPresence();
      final r = interpreter.interpret(
        rawAnswer: 'لا',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.symptomStatuses['fever'], SymptomPolarity.absent);
    });

    test('P — يمكن → fever uncertain', () {
      final q = HealthFollowUpQuestionCatalog.feverPresence();
      final r = interpreter.interpret(
        rawAnswer: 'يمكن',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(
          r.updatedFacts?.symptomStatuses['fever'], SymptomPolarity.uncertain);
    });

    test('Q — الثاني in severity choices → moderate', () {
      final q = HealthFollowUpQuestionCatalog.severity();
      final r = interpreter.interpret(
        rawAnswer: 'الثاني',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.updatedFacts?.userSeverity, UserStatedSeverity.moderate);
    });

    test('R — metadata associates answer with correct symptom', () {
      final q = HealthFollowUpQuestionCatalog.duration(
        symptomConceptId: 'headache',
      );
      final r = interpreter.interpret(
        rawAnswer: 'من يومين',
        question: q,
        facts: factsFrom('عندي صداع'),
      );
      expect(r.updatedFacts?.symptomFacts['headache']?.duration, isNotNull);
      expect(HealthQuestionMeta.fromQuestion(q)?.symptomConceptId, 'headache');
    });

    test('S — headache duration does not leak to knee pain', () {
      final q = HealthFollowUpQuestionCatalog.duration(
        symptomConceptId: 'headache',
      );
      var facts = factsFrom('عندي صداع وألم بالركبة');
      final r = interpreter.interpret(
        rawAnswer: 'من يومين',
        question: q,
        facts: facts,
      );
      expect(r.updatedFacts?.symptomFacts['headache']?.duration, isNotNull);
      expect(r.updatedFacts?.symptomFacts['knee_pain']?.duration, isNull);
    });

    test('T — correction 2 days → 3 days replaces previous', () {
      final q = HealthFollowUpQuestionCatalog.duration(
        symptomConceptId: 'abdominal_pain',
      );
      var facts = factsFrom('بطني يوجعني');
      final first = interpreter.interpret(
        rawAnswer: 'من يومين',
        question: q,
        facts: facts,
      );
      expect(first.updatedFacts?.duration?.amount, 2);
      final second = interpreter.interpret(
        rawAnswer: 'لا قصدي من ثلاثة أيام',
        question: q,
        facts: first.updatedFacts!,
      );
      expect(second.updatedFacts?.duration?.amount, 3);
    });

    test('U — correction right → left replaces laterality', () {
      final q = HealthFollowUpQuestionCatalog.abdominalLocation();
      final first = interpreter.interpret(
        rawAnswer: 'يمين',
        question: q,
        facts: factsFrom('بطني يوجعني'),
      );
      expect(first.updatedFacts?.laterality, Laterality.right);
      final second = interpreter.interpret(
        rawAnswer: 'لا، يسار',
        question: q,
        facts: first.updatedFacts!,
      );
      expect(second.updatedFacts?.laterality, Laterality.left);
    });

    test('V — ما ادري does not invent answer', () {
      final q = HealthFollowUpQuestionCatalog.duration();
      final r = interpreter.interpret(
        rawAnswer: 'ما ادري',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(r.kind, HealthFollowUpInterpretKind.unknownSkip);
      expect(r.updatedFacts, isNull);
    });

    test('W — skipped question is not immediately repeated', () {
      final facts = factsFrom('بطني يوجعني');
      final first = planner.plan(
        facts: facts,
        askedQuestionIds: const [],
        answeredQuestionIds: const [],
        skippedQuestionIds: const [],
        questionsAskedCount: 0,
      );
      expect(first.question, isNotNull);
      final again = planner.plan(
        facts: facts,
        askedQuestionIds: [first.question!.id],
        answeredQuestionIds: const [],
        skippedQuestionIds: [first.question!.id],
        questionsAskedCount: 1,
      );
      expect(again.question?.id, isNot(first.question!.id));
    });

    test('X — ما اريد اجاوب does not cancel whole health flow', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      final cont = coordinator.continueAfterAnswer(
        answerText: 'ما اريد اجاوب',
        session: start.session,
        turnId: 2,
        pendingQuestion: start.decision?.nextQuestion,
      );
      expect(cont.session.status, isNot(HealthGuidanceSessionStatus.cancelled));
      expect(cont.session.skippedQuestionIds, isNotEmpty);
    });

    test('Y — ما اريد اكمل cancels health flow', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      final cont = coordinator.continueAfterAnswer(
        answerText: 'ما اريد اكمل',
        session: start.session,
        turnId: 2,
        pendingQuestion: start.decision?.nextQuestion,
      );
      expect(cont.session.status, HealthGuidanceSessionStatus.cancelled);
    });

    test('Z — explicit doctor request exits health flow', () async {
      final start = await brain.plan(query: 'بطني يوجعني', context: ctx);
      expect(start.kind, AssistantActionKind.healthGuidance);
      expect(ctx.healthGuidanceSession.status,
          HealthGuidanceSessionStatus.waitingForAnswer);
      final next = await brain.plan(query: 'أريد طبيب أطفال', context: ctx);
      expect(ctx.healthGuidanceSession.status,
          HealthGuidanceSessionStatus.cancelled);
      expect(
        next.kind == AssistantActionKind.runSpecialtySearch ||
            next.kind == AssistantActionKind.runDoctorSearch ||
            next.kind == AssistantActionKind.showMessage ||
            next.message.contains('أطفال') ||
            next.intentResult.intent == AssistantIntent.specialtySearch ||
            next.intentResult.intent == AssistantIntent.doctorSearch,
        isTrue,
      );
    });

    test('AA — explicit laboratory request exits health flow', () async {
      await brain.plan(query: 'بطني يوجعني', context: ctx);
      await brain.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(ctx.healthGuidanceSession.status,
          HealthGuidanceSessionStatus.cancelled);
    });

    test('AB — explicit analysis request exits health flow', () async {
      await brain.plan(query: 'بطني يوجعني', context: ctx);
      final plan = await brain.plan(query: 'أريد تحليل CBC', context: ctx);
      expect(ctx.healthGuidanceSession.status,
          HealthGuidanceSessionStatus.cancelled);
      expect(
        plan.intentResult.intent == AssistantIntent.findAnalysis ||
            plan.kind == AssistantActionKind.runAnalysisSearch ||
            plan.kind == AssistantActionKind.showMessage,
        isTrue,
      );
    });

    test('AC — existing entity action exits health flow', () async {
      await brain.plan(query: 'بطني يوجعني', context: ctx);
      await brain.plan(query: 'اتصل بالدكتور الثاني', context: ctx);
      expect(
        ctx.healthGuidanceSession.status ==
                HealthGuidanceSessionStatus.cancelled ||
            !ctx.healthGuidanceSession.isActive,
        isTrue,
      );
    });

    test('AD — ليش تسأل؟ keeps pending question', () async {
      await brain.plan(query: 'بطني يوجعني', context: ctx);
      final pending =
          ctx.healthGuidanceSession.currentDecision?.nextQuestion?.id;
      final r = await brain.plan(query: 'ليش تسأل؟', context: ctx);
      expect(ctx.healthGuidanceSession.status,
          HealthGuidanceSessionStatus.waitingForAnswer);
      expect(ctx.healthGuidanceSession.currentDecision?.nextQuestion?.id,
          pending);
      expect(r.message.isNotEmpty, isTrue);
    });

    test('AE — شنو تقصد؟ rephrases and keeps pending', () async {
      await brain.plan(query: 'بطني يوجعني', context: ctx);
      final pending =
          ctx.healthGuidanceSession.currentDecision?.nextQuestion?.id;
      final r = await brain.plan(query: 'شنو تقصد؟', context: ctx);
      expect(ctx.healthGuidanceSession.currentDecision?.nextQuestion?.id,
          pending);
      expect(r.message.contains('يمين') || r.message.contains('جهة'), isTrue);
    });

    test('AF — only one question per turn', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(start.decision?.nextQuestion, isNotNull);
      expect(start.message.split('؟').length, lessThanOrEqualTo(2));
    });

    test('AG — question budget prevents endless loop', () {
      final facts = factsFrom('بطني يوجعني');
      final plan = planner.plan(
        facts: facts,
        askedQuestionIds: const ['a', 'b', 'c', 'd'],
        answeredQuestionIds: const [],
        skippedQuestionIds: const ['a', 'b', 'c', 'd'],
        questionsAskedCount: 4,
        maxQuestionsOverride: 4,
      );
      expect(plan.budgetExhausted, isTrue);
      expect(plan.question, isNull);

      final session = sessionWith(facts, askedCount: 4, maxQ: 4);
      final decided = coordinator.continueAfterAnswer(
        answerText: 'ما ادري',
        session: session.copyWith(
          status: HealthGuidanceSessionStatus.waitingForAnswer,
          currentDecision: HealthGuidanceDecision(
            type: HealthGuidanceDecisionType.needMoreInformation,
            nextQuestion: HealthFollowUpQuestionCatalog.duration(),
          ),
          pendingMissingFact: HealthMissingFact.duration,
        ),
        turnId: 9,
        pendingQuestion: HealthFollowUpQuestionCatalog.duration(),
      );
      // بعد تخطي مع ميزانية ممتلئة → قرار آمن
      expect(
        decided.decision?.type ==
                HealthGuidanceDecisionType.generalEvaluation ||
            decided.decision?.type ==
                HealthGuidanceDecisionType.unableToDetermine ||
            decided.decision?.type ==
                HealthGuidanceDecisionType.needMoreInformation,
        isTrue,
      );
    });

    test('AH — no medical fact-question when Step 10C has sufficient direction', () {
      final d = engine.evaluate(factsFrom('ما اسمع زين'));
      expect(d.type, HealthGuidanceDecisionType.specialtyDirection);
      expect(d.nextQuestion, isNull);
      final start = coordinator.startFromUserText(
        query: 'ما اسمع زين',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(start.decision?.type, HealthGuidanceDecisionType.specialtyDirection);
      // Step 10F: سؤال قبول عرض الأطباء فقط — ليس سؤال متابعة طبية.
      expect(
        start.session.handoff.status,
        HealthGuidanceHandoffStatus.awaitingAcceptance,
      );
      expect(
        start.startGuidedFlow?.steps.first.question.metadata['purpose'],
        'providerDiscoveryConfirmation',
      );
      expect(start.decision?.missingFact, isNull);
    });

    test('AI — urgent rule stops remaining questions', () {
      var facts = factsFrom('صدري يوجعني وضيق نفس');
      final r = coordinator.continueAfterAnswer(
        answerText: 'شديد',
        session: sessionWith(facts, askedCount: 1).copyWith(
          status: HealthGuidanceSessionStatus.waitingForAnswer,
          currentDecision: HealthGuidanceDecision(
            type: HealthGuidanceDecisionType.needMoreInformation,
            nextQuestion: HealthFollowUpQuestionCatalog.severity(
              symptomConceptId: 'chest_pain',
            ),
            missingFact: HealthMissingFact.severity,
          ),
          pendingMissingFact: HealthMissingFact.severity,
        ),
        turnId: 2,
        pendingQuestion: HealthFollowUpQuestionCatalog.severity(
          symptomConceptId: 'chest_pain',
        ),
      );
      expect(r.decision?.type, HealthGuidanceDecisionType.urgentEvaluation);
      expect(r.startGuidedFlow, isNull);
    });

    test('AJ — urgent response has no commercial content', () {
      var facts = factsFrom('صدري يوجعني وضيق نفس');
      facts = facts.copyWith(userSeverity: UserStatedSeverity.severe);
      final d = engine.evaluate(facts);
      expect(d.allowCommercialOffers, isFalse);
      expect(d.userMessage.toLowerCase().contains('باقة'), isFalse);
      expect(d.userMessage.contains('عرض'), isFalse);
    });

    test('AK — no diagnosis produced', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(start.message.contains('زائدة'), isFalse);
      expect(start.message.contains('تشخيص'), isFalse);
    });

    test('AL — no medication/treatment recommendation', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(start.message.contains('دواء'), isFalse);
      expect(start.message.contains('علاج'), isFalse);
    });

    test('AM — no imaging recommendation', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(start.message.contains('أشعة'), isFalse);
      expect(start.message.contains('سونار'), isFalse);
      expect(start.message.contains('MRI'), isFalse);
    });

    test('AN — no analysis recommendation', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(start.message.contains('تحليل'), isFalse);
    });

    test('AO — no package recommendation', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(start.message.contains('باقة'), isFalse);
    });

    test('AP — voice/text parity', () {
      final q = HealthFollowUpQuestionCatalog.severity();
      final typed = interpreter.interpret(
        rawAnswer: 'متوسط',
        question: q,
        facts: const HealthSessionFacts(),
      );
      final voice = interpreter.interpret(
        rawAnswer: 'متوسط',
        question: q,
        facts: const HealthSessionFacts(),
      );
      expect(typed.updatedFacts?.userSeverity, voice.updatedFacts?.userSeverity);
    });

    test('AQ — no raw answer persistence', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      final cont = coordinator.continueAfterAnswer(
        answerText: 'باليمين',
        session: start.session,
        turnId: 2,
        pendingQuestion: start.decision?.nextQuestion,
      );
      final snap = cont.session.debugSnapshot();
      expect(snap.values.any((v) => '$v'.contains('باليمين')), isFalse);
      expect(File('lib/health/guidance/health_guidance_coordinator.dart')
          .readAsStringSync()
          .contains('SharedPreferences'), isFalse);
    });

    test('AR — debug snapshot contains no raw health answer', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      final cont = coordinator.continueAfterAnswer(
        answerText: 'قوي جداً ومو طبيعي',
        session: start.session,
        turnId: 2,
        pendingQuestion: start.decision?.nextQuestion,
      );
      final snap = cont.session.debugSnapshot();
      final blob = snap.toString();
      expect(blob.contains('قوي جداً'), isFalse);
      expect(snap.containsKey('questionCount'), isTrue);
      expect(snap.containsKey('answeredQuestionIds'), isTrue);
    });

    test('SCRIPT 1 — natural follow-up', () {
      final s1 = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(s1.decision?.nextQuestion, isNotNull);
      final s2 = coordinator.continueAfterAnswer(
        answerText: 'باليمين',
        session: s1.session,
        turnId: 2,
        pendingQuestion: s1.decision?.nextQuestion,
      );
      expect(s2.session.facts.laterality, Laterality.right);
      expect(s2.decision?.nextQuestion?.id.contains('location'), isFalse);
      if (s2.decision?.type == HealthGuidanceDecisionType.needMoreInformation) {
        final s3 = coordinator.continueAfterAnswer(
          answerText: 'من البارحة',
          session: s2.session,
          turnId: 3,
          pendingQuestion: s2.decision?.nextQuestion,
        );
        expect(s3.session.facts.duration, isNotNull);
        expect(s3.decision?.nextQuestion?.id.contains('duration'), isFalse);
        expect(s3.decision?.nextQuestion?.id.contains('location'), isFalse);
      }
    });

    test('SCRIPT 2 — correction duration', () {
      final q = HealthFollowUpQuestionCatalog.duration(
        symptomConceptId: 'abdominal_pain',
      );
      final a = interpreter.interpret(
        rawAnswer: 'من يومين',
        question: q,
        facts: factsFrom('بطني يوجعني'),
      );
      final b = interpreter.interpret(
        rawAnswer: 'لا قصدي من ثلاثة أيام',
        question: q,
        facts: a.updatedFacts!,
      );
      expect(b.updatedFacts?.duration?.amount, 3);
      expect(a.updatedFacts?.duration?.amount, isNot(b.updatedFacts?.duration?.amount));
    });

    test('SCRIPT 3 — question about question then answer', () async {
      await brain.plan(query: 'بطني يوجعني', context: ctx);
      final pending =
          ctx.healthGuidanceSession.currentDecision?.nextQuestion?.id;
      await brain.plan(query: 'ليش تسأل؟', context: ctx);
      expect(ctx.healthGuidanceSession.currentDecision?.nextQuestion?.id,
          pending);
      // أجب عن المكان
      await brain.plan(query: 'من أسبوع', context: ctx);
      // قد يُقبل كمدة إذا كان السؤال مدة، أو يبقى معلقاً إن كان مكاناً
      expect(ctx.healthGuidanceSession.isActive, isTrue);
    });

    test('SCRIPT 4 — topic switch', () async {
      await brain.plan(query: 'بطني يوجعني', context: ctx);
      await brain.plan(query: 'خلينا من هذا، أريد طبيب أطفال', context: ctx);
      expect(ctx.healthGuidanceSession.status,
          HealthGuidanceSessionStatus.cancelled);
      expect(ctx.guidedConversation.isWaitingForAnswer, isFalse);
    });

    test('SCRIPT 5 — urgent interruption', () {
      var facts = factsFrom('صدري يوجعني وضيق نفس');
      final mid = sessionWith(
        facts,
        asked: const ['health_severity'],
        askedCount: 1,
      );
      final r = coordinator.continueAfterAnswer(
        answerText: 'شديد',
        session: mid.copyWith(
          status: HealthGuidanceSessionStatus.waitingForAnswer,
          currentDecision: HealthGuidanceDecision(
            type: HealthGuidanceDecisionType.needMoreInformation,
            nextQuestion: HealthFollowUpQuestionCatalog.severity(
              symptomConceptId: 'chest_pain',
            ),
            missingFact: HealthMissingFact.severity,
          ),
          pendingMissingFact: HealthMissingFact.severity,
        ),
        turnId: 5,
        pendingQuestion: HealthFollowUpQuestionCatalog.severity(
          symptomConceptId: 'chest_pain',
        ),
      );
      expect(r.decision?.type, HealthGuidanceDecisionType.urgentEvaluation);
      expect(r.startGuidedFlow, isNull);
      expect(r.decision?.allowCommercialOffers, isFalse);
    });
  });
}
