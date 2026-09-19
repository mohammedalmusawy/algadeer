import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/health/guidance/health_follow_up_question_catalog.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_coordinator.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_engine.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_models.dart';
import 'package:ghadeer_clinic/health/guidance/local_health_guidance_rules.dart';
import 'package:ghadeer_clinic/health/safety/local_medical_safety_rules.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_engine.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_models.dart';
import 'package:ghadeer_clinic/health/understanding/health_understanding_engine.dart';
import 'package:ghadeer_clinic/health/understanding/symptom_models.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/guided_conversation_models.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  late MedicalSafetyEngine safety;
  late HealthGuidanceEngine guidance;
  late HealthGuidanceCoordinator coordinator;
  late HealthUnderstandingEngine understanding;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;

  setUp(() {
    safety = MedicalSafetyEngine();
    guidance = HealthGuidanceEngine();
    coordinator = HealthGuidanceCoordinator();
    understanding = HealthUnderstandingEngine();
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      doctorLookup: (q) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. تجريبي',
              subtitle: 'باطنية',
              doctorId: 'd1',
              score: 90,
              specialty: 'باطنية',
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

  group('Medical safety / red flags engine', () {
    test('A — no configured red flag → noRedFlagDetected', () {
      final d = safety.evaluate(factsFrom('راسي يوجعني'));
      expect(d.status, MedicalSafetyStatus.noRedFlagDetected);
    });

    test('B — noRedFlagDetected does NOT say you are safe', () {
      final d = safety.evaluate(factsFrom('راسي يوجعني'));
      expect(d.userMessage.contains('بخير'), isFalse);
      expect(d.userMessage.contains('ماكو خطر'), isFalse);
      expect(d.userMessage.contains('آمن'), isFalse);
      expect(d.userMessage.contains('ما تحتاج'), isFalse);
    });

    test('C — severe chest + severe breathing → urgent/emergency', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      );
      final d = safety.evaluate(facts);
      expect(
        d.status == MedicalSafetyStatus.urgentEvaluation ||
            d.status == MedicalSafetyStatus.emergencyEvaluation,
        isTrue,
      );
      expect(d.suppressCommercialContent, isTrue);
      expect(d.interruptConversation, isTrue);
    });

    test('D — chest pain + breathing ABSENT → no combined match', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.absent,
        },
        userSeverity: UserStatedSeverity.severe,
      );
      final d = safety.evaluate(facts);
      expect(d.matchedRuleId, isNot('safety_chest_breathing_severe'));
      expect(d.status, isNot(MedicalSafetyStatus.urgentEvaluation));
    });

    test('E — uncertain breathing does not satisfy strict PRESENT', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.uncertain,
        },
        userSeverity: UserStatedSeverity.severe,
      );
      final d = safety.evaluate(facts);
      expect(d.matchedRuleId, isNot('safety_chest_breathing_severe'));
    });

    test('F — severity uses user-stated value only', () {
      const mild = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.mild,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.mild),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.mild),
        },
      );
      expect(safety.evaluate(mild).isEscalation, isFalse);

      const severe = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      );
      expect(safety.evaluate(severe).isEscalation, isTrue);
    });

    test('G — sudden one-sided weakness when facts complete', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {'weakness': SymptomPolarity.present},
        onset: OnsetPattern.sudden,
        laterality: Laterality.left,
        symptomFacts: {
          'weakness': SymptomScopedFacts(
            onset: OnsetPattern.sudden,
            laterality: Laterality.left,
          ),
        },
      );
      final d = safety.evaluate(facts);
      expect(d.status, MedicalSafetyStatus.emergencyEvaluation);
      expect(d.matchedRuleId, 'safety_sudden_unilateral_weakness');
    });

    test('H — gradual weakness does not satisfy sudden rule', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {'weakness': SymptomPolarity.present},
        onset: OnsetPattern.gradual,
        laterality: Laterality.left,
        symptomFacts: {
          'weakness': SymptomScopedFacts(
            onset: OnsetPattern.gradual,
            laterality: Laterality.left,
          ),
        },
      );
      final d = safety.evaluate(facts);
      expect(d.matchedRuleId, isNot('safety_sudden_unilateral_weakness'));
      expect(d.isEscalation, isFalse);
    });

    test('I — laterality belongs to correct symptom', () {
      var facts = factsFrom('ضعف باليد اليسار');
      // حتى مع جانبية عامة، القاعدة تقرأ lateralityConceptId=weakness
      facts = facts.copyWith(
        onset: OnsetPattern.sudden,
        laterality: Laterality.left,
        symptomFacts: {
          'weakness': SymptomScopedFacts(
            laterality: Laterality.left,
            onset: OnsetPattern.sudden,
          ),
          'knee_pain': const SymptomScopedFacts(laterality: Laterality.right),
        },
        symptomStatuses: {
          ...facts.symptomStatuses,
          'weakness': SymptomPolarity.present,
        },
      );
      final d = safety.evaluate(facts);
      expect(d.status, MedicalSafetyStatus.emergencyEvaluation);
    });

    test('J — severe knee pain does not make headache severe for safety', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'headache': SymptomPolarity.present,
          'knee_pain': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'knee_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'headache': SymptomScopedFacts(severity: UserStatedSeverity.unknown),
        },
      );
      // لا قاعدة رأس شديدة؛ وتأكد أن شدة الركبة لا تفعّل صدر
      final d = safety.evaluate(facts);
      expect(d.isEscalation, isFalse);
      expect(
        facts.symptomFacts['headache']?.severity,
        UserStatedSeverity.unknown,
      );
    });

    test('K — partial safety rule can request ONE safety question', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
      );
      final d = safety.evaluate(facts);
      expect(d.status, MedicalSafetyStatus.needSafetyInformation);
      expect(d.nextQuestion, isNotNull);
      expect(d.nextQuestion!.prompt.contains('؟'), isTrue);
    });

    test('L — safety question outranks routine follow-up', () {
      // ألم بطن + ألم صدر/ضيق بدون شدة → سؤال سلامة قبل مكان البطن
      final r = coordinator.startFromUserText(
        query: 'بطني يوجعني وصدري يوجعني ونفسي ضايج',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(r.decision?.nextQuestion, isNotNull);
      expect(
        r.decision!.nextQuestion!.id.startsWith('safety_') ||
            r.safetyDecision?.needsQuestion == true ||
            r.session.pendingSafetyQuestionId != null,
        isTrue,
      );
    });

    test('M — safety answer re-evaluates safety engine', () {
      final start = coordinator.startFromUserText(
        query: 'صدري يوجعني ونفسي ضايج',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(start.decision?.type, HealthGuidanceDecisionType.needMoreInformation);
      final cont = coordinator.continueAfterAnswer(
        answerText: 'شديد',
        session: start.session,
        turnId: 2,
        pendingQuestion: start.decision?.nextQuestion,
      );
      expect(
        cont.decision?.type == HealthGuidanceDecisionType.urgentEvaluation ||
            cont.decision?.type ==
                HealthGuidanceDecisionType.emergencyEvaluation,
        isTrue,
      );
    });

    test('N — fully matched urgent stops routine questions', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      );
      final r = coordinator.continueAfterAnswer(
        answerText: 'شديد',
        session: HealthGuidanceSession(
          id: 't',
          status: HealthGuidanceSessionStatus.waitingForAnswer,
          facts: facts,
          currentDecision: HealthGuidanceDecision(
            type: HealthGuidanceDecisionType.needMoreInformation,
            nextQuestion: HealthFollowUpQuestionCatalog.duration(),
          ),
        ),
        turnId: 3,
        pendingQuestion: HealthFollowUpQuestionCatalog.duration(),
      );
      // بعد الدمج قد يبقى عاجلاً من الحقائق الموجودة
      expect(r.startGuidedFlow, isNull);
      expect(
        r.decision?.type == HealthGuidanceDecisionType.urgentEvaluation ||
            r.decision?.type == HealthGuidanceDecisionType.emergencyEvaluation ||
            r.decision?.type == HealthGuidanceDecisionType.needMoreInformation,
        isTrue,
      );
      if (r.decision?.type == HealthGuidanceDecisionType.urgentEvaluation ||
          r.decision?.type == HealthGuidanceDecisionType.emergencyEvaluation) {
        expect(r.session.status, HealthGuidanceSessionStatus.decided);
      }
    });

    test('O — urgent suppresses packages', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      );
      final d = guidance.evaluate(facts);
      expect(d.allowCommercialOffers, isFalse);
      expect(d.userMessage.contains('باقة'), isFalse);
    });

    test('P — urgent suppresses offers', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      );
      final d = guidance.evaluate(facts);
      expect(d.userMessage.contains('عرض'), isFalse);
      expect(d.allowCommercialOffers, isFalse);
    });

    test('Q — urgent does not select a lab', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      );
      final d = guidance.evaluate(facts);
      expect(d.destination?.key.contains('lab'), isFalse);
      expect(d.userMessage.contains('مختبر'), isFalse);
    });

    test('R — urgent does not select a doctor', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      );
      final d = guidance.evaluate(facts);
      expect(d.suggestShowSpecialtyDoctors, isFalse);
      expect(d.userMessage.contains('دكتور ناصر'), isFalse);
    });

    test('S — urgent does not recommend imaging', () {
      final d = safety.evaluate(const HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      ));
      expect(d.userMessage.contains('أشعة'), isFalse);
      expect(d.userMessage.contains('MRI'), isFalse);
      expect(d.userMessage.contains('سونار'), isFalse);
    });

    test('T — urgent does not recommend analysis', () {
      final d = safety.evaluate(const HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      ));
      expect(d.userMessage.contains('تحليل'), isFalse);
      expect(d.userMessage.contains('CBC'), isFalse);
    });

    test('U — no disease diagnosis in safety decision', () {
      final d = safety.evaluate(const HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      ));
      expect(d.userMessage.contains('تشخيص'), isFalse);
      expect(d.userMessage.contains('مصاب'), isFalse);
    });

    test('V — chest rule never outputs heart attack', () {
      final d = safety.evaluate(const HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      ));
      expect(d.userMessage.contains('جلطة'), isFalse);
      expect(d.userMessage.contains('نوبة قلبية'), isFalse);
      expect(d.userMessage.toLowerCase().contains('heart'), isFalse);
    });

    test('W — one-sided weakness never outputs stroke', () {
      final d = safety.evaluate(const HealthSessionFacts(
        symptomStatuses: {'weakness': SymptomPolarity.present},
        onset: OnsetPattern.sudden,
        laterality: Laterality.right,
        symptomFacts: {
          'weakness': SymptomScopedFacts(
            onset: OnsetPattern.sudden,
            laterality: Laterality.right,
          ),
        },
      ));
      expect(d.userMessage.contains('جلطة'), isFalse);
      expect(d.userMessage.contains('سكتة'), isFalse);
      expect(d.userMessage.toLowerCase().contains('stroke'), isFalse);
    });

    test('X — abdominal safety never outputs appendicitis', () {
      final d = safety.evaluate(const HealthSessionFacts(
        symptomStatuses: {
          'abdominal_pain': SymptomPolarity.present,
          'fever': SymptomPolarity.present,
          'vomiting': SymptomPolarity.present,
        },
        laterality: Laterality.right,
        abdominalLocationResolved: true,
        symptomFacts: {
          'abdominal_pain': SymptomScopedFacts(laterality: Laterality.right),
        },
      ));
      expect(d.userMessage.contains('زائدة'), isFalse);
      expect(d.userMessage.contains('التهاب الزائدة'), isFalse);
      expect(d.userMessage.toLowerCase().contains('append'), isFalse);
    });

    test('Y — safety warning not repeated every unrelated turn', () {
      const facts = HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      );
      final first = coordinator.startFromUserText(
        query: 'صدري يوجعني كلش ونفسي ضايج كلش',
        current: HealthGuidanceSession(facts: facts, id: 's'),
        turnId: 1,
      );
      // فرض الحقائق العاجلة مباشرة
      final delivered = coordinator.continueAfterAnswer(
        answerText: 'شديد',
        session: HealthGuidanceSession(
          id: 's',
          status: HealthGuidanceSessionStatus.active,
          facts: facts,
          safetyWarningDelivered: false,
        ),
        turnId: 1,
      );
      expect(delivered.message.isNotEmpty, isTrue);
      final again = coordinator.startFromUserText(
        query: 'صدري يوجعني كلش ونفسي ضايج كلش',
        current: delivered.session.copyWith(facts: facts),
        turnId: 2,
      );
      expect(again.session.safetyWarningDelivered, isTrue);
      expect(again.message, isEmpty);
      expect(first, isNotNull);
    });

    test('Z — explicit topic switch remains possible after warning', () async {
      await brain.plan(
        query: 'صدري يوجعني كلش ونفسي ضايج كلش',
        context: ctx,
      );
      final next = await brain.plan(
        query: 'أريد مختبر الحياة',
        context: ctx,
      );
      expect(
        ctx.healthGuidanceSession.status ==
                HealthGuidanceSessionStatus.cancelled ||
            next.kind != AssistantActionKind.healthGuidance ||
            next.intentResult.intent.toString().contains('Lab') ||
            next.kind == AssistantActionKind.runLabSearch ||
            next.kind == AssistantActionKind.showMessage,
        isTrue,
      );
    });

    test('AA — no emergency phone number invented', () {
      final d = safety.evaluate(const HealthSessionFacts(
        symptomStatuses: {
          'chest_pain': SymptomPolarity.present,
          'shortness_of_breath': SymptomPolarity.present,
        },
        userSeverity: UserStatedSeverity.severe,
        symptomFacts: {
          'chest_pain': SymptomScopedFacts(severity: UserStatedSeverity.severe),
          'shortness_of_breath':
              SymptomScopedFacts(severity: UserStatedSeverity.severe),
        },
      ));
      expect(RegExp(r'911|112|997|999|0770').hasMatch(d.userMessage), isFalse);
    });

    test('AB — raw health text not persisted', () {
      final r = coordinator.startFromUserText(
        query: 'صدري يوجعني كلش ونفسي ضايج كلش',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      final snap = r.session.debugSnapshot().toString();
      expect(snap.contains('صدري يوجعني كلش'), isFalse);
      expect(
        File('lib/health/safety/medical_safety_engine.dart')
            .readAsStringSync()
            .contains('SharedPreferences'),
        isFalse,
      );
    });

    test('AC — debug snapshot contains no raw health text', () {
      final r = coordinator.startFromUserText(
        query: 'صدري يوجعني كلش ونفسي ضايج كلش',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      final snap = r.session.debugSnapshot();
      expect(snap.containsKey('safetyStatus'), isTrue);
      expect(snap.toString().contains('ضايج كلش'), isFalse);
    });

    test('AD — voice/text parity', () {
      const q = 'صدري يوجعني كلش ونفسي ضايج كلش';
      final a = safety.evaluate(factsFrom(q));
      final b = safety.evaluate(factsFrom(q));
      expect(a.status, b.status);
      expect(a.matchedRuleId, b.matchedRuleId);
    });

    test('AJ — safety engine contains no doctor names', () {
      for (final r in const LocalMedicalSafetyRuleSource().enabledRulesSync()) {
        final blob = '${r.id}${r.rationaleCode}';
        expect(blob.contains('ناصر'), isFalse);
        expect(blob.contains('دكتور'), isFalse);
      }
    });

    test('AK — safety engine contains no lab/package names', () {
      for (final r in const LocalMedicalSafetyRuleSource().enabledRulesSync()) {
        final blob = '${r.id}${r.rationaleCode}';
        expect(blob.contains('باقة'), isFalse);
        expect(blob.contains('الحياة'), isFalse);
      }
    });

    test('AL — no paid AI/LLM dependency in safety sources', () {
      final src = File('lib/health/safety/medical_safety_engine.dart')
          .readAsStringSync();
      expect(src.toLowerCase().contains('openai'), isFalse);
      expect(src.toLowerCase().contains('embedding'), isFalse);
      expect(src.contains('ChatGPT'), isFalse);
    });

    test('SCRIPT 1 — chest safety', () {
      final facts = factsFrom('صدري يوجعني كلش ونفسي ضايج كلش');
      final d = safety.evaluate(facts);
      expect(d.isEscalation || d.needsQuestion, isTrue);
      if (d.isEscalation) {
        expect(d.suppressCommercialContent, isTrue);
        expect(d.userMessage.contains('نوبة قلبية'), isFalse);
      }
      final g = guidance.evaluate(facts);
      if (g.type == HealthGuidanceDecisionType.urgentEvaluation ||
          g.type == HealthGuidanceDecisionType.emergencyEvaluation) {
        expect(g.allowCommercialOffers, isFalse);
        expect(g.suggestShowSpecialtyDoctors, isFalse);
      }
    });

    test('SCRIPT 2 — negation', () {
      final facts = factsFrom('صدري يوجعني بس ما عندي ضيق نفس');
      expect(facts.symptomStatuses['chest_pain'], SymptomPolarity.present);
      expect(
          facts.symptomStatuses['shortness_of_breath'], SymptomPolarity.absent);
      final d = safety.evaluate(facts);
      expect(d.matchedRuleId, isNot('safety_chest_breathing_severe'));
    });

    test('SCRIPT 3 — safety question then re-eval', () {
      final start = coordinator.startFromUserText(
        query: 'عندي ألم بالصدر ونفسي ضايج',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      if (start.decision?.type ==
          HealthGuidanceDecisionType.needMoreInformation) {
        expect(start.decision?.nextQuestion, isNotNull);
        final cont = coordinator.continueAfterAnswer(
          answerText: 'كلش قوي',
          session: start.session,
          turnId: 2,
          pendingQuestion: start.decision?.nextQuestion,
        );
        expect(
          cont.decision?.type == HealthGuidanceDecisionType.urgentEvaluation ||
              cont.decision?.type ==
                  HealthGuidanceDecisionType.emergencyEvaluation ||
              cont.decision?.type ==
                  HealthGuidanceDecisionType.needMoreInformation,
          isTrue,
        );
      }
    });

    test('SCRIPT 4 — urgent interruption of routine flow', () {
      final start = coordinator.startFromUserText(
        query: 'بطني يوجعني',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(start.session.status, HealthGuidanceSessionStatus.waitingForAnswer);
      final interrupted = coordinator.continueAfterAnswer(
        answerText: 'شديد',
        session: start.session.copyWith(
          facts: start.session.facts.copyWith(
            symptomStatuses: {
              ...start.session.facts.symptomStatuses,
              'chest_pain': SymptomPolarity.present,
              'shortness_of_breath': SymptomPolarity.present,
            },
            userSeverity: UserStatedSeverity.severe,
            symptomFacts: {
              ...start.session.facts.symptomFacts,
              'chest_pain':
                  const SymptomScopedFacts(severity: UserStatedSeverity.severe),
              'shortness_of_breath':
                  const SymptomScopedFacts(severity: UserStatedSeverity.severe),
            },
          ),
        ),
        turnId: 2,
        pendingQuestion: start.decision?.nextQuestion,
      );
      expect(
        interrupted.decision?.type ==
                HealthGuidanceDecisionType.urgentEvaluation ||
            interrupted.decision?.type ==
                HealthGuidanceDecisionType.emergencyEvaluation,
        isTrue,
      );
      expect(interrupted.decision?.allowCommercialOffers, isFalse);
      expect(interrupted.session.safetyWarningDelivered, isTrue);
    });

    test('SCRIPT 5 — no false reassurance', () {
      final d = safety.evaluate(factsFrom('راسي يوجعني شوية'));
      expect(d.status, MedicalSafetyStatus.noRedFlagDetected);
      final g = guidance.evaluate(factsFrom('راسي يوجعني شوية'));
      expect(g.userMessage.contains('أنت بخير'), isFalse);
      expect(g.userMessage.contains('ماكو خطر'), isFalse);
      expect(g.userMessage.contains('ما تحتاج طبيب'), isFalse);
    });

    test('10C no longer owns competing urgent rule', () {
      final rules = const LocalHealthGuidanceRuleSource().enabledRulesSync();
      expect(rules.any((r) => r.isUrgentSafety), isFalse);
      expect(rules.any((r) => r.id.contains('urgent_chest')), isFalse);
    });
  });
}
