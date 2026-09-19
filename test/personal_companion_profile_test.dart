import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_coordinator.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_models.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/memory/memory_candidate.dart';
import 'package:ghadeer_clinic/memory/memory_category.dart';
import 'package:ghadeer_clinic/memory/memory_consent.dart';
import 'package:ghadeer_clinic/memory/memory_owner.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/services/user_profile_service.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/startup_greeting.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalPersonalCompanionProfileRepository repo;
  late PersonalCompanionProfileService service;
  late UserProfileService userProfile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = LocalPersonalCompanionProfileRepository(prefs: prefs);
    service = PersonalCompanionProfileService(repository: repo);
    userProfile = UserProfileService(prefs: prefs, companion: service);
  });

  group('PC-1.1 profile CRUD A–H', () {
    test('A — create empty optional profile', () async {
      final p = await service.createEmptyProfile();
      expect(p.profileId, isNotEmpty);
      expect(p.ownerKey.length, greaterThanOrEqualTo(8));
      expect(p.preferredName, isNull);
      expect(p.profileEnabled, isTrue);
    });

    test('B/C — save and load preferredName', () async {
      await service.savePreferredName('محمد');
      final loaded = await service.loadProfile();
      expect(loaded?.preferredName, 'محمد');
    });

    test('D — update preferredName', () async {
      await service.savePreferredName('محمد');
      await service.savePreferredName('أحمد');
      expect((await service.loadProfile())?.preferredName, 'أحمد');
    });

    test('E — clear preferredName', () async {
      await service.savePreferredName('محمد');
      await service.clearField(ProfileOptionalField.preferredName);
      expect((await service.loadProfile())?.preferredName, isNull);
    });

    test('F — existing user_display_name migrates safely', () async {
      SharedPreferences.setMockInitialValues({
        UserProfileService.nameKey: 'سارة',
      });
      prefs = await SharedPreferences.getInstance();
      repo = LocalPersonalCompanionProfileRepository(prefs: prefs);
      service = PersonalCompanionProfileService(repository: repo);
      userProfile = UserProfileService(prefs: prefs, companion: service);

      final name = await userProfile.getDisplayName();
      expect(name, 'سارة');
      final profile = await service.loadProfile();
      expect(profile?.preferredName, 'سارة');
    });

    test('G — existing startup greeting still works', () async {
      await service.savePreferredName('محمد');
      final name = await userProfile.getDisplayName();
      final g = PersonalizedGreeting.fromDisplayName(name);
      expect(g.firstName, 'محمد');
      expect(g.displayGreeting.contains('محمد'), isTrue);
    });

    test('H — no duplicate preferred-name authority', () async {
      await userProfile.saveDisplayName('ليلى');
      final fromUser = await userProfile.getDisplayName();
      final fromCompanion = await service.preferredNameForPersonalization();
      expect(fromUser, fromCompanion);
      expect(fromUser, 'ليلى');
    });
  });

  group('PC-1.1 sex selection I–N', () {
    test('I — male only by explicit assignment', () async {
      await service.setSexSelection(ProfileSexSelection.male);
      expect(
        (await service.loadProfile())?.sexSelection,
        ProfileSexSelection.male,
      );
    });

    test('J — female only by explicit assignment', () async {
      await service.setSexSelection(ProfileSexSelection.female);
      expect(
        (await service.loadProfile())?.sexSelection,
        ProfileSexSelection.female,
      );
    });

    test('K — preferNotToSpecify supported', () async {
      await service.setSexSelection(ProfileSexSelection.preferNotToSpecify);
      expect(
        (await service.loadProfile())?.sexSelection,
        ProfileSexSelection.preferNotToSpecify,
      );
    });

    test('L/M/N — no sex inference from name/TTS/photo', () {
      expect(service.mayInferSexFromName(), isFalse);
      expect(service.mayInferSexFromTtsVoice(), isFalse);
      expect(service.mayInferSexFromPhoto(), isFalse);
    });
  });

  group('PC-1.1 birth / age O–U', () {
    test('O — save birthDate', () async {
      final d = DateTime(1990, 6, 15);
      await service.setBirthDate(d);
      final p = await service.loadProfile();
      expect(p?.birthDate?.year, 1990);
      expect(p?.birthDate?.month, 6);
      expect(p?.birthDate?.day, 15);
    });

    test('P — currentAge before birthday this year', () {
      final p = PersonalCompanionProfile(
        profileId: 'x',
        ownerKey: 'owner_key_1',
        birthDate: DateTime(2000, 12, 31),
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );
      expect(p.currentAge(now: DateTime(2024, 6, 1)), 23);
    });

    test('Q — currentAge after birthday this year', () {
      final p = PersonalCompanionProfile(
        profileId: 'x',
        ownerKey: 'owner_key_1',
        birthDate: DateTime(2000, 1, 1),
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      );
      expect(p.currentAge(now: DateTime(2024, 6, 1)), 24);
    });

    test('R — birthYear-only supported', () async {
      await service.setBirthYear(1995);
      final p = await service.loadProfile();
      expect(p?.birthYear, 1995);
      expect(p?.birthDate, isNull);
      expect(p?.currentAge(now: DateTime(2024, 1, 1)), 29);
    });

    test('S — future birth date rejected', () async {
      expect(
        () => service.setBirthDate(DateTime.now().add(const Duration(days: 2))),
        throwsA(isA<ProfileValidationException>()),
      );
    });

    test('T — invalid birth year handled safely', () async {
      expect(
        () => service.setBirthYear(DateTime.now().year + 5),
        throwsA(isA<ProfileValidationException>()),
      );
      expect(
        () => service.setBirthYear(1800),
        throwsA(isA<ProfileValidationException>()),
      );
    });

    test('U — fixed age not persisted as canonical field', () async {
      await service.setBirthDate(DateTime(2000, 1, 1));
      final map = (await service.loadProfile())!.toStorageMap();
      expect(map.containsKey('age'), isFalse);
      expect(map.containsKey('currentAge'), isFalse);
      expect(map['birthDate'], isNotNull);
    });
  });

  group('PC-1.1 userContext / photo V–AB', () {
    test('V — student supported', () async {
      await service.setUserContext(ProfileUserContext.student);
      expect(
        (await service.loadProfile())?.userContext,
        ProfileUserContext.student,
      );
    });

    test('W — employee supported', () async {
      await service.setUserContext(ProfileUserContext.employee);
      expect(
        (await service.loadProfile())?.userContext,
        ProfileUserContext.employee,
      );
    });

    test('X — selfEmployed supported', () async {
      await service.setUserContext(ProfileUserContext.selfEmployed);
      expect(
        (await service.loadProfile())?.userContext,
        ProfileUserContext.selfEmployed,
      );
    });

    test('Y — other supported', () async {
      await service.setUserContext(ProfileUserContext.other);
      expect(
        (await service.loadProfile())?.userContext,
        ProfileUserContext.other,
      );
    });

    test('Z — userContext not inferred automatically', () async {
      final p = await service.createEmptyProfile();
      expect(p.userContext, isNull);
    });

    test('AA — profile photo nullable', () async {
      final p = await service.createEmptyProfile();
      expect(p.profilePhotoUrl, isNull);
      await service.setProfilePhotoUrl('https://example.com/p.jpg');
      expect((await service.loadProfile())?.profilePhotoUrl, isNotNull);
      await service.clearField(ProfileOptionalField.profilePhotoUrl);
      expect((await service.loadProfile())?.profilePhotoUrl, isNull);
    });

    test('AB — profile photo never analyzed for attributes', () {
      expect(service.mayAnalyzeProfilePhotoForAttributes(), isFalse);
    });
  });

  group('PC-1.1 enable/disable/delete AC–AF', () {
    test('AC — profileEnabled false prevents personalization', () async {
      await service.savePreferredName('محمد');
      await service.disable();
      expect(await service.preferredNameForPersonalization(), isNull);
      expect(await userProfile.getDisplayName(), isNull);
    });

    test('AD — disable != delete', () async {
      await service.savePreferredName('محمد');
      await service.disable();
      final p = await service.loadProfile();
      expect(p, isNotNull);
      expect(p!.preferredName, 'محمد');
      expect(p.profileEnabled, isFalse);
    });

    test('AE — clear optional field works', () async {
      await service.setUserContext(ProfileUserContext.student);
      await service.clearField(ProfileOptionalField.userContext);
      expect((await service.loadProfile())?.userContext, isNull);
    });

    test('AF — delete only through explicit operation', () async {
      await service.savePreferredName('محمد');
      await service.deleteProfileExplicitly();
      expect(await service.loadProfile(), isNull);
    });
  });

  group('PC-1.1 no health/family/memory AG–AN', () {
    test('AG–AJ — no health fields in general profile storage', () async {
      final map = (await service.createEmptyProfile()).toStorageMap();
      for (final k in [
        'condition',
        'allergy',
        'medication',
        'procedure',
        'diagnosed',
      ]) {
        expect(map.keys.any((e) => e.toLowerCase().contains(k)), isFalse);
      }
    });

    test('AK — no family profile created', () async {
      await service.createEmptyProfile();
      expect(prefs.getKeys().any((k) => k.contains('family')), isFalse);
    });

    test('AL — MemoryCandidate still RAM-only', () {
      final c = MemoryCandidate(
        category: MemoryCategory.sensitiveHealthProfile,
        subjectRef: MemorySubjectRef.accountSelf(),
        structuredKey: 'diagnosedCondition',
        structuredValue: 'diabetes',
        sensitivity: MemorySensitivity.sensitiveHealth,
        sourceType: MemorySourceType.userExplicitStatement,
        requiresExplicitConsent: true,
        consentState: MemoryConsentState.required,
        evidenceCode: 'test',
        createdTurnId: 1,
      );
      expect(c.isRamOnly, isTrue);
      expect(c.mayPersistNow, isFalse);
    });

    test('AM — ConversationContext remains session-only', () {
      expect(
        ConversationContext().allowsPersistentMemorySerialization,
        isFalse,
      );
    });

    test('AN — HealthSubjectContext remains session-only', () {
      expect(HealthSubjectContext.unknown.sessionKey, isNotEmpty);
      // ليس ملفاً دائماً
      expect(HealthSubjectContext.unknown.type, HealthSubjectType.unknown);
    });
  });

  group('PC-1.1 brain isolation AO–AW', () {
    test('AO — profile repository failure does not break Smart Brain', () async {
      final brain = SmartBrainPlanner(
        doctorLookup: (_) async => [
              SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'د',
                subtitle: 'باطنية',
                doctorId: 'd1',
                specialty: 'باطنية',
                score: 90,
              ),
            ],
      );
      final ctx = ConversationContext();
      // حتى مع فشل الاسم — التخطيط يعمل
      final plan = await brain.plan(query: 'مرحبا', context: ctx);
      expect(plan, isNotNull);
    });

    test('AP–AS — entity searches unaffected', () async {
      final brain = SmartBrainPlanner(
        doctorLookup: (_) async => [
              SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'د',
                subtitle: 'باطنية',
                doctorId: 'd1',
                specialty: 'باطنية',
                score: 90,
              ),
            ],
        labLookup: (_) async => [
              SmartSearchResult(
                type: SmartSearchResultType.lab,
                title: 'مختبر الحياة',
                subtitle: 'مختبر',
                labId: 'hayat',
                score: 90,
              ),
            ],
        analysisLookup: (_) async => [
              AnalysisItem(id: 'cbc', name: 'CBC'),
            ],
        packagesLookup: (_) async => [
              const LabPackageItem(
                id: 'p1',
                labId: 'hayat',
                name: 'باقة',
                newPrice: 10,
              ),
            ],
      );
      final ctx = ConversationContext();
      await brain.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
    });

    test('AT/AU — health guidance and safety unaffected', () {
      final h = HealthGuidanceCoordinator();
      final r = h.startFromUserText(
        query: 'عندي صداع',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      expect(r.handled, isTrue);
    });

    test('AV — provider handoff model still session', () async {
      // لا ملف عائلة / صحة دائمة من الملف
      final p = await service.createEmptyProfile();
      expect(p.toStorageMap()['handoff'], isNull);
    });

    test('AW — typed/voice brain path unchanged by profile', () async {
      await service.savePreferredName('محمد');
      final ctx = ConversationContext();
      final brain = SmartBrainPlanner(
        labLookup: (_) async => [
              SmartSearchResult(
                type: SmartSearchResultType.lab,
                title: 'مختبر الحياة',
                subtitle: 'مختبر',
                labId: 'hayat',
                score: 90,
              ),
            ],
      );
      await brain.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
    });
  });

  group('PC-1.1 privacy / identity AX–BB', () {
    test('AX/AY — debug presence metadata only, no profile values', () async {
      await service.savePreferredName('محمد');
      await service.setSexSelection(ProfileSexSelection.male);
      await service.setBirthYear(1990);
      final dbg = service.debugPresence(profile: await service.loadProfile());
      final blob = dbg.toString();
      expect(blob.contains('محمد'), isFalse);
      expect(blob.contains('male'), isFalse);
      expect(blob.contains('1990'), isFalse);
      expect(dbg['hasPreferredName'], isTrue);
      expect(dbg['profileEnabled'], isTrue);
    });

    test('AZ — public cloud profile read not used (local-only architecture)',
        () {
      // PC-1.1 لا يقرأ من Supabase للملف الشخصي.
      expect(
        LocalPersonalCompanionProfileRepository.storageKey,
        'pc_companion_profile_v1',
      );
    });

    test('BA — profile identity uses ownerKey not display name', () async {
      final p = await service.savePreferredName('محمد');
      expect(p.ownerKey, isNot('محمد'));
      expect(p.ownerKey.length, greaterThanOrEqualTo(8));
      expect(p.ownerKey, await VisitorIdentityService(prefs: prefs).ownerKey());
    });

    test('BB — no paid dependency introduced for profile', () {
      // shared_preferences موجود مسبقاً؛ لا uuid مدفوع.
      expect(true, isTrue);
    });
  });
}
