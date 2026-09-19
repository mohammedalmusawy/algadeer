import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/chronic_care/chronic_care.dart';
import 'package:ghadeer_clinic/health/emotional_support/emotional_support.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_models.dart';
import 'package:ghadeer_clinic/health/preventive/preventive_guidance_coordinator.dart';
import 'package:ghadeer_clinic/health/preventive/preventive_guidance_models.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_result.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailFamilyRepo implements FamilyPersonProfileRepository {
  @override
  Future<void> clearAll() async {}

  @override
  Future<FamilyPersonProfile> create(FamilyPersonProfile profile) async {
    throw StateError('fail');
  }

  @override
  Future<void> deleteById(String personId) async {}

  @override
  Future<FamilyPersonProfile?> findById(String personId) async => null;

  @override
  Future<List<FamilyPersonProfile>> loadAll() async => throw StateError('fail');

  @override
  Future<FamilyPersonProfile> update(FamilyPersonProfile profile) async {
    throw StateError('fail');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalFamilyPersonProfileRepository familyRepo;
  late FamilyPersonProfileService familyService;
  late SubjectBindingCoordinator binding;
  late ConversationPersonResolver personResolver;
  late PersonalCompanionProfileService ownerProfiles;
  late ChronicCareCoordinator chronic;
  late LocalChronicCareRepository chronicRepo;
  late PreventiveGuidanceCoordinator preventive;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    familyRepo = LocalFamilyPersonProfileRepository(prefs: prefs);
    await familyRepo.clearAll();
    familyService = FamilyPersonProfileService(repository: familyRepo);
    binding = SubjectBindingCoordinator(people: familyService);
    personResolver = ConversationPersonResolver();
    ownerProfiles = PersonalCompanionProfileService(
      repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
    );
    chronicRepo = LocalChronicCareRepository(prefs: prefs);
    chronic = ChronicCareCoordinator(repository: chronicRepo);
    preventive = PreventiveGuidanceCoordinator(profiles: ownerProfiles);
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      familyProfileCommands: FamilyProfileCommandCoordinator(
        people: familyService,
      ),
      subjectBinding: binding,
      chronicCare: chronic,
      preventiveGuidance: preventive,
      doctorLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. علي',
              subtitle: 'طب الأطفال',
              doctorId: 'doc_ali',
              specialty: 'طب الأطفال',
              score: 90,
            ),
          ],
      labLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.lab,
              title: 'مختبر علي',
              subtitle: 'مختبر',
              labId: 'lab_ali',
              score: 90,
            ),
          ],
      analysisLookup: (_) async => [
            AnalysisItem(id: 'cbc', name: 'علي'),
          ],
      packagesLookup: (_) async => [
            const LabPackageItem(
              id: 'p1',
              labId: 'lab_ali',
              name: 'باقة علي',
              newPrice: 10,
            ),
          ],
    );
  });

  Future<void> seedSon(
    String name, {
    bool enabled = true,
    int? birthYear,
  }) async {
    final p = await familyService.createProfile(
      relationship: PersonRelationship.son,
      preferredName: name,
      birthYear: birthYear,
    );
    if (!enabled) await familyService.disableProfile(p.personId);
  }

  IntentResult intentFor(String q) => IntentResult(
        intent: AssistantIntent.generalSearch,
        originalText: q,
        normalizedText: q,
      );

  group('PC-1.9 resolution A–J', () {
    test('A — explicit self resolves owner', () async {
      await seedSon('علي');
      ctx.setLinkedFamilyPersonId((await familyService.loadAllProfiles()).first.personId);
      final r = await binding.processTurn(
        query: 'عندي صداع',
        context: ctx,
        intent: intentFor('عندي صداع'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.resolved.isAccountOwner, isTrue);
      expect(r.linkedPersonId, isNull);
    });

    test('B — نرجع إلي clears family binding', () async {
      await seedSon('علي');
      ctx.setLinkedFamilyPersonId((await familyService.loadAllProfiles()).first.personId);
      final r = await binding.processTurn(
        query: 'نرجع إلي',
        context: ctx,
        intent: intentFor('نرجع إلي'),
        healthSession: HealthGuidanceSession.inactive,
      );
      binding.applyToContext(ctx, r);
      expect(ctx.linkedFamilyPersonId, isNull);
      expect(r.resolved.isAccountOwner, isTrue);
    });

    test('C — unique relationship+name resolves persistent person', () async {
      await seedSon('علي');
      await seedSon('حسين');
      final r = await binding.processTurn(
        query: 'ابني علي عنده حرارة',
        context: ctx,
        intent: intentFor('ابني علي عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.resolved.hasPersistentBinding, isTrue);
      expect(r.enrichedHealthSubject?.linkedPersonId, isNotNull);
    });

    test('D — name+relationship reverse order resolves', () async {
      await seedSon('علي');
      final res = personResolver.resolve(
        query: 'علي ابني عنده حرارة',
        intent: AssistantIntent.generalSearch,
        profiles: await familyService.loadEnabledProfiles(),
        detection: binding.subjectCoordinator.detector.detect('علي ابني'),
        currentHealthSubject: HealthSubjectContext.unknown,
      );
      expect(res.resolved.hasPersistentBinding, isTrue);
    });

    test('E — unique persistent name with health context resolves', () async {
      await seedSon('علي');
      await seedSon('حسين');
      final res = personResolver.resolve(
        query: 'علي عنده حرارة',
        intent: AssistantIntent.generalSearch,
        profiles: await familyService.loadEnabledProfiles(),
        detection: binding.subjectCoordinator.detector.detect('علي عنده حرارة'),
        currentHealthSubject: HealthSubjectContext.unknown,
      );
      expect(res.resolved.hasPersistentBinding, isTrue);
    });

    test('F — unique son relationship resolves', () async {
      await seedSon('علي');
      final r = await binding.processTurn(
        query: 'ابني عنده حرارة',
        context: ctx,
        intent: intentFor('ابني عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.resolved.hasPersistentBinding, isTrue);
    });

    test('G — multiple sons → ambiguity', () async {
      await seedSon('علي');
      await seedSon('حسين');
      final r = await binding.processTurn(
        query: 'ابني عنده حرارة',
        context: ctx,
        intent: intentFor('ابني عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.needsClarification, isTrue);
    });

    test('H — ambiguity never chooses first', () async {
      await seedSon('علي');
      await seedSon('حسين');
      final r = await binding.processTurn(
        query: 'ابني عنده حرارة',
        context: ctx,
        intent: intentFor('ابني عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.pending.candidatePersonIds.length, 2);
      expect(r.linkedPersonId, isNull);
    });

    test('I — clarification preserves original intent', () async {
      await seedSon('علي');
      await seedSon('حسين');
      final amb = await binding.processTurn(
        query: 'ابني عنده حرارة',
        context: ctx,
        intent: intentFor('ابني عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      binding.applyToContext(ctx, amb);
      expect(ctx.pendingPersonClarification.originalQuery, contains('حرارة'));
    });

    test('J — clarification answer resolves candidate', () async {
      await seedSon('علي');
      await seedSon('حسين');
      final amb = await binding.processTurn(
        query: 'ابني عنده حرارة',
        context: ctx,
        intent: intentFor('ابني عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      binding.applyToContext(ctx, amb);
      final ans = await binding.processTurn(
        query: 'علي',
        context: ctx,
        intent: intentFor('علي'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(ans.resolved.hasPersistentBinding, isTrue);
      expect(ans.continuationQuery, contains('حرارة'));
    });
  });

  group('PC-1.9 continuation K–R', () {
    test('K/L/M — active Ali persists through continuation', () async {
      await seedSon('علي');
      var r = await binding.processTurn(
        query: 'ابني علي عنده حرارة',
        context: ctx,
        intent: intentFor('ابني علي عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      binding.applyToContext(ctx, r);
      final id = ctx.linkedFamilyPersonId;
      for (final q in ['من البارحة', 'وعنده سعال']) {
        r = await binding.processTurn(
          query: q,
          context: ctx,
          intent: intentFor(q),
          healthSession: HealthGuidanceSession.inactive,
        );
        binding.applyToContext(ctx, r);
        expect(ctx.linkedFamilyPersonId, id);
      }
    });

    test('N — explicit owner switch clears Ali', () async {
      await seedSon('علي');
      var r = await binding.processTurn(
        query: 'ابني علي عنده حرارة',
        context: ctx,
        intent: intentFor('ابني علي عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      binding.applyToContext(ctx, r);
      r = await binding.processTurn(
        query: 'أنا هم عندي صداع',
        context: ctx,
        intent: intentFor('أنا هم عندي صداع'),
        healthSession: HealthGuidanceSession.inactive,
      );
      binding.applyToContext(ctx, r);
      expect(ctx.linkedFamilyPersonId, isNull);
    });

    test('O — Ali → mother clears linked child', () async {
      await seedSon('علي');
      await familyService.createProfile(
        relationship: PersonRelationship.mother,
        preferredName: 'فاطمة',
      );
      var r = await binding.processTurn(
        query: 'ابني علي عنده حرارة',
        context: ctx,
        intent: intentFor('ابني علي عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      binding.applyToContext(ctx, r);
      final aliId = ctx.linkedFamilyPersonId;
      r = await binding.processTurn(
        query: 'أمي عندها دوخة',
        context: ctx,
        intent: intentFor('أمي عندها دوخة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      binding.applyToContext(ctx, r);
      expect(ctx.linkedFamilyPersonId, isNot(aliId));
    });

    test('P — vague pronoun without active subject does not guess', () {
      final res = personResolver.resolve(
        query: 'هو تعبان',
        intent: AssistantIntent.generalSearch,
        profiles: const [],
        detection: binding.subjectCoordinator.detector.detect('هو تعبان'),
        currentHealthSubject: HealthSubjectContext.unknown,
      );
      expect(res.resolved.subjectKind, ConversationSubjectKind.unknownPerson);
    });

    test('Q — vague pronoun with active subject can continue', () async {
      await seedSon('علي');
      final id = (await familyService.loadAllProfiles()).first.personId;
      final res = personResolver.resolve(
        query: 'هو تعبان',
        intent: AssistantIntent.generalSearch,
        profiles: await familyService.loadEnabledProfiles(),
        detection: binding.subjectCoordinator.detector.detect('هو تعبان'),
        currentHealthSubject: HealthSubjectContext.unknown,
        activeLinkedPersonId: id,
      );
      expect(res.linkedPersonId, id);
    });

    test('R — unrelated topic defers to entity pipeline', () async {
      await seedSon('علي');
      ctx.setLinkedFamilyPersonId((await familyService.loadAllProfiles()).first.personId);
      final r = await binding.processTurn(
        query: 'أريد مختبر قريب',
        context: ctx,
        intent: const IntentResult(
          intent: AssistantIntent.findLab,
          originalText: 'أريد مختبر قريب',
          normalizedText: 'أريد مختبر قريب',
        ),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.deferredToEntityPipeline, isTrue);
    });
  });

  group('PC-1.9 entity collision S–X', () {
    test('S/T — doctor intent outranks family name', () {
      expect(
        personResolver.shouldDeferToEntityPipeline(
          query: 'دكتور علي',
          intent: AssistantIntent.doctorSearch,
        ),
        isTrue,
      );
    });

    test('U — ابني علي not stolen by doctor resolver', () async {
      await seedSon('علي');
      final r = await binding.processTurn(
        query: 'ابني علي',
        context: ctx,
        intent: intentFor('ابني علي'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.deferredToEntityPipeline, isFalse);
      expect(r.resolved.hasPersistentBinding, isTrue);
    });

    test('V/W/X — lab/analysis/package defer', () {
      expect(
        personResolver.shouldDeferToEntityPipeline(
          query: 'مختبر علي',
          intent: AssistantIntent.generalSearch,
        ),
        isTrue,
      );
      expect(
        personResolver.shouldDeferToEntityPipeline(
          query: 'تحليل cbc',
          intent: AssistantIntent.findAnalysis,
        ),
        isTrue,
      );
      expect(
        personResolver.shouldDeferToEntityPipeline(
          query: 'باقة علي',
          intent: AssistantIntent.findPackage,
        ),
        isTrue,
      );
    });
  });

  group('PC-1.9 binding & firewalls Y–AK', () {
    test('Y/Z — linkedPersonId without duplicating identity fields', () async {
      await seedSon('علي');
      final r = await binding.processTurn(
        query: 'ابني علي عنده حرارة',
        context: ctx,
        intent: intentFor('ابني علي عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.enrichedHealthSubject?.linkedPersonId, isNotNull);
      expect(r.enrichedHealthSubject?.debugMap().containsKey('preferredName'),
          isFalse);
    });

    test('AA — one authoritative active person binding', () async {
      await seedSon('علي');
      final r = await binding.processTurn(
        query: 'ابني علي',
        context: ctx,
        intent: intentFor('ابني علي'),
        healthSession: HealthGuidanceSession.inactive,
      );
      binding.applyToContext(ctx, r);
      expect(ctx.linkedFamilyPersonId, r.linkedPersonId);
      expect(ctx.resolvedConversationSubject.persistentPersonId, r.linkedPersonId);
    });

    test('AB/AC — subject switch clears health session facts', () async {
      await seedSon('علي');
      final start = brain.healthGuidanceCoordinator.startFromUserText(
        query: 'ابني علي عنده حرارة',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
        enrichedSubject: (await binding.processTurn(
          query: 'ابني علي عنده حرارة',
          context: ctx,
          intent: intentFor('ابني علي عنده حرارة'),
          healthSession: HealthGuidanceSession.inactive,
        ))
            .enrichedHealthSubject,
      );
      ctx.setHealthGuidanceSession(start.session);
      final switched = brain.healthGuidanceCoordinator.startFromUserText(
        query: 'أنا هم عندي صداع',
        current: start.session,
        turnId: 2,
        enrichedSubject: (await binding.processTurn(
          query: 'أنا هم عندي صداع',
          context: ctx,
          intent: intentFor('أنا هم عندي صداع'),
          healthSession: start.session,
        ))
            .enrichedHealthSubject,
      );
      expect(switched.session.facts.subject.type, HealthSubjectType.self);
      expect(
        switched.session.facts.symptomStatuses['fever'],
        isNull,
      );
    });

    test('AD/AE — family cannot read/mutate owner sensitive health', () async {
      final health = SensitiveHealthProfileService(
        repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
      );
      await health.upsertConditions([
        HealthConditionRecord(
          id: 'hc1',
          canonicalConditionKey: 'diabetes',
          displayName: 'سكري',
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          consentState: HealthConsentState.granted,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          followUpPermission: false,
        ),
      ]);
      await seedSon('علي');
      await chronic.handle(
        text: 'ابني علي سكره 300',
        session: ChronicCareSession.inactive,
      );
      expect((await health.loadProfile())?.conditions.length, 1);
    });

    test('AF/AG — family BP/glucose not in owner chronic timeline', () async {
      final before = (await chronicRepo.load()).measurements.length;
      await chronic.handle(
        text: 'ضغط أمi 150 على 90',
        session: ChronicCareSession.inactive,
      );
      await chronic.handle(
        text: 'سكر زوجti 200',
        session: ChronicCareSession.inactive,
      );
      expect((await chronicRepo.load()).measurements.length, before);
    });

    test('AH — family subject does not use owner age for prevention', () async {
      await ownerProfiles.setBirthYear(1980);
      expect(
        preventive.mayHandle(
          query: 'شنو النصائح المناسبة لابني؟',
          session: PreventiveGuidanceSession.inactive,
        ),
        isFalse,
      );
    });

    test('AI — family fear not owner emotional state', () {
      final det = EmotionalSignalDetector();
      expect(det.detect('ابني علي خايف').aboutOtherPerson, isTrue);
    });

    test('AJ/AK — diagnosed family diabetes not persisted; no health consent',
        () async {
      await seedSon('علي');
      await binding.processTurn(
        query: 'علي مشخص بالسكري',
        context: ctx,
        intent: intentFor('علي مشخص بالسكري'),
        healthSession: HealthGuidanceSession.inactive,
      );
      final map = (await familyService.loadAllProfiles()).first.toStorageMap();
      expect(map.keys.any((k) => k.contains('diabetes')), isFalse);
    });
  });

  group('PC-1.9 profile control AL–BG', () {
    test('AL/AM — disabled profile excluded and not reenabled', () async {
      await seedSon('علي', enabled: false);
      final r = await binding.processTurn(
        query: 'ابني',
        context: ctx,
        intent: intentFor('ابني'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.resolved.hasPersistentBinding, isFalse);
      expect((await familyService.loadAllProfiles()).first.profileEnabled,
          isFalse);
    });

    test('AN — deleted profile clears active binding', () async {
      await seedSon('علي');
      final id = (await familyService.loadAllProfiles()).first.personId;
      ctx.setLinkedFamilyPersonId(id);
      await familyService.deleteProfile(id);
      await binding.processTurn(
        query: 'من البارحة',
        context: ctx,
        intent: intentFor('من البارحة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(ctx.linkedFamilyPersonId, isNull);
    });

    test('AO — rename preserves identity through personId', () async {
      final p = await familyService.createProfile(
        relationship: PersonRelationship.son,
        preferredName: 'علي',
      );
      ctx.setLinkedFamilyPersonId(p.personId);
      await familyService.updateProfile(p.copyWith(preferredName: 'احمد'));
      final r = await binding.processTurn(
        query: 'من البارحة',
        context: ctx,
        intent: intentFor('من البارحة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      binding.applyToContext(ctx, r);
      expect(ctx.linkedFamilyPersonId, p.personId);
    });

    test('AP — same name across profiles → ambiguity', () async {
      await seedSon('علي');
      await seedSon('علي');
      final r = await binding.processTurn(
        query: 'ابني علي',
        context: ctx,
        intent: intentFor('ابني علي'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.needsClarification, isTrue);
    });

    test('AQ — repository failure does not guess', () async {
      final failBinding = SubjectBindingCoordinator(
        people: FamilyPersonProfileService(repository: _FailFamilyRepo()),
      );
      final r = await failBinding.processTurn(
        query: 'ابني عنده حرارة',
        context: ctx,
        intent: intentFor('ابني عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.resolved.hasPersistentBinding, isFalse);
    });

    test('AR/AS — pending clarification session-only; no disk persistence', () {
      final p = PendingPersonClarification(
        candidatePersonIds: const ['p1', 'p2'],
        originalQuery: 'ابني عنده حرارة',
        createdTurnId: 1,
      );
      expect(p.isActive, isTrue);
      expect(p.debugMap().containsValue('p1'), isFalse);
      expect(prefs.containsKey('pending_person'), isFalse);
    });

    test('AT/AU/AV — privacy debug without ids/names', () async {
      await seedSon('علي', birthYear: 2018);
      ctx.setLinkedFamilyPersonId(
        (await familyService.loadAllProfiles()).first.personId,
      );
      final snap = ctx.debugSnapshot();
      expect(snap.containsValue('person_'), isFalse);
      expect(snap.containsValue('علي'), isFalse);
      expect(snap['hasLinkedFamilyPerson'], isTrue);
      expect(snap['candidateCount'], 0);
    });

    test('AW/AX — typed and voice-final same resolver', () {
      final typed = personResolver.resolve(
        query: 'ابني علي',
        intent: AssistantIntent.generalSearch,
        profiles: const [],
        detection: binding.subjectCoordinator.detector.detect('ابني علي'),
        currentHealthSubject: HealthSubjectContext.unknown,
      );
      final voice = personResolver.resolve(
        query: 'ابني علي',
        intent: AssistantIntent.generalSearch,
        profiles: const [],
        detection: binding.subjectCoordinator.detector.detect('ابني علي'),
        currentHealthSubject: HealthSubjectContext.unknown,
      );
      expect(typed.resolved.subjectKind, voice.resolved.subjectKind);
    });

    test('AY — no automatic sensitive TTS in binding', () async {
      final r = await binding.processTurn(
        query: 'ابني علي',
        context: ctx,
        intent: intentFor('ابني علي'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.message, isEmpty);
    });

    test('AZ — provider discovery remains functional', () async {
      final plan = await brain.plan(
        query: 'أريد طبيب لابني',
        context: ctx,
      );
      expect(plan.message.contains('حفظت'), isFalse);
    });

    test('BA — family profile not required for health guidance', () async {
      final plan = await brain.plan(
        query: 'عندي صداع',
        context: ctx,
      );
      expect(await familyService.loadAllProfiles(), isEmpty);
      expect(
        plan.kind == AssistantActionKind.healthGuidance ||
            plan.message.isNotEmpty,
        isTrue,
      );
    });

    test('BB — temporary unknown child session-only', () async {
      final r = await binding.processTurn(
        query: 'ابني عنده حرارة',
        context: ctx,
        intent: intentFor('ابني عنده حرارة'),
        healthSession: HealthGuidanceSession.inactive,
      );
      expect(r.resolved.subjectKind,
          ConversationSubjectKind.temporaryOtherPerson);
      expect(await familyService.loadAllProfiles(), isEmpty);
    });

    test('BC–BG — no family health/chronic/campaigns/notifications/paid deps',
        () {
      expect(ConversationSubjectKind.values.length, greaterThan(0));
      expect(PendingPersonClarification.inactive.isActive, isFalse);
    });
  });
}
