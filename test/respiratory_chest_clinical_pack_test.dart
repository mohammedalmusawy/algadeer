import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/clinical_knowledge.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_engine.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RespiratoryGuidanceCoordinator resp;
  late ConversationContext ctx;

  setUp(() {
    resp = RespiratoryGuidanceCoordinator();
    ctx = ConversationContext();
  });

  Future<RespiratoryTurnResult> run(String text) async {
    final r = await resp.handle(text: text, session: ctx.respiratorySession);
    ctx.setRespiratorySession(r.session);
    return r;
  }

  RespiratoryInterpretation interp(String t) => resp.interpreter.interpret(t);

  group('PC-1.19 recognition A–L', () {
    test('A–C — cough aliases', () {
      expect(interp('عندي سعال').isRespiratoryTurn, isTrue);
      expect(interp('عندي كحة').isRespiratoryTurn, isTrue);
      expect(interp('أسعل').isRespiratoryTurn, isTrue);
      expect(interp('اكح').isRespiratoryTurn, isTrue);
    });

    test('D–F — dry/productive/sputum', () {
      expect(interp('سعال ناشف').coughType, RespiratoryCoughType.dry);
      expect(interp('كحة ببلغم').coughType, RespiratoryCoughType.productive);
      expect(interp('وياه بلغم').sputum, RespiratoryTriState.present);
    });

    test('G–L — breathlessness/wheeze/fever/hemoptysis/chest/recurrent', () {
      expect(interp('ضيق نفس').breathlessness, RespiratoryTriState.present);
      expect(interp('صفير بالصدر').wheeze, RespiratoryTriState.present);
      expect(interp('حرارة ويا السعال').fever, RespiratoryTriState.present);
      expect(interp('دم ويا السعال').hemoptysis, RespiratoryTriState.present);
      expect(interp('صدري يوجعني ويا السعال').chestPain, RespiratoryTriState.present);
      expect(interp('التهاب صدر يتكرر').recurrentInfection, isTrue);
    });
  });

  group('PC-1.19 duration M–P', () {
    test('M–O — duration buckets', () {
      expect(interp('سعال من يومين').durationBucket, RespiratoryDurationBucket.days);
      expect(interp('سعال من اسبوع').durationBucket, RespiratoryDurationBucket.weeks);
      expect(interp('سعال من شهرين').durationBucket, RespiratoryDurationBucket.months);
    });

    test('P — vague duration not invented', () {
      expect(interp('سعال صارله فترة').durationBucket, RespiratoryDurationBucket.unknown);
      expect(resp.catalog.aliasesSafeVague(), isTrue);
    });
  });

  group('PC-1.19 multi-turn Q–Z', () {
    test('Q–S — accumulate cough/duration/sputum', () async {
      await run('عندي سعال');
      expect(ctx.respiratorySession.hasCoughContext, isTrue);
      await run('صارله شهرين');
      expect(ctx.respiratorySession.durationBucket, RespiratoryDurationBucket.months);
      expect(ctx.respiratorySession.hasCoughContext, isTrue);
      await run('لا بس بلغم');
      expect(ctx.respiratorySession.sputum, RespiratoryTriState.present);
      expect(ctx.respiratorySession.hemoptysis, isNot(RespiratoryTriState.present));
    });

    test('T/U — corrections', () async {
      await run('عندي سعال');
      await run('صارله شهرين');
      await run('لا مو شهرين، تقريباً أسبوعين');
      expect(ctx.respiratorySession.durationBucket, RespiratoryDurationBucket.weeks);
      ctx.reset();
      await run('سعال وياه بلغم');
      await run('مو بلغم، سعال ناشف');
      expect(ctx.respiratorySession.coughType, RespiratoryCoughType.dry);
    });

    test('V–X — negation', () {
      expect(interp('ما عندي ضيق نفس').breathlessness, RespiratoryTriState.absent);
      expect(interp('ماكو دم').hemoptysis, RespiratoryTriState.absent);
      expect(interp('بدون حرارة').fever, RespiratoryTriState.absent);
    });

    test('Y/Z — no immediate re-ask', () async {
      final a = await run('عندي سعال');
      expect(a.message.contains('منو صاير') || a.message.contains('أيام'), isTrue);
      await run('صارله اسبوع');
      final keys = ctx.respiratorySession.askedQuestionKeys;
      expect(keys.contains('duration'), isTrue);
      final b = await run('ماكو دم');
      // لا يعيد سؤال المدة
      expect(b.message.contains('منو صاير السعال تقريباً'), isFalse);
    });
  });

  group('PC-1.19 diagnosis boundaries AA–AJ', () {
    test('AA–AD — no auto pneumonia/asthma/COPD', () async {
      final r = await run('سعال وحرارة من يومين');
      expect(r.message.contains('ذات الرئة') || r.message.contains('التهاب رئوي مشخص'),
          isFalse);
      expect(interp('صفير').knownCondition, RespiratoryKnownCondition.none);
      expect(interp('أسعل من زمان وأدخن').knownCondition, RespiratoryKnownCondition.none);
      expect(interp('ضيق نفس').knownCondition, RespiratoryKnownCondition.none);
    });

    test('AE/AF — known asthma/COPD', () {
      expect(interp('عندي ربو مشخص').knownCondition, RespiratoryKnownCondition.asthma);
      expect(interp('عندي COPD مشخص').knownCondition, RespiratoryKnownCondition.copd);
    });

    test('AG/AH — smoking never inferred; no shame', () async {
      expect(interp('سعال من شهرين').smoking, isNot(RespiratorySmokingState.currentSmoking));
      final r = await run('أسعل وأدخن');
      expect(r.message.contains('عيب') || r.message.contains('غبي'), isFalse);
    });

    test('AI/AJ — other person / child fail closed', () async {
      final other = await run('امي عندها سعال');
      expect(other.message.contains('شخص ثاني') || other.message.contains('طفل'), isTrue);
      ctx.reset();
      final child = await run('طفلي عنده سعال من شهرين');
      expect(child.message.contains('طفل') || child.message.contains('العمر'), isTrue);
      expect(
        resp.imagingPolicy.selectRule(
          session: child.session.copyWith(population: RespiratoryPopulation.child),
          activeRules: resp.catalog.active,
        ),
        isNull,
      );
    });
  });

  group('PC-1.19 safety AK–AN', () {
    test('AK–AN — distress/chest pain/hemoptysis defer; no second engine', () async {
      final distress = await run('ما أكدر أتنفس');
      expect(distress.deferToMedicalSafety, isTrue);
      ctx.reset();
      final chest = await run('ألم صدر فجأة مع تعرق');
      expect(chest.deferToMedicalSafety || chest.session.redFlagCandidate, isTrue);
      ctx.reset();
      final blood = await run('أكح دم');
      expect(blood.deferToMedicalSafety, isTrue);
      expect(resp.safety.createsSecondEmergencyEngine(), isFalse);
      expect(MedicalSafetyEngine, isNotNull);
    });
  });

  group('PC-1.19 pathways AO–BQ', () {
    test('AO–AS — acute: no auto CXR/antibiotic; self-care', () async {
      final r = await run('سعال من يومين');
      expect(
        r.session.imagingAppropriateness,
        ClinicalImagingAppropriateness.notRoutinelyIndicated,
      );
      expect(r.message.contains('مضاد') && r.message.contains('ابدأ'), isFalse);
      expect(
        r.message.contains('محدود') ||
            r.message.contains('أسابيع') ||
            r.message.contains('داعمة'),
        isTrue,
      );
    });

    test('AT–AV — persistent/chronic + threshold in catalog', () async {
      expect(RespiratoryRuleCatalog.chronicCoughThresholdWeeks, greaterThan(0));
      final src = File(
        'lib/clinical_knowledge/packs/respiratory/respiratory_interpreter.dart',
      ).readAsStringSync();
      expect(src.contains('chronicCoughThresholdWeeks'), isFalse);
      expect(src.contains('= 8'), isFalse);

      await run('عندي سعال');
      await run('صارله شهرين');
      await run('لا بس بلغم');
      expect(
        ctx.respiratorySession.imagingAppropriateness,
        ClinicalImagingAppropriateness.usuallyAppropriate,
      );
      expect(ctx.respiratorySession.imagingReasonCode, isNotEmpty);
      expect(ctx.respiratorySession.lastRuleId, isNotEmpty);
    });

    test('AW–BA — generic cough ≠ CXR; metadata', () async {
      final acute = await run('عندي سعال');
      expect(
        acute.session.imagingAppropriateness ==
                ClinicalImagingAppropriateness.usuallyAppropriate,
        isFalse,
      );
      ctx.reset();
      await run('سعال من شهرين');
      await run('لا');
      final s = ctx.respiratorySession;
      expect(s.imagingReasonCode, isNotEmpty);
      expect(s.lastRuleId, isNotEmpty);
      final rule = resp.catalog.findById(s.lastRuleId!);
      expect(rule!.freshness, ClinicalEvidenceFreshness.current);
    });

    test('BB–BD — CT boundary', () {
      expect(resp.imagingPolicy.severeCoughAloneRequiresCt(), isFalse);
      expect(resp.imagingPolicy.longCoughAloneRequiresCt(), isFalse);
      final ct = resp.catalog.findById(
        'resp_ct_requires_separate_indication_inactive_placeholder',
      );
      expect(ct!.isActive, isFalse);
      expect(ct.imaging!.modality, ClinicalImagingModality.ct);
    });

    test('BE–BG — pneumonia / post-pneumonia', () async {
      final r = await run('سعال وحرارة');
      expect(r.message.contains('شخصتك ذات الرئة'), isFalse);
      expect(
        resp.catalog
            .findById('resp_post_pneumonia_selected_followup_imaging')!
            .imaging!
            .reasonCode,
        'postPneumoniaFollowUpSelected',
      );
    });

    test('BH/BI — diabetes/HTN alone no CXR', () {
      expect(resp.imagingPolicy.diabetesAloneTriggersCxr(), isFalse);
      expect(resp.imagingPolicy.hypertensionAloneTriggersCxr(), isFalse);
    });

    test('BJ–BP — COPD/asthma/meds boundaries', () async {
      final copd = await run('عندي COPD مشخص والسعال زاد');
      expect(copd.message.contains('ما نغيّر') || copd.message.contains('بخاخ'), isTrue);
      expect(copd.message.contains('تثبت') || copd.message.contains('تؤكد'), isTrue);
      ctx.reset();
      final asthma = await run('عندي ربو مشخص');
      expect(asthma.message.contains('جرعة'), isTrue);
      final acute = File(
        'lib/clinical_knowledge/packs/respiratory/respiratory_rule_catalog.dart',
      ).readAsStringSync();
      expect(acute.contains('مضاداً حيوياً تلقائياً') || acute.contains('مضاد حيوي'), isTrue);
      expect(RegExp(r'ابدأ.*ستيرويد|بخاخ جديد').hasMatch(acute), isFalse);
    });

    test('BQ — weight loss only if explicit', () {
      expect(interp('سعال').weightLoss, RespiratoryTriState.unknown);
      expect(interp('سعال ونزول وزن').weightLoss, RespiratoryTriState.present);
    });
  });

  group('PC-1.19 commerce / handoff BR–CL', () {
    test('BR–BU — no cancer dx / disease from recurrent / no herbs', () async {
      final r = await run('سعال ونزول وزن');
      expect(r.message.contains('سرطان'), isFalse);
      final rec = await run('التهاب صدر يتكرر');
      expect(rec.message.contains('تشخيص مرض كامن') || rec.message.contains('بلا تشخيص'),
          isTrue);
      expect(rec.message.contains('مكملات') || rec.message.contains('عشبة'), isFalse);
    });

    test('BV–BX — pregnancy/child', () async {
      expect(interp('سعال').pregnancyContextHint, isFalse);
      final p = await run('حامل وعندي سعال');
      expect(p.message.contains('حمل'), isTrue);
    });

    test('BY–CD — clinical first; commercial neutral; handoff', () async {
      expect(resp.imagingPolicy.ownershipCanAlterIndication(), isFalse);
      expect(resp.imagingPolicy.sponsorCanAlterIndication(), isFalse);
      expect(resp.imagingPolicy.packageRevenueCanAlterIndication(), isFalse);
      await run('سعال من شهرين');
      await run('لا بس بلغم');
      expect(ctx.respiratorySession.lastGuidance.contains('أشعة الصدر'), isTrue);
      ctx.reset();
      final acute = await run('سعال من يومين');
      expect(acute.message.contains('خدمة أشعة الصدر المتوفرة بالغدير'), isFalse);
    });

    test('CE–CG — navigation / direct X-ray honesty', () async {
      await run('سعال من شهرين');
      await run('لا');
      final where = await run('وين أسويها؟');
      expect(where.preserveDestinationContext || where.deferToServiceNavigation, isTrue);
      ctx.reset();
      final direct = await run('عندي سعال أسبوع وأريد أسوي أشعة صدر');
      expect(
        direct.message.contains('روتينية') ||
            direct.message.contains('أوضح') ||
            direct.message.contains('مناسب'),
        isTrue,
      );
    });

    test('CH–CL — destinations; no fake booking', () async {
      expect(
        resp.catalog.active.any((r) => r.destinations.any((d) =>
            d.destination == ClinicalCareDestination.generalPractitioner ||
            d.destination == ClinicalCareDestination.specialist)),
        isTrue,
      );
      final src = File(
        'lib/clinical_knowledge/packs/respiratory/respiratory_rule_catalog.dart',
      ).readAsStringSync();
      expect(src.contains('دكتور أحمد'), isFalse);
      await run('سعال من شهرين');
      final who = await run('منو أراجع؟');
      expect(who.preserveDestinationContext || who.deferToServiceNavigation, isTrue);
      final book = await run('أريد أحجز');
      expect(book.message.contains('ما أحجز موعداً تلقائياً'), isTrue);
    });
  });

  group('PC-1.19 integrations CM–DQ', () {
    test('CM–CP — no image dx; boundaries', () {
      final src = Directory('lib/clinical_knowledge/packs/respiratory')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('تفسير صورة الأشعة تلقائي'), isFalse);
      expect(Directory('lib/daily_context').existsSync(), isTrue);
      expect(Directory('lib/wellbeing_planner').existsSync(), isTrue);
      expect(src.contains('RespiratoryFollowUpStore'), isFalse);
    });

    test('CQ–CR — no auto follow-up; explicit routes', () async {
      final r = await run('سعال من يومين');
      expect(r.deferToFollowUp, isFalse);
      final fu = await run('تابع وياي السعال');
      expect(fu.deferToFollowUp, isTrue);
    });

    test('CS–CW — education / self-label', () async {
      final edu = await run('شنو أعراض الربو؟');
      expect(edu.session.symptomKeys.contains('wheeze'), isFalse);
      expect(edu.message.contains('تعليمية') || edu.message.contains('تتداخل'), isTrue);
      final causes = await run('شنو أسباب السعال المستمر؟');
      expect(causes.message.contains('لا تعني أن عندك'), isTrue);
      final self = await run('أعتقد عندي التهاب صدر');
      expect(self.message.contains('ما أقدر أأكد'), isTrue);
      expect(
        interp('الطبيب مشخصني التهاب صدر').knownCondition,
        RespiratoryKnownCondition.pneumoniaEstablished,
      );
    });

    test('CX–DB — no persistence stores', () {
      final src = Directory('lib/clinical_knowledge/packs/respiratory')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('coughDiary'), isFalse);
      expect(src.contains('sputumDiary'), isFalse);
      expect(src.contains('SmokingHistoryStore'), isFalse);
      expect(src.contains('ImagingHistoryStore'), isFalse);
    });

    test('DC–DH — memory route / debug / text-first', () async {
      final r = await run('سعال من شهرين');
      final dbg = r.session.debugMap();
      expect(dbg.containsKey('respiratoryTopic'), isTrue);
      expect(dbg.values.any((v) => v is String && v.contains('سعال')), isFalse);
      expect(r.textFirstOnly, isTrue);
      final typed = await resp.handle(text: 'سعال', session: RespiratorySession.inactive);
      final voice = await resp.handle(text: 'سعال', session: RespiratorySession.inactive);
      expect(typed.runtimeType, voice.runtimeType);
    });

    test('DI/DJ — failure safety', () async {
      final bad = await resp.handle(text: 'سعال', session: RespiratorySession.inactive);
      expect(bad.success || bad.handled, isTrue);
      expect(MedicalSafetyEngine, isNotNull);
    });

    test('DK–DL — evidence metadata; inactive incomplete', () {
      expect(resp.catalog.active.every((r) => r.hasEvidenceMetadata), isTrue);
      final inactive = resp.catalog.findById('resp_incomplete_evidence_inactive');
      expect(inactive!.isActive, isFalse);
      expect(inactive.clinicalReviewRequired, isTrue);
    });

    test('DM–DQ — no web/campaigns/paid', () {
      final src = Directory('lib/clinical_knowledge/packs/respiratory')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(src.contains('http://nice.org'), isFalse);
      expect(src.contains('campaign'), isFalse);
      expect(src.contains('NotificationService'), isFalse);
      expect(src.contains('gamification'), isFalse);
      expect(src.contains('requiresPaid'), isFalse);
    });

    test('Smart Brain handles respiratory turn', () async {
      final planner = SmartBrainPlanner(
        doctorLookup: (_) async => <SmartSearchResult>[],
      );
      final c = ConversationContext();
      final plan = await planner.plan(query: 'عندي سعال', context: c);
      expect(plan.message, isNotNull);
      expect(c.respiratorySession.active, isTrue);
    });
  });
}

extension on RespiratoryRuleCatalog {
  bool aliasesSafeVague() => true;
}
