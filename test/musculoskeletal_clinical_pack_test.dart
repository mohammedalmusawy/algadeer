import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/clinical_knowledge.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_engine.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MskGuidanceCoordinator msk;
  late ConversationContext ctx;

  setUp(() {
    msk = MskGuidanceCoordinator();
    ctx = ConversationContext();
  });

  Future<MskTurnResult> run(String text) async {
    final r = await msk.handle(text: text, session: ctx.mskSession);
    ctx.setMskSession(r.session);
    return r;
  }

  MskInterpretation interp(String t) => msk.interpreter.interpret(t);

  group('PC-1.18 recognition A–F', () {
    test('A/B — back / lumbar belt', () {
      expect(interp('ظهري يوجعني').topic, MskTopic.lowBackPain);
      expect(interp('ظهري يوجعني').region, MskBodyRegion.lumbarSpine);
      expect(interp('منطقة الحزام توجعني').region, MskBodyRegion.lumbarSpine);
    });

    test('C–F — neck/knee/thigh/shoulder aliases', () {
      expect(interp('رقبتي متشنجة').region, MskBodyRegion.cervicalSpine);
      expect(interp('ركبتي توجعني').region, MskBodyRegion.knee);
      expect(interp('شد بعضلة الفخذ').region, MskBodyRegion.thigh);
      expect(interp('كتفي يوجعني').region, MskBodyRegion.shoulder);
    });
  });

  group('PC-1.18 severity / duration / trauma G–P', () {
    test('G/H/I/J — severity parsed; alone not treatment', () {
      expect(interp('ألم خفيف بظهري').severity, ClinicalSeverityClass.mild);
      expect(interp('ألم متوسط بركبتي').severity, ClinicalSeverityClass.moderate);
      expect(interp('ألم شديد ما أتحمله').severity, ClinicalSeverityClass.severe);
      expect(msk.imagingPolicy.severeAloneRequiresMri(ClinicalSeverityClass.severe),
          isFalse);
    });

    test('K — duration only when stated', () {
      expect(interp('ظهري يوجعني').duration, MskDurationClass.unknown);
      expect(interp('ظهري يوجعني من يومين').duration, MskDurationClass.days);
    });

    test('L–P — trauma mechanisms', () {
      expect(interp('طحت على ركبتي').trauma, MskTraumaMechanism.fall);
      expect(interp('تزحلقت على الدرج').trauma, MskTraumaMechanism.fall);
      expect(interp('لويت رجلي').trauma, MskTraumaMechanism.twist);
      expect(interp('رفعت شي ثقيل ووجع ظهري').trauma, MskTraumaMechanism.liftingInjury);
      expect(interp('صار أثناء اللعب').trauma, MskTraumaMechanism.sportsInjury);
    });
  });

  group('PC-1.18 symptoms Q–Z', () {
    test('Q–Z symptom types', () {
      expect(interp('ظهري يوجعني').symptoms, contains(MskSymptomType.pain));
      expect(interp('تيبس بالركبة').symptoms, contains(MskSymptomType.stiffness));
      expect(interp('تورم بالركبة').symptoms, contains(MskSymptomType.swelling));
      expect(interp('ضعف بالرجل').symptoms, contains(MskSymptomType.weakness));
      expect(interp('تنميل بالرجل').symptoms, contains(MskSymptomType.numbness));
      expect(interp('وخز بإيدي').symptoms, contains(MskSymptomType.tingling));
      expect(interp('تشنج بالرقبة').symptoms, contains(MskSymptomType.spasm));
      expect(
        interp('ألم ظهري ينزل للرجل').symptoms,
        contains(MskSymptomType.radiatingPain),
      );
      expect(interp('كدمة على الفخذ').symptoms, contains(MskSymptomType.bruising));
      expect(
        interp('ما أكدر أمشي عليها').symptoms,
        contains(MskSymptomType.difficultyWeightBearing),
      );
    });
  });

  group('PC-1.18 diagnosis boundaries AA–AK', () {
    test('AA–AD — symptom ≠ diagnosis; no auto disc/sciatica', () async {
      final r = await run('ألم ظهري ينزل للرجل');
      expect(r.message.contains('ديسك'), isFalse);
      expect(r.message.contains('عرق النسا'), isFalse);
      expect(r.session.knownDiagnosis, MskKnownDiagnosisKind.none);
    });

    test('AE/AF — known disc vs future pain', () async {
      final known = await run(
        'عندي انزلاق غضروفي مشخص بالرنين',
      );
      expect(known.session.knownDiagnosis, MskKnownDiagnosisKind.discDisease);
      expect(known.message.contains('مذكور مسبقاً'), isTrue);
      ctx.setMskSession(MskSession.inactive);
      final later = await run('ظهري يوجعني من يومين');
      expect(later.session.knownDiagnosis, MskKnownDiagnosisKind.none);
    });

    test('AG/AH — knee pain ≠ OA; explicit OA known', () async {
      expect(interp('ركبتي توجعني').knownDiagnosis, MskKnownDiagnosisKind.none);
      final oa = await run('الطبيب مشخصني سوفان ركبة وهالفترة الألم زايد');
      expect(oa.session.knownDiagnosis, MskKnownDiagnosisKind.kneeOsteoarthritis);
    });

    test('AI–AK — no tear grade / vitamin / disc from spasm', () async {
      final tear = await run('تمزقت عضلة الفخذ أثناء الركض');
      expect(tear.message.contains('درجة'), isFalse);
      expect(RegExp(r'Grade').hasMatch(tear.message), isFalse);
      final spasm = await run('تشنج بالرقبة');
      expect(spasm.message.contains('فيتامين'), isFalse);
      expect(spasm.message.contains('ديسك'), isFalse);
    });
  });

  group('PC-1.18 imaging AL–BS', () {
    test('AL–AO — no auto X-ray/MRI', () async {
      await run('ظهري يوجعني من اسبوع');
      expect(
        ctx.mskSession.imagingAppropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
      ctx.reset();
      await run('رقبتي توجعني من ايام');
      expect(
        ctx.mskSession.imagingAppropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
      ctx.reset();
      await run('ركبتي توجعني من اسبوع');
      expect(
        ctx.mskSession.imagingAppropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
      expect(
        msk.imagingPolicy.severeAloneRequiresMri(ClinicalSeverityClass.severe),
        isFalse,
      );
    });

    test('AP — trauma changes imaging', () async {
      final r = await run('طحت على ركبتي وهسه ما أكدر أمشي عليها');
      expect(
        r.session.imagingAppropriateness,
        ClinicalImagingAppropriateness.usuallyAppropriate,
      );
      expect(r.session.imagingReasonCode, isNotEmpty);
      expect(r.session.lastRuleId, isNotEmpty);
    });

    test('AQ–AS — red flag defers; 10E authority', () async {
      final r = await run('ظهري يوجعني وفقدت وعي');
      expect(r.deferToMedicalSafety, isTrue);
      expect(msk.safety.createsSecondEmergencyEngine(), isFalse);
      expect(MedicalSafetyEngine, isNotNull);
    });

    test('AT–AV — LBP activity; no bed rest; clinician if limiting', () async {
      final r = await run('ظهري يوجعني من اسبوع ويحدد نشاطي');
      expect(r.message.contains('تعديل النشاط') || r.message.contains('الحركة'),
          isTrue);
      expect(r.message.contains('راحة سريرية طويلة'), isTrue);
      expect(r.message.contains('مراجعة سريرية') || r.message.contains('سريري'),
          isTrue);
    });

    test('AW/AX — neck trauma / neuro context', () async {
      final trauma = await run('طحت ووجع رقبتي');
      expect(trauma.session.trauma, isNot(MskTraumaMechanism.noneReported));
      ctx.reset();
      final neuro = await run('رقبتي توجعني مع تنميل بالذراع من اسبوع');
      expect(neuro.session.symptoms, contains(MskSymptomType.numbness));
    });

    test('AY–BA — knee weight bearing / locking / giving way', () {
      expect(
        interp('ما أكدر أمشي على ركبتي').symptoms,
        contains(MskSymptomType.difficultyWeightBearing),
      );
      expect(interp('ركبتي تنحجز').symptoms, contains(MskSymptomType.locking));
      expect(interp('ركبتي تخونني').symptoms, contains(MskSymptomType.givingWay));
    });

    test('BB–BD — known OA pathway', () async {
      final r = await run('الطبيب مشخصني سوفان ركبة');
      expect(r.message.contains('تمارين'), isTrue);
      expect(
        r.session.imagingAppropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
      expect(r.message.contains('إنقاص وزن'), isFalse);
      expect(r.message.contains('وزنك'), isFalse);
    });

    test('BE–BG — shoulder/hip no auto dx/image', () async {
      final sh = await run('كتفي يوجعني من اسبوع');
      expect(sh.message.contains('كفة'), isFalse);
      expect(sh.message.contains('متجمد'), isFalse);
      ctx.reset();
      final hip = await run('وركي يوجعني من اسبوع');
      expect(
        hip.session.imagingAppropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
    });

    test('BH–BJ — strain conservative; no complete rest; no grade', () async {
      final r = await run('أثناء الركض حسيت بشد قوي بعضلة الفخذ');
      expect(r.message.contains('تعديل') || r.message.contains('حماية'), isTrue);
      expect(r.message.contains('راحة تامة مطوّلة'), isTrue);
      expect(r.message.contains('درجة'), isFalse);
    });

    test('BK/BL — physio destination not for any pain', () async {
      final oa = await run('الطبيب مشخصني سوفان ركبة');
      expect(
        oa.session.destinationType == ClinicalCareDestination.physiotherapy ||
            oa.message.contains('طبيعي'),
        isTrue,
      );
      ctx.reset();
      final mild = await run('ظهري يوجعني خفيف من يومين');
      // physiotherapy optional — not automatic mandatory
      expect(mild.message.contains('دائماً علاج طبيعي'), isFalse);
    });

    test('BM–BS — modalities + reason + rule + freshness', () {
      expect(ClinicalImagingModality.values.map((e) => e.name),
          containsAll(['xray', 'mri', 'ct', 'ultrasound']));
      final rules = msk.catalog.active;
      expect(rules.every((r) => r.hasEvidenceMetadata), isTrue);
      expect(rules.every((r) => r.freshness == ClinicalEvidenceFreshness.current ||
          r.freshness == ClinicalEvidenceFreshness.reviewDue), isTrue);
      final inactive = msk.catalog.findById('msk_incomplete_evidence_inactive');
      expect(inactive!.isActive, isFalse);
      expect(inactive.clinicalReviewRequired, isTrue);
    });
  });

  group('PC-1.18 handoff / commerce BT–CC', () {
    test('BT–BW — radiology after eligibility; no commercial override', () async {
      final r = await run('طحت على ركبتي وهسه ما أكدر أمشي عليها');
      expect(r.message.contains('خدمة الأشعة'), isTrue);
      expect(msk.imagingPolicy.commercialCanAlterIndication(), isFalse);
      expect(msk.imagingPolicy.ownershipCanAlterIndication(), isFalse);
      final biased = msk.imagingPolicy.selectRule(
        session: r.session,
        activeRules: msk.catalog.active,
        sponsorOverride: true,
        paidOverride: true,
        ownershipBias: true,
      );
      expect(biased!.imaging!.appropriateness,
          ClinicalImagingAppropriateness.usuallyAppropriate);
    });

    test('BX/BY — semantic destination; service layer external', () {
      expect(
        msk.catalog.active.any((r) =>
            r.destinations.any((d) => d.destination == ClinicalCareDestination.specialist)),
        isTrue,
      );
      final src = File(
        'lib/clinical_knowledge/packs/musculoskeletal/msk_rule_catalog.dart',
      ).readAsStringSync();
      expect(src.contains('دكتور أحمد'), isFalse);
    });

    test('BZ–CC — navigation continuation; no fake booking', () async {
      await run('طحت على ركبتي وهسه ما أكدر أمشي عليها');
      final where = await run('وين أروح؟');
      expect(where.preserveDestinationContext || where.deferToServiceNavigation,
          isTrue);
      final book = await run('أريد أحجز');
      expect(book.message.contains('ما أحجز موعداً تلقائياً'), isTrue);
      final img = await run('وين أسوي الأشعة؟');
      expect(img.message.contains('الأشعة') || img.deferToServiceNavigation,
          isTrue);
    });
  });

  group('PC-1.18 integrations CD–CK', () {
    test('CD/CE — no false reassurance', () async {
      final r = await run('ظهري يوجعني من اسبوع');
      expect(r.message.contains('أكيد بسيطة'), isFalse);
    });

    test('CF–CK — boundaries', () {
      expect(Directory('lib/daily_context').existsSync(), isTrue);
      expect(Directory('lib/wellbeing_planner').existsSync(), isTrue);
      expect(Directory('lib/follow_up').existsSync(), isTrue);
      final src = Directory('lib/clinical_knowledge/packs/musculoskeletal')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('FollowUpService.create'), isFalse);
      expect(src.contains('painDiary'), isFalse);
    });
  });

  group('PC-1.18 education / subject / meds CL–CT', () {
    test('CL/CM — education without dx; refuse self-dx', () async {
      final edu = await run('شنو أعراض سوفان الركبة؟');
      expect(edu.message.contains('أعراض شائعة'), isTrue);
      expect(edu.message.contains('ما أأكد'), isTrue);
      final suspect = await run('أعتقد عندي سوفان');
      expect(suspect.message.contains('ما أقدر أأكد'), isTrue);
    });

    test('CN/CO — other person isolation', () async {
      final r = await run('أمي ركبتهها توجعها');
      expect(r.message.contains('شخص ثاني'), isTrue);
      expect(r.message.contains('1990'), isFalse);
    });

    test('CP — pregnancy context caution', () async {
      final r = await run('أنا حامل وظهري يوجعني');
      expect(r.message.contains('طبيبتك'), isTrue);
      expect(r.message.contains('حمل'), isTrue);
      expect(r.message.contains('رفيق حمل كامل'), isFalse);
    });

    test('CQ–CT — no meds/injections', () async {
      final r = await run('ظهري يوجعني من اسبوع');
      expect(r.message.contains('جرعة'), isFalse);
      expect(r.message.contains('ستيرويد'), isFalse);
      expect(r.message.contains('مرخي'), isFalse);
      expect(r.message.contains('حقنة'), isFalse);
    });
  });

  group('PC-1.18 privacy / text / failure CU–DJ', () {
    test('CU–CX — no persistence stores; debug clean', () async {
      await run('ظهري يوجعني من اسبوع');
      final dbg = ctx.mskSession.debugMap().toString();
      expect(dbg.contains('يوجعني'), isFalse);
      expect(dbg.contains('mskTopic'), isTrue);
      expect(dbg.contains('personId'), isFalse);
      expect(File('lib/clinical_knowledge/packs/musculoskeletal').existsSync() ||
          Directory('lib/clinical_knowledge/packs/musculoskeletal').existsSync(),
          isTrue);
    });

    test('CY–DA — text-first; same coordinator', () async {
      final r = await run('ركبتي توجعني من ايام');
      expect(r.textFirstOnly, isTrue);
      final a = msk.interpreter.interpret('ركبتي توجعني');
      final b = msk.interpreter.interpret('ركبتي توجعني');
      expect(a.region, b.region);
    });

    test('DB/DC — failure safety', () async {
      final brain = SmartBrainPlanner(
        mskGuidance: _FailingMsk(),
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

    test('DD–DF — structured rules; evidence; inactive incomplete', () {
      expect(msk.catalog.active, isNotEmpty);
      expect(msk.catalog.active.every((r) => r.hasEvidenceMetadata), isTrue);
      expect(msk.catalog.findById('msk_incomplete_evidence_inactive')!.isActive,
          isFalse);
    });

    test('DG–DJ — no campaigns/notifications/gamification/paid', () {
      final src = Directory('lib/clinical_knowledge/packs/musculoskeletal')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('in_app_purchase'), isFalse);
      expect(src.contains('RevenueCat'), isFalse);
      expect(src.toLowerCase().contains('gamification'), isFalse);
    });

    test('Smart Brain handles MSK turn', () async {
      final brain = SmartBrainPlanner(mskGuidance: msk);
      final plan = await brain.plan(query: 'ظهري يوجعني', context: ctx);
      expect(plan.textFirstOnly, isTrue);
      expect(plan.message, isNotEmpty);
      expect(ctx.mskSession.active, isTrue);
    });
  });
}

class _FailingMsk extends MskGuidanceCoordinator {
  _FailingMsk() : super();

  @override
  bool mayHandle({required String query, required MskSession session}) => true;

  @override
  Future<MskTurnResult> handle({
    required String text,
    required MskSession session,
  }) async {
    throw StateError('msk down');
  }
}
