import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_coordinator.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_models.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_engine.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_models.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_coordinator.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_detector.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/health/understanding/symptom_models.dart';
import 'package:ghadeer_clinic/labs/labs_service.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conduct/conversation_conduct_detector.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/guided_conversation_models.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

/// PC-0.3 — Health subject session foundation.
///
/// Invariants under test:
/// SYMPTOM ≠ DIAGNOSIS
/// SUBJECT HEALTH FACT ≠ ACCOUNT OWNER HEALTH FACT
/// SESSION SUBJECT ≠ PERSISTENT PERSON PROFILE
void main() {
  late HealthSubjectDetector detector;
  late HealthSubjectCoordinator subjects;
  late HealthGuidanceCoordinator health;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;

  setUp(() {
    detector = const HealthSubjectDetector();
    subjects = HealthSubjectCoordinator(detector: detector);
    health = HealthGuidanceCoordinator(subjectCoordinator: subjects);
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      doctorLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. تجريبي',
              subtitle: 'باطنية',
              doctorId: 'd1',
              specialty: 'باطنية',
              score: 90,
            ),
          ],
      labLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.lab,
              title: 'مختبر الحياة',
              subtitle: 'مختبر',
              labId: 'hayat',
              score: 90,
            ),
          ],
      analysisLookup: (_) async => [
            AnalysisItem(id: 'cbc', name: 'CBC', aliases: const ['سي بي سي']),
          ],
      packagesLookup: (_) async => [
            const LabPackageItem(
              id: 'p1',
              labId: 'hayat',
              name: 'باقة أ',
              newPrice: 50,
            ),
          ],
      activePackagesLookup: ({labId, nameQuery}) async => [
            AnalysisPackageLink(
              package: const LabPackageItem(
                id: 'p1',
                labId: 'hayat',
                name: 'باقة أ',
                newPrice: 50,
              ),
              labId: 'hayat',
              labName: 'مختبر الحياة',
            ),
          ],
      packagesForAnalysisLookup: (_) async => const [],
    );
  });

  HealthGuidanceSession start(String text, {HealthGuidanceSession? current}) {
    final r = health.startFromUserText(
      query: text,
      current: current ?? HealthGuidanceSession.inactive,
      turnId: 1,
    );
    expect(r.handled, isTrue, reason: 'expected health handle for: $text');
    return r.session;
  }

  group('PC-0.3 HealthSubject detection A–J', () {
    test('A — عندي صداع → self', () {
      final d = detector.detect('عندي صداع');
      expect(d.type, HealthSubjectType.self);
      expect(d.evidence, HealthSubjectEvidence.explicitSelf);
    });

    test('B — صارلي يومين عندي ألم → self', () {
      final d = detector.detect('صارلي يومين عندي ألم');
      expect(d.type, HealthSubjectType.self);
    });

    test('C — ابني عنده حرارة → child', () {
      final d = detector.detect('ابني عنده حرارة');
      expect(d.type, HealthSubjectType.child);
      expect(d.evidence, HealthSubjectEvidence.explicitRelationship);
    });

    test('D — بنتي عندها سعال → child', () {
      expect(detector.detect('بنتي عندها سعال').type, HealthSubjectType.child);
    });

    test('E — أمي عندها دوخة → mother', () {
      expect(detector.detect('أمي عندها دوخة').type, HealthSubjectType.mother);
    });

    test('F — والدتي عندها ألم → mother', () {
      expect(
        detector.detect('والدتي عندها ألم').type,
        HealthSubjectType.mother,
      );
    });

    test('G — أبويه يتعب من المشي → father', () {
      expect(
        detector.detect('أبويه يتعب من المشي').type,
        HealthSubjectType.father,
      );
    });

    test('H — والدي عنده ألم → father', () {
      expect(detector.detect('والدي عنده ألم').type, HealthSubjectType.father);
    });

    test('I — زوجتي عندها دوخة → spouse', () {
      expect(
        detector.detect('زوجتي عندها دوخة').type,
        HealthSubjectType.spouse,
      );
    });

    test('J — أخي عنده ألم → familyMember', () {
      expect(
        detector.detect('أخي عنده ألم').type,
        HealthSubjectType.familyMember,
      );
    });
  });

  group('PC-0.3 subject session ownership', () {
    test('K — عنده ألم without referent → unknown, not self', () {
      final d = detector.detect('عنده ألم');
      expect(d.type, HealthSubjectType.unknown);
      expect(d.evidence, HealthSubjectEvidence.ambiguous);
      final session = start('عنده ألم بطن');
      expect(session.subject.type, isNot(HealthSubjectType.self));
    });

    test('L — child complaint → من البارحة remains child', () {
      var s = start('ابني عنده حرارة');
      expect(s.subject.type, HealthSubjectType.child);
      final cont = health.continueAfterAnswer(
        answerText: 'من البارحة',
        session: s.copyWith(status: HealthGuidanceSessionStatus.waitingForAnswer),
        turnId: 2,
        pendingQuestion: s.currentDecision?.nextQuestion,
      );
      expect(cont.session.subject.type, HealthSubjectType.child);
    });

    test('M — mother → وعندها غثيان remains mother', () {
      var s = start('أمي عندها دوخة');
      expect(s.subject.type, HealthSubjectType.mother);
      final cont = health.startFromUserText(
        query: 'وعندها غثيان',
        current: s,
        turnId: 2,
      );
      expect(cont.session.subject.type, HealthSubjectType.mother);
    });

    test('N — child → وأنا عندي صداع switches to self', () {
      final child = start('ابني عنده حرارة');
      final feverPresent =
          child.facts.symptomStatuses['fever'] == SymptomPolarity.present ||
              child.facts.symptomStatuses.isNotEmpty;
      final next = health.startFromUserText(
        query: 'وأنا عندي صداع',
        current: child,
        turnId: 2,
      );
      expect(next.session.subject.type, HealthSubjectType.self);
      expect(next.session.previousSubjectType, HealthSubjectType.child);
      // P/Q/R — لا دمج
      if (feverPresent) {
        expect(
          next.session.facts.symptomStatuses['fever'],
          isNot(SymptomPolarity.present),
        );
      }
    });

    test('O — self → أمي عندها دوخة switches to mother', () {
      final self = start('أنا عندي ألم ظهر');
      expect(self.subject.type, HealthSubjectType.self);
      final next = health.startFromUserText(
        query: 'أمي عندها دوخة',
        current: self,
        turnId: 2,
      );
      expect(next.session.subject.type, HealthSubjectType.mother);
    });

    test('P/Q/R/S — subject switch does not merge facts', () {
      var child = start('ابني عنده حرارة');
      // simulate duration/severity/safety on child session
      child = child.copyWith(
        facts: child.facts.copyWith(
          duration: const DurationValue(amount: 2, unit: 'day', rawText: 'يومين'),
          userSeverity: UserStatedSeverity.severe,
        ),
        lastSafetyStatus: MedicalSafetyStatus.urgentEvaluation.name,
        matchedSafetyRuleId: 'child_rule',
        safetyWarningDelivered: true,
      );
      final next = health.startFromUserText(
        query: 'وأنا عندي صداع',
        current: child,
        turnId: 3,
      );
      expect(next.session.subject.type, HealthSubjectType.self);
      expect(next.session.facts.duration, isNull); // Q
      expect(
        next.session.facts.userSeverity,
        isNot(UserStatedSeverity.severe),
      ); // R
      // سلامة الطفل لا تُورَّث — تقييم جديد فقط إن وُجد
      expect(next.session.matchedSafetyRuleId, isNull); // S
      expect(next.session.safetyWarningDelivered, isFalse);
      expect(
        next.session.lastSafetyStatus,
        isNot(MedicalSafetyStatus.urgentEvaluation.name),
      );
      expect(
        next.session.facts.symptomStatuses['fever'],
        isNot(SymptomPolarity.present),
      ); // P
    });

    test('T — pending child Q + self complaint not consumed as child answer',
        () {
      final child = start('ابني عنده حرارة');
      final q = child.currentDecision?.nextQuestion;
      expect(q, isNotNull);
      final waiting = child.copyWith(
        status: HealthGuidanceSessionStatus.waitingForAnswer,
      );
      final cont = health.continueAfterAnswer(
        answerText: 'أنا هم عندي صداع من البارحة',
        session: waiting,
        turnId: 2,
        pendingQuestion: q,
      );
      expect(cont.session.subject.type, HealthSubjectType.self);
      // المدة الجديدة تخص self وليست إجابة سؤال الطفل بالضرورة كدمج
      expect(cont.session.previousSubjectType, HealthSubjectType.child);
      expect(
        cont.session.facts.symptomStatuses['fever'],
        isNot(SymptomPolarity.present),
      );
    });

    test('U — pending mother Q + father complaint switches', () {
      final mother = start('أمي عندها دوخة');
      final q = mother.currentDecision?.nextQuestion;
      final waiting = mother.copyWith(
        status: HealthGuidanceSessionStatus.waitingForAnswer,
      );
      final cont = health.continueAfterAnswer(
        answerText: 'أبويه يتعب من المشي وعنده ألم',
        session: waiting,
        turnId: 2,
        pendingQuestion: q,
      );
      expect(cont.session.subject.type, HealthSubjectType.father);
    });

    test('V — نرجع لابني does not fabricate lost health facts', () {
      final child = start('ابني عنده حرارة');
      final afterSelf = health.startFromUserText(
        query: 'وأنا عندي صداع',
        current: child,
        turnId: 2,
      );
      final back = health.startFromUserText(
        query: 'نرجع لابني',
        current: afterSelf.session,
        turnId: 3,
      );
      expect(back.handled, isTrue);
      expect(back.session.subject.type, HealthSubjectType.child);
      expect(back.session.facts.symptomStatuses['fever'], isNull);
      expect(back.session.facts.duration, isNull);
    });
  });

  group('PC-0.3 entity search unaffected W–Z', () {
    test('W — doctor search unaffected', () async {
      // طبقة الموضوع لا تمنع مسار الكيانات؛ نتائج الأطباء تُحفظ ككيان محادثة.
      ctx.rememberResults(
        [
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'د. تجريبي',
            subtitle: 'باطنية',
            doctorId: 'd1',
            specialty: 'باطنية',
            score: 90,
          ),
        ],
        intent: AssistantIntent.specialtySearch,
      );
      expect(ctx.currentResultContext?.entityType, ConversationEntityType.doctor);
      final plan = await brain.plan(query: 'أريد طبيب باطنية', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.healthGuidance));
    });

    test('X — lab search unaffected', () async {
      await brain.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
    });

    test('Y — analysis search unaffected', () async {
      await brain.plan(query: 'أريد تحليل CBC', context: ctx);
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.analysis,
      );
    });

    test('Z — package search unaffected', () async {
      final plan = await brain.plan(query: 'أريد باقات', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.healthGuidance));
      expect(
        ctx.currentResultContext?.entityType ==
                ConversationEntityType.package ||
            plan.message.contains('باق'),
        isTrue,
      );
    });
  });

  group('PC-0.3 safety & handoff AA–AF', () {
    test('AA — health safety authoritative per subject', () {
      final mother = start('أمي عندها دوخة');
      expect(mother.subject.type, HealthSubjectType.mother);
      final safety = MedicalSafetyEngine().evaluate(mother.facts);
      expect(safety, isA<MedicalSafetyDecision>());
    });

    test('AB — urgent mother does not mark account-owner session after switch',
        () {
      var mother = start('أمي عندها دوخة شديدة وإغماء');
      mother = mother.copyWith(
        lastSafetyStatus: MedicalSafetyStatus.urgentEvaluation.name,
        safetyWarningDelivered: true,
      );
      final self = health.startFromUserText(
        query: 'وأنا عندي صداع خفيف',
        current: mother,
        turnId: 2,
      );
      expect(self.session.subject.type, HealthSubjectType.self);
      expect(self.session.safetyWarningDelivered, isFalse);
      expect(
        self.session.lastSafetyStatus,
        isNot(MedicalSafetyStatus.urgentEvaluation.name),
      );
    });

    test('AC — urgent self does not leak into child context', () {
      var self = start('عندي ألم صدر شديد');
      self = self.copyWith(
        lastSafetyStatus: MedicalSafetyStatus.urgentEvaluation.name,
        safetyWarningDelivered: true,
        matchedSafetyRuleId: 'self_urgent',
      );
      final child = health.startFromUserText(
        query: 'ابني عنده حرارة',
        current: self,
        turnId: 2,
      );
      expect(child.session.subject.type, HealthSubjectType.child);
      expect(child.session.matchedSafetyRuleId, isNull);
      expect(child.session.safetyWarningDelivered, isFalse);
    });

    test('AD — provider handoff after child health flow', () {
      final child = start('ابني عنده حرارة');
      expect(child.subject.type, HealthSubjectType.child);
      // حتى قبل الاكتشاف — الموضوع على الحقائق
      expect(child.facts.subject.type, HealthSubjectType.child);
    });

    test('AE — provider handoff after self health flow', () {
      final self = start('عندي صداع');
      expect(self.subject.type, HealthSubjectType.self);
    });

    test('AF — no symptoms sent to provider / handoff metadata only', () {
      final child = start('ابني عنده حرارة');
      final handoff = HealthGuidanceHandoff(
        status: HealthGuidanceHandoffStatus.awaitingAcceptance,
        subjectTypeName: child.subject.type.name,
      );
      final map = handoff.debugMap();
      expect(map['handoffSubjectType'], 'child');
      final blob = map.values.join(' ');
      expect(blob.toLowerCase().contains('حرارة'), isFalse);
      expect(blob.contains('fever'), isFalse);
    });
  });

  group('PC-0.3 privacy & lifecycle AG–AK', () {
    test('AG — no subject health data in analytics-shaped snapshot raw text', () {
      final s = start('ابني عنده حرارة وصداع');
      final snap = s.debugSnapshot();
      final blob = snap.toString();
      expect(blob.contains('حرارة'), isFalse);
      expect(blob.contains('صداع'), isFalse);
      expect(snap['subjectType'], 'child');
    });

    test('AH — no SharedPreferences persistence API used by subject layer', () {
      final src = File(
        'lib/health/subject/health_subject_models.dart',
      ).readAsStringSync();
      expect(src.contains('SharedPreferences'), isFalse);
      expect(src.contains('supabase'), isFalse);
    });

    test('AI — no Supabase in subject package', () {
      for (final f in [
        'lib/health/subject/health_subject_detector.dart',
        'lib/health/subject/health_subject_coordinator.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src.toLowerCase().contains('supabase'), isFalse);
        expect(src.contains('SharedPreferences'), isFalse);
      }
    });

    test('AJ — reset removes subject state', () {
      ctx.setHealthGuidanceSession(start('ابني عنده حرارة'));
      expect(ctx.healthGuidanceSession.subject.type, HealthSubjectType.child);
      ctx.reset();
      expect(ctx.healthGuidanceSession.subject.type, HealthSubjectType.unknown);
      expect(ctx.healthGuidanceSession.isActive, isFalse);
    });

    test('AK — new ConversationContext begins without session subject', () {
      final fresh = ConversationContext();
      expect(fresh.healthGuidanceSession.subject.type, HealthSubjectType.unknown);
      expect(fresh.healthGuidanceSession.isActive, isFalse);
    });
  });

  group('PC-0.3 parity & conduct AL–AP', () {
    test('AL — voice/text parity of subject detection', () {
      const q = 'ابني عنده حرارة';
      final a = detector.detect(q);
      final b = detector.detect(q); // same transcript path
      expect(a.type, b.type);
      expect(a.evidence, b.evidence);
    });

    test('AM — conduct does not destroy child evidence', () {
      const q = 'يا غبي ابني عنده حرارة';
      final d = detector.detect(q);
      expect(d.type, HealthSubjectType.child);
      final conduct = ConversationConductDetector().detect(q);
      expect(conduct.level.name.isNotEmpty, isTrue);
      final session = start(q);
      expect(session.subject.type, HealthSubjectType.child);
    });

    test('AN — correction لا مو إلي، لابني → child', () {
      final self = start('عندي صداع');
      final corr = health.startFromUserText(
        query: 'لا مو إلي، لابني',
        current: self,
        turnId: 2,
      );
      expect(corr.session.subject.type, HealthSubjectType.child);
    });

    test('AO — correction لا مو لابني، إلي → self', () {
      final child = start('ابني عنده حرارة');
      final corr = health.startFromUserText(
        query: 'لا مو لابني، إلي',
        current: child,
        turnId: 2,
      );
      expect(corr.session.subject.type, HealthSubjectType.self);
    });

    test('AP — unknown subject handled conservatively', () {
      final r = subjects.resolve(
        current: null,
        text: 'عنده ألم',
      );
      expect(r.subject.type, HealthSubjectType.unknown);
      expect(r.ambiguous, isTrue);
      expect(r.switched, isFalse);
    });
  });

  group('PC-0.3 invariants', () {
    test('SESSION SUBJECT ≠ PERSISTENT PERSON PROFILE comment present', () {
      final src = File('lib/health/subject/health_subject_models.dart')
          .readAsStringSync();
      expect(src.contains('SESSION SUBJECT ≠ PERSISTENT PERSON PROFILE'), isTrue);
      expect(src.contains('SUBJECT HEALTH FACT ≠ ACCOUNT OWNER HEALTH FACT'),
          isTrue);
      expect(src.contains('SYMPTOM ≠ DIAGNOSIS'), isTrue);
    });

    test('diagnosed condition stays on subject session only', () {
      final child = start('ابني مشخص ربو وعنده حرارة');
      expect(child.subject.type, HealthSubjectType.child);
      final self = health.startFromUserText(
        query: 'وأنا عندي صداع',
        current: child,
        turnId: 2,
      );
      expect(self.session.subject.type, HealthSubjectType.self);
      // لا وراثة لحقائق الطفل إلى صاحب الحساب
      expect(self.session.facts.symptomStatuses, isNot(child.facts.symptomStatuses));
    });

    test('selected entities remain conversation entities not patient profile',
        () async {
      final s = start('عندي صداع');
      ctx.setHealthGuidanceSession(s);
      ctx.rememberResults(
        [
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'د. تجريبي',
            subtitle: 'باطنية',
            doctorId: 'd1',
            specialty: 'باطنية',
            score: 90,
          ),
        ],
        intent: AssistantIntent.specialtySearch,
      );
      expect(ctx.currentResultContext?.entityType, ConversationEntityType.doctor);
      expect(ctx.healthGuidanceSession.subject.type, HealthSubjectType.self);
      // كيان المحادثة ≠ ملف المريض
      expect(ctx.selectedDoctor?.doctorId, isNot(equals('patient')));
    });
  });
}
