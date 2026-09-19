import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/clinical_knowledge_models.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/dental/dental.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_engine.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  late DentalGuidanceCoordinator dental;

  setUp(() {
    dental = DentalGuidanceCoordinator();
  });

  Future<DentalTurnResult> run(String text, {DentalSession? session}) =>
      dental.handle(text: text, session: session ?? DentalSession.inactive);

  group('PC-1.22 basic pain', () {
    test('toothache no autonomous diagnosis', () async {
      final r = await run('سني يوجعني');
      expect(r.handled, isTrue);
      expect(r.session.topic, DentalTopic.toothPain);
      expect(r.message.contains('تسوس مؤكد') || r.message.contains('التهاب عصب مؤكد'),
          isFalse);
      expect(r.message.contains('تشخيص'), isFalse);
    });

    test('night / cold / severity', () async {
      expect(
        dental.interpreter.interpret('وجع السن يزيد بالليل').triggers,
        contains(DentalPainTrigger.night),
      );
      expect(
        dental.interpreter.interpret('وجع من أشرب بارد').triggers,
        contains(DentalPainTrigger.cold),
      );
      expect(
        dental.interpreter.interpret('سني يوجعني شديد').severity,
        ClinicalSeverityClass.severe,
      );
      expect(dental.imagingPolicy.severityAloneRequiresXray(ClinicalSeverityClass.severe),
          isFalse);
    });
  });

  group('PC-1.22 swelling / safety', () {
    test('facial swelling urgent language', () async {
      final r = await run('وجهي ورم من السن');
      expect(r.handled, isTrue);
      expect(r.message.contains('لما تقدر'), isFalse);
      expect(r.session.urgency, DentalUrgency.urgentDentalReview);
    });

    test('difficulty swallowing defers to 10E', () async {
      final r = await run('سني يوجعني ووجهي وارم وما اكدر ابلع');
      expect(r.deferToMedicalSafety, isTrue);
      expect(dental.createsDentalEmergencyEngine(), isFalse);
      expect(MedicalSafetyEngine, isNotNull);
    });

    test('difficulty breathing defers', () async {
      final r = await run('ورم وجهي وما اكدر اتنفس');
      expect(r.deferToMedicalSafety, isTrue);
    });
  });

  group('PC-1.22 antibiotics', () {
    test('need antibiotic — stewardship no prescribing', () async {
      final r = await run('سني يوجعني أحتاج مضاد؟');
      expect(r.handled, isTrue);
      expect(r.message.contains('مضاد وحده') || r.message.contains('العلاج السببي'),
          isTrue);
      expect(dental.autonomouslyPrescribesAntibiotics(), isFalse);
      expect(dental.createsDentalAntibioticEngine(), isFalse);
    });

    test('named antibiotic / leftover / prophylaxis refused', () async {
      final named = await run('أعطني أموكسيسيلين للضرس');
      expect(named.message.contains('بالاسم') || named.message.contains('ما نبدأ'),
          isTrue);
      final pro = await run('أحتاج مضاد وقائي قبل خلع لأن عندي صمام قلب');
      expect(pro.message.contains('وقائي'), isTrue);
    });
  });

  group('PC-1.22 trauma / primary vs permanent', () {
    test('avulsion unknown asks tooth type', () async {
      final r = await run('طفلي طاح وسنه طاح من مكانه');
      expect(r.handled, isTrue);
      expect(r.message.contains('لبني') || r.message.contains('دائم'), isTrue);
    });

    test('primary != permanent guidance', () async {
      final primary = await run(
        'سن ابني اللبني طاح من مكانه',
        session: const DentalSession(active: true),
      );
      expect(primary.message.contains('اللبني') || primary.message.contains('بخلاف'),
          isTrue);
      expect(dental.confusesPrimaryWithPermanent(), isFalse);

      final perm = await run('السن الدائم انخلع بعد ضربة');
      expect(perm.message.contains('دائم') || perm.message.contains('عاجلة'),
          isTrue);
    });

    test('broken tooth no restoration promise', () async {
      final r = await run('سن انكسر');
      expect(r.message.contains('نوع الترميم'), isTrue);
      expect(RegExp(r'تحتاجين?\s*تاج').hasMatch(r.message), isFalse);
    });
  });

  group('PC-1.22 pregnancy / child / gums', () {
    test('pregnant + toothache one coherent path', () async {
      final r = await run('اني حامل وأسناني توجعني');
      expect(r.handled, isTrue);
      expect(r.session.pregnancyContext, isTrue);
      expect(r.message.contains('لما تولدين'), isFalse);
      expect(r.message.contains('انتظري لما'), isFalse);
    });

    test('gum bleeding no stop brushing', () async {
      final r = await run('لثتي تنزف وقت التفريش');
      expect(r.message.contains('ما نوقف التفريش') || r.message.contains('لا يعني'),
          isTrue);
    });

    test('child no adult dose', () async {
      final r = await run('ابني سنه يوجعه أحتاج مسكن؟');
      expect(r.message.contains('جرعة بالغ') || r.message.contains('ما أحسب'),
          isTrue);
    });
  });

  group('PC-1.22 wisdom / lesion / imaging', () {
    test('wisdom no auto extraction', () async {
      final r = await run('ضرس العقل يوجعني اخلع');
      expect(r.message.contains('خلع تلقائي') || r.message.contains('ما أقرر خلعاً'),
          isTrue);
    });

    test('oral lesion no cancer diagnosis', () async {
      final r = await run('عندي كتلة بالفم مستمرة أكثر من أسبوعين خايف سرطان');
      expect(r.message.contains('سرطان مؤكد') || r.message.contains('هاي سرطان'),
          isFalse);
      expect(r.message.contains('أكيد مو سرطان'), isFalse);
    });

    test('imaging clinical first / commercial neutral', () async {
      expect(dental.imagingPolicy.toothacheAloneRequiresPanoramic(), isFalse);
      expect(dental.imagingPolicy.commercialCanAlterIndication(), isFalse);
      expect(dental.imagingPolicy.pregnancyBansAllDentalXray(), isFalse);
      final r = await run('سني يوجعني أحتاج أشعة بانوراما؟');
      expect(r.message.contains('تلقائياً') || r.message.contains('لا يفرض'),
          isTrue);
    });
  });

  group('PC-1.22 subject / negation / mayHandle', () {
    test('other person isolation', () async {
      final r = await run('ابني سنه يوجعه');
      expect(r.session.isOtherPerson, isTrue);
    });

    test('negation clears swelling', () async {
      var s = const DentalSession(
        active: true,
        topic: DentalTopic.toothPain,
        swelling: DentalSwellingClass.facial,
      );
      final r = await run('ماكو ورم، بس ألم', session: s);
      expect(r.session.swelling, DentalSwellingClass.none);
    });

    test('PC-1.24 regression: facial negation + gum same turn', () async {
      var s = const DentalSession(
        active: true,
        topic: DentalTopic.facialSwelling,
        swelling: DentalSwellingClass.facial,
      );
      final r = await run('لا ماكو ورم بالوجه، بس اللثة وارمة', session: s);
      expect(r.session.swelling, DentalSwellingClass.gum);
      expect(r.message.contains('تورم الوجه المرتبط'), isFalse);
    });

    test('PC-1.24 regression: active dental continues on face swelling cue', () {
      final s = const DentalSession(active: true, topic: DentalTopic.toothPain);
      expect(
        dental.mayHandle(query: 'ووجهه هم وارم', session: s),
        isTrue,
      );
    });

    test('mayHandle strict', () {
      expect(
        dental.mayHandle(query: 'مرحبا', session: DentalSession.inactive),
        isFalse,
      );
      expect(
        dental.mayHandle(query: 'عندي صداع', session: DentalSession.inactive),
        isFalse,
      );
      expect(
        dental.mayHandle(query: 'عندي سعال', session: DentalSession.inactive),
        isFalse,
      );
      expect(
        dental.mayHandle(query: 'سني يوجعني', session: DentalSession.inactive),
        isTrue,
      );
      const active = DentalSession(active: true, topic: DentalTopic.toothPain);
      expect(dental.mayHandle(query: 'مرحبا', session: active), isFalse);
    });

    test('education does not diagnose', () async {
      final r = await run('شنو هو تسوس الأسنان؟');
      expect(r.session.topic, DentalTopic.educationOnly);
      expect(r.message.contains('تشخيص لحالتك') || r.message.contains('تعليمي'),
          isTrue);
    });
  });

  group('PC-1.22 architecture / privacy / failure', () {
    test('evidence metadata and thresholds', () {
      for (final r in dental.catalog.active) {
        expect(r.hasEvidenceMetadata, isTrue, reason: r.ruleId);
      }
      expect(DentalRuleCatalog.oralLesionPersistenceDays, 14);
      expect(DentalRuleCatalog.avulsionUrgentWindowMinutes, 60);
    });

    test('no duplicate authorities', () {
      expect(dental.createsDentalHistoryStore(), isFalse);
      expect(dental.createsDentalEmergencyEngine(), isFalse);
      expect(dental.autonomouslySelectsProcedures(), isFalse);
      expect(dental.commercialImagingBias(), isFalse);
    });

    test('debug privacy', () {
      final d = const DentalSession(
        active: true,
        topic: DentalTopic.toothPain,
        matchedRuleIds: ['dental_ada_pain_definitive_care'],
      ).debugMap();
      expect(d.containsKey('personId'), isFalse);
      expect(d.values.contains('سني يوجعني'), isFalse);
    });

    test('catalog failure', () async {
      final bad = DentalGuidanceCoordinator(
        catalog: DentalRuleCatalog(rules: [
          DentalClinicalRule(
            ruleId: 'broken',
            topic: DentalTopic.toothPain,
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
      final r = await bad.handle(
        text: 'سني يوجعني',
        session: DentalSession.inactive,
      );
      expect(r.success, isFalse);
    });

    test('Smart Brain wires dental pack', () async {
      final planner = SmartBrainPlanner(
        doctorLookup: (_) async => <SmartSearchResult>[],
      );
      final c = ConversationContext();
      final plan = await planner.plan(query: 'سني يوجعني', context: c);
      expect(plan.message, isNotNull);
      expect(c.dentalSession.active, isTrue);
    });

    test('pregnant dental goes to dental not pregnancy-only', () async {
      final planner = SmartBrainPlanner(
        doctorLookup: (_) async => <SmartSearchResult>[],
      );
      final c = ConversationContext();
      await planner.plan(query: 'اني حامل وأسناني توجعني', context: c);
      expect(c.dentalSession.active, isTrue);
      expect(c.dentalSession.pregnancyContext, isTrue);
    });

    test('text-first / pack exists', () async {
      final r = await run('سني يوجعني');
      expect(r.textFirstOnly, isTrue);
      expect(Directory('lib/clinical_knowledge/packs/dental').existsSync(), isTrue);
    });

    test('destination dentist', () async {
      final r = await run('سني يوجعني وين أروح؟');
      expect(r.session.destinationType, ClinicalCareDestination.dentist);
    });

    test('abscess user-reported', () async {
      final r = await run('عندي خراج بالضرس');
      expect(r.session.userReportedAbscess, isTrue);
      expect(r.message.contains('ما أثبّته') || r.message.contains('بلاغ'),
          isTrue);
    });

    test('follow-up deferred', () async {
      final r = await run('سني يوجعني ذكرني بعد اسبوع');
      expect(r.deferToFollowUp, isTrue);
    });
  });
}
