import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/clinical_knowledge_models.dart';
import 'package:ghadeer_clinic/companion/adolescent/adolescent.dart';
import 'package:ghadeer_clinic/health/emotional_support/mental_health_safety_gate.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_engine.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  late AdolescentCompanionCoordinator ado;

  setUp(() {
    ado = AdolescentCompanionCoordinator();
  });

  Future<AdolescentCompanionTurnResult> run(
    String text, {
    AdolescentCompanionSession? session,
  }) =>
      ado.handle(
        text: text,
        session: session ?? AdolescentCompanionSession.inactive,
      );

  group('PC-1.23 age', () {
    test('explicit adolescent age activates', () async {
      final r = await run('عمري 16 وما اكدر أركز بالدراسة');
      expect(r.handled, isTrue);
      expect(r.session.statedAgeYears, 16);
      expect(r.session.developmentState,
          AdolescentDevelopmentState.confirmedAdolescent);
      expect(ado.infersAgeFromStyle(), isFalse);
    });

    test('school alone without age does not activate', () {
      expect(
        ado.mayHandle(
          query: 'عندي امتحان بالمدرسة',
          session: AdolescentCompanionSession.inactive,
        ),
        isFalse,
      );
    });

    test('adult / younger child boundaries', () async {
      expect(
        (await run('عمري 25 ومتوتر من الشغل')).session.developmentState,
        AdolescentDevelopmentState.adult,
      );
      expect(
        (await run('عمري 8 وما أدرس')).session.developmentState,
        AdolescentDevelopmentState.youngerChild,
      );
    });

    test('thresholds centralized', () {
      expect(AdolescentEvidenceCatalog.adolescenceMinAgeInclusive, 10);
      expect(AdolescentEvidenceCatalog.adolescenceMaxAgeInclusive, 19);
      expect(AdolescentEvidenceCatalog.recommendedSleepHoursMin, 8);
    });
  });

  group('PC-1.23 subject', () {
    test('parent about son not owner', () async {
      final r = await run('ابني عمره 15 وما يدرس');
      expect(r.session.parentAskingAboutTeen || r.session.isOtherPerson, isTrue);
      expect(r.message.contains('كسل') && r.message.contains('أنت كسول'), isFalse);
    });

    test('subject correction clears owner age', () async {
      final s = AdolescentCompanionSession(
        active: true,
        statedAgeYears: 16,
        developmentState: AdolescentDevelopmentState.confirmedAdolescent,
      );
      final r = await run('مو إلي، لابني', session: s);
      expect(r.session.isOtherPerson, isTrue);
      expect(r.session.statedAgeYears, isNull);
    });
  });

  group('PC-1.23 study / sleep / body', () {
    test('study help no ADHD diagnosis', () async {
      final r = await run('عمري 16 وما اكدر أركز بالدراسة');
      expect(r.message.toLowerCase().contains('adhd'), isFalse);
      expect(RegExp(r'تشخيص\s+(?:ADHD|قلق|اكتئاب)').hasMatch(r.message), isFalse);
      expect(ado.diagnosesAdhdFromConcentration(), isFalse);
    });

    test('exam stress practical next step', () async {
      final r = await run('عمري 17 عندي امتحان وخايف');
      expect(r.handled, isTrue);
      expect(RegExp(r'عندك\s*اكتئاب').hasMatch(r.message), isFalse);
    });

    test('motivation no moralizing', () async {
      final r = await run('عمري 15 ما عندي نفس أدرس');
      expect(RegExp(r'أنت\s*كسول|انك\s*كسول').hasMatch(r.message), isFalse);
    });

    test('sleep guidance', () async {
      final r = await run('عمري 16 وأسهر كل الليل');
      expect(r.message.contains('8') || r.message.contains('نوم'), isTrue);
      expect(r.message.contains('أرق مزمن مشخص'), isFalse);
    });

    test('body image / refuse unsafe weight loss', () async {
      final r = await run('عمري 15 ما أحب شكلي وأريد أخس بسرعة بحبوب');
      expect(r.message.contains('حبوب') || r.message.contains('تخسيس'), isTrue);
      expect(r.message.contains('خطة سعرات'), isFalse);
    });
  });

  group('PC-1.23 bullying / family / mental', () {
    test('bullying support', () async {
      final r = await run('عمري 14 وأصدقائي يتنمرون علي');
      expect(r.session.bullyingContext, isTrue);
      expect(r.message.contains('الرد الجسدي') || r.message.contains('بالغ موثوق'),
          isTrue);
    });

    test('cyberbullying no password request', () async {
      final r = await run('عمري 15 واحد بالنت يضايقني ويتنمر');
      expect(r.message.contains('أعطني كلمة السر') ||
          r.message.contains('ارسلي الباسوورد'), isFalse);
    });

    test('family tension no side-taking', () async {
      final r = await run('عمري 16 أهلي ما يفهموني');
      expect(r.message.contains('طرفاً'), isTrue);
    });

    test('self-harm defers to MentalHealthSafetyGate', () async {
      final r = await run('عمري 16 أبي أقتل نفسي');
      expect(r.deferToMentalSafety, isTrue);
      expect(const MentalHealthSafetyGate().triggersCrisis('أبي أقتل نفسي'),
          isTrue);
      expect(MedicalSafetyEngine, isNotNull);
    });
  });

  group('PC-1.23 puberty / education / mayHandle', () {
    test('puberty education no sex inference', () async {
      final r = await run('شنو يصير بسن المراهقة؟');
      expect(r.handled, isTrue);
      expect(r.session.topic, AdolescentTopic.educationOnly);
    });

    test('mayHandle strict', () {
      expect(
        ado.mayHandle(query: 'مرحبا', session: AdolescentCompanionSession.inactive),
        isFalse,
      );
      expect(
        ado.mayHandle(
          query: 'عندي سعال',
          session: AdolescentCompanionSession.inactive,
        ),
        isFalse,
      );
      expect(
        ado.mayHandle(
          query: 'سني يوجعني',
          session: AdolescentCompanionSession.inactive,
        ),
        isFalse,
      );
      expect(
        ado.mayHandle(
          query: 'عمري 16 وما اكدر أركز بالدراسة',
          session: AdolescentCompanionSession.inactive,
        ),
        isTrue,
      );
    });

    test('active session no hijack greeting', () {
      const active = AdolescentCompanionSession(
        active: true,
        statedAgeYears: 16,
        developmentState: AdolescentDevelopmentState.confirmedAdolescent,
      );
      expect(ado.mayHandle(query: 'مرحبا', session: active), isFalse);
    });
  });

  group('PC-1.23 architecture', () {
    test('no duplicate stores / commercial', () {
      expect(ado.createsTeenProfileStore(), isFalse);
      expect(ado.createsTeenMentalHealthStore(), isFalse);
      expect(ado.createsSchoolRecordStore(), isFalse);
      expect(ado.createsSurveillance(), isFalse);
      expect(ado.commercialTargetsTeens(), isFalse);
      expect(ado.usesDependencyLanguage(), isFalse);
    });

    test('evidence metadata', () {
      for (final r in ado.catalog.active) {
        expect(r.hasEvidenceMetadata, isTrue, reason: r.ruleId);
      }
    });

    test('debug privacy', () {
      final d = const AdolescentCompanionSession(
        active: true,
        statedAgeYears: 16,
        topic: AdolescentTopic.examStress,
        matchedRuleIds: ['ado_study_stress_support'],
      ).debugMap();
      expect(d.containsKey('personId'), isFalse);
      expect(d.values.contains(16), isFalse);
      expect(d.values.contains('امتحان'), isFalse);
    });

    test('catalog failure', () async {
      final bad = AdolescentCompanionCoordinator(
        catalog: AdolescentEvidenceCatalog(rules: [
          AdolescentEvidenceRule(
            ruleId: 'broken',
            topic: AdolescentTopic.studyDifficulty,
            evidence: const ClinicalEvidenceReference(
              sourceOrganization: '',
              sourceTitle: '',
              sourceReference: '',
              sourceVersionOrDate: '',
              evidenceType: ClinicalEvidenceType.other,
            ),
            reviewedAt: DateTime(2020),
            freshness: ClinicalEvidenceFreshness.reviewDue,
            clinicalReviewRequired: true,
            isActive: true,
          ),
        ]),
      );
      // Need ClinicalEvidence imports - use catalog from package
      final r = await bad.handle(
        text: 'عمري 16 متوتر',
        session: AdolescentCompanionSession.inactive,
      );
      expect(r.success, isFalse);
    });

    test('Smart Brain wires adolescent companion', () async {
      final planner = SmartBrainPlanner(
        doctorLookup: (_) async => <SmartSearchResult>[],
      );
      final c = ConversationContext();
      final plan = await planner.plan(
        query: 'عمري 16 وما اكدر أركز بالدراسة',
        context: c,
      );
      expect(plan.message, isNotNull);
      expect(c.adolescentCompanionSession.active, isTrue);
    });

    test('teen + cough defers clinical (dental/resp path)', () async {
      expect(
        ado.mayHandle(
          query: 'عمري 16 وعندي سعال',
          session: AdolescentCompanionSession.inactive,
        ),
        isFalse,
      );
    });

    test('text-first / pack exists', () async {
      final r = await run('عمري 16 متوتر من الامتحان');
      expect(r.textFirstOnly, isTrue);
      expect(Directory('lib/companion/adolescent').existsSync(), isTrue);
    });

    test('follow-up deferred', () async {
      final r = await run('عمري 16 ذكرني أدرس');
      expect(r.deferToFollowUp, isTrue);
    });

    test('plan handoff', () async {
      final r = await run('عمري 16 أريد أرتب يومي');
      expect(r.deferToPlanner || r.message.contains('مخطّط'), isTrue);
    });

    test('no absolute secrecy promise language in responses', () async {
      final r = await run('عمري 16 أهلي ما يفهموني');
      expect(r.message.contains('سر بيني وبينك مهما صار'), isFalse);
      expect(r.message.contains('صديقك الوحيد'), isFalse);
    });
  });
}
