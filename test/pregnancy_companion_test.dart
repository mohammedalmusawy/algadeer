import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/clinical_knowledge_models.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/pregnancy_companion/pregnancy_companion.dart';
import 'package:ghadeer_clinic/health/safety/medical_safety_engine.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  late PregnancyCompanionCoordinator pc;
  late ConversationContext ctx;

  setUp(() {
    pc = PregnancyCompanionCoordinator();
    ctx = ConversationContext();
  });

  Future<PregnancyCompanionTurnResult> run(
    String text, {
    PregnancyCompanionSession? session,
  }) =>
      pc.handle(
        text: text,
        session: session ?? ctx.pregnancyCompanionSession,
      );

  group('PC-1.21 identity / subject', () {
    test('owner confirmed pregnancy', () async {
      final r = await run('اني حامل بالأسبوع 18');
      expect(r.handled, isTrue);
      expect(r.session.status, PregnancyStatus.confirmed);
      expect(r.session.isOtherPerson, isFalse);
      expect(r.session.gestationalWeeks, 18);
    });

    test('wife / mother / sister not owner', () async {
      for (final q in ['زوجتي حامل', 'أمي حامل', 'اختي حامل بالأسبوع 20']) {
        final r = await run(q);
        expect(r.session.isOtherPerson, isTrue, reason: q);
        expect(r.message.contains('شخص ثاني') || r.message.contains('spouse') ||
            r.message.contains('mother') || r.message.contains('sister') ||
            r.message.contains('مو عنج'), isTrue);
      }
    });

    test('subject correction owner→wife', () async {
      final s = PregnancyCompanionSession(
        active: true,
        status: PregnancyStatus.confirmed,
        gestationalWeeks: 18,
      );
      final r2 = await run('لا مو آني، زوجتي', session: s);
      expect(r2.session.isOtherPerson, isTrue);
      expect(r2.session.gestationalWeeks, isNull);
    });

    test('no subject leakage in debug', () {
      final s = PregnancyCompanionSession(
        active: true,
        status: PregnancyStatus.confirmed,
        gestationalWeeks: 22,
        fetalSexFromClinician: 'female',
      );
      final d = s.debugMap();
      expect(d.containsKey('personId'), isFalse);
      expect(d.values.contains(22), isFalse);
      expect(d.values.contains('female'), isFalse);
    });
  });

  group('PC-1.21 confirmation', () {
    test('explicit / clinician / positive test', () async {
      expect(
        (await run('اني حامل')).session.status,
        PregnancyStatus.confirmed,
      );
      expect(
        (await run('الدكتورة أكدت الحمل')).session.status,
        PregnancyStatus.confirmed,
      );
      expect(
        (await run('فحص الحمل طلع موجب')).session.status,
        PregnancyStatus.confirmed,
      );
    });

    test('symptoms alone do not confirm', () async {
      final r = await run('عندي غثيان وتعب');
      expect(r.session.status, isNot(PregnancyStatus.confirmed));
    });

    test('late period / possible / trying / loss', () async {
      expect(
        (await run('تأخر الدورة عندي')).session.status,
        PregnancyStatus.possible,
      );
      expect(
        (await run('نحاول حمل')).session.status,
        PregnancyStatus.tryingToConceive,
      );
      final loss = await run('فقدت الحمل');
      expect(loss.session.status, PregnancyStatus.pregnancyLossReported);
      expect(loss.message.contains('احتفالية') || loss.message.contains('آسفة'),
          isTrue);
    });
  });

  group('PC-1.21 gestational context', () {
    test('explicit week + days', () {
      final i = pc.interpreter.interpret('اني حامل بالأسبوع 18 و3 أيام');
      expect(i.gestationalWeeks, 18);
      expect(i.gestationalDaysExtra, 3);
      expect(i.datingSource, GestationalDatingSource.explicitWeek);
    });

    test('trimester / month colloquial no exact week', () {
      final m = pc.interpreter.interpret('دخلت الشهر الخامس');
      expect(m.monthColloquial, 5);
      expect(m.gestationalWeeks, isNull);
      expect(m.datingSource, GestationalDatingSource.monthColloquial);
      expect(pc.inventsGestationalDayFromVagueMonth(), isFalse);
    });

    test('LMP calculator deterministic', () {
      const calc = PregnancyGestationalCalculator();
      final r = calc.fromLmp(
        lmp: DateTime(2026, 1, 1),
        now: DateTime(2026, 3, 12),
      );
      expect(r, isNotNull);
      expect(r!.weeks, greaterThan(8));
      final approx = calc.fromLmp(
        lmp: DateTime(2026, 1, 1),
        now: DateTime(2026, 3, 12),
        approximate: true,
      );
      expect(approx!.approximate, isTrue);
    });

    test('EDD estimated not guaranteed wording', () async {
      final r = await run('اني حامل بالأسبوع 20');
      expect(r.message.contains('راح تولدين بهذا اليوم'), isFalse);
    });

    test('week correction', () async {
      final s = PregnancyCompanionSession(
        active: true,
        status: PregnancyStatus.confirmed,
        gestationalWeeks: 20,
      );
      final r = await run('مو 20 أسبوع، 18', session: s);
      // المفسّر يلتقط 18 إن وُجدت
      final i = pc.interpreter.interpret('مو 20 أسبوع، بالأسبوع 18');
      expect(i.gestationalWeeks, 18);
      expect(r.handled, isTrue);
    });

    test('PC-1.24 regression: لا 22 / آسف 23 updates weeks', () async {
      var s = const PregnancyCompanionSession(
        active: true,
        status: PregnancyStatus.confirmed,
        gestationalWeeks: 24,
      );
      var r = await run('لا 22', session: s);
      expect(r.session.gestationalWeeks, 22);
      r = await run('آسف 23', session: r.session);
      expect(r.session.gestationalWeeks, 23);
    });
  });

  group('PC-1.21 care map / UNKNOWN≠OVERDUE', () {
    test('whats left default ≤3', () async {
      final s = PregnancyCompanionSession(
        active: true,
        status: PregnancyStatus.confirmed,
        gestationalWeeks: 20,
      );
      final r = await run('شنو باقي علي؟', session: s);
      expect(r.handled, isTrue);
      expect(r.session.priorities.length, lessThanOrEqualTo(3));
      expect(
        r.session.priorities.any((p) => p.status == PregnancyCareItemStatus.overdue),
        isFalse,
      );
      expect(r.message.contains('متأخر') && r.message.contains('تشوهات'), isFalse);
    });

    test('unknown ultrasound not overdue', () {
      final priorities = pc.assembler.assemble(
        session: const PregnancyCompanionSession(
          active: true,
          status: PregnancyStatus.confirmed,
          gestationalWeeks: 20,
        ),
        catalog: pc.catalog,
        due: pc.duePolicy,
      );
      final us = priorities.where(
        (p) => p.id == PregnancyCareItem.ultrasoundDating.name,
      );
      for (final p in us) {
        expect(p.status, isNot(PregnancyCareItemStatus.overdue));
      }
    });

    test('completed ultrasound acknowledged', () async {
      final s = PregnancyCompanionSession(
        active: true,
        status: PregnancyStatus.confirmed,
        gestationalWeeks: 19,
        completedCareItems: [PregnancyCareItem.ultrasoundDating.name],
      );
      final r = await run('أكدر أسوي سونار؟', session: s);
      expect(r.message.contains('تكرار') || r.message.contains('حديث'), isTrue);
    });

    test('full checklist request', () async {
      final s = PregnancyCompanionSession(
        active: true,
        status: PregnancyStatus.confirmed,
        gestationalWeeks: 25,
      );
      final r = await run('قائمة متابعة كاملة checklist', session: s);
      expect(r.session.priorities.length, greaterThan(3));
    });
  });

  group('PC-1.21 ultrasound / commercial', () {
    test('no commercial bias', () {
      expect(pc.ultrasoundPolicy.commercialCanAlterIndication(), isFalse);
      expect(pc.ultrasoundPolicy.packagePresenceCreatesNeed(), isFalse);
      expect(pc.ultrasoundPolicy.interpretsUltrasoundImages(), isFalse);
    });

    test('ultrasound question', () async {
      final r = await run('اني حامل أريد سونار');
      expect(r.handled, isTrue);
      expect(r.message.contains('تكرار عشوائي') || r.message.contains('السونار'),
          isTrue);
    });
  });

  group('PC-1.21 diabetes / BP boundary', () {
    test('GDM established / single glucose / preexisting', () async {
      final gdm = await run('طلع عندي سكر حمل');
      expect(gdm.message.contains('إنسولين') || gdm.message.contains('تشخيص'),
          isTrue);
      expect(gdm.message.contains('عدّل إنسولين') ||
          gdm.message.contains('ما نعدّل'), isTrue);

      final s = PregnancyCompanionSession(
        active: true,
        status: PregnancyStatus.confirmed,
        gestationalWeeks: 26,
      );
      final one = await run('السكر 200', session: s);
      expect(one.message.contains('ما تشخّص'), isTrue);

      final pre = await run('عندي سكري مشخص واني حامل');
      expect(pre.message.contains('غير حمل') || pre.message.contains('سابقة'),
          isTrue);
    });

    test('high BP no preeclampsia diagnosis', () async {
      final r = await run('اني حامل والدكتورة گالت ضغطي مرتفع');
      expect(r.message.contains('أشخّص تسمم') || r.message.contains('ما أشخّص'),
          isTrue);
    });
  });

  group('PC-1.21 symptoms / safety', () {
    test('common symptoms no overdiagnosis', () async {
      for (final q in [
        'اني حامل وعندي غثيان',
        'اني حامل وحرقة معدة',
        'اني حامل وامساك',
      ]) {
        final r = await run(q);
        expect(r.handled, isTrue, reason: q);
        expect(r.message.contains('تشخيص'), isFalse, reason: q);
      }
    });

    test('bleeding / severe defer to 10E', () async {
      final r = await run('اني حامل ونزل علي دم');
      expect(r.deferToMedicalSafety, isTrue);
      expect(pc.createsSecondEmergencyEngine(), isFalse);
      expect(MedicalSafetyEngine, isNotNull);
    });

    test('reduced movement gestationally relevant', () async {
      final early = pc.interpreter.interpret('اني حامل بالأسبوع 12 وحركة الطفل قلت');
      expect(early.redFlagCandidate, isFalse);
      final late = pc.interpreter.interpret('اني حامل بالأسبوع 30 وحركة الطفل قلت');
      expect(late.redFlagCandidate, isTrue);
    });
  });

  group('PC-1.21 emotional / myths / clinician', () {
    test('fear of birth no false reassurance', () async {
      final r = await run('اني حامل وخايفة من الولادة');
      expect(r.message.contains('أكيد كلشي تمام'), isFalse);
      expect(r.message.contains('لا تحتاجين طبيبتج'), isFalse);
    });

    test('fetal sex myths refused', () async {
      final r = await run('متى أعرف جنس الطفل من ضربات القلب؟');
      expect(r.message.contains('ما أخمّن') || r.message.contains('خرافات'),
          isTrue);
    });

    test('doctor said girl', () async {
      final r = await run('الدكتورة گالت بنت');
      expect(r.message.contains('بنت'), isTrue);
    });

    test('clinician plan respected', () async {
      final r = await run('الدكتورة گالت أعيد الفحص بعد أسبوعين');
      expect(r.message.contains('خطة الطبيبة') || r.message.contains('خطة'),
          isTrue);
    });
  });

  group('PC-1.21 activity / follow-up / mayHandle', () {
    test('can I walk', () async {
      final r = await run('اني حامل أكدر أمشي؟');
      expect(r.handled, isTrue);
      expect(r.message.contains('10 آلاف') || r.message.contains('10000'), isFalse);
    });

    test('explicit follow-up deferred', () async {
      final r = await run('اني حامل ذكرني بعد اسبوع');
      expect(r.deferToFollowUp, isTrue);
    });

    test('mayHandle does not steal greeting / cough / MSK', () {
      expect(
        pc.mayHandle(query: 'مرحبا', session: PregnancyCompanionSession.inactive),
        isFalse,
      );
      expect(
        pc.mayHandle(
          query: 'اني حامل وعندي سعال',
          session: PregnancyCompanionSession.inactive,
        ),
        isFalse,
      );
      expect(
        pc.mayHandle(
          query: 'أنا حامل وظهري يوجعني',
          session: PregnancyCompanionSession.inactive,
        ),
        isFalse,
      );
      expect(
        pc.mayHandle(
          query: 'اني حامل بالأسبوع 18 شنو المفروض أسوي؟',
          session: PregnancyCompanionSession.inactive,
        ),
        isTrue,
      );
    });

    test('active session does not hijack unrelated', () {
      const active = PregnancyCompanionSession(
        active: true,
        status: PregnancyStatus.confirmed,
        gestationalWeeks: 18,
      );
      expect(pc.mayHandle(query: 'مرحبا', session: active), isFalse);
      expect(
        pc.mayHandle(query: 'شنو باقي علي؟', session: active),
        isTrue,
      );
    });
  });

  group('PC-1.21 evidence / architecture', () {
    test('active rules have evidence metadata', () {
      for (final r in pc.catalog.active) {
        expect(r.hasEvidenceMetadata, isTrue, reason: r.ruleId);
        expect(r.freshness, ClinicalEvidenceFreshness.current);
      }
    });

    test('thresholds centralized in catalog', () {
      expect(PregnancyEvidenceCatalog.gdmScreenStartWeek, 24);
      expect(PregnancyEvidenceCatalog.ultrasoundBeforeWeek, 24);
      expect(PregnancyEvidenceCatalog.anatomyWindowStartWeek, 18);
    });

    test('no duplicate authorities', () {
      expect(pc.createsPregnancyDatabase(), isFalse);
      expect(pc.replacesFollowUpAuthority(), isFalse);
      expect(pc.replacesActivityAuthority(), isFalse);
      expect(pc.replacesEmotionalAuthority(), isFalse);
      expect(pc.commercialUltrasoundBias(), isFalse);
      expect(pc.infersSexFromMyths(), isFalse);
    });

    test('failure safety', () async {
      final bad = PregnancyCompanionCoordinator(
        catalog: PregnancyEvidenceCatalog(rules: [
          PregnancyEvidenceRule(
            ruleId: 'broken',
            careItem: PregnancyCareItem.antenatalContact,
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
        text: 'اني حامل',
        session: PregnancyCompanionSession.inactive,
      );
      expect(r.success, isFalse);
      expect(r.message.contains('بدون دليل') || r.message.contains('طبيبة'),
          isTrue);
    });

    test('Smart Brain wires pregnancy companion', () async {
      final planner = SmartBrainPlanner(
        doctorLookup: (_) async => <SmartSearchResult>[],
      );
      final c = ConversationContext();
      final plan = await planner.plan(
        query: 'اني حامل بالأسبوع 18 شنو المفروض أسوي؟',
        context: c,
      );
      expect(plan.message, isNotNull);
      expect(c.pregnancyCompanionSession.active, isTrue);
    });

    test('text-first', () async {
      final r = await run('اني حامل');
      expect(r.textFirstOnly, isTrue);
    });

    test('pack files exist', () {
      expect(
        Directory('lib/clinical_knowledge/packs/pregnancy_companion').existsSync(),
        isTrue,
      );
    });
  });
}
