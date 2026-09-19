/// PC-1.25 — بوابة إطلاق Smart Brain V1: تحقق خصومي + تقوية دنيا.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/dental/dental_guidance_coordinator.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/dental/dental_models.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/dental/dental_rule_catalog.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/musculoskeletal/msk_guidance_coordinator.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/pregnancy_companion/pregnancy_evidence_catalog.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory_guidance_coordinator.dart';
import 'package:ghadeer_clinic/companion/adolescent/adolescent_evidence_catalog.dart';
import 'package:ghadeer_clinic/companion/people/subject_binding/subject_binding_coordinator.dart';
import 'package:ghadeer_clinic/companion/people/subject_binding/subject_binding_models.dart';
import 'package:ghadeer_clinic/companion/personal_companion_profile.dart';
import 'package:ghadeer_clinic/health/emotional_support/mental_health_safety_gate.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/musculoskeletal/msk_models.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory_models.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  SmartBrainPlanner planner({
    SmartBrainDoctorLookup? doctors,
    SmartBrainLabLookup? labs,
  }) =>
      SmartBrainPlanner(
        doctorLookup: doctors ?? ((_) async => <SmartSearchResult>[]),
        labLookup: labs ??
            ((_) async => [
                  SmartSearchResult(
                    type: SmartSearchResultType.lab,
                    title: 'مختبر الغدير',
                    subtitle: 'مختبر',
                    labId: 'lab-ghadeer',
                    score: 95,
                  ),
                ]),
        analysisLookup: (_) async => const [],
        packagesLookup: (_) async => const [],
        packagesForAnalysisLookup: (_) async => const [],
        activePackagesLookup: ({labId, nameQuery}) async => const [],
        discountedPackagesLookup: ({labId}) async => const [],
      );

  group('PC-1.25 release gate — flagship + family', () {
    test('flagship multi-turn remains coherent', () async {
      final p = planner();
      final c = ConversationContext();
      Future<String> say(String q) async {
        final plan = await p.plan(query: q, context: c);
        expect(plan.message.trim(), isNotEmpty, reason: 'blank for: $q');
        expect(
          ConversationHarness.clarificationCount(plan.message),
          lessThanOrEqualTo(1),
        );
        return plan.message;
      }

      await say(
        'اني حامل بالأسبوع 24 وعندي سكر حمل ومن البارحة ظهري يوجعني وخايفة',
      );
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.msk,
      );
      expect(c.pregnancyCompanionSession.gestationalWeeks, 24);

      await say('الألم متوسط وما عندي نزف');
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.msk,
      );

      await say('مو 24، 22');
      // تصحيح أسبوع عبر امتصاص سياقي أو جلسة حمل
      if (c.pregnancyCompanionSession.active) {
        expect(c.pregnancyCompanionSession.gestationalWeeks, isNot(24));
      }

      await say('وين أكدر ألكه طبيب أسنان؟');
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        isNot(BrainAuthorityId.msk),
      );

      await say('لا مو إلي، ابني عمره 15 سنه يوجعه');
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.dental,
      );

      await say('ووجهه هم وارم');
      expect(c.dentalSession.active, isTrue);

      await say('لا ماكو ورم بالوجه، بس اللثة وارمة');
      expect(c.dentalSession.swelling, DentalSwellingClass.gum);
      expect(c.dentalSession.redFlagCandidate, isFalse);

      await say('ذكرني بعد أسبوع');
      await say('بالنسبة لظهري، الألم بعده موجود');
    });

    test('family >=15 turns zero leakage', () async {
      final p = planner();
      final c = ConversationContext();
      final turns = <String>[
        'اني حامل بالأسبوع 24',
        'ابني عمره 15 ومتوتر من الامتحان',
        'زوجتي سنها يوجعها',
        'أمي عندها ضغط',
        'هسه بالنسبة إلي ظهري يوجعني',
        'ابني هم عنده سعال',
        'زوجتي اللثة وارمة',
        'اني خايفة',
        'وين مختبر الغدير؟',
        'ابني ما يكدر يركز',
        'اني الألم خفيف هسه',
        'أمي قراءتها 140 على 90',
        'زوجتي ماكو ورم بالوجه',
        'ذكرني أراجع',
        'خلاص اترك موضوع أمي',
        'بالنسبة لظهري بعده موجود',
      ];
      for (final q in turns) {
        final plan = await p.plan(query: q, context: c);
        expect(plan.message.trim().isNotEmpty || q.contains('خلاص'), isTrue,
            reason: 'empty/blank: $q');
        final dump = c.unifiedBrainDiagnostics.toDebugMap().toString();
        expect(dump.contains('personId'), isFalse);
        expect(dump.contains('حامل بالأسبوع'), isFalse);
      }
      // بعد ظهر المالك لا يجب أن يبقى المراهق مسيطراً كمالك
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        anyOf(BrainAuthorityId.msk, BrainAuthorityId.none, BrainAuthorityId.followUp),
      );
    });
  });

  group('PC-1.25 subject / age / correction / negation', () {
    test('age authority boundaries and precedence', () {
      const age = AgeAuthorityResolver();
      final bd = age.resolve(
        birthDate: DateTime(2010, 9, 17),
        now: DateTime(2026, 9, 16),
      );
      expect(bd.ageYears, 15);
      expect(bd.provenance, AgeProvenance.exactBirthDateDerived);

      final by = age.resolve(birthYear: 2010, now: DateTime(2026, 9, 16));
      expect(by.provenance, AgeProvenance.birthYearDerived);

      final ex = age.resolve(
        explicitAgeFromUtterance: 17,
        birthDate: DateTime(2010, 1, 1),
        now: DateTime(2026, 9, 16),
      );
      expect(ex.ageYears, 17);
      expect(ex.provenance, AgeProvenance.explicitCurrentAge);
      expect(age.resolve().isKnown, isFalse);
    });

    test('adolescent age leakage to owner blocked', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'ابني عمره 15 ومتوتر', context: c);
      await p.plan(query: 'اني ظهري يوجعني', context: c);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.msk,
      );
      expect(c.adolescentCompanionSession.active, isFalse);
    });

    test('repeated week corrections end at 21', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'اني حامل بالأسبوع 24', context: c);
      await p.plan(query: 'لا 22', context: c);
      await p.plan(query: 'آسف 23', context: c);
      await p.plan(query: 'لا، 21', context: c);
      expect(c.pregnancyCompanionSession.gestationalWeeks, 21);
    });

    test('negation clears facial red-flag stickiness', () async {
      final dental = DentalGuidanceCoordinator();
      var s = DentalSession.inactive;
      var r = await dental.handle(
        text: 'سني يوجعني ووجهي وارم',
        session: s,
      );
      s = r.session;
      expect(s.swelling, DentalSwellingClass.facial);
      r = await dental.handle(
        text: 'لا ماكو ورم بالوجه، بس اللثة وارمة',
        session: s,
      );
      expect(r.session.swelling, DentalSwellingClass.gum);
      expect(r.session.redFlagCandidate, isFalse);
    });

    test('subjectChanged clears clinical sessions', () {
      final c = ConversationContext()
        ..mskSession = const MskSession(active: true, lastQuestionKey: 'q')
        ..linkedFamilyPersonId = 'wife-1'
        ..resolvedConversationSubject = const ResolvedConversationSubject(
          subjectKind: ConversationSubjectKind.persistentPerson,
          status: ConversationPersonResolutionStatus.resolved,
          healthSubjectType: HealthSubjectType.otherPerson,
          persistentPersonId: 'wife-1',
          isAccountOwner: false,
        );
      final binding = SubjectBindingCoordinator();
      binding.applyToContext(
        c,
        const SubjectBindingTurnResult(
          linkedPersonId: null,
          resolved: ResolvedConversationSubject(
            subjectKind: ConversationSubjectKind.accountOwner,
            status: ConversationPersonResolutionStatus.resolved,
            healthSubjectType: HealthSubjectType.self,
            isAccountOwner: true,
          ),
          subjectChanged: true,
        ),
      );
      expect(c.mskSession.active, isFalse);
    });
  });

  group('PC-1.25 safety / crisis / one-response / one-question', () {
    test('MentalHealthSafetyGate wins over adolescent productivity', () async {
      final p = planner();
      final c = ConversationContext();
      const q = 'عمري 16 أبي أقتل نفسي';
      expect(const MentalHealthSafetyGate().triggersCrisis(q), isTrue);
      final plan = await p.plan(query: q, context: c);
      expect(plan.message, isNotEmpty);
      expect(RegExp(r'خطة\s*دراس').hasMatch(plan.message), isFalse);
    });

    test('ordinary anxiety is not crisis', () {
      expect(
        const MentalHealthSafetyGate().triggersCrisis('خايف من الامتحان'),
        isFalse,
      );
    });

    test('one response pregnancy+cough', () async {
      final p = planner();
      final c = ConversationContext();
      final plan = await p.plan(query: 'اني حامل وعندي سعال', context: c);
      expect(plan.message, isNotEmpty);
      expect(plan.message.contains('——'), isFalse);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.respiratory,
      );
      expect(ConversationHarness.clarificationCount(plan.message), lessThanOrEqualTo(1));
    });

    test('one-question under multi-pack desire', () async {
      final brain = UnifiedBrainCoordinator();
      final turn = brain.buildTurn(
        'اني حامل وظهري يوجعني وخايفة وسني يوجعني',
      );
      final plan = brain.planFromContributions(
        turn: turn,
        candidates: const [],
        primary: const BrainContribution(
          authority: BrainAuthorityId.msk,
          role: BrainAuthorityRole.primary,
          priority: 100,
          message: 'ألم ظهر.',
          clarificationQuestion: 'الألم إلك؟',
        ),
        contextual: const [
          BrainContribution(
            authority: BrainAuthorityId.pregnancy,
            role: BrainAuthorityRole.contextual,
            priority: 40,
            clarificationQuestion: 'أي أسبوع؟',
          ),
          BrainContribution(
            authority: BrainAuthorityId.dental,
            role: BrainAuthorityRole.primary,
            priority: 50,
            clarificationQuestion: 'في ورم؟',
          ),
        ],
      );
      expect(plan.questionBudgetUsed, isTrue);
      expect(plan.clarificationQuestion, 'الألم إلك؟');
      expect(plan.message.contains('أي أسبوع؟'), isFalse);
    });
  });

  group('PC-1.25 sessions / matrix / neutrality / no-result', () {
    test('stale session no hijack lab then resume', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'ظهري يوجعني', context: c);
      expect(c.mskSession.active, isTrue);
      await p.plan(query: 'وين مختبر الغدير؟', context: c);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        isNot(BrainAuthorityId.msk),
      );
      await p.plan(query: 'مرحبا', context: c);
      await p.plan(query: 'بالنسبة لظهري، الألم بعده موجود', context: c);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.msk,
      );
    });

    test('domain switch matrix samples', () async {
      Future<BrainAuthorityId> primary(String q) async {
        final c = ConversationContext();
        await planner().plan(query: q, context: c);
        return c.unifiedBrainDiagnostics.selectedPrimaryAuthority;
      }

      expect(await primary('اني حامل وعندي سعال'), BrainAuthorityId.respiratory);
      expect(await primary('اني حامل وضرس العقل يوجعني'), BrainAuthorityId.dental);
      expect(
        await primary('اني حامل بالأسبوع 24 وظهري يوجعني'),
        BrainAuthorityId.msk,
      );
      expect(await primary('عمري 16 وسني يوجعني'), BrainAuthorityId.dental);
      expect(await primary('عمري 16 وعندي سعال'), BrainAuthorityId.respiratory);
    });

    test('dentist service no-result is non-empty', () async {
      final p = planner(doctors: (_) async => <SmartSearchResult>[]);
      final c = ConversationContext();
      final plan = await p.plan(
        query: 'وين أكدر ألكه طبيب أسنان؟',
        context: c,
      );
      expect(plan.message.trim(), isNotEmpty);
      expect(plan.message.toLowerCase().contains('دكتور علي'), isFalse);
    });

    test('ResultContext doctor location continuity', () async {
      final p = planner(
        doctors: (_) async => [
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'دكتور علي',
            subtitle: 'طب عام',
            doctorId: 'd-ali',
            specialty: 'طب عام',
            clinicLocation: 'عيادة الغدير',
            score: 95,
          ),
        ],
      );
      final c = ConversationContext();
      c.rememberResults(
        [
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'دكتور علي',
            subtitle: 'طب عام',
            doctorId: 'd-ali',
            specialty: 'طب عام',
            clinicLocation: 'عيادة الغدير',
            score: 95,
          ),
        ],
        intent: AssistantIntent.doctorSearch,
      );
      final plan = await p.plan(query: 'وين عيادته؟', context: c);
      expect(plan.message, isNotEmpty);
      expect(RegExp(r'(عياد|غدير|موقع|علي)').hasMatch(plan.message), isTrue);
    });

    test('imaging neutrality: severity alone no MRI order', () {
      final msk = MskGuidanceCoordinator();
      expect(
        msk.imagingPolicy.severeAloneRequiresMri(
          msk.interpreter.interpret('ألم شديد بظهري').severity,
        ),
        isFalse,
      );
    });
  });

  group('PC-1.25 evidence / medication / diagnosis boundaries', () {
    test('dental evidence thresholds documented', () {
      expect(DentalRuleCatalog.oralLesionPersistenceDays, 14);
      expect(DentalRuleCatalog.avulsionUrgentWindowMinutes, 60);
      final lesion = DentalRuleCatalog().findById('dental_oral_lesion_persistence');
      expect(lesion?.hasEvidenceMetadata, isTrue);
    });

    test('pregnancy evidence windows centralized', () {
      expect(PregnancyEvidenceCatalog.gdmScreenStartWeek, isNonZero);
      expect(PregnancyEvidenceCatalog.firstTrimesterEndExclusive, isNonZero);
    });

    test('adolescent age bounds centralized', () {
      expect(AdolescentEvidenceCatalog.adolescenceMinAgeInclusive, 10);
      expect(AdolescentEvidenceCatalog.adolescenceMaxAgeInclusive, 19);
    });

    test('no antibiotic auto-prescribe language', () async {
      final dental = DentalGuidanceCoordinator();
      final r = await dental.handle(
        text: 'سني يوجعني اريد اموكسيسيلين',
        session: DentalSession.inactive,
      );
      expect(r.message.toLowerCase().contains('اموكسيسيلين 500'), isFalse);
      expect(dental.autonomouslyPrescribesAntibiotics(), isFalse);
    });
  });

  group('PC-1.25 privacy / mayHandle / failure / malformed / determinism', () {
    test('mayHandle does not mutate dental session', () {
      final dental = DentalGuidanceCoordinator();
      final s = const DentalSession(active: true, lastQuestionKey: 'q');
      dental.mayHandle(query: 'سني يوجعني', session: s);
      expect(s.active, isTrue);
      expect(s.lastQuestionKey, 'q');
    });

    test('mayHandle does not mutate msk/respiratory sessions', () {
      final msk = MskGuidanceCoordinator();
      final resp = RespiratoryGuidanceCoordinator();
      const ms = MskSession(active: true, lastQuestionKey: 'x');
      const rs = RespiratorySession(active: true, lastQuestionKey: 'y');
      msk.mayHandle(query: 'ظهري', session: ms);
      resp.mayHandle(query: 'سعال', session: rs);
      expect(ms.lastQuestionKey, 'x');
      expect(rs.lastQuestionKey, 'y');
    });

    test('privacy diagnostics after complex turn', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(
        query: 'اني حامل وابني عمره 15 وزوجتي سنها يوجعها',
        context: c,
      );
      final dump = c.unifiedBrainDiagnostics.toDebugMap().toString();
      expect(dump.contains('personId'), isFalse);
      expect(dump.contains('transcript'), isFalse);
      expect(RegExp(r'\b\d{2,3}/\d{2,3}\b').hasMatch(dump), isFalse);
    });

    test('failure isolation throwing dental', () async {
      final p = SmartBrainPlanner(
        doctorLookup: (_) async => <SmartSearchResult>[],
        labLookup: (_) async => <SmartSearchResult>[],
        dentalGuidance: _ThrowDental(),
      );
      final c = ConversationContext();
      final plan = await p.plan(query: 'ظهري يوجعني', context: c);
      expect(plan.message, isNotEmpty);
      expect(c.mskSession.active, isTrue);
    });

    test('malformed inputs no crash', () async {
      final p = planner();
      for (final q in ['', '   ', '!!!', '😀😀😀', 'ا' * 4000]) {
        final c = ConversationContext();
        final plan = await p.plan(query: q, context: c);
        expect(plan, isNotNull);
      }
    });

    test('Iraqi dialect aliases route MSK', () async {
      for (final q in [
        'ظهري يوجعني',
        'ضهري يوجعني',
        'عندي وجع بظهري',
      ]) {
        final c = ConversationContext();
        await planner().plan(query: q, context: c);
        expect(
          c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
          BrainAuthorityId.msk,
          reason: q,
        );
      }
    });

    test('determinism of primary selection', () {
      final brain = UnifiedBrainCoordinator();
      final turn = brain.buildTurn('عندي سعال وظهري يوجعني');
      final cands = [
        brain.arbitrator.classifyCandidate(
          authority: BrainAuthorityId.msk,
          turn: turn,
          mayHandle: true,
        ),
        brain.arbitrator.classifyCandidate(
          authority: BrainAuthorityId.respiratory,
          turn: turn,
          mayHandle: true,
        ),
      ];
      final a = brain.selectPrimary(turn, cands);
      final b = brain.selectPrimary(turn, cands);
      expect(a, b);
      expect(a, BrainAuthorityId.respiratory);
    });

    test('greeting performance: no clinical activation', () async {
      final c = ConversationContext();
      await planner().plan(query: 'مرحبا', context: c);
      expect(c.mskSession.active, isFalse);
      expect(c.dentalSession.active, isFalse);
      expect(c.pregnancyCompanionSession.active, isFalse);
      expect(c.respiratorySession.active, isFalse);
      expect(c.adolescentCompanionSession.active, isFalse);
    });
  });

  group('PC-1.25 long conversation stress', () {
    test('>=30 turn multi-domain stability', () async {
      final p = planner();
      final c = ConversationContext();
      final script = <String>[
        'اني حامل بالأسبوع 24',
        'وعندي سكر حمل',
        'ظهري يوجعني',
        'الألم متوسط',
        'ما عندي نزف',
        'خايفة',
        'وين مختبر الغدير؟',
        'ابني عمره 15 ومتوتر',
        'زوجتي سنها يوجعها',
        'ووجهها وارم',
        'لا ماكو ورم بالوجه بس اللثة',
        'اني هسه الألم خفيف',
        'عمري مو 15 اني بالغة',
        'ابني عنده امتحان',
        'ذكرني بعد أسبوع',
        'سني يوجعني',
        'عندي سعال',
        'اني حامل وعندي سعال',
        'شنو هو MRI؟',
        'أحتاج أشعة لظهري؟',
        'مرحبا',
        'بالنسبة لظهري بعده',
        'أمي ضغطها مرتفع',
        'لا مو إلي لابني السعال',
        'اي',
        'من البارحة',
        'شديد',
        'ماكو',
        'رتبلي يومي بسيط',
        'خلاص اترك الموضوع',
        'هسه ظهري يوجعني مرة ثانية',
      ];
      expect(script.length, greaterThanOrEqualTo(30));
      for (final q in script) {
        final plan = await p.plan(query: q, context: c);
        expect(plan, isNotNull);
        final dump = c.unifiedBrainDiagnostics.toDebugMap().toString();
        expect(dump.contains('personId'), isFalse);
      }
    });

    test('100 synthetic turns no crash / no unbounded pending', () async {
      final p = planner();
      final c = ConversationContext();
      final pool = [
        'ظهري يوجعني',
        'سعال خفيف',
        'سني يوجعني',
        'مرحبا',
        'وين مختبر الغدير؟',
        'اي',
        'لا',
        'متوسط',
        'ماكو',
        'اني حامل بالأسبوع 20',
        'ابني عمره 14 متوتر',
        'ذكرني',
        'خلاص',
      ];
      for (var i = 0; i < 100; i++) {
        final q = pool[i % pool.length];
        final plan = await p.plan(query: q, context: c);
        expect(plan, isNotNull);
        expect(
          (c.unifiedPendingClarificationKey?.length ?? 0) < 200,
          isTrue,
        );
      }
    });
  });

  group('PC-1.25 short replies / current-turn severity', () {
    test('current severity outranks stale severe', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'ظهري يوجعني ألم شديد', context: c);
      await p.plan(query: 'هسه صار خفيف', context: c);
      expect(c.mskSession.active, isTrue);
      // لا نطلب شدة من جديد إن ذُكرت
      final plan = await p.plan(query: 'هسه صار خفيف', context: c);
      expect(plan.message.contains('شديد ولا خفيف'), isFalse);
    });
  });
}

class ConversationHarness {
  static int clarificationCount(String message) {
    final marks = RegExp(r'[؟?]').allMatches(message).length;
    return marks;
  }
}

class _ThrowDental extends DentalGuidanceCoordinator {
  @override
  bool mayHandle({
    required String query,
    required DentalSession session,
  }) {
    throw StateError('simulated');
  }
}
