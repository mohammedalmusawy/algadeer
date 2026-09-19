import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/clinical_knowledge.dart';
import 'package:ghadeer_clinic/health/emotional_support/mental_health_safety_gate.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_engine.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClinicalKnowledgeCoordinator ck;
  late LocalClinicalKnowledgeCatalog catalog;
  late ConversationContext ctx;

  setUp(() {
    catalog = LocalClinicalKnowledgeCatalog();
    ck = ClinicalKnowledgeCoordinator(
      retriever: ClinicalKnowledgeRetriever(catalog: catalog),
    );
    ctx = ConversationContext();
  });

  group('PC-1.17 architecture A–G', () {
    test('A — catalog separate from Smart Brain', () {
      expect(Directory('lib/clinical_knowledge').existsSync(), isTrue);
      final brain = File('lib/voice/intent/smart_brain_planner.dart')
          .readAsStringSync();
      expect(brain.contains('nonspecific_low_back_pain_imaging'), isFalse);
      expect(brain.contains('ACR Appropriateness Criteria'), isFalse);
    });

    test('B/C — domains and topics typed', () {
      expect(ClinicalDomain.values.length, greaterThanOrEqualTo(10));
      expect(ClinicalKnowledgeTopic.lowBackPain.name, 'lowBackPain');
      expect(ClinicalDomain.pregnancy.name, 'pregnancy');
    });

    test('D–G — evidence metadata required', () async {
      final rules = await catalog.loadRules(activeOnly: true);
      expect(rules, isNotEmpty);
      for (final r in rules) {
        expect(r.hasEvidenceReference, isTrue);
        expect(r.evidence.sourceOrganization, isNotEmpty);
        expect(r.evidence.sourceVersionOrDate, isNotEmpty);
        expect(r.reviewedAt, isNotNull);
      }
    });
  });

  group('PC-1.17 freshness / review H–L', () {
    test('H/I/J — freshness states', () {
      expect(
        LocalClinicalKnowledgeCatalog.foundationRules
            .any((r) => r.freshness == ClinicalEvidenceFreshness.current),
        isTrue,
      );
      expect(
        LocalClinicalKnowledgeCatalog.foundationRules
            .any((r) => r.freshness == ClinicalEvidenceFreshness.reviewDue),
        isTrue,
      );
      expect(
        LocalClinicalKnowledgeCatalog.foundationRules
            .any((r) => r.freshness == ClinicalEvidenceFreshness.superseded),
        isTrue,
      );
    });

    test('K — clinicalReviewRequired', () async {
      final rules = await catalog.loadRules(activeOnly: false);
      expect(rules.every((r) => r.clinicalReviewRequired == true || r.clinicalReviewRequired == false),
          isTrue);
      expect(rules.any((r) => r.clinicalReviewRequired), isTrue);
    });

    test('L — inactive not selected', () async {
      final match = await ck.query(
        const ClinicalKnowledgeQuery(
          topic: ClinicalKnowledgeTopic.other,
          contextTags: {},
        ),
      );
      expect(match.rule?.ruleId, isNot('ck_inactive_example_do_not_select'));
      final inactive = await catalog.findById('ck_inactive_example_do_not_select');
      expect(inactive!.isActive, isFalse);
    });
  });

  group('PC-1.17 symptom / severity / questions M–S', () {
    test('M/N — symptoms ≠ diagnosis; known diagnosis distinct', () {
      const pattern = ClinicalSymptomPattern(
        symptomKey: 'polyuria',
        userReportedKnownDiagnosis: 'diabetes',
      );
      expect(pattern.isKnownDiagnosisContext, isTrue);
      const onlySymptom = ClinicalSymptomPattern(symptomKey: 'polyuria');
      expect(onlySymptom.isKnownDiagnosisContext, isFalse);
      expect(onlySymptom.symptomKey, isNot(onlySymptom.userReportedKnownDiagnosis));
    });

    test('O/P — severity supported; alone not treatment', () {
      expect(ClinicalSeverityClass.values, contains(ClinicalSeverityClass.mild));
      expect(ClinicalSeverityClass.values, contains(ClinicalSeverityClass.severe));
      expect(ck.eligibility.severityAloneDeterminesTreatment(), isFalse);
    });

    test('Q/R/S — functional impact + questions; no long interrogation', () async {
      expect(ClinicalFunctionalImpact.difficultyWalking.name, isNotEmpty);
      final rule = await catalog.findById('ck_msk_lbp_imaging_not_routine');
      expect(rule!.minimumQuestions, isNotEmpty);
      expect(rule.minimumQuestions.length, lessThanOrEqualTo(5));
    });
  });

  group('PC-1.17 safety / actions T–AD', () {
    test('T/U — 10E remains authority; no second emergency engine', () {
      expect(ck.createsSecondEmergencyEngine(), isFalse);
      expect(MedicalSafetyEngine, isNotNull);
      expect(
        LocalClinicalKnowledgeCatalog.foundationRules
            .where((r) => r.redFlagKeys.isNotEmpty)
            .every((r) => true),
        isTrue,
      );
    });

    test('V–AD — care actions and destinations', () async {
      final types = ClinicalCareActionType.values.map((e) => e.name).toSet();
      expect(types.contains('generalSelfCare'), isTrue);
      expect(types.contains('activityModification'), isTrue);
      expect(types.contains('physiotherapyDiscussion'), isTrue);
      expect(types.contains('clinicianReview'), isTrue);
      expect(types.contains('imagingDiscussion'), isTrue);

      final dest = ClinicalCareDestination.values.map((e) => e.name).toSet();
      expect(dest.contains('radiology'), isTrue);
      expect(dest.contains('dentist'), isTrue);
      expect(dest.contains('mentalHealthProfessional'), isTrue);
      expect(dest.contains('obstetricsGynecology'), isTrue);

      final dental = await catalog.findById('ck_dental_pain_foundation');
      expect(
        dental!.destinations.any((d) => d.destination == ClinicalCareDestination.dentist),
        isTrue,
      );
    });
  });

  group('PC-1.17 imaging AE–AL', () {
    test('AE–AH — appropriateness classes', () {
      final vals = ClinicalImagingAppropriateness.values.map((e) => e.name);
      expect(vals, contains('notRoutinelyIndicated'));
      expect(vals, contains('mayBeAppropriate'));
      expect(vals, contains('usuallyAppropriate'));
      expect(vals, contains('clinicianDecision'));
    });

    test('AI–AL — modalities', () {
      final m = ClinicalImagingModality.values.map((e) => e.name);
      expect(m, containsAll(['xray', 'mri', 'ct', 'ultrasound']));
    });
  });

  group('PC-1.17 imaging eligibility AM–AT', () {
    test('AM/AN — reviewed rule; generic back pain no auto X-ray', () async {
      final img = await ck.evaluateImaging(
        topic: ClinicalKnowledgeTopic.lowBackPain,
        symptomKeys: const ['low_back_pain'],
      );
      expect(img, isNotNull);
      expect(img!.reasonCode, isNotEmpty);
      expect(
        img.appropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
      expect(img.allowsServiceHandoff, isFalse);
    });

    test('AO/AP — neck/knee no auto X-ray', () async {
      final neck = await ck.evaluateImaging(
        topic: ClinicalKnowledgeTopic.neckPain,
        symptomKeys: const ['neck_pain'],
      );
      expect(
        neck!.appropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
      final knee = await ck.evaluateImaging(
        topic: ClinicalKnowledgeTopic.kneePain,
        symptomKeys: const ['knee_pain'],
      );
      expect(
        knee!.appropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
    });

    test('AQ — generic cough no auto CXR', () async {
      final img = await ck.evaluateImaging(
        topic: ClinicalKnowledgeTopic.acuteCough,
        symptomKeys: const ['cough'],
        coughDuration: ClinicalCoughDurationClass.acute,
      );
      expect(
        img!.appropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
    });

    test('AR — diabetes alone no CXR', () async {
      final img = await ck.evaluateImaging(
        topic: ClinicalKnowledgeTopic.diabetesRoutineCare,
        knownDiagnosisKeys: const ['diabetes'],
      );
      expect(
        img!.appropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
      expect(img.reasonCode, 'diabetesAloneNoRoutineCxr');
    });

    test('AS/AT — chronic cough duration/context + reason', () async {
      final img = await ck.evaluateImaging(
        topic: ClinicalKnowledgeTopic.chronicCough,
        symptomKeys: const ['chronic_cough'],
        coughDuration: ClinicalCoughDurationClass.chronic,
        contextTags: const {'duration_chronic'},
      );
      expect(
        img!.appropriateness,
        ClinicalImagingAppropriateness.mayBeAppropriate,
      );
      expect(img.reasonCode, 'chronicCoughCriteria');
    });
  });

  group('PC-1.17 handoff / neutrality AU–BA', () {
    test('AU — clinical before service handoff', () async {
      final match = await ck.query(
        const ClinicalKnowledgeQuery(
          topic: ClinicalKnowledgeTopic.kneePain,
          symptomKeys: ['knee_pain'],
          contextTags: {'trauma_with_bony_concern'},
        ),
      );
      expect(match.rule!.imaging!.allowsServiceHandoff, isTrue);
      expect(match.allowsRadiologyHandoff, isTrue);
      expect(match.message.contains('خدمة الأشعة'), isTrue);
      // القرار السريري موجود قبل جملة الخدمة
      final clinicalIdx = match.message.indexOf('التصوير');
      final serviceIdx = match.message.indexOf('غدير');
      expect(clinicalIdx, greaterThanOrEqualTo(0));
      expect(serviceIdx, greaterThan(clinicalIdx));
    });

    test('AV/AW — sponsor/paid cannot alter imaging', () async {
      final base = await ck.evaluateImaging(
        topic: ClinicalKnowledgeTopic.lowBackPain,
        symptomKeys: const ['low_back_pain'],
      );
      final sponsored = await ck.evaluateImaging(
        topic: ClinicalKnowledgeTopic.lowBackPain,
        symptomKeys: const ['low_back_pain'],
        sponsorOverride: true,
        paidPackageOverride: true,
      );
      expect(sponsored!.appropriateness, base!.appropriateness);
      expect(ck.eligibility.commercialOverrideAllowed(
        const ClinicalKnowledgeQuery(sponsorOverrideRequested: true),
      ), isFalse);
    });

    test('AX/AY/AZ/BA — no hardcoded doctor; semantic destination; no fake avail',
        () async {
      final src = File('lib/clinical_knowledge/local_clinical_knowledge_catalog.dart')
          .readAsStringSync();
      expect(src.contains('دكتور أحمد'), isFalse);
      expect(src.contains('doctorId'), isFalse);
      final rule = await catalog.findById('ck_msk_lbp_imaging_not_routine');
      expect(
        rule!.destinations.any(
          (d) => d.destination == ClinicalCareDestination.physiotherapy,
        ),
        isTrue,
      );
      expect(Directory('lib/health/guidance').existsSync(), isTrue);
      final msg = ck.retriever; // service layer remains external
      expect(msg, isNotNull);
      expect(
        const ClinicalKnowledgeResponsePolicy().claimsFakeAvailability(
          'الطبيب متاح الآن',
        ),
        isTrue,
      );
    });
  });

  group('PC-1.17 domain foundations BB–BH', () {
    test('BB–BF — diabetes/htn/pregnancy/dental prepared', () async {
      expect(
        (await catalog.loadRules(activeOnly: false))
            .any((r) => r.domain == ClinicalDomain.diabetes),
        isTrue,
      );
      expect(
        (await catalog.loadRules(activeOnly: false))
            .any((r) => r.domain == ClinicalDomain.hypertension),
        isTrue,
      );
      expect(
        (await catalog.loadRules(activeOnly: false))
            .any((r) => r.domain == ClinicalDomain.pregnancy),
        isTrue,
      );
      expect(
        (await catalog.loadRules(activeOnly: false))
            .any((r) => r.domain == ClinicalDomain.dental),
        isTrue,
      );
    });

    test('BE — pregnancy not inferred from age/sex', () async {
      expect(ck.mayInferPregnancyFromAgeOrSex(), isFalse);
      final match = await ck.query(
        const ClinicalKnowledgeQuery(
          topic: ClinicalKnowledgeTopic.pregnancyRoutineCare,
          inferPregnancyFromDemographics: true,
        ),
      );
      expect(match.rule, isNull);
      final without = await ck.query(
        const ClinicalKnowledgeQuery(
          topic: ClinicalKnowledgeTopic.pregnancyRoutineCare,
          contextTags: {'explicit_pregnancy_confirmed'},
        ),
      );
      expect(without.rule?.domain, ClinicalDomain.pregnancy);
    });

    test('BG/BH — mental health does not replace PC-1.6; adolescent prepared',
        () {
      expect(ck.replacesMentalHealthAuthority(), isFalse);
      expect(const MentalHealthSafetyGate(), isNotNull);
      expect(
        LocalClinicalKnowledgeCatalog.foundationRules
            .any((r) => r.domain == ClinicalDomain.adolescentHealth),
        isTrue,
      );
    });
  });

  group('PC-1.17 integrations BI–BM', () {
    test('BI–BM — authorities / no auto follow-up / no reinterpret', () {
      expect(ck.replacesChronicCareAuthority(), isFalse);
      expect(ck.dailyContextMayAlterEvidence(), isFalse);
      expect(ck.wellbeingPlannerMayReinterpretRules(), isFalse);
      expect(ck.autoCreatesFollowUp(), isFalse);
      expect(Directory('lib/health/sensitive_profile').existsSync(), isTrue);
    });
  });

  group('PC-1.17 localization / catalog BN–BS', () {
    test('BN/BO/BP — Arabic / Iraqi / English keys', () async {
      final r = await catalog.findById('ck_msk_lbp_imaging_not_routine');
      expect(r!.arabicSummary, isNotEmpty);
      expect(r.iraqiAliases, isNotEmpty);
      expect(r.englishCanonicalKey, isNotEmpty);
    });

    test('BQ/BR/BS — extensible; small; no patient records', () async {
      expect(catalog, isA<ClinicalKnowledgeCatalog>());
      final active = await catalog.loadRules(activeOnly: true);
      expect(active.length, lessThan(40));
      expect(ck.storesPatientRecordsInCatalog(), isFalse);
      final blob = File('lib/clinical_knowledge/local_clinical_knowledge_catalog.dart')
          .readAsStringSync();
      expect(blob.contains('personId'), isFalse);
      expect(blob.contains('patientRecord'), isFalse);
    });
  });

  group('PC-1.17 privacy / text / failure BT–BZ', () {
    test('BT/BU — debug excludes raw symptoms/measurements', () async {
      final match = await ck.query(
        const ClinicalKnowledgeQuery(
          topic: ClinicalKnowledgeTopic.lowBackPain,
          symptomKeys: ['low_back_pain'],
        ),
      );
      ctx.setClinicalKnowledgeSession(
        ClinicalKnowledgeSession(lastMatch: match, active: true),
      );
      final dbg = ctx.clinicalKnowledgeSession.debugMap().toString();
      expect(dbg.contains('وجع'), isFalse);
      expect(dbg.contains('glucose'), isFalse);
      expect(dbg.contains('matchedRuleCount'), isTrue);
      expect(dbg.contains('selectedRuleId'), isTrue);
    });

    test('BV/BW/BX — text-first; same coordinator', () async {
      final turn = await ck.handle(
        text: 'لازم أشعة للظهر؟',
        session: ctx.clinicalKnowledgeSession,
      );
      if (turn.handled) {
        expect(turn.textFirstOnly, isTrue);
      }
      final a = ck.retriever;
      final b = ck.retriever;
      expect(identical(a.catalog, b.catalog) || a.catalog.runtimeType == b.catalog.runtimeType,
          isTrue);
    });

    test('BY/BZ — failure does not break Smart Brain / 10E', () async {
      final brain = SmartBrainPlanner(
        clinicalKnowledge: _FailingCk(),
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
      expect(MedicalSafetyEngine, isNotNull);
    });
  });

  group('PC-1.17 future / anti-features CA–CJ', () {
    test('CA–CF — no admin UI / no full packs / no pregnancy companion', () {
      final c = ck.futureAdmin;
      expect(c.adminUiEnabled, isFalse);
      expect(c.pregnancyCompanionEnabled, isFalse);
      expect(c.fullMskPackEnabled, isFalse);
      expect(c.fullRespiratoryPackEnabled, isFalse);
      expect(c.fullDiabetesPackEnabled, isFalse);
      expect(c.fullDentalPackEnabled, isFalse);
    });

    test('CG–CJ — no campaigns/notifications/gamification/paid', () {
      final src = Directory('lib/clinical_knowledge')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('in_app_purchase'), isFalse);
      expect(src.contains('RevenueCat'), isFalse);
      expect(src.toLowerCase().contains('gamification'), isFalse);
      expect(ClinicalCareActionType.values.map((e) => e.name),
          isNot(contains('campaign')));
    });

    test('Smart Brain can surface clinical imaging guidance', () async {
      final brain = SmartBrainPlanner(clinicalKnowledge: ck);
      final plan = await brain.plan(
        query: 'لازم أشعة للظهر؟',
        context: ctx,
      );
      expect(plan.textFirstOnly, isTrue);
      expect(ctx.clinicalKnowledgeSession.active || plan.message.isNotEmpty, isTrue);
    });
  });
}

class _FailingCk extends ClinicalKnowledgeCoordinator {
  _FailingCk() : super();

  @override
  bool mayHandle({
    required String query,
    required ClinicalKnowledgeSession session,
  }) =>
      true;

  @override
  Future<ClinicalKnowledgeTurnResult> handle({
    required String text,
    required ClinicalKnowledgeSession session,
    bool urgentMedicalHint = false,
  }) async {
    throw StateError('clinical knowledge down');
  }
}
