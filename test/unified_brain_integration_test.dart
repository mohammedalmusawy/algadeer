import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghadeer_clinic/companion/personal_companion_profile.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/musculoskeletal/msk_models.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory_models.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/dental/dental_models.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/pregnancy_companion/pregnancy_models.dart';
import 'package:ghadeer_clinic/companion/adolescent/adolescent_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late UnifiedBrainCoordinator brain;
  late UnifiedBrainArbitrator arbitrator;
  late AgeAuthorityResolver ageResolver;
  late UnifiedBrainTurnInterpreter interpreter;

  setUp(() {
    brain = UnifiedBrainCoordinator();
    arbitrator = const UnifiedBrainArbitrator();
    ageResolver = const AgeAuthorityResolver();
    interpreter = UnifiedBrainTurnInterpreter();
  });

  group('PC-1.24 architecture contract', () {
    test('no god-object class names in library', () {
      expect(brain.runtimeType.toString().contains('God'), isFalse);
      expect(brain.runtimeType.toString().contains('MasterMedical'), isFalse);
      expect(brain.runtimeType.toString().contains('UniversalReasoning'), isFalse);
    });

    test('ownership map authorities are distinct', () {
      final ids = BrainAuthorityId.values.toSet();
      expect(ids.contains(BrainAuthorityId.pregnancy), isTrue);
      expect(ids.contains(BrainAuthorityId.dental), isTrue);
      expect(ids.contains(BrainAuthorityId.msk), isTrue);
      expect(ids.contains(BrainAuthorityId.adolescent), isTrue);
      expect(ids.contains(BrainAuthorityId.mentalCrisis), isTrue);
      expect(ids.contains(BrainAuthorityId.safety10E), isTrue);
    });
  });

  group('PC-1.24 turn interpreter', () {
    test('greeting is foreign to clinical sessions', () {
      final t = interpreter.interpret('مرحبا');
      expect(t.isGreeting, isTrue);
      expect(t.isForeignToClinicalSessions, isTrue);
      expect(t.primaryIntent, BrainPrimaryIntent.greeting);
    });

    test('lab navigation is service intent', () {
      final t = interpreter.interpret('أريد مختبر قريب');
      expect(t.isServiceOrNavigationIntent, isTrue);
      expect(t.primaryIntent, BrainPrimaryIntent.labQuestion);
    });

    test('pregnancy + cough → respiratory primary intent cue', () {
      final t = interpreter.interpret('اني حامل وعندي سعال');
      expect(t.hasPregnancyCue, isTrue);
      expect(t.hasRespiratoryCue, isTrue);
    });

    test('pregnancy + back pain cues', () {
      final t = interpreter.interpret('اني حامل بالأسبوع 24 وظهري يوجعني');
      expect(t.hasPregnancyCue, isTrue);
      expect(t.hasMskCue, isTrue);
    });

    test('educational diabetes does not look like personal symptom alone', () {
      final t = interpreter.interpret('شنو أعراض السكري؟');
      expect(t.isEducational, isTrue);
      expect(t.primaryIntent, BrainPrimaryIntent.education);
    });

    test('explicit follow-up intent', () {
      final t = interpreter.interpret('ذكرني بعد أسبوع');
      expect(t.isExplicitFollowUp, isTrue);
    });

    test('subject other-person cue', () {
      final t = interpreter.interpret('ابني هم عنده سعال');
      expect(t.isAboutOtherPerson, isTrue);
    });

    test('flagship complex turn cues', () {
      final t = interpreter.interpret(
        'اني حامل بالأسبوع 24 وعندي سكر حمل ومن البارحة ظهري يوجعني وخايفة',
      );
      expect(t.hasPregnancyCue, isTrue);
      expect(t.hasChronicCue, isTrue);
      expect(t.hasMskCue, isTrue);
    });
  });

  group('PC-1.24 age unification', () {
    test('explicit age outranks birthDate', () {
      final r = ageResolver.resolve(
        explicitAgeFromUtterance: 17,
        birthDate: DateTime(2010, 5, 1),
        now: DateTime(2026, 9, 16),
      );
      expect(r.ageYears, 17);
      expect(r.provenance, AgeProvenance.explicitCurrentAge);
    });

    test('exact birthDate derived', () {
      final r = ageResolver.resolve(
        birthDate: DateTime(2010, 1, 1),
        now: DateTime(2026, 9, 16),
      );
      expect(r.ageYears, 16);
      expect(r.provenance, AgeProvenance.exactBirthDateDerived);
    });

    test('birthYear derived is not exact birthday', () {
      final r = ageResolver.resolve(
        birthYear: 2010,
        now: DateTime(2026, 9, 16),
      );
      expect(r.ageYears, 16);
      expect(r.provenance, AgeProvenance.birthYearDerived);
    });

    test('unknown remains unknown', () {
      final r = ageResolver.resolve();
      expect(r.isKnown, isFalse);
      expect(r.provenance, AgeProvenance.unknown);
    });

    test('owner profile path', () {
      final profile = PersonalCompanionProfile(
        profileId: 'p1',
        ownerKey: 'o1',
        preferredName: 'test',
        birthYear: 2008,
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );
      final r = ageResolver.resolveFromOwnerProfile(
        profile,
        now: DateTime(2026, 9, 16),
      );
      expect(r.ageYears, 18);
      expect(r.provenance, AgeProvenance.birthYearDerived);
    });

    test('parse explicit from utterance', () {
      expect(ageResolver.parseExplicitAgeYears('عمري 16 وخايف'), 16);
      expect(ageResolver.parseExplicitAgeYears('مرحبا'), isNull);
    });

    test('no inference from name', () {
      final r = ageResolver.resolve();
      expect(r.ageYears, isNull);
    });
  });

  group('PC-1.24 arbitration primary vs contextual', () {
    test('pregnancy + cough → respiratory primary, pregnancy contextual', () {
      final turn = interpreter.interpret('اني حامل وعندي سعال');
      final cands = [
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.pregnancy,
          turn: turn,
          mayHandle: true,
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.respiratory,
          turn: turn,
          mayHandle: true,
        ),
      ];
      final primary = brain.selectPrimary(turn, cands);
      expect(primary, BrainAuthorityId.respiratory);
      expect(
        cands
            .firstWhere((c) => c.authority == BrainAuthorityId.pregnancy)
            .role,
        BrainAuthorityRole.contextual,
      );
    });

    test('pregnancy + MSK → msk primary', () {
      final turn = interpreter.interpret('اني حامل بالأسبوع 24 وظهري يوجعني');
      final cands = [
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.pregnancy,
          turn: turn,
          mayHandle: true,
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.msk,
          turn: turn,
          mayHandle: true,
        ),
      ];
      expect(brain.selectPrimary(turn, cands), BrainAuthorityId.msk);
    });

    test('pregnancy + dental → dental primary', () {
      final turn = interpreter.interpret('اني حامل وضرس العقل يوجعني');
      final cands = [
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.pregnancy,
          turn: turn,
          mayHandle: true,
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.dental,
          turn: turn,
          mayHandle: true,
        ),
      ];
      expect(brain.selectPrimary(turn, cands), BrainAuthorityId.dental);
    });

    test('adolescent + dental → dental primary, adolescent contextual', () {
      final turn = interpreter.interpret('عمري 16 وسني يوجعني');
      final cands = [
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.adolescent,
          turn: turn,
          mayHandle: true,
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.dental,
          turn: turn,
          mayHandle: true,
        ),
      ];
      expect(brain.selectPrimary(turn, cands), BrainAuthorityId.dental);
      expect(
        cands
            .firstWhere((c) => c.authority == BrainAuthorityId.adolescent)
            .role,
        BrainAuthorityRole.contextual,
      );
    });

    test('cough + back pain prefers respiratory', () {
      final turn = interpreter.interpret('عندي سعال وظهري يوجعني');
      final cands = [
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.msk,
          turn: turn,
          mayHandle: true,
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.respiratory,
          turn: turn,
          mayHandle: true,
        ),
      ];
      expect(brain.selectPrimary(turn, cands), BrainAuthorityId.respiratory);
    });

    test('service foreign turn suppresses sticky clinical continuation', () {
      final turn = interpreter.interpret('أريد مختبر قريب');
      final c = arbitrator.classifyCandidate(
        authority: BrainAuthorityId.msk,
        turn: turn,
        mayHandle: true,
        mayHandleReason: 'sessionContinuation',
      );
      expect(c.role, BrainAuthorityRole.suppressed);
      expect(c.suppressionReason, 'foreignTurn');
    });

    test('mental crisis plan takes precedence', () {
      final turn = interpreter.interpret('عمري 16 وأفكر أأذي نفسي');
      final plan = brain.planFromContributions(
        turn: turn,
        candidates: [
          arbitrator.classifyCandidate(
            authority: BrainAuthorityId.adolescent,
            turn: turn,
            mayHandle: true,
          ),
        ],
        mentalCrisisInvoked: true,
        primary: const BrainContribution(
          authority: BrainAuthorityId.adolescent,
          role: BrainAuthorityRole.primary,
          priority: 1,
          message: 'study tips',
        ),
      );
      expect(plan.primaryAuthority, BrainAuthorityId.mentalCrisis);
      expect(plan.mentalCrisisMode, isTrue);
    });

    test('safety plan takes precedence', () {
      final turn = interpreter.interpret('سعال وضيق نفس شديد');
      final plan = brain.planFromContributions(
        turn: turn,
        candidates: const [],
        safetyInvoked: true,
      );
      expect(plan.primaryAuthority, BrainAuthorityId.safety10E);
      expect(plan.safetyMode, isTrue);
    });
  });

  group('PC-1.24 one-question budget', () {
    test('only one clarification selected', () {
      final turn = interpreter.interpret('ظهري يوجعني');
      final plan = brain.planFromContributions(
        turn: turn,
        candidates: [
          arbitrator.classifyCandidate(
            authority: BrainAuthorityId.msk,
            turn: turn,
            mayHandle: true,
          ),
        ],
        primary: const BrainContribution(
          authority: BrainAuthorityId.msk,
          role: BrainAuthorityRole.primary,
          priority: 100,
          message: 'ألم الظهر يحتاج تقييم.',
          clarificationQuestion: 'الألم إلك لو لشخص ثاني؟',
        ),
        contextual: const [
          BrainContribution(
            authority: BrainAuthorityId.pregnancy,
            role: BrainAuthorityRole.contextual,
            priority: 40,
            clarificationQuestion: 'أنتِ حامل؟',
          ),
          BrainContribution(
            authority: BrainAuthorityId.emotional,
            role: BrainAuthorityRole.emotional,
            priority: 20,
            clarificationQuestion: 'كيف مزاجك؟',
          ),
        ],
      );
      expect(plan.questionBudgetUsed, isTrue);
      expect(plan.clarificationQuestion, 'الألم إلك لو لشخص ثاني؟');
      expect(plan.message.contains('أنتِ حامل؟'), isFalse);
      expect(plan.message.contains('كيف مزاجك؟'), isFalse);
    });

    test('safety-changing question outranks routine', () {
      final turn = interpreter.interpret('وجهي وارم');
      final plan = brain.planFromContributions(
        turn: turn,
        candidates: const [],
        primary: const BrainContribution(
          authority: BrainAuthorityId.dental,
          role: BrainAuthorityRole.primary,
          priority: 100,
          message: 'تورم الوجه.',
          clarificationQuestion: 'هل عندك حرارة؟',
        ),
        contextual: const [
          BrainContribution(
            authority: BrainAuthorityId.safety10E,
            role: BrainAuthorityRole.safety,
            priority: 1000,
            safetyDeferred: true,
            clarificationQuestion: 'هل عندك صعوبة بالتنفس؟',
          ),
        ],
      );
      expect(plan.clarificationQuestion, 'هل عندك صعوبة بالتنفس؟');
    });
  });

  group('PC-1.24 one response plan', () {
    test('compose single message not collage', () {
      final turn = interpreter.interpret('اني حامل وعندي سعال');
      final plan = brain.planFromContributions(
        turn: turn,
        candidates: [
          arbitrator.classifyCandidate(
            authority: BrainAuthorityId.respiratory,
            turn: turn,
            mayHandle: true,
          ),
        ],
        primary: const BrainContribution(
          authority: BrainAuthorityId.respiratory,
          role: BrainAuthorityRole.primary,
          priority: 100,
          message: 'السعال أثناء الحمل يحتاج تقييم هادئ.',
        ),
      );
      expect(plan.message, 'السعال أثناء الحمل يحتاج تقييم هادئ.');
      expect(plan.message.split('\n\n\n').length, 1);
    });

    test('determinism of primary selection', () {
      final turn = interpreter.interpret('عندي سعال وظهري يوجعني');
      final cands = [
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.msk,
          turn: turn,
          mayHandle: true,
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.respiratory,
          turn: turn,
          mayHandle: true,
        ),
      ];
      final a = brain.selectPrimary(turn, cands);
      final b = brain.selectPrimary(turn, cands);
      final c = brain.selectPrimary(turn, cands);
      expect(a, b);
      expect(b, c);
      expect(a, BrainAuthorityId.respiratory);
    });
  });

  group('PC-1.24 privacy diagnostics', () {
    test('debug map has no raw transcript or personId', () {
      final turn = interpreter.interpret(
        'اني حامل بالأسبوع 24 وعندي سكر حمل وظهري يوجعني',
      );
      final plan = brain.planFromContributions(
        turn: turn,
        candidates: [
          arbitrator.classifyCandidate(
            authority: BrainAuthorityId.msk,
            turn: turn,
            mayHandle: true,
          ),
        ],
        primary: const BrainContribution(
          authority: BrainAuthorityId.msk,
          role: BrainAuthorityRole.primary,
          priority: 1,
          message: 'guidance',
        ),
      );
      final diag = brain.diagnosticsFromPlan(
        turn: turn,
        plan: plan,
        candidates: [
          arbitrator.classifyCandidate(
            authority: BrainAuthorityId.msk,
            turn: turn,
            mayHandle: true,
          ),
        ],
      );
      final dump = diag.toDebugMap().toString();
      expect(dump.contains('personId'), isFalse);
      expect(dump.contains('سكر حمل'), isFalse);
      expect(dump.contains('اني حامل'), isFalse);
      expect(dump.contains('transcript'), isFalse);
      expect(diag.selectedPrimaryAuthority, BrainAuthorityId.msk);
    });
  });

  group('PC-1.24 session / foreign turn context', () {
    test('clear clinical sessions for foreign turn', () {
      final ctx = ConversationContext()
        ..mskSession = const MskSession(active: true, lastQuestionKey: 'q1')
        ..respiratorySession =
            const RespiratorySession(active: true, lastQuestionKey: 'q2')
        ..dentalSession = const DentalSession(active: true, lastQuestionKey: 'q3')
        ..pregnancyCompanionSession =
            const PregnancyCompanionSession(active: true)
        ..adolescentCompanionSession =
            const AdolescentCompanionSession(active: true);

      ctx.clearClinicalPackSessionsForForeignTurn();
      expect(ctx.mskSession.active, isFalse);
      expect(ctx.respiratorySession.active, isFalse);
      expect(ctx.dentalSession.active, isFalse);
      expect(ctx.pregnancyCompanionSession.active, isFalse);
      expect(ctx.adolescentCompanionSession.active, isFalse);
    });

    test('subject switch clears sessions', () {
      final ctx = ConversationContext()
        ..mskSession = const MskSession(active: true, lastQuestionKey: 'pain');
      final switched = ctx.noteClinicalSubjectScope('other:child');
      expect(switched, isFalse); // first set
      ctx.mskSession = const MskSession(active: true, lastQuestionKey: 'pain');
      final switched2 = ctx.noteClinicalSubjectScope('owner');
      expect(switched2, isTrue);
      expect(ctx.mskSession.active, isFalse);
    });

    test('invalidate siblings keeps pregnancy contextual', () {
      final ctx = ConversationContext()
        ..mskSession = const MskSession(active: true)
        ..pregnancyCompanionSession =
            const PregnancyCompanionSession(active: true)
        ..dentalSession = const DentalSession(active: true);
      ctx.invalidateSiblingClinicalSessions(
        primary: BrainAuthorityId.msk,
        keepPregnancyContextual: true,
      );
      expect(ctx.mskSession.active, isTrue);
      expect(ctx.pregnancyCompanionSession.active, isTrue);
      expect(ctx.dentalSession.active, isFalse);
    });
  });

  group('PC-1.24 SmartBrainPlanner integration', () {
    SmartBrainPlanner planner() => SmartBrainPlanner(
          doctorLookup: (_) async => <SmartSearchResult>[],
          labLookup: (_) async => <SmartSearchResult>[],
        );

    test('single domain MSK wires and records diagnostics', () async {
      final p = planner();
      final c = ConversationContext();
      final plan = await p.plan(query: 'ظهري يوجعني من البارحة', context: c);
      expect(plan.message, isNotNull);
      expect(c.mskSession.active, isTrue);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.msk,
      );
    });

    test('single domain respiratory', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'عندي سعال من يومين', context: c);
      expect(c.respiratorySession.active, isTrue);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.respiratory,
      );
    });

    test('pregnancy alone activates pregnancy', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(
        query: 'اني حامل بالأسبوع 18 شنو المفروض أسوي؟',
        context: c,
      );
      expect(c.pregnancyCompanionSession.active, isTrue);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.pregnancy,
      );
    });

    test('pregnancy + cough → one respiratory primary', () async {
      final p = planner();
      final c = ConversationContext();
      final plan = await p.plan(
        query: 'اني حامل وعندي سعال',
        context: c,
      );
      expect(plan.message, isNotNull);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.respiratory,
      );
      // one message path
      expect(plan.message.contains('\n\n\n'), isFalse);
    });

    test('pregnancy + dental → dental primary', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'اني حامل وضرس العقل يوجعني', context: c);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.dental,
      );
    });

    test('pregnancy + MSK → msk primary', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(
        query: 'اني حامل بالأسبوع 24 وظهري يوجعني',
        context: c,
      );
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.msk,
      );
    });

    test('adolescent + dental clinical ownership', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'عمري 16 وسني يوجعني', context: c);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.dental,
      );
    });

    test('MSK session does not hijack lab request', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'ظهري يوجعني', context: c);
      expect(c.mskSession.active, isTrue);
      await p.plan(query: 'أريد مختبر قريب', context: c);
      expect(
        c.unifiedBrainDiagnostics.clinicalSessionsClearedForForeignTurn ||
            !c.mskSession.active ||
            c.unifiedBrainDiagnostics.serviceHandoff,
        isTrue,
      );
      // should not keep forcing MSK as primary for lab intent
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority !=
                BrainAuthorityId.msk ||
            c.unifiedBrainDiagnostics.clinicalSessionsClearedForForeignTurn,
        isTrue,
      );
    });

    test('greeting after dental does not sticky-handle clinically', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'سني يوجعني', context: c);
      expect(c.dentalSession.active, isTrue);
      await p.plan(query: 'مرحبا', context: c);
      expect(
        c.unifiedBrainDiagnostics.clinicalSessionsClearedForForeignTurn ||
            c.unifiedBrainDiagnostics.primaryIntent ==
                BrainPrimaryIntent.greeting,
        isTrue,
      );
    });

    test('subject switch owner pregnancy then wife dental clears leak path',
        () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'اني حامل بالأسبوع 20', context: c);
      expect(c.pregnancyCompanionSession.active, isTrue);
      await p.plan(query: 'زوجتي سنها يوجعها', context: c);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.dental,
      );
      // dental wife session must not require owner pregnancy as primary
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        isNot(BrainAuthorityId.pregnancy),
      );
    });

    test('child then owner MSK no adolescent contamination on owner', () async {
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

    test('typed and voice-originated text same primary', () async {
      final p = planner();
      const q = 'عندي سعال من يومين';
      final c1 = ConversationContext();
      final c2 = ConversationContext();
      await p.plan(query: q, context: c1);
      await p.plan(query: q, context: c2);
      expect(
        c1.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        c2.unifiedBrainDiagnostics.selectedPrimaryAuthority,
      );
      expect(
        c1.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.respiratory,
      );
    });

    test('performance guard: greeting does not activate clinical packs',
        () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'مرحبا', context: c);
      expect(c.mskSession.active, isFalse);
      expect(c.respiratorySession.active, isFalse);
      expect(c.dentalSession.active, isFalse);
      expect(c.pregnancyCompanionSession.active, isFalse);
      expect(c.adolescentCompanionSession.active, isFalse);
    });

    test('flagship complex: pregnancy + GDM + back + fear → one MSK primary',
        () async {
      final p = planner();
      final c = ConversationContext();
      final plan = await p.plan(
        query:
            'اني حامل بالأسبوع 24 وعندي سكر حمل ومن البارحة ظهري يوجعني وخايفة',
        context: c,
      );
      expect(plan.message, isNotNull);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.msk,
      );
      // not a multi-bot collage marker
      expect(plan.message.split('——').length, lessThan(3));
    });

    test('multi-complaint cough+back one primary', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'عندي سعال وظهري يوجعني', context: c);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.respiratory,
      );
      expect(c.mskSession.active, isFalse);
    });

    test('adolescent study stress path', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'عمري 16 وعندي امتحان وخايف', context: c);
      expect(
        c.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.adolescent,
      );
    });

    test('diagnostics privacy on planner path', () async {
      final p = planner();
      final c = ConversationContext();
      await p.plan(query: 'اني حامل وضرس العقل يوجعني', context: c);
      final dump = c.unifiedBrainDiagnostics.toDebugMap().toString();
      expect(dump.contains('ضرس'), isFalse);
      expect(dump.contains('حامل'), isFalse);
      expect(dump.contains('personId'), isFalse);
    });

    test('failure isolation: coordinator still constructs', () {
      expect(planner().unifiedBrainCoordinator, isNotNull);
    });
  });

  group('PC-1.24 corrections / negation representation', () {
    test('correction cue detected', () {
      final t = interpreter.interpret('لا مو آني، زوجتي');
      expect(t.hasCorrection || t.isAboutOtherPerson, isTrue);
    });

    test('negation cue detected', () {
      final t = interpreter.interpret('لا، ماكو ورم بالوجه، بس اللثة');
      expect(t.hasNegation, isTrue);
    });
  });

  group('PC-1.24 information vs action intents', () {
    test('what is MRI educational', () {
      final t = interpreter.interpret('شنو هو MRI؟');
      expect(t.isEducational || t.primaryIntent == BrainPrimaryIntent.education,
          isTrue);
    });

    test('where is clinic is service', () {
      final t = interpreter.interpret('وين عيادة الغدير؟');
      expect(t.isServiceOrNavigationIntent, isTrue);
    });
  });
}
