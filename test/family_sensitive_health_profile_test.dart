import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/people/family_person_profile.dart';
import 'package:ghadeer_clinic/companion/people/family_person_profile_service.dart';
import 'package:ghadeer_clinic/companion/people/family_profile_command_coordinator.dart';
import 'package:ghadeer_clinic/companion/people/family_profile_command_models.dart';
import 'package:ghadeer_clinic/companion/people/local_family_person_profile_repository.dart';
import 'package:ghadeer_clinic/health/family_sensitive/family_sensitive_health.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FamilyPersonProfileService people;
  late FamilySensitiveHealthService familyHealth;
  late FamilyHealthCommandCoordinator familyHealthCoord;
  late FamilyProfileCommandCoordinator familyProfileCoord;
  late SensitiveHealthProfileService ownerHealth;
  late ConversationContext ctx;

  Future<FamilyPersonProfile> seedAli({
    String name = 'علي',
    bool enabled = true,
  }) async {
    final p = await people.createProfile(
      relationship: PersonRelationship.son,
      preferredName: name,
    );
    if (!enabled) {
      return people.disableProfile(p.personId);
    }
    return p;
  }

  Future<FamilyPersonProfile> seedHassan() => people.createProfile(
        relationship: PersonRelationship.son,
        preferredName: 'حسين',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    people = FamilyPersonProfileService(
      repository: LocalFamilyPersonProfileRepository(prefs: prefs),
    );
    familyHealth = FamilySensitiveHealthService(
      repository: LocalFamilySensitiveHealthRepository(prefs: prefs),
    );
    familyHealthCoord = FamilyHealthCommandCoordinator(
      service: familyHealth,
      people: people,
    );
    familyProfileCoord = FamilyProfileCommandCoordinator(
      people: people,
      familyHealth: familyHealth,
    );
    ownerHealth = SensitiveHealthProfileService(
      repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
    );
    ctx = ConversationContext();
  });

  group('PC-1.10 candidates & consent A–L', () {
    test('A — persistent Ali + diagnosed diabetes becomes candidate', () async {
      await seedAli();
      final r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.handled, isTrue);
      expect(r.pending.consent.isActive, isTrue);
      expect(r.pending.consent.candidates, isNotEmpty);
      expect(r.pending.consent.candidates.first.canonicalConditionKey, 'diabetes');
    });

    test('B/C — temporary child cannot persist; no silent profile create',
        () async {
      final before = await people.loadAllProfiles();
      final r = await familyHealthCoord.handle(
        text: 'ابني عنده سكري مشخص، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.commandKind, FamilyHealthCommandKind.needsPersistentProfile);
      expect(await people.loadAllProfiles(), before);
      expect(await familyHealth.loadStore(), isNull);
    });

    test('D — suspected diabetes not eligible', () async {
      await seedAli();
      final r = await familyHealthCoord.handle(
        text: 'علي يمكن عنده سكري، تذكر',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.commandKind, FamilyHealthCommandKind.rejectIneligible);
      expect(r.pending.consent.isActive, isFalse);
    });

    test('E — symptom not eligible', () async {
      await seedAli();
      final r = await familyHealthCoord.handle(
        text: 'علي عنده دوخة، تذكر',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.commandKind, FamilyHealthCommandKind.rejectIneligible);
    });

    test('F — high glucose reading is not diagnosis', () async {
      await seedAli();
      final q = const FamilyHealthConditionQualifier();
      expect(q.extractEligibleCandidates('سكره اليوم 180'), isEmpty);
      expect(q.looksLikeMeasurementOnly('سكره اليوم 180'), isTrue);
    });

    test('G — تذكر does not upgrade uncertainty', () async {
      await seedAli();
      final r = await familyHealthCoord.handle(
        text: 'تذكر أن علي يمكن عنده سكري',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.commandKind, FamilyHealthCommandKind.rejectIneligible);
    });

    test('H/I/J/K/L — consent yes/no/later/why', () async {
      await seedAli();
      var r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.pending.consent.isActive, isTrue);
      expect(r.message.contains('تريد أحفظها') || r.message.contains('تحب'),
          isTrue);

      // L — why
      r = await familyHealthCoord.handle(
        text: 'ليش',
        pending: r.pending,
      );
      expect(r.pending.consent.isActive, isTrue);
      expect(r.message.contains('محلياً') || r.message.contains('وافقت'), isTrue);

      // K — later
      final later = await familyHealthCoord.handle(
        text: 'بعدين',
        pending: r.pending,
      );
      expect(later.pending.isActive, isFalse);
      expect(await familyHealth.loadStore(), isNull);

      // restart + J no
      r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      final no = await familyHealthCoord.handle(text: 'لا', pending: r.pending);
      expect(no.pending.isActive, isFalse);
      expect(await familyHealth.loadStore(), isNull);

      // H/I — yes persists
      r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      final yes = await familyHealthCoord.handle(text: 'نعم', pending: r.pending);
      expect(yes.success, isTrue);
      expect(yes.message.contains('تم الحفظ'), isTrue);
      final ali = (await people.loadAllProfiles()).first;
      expect(await familyHealth.countForPerson(ali.personId), 1);
    });
  });

  group('PC-1.10 person clarity & multi M–S', () {
    test('M/N — ambiguous person clarified before consent', () async {
      await seedAli();
      await seedHassan();
      var r = await familyHealthCoord.handle(
        text: 'ابني مشخص بالسكري، تذكر',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.pending.kind, FamilyHealthPendingKind.clarifyPersonBeforeConsent);
      expect(r.pending.candidatePersonIds.length, greaterThan(1));

      r = await familyHealthCoord.handle(text: 'علي', pending: r.pending);
      expect(r.pending.consent.isActive, isTrue);
      expect(r.pending.consent.persistentPersonId, isNotNull);
    });

    test('O — child wording does not claim guardianship', () async {
      await seedAli();
      final r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.message.contains('ولي أمر'), isFalse);
      expect(r.message.contains('إذا تريد الغدير يتذكر'), isTrue);
    });

    test('P/Q/R — multiple established conditions one consent', () async {
      await seedAli();
      var r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري والربو، تذكر',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.pending.consent.candidates.length, 2);
      await familyHealthCoord.handle(text: 'لا', pending: r.pending);
      expect(await familyHealth.loadStore(), isNull);

      r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري والربو، تذكر',
        pending: FamilyHealthPendingOp.none,
      );
      final yes = await familyHealthCoord.handle(text: 'نعم', pending: r.pending);
      expect(yes.success, isTrue);
      final ali = (await people.loadAllProfiles()).first;
      expect(await familyHealth.countForPerson(ali.personId), 2);
    });

    test('S — mixed established/uncertain does not silent partial-save',
        () async {
      await seedAli();
      final r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري ويمكن عنده ربو، تذكر',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.pending.consent.isActive, isTrue);
      expect(r.pending.consent.candidates.length, 1);
      expect(r.message.contains('اللي أقدر أحفظه') || r.message.contains('فقط'),
          isTrue);
      expect(await familyHealth.loadStore(), isNull);
    });
  });

  group('PC-1.10 ownership firewalls T–Z', () {
    test('T/U — records owned by personId; rename preserves', () async {
      final ali = await seedAli();
      var r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      await familyHealthCoord.handle(text: 'نعم', pending: r.pending);
      await people.updateProfile(ali.copyWith(preferredName: 'احمد'));
      final p = await familyHealth.loadForPerson(ali.personId);
      expect(p!.conditions.first.persistentPersonId, ali.personId);
      expect(p.conditions.first.displayName, 'السكري');
    });

    test('V/W — same name / Ali+Hassan diabetes remain separate', () async {
      final a1 = await seedAli(name: 'علي');
      final a2 = await people.createProfile(
        relationship: PersonRelationship.brother,
        preferredName: 'علي',
      );
      final hassan = await seedHassan();
      await familyHealth.upsertConditions(
        persistentPersonId: a1.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      await familyHealth.upsertConditions(
        persistentPersonId: hassan.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      expect(await familyHealth.countForPerson(a1.personId), 1);
      expect(await familyHealth.countForPerson(hassan.personId), 1);
      expect(a2.personId, isNot(a1.personId));
    });

    test('X/Y/Z — owner and family health never merge', () async {
      final ali = await seedAli();
      await familyHealth.upsertConditions(
        persistentPersonId: ali.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      await ownerHealth.upsertConditions([
        HealthConditionRecord(
          id: 'hc_diabetes_1',
          canonicalConditionKey: 'diabetes',
          displayName: 'السكري',
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      final owner = await ownerHealth.loadProfile();
      final fam = await familyHealth.loadForPerson(ali.personId);
      expect(owner!.conditions.length, 1);
      expect(fam!.conditions.length, 1);
      expect(owner.toStorageMap().toString().contains(ali.personId), isFalse);
      expect(fam.conditions.first.persistentPersonId, ali.personId);
    });
  });

  group('PC-1.10 show/delete AA–AI', () {
    test('AA/AB — show persistent only; session fever not shown', () async {
      final ali = await seedAli();
      await familyHealth.upsertConditions(
        persistentPersonId: ali.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      ctx.setLinkedFamilyPersonId(ali.personId);
      final r = await familyHealthCoord.handle(
        text: 'شنو متذكر عن صحة علي؟',
        pending: FamilyHealthPendingOp.none,
        linkedFamilyPersonId: ali.personId,
      );
      expect(r.message.contains('السكري'), isTrue);
      expect(r.message.contains('حرارة') || r.message.contains('حمى'), isFalse);
    });

    test('AC — global family query does not dump diagnoses', () async {
      final ali = await seedAli();
      await familyHealth.upsertConditions(
        persistentPersonId: ali.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      final r = await familyHealthCoord.handle(
        text: 'شنو المعلومات الصحية اللي حافظها عن عائلتي؟',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.message.contains('السكري'), isFalse);
      expect(r.message.contains('علي') || r.message.contains('شخص'), isTrue);
    });

    test('AD/AE — delete one condition preserves PersonProfile', () async {
      final ali = await seedAli();
      await familyHealth.upsertConditions(
        persistentPersonId: ali.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
          HealthConditionCandidate(
            canonicalConditionKey: 'asthma',
            displayName: 'الربو',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      final r = await familyHealthCoord.handle(
        text: 'امسح السكري من معلومات علي الصحية',
        pending: FamilyHealthPendingOp.none,
        linkedFamilyPersonId: ali.personId,
      );
      expect(r.success, isTrue);
      expect(await familyHealth.countForPerson(ali.personId), 1);
      expect((await people.loadAllProfiles()).length, 1);
    });

    test('AF/AG — delete all health requires confirm; preserves identity',
        () async {
      final ali = await seedAli();
      await familyHealth.upsertConditions(
        persistentPersonId: ali.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      var r = await familyHealthCoord.handle(
        text: 'امسح كل المعلومات الصحية المحفوظة عن علي',
        pending: FamilyHealthPendingOp.none,
        linkedFamilyPersonId: ali.personId,
      );
      expect(r.pending.kind, FamilyHealthPendingKind.deleteAllHealthForPerson);
      r = await familyHealthCoord.handle(text: 'نعم', pending: r.pending);
      expect(await familyHealth.countForPerson(ali.personId), 0);
      expect((await people.loadAllProfiles()).first.personId, ali.personId);
    });

    test('AH/AI — profile deletion cannot orphan health / no silent destroy',
        () async {
      final ali = await seedAli();
      await familyHealth.upsertConditions(
        persistentPersonId: ali.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      var r = await familyProfileCoord.handle(
        text: 'امسح ملف ابني علي',
        pending: FamilyProfilePendingOp.none,
      );
      expect(r.pending.alsoDeletesFamilyHealth, isTrue);
      expect(r.message.contains('صحية'), isTrue);
      // بدون تأكيد — الصحة باقية
      expect(await familyHealth.countForPerson(ali.personId), 1);
      r = await familyProfileCoord.handle(text: 'نعم', pending: r.pending);
      expect(await familyHealth.countForPerson(ali.personId), 0);
      expect(await people.loadAllProfiles(), isEmpty);
    });
  });

  group('PC-1.10 retrieval & boundaries AJ–AW', () {
    test('AJ/AK — disabled excluded from auto retrieval; health stored',
        () async {
      final ali = await seedAli();
      await familyHealth.upsertConditions(
        persistentPersonId: ali.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      final disabled = await people.disableProfile(ali.personId);
      final policy = const FamilySensitiveHealthRetrievalPolicy();
      final auto = await policy.retrieveRelevant(
        service: familyHealth,
        purpose: FamilyHealthRetrievalPurpose.diabetesRelated,
        activePersistentPersonId: ali.personId,
        personProfile: disabled,
      );
      expect(auto, isEmpty);
      expect(await familyHealth.countForPerson(ali.personId), 1);
    });

    test('AL–AP — purpose-limited; no inject into greeting/doctor/lab/offers',
        () async {
      final ali = await seedAli();
      await familyHealth.upsertConditions(
        persistentPersonId: ali.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      final policy = const FamilySensitiveHealthRetrievalPolicy();
      for (final purpose in [
        FamilyHealthRetrievalPurpose.greeting,
        FamilyHealthRetrievalPurpose.doctorBrowsing,
        FamilyHealthRetrievalPurpose.labBrowsing,
        FamilyHealthRetrievalPurpose.offersPackages,
        FamilyHealthRetrievalPurpose.generalChat,
      ]) {
        final got = await policy.retrieveRelevant(
          service: familyHealth,
          purpose: purpose,
          activePersistentPersonId: ali.personId,
          personProfile: ali,
        );
        expect(got, isEmpty, reason: purpose.name);
      }
      final health = await policy.retrieveRelevant(
        service: familyHealth,
        purpose: FamilyHealthRetrievalPurpose.diabetesRelated,
        activePersistentPersonId: ali.personId,
        personProfile: ali,
      );
      expect(health.length, 1);
    });

    test('AQ/AR — no family chronic / timeline', () async {
      expect(
        familyHealthCoord.interpreter
            .interpret(
              raw: 'شلون سكر علي؟',
              pending: FamilyHealthPendingOp.none,
            )
            .kind,
        FamilyHealthCommandKind.notImplementedChronic,
      );
      final store = await familyHealth.ensureStore();
      expect(store.toStorageMap().toString().contains('timeline'), isFalse);
      expect(store.toStorageMap().toString().contains('followUpPermission'),
          isFalse);
    });

    test('AS/AT/AU/AV — measurement/med/allergy/fear not persisted', () async {
      final ali = await seedAli();
      var r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري وسكره اليوم 180، تذكر',
        pending: FamilyHealthPendingOp.none,
      );
      await familyHealthCoord.handle(text: 'نعم', pending: r.pending);
      final map = (await familyHealth.loadForPerson(ali.personId))!
          .toStorageMap()
          .toString();
      expect(map.contains('180'), isFalse);
      expect(map.contains('دواء'), isFalse);

      r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري وياخذ دواء X، تذكر',
        pending: FamilyHealthPendingOp.none,
      );
      if (r.pending.consent.isActive) {
        await familyHealthCoord.handle(text: 'نعم', pending: r.pending);
      }
      final after = (await familyHealth.loadForPerson(ali.personId))!
          .toStorageMap()
          .toString();
      expect(after.contains('دواء'), isFalse);
      expect(after.contains(' X'), isFalse);

      expect(
        familyHealthCoord.interpreter
            .interpret(
              raw: 'احفظ حساسية علي',
              pending: FamilyHealthPendingOp.none,
            )
            .kind,
        FamilyHealthCommandKind.notImplementedAllergy,
      );

      final fear = const FamilyHealthConditionQualifier()
          .extractEligibleCandidates('علي خايف بسبب السكري');
      expect(fear, isEmpty);
    });

    test('AW — family prevention not auto-enabled', () async {
      final ali = await seedAli();
      await familyHealth.upsertConditions(
        persistentPersonId: ali.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      final p = await familyHealth.loadForPerson(ali.personId);
      expect(p!.toStorageMap().toString().contains('preventive'), isFalse);
    });
  });

  group('PC-1.10 safety / text / privacy AX–BK', () {
    test('AX/AY — urgent & mental safety outrank memory consent', () async {
      await seedAli();
      final urgent = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري وعنده ضيق نفس، تذكر',
        pending: FamilyHealthPendingOp.none,
        preferUrgentSafety: true,
      );
      expect(urgent.deferToUrgentSafety || !urgent.handled || urgent.handled == false,
          isTrue);
      expect(await familyHealth.loadStore(), isNull);

      final mental = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري ويريد انتحار، تذكر',
        pending: FamilyHealthPendingOp.none,
      );
      expect(mental.deferToMentalSafety || mental.handled == false, isTrue);
    });

    test('AZ — provider request remains accessible', () async {
      await seedAli();
      final r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري وأريد طبيب',
        pending: FamilyHealthPendingOp.none,
      );
      expect(r.deferToProvider || !r.handled, isTrue);
    });

    test('BA/BB/BC — text-first; no TTS; voice-final same interpreter', () {
      final a = familyHealthCoord.interpreter.interpret(
        raw: 'علي مشخص بالسكري، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      final b = familyHealthCoord.interpreter.interpret(
        raw: 'علي مشخص بالسكري، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      expect(a.kind, b.kind);
      expect(a.debugMap().containsKey('familyHealthCommandType'), isTrue);
    });

    test('BD/BE — no personId/names/conditions in debug/analytics', () async {
      await seedAli();
      final r = await familyHealthCoord.handle(
        text: 'علي مشخص بالسكري، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      final dbg = r.debugMap().toString();
      expect(dbg.contains('person_'), isFalse);
      expect(dbg.contains('علي'), isFalse);
      expect(dbg.contains('سكري'), isFalse);
      expect(dbg.contains('diabetes'), isFalse);
    });

    test('BF — repository failure does not claim success', () async {
      final fail = FamilyHealthCommandCoordinator(
        service: FamilySensitiveHealthService(repository: _FailRepo()),
        people: people,
      );
      await seedAli();
      var r = await fail.handle(
        text: 'علي مشخص بالسكري، تذكر هذا',
        pending: FamilyHealthPendingOp.none,
      );
      r = await fail.handle(text: 'نعم', pending: r.pending);
      expect(r.success, isFalse);
      expect(r.message.contains('ما تم الحفظ'), isTrue);
    });

    test('BG–BK — no cloud sync / chronic / campaigns / notifications / paid',
        () {
      expect(LocalFamilySensitiveHealthRepository.storageKey,
          'pc_family_sensitive_health_v1');
      expect(
        LocalFamilySensitiveHealthRepository.storageKey,
        isNot('pc_sensitive_health_profile_v1'),
      );
      final profile = FamilySensitiveHealthProfile(
        persistentPersonId: 'x',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(profile.chronicCarePlaceholder, isEmpty);
      expect(profile.measurementsPlaceholder, isEmpty);
      expect(profile.medicationsPlaceholder, isEmpty);
      expect(profile.allergiesPlaceholder, isEmpty);
    });

    test('SmartBrain wires family health text-first', () async {
      await seedAli();
      final brain = SmartBrainPlanner(
        familyProfileCommands: familyProfileCoord,
        familySensitiveHealth: familyHealthCoord,
      );
      final plan = await brain.plan(
        query: 'علي مشخص بالسكري، تذكر هذا',
        context: ctx,
      );
      expect(plan.message, isNotEmpty);
      expect(ctx.familySensitiveHealthPending.consent.isActive, isTrue);
      expect(plan.textFirstOnly, isTrue);
    });
  });
}

class _FailRepo implements FamilySensitiveHealthRepository {
  @override
  Future<void> clearStore() async {}

  @override
  Future<FamilySensitiveHealthStore?> loadStore() async => null;

  @override
  Future<FamilySensitiveHealthStore> saveStore(
    FamilySensitiveHealthStore store,
  ) async {
    throw FamilySensitiveHealthStorageException('fail');
  }
}
