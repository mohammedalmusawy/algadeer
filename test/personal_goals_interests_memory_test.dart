import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion_command_domain.dart';
import 'package:ghadeer_clinic/companion/local_personal_companion_profile_repository.dart';
import 'package:ghadeer_clinic/companion/people/family_person_profile.dart';
import 'package:ghadeer_clinic/companion/people/family_person_profile_service.dart';
import 'package:ghadeer_clinic/companion/people/local_family_person_profile_repository.dart';
import 'package:ghadeer_clinic/companion/personal_companion_profile.dart';
import 'package:ghadeer_clinic/companion/personal_companion_profile_service.dart';
import 'package:ghadeer_clinic/companion/personal_memory/personal_memory.dart';
import 'package:ghadeer_clinic/follow_up/follow_up.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingPersonalMemoryRepo implements PersonalMemoryRepository {
  @override
  Future<void> clearStore() async {}

  @override
  Future<CompanionPersonalMemoryStore?> loadStore() async =>
      throw StateError('repo down');

  @override
  Future<CompanionPersonalMemoryStore> saveStore(
    CompanionPersonalMemoryStore store,
  ) async =>
      throw StateError('repo down');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PersonalMemoryService mem;
  late PersonalMemoryCoordinator coord;
  late FollowUpService followUps;
  late FollowUpCoordinator followCoord;
  late PersonalCompanionProfileService profiles;
  late SensitiveHealthProfileService health;
  late FamilyPersonProfileService people;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mem = PersonalMemoryService(
      repository: LocalPersonalMemoryRepository(prefs: prefs),
    );
    followUps = FollowUpService(
      repository: LocalFollowUpRepository(prefs: prefs),
    );
    followCoord = FollowUpCoordinator(service: followUps);
    profiles = PersonalCompanionProfileService(
      repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
    );
    health = SensitiveHealthProfileService(
      repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
    );
    people = FamilyPersonProfileService(
      repository: LocalFamilyPersonProfileRepository(prefs: prefs),
    );
    coord = PersonalMemoryCoordinator(
      service: mem,
      profiles: profiles,
      followUps: followUps,
    );
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      personalMemory: coord,
      followUp: followCoord,
      companionOnboardingCoordinator: null,
      doctorLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. قلب',
              subtitle: 'قلب',
              doctorId: 'd1',
              score: 90,
            ),
          ],
    );
  });

  Future<PersonalMemoryCommandTurnResult> run(
    String text, {
    PersonalMemoryPendingOp? pending,
  }) async {
    final r = await coord.handle(
      text: text,
      pending: pending ?? ctx.personalMemoryPending,
    );
    ctx.setPersonalMemoryPending(r.pending);
    return r;
  }

  group('PC-1.12 persist A–J', () {
    test('A — explicit remember goal persists', () async {
      final r = await run('تذكر أن هدفي أتعلم Flutter');
      expect(r.success, isTrue);
      final goals = await mem.listByType(PersonalMemoryType.goal);
      expect(goals, isNotEmpty);
      expect(goals.first.canonicalKey, contains('flutter'));
    });

    test('B — أتعلم Flutter alone does not persist', () async {
      final interp = coord.interpreter.interpret(
        raw: 'أتعلم Flutter',
        pending: PersonalMemoryPendingOp.none,
      );
      expect(interp.isCommand, isFalse);
      expect(await mem.listAll(), isEmpty);
    });

    test('C — explicit remember interest persists', () async {
      final r = await run('احفظ أني مهتم بالتصوير');
      expect(r.success, isTrue);
      final list = await mem.listByType(PersonalMemoryType.interest);
      expect(list.single.canonicalKey, contains('photo'));
    });

    test('D — أحب التصوير alone does not persist', () async {
      final interp = coord.interpreter.interpret(
        raw: 'أحب التصوير',
        pending: PersonalMemoryPendingOp.none,
      );
      expect(interp.isCommand, isFalse);
      expect(await mem.listAll(), isEmpty);
    });

    test('E — explicit stable preference persists', () async {
      final r = await run('من هسه اعرف أني أفضل الشرح بالعربي');
      expect(r.success, isTrue);
      final prefsList = await mem.listByType(PersonalMemoryType.preference);
      expect(prefsList, isNotEmpty);
    });

    test('F — fleeting preference does not persist automatically', () async {
      final interp = coord.interpreter.interpret(
        raw: 'اليوم ما أريد شرح طويل',
        pending: PersonalMemoryPendingOp.none,
      );
      expect(interp.isCommand, isFalse);
      expect(await mem.listAll(), isEmpty);
    });

    test('G — goals/interests/preferences are distinct types', () async {
      await run('تذكر أن هدفي أتعلم Flutter');
      await run('احفظ أني مهتم بالتصوير');
      await run('من هسه اعرف أني أفضل الشرح بالعربي');
      expect(await mem.listByType(PersonalMemoryType.goal), hasLength(1));
      expect(await mem.listByType(PersonalMemoryType.interest), hasLength(1));
      expect(await mem.listByType(PersonalMemoryType.preference), hasLength(1));
    });

    test('H — multiple goals supported', () async {
      await run('تذكر أن هدفي أتعلم Flutter');
      await run('خلي ببالك هدفي أتعلم إنكليزي');
      await run('تذكر أني أريد ألتزم بالمشي');
      expect(await mem.listByType(PersonalMemoryType.goal), hasLength(3));
    });

    test('I — multiple interests supported', () async {
      await run('احفظ أني مهتم بالتصوير');
      await run('تذكر أني مهتم بصناعة المحتوى');
      expect(await mem.listByType(PersonalMemoryType.interest), hasLength(2));
    });

    test('J — unknown goal category remains representable', () async {
      await run('تذكر أن هدفي أتعلم الخزف');
      final goals = await mem.listByType(PersonalMemoryType.goal);
      expect(goals, isNotEmpty);
      expect(goals.first.category, PersonalGoalCategory.other.name);
    });
  });

  group('PC-1.12 follow-up / owner boundary K–Q', () {
    test('K/N — goal does not auto-create follow-up; no FU state on record',
        () async {
      await run('تذكر هدفي أتعلم Flutter');
      expect(await followUps.listActive(), isEmpty);
      final g = (await mem.listByType(PersonalMemoryType.goal)).first;
      final map = g.toStorageMap();
      expect(map.containsKey('followUpId'), isFalse);
      expect(map.containsKey('followUpStatus'), isFalse);
    });

    test('L/M — explicit follow-up integrates; PC-1.11 authority', () async {
      await run('تذكر هدفي أتعلم Flutter');
      var fu = await followCoord.handle(
        text: 'تابع وياي هدفي بتعلم Flutter',
        pending: FollowUpPendingOp.none,
      );
      expect(fu.pending.isActive || fu.success, isTrue);
      if (fu.pending.isActive) {
        fu = await followCoord.handle(text: 'نعم', pending: fu.pending);
      }
      expect(await followUps.listActive(), isNotEmpty);
      final c = (await followUps.listActive()).first;
      expect(c.domain, FollowUpDomain.personalGoal);
      expect(c.subjectRef.isAccountOwner, isTrue);
    });

    test('O/P/Q — family / other-person not stored as owner memory', () async {
      await people.createProfile(
        relationship: PersonRelationship.son,
        preferredName: 'علي',
      );
      final o = await run('تذكر أن ابني يحب كرة القدم');
      expect(o.commandKind, PersonalMemoryCommandKind.rejectNonOwner);
      expect(await mem.listAll(), isEmpty);

      final p = await run('تذكر أن هدفي ابني يتعلم كرة القدم');
      expect(
        p.commandKind == PersonalMemoryCommandKind.rejectNonOwner ||
            (await mem.listByType(PersonalMemoryType.goal)).isEmpty,
        isTrue,
      );

      final q = await run('صديقي مهتم بالتصوير');
      expect(q.handled == false || (await mem.listAll()).isEmpty, isTrue);
      expect(await mem.listAll(), isEmpty);
    });
  });

  group('PC-1.12 firewalls R–W', () {
    test('R/S — emotional / stress not persisted', () async {
      final r = await run('تذكر أني حزين');
      expect(r.commandKind, PersonalMemoryCommandKind.rejectEmotional);
      final s = await run('تذكر أني مضغوط');
      expect(
        s.commandKind == PersonalMemoryCommandKind.rejectEmotional ||
            await mem.listAll() == [],
        isTrue,
      );
      expect(await mem.listAll(), isEmpty);
    });

    test('T — no personality inference', () async {
      final t = await run('تذكر أني كسول');
      expect(t.commandKind, PersonalMemoryCommandKind.rejectPersonality);
      expect(await mem.listAll(), isEmpty);
    });

    test('U/V — sensitive health not ordinary memory', () async {
      final u = await run('تذكر عندي سكري مشخص');
      expect(u.commandKind, PersonalMemoryCommandKind.rejectSensitiveHealth);
      expect(await mem.listAll(), isEmpty);
      expect(await health.loadProfile(), isNull);
    });

    test('W — diabetes goal does not duplicate diagnosis', () async {
      await run('تذكر هدفي أسيطر على السكري');
      final goals = await mem.listByType(PersonalMemoryType.goal);
      expect(goals, isNotEmpty);
      expect(goals.first.displayLabel.contains('مشخص'), isFalse);
      expect(goals.first.canonicalKey, isNot(contains('diagnosis')));
      final dbg = goals.first.debugMap().toString();
      expect(dbg.contains('سكري'), isFalse);
    });
  });

  group('PC-1.12 lifecycle X–AB', () {
    test('X/Y — complete keeps record', () async {
      await run('تذكر هدفي أتعلم Flutter');
      final r = await run('كملت هدفي بتعلم Flutter');
      expect(r.success, isTrue);
      final goals = await mem.listByType(PersonalMemoryType.goal);
      expect(goals.single.status, PersonalMemoryStatus.completed);
    });

    test('Z/AA — pause coordinates with active follow-up', () async {
      await run('تذكر هدفي أتعلم Flutter');
      final g = (await mem.listByType(PersonalMemoryType.goal)).first;
      await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.personalGoal,
        topicKey: g.canonicalKey,
        displayTopic: g.displayLabel,
      );
      expect(await followUps.listActive(), isNotEmpty);
      await run('وقف هذا الهدف مؤقتاً Flutter');
      expect(
        (await mem.listByType(PersonalMemoryType.goal)).first.status,
        PersonalMemoryStatus.paused,
      );
      expect(await followUps.listActive(), isEmpty);
      final pausedFu = await followUps.findById(
        (await followUps.listAll()).first.commitmentId,
      );
      expect(pausedFu!.status, FollowUpStatus.paused);
    });

    test('AB — resume does not recreate cancelled follow-up', () async {
      await run('تذكر هدفي أتعلم Flutter');
      final g = (await mem.listByType(PersonalMemoryType.goal)).first;
      final c = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.personalGoal,
        topicKey: g.canonicalKey,
        displayTopic: g.displayLabel,
      );
      await followUps.cancel(c.commitmentId);
      await run('وقف هذا الهدف مؤقتاً Flutter');
      await run('رجع هدفي Flutter');
      expect(
        (await mem.listByType(PersonalMemoryType.goal)).first.status,
        PersonalMemoryStatus.active,
      );
      expect(await followUps.listActive(), isEmpty);
    });
  });

  group('PC-1.12 correction / delete AC–AM', () {
    test('AC/AD — correction replaces pending/duplicate', () async {
      await run('تذكر هدفي أتعلم Flutter');
      await run('مو Flutter، هدفي أتعلم Figma');
      final goals = await mem.listByType(PersonalMemoryType.goal);
      expect(goals.length, 1);
      expect(goals.single.canonicalKey, contains('figma'));
    });

    test('AE — ambiguous goal deletion clarifies', () async {
      await mem.upsertCandidate(
        const PersonalMemoryCandidate(
          memoryType: PersonalMemoryType.goal,
          canonicalKey: 'goal_learn_flutter',
          displayLabel: 'تعلم Flutter',
          category: 'technology',
        ),
      );
      await mem.upsertCandidate(
        const PersonalMemoryCandidate(
          memoryType: PersonalMemoryType.goal,
          canonicalKey: 'goal_flutter_ui',
          displayLabel: 'تحسين واجهة Flutter',
          category: 'technology',
        ),
      );
      final r = await run('احذف هدف Flutter');
      expect(r.commandKind, PersonalMemoryCommandKind.clarifyAmbiguous);
      expect(await mem.listByType(PersonalMemoryType.goal), hasLength(2));
    });

    test('AF/AG — delete one preserves others / interests vs goals', () async {
      await run('تذكر هدفي أتعلم Flutter');
      await run('خلي ببالك هدفي أتعلم إنكليزي');
      await run('احفظ أني مهتم بالتصوير');
      await run('لا تتذكر أني أتعلم Flutter');
      expect(await mem.listByType(PersonalMemoryType.goal), hasLength(1));
      expect(await mem.listByType(PersonalMemoryType.interest), hasLength(1));
      await run('احذف اهتمامي بالتصوير');
      expect(await mem.listByType(PersonalMemoryType.interest), isEmpty);
      expect(await mem.listByType(PersonalMemoryType.goal), hasLength(1));
    });

    test('AH/AI — bulk delete requires confirmation', () async {
      await run('تذكر هدفي أتعلم Flutter');
      final ah = await run('امسح كل أهدافي');
      expect(ah.pending.kind, PersonalMemoryPendingKind.bulkDelete);
      expect(await mem.listByType(PersonalMemoryType.goal), hasLength(1));
      await run('نعم', pending: ah.pending);
      expect(await mem.listByType(PersonalMemoryType.goal), isEmpty);

      await run('احفظ أني مهتم بالتصوير');
      final ai = await run('امسح كل اهتماماتي');
      expect(ai.pending.kind, PersonalMemoryPendingKind.bulkDelete);
      await run('لا', pending: ai.pending);
      expect(await mem.listByType(PersonalMemoryType.interest), hasLength(1));
    });

    test('AJ/AK/AL/AM — bulk delete does not wipe other domains', () async {
      await profiles.savePreferredName('محمد');
      final now = DateTime.now();
      await health.upsertConditions([
        HealthConditionRecord(
          id: 'hc_diabetes',
          canonicalConditionKey: 'diabetes',
          displayName: 'سكري',
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          consentState: HealthConsentState.granted,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      await people.createProfile(
        relationship: PersonRelationship.spouse,
        preferredName: 'سارة',
      );
      await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.personalGoal,
        topicKey: 'goal_learn_flutter',
        displayTopic: 'تعلم Flutter',
      );
      await run('تذكر هدفي أتعلم Flutter');
      final req = await run('امسح كل أهدافي');
      await run('نعم', pending: req.pending);

      expect((await profiles.loadProfile())?.preferredName, 'محمد');
      expect(await health.loadProfile(), isNotNull);
      expect(await people.loadAllProfiles(), isNotEmpty);
      expect(await followUps.listAll(), isNotEmpty);
    });
  });

  group('PC-1.12 show / retrieval AN–AS', () {
    test('AN/AO — broad queries exclude sensitive health', () async {
      await profiles.savePreferredName('محمد');
      await run('تذكر هدفي أتعلم Flutter');
      final now = DateTime.now();
      await health.upsertConditions([
        HealthConditionRecord(
          id: 'hc_diabetes',
          canonicalConditionKey: 'diabetes',
          displayName: 'سكري',
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          consentState: HealthConsentState.granted,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final an = await run('شنو الأشياء اللي طلبت منك تتذكرها؟');
      expect(an.message.contains('سكري'), isFalse);
      final ao = await run('شنو تعرف عني؟');
      expect(ao.message.contains('محمد'), isTrue);
      expect(ao.message.contains('Flutter'), isTrue);
      expect(ao.message.contains('سكري'), isFalse);
    });

    test('AP/AQ/AR/AS — purpose-limited retrieval', () async {
      await run('تذكر هدفي أتعلم Flutter');
      await run('احفظ أني مهتم بصناعة المحتوى');
      final policy = const PersonalMemoryRetrievalPolicy();

      final learn = await policy.retrieveRelevant(
        service: mem,
        purpose: PersonalMemoryRetrievalPurpose.learningAdvice,
      );
      expect(learn, isNotEmpty);
      expect(learn.any((e) => e.canonicalKey.contains('flutter')), isTrue);

      final doctor = await policy.retrieveRelevant(
        service: mem,
        purpose: PersonalMemoryRetrievalPurpose.doctorQuery,
      );
      expect(doctor, isEmpty);

      final content = await policy.retrieveRelevant(
        service: mem,
        purpose: PersonalMemoryRetrievalPurpose.contentCreationHelp,
      );
      expect(content, isNotEmpty);

      expect(
        policy.purposeForQuery('أريد طبيب قلب'),
        PersonalMemoryRetrievalPurpose.doctorQuery,
      );
      expect(
        policy.purposeForQuery('شنو تنصحني اتعلم بعد؟'),
        PersonalMemoryRetrievalPurpose.learningAdvice,
      );
    });
  });

  group('PC-1.12 policy / wiring AT–BH', () {
    test('AT/AU/AV — no engagement pressure / gamification / auto coaching',
        () async {
      await run('تذكر هدفي أتعلم Flutter');
      final r = await run('شنو أهدافي؟');
      expect(r.message.contains('لا تنسَ'), isFalse);
      expect(r.message.contains('اشتقت'), isFalse);
      expect(r.message.contains('streak'), isFalse);
      expect(r.message.contains('نقطة'), isFalse);
      expect(r.message.contains('شارة'), isFalse);
      expect(r.message.contains('درست اليوم'), isFalse);
      expect(r.message.contains('مشيت اليوم'), isFalse);
    });

    test('AW — student context does not infer study goal', () async {
      await profiles.setUserContext(ProfileUserContext.student);
      expect(await mem.listAll(), isEmpty);
    });

    test('AX — walking goal is not medical prescription', () async {
      final r = await run('تذكر أن هدفي ألتزم بالمشي');
      expect(r.message.contains('وصفة'), isFalse);
      expect(r.message.contains('جرعة'), isFalse);
      final g = (await mem.listByType(PersonalMemoryType.goal)).first;
      expect(g.category, PersonalGoalCategory.fitness.name);
    });

    test('AY/AZ/BA — text-first; same interpreter for voice transcript',
        () async {
      final plan = await brain.plan(
        query: 'تذكر أن هدفي أتعلم Flutter',
        context: ctx,
      );
      expect(plan.textFirstOnly, isTrue);
      expect(plan.kind, AssistantActionKind.showMessage);

      final a = coord.interpreter.interpret(
        raw: 'احفظ أني مهتم بالتصوير',
        pending: PersonalMemoryPendingOp.none,
      );
      final b = coord.interpreter.interpret(
        raw: 'احفظ أني مهتم بالتصوير',
        pending: PersonalMemoryPendingOp.none,
      );
      expect(a.kind, b.kind);
      expect(a.candidate?.canonicalKey, b.candidate?.canonicalKey);
    });

    test('BB/BC — debug/analytics omit raw memory content', () async {
      await run('تذكر هدفي أتعلم Flutter');
      final turn = await run('شنو أهدافي؟');
      final dbg = turn.debugMap().toString();
      expect(dbg.contains('Flutter'), isFalse);
      expect(dbg.contains('memoryId'), isFalse);
      expect(dbg.contains('operationType'), isTrue);
      expect(ctx.debugSnapshot().toString().contains('Flutter'), isFalse);
    });

    test('BD — repository failure does not claim success', () async {
      final failing = PersonalMemoryCoordinator(
        service: PersonalMemoryService(repository: _FailingPersonalMemoryRepo()),
        profiles: profiles,
        followUps: followUps,
      );
      final r = await failing.handle(
        text: 'تذكر هدفي أتعلم Flutter',
        pending: PersonalMemoryPendingOp.none,
      );
      expect(r.success, isFalse);
      expect(r.message.contains('ما تم الحفظ'), isTrue);
    });

    test('BE — local store key; no cloud sync key', () {
      expect(LocalPersonalMemoryRepository.storageKey, 'pc_personal_memory_v1');
      expect(
        LocalPersonalMemoryRepository.storageKey.contains('supabase'),
        isFalse,
      );
    });

    test('BF/BG/BH — no campaigns / notifications / paid dependency hooks',
        () {
      expect(PersonalMemoryType.values.map((e) => e.name),
          isNot(contains('campaign')));
      expect(PersonalMemoryStatus.values.map((e) => e.name),
          isNot(contains('notified')));
      expect(PersonalMemoryCommandKind.values.map((e) => e.name),
          isNot(contains('purchase')));
    });

    test('router routes personal memory domain', () {
      const router = CompanionCommandRouter();
      final r = router.route('تذكر أن هدفي أتعلم Flutter');
      expect(r?.domain, CompanionCommandDomain.personalMemory);
    });
  });
}
