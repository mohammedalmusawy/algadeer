import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/clinical_knowledge.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_engine.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChronicClinicalCoordinator cc;
  late ConversationContext ctx;

  setUp(() {
    cc = ChronicClinicalCoordinator();
    ctx = ConversationContext();
  });

  Future<ChronicClinicalTurnResult> run(String text) async {
    final r = await cc.handle(text: text, session: ctx.chronicClinicalSession);
    ctx.setChronicClinicalSession(r.session);
    return r;
  }

  ChronicClinicalInterpretation interp(String t) =>
      cc.interpreter.interpret(t);

  group('PC-1.20 recognition A–K', () {
    test('A–D — diabetes status boundaries', () {
      expect(
        interp('عندي سكري مشخص والطبيب مشخصني').diabetesStatus,
        ChronicConditionStatus.established,
      );
      expect(
        interp('أعتقد عندي سكري').diabetesStatus,
        ChronicConditionStatus.suspected,
      );
      expect(
        interp('طلع السكر 240 مرة').diabetesStatus,
        ChronicConditionStatus.singleAbnormalMeasurement,
      );
      expect(
        interp('أبويه عنده سكري').diabetesStatus,
        ChronicConditionStatus.familyHistoryOnly,
      );
    });

    test('E–H — diabetes type / insulin / gestational', () {
      expect(interp('سكري نوع أول مشخص').diabetesType, DiabetesTypeContext.type1);
      expect(interp('سكري نوع ثاني مشخص').diabetesType, DiabetesTypeContext.type2);
      expect(cc.diabetesPolicy.insulinInfersType1(), isFalse);
      expect(
        interp('عندي سكري حمل').diabetesType,
        DiabetesTypeContext.gestational,
      );
    });

    test('I–K — hypertension status / family', () {
      expect(
        interp('عندي ضغط مشخص من الطبيب').hypertensionStatus,
        ChronicConditionStatus.established,
      );
      expect(
        interp('ضغطي اليوم 150/95').hypertensionStatus,
        ChronicConditionStatus.singleAbnormalMeasurement,
      );
      expect(
        interp('ضغط أمي 170/100').isAboutOtherPerson,
        isTrue,
      );
    });
  });

  group('PC-1.20 measurements L–W', () {
    test('L–N — BP parse/correct', () {
      final a = interp('ضغطي 150 على 95');
      expect(a.systolic, 150);
      expect(a.diastolic, 95);
      final b = interp('الضغط 150/95');
      expect(b.systolic, 150);
      expect(b.diastolic, 95);
    });

    test('O–S — glucose / HbA1c context', () {
      final g = interp('السكر 180');
      expect(g.glucoseValue, 180);
      expect(g.isFasting, isFalse);
      expect(interp('السكر 180 صايم').isFasting, isTrue);
      expect(interp('السكر 180 بعد الأكل').isPostMeal, isTrue);
      expect(interp('التراكمي 7.2').hba1cValue, 7.2);
      expect(interp('التراكمي 7.2').measurementKind, ChronicMeasurementKind.hba1c);
    });

    test('T–W — units / no false control/trend', () async {
      expect(interp('7.2').isChronicClinicalTurn, isFalse);
      final r = await run('السكر 110');
      expect(r.message.contains('مضبوط تماما'), isFalse);
      expect(r.message.contains('يرتفع'), isFalse);
      expect(cc.queryAdapter.createsMeasurementStore(), isFalse);
    });
  });

  group('PC-1.20 safety X–AH', () {
    test('X–AB — PC-1.5 / 10E / no second engines', () {
      expect(cc.queryAdapter.isReadOnly, isTrue);
      expect(cc.queryAdapter.createsConditionStore(), isFalse);
      expect(cc.queryAdapter.createsFollowUpStore(), isFalse);
      expect(cc.queryAdapter.mutatesChronicCareStore(), isFalse);
      expect(MedicalSafetyEngine, isNotNull);
      expect(cc.safety.createsDiabetesEmergencyEngine(), isFalse);
      expect(cc.safety.createsHypertensionEmergencyEngine(), isFalse);
    });

    test('AC–AH — BP/glucose safety boundaries', () async {
      final mild = await run('ضغطي 150/95');
      expect(mild.deferToMedicalSafety, isFalse);
      ctx.reset();
      final danger = await run('ضغطي 190 مع ألم صدر');
      expect(danger.deferToMedicalSafety, isTrue);
      ctx.reset();
      final meta = await run('سكر عالي مع استفراغ مستمر وفقدان وعي');
      expect(meta.deferToMedicalSafety || meta.session.redFlagCandidate, isTrue);
      expect(interp('دوخة').redFlagCandidate, isFalse);
    });
  });

  group('PC-1.20 BP technique AI–AK', () {
    test('AI–AK — recheck / technique / cuffless', () async {
      final r = await run('ضغطي 150/95');
      expect(r.message.contains('إعادة') || r.message.contains('أعد') || r.message.contains('اعد'), isTrue);
      ctx.reset();
      final tech = await run('شلون أقيس الضغط صح؟');
      expect(tech.message.contains('كفة') || tech.message.contains('عضد'), isTrue);
      final cuff = await run('الساعة كالت ضغطي 140');
      expect(cuff.message.contains('كفة') || cuff.message.contains('مكافئ'), isTrue);
      expect(cc.hypertensionPolicy.cufflessEqualsValidatedCuff(), isFalse);
    });
  });

  group('PC-1.20 care items AL–BQ', () {
    test('AL–AO — typed items / unknown ≠ overdue', () {
      expect(DiabetesCareItem.values.length, greaterThan(5));
      expect(HypertensionCareItem.values.length, greaterThan(5));
      expect(
        cc.duePolicy.statusFor(
          careItemId: 'eye',
          recentlyCompleted: false,
          dateKnown: false,
          evidenceSupportsDue: true,
          needsClinician: false,
        ),
        CareItemStatus.unknown,
      );
    });

    test('AP–AT — completed eye / due from evidence', () async {
      await run('عندي سكري مشخص');
      await run('فحصت عيوني قبل شهر');
      final left = await run('شنو باقي علي؟');
      expect(
        left.session.assembledPriorities.any((p) =>
            p.id == DiabetesCareItem.eyeAssessment.name &&
            p.status == CareItemStatus.recentlyCompleted),
        isFalse,
      );
      // لا يُعاد اقتراح العين فوراً ضمن أولويات غير المكتملة
      expect(
        left.message.contains('فحص العين — مستحق') ||
            left.message.contains('فحص العين — متأخر'),
        isFalse,
      );
      expect(DiabetesRuleCatalog.hba1cStableIntervalMonths, greaterThan(0));
      final interpSrc = File(
        'lib/clinical_knowledge/packs/chronic_care/chronic_care_interpreter.dart',
      ).readAsStringSync();
      expect(interpSrc.contains('type1KidneyScreenMinYears'), isFalse);
      expect(interpSrc.contains('hba1cStableIntervalMonths'), isFalse);
    });

    test('AU–BF — A1c/kidney boundaries', () {
      expect(cc.diabetesPolicy.universalPersonalA1cTarget(), isFalse);
      expect(
        cc.diabetesRules.forCareItem(DiabetesCareItem.kidneyAssessment)!
            .arabicGuidance
            .contains('UACR'),
        isTrue,
      );
      expect(
        cc.diabetesRules
            .forCareItem(DiabetesCareItem.kidneyAssessment)!
            .arabicGuidance
            .contains('eGFR'),
        isTrue,
      );
      expect(
        cc.duePolicy.type1KidneyEligible(
          type: DiabetesTypeContext.type1,
          durationYearsKnown: null,
        ),
        isFalse,
      );
      expect(
        cc.duePolicy.type1KidneyEligible(
          type: DiabetesTypeContext.type2,
          durationYearsKnown: null,
        ),
        isTrue,
      );
      expect(cc.diabetesPolicy.numbnessDiagnosesNeuropathy(), isFalse);
    });

    test('BG–BQ — eye/foot/cv', () async {
      expect(
        cc.destinations.forCareItem(DiabetesCareItem.eyeAssessment.name),
        ClinicalCareDestination.specialist,
      );
      expect(cc.diabetesPolicy.footWoundAutoXray(), isFalse);
      expect(cc.diabetesPolicy.inventsAscvdPercent(), isFalse);
      expect(cc.diabetesPolicy.initiatesStatin(), isFalse);
      final wound = await run('عندي سكري مشخص وجرح بالقدم');
      expect(
        wound.session.assembledPriorities.any((p) =>
            p.id == DiabetesCareItem.footAssessment.name ||
            p.status == CareItemStatus.needsClinicianReview),
        isTrue,
      );
    });
  });

  group('PC-1.20 hypertension CA–CE', () {
    test('CA–CE — thresholds in catalog / combined', () async {
      expect(cc.hypertensionPolicy.thresholdsLiveInCatalogOnly(), isTrue);
      final plannerSrc = File(
        'lib/voice/intent/smart_brain_planner.dart',
      ).readAsStringSync();
      expect(plannerSrc.contains('systolicElevated = 130'), isFalse);
      expect(cc.hypertensionPolicy.universalPersonalBpTarget(), isFalse);
      await run('عندي سكري مشخص');
      await run('عندي ضغط مشخص من الطبيب');
      final r = await run('شنو باقي علي؟');
      expect(r.message.contains('سكري') || r.message.contains('ضغط'), isTrue);
      // lifestyle مرة واحدة تقريباً
      expect(
        'نمط حياة'.allMatches(r.message).length,
        lessThanOrEqualTo(2),
      );
    });
  });

  group('PC-1.20 assembler CF–CL', () {
    test('CF–CL — priorities / whats left / why kidney', () async {
      await run('عندي سكري مشخص');
      final direct = cc.assembler.assemble(
        session: ctx.chronicClinicalSession.copyWith(
          diabetesStatus: ChronicConditionStatus.established,
        ),
        diabetesRules: cc.diabetesRules,
        htnRules: cc.hypertensionRules,
        fullChecklist: true,
      );
      expect(direct.length, greaterThanOrEqualTo(4));
      final r = await run('سويلي قائمة متابعة للسكري');
      expect(r.message.contains('تراكمي') || r.message.contains('الكلى'), isTrue);
      ctx.reset();
      await run('عندي سكري مشخص');
      final short = await run('شنو باقي علي؟');
      expect(short.session.assembledPriorities.length, lessThanOrEqualTo(3));
      final why = await run('ليش فحص الكلى؟');
      expect(why.message.contains('UACR') || why.message.contains('الكلى'), isTrue);
      expect(why.message.contains('تخويف') || why.message.contains('سرطان'), isFalse);
    });
  });

  group('PC-1.20 persistence / packs CM–DR', () {
    test('CM–CP — no new stores; PC-1.5 preserved', () {
      final src = Directory('lib/clinical_knowledge/packs/chronic_care')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('DiabetesCareHistoryStore'), isFalse);
      expect(src.contains('LabHistoryStore'), isFalse);
      expect(Directory('lib/health/chronic_care').existsSync(), isTrue);
    });

    test('CQ–CT — no auto follow-up / fake schedule', () async {
      final r = await run('التراكمي صار موعده');
      expect(r.deferToFollowUp, isFalse);
      final fu = await run('تابع وياي التراكمي');
      expect(fu.deferToFollowUp, isTrue);
      expect(fu.message.contains('جدولة التذكير'), isFalse);
    });

    test('CU–CZ — lifestyle boundaries', () async {
      final r = await run('عندي سكري مشخص');
      expect(r.message.contains('وزنك زايد') || r.message.contains('اسمن'), isFalse);
      expect(r.message.contains('مكمل'), isFalse);
      expect(r.message.contains('ممنوع الرز'), isFalse);
    });

    test('DA–DG — no med titration', () {
      expect(cc.diabetesPolicy.adjustsInsulinDose(), isFalse);
      expect(cc.hypertensionPolicy.adjustsAntihypertensiveDose(), isFalse);
      expect(cc.diabetesPolicy.initiatesStatin(), isFalse);
    });

    test('DH–DN — lab/commercial neutrality', () {
      expect(cc.duePolicy.commercialCanAlterEligibility(), isFalse);
      expect(cc.duePolicy.packageCanCreateMedicalNeed(), isFalse);
      expect(cc.duePolicy.sponsorCanAlterEligibility(), isFalse);
      expect(cc.duePolicy.discountCanAlterFrequency(), isFalse);
      expect(cc.destinations.hardcodesPackageIds(), isFalse);
      expect(cc.destinations.hardcodesProviderNames(), isFalse);
    });

    test('DO–DR — radiology / cross-pack', () async {
      expect(cc.diabetesPolicy.diabetesAloneChestXray(), isFalse);
      expect(cc.hypertensionPolicy.hypertensionAloneChestXray(), isFalse);
      final planner = SmartBrainPlanner(
        doctorLookup: (_) async => <SmartSearchResult>[],
      );
      final c = ConversationContext();
      await planner.plan(query: 'عندي سكري مشخص', context: c);
      final cough = await planner.plan(query: 'عندي سعال', context: c);
      expect(c.respiratorySession.active || cough.message.contains('سعال'), isTrue);
      c.reset();
      await planner.plan(query: 'عندي ضغط مشخص من الطبيب', context: c);
      final back = await planner.plan(query: 'ظهري يوجعني', context: c);
      expect(c.mskSession.active || back.message.contains('ظهر'), isTrue);
    });
  });

  group('PC-1.20 questions / education / checklist DS–EH', () {
    test('DS–DX — no re-ask / corrections', () async {
      await run('عندي سكري مشخص');
      final again = await run('شنو باقي علي؟');
      expect(again.message.contains('عندك سكري؟'), isFalse);
      await run('لا مو سكري نوع أول، نوع ثاني');
      expect(ctx.chronicClinicalSession.diabetesType, DiabetesTypeContext.type2);
    });

    test('DY–EF — subject / education / no auto dx', () async {
      final fam = await run('أبويه عنده سكري');
      expect(fam.session.diabetesStatus, isNot(ChronicConditionStatus.established));
      final edu = await run('شنو فحوص مريض السكري؟');
      expect(edu.session.lastGlucose, isNull);
      expect(cc.diabetesPolicy.diagnosesFromSingleGlucose(), isFalse);
    });

    test('EG–EH — smart checklist statuses', () async {
      await run('عندي سكري مشخص');
      await run('فحصت عيوني قبل شهر');
      final list = await run('سويلي قائمة متابعة للسكري');
      final statuses = list.session.assembledPriorities.map((e) => e.status).toSet();
      expect(statuses.contains(CareItemStatus.recentlyCompleted) ||
          list.message.contains('غير معلوم'), isTrue);
    });
  });

  group('PC-1.20 evidence / privacy / failure EI–FF', () {
    test('EI–EN — no gamification/notifications; evidence', () {
      final src = Directory('lib/clinical_knowledge/packs/chronic_care')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('gamification'), isFalse);
      expect(src.contains('NotificationService'), isFalse);
      expect(src.contains('http://diabetes.org'), isFalse);
      expect(cc.diabetesRules.active.every((r) => r.hasEvidenceMetadata), isTrue);
      expect(
        cc.diabetesRules.findById('dm_incomplete_evidence_inactive')!.isActive,
        isFalse,
      );
    });

    test('EO–ES — debug clean', () async {
      final r = await run('السكر 250');
      final dbg = r.session.debugMap();
      expect(dbg.values.contains(250), isFalse);
      expect(dbg.values.contains(250.0), isFalse);
      expect(dbg.containsKey('personId'), isFalse);
    });

    test('ET–FA — text-first / failure safety', () async {
      final r = await run('عندي سكري مشخص');
      expect(r.textFirstOnly, isTrue);
      expect(MedicalSafetyEngine, isNotNull);
      expect(Directory('lib/clinical_knowledge/packs/musculoskeletal').existsSync(),
          isTrue);
      expect(Directory('lib/clinical_knowledge/packs/respiratory').existsSync(),
          isTrue);
    });

    test('FB–FF — no campaigns/admin/pregnancy companion/paid', () {
      final src = Directory('lib/clinical_knowledge/packs/chronic_care')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('campaign'), isFalse);
      expect(src.contains('ClinicalAdminUi'), isFalse);
      expect(src.contains('PregnancyCompanion'), isFalse);
      expect(src.contains('requiresPaid'), isFalse);
      expect(src.contains('DiseaseDiaryStore'), isFalse);
    });

    test('Smart Brain handles chronic clinical turn', () async {
      final planner = SmartBrainPlanner(
        doctorLookup: (_) async => <SmartSearchResult>[],
      );
      final c = ConversationContext();
      final plan = await planner.plan(
        query: 'شنو فحوص مريض السكري؟',
        context: c,
      );
      expect(plan.message, isNotNull);
      expect(c.chronicClinicalSession.active, isTrue);
    });

    test('architecture — PC-1.5 session distinct from pack session', () {
      expect(ctx.chronicCareSession, isNot(equals(ctx.chronicClinicalSession)));
      expect(
        File('lib/clinical_knowledge/packs/chronic_care/chronic_care_query_adapter.dart')
            .existsSync(),
        isTrue,
      );
      final adapterSrc = File(
        'lib/clinical_knowledge/packs/chronic_care/chronic_care_query_adapter.dart',
      ).readAsStringSync();
      expect(adapterSrc.contains('save('), isFalse);
      expect(adapterSrc.contains('isReadOnly'), isTrue);
    });

    test('architecture — measurement capture not stolen when PC-1.5 claims',
        () async {
      final planner = SmartBrainPlanner(
        doctorLookup: (_) async => <SmartSearchResult>[],
      );
      final c = ConversationContext();
      // PC-1.5 mayHandle matches السكر\d — حزمة PC-1.20 لا تسرق التسجيل
      await planner.plan(query: 'السكر 180', context: c);
      // إما PC-1.5 عالج أو مسار آخر — المهم الجلسة السريرية لا تفرض overdue
      expect(
        c.chronicClinicalSession.assembledPriorities
            .any((p) => p.status == CareItemStatus.overdue),
        isFalse,
      );
    });

    test('architecture — inactive flags not required for routing', () {
      expect(
        const ClinicalKnowledgeAdminContract().fullDiabetesPackEnabled,
        isFalse,
      );
      // التوجيه يعمل عبر المنسّق مباشرة بلا الاعتماد على العلم
      expect(
        cc.mayHandle(
          query: 'شنو فحوص مريض السكري؟',
          session: ChronicClinicalSession.inactive,
        ),
        isTrue,
      );
    });
  });
}
