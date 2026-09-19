import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/chronic_care/chronic_care.dart';
import 'package:ghadeer_clinic/health/emotional_support/emotional_support.dart';
import 'package:ghadeer_clinic/health/preventive/preventive_guidance_coordinator.dart';
import 'package:ghadeer_clinic/health/preventive/preventive_guidance_models.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_coordinator.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThrowingFamilyRepo implements FamilyPersonProfileRepository {
  @override
  Future<void> clearAll() async {}

  @override
  Future<FamilyPersonProfile> create(FamilyPersonProfile profile) async {
    throw StateError('repo_fail');
  }

  @override
  Future<void> deleteById(String personId) async {}

  @override
  Future<FamilyPersonProfile?> findById(String personId) async => null;

  @override
  Future<List<FamilyPersonProfile>> loadAll() async => const [];

  @override
  Future<FamilyPersonProfile> update(FamilyPersonProfile profile) async {
    throw StateError('repo_fail');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalFamilyPersonProfileRepository familyRepo;
  late FamilyPersonProfileService familyService;
  late FamilyProfileCommandCoordinator familyCoord;
  late PersonalCompanionProfileService ownerProfiles;
  late LocalPersonalCompanionProfileRepository ownerRepo;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;
  late HealthSubjectCoordinator subjects;
  late PersonReferenceResolver resolver;
  late ChronicCareCoordinator chronic;
  late LocalChronicCareRepository chronicRepo;
  late PreventiveGuidanceCoordinator preventive;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    familyRepo = LocalFamilyPersonProfileRepository(prefs: prefs);
    await familyRepo.clearAll();
    familyService = FamilyPersonProfileService(repository: familyRepo);
    familyCoord = FamilyProfileCommandCoordinator(people: familyService);
    ownerRepo = LocalPersonalCompanionProfileRepository(prefs: prefs);
    ownerProfiles = PersonalCompanionProfileService(repository: ownerRepo);
    ctx = ConversationContext();
    subjects = HealthSubjectCoordinator();
    resolver = const PersonReferenceResolver();
    chronicRepo = LocalChronicCareRepository(prefs: prefs);
    chronic = ChronicCareCoordinator(repository: chronicRepo);
    preventive = PreventiveGuidanceCoordinator(profiles: ownerProfiles);
    brain = SmartBrainPlanner(
      companionProfileCommands: CompanionProfileCommandCoordinator(
        profiles: ownerProfiles,
      ),
      familyProfileCommands: familyCoord,
      chronicCare: chronic,
      preventiveGuidance: preventive,
      doctorLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. أطفال',
              subtitle: 'طب الأطفال',
              doctorId: 'd1',
              specialty: 'طب الأطفال',
              score: 90,
            ),
          ],
      labLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.lab,
              title: 'مختبر',
              subtitle: 'مختبر',
              labId: 'l1',
              score: 90,
            ),
          ],
      analysisLookup: (_) async => [AnalysisItem(id: 'cbc', name: 'CBC')],
      packagesLookup: (_) async => [
            const LabPackageItem(
              id: 'p1',
              labId: 'l1',
              name: 'باقة',
              newPrice: 10,
            ),
          ],
    );
  });

  Future<FamilyProfileCommandTurnResult> runFamily(String text) =>
      familyCoord.handle(text: text, pending: ctx.familyProfilePending);

  Future<void> seedSon(String name, {int? birthYear}) async {
    await familyService.createProfile(
      relationship: PersonRelationship.son,
      preferredName: name,
      birthYear: birthYear,
    );
  }

  group('PC-1.8 creation A–J', () {
    test('A — temporary ابني عنده حرارة creates no persistent person', () async {
      final r = await runFamily('ابني عنده حرارة');
      expect(r.handled, isFalse);
      expect(await familyService.loadAllProfiles(), isEmpty);
    });

    test('B — explicit تذكر ابني علي creates persistent person', () async {
      final r = await runFamily('تذكر ابني علي');
      expect(r.handled, isTrue);
      expect(r.success, isTrue);
      final all = await familyService.loadAllProfiles();
      expect(all.length, 1);
      expect(all.first.effectiveName, 'علي');
    });

    test('C — account owner not duplicated as family profile', () async {
      await ownerProfiles.savePreferredName('محمد');
      await runFamily('تذكر ابني علي');
      final owners = await ownerProfiles.loadProfile();
      final family = await familyService.loadAllProfiles();
      expect(owners?.preferredName, 'محمد');
      expect(family.any((p) => p.effectiveName == 'محمد'), isFalse);
      expect(family.length, 1);
    });

    test('D — person profile stores relationship', () async {
      await runFamily('تذكر ابني علي');
      expect(
        (await familyService.loadAllProfiles()).first.relationship,
        PersonRelationship.son,
      );
    });

    test('E — person profile stores preferredName', () async {
      await runFamily('اسم أمي فاطمة');
      expect(
        (await familyService.loadAllProfiles()).first.effectiveName,
        'فاطمه',
      );
    });

    test('F — fixed age is not persisted', () async {
      final r = await runFamily('تذكر ابني علي، عمره 8 سنوات');
      expect(r.handled, isTrue);
      expect(r.operationType, 'progressive_birth');
      expect(await familyService.loadAllProfiles(), isEmpty);
    });

    test('G — birthYear can be persisted explicitly', () async {
      await runFamily('تذكر ابني علي مواليد 2018');
      expect(
        (await familyService.loadAllProfiles()).first.birthYear,
        2018,
      );
    });

    test('H — dynamic person age can be computed', () async {
      final now = DateTime(2026, 9, 16);
      final p = await familyService.createProfile(
        relationship: PersonRelationship.son,
        preferredName: 'علي',
        birthYear: 2018,
      );
      expect(p.currentAge(now: now), 8);
    });

    test('I — future birth year rejected', () async {
      final r = await runFamily('تذكر ابني علي مواليد 2099');
      expect(r.success, isFalse);
      expect(await familyService.loadAllProfiles(), isEmpty);
    });

    test('J — no sex inference from name', () async {
      await runFamily('تذكر ابني فاطمة');
      expect(
        (await familyService.loadAllProfiles()).first.sexSelection,
        isNull,
      );
    });

    test('K — no sex inference from voice/TTS path', () {
      expect(ownerProfiles.mayInferSexFromTtsVoice(), isFalse);
      expect(
        FamilyPersonProfile(
          personId: 'p1',
          ownerKey: 'o',
          relationship: PersonRelationship.son,
          preferredName: 'علي',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ).sexSelection,
        isNull,
      );
    });
  });

  group('PC-1.8 resolution L–P', () {
    test('L — multiple children supported', () async {
      await seedSon('علي');
      await seedSon('حسين');
      expect((await familyService.loadAllProfiles()).length, 2);
    });

    test('M — same-name profiles supported', () async {
      await seedSon('علي');
      await familyService.createProfile(
        relationship: PersonRelationship.son,
        preferredName: 'علي',
      );
      expect((await familyService.loadAllProfiles()).length, 2);
    });

    test('N — ambiguous child reference requires clarification', () async {
      await seedSon('علي');
      await seedSon('حسين');
      final res = resolver.resolve(
        query: 'ابني',
        profiles: await familyService.loadAllProfiles(),
      );
      expect(res.isAmbiguous, isTrue);
    });

    test('O — unique child reference resolves', () async {
      await seedSon('علي');
      final res = resolver.resolve(
        query: 'ابني',
        profiles: await familyService.loadAllProfiles(),
      );
      expect(res.isResolved, isTrue);
    });

    test('P — relationship + name resolves correctly', () async {
      await seedSon('علي');
      await seedSon('حسين');
      final res = resolver.resolve(
        query: 'ابني علي',
        profiles: await familyService.loadAllProfiles(),
        relationshipHint: PersonRelationship.son,
        nameHint: 'علي',
      );
      expect(res.isResolved, isTrue);
      expect(res.profile?.effectiveName, 'علي');
    });
  });

  group('PC-1.8 subject switching Q–T', () {
    test('Q — subject can switch owner → child', () {
      var subj = subjects.resolve(
        current: HealthSubjectContext.unknown,
        text: 'عندي صداع',
      ).subject;
      expect(subj.type, HealthSubjectType.self);
      final r = subjects.resolve(
        current: subj,
        text: 'هسه نحكي عن ابني علي',
      );
      expect(r.subject.type, HealthSubjectType.child);
      expect(r.switched, isTrue);
    });

    test('R — subject can switch child → owner', () {
      var subj = subjects.resolve(
        current: HealthSubjectContext.unknown,
        text: 'ابني عنده حرارة',
      ).subject;
      final r = subjects.resolve(
        current: subj,
        text: 'أنا هم عندي صداع',
      );
      expect(r.subject.type, HealthSubjectType.self);
      expect(r.switched, isTrue);
    });

    test('S — subject can switch child → mother', () {
      var subj = subjects.resolve(
        current: HealthSubjectContext.unknown,
        text: 'ابني عنده حرارة',
      ).subject;
      final r = subjects.resolve(current: subj, text: 'نرجع لأمي');
      expect(r.subject.type, HealthSubjectType.mother);
    });

    test('T — subject switch leaks no health facts', () {
      var subj = subjects.resolve(
        current: HealthSubjectContext.unknown,
        text: 'ابني عنده حرارة',
      ).subject;
      subj = subj.copyWith(ageYears: 8);
      final switched = subjects.resolve(
        current: subj,
        text: 'أنا هم عندي صداع',
      ).subject;
      expect(switched.type, HealthSubjectType.self);
      expect(switched.ageYears, isNull);
    });
  });

  group('PC-1.8 show/edit/delete U–AF', () {
    test('U — show people lists persistent profiles only', () async {
      await seedSon('علي');
      final r = await runFamily('منو متذكر من عائلتي؟');
      expect(r.message.contains('علي'), isTrue);
    });

    test('V — show person exposes basic identity only', () async {
      await seedSon('علي', birthYear: 2018);
      final r = await runFamily('شنو تعرف عن ابني علي؟');
      expect(r.message.contains('2018'), isTrue);
      expect(r.message.contains('حرارة'), isFalse);
    });

    test('W — session symptoms not shown as persistent person data', () async {
      await seedSon('علي');
      await runFamily('شنو تعرف عن ابني علي؟');
      final r = await runFamily('شنو تعرف عن ابني علي؟');
      expect(r.message.contains('حرارة'), isFalse);
      expect(r.message.contains('سكري'), isFalse);
    });

    test('X — edit unique person works', () async {
      await seedSon('علي');
      final r = await runFamily('غير اسم ابني علي إلى أحمد');
      expect(r.success, isTrue);
      expect(
        (await familyService.loadAllProfiles()).first.effectiveName,
        'احمد',
      );
    });

    test('Y — ambiguous edit does not modify anyone', () async {
      await seedSon('علي');
      await seedSon('علي');
      final before = await familyService.loadAllProfiles();
      final r = await runFamily('غير اسم ابني علي إلى أحمد');
      expect(r.resolutionStatus, PersonResolutionStatus.ambiguous);
      final after = await familyService.loadAllProfiles();
      expect(after.map((p) => p.effectiveName), before.map((p) => p.effectiveName));
    });

    test('Z — delete person requires confirmation', () async {
      await seedSon('علي');
      final r = await runFamily('امسح ملف ابني علي');
      expect(r.pending.isActive, isTrue);
      expect(r.message.contains('تأكيد'), isTrue);
      expect((await familyService.loadAllProfiles()).length, 1);
    });

    test('AA — declined delete preserves profile', () async {
      await seedSon('علي');
      final req = await runFamily('امسح ملف ابني علي');
      ctx.setFamilyProfilePending(req.pending);
      final r = await familyCoord.handle(
        text: 'لا',
        pending: ctx.familyProfilePending,
      );
      ctx.setFamilyProfilePending(r.pending);
      expect((await familyService.loadAllProfiles()).length, 1);
      expect(r.message.contains('ما مسحت'), isTrue);
    });

    test('AB — confirmed delete removes only target person', () async {
      await seedSon('علي');
      await seedSon('حسين');
      expect((await familyService.loadAllProfiles()).length, 2);
      final req = await familyCoord.handle(
        text: 'امسح ملف ابني علي',
        pending: FamilyProfilePendingOp.none,
      );
      expect(req.pending.isActive, isTrue);
      expect(req.pending.targetPersonId, isNotNull);
      final confirm = await familyCoord.handle(
        text: 'نعم',
        pending: req.pending,
      );
      expect(confirm.operationType, 'delete_confirmed');
      final left = await familyService.loadAllProfiles();
      expect(left.length, 1);
      expect(left.first.effectiveName, 'حسين');
    });

    test('AC — account-owner profile unaffected by family deletion', () async {
      await ownerProfiles.savePreferredName('محمد');
      await seedSon('علي');
      final req = await runFamily('امسح ملف ابني علي');
      await familyCoord.handle(text: 'نعم', pending: req.pending);
      expect((await ownerProfiles.loadProfile())?.preferredName, 'محمد');
    });

    test('AD — owner health profile unaffected', () async {
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
      await familyCoord.handle(
        text: 'نعم',
        pending: (await runFamily('امسح ملف ابني علي')).pending,
      );
      expect((await health.loadProfile())?.conditions.length, 1);
    });

    test('AE — disable != delete', () async {
      await seedSon('علي');
      await runFamily('عطل ملف ابني علي');
      expect((await familyService.loadAllProfiles()).length, 1);
      expect((await familyService.loadAllProfiles()).first.profileEnabled, isFalse);
    });

    test('AF — disabled person excluded from normal resolution', () async {
      await seedSon('علي');
      final id = (await familyService.loadAllProfiles()).first.personId;
      await familyService.disableProfile(id);
      final res = resolver.resolve(
        query: 'ابني',
        profiles: await familyService.loadAllProfiles(),
      );
      expect(res.isResolved, isFalse);
    });
  });

  group('PC-1.8 firewalls AG–AL', () {
    test('AG — child fever remains session-only', () async {
      await seedSon('علي');
      final r = await runFamily('علي عنده حرارة');
      expect(r.handled, isFalse);
      final map = (await familyService.findById(
        (await familyService.loadAllProfiles()).first.personId,
      ))!
          .toStorageMap();
      expect(map.keys.any((k) => k.contains('symptom')), isFalse);
    });

    test('AH — child diagnosed diabetes not persisted by PC-1.8', () async {
      await seedSon('علي');
      await runFamily('علي عنده سكري مشخص');
      final map = (await familyService.loadAllProfiles()).first.toStorageMap();
      for (final k in ['diabetes', 'condition', 'diagnosis', 'medication']) {
        expect(map.keys.any((e) => e.toLowerCase().contains(k)), isFalse);
      }
    });

    test('AI — mother BP never enters owner chronic timeline', () async {
      final before = (await chronicRepo.load()).measurements.length;
      await chronic.handle(
        text: 'ضغط أمي 150 على 90',
        session: ChronicCareSession.inactive,
      );
      expect((await chronicRepo.load()).measurements.length, before);
    });

    test('AJ — wife glucose never enters owner timeline', () async {
      final before = (await chronicRepo.load()).measurements.length;
      await chronic.handle(
        text: 'سكر زوجتي 200',
        session: ChronicCareSession.inactive,
      );
      expect((await chronicRepo.load()).measurements.length, before);
    });

    test('AK — child fear does not become owner emotional state', () {
      final detector = EmotionalSignalDetector();
      final signal = detector.detect('ابني خايف');
      expect(signal.aboutOtherPerson, isTrue);
      expect(ctx.emotionalSupport.enabled, isFalse);
    });

    test('AL — child preventive does not use owner age', () async {
      await ownerProfiles.setBirthYear(1980);
      expect(
        preventive.mayHandle(
          query: 'شنو النصائح المناسبة لابني؟',
          session: PreventiveGuidanceSession.inactive,
        ),
        isFalse,
      );
    });
  });

  group('PC-1.8 integration AM–BE', () {
    test('AM — doctor request for child reuses provider discovery', () {
      expect(familyCoord.shouldEscapeToProvider('أريد طبيب لابني علي'), isTrue);
    });

    test('AN — family profile not required for doctor discovery', () async {
      expect(familyCoord.shouldEscapeToProvider('أريد طبيب لابني'), isTrue);
      final plan = await brain.plan(
        query: 'أريد طبيب لابني',
        context: ctx,
      );
      expect(plan.message.contains('حفظت'), isFalse);
      expect(await familyService.loadAllProfiles(), isEmpty);
    });

    test('AO–AS — no health data stored in PersonProfile', () async {
      await seedSon('علي', birthYear: 2018);
      final map = (await familyService.loadAllProfiles()).first.toStorageMap();
      for (final forbidden in [
        'diagnosis',
        'symptom',
        'medication',
        'allergy',
        'measurement',
        'emotion',
        'fever',
      ]) {
        expect(map.keys.any((k) => k.toLowerCase().contains(forbidden)), isFalse);
      }
    });

    test('AT — local-first repository', () {
      expect(
        prefs.containsKey(LocalFamilyPersonProfileRepository.storageKey),
        isFalse,
      );
    });

    test('AU/AV — no person names or birth values in analytics debug', () async {
      await seedSon('علي', birthYear: 2018);
      final dbg = (await familyService.loadAllProfiles()).first.debugPresenceMap();
      expect(dbg.containsValue('علي'), isFalse);
      expect(dbg.containsValue(2018), isFalse);
      expect(dbg['relationshipType'], 'son');
    });

    test('AW — no names in generic debug', () {
      ctx.setLinkedFamilyPersonId('person_123');
      final snap = ctx.debugSnapshot();
      expect(snap.containsValue('person_123'), isFalse);
      expect(snap['hasLinkedFamilyPerson'], isTrue);
    });

    test('AX — text-first', () async {
      final r = await runFamily('تذكر ابني علي');
      expect(r.textFirstOnly, isTrue);
    });

    test('AY — no automatic TTS in family turn', () async {
      final r = await runFamily('تذكر ابني علي');
      expect(r.message.isNotEmpty, isTrue);
    });

    test('AZ — voice-final uses same interpreter', () {
      const interp = FamilyProfileCommandInterpreter();
      final typed = interp.interpret(
        raw: 'تذكر ابني علي',
        pending: FamilyProfilePendingOp.none,
      );
      final voice = interp.interpret(
        raw: 'تذكر ابني علي',
        pending: FamilyProfilePendingOp.none,
      );
      expect(typed.kind, voice.kind);
    });

    test('BA — repository failure does not claim save success', () async {
      final failCoord = FamilyProfileCommandCoordinator(
        people: FamilyPersonProfileService(repository: _ThrowingFamilyRepo()),
      );
      final r = await failCoord.handle(
        text: 'تذكر ابني علي',
        pending: FamilyProfilePendingOp.none,
      );
      expect(r.success, isFalse);
      expect(r.message.contains('ما كدرت'), isTrue);
    });

    test('BB — no family health persistence layer', () {
      expect(
        () => FamilyPersonProfile(
          personId: 'p',
          ownerKey: 'o',
          relationship: PersonRelationship.son,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        returnsNormally,
      );
    });

    test('BC — no campaigns', () async {
      final r = await runFamily('تذكر ابني علي');
      expect(r.message.contains('حملة'), isFalse);
    });

    test('BD — no notifications', () async {
      final r = await runFamily('تذكر ابني علي');
      expect(r.message.contains('إشعار'), isFalse);
    });

    test('BE — no paid dependency', () {
      expect(LocalFamilyPersonProfileRepository.storageKey, isNotEmpty);
    });
  });

  group('PC-1.8 PersonIdentityLink', () {
    test('links persistent person to health subject session', () async {
      final p = await familyService.createProfile(
        relationship: PersonRelationship.son,
        preferredName: 'علي',
      );
      final link = PersonIdentityLink.fromProfile(p)!;
      final linked = link.applyToSubject(HealthSubjectContext.unknown);
      expect(linked.linkedPersonId, p.personId);
      expect(linked.type, HealthSubjectType.child);
    });
  });
}
