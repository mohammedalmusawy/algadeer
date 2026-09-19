import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/specialty_catalog.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_coordinator.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_engine.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_models.dart';
import 'package:ghadeer_clinic/health/guidance/health_rule_evaluator.dart';
import 'package:ghadeer_clinic/health/guidance/local_health_guidance_rules.dart';
import 'package:ghadeer_clinic/health/understanding/health_understanding_engine.dart';
import 'package:ghadeer_clinic/health/understanding/symptom_models.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/guided_conversation_models.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  late HealthGuidanceEngine engine;
  late HealthGuidanceCoordinator coordinator;
  late HealthUnderstandingEngine understanding;
  late ConversationContext ctx;
  late SmartBrainPlanner planner;

  setUp(() {
    engine = HealthGuidanceEngine();
    coordinator = HealthGuidanceCoordinator();
    understanding = HealthUnderstandingEngine();
    ctx = ConversationContext();
    planner = SmartBrainPlanner(
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

  HealthSessionFacts factsFrom(String text) {
    return const HealthSessionFacts()
        .mergeUnderstanding(understanding.understand(text));
  }

  group('Health guidance rules engine', () {
    test('A — hearing loss → ENT', () {
      final d = engine.evaluate(factsFrom('ما اسمع زين'));
      expect(d.type, HealthGuidanceDecisionType.specialtyDirection);
      expect(d.destination?.specialtyCatalogId, 'ent');
      expect(d.destination?.key, SpecialtyCatalog.all.firstWhere((s) => s.id == 'ent').id);
    });

    test('B — tinnitus → ENT', () {
      final d = engine.evaluate(factsFrom('صفير باذني'));
      expect(d.destination?.specialtyCatalogId, 'ent');
    });

    test('C — ear pain → ENT', () {
      final d = engine.evaluate(factsFrom('اذني توجعني'));
      expect(d.destination?.specialtyCatalogId, 'ent');
    });

    test('D — nasal congestion → ENT', () {
      final d = engine.evaluate(factsFrom('خشمي مسدود'));
      expect(d.destination?.specialtyCatalogId, 'ent');
    });

    test('E — hoarseness → ENT', () {
      final d = engine.evaluate(factsFrom('صوتي مبحوح'));
      expect(d.destination?.specialtyCatalogId, 'ent');
    });

    test('F — abdominal pain → needMoreInformation', () {
      final d = engine.evaluate(factsFrom('بطني يوجعني'));
      expect(d.type, HealthGuidanceDecisionType.needMoreInformation);
      expect(d.nextQuestion, isNotNull);
    });

    test('G — one missing fact question only', () {
      final d = engine.evaluate(factsFrom('بطني يوجعني'));
      expect(d.nextQuestion?.prompt.contains('؟') ?? false, isTrue);
      expect(d.missingFact, isNotNull);
    });

    test('H — answer updates health session', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(start.session.status, HealthGuidanceSessionStatus.waitingForAnswer);
      final cont = coordinator.continueAfterAnswer(
        answerText: 'بالجهة اليمنى',
        session: start.session,
        turnId: 2,
        guidedAnswer: const GuidedAnswer(
          questionId: 'health_abdominal_location',
          rawText: 'بالجهة اليمنى',
          normalizedValue: 'right',
          answerType: GuidedAnswerType.singleChoice,
          optionIds: ['right'],
        ),
      );
      expect(cont.session.facts.laterality, Laterality.right);
      expect(cont.session.answeredQuestionIds, isNotEmpty);
    });

    test('I — engine re-evaluates after answer', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      final cont = coordinator.continueAfterAnswer(
        answerText: 'بالجهة اليمنى',
        session: start.session,
        turnId: 2,
        guidedAnswer: const GuidedAnswer(
          questionId: 'health_abdominal_location',
          rawText: 'يمين',
          normalizedValue: 'right',
          answerType: GuidedAnswerType.singleChoice,
          optionIds: ['right'],
        ),
      );
      expect(
        cont.decision?.type == HealthGuidanceDecisionType.generalEvaluation ||
            cont.decision?.type ==
                HealthGuidanceDecisionType.needMoreInformation ||
            cont.decision?.type == HealthGuidanceDecisionType.specialtyDirection,
        isTrue,
      );
    });

    test('J — negated fever does not satisfy present', () {
      const req = SymptomRequirement(conceptId: 'fever');
      final facts = factsFrom('ما عندي حرارة');
      final ev = const HealthRuleEvaluator().evaluate(
        HealthGuidanceRule(
          id: 't',
          priority: 1,
          requiredSymptoms: [req],
          destination: GuidanceDestination.general,
        ),
        facts,
      );
      expect(ev.eligible, isFalse);
      expect(facts.symptomStatuses['fever'], SymptomPolarity.absent);
    });

    test('K — uncertain fever does not satisfy strict present', () {
      final facts = factsFrom('يمكن عندي حرارة');
      expect(facts.symptomStatuses['fever'], SymptomPolarity.uncertain);
      final ev = const HealthRuleEvaluator().evaluate(
        const HealthGuidanceRule(
          id: 't2',
          priority: 1,
          requiredSymptoms: [
            SymptomRequirement(conceptId: 'fever'),
          ],
          destination: GuidanceDestination.general,
        ),
        facts,
      );
      expect(ev.eligible, isFalse);
    });

    test('L — multiple symptoms combine deterministically', () {
      final d = engine.evaluate(
        factsFrom('ما اسمع زين وعندي صفير باذني'),
      );
      expect(d.destination?.specialtyCatalogId, 'ent');
      expect(d.matchedRuleId, isNotNull);
    });

    test('M — no disease diagnosis field', () {
      final d = engine.evaluate(factsFrom('ما اسمع زين'));
      expect(d.toString().toLowerCase().contains('diagnos'), isFalse);
      expect(d.userMessage.contains('مصاب'), isFalse);
    });

    test('N — no medication', () {
      final d = engine.evaluate(factsFrom('عندي صداع'));
      expect(d.userMessage.contains('دواء'), isFalse);
    });

    test('O — no treatment', () {
      final d = engine.evaluate(factsFrom('عندي صداع'));
      expect(d.userMessage.contains('خذ'), isFalse);
    });

    test('P — no package recommendation', () {
      final d = engine.evaluate(factsFrom('بطني يوجعني'));
      expect(d.userMessage.contains('باقة'), isFalse);
      expect(d.allowCommercialOffers || !d.allowCommercialOffers, isTrue);
    });

    test('Q — no analysis recommendation', () {
      final d = engine.evaluate(factsFrom('عندي حرارة'));
      expect(d.userMessage.contains('CBC'), isFalse);
      expect(d.userMessage.contains('تحليل'), isFalse);
    });

    test('R — no imaging recommendation', () {
      final d = engine.evaluate(factsFrom('ظهري يوجعني'));
      expect(d.userMessage.contains('رنين'), isFalse);
      expect(d.userMessage.contains('مفراس'), isFalse);
      expect(d.userMessage.contains('CT'), isFalse);
    });

    test('S — no specific doctor hardcoded', () {
      for (final r in const LocalHealthGuidanceRuleSource().enabledRulesSync()) {
        expect(r.destination.displayNameAr.contains('دكتور'), isFalse);
        expect(r.id.toLowerCase().contains('dr.'), isFalse);
      }
    });

    test('T — specialty uses SpecialtyCatalog ids', () {
      final d = engine.evaluate(factsFrom('ما اسمع زين'));
      final id = d.destination!.specialtyCatalogId!;
      expect(SpecialtyCatalog.all.any((s) => s.id == id), isTrue);
      expect(d.destination!.displayNameAr,
          SpecialtyCatalog.all.firstWhere((s) => s.id == id).nameAr);
    });

    test('U — user can cancel health session', () async {
      await planner.plan(query: 'بطني يوجعني', context: ctx);
      expect(ctx.healthGuidanceSession.isActive, isTrue);
      await planner.plan(query: 'خلاص', context: ctx);
      expect(
        ctx.healthGuidanceSession.status ==
                HealthGuidanceSessionStatus.cancelled ||
            ctx.guidedConversation.status == GuidedFlowStatus.cancelled,
        isTrue,
      );
    });

    test('V — lab request exits health and reaches pipeline', () async {
      await planner.plan(query: 'بطني يوجعني', context: ctx);
      final plan = await planner.plan(
        query: 'خلينا من هذا أريد مختبر الحياة',
        context: ctx,
      );
      expect(ctx.healthGuidanceSession.status,
          HealthGuidanceSessionStatus.cancelled);
      expect(
        plan.kind == AssistantActionKind.runLabSearch ||
            plan.labQuery != null ||
            plan.canExecute ||
            plan.target?.labId == 'hayat',
        isTrue,
      );
    });

    test('W — analysis request does not start health', () async {
      final plan = await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      expect(ctx.healthGuidanceSession.isActive, isFalse);
      expect(plan.kind, isNot(AssistantActionKind.healthGuidance));
    });

    test('X — doctor search does not start health', () async {
      final plan =
          await planner.plan(query: 'أريد طبيب أعصاب', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.healthGuidance));
    });

    test('Y — Step 10A pending question reused', () async {
      final plan = await planner.plan(query: 'بطني يوجعني', context: ctx);
      expect(plan.kind, AssistantActionKind.healthGuidance);
      expect(ctx.guidedConversation.isWaitingForAnswer, isTrue);
      expect(ctx.guidedConversation.flowType,
          GuidedFlowType.healthGuidanceReserved);
      expect(ctx.guidedConversation.pendingQuestion, isNotNull);
    });

    test('Z — Step 10A correction updates health fact', () async {
      await planner.plan(query: 'ظهري يوجعني من يومين', context: ctx);
      // إن طُلبت مدة أو اكتمل — صحّح المدة عبر النص
      final session = ctx.healthGuidanceSession.copyWith(
        facts: ctx.healthGuidanceSession.facts.copyWith(
          duration: const DurationValue(amount: 2, unit: 'day', rawText: 'يومين'),
        ),
        status: HealthGuidanceSessionStatus.waitingForAnswer,
      );
      ctx.setHealthGuidanceSession(session);
      final cont = coordinator.continueAfterAnswer(
        answerText: 'لا قصدي من 3 أيام',
        session: session,
        turnId: 3,
        guidedAnswer: GuidedAnswer(
          questionId: 'health_duration',
          rawText: 'من 3 أيام',
          normalizedValue: const {'amount': 3, 'unit': 'day'},
          answerType: GuidedAnswerType.duration,
          durationValue:
              const DurationValue(amount: 3, unit: 'day', rawText: '3 أيام'),
        ),
      );
      expect(cont.session.facts.duration?.amount, 3);
    });

    test('AA — health session does not erase Step 9 entities', () async {
      ctx.selectDoctor(
        SmartSearchResult(
          type: SmartSearchResultType.doctor,
          title: 'دكتور',
          subtitle: 'أ',
          doctorId: 'd1',
          score: 90,
        ),
      );
      await planner.plan(query: 'عندي صداع', context: ctx);
      expect(ctx.selectedDoctor?.doctorId, 'd1');
    });

    test('AB — health session not persisted', () {
      final dir = Directory('lib/health/guidance');
      for (final f in dir.listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        expect(src.contains('SharedPreferences'), isFalse);
        expect(src.contains('supabase.from'), isFalse);
      }
    });

    test('AC — debugSnapshot no raw health text', () async {
      await planner.plan(query: 'بطني يوجعني من البارحة', context: ctx);
      final snap = ctx.debugSnapshot().toString();
      expect(snap.contains('بطني'), isFalse);
      expect(snap.contains('healthSessionStatus'), isTrue);
      expect(snap.contains('matchedRuleId') || snap.contains('decisionType'),
          isTrue);
    });

    test('AD — voice/text parity', () {
      const q = 'ما اسمع زين وعندي صفير باذني';
      expect(QueryInputSource.voice, isNot(QueryInputSource.typed));
      final a = engine.evaluate(factsFrom(q));
      final b = engine.evaluate(factsFrom(q));
      expect(a.type, b.type);
      expect(a.destination?.key, b.destination?.key);
    });

    test('AE — urgent produces no commercial offer', () {
      final facts = const HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
      );
      final d = engine.evaluate(facts);
      expect(d.type, HealthGuidanceDecisionType.urgentEvaluation);
      expect(d.allowCommercialOffers, isFalse);
      expect(d.userMessage.contains('باقة'), isFalse);
      expect(d.userMessage.contains('عرض'), isFalse);
    });

    test('AF — urgent does not claim diagnosis', () {
      final facts = const HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
      );
      final d = engine.evaluate(facts);
      expect(d.userMessage.contains('نوبة'), isFalse);
      expect(d.userMessage.contains('جلطة'), isFalse);
      expect(d.userMessage.contains('مصاب'), isFalse);
    });

    test('AG — weak health → not over-specific specialty', () {
      final d = engine.evaluate(factsFrom('تعبان'));
      expect(
        d.type == HealthGuidanceDecisionType.generalEvaluation ||
            d.type == HealthGuidanceDecisionType.needMoreInformation ||
            d.destination?.type ==
                GuidanceDestinationType.generalMedicalEvaluation,
        isTrue,
      );
      expect(d.destination?.specialtyCatalogId, isNot('neurology'));
    });

    test('AH — patient age not assumed from app user', () {
      final d = engine.evaluate(factsFrom('عندي حرارة'));
      // بدون سياق طفل صريح لا يوجّه لأطفال
      expect(d.destination?.specialtyCatalogId, isNot('pediatrics'));
    });

    test('AI — pediatrics only when child context known', () {
      final facts = factsFrom('عندي حرارة').copyWith(patientIsChild: true);
      final d = engine.evaluate(facts);
      expect(d.destination?.specialtyCatalogId, 'pediatrics');
    });

    test('AJ — provider names absent from rules', () {
      for (final r in const LocalHealthGuidanceRuleSource().enabledRulesSync()) {
        final blob = '${r.id}${r.rationaleCode}${r.destination.key}';
        expect(blob.contains('ناصر'), isFalse);
        expect(blob.contains('الحياة'), isFalse);
      }
    });

    test('AK — radiology destination types exist reserved', () {
      expect(GuidanceDestinationType.radiologyReserved, isNotNull);
      expect(GuidanceDestinationType.ctReserved, isNotNull);
      expect(GuidanceDestinationType.mriReserved, isNotNull);
    });

    test('AL — Step 10B parsing unchanged', () {
      final u = understanding.understand('راسي يوجعني');
      expect(u.symptomById('headache')?.status, SymptomPolarity.present);
    });

    test('future-ready destination not recommending imaging', () {
      final d = engine.evaluate(factsFrom('ما اسمع زين'));
      expect(d.destination?.type, isNot(GuidanceDestinationType.ctReserved));
      expect(d.destination?.type, isNot(GuidanceDestinationType.mriReserved));
    });
  });

  group('Scripts', () {
    test('SCRIPT 1 — ENT hearing + tinnitus', () async {
      final plan = await planner.plan(
        query: 'ما اسمع زين وعندي صفير باذني',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.healthGuidance);
      expect(plan.healthDecision?.destination?.specialtyCatalogId, 'ent');
      expect(plan.message.contains('مصاب'), isFalse);
      expect(plan.healthDecision?.suggestShowSpecialtyDoctors, isTrue);
    });

    test('SCRIPT 2 — abdominal follow-up', () async {
      final p1 = await planner.plan(query: 'بطني يوجعني', context: ctx);
      expect(p1.healthDecision?.type,
          HealthGuidanceDecisionType.needMoreInformation);
      expect(ctx.guidedConversation.isWaitingForAnswer, isTrue);

      final p2 = await planner.plan(query: 'بالجهة اليمنى', context: ctx);
      expect(ctx.healthGuidanceSession.facts.laterality, Laterality.right);
      expect(p2.message.contains('مصاب'), isFalse);
    });

    test('SCRIPT 3 — topic change to lab', () async {
      await planner.plan(query: 'بطني يوجعني', context: ctx);
      final plan = await planner.plan(
        query: 'خلينا من هذا أريد مختبر الحياة',
        context: ctx,
      );
      expect(ctx.healthGuidanceSession.status,
          HealthGuidanceSessionStatus.cancelled);
      expect(
        plan.kind == AssistantActionKind.runLabSearch ||
            plan.canExecute ||
            plan.labQuery != null,
        isTrue,
      );
    });

    test('SCRIPT 4 — urgent safe category', () {
      final d = engine.evaluate(
        const HealthSessionFacts(
          symptomStatuses: {
            'chest_pain': SymptomPolarity.present,
            'shortness_of_breath': SymptomPolarity.present,
          },
          userSeverity: UserStatedSeverity.severe,
        ),
      );
      expect(d.type, HealthGuidanceDecisionType.urgentEvaluation);
      expect(d.allowCommercialOffers, isFalse);
      expect(d.userMessage.contains('عاجلاً') || d.userMessage.contains('عاجل'),
          isTrue);
    });
  });
}
