/// Phase 3A — تأسيس الملف الشخصي الأساسي فوق PersonalCompanionProfile القائم.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/services/user_profile_service.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalPersonalCompanionProfileRepository repo;
  late PersonalCompanionProfileService service;
  late PersonalProfileFoundation foundation;
  late UserProfileService userProfile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = LocalPersonalCompanionProfileRepository(prefs: prefs);
    service = PersonalCompanionProfileService(repository: repo);
    foundation = PersonalProfileFoundation(profiles: service);
    userProfile = UserProfileService(prefs: prefs, companion: service);
  });

  group('A — ملف فارغ عند أول استخدام', () {
    test('لا ملف حتى يُنشأ', () async {
      expect(await foundation.load(), isNull);
      expect(await foundation.displayName(), isNull);
      expect(await foundation.ageYears(), isNull);
      expect(await foundation.sex(), isNull);
      expect(await foundation.isBasicProfileComplete(), isFalse);
    });
  });

  group('B–E — حفظ أساسي', () {
    test('B — حفظ اسم عربي ثلاثي', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      expect(await foundation.fullName(), 'محمد علي حسن');
      expect(await foundation.displayName(), 'محمد علي حسن');
    });

    test('C — حفظ سنة ميلاد / عمر مشتق', () async {
      await foundation.saveBasicProfile(
        fullName: 'سارة أحمد كريم',
        birthYear: 1995,
        sex: ProfileSexSelection.female,
      );
      final age = await foundation.ageYears();
      expect(age, DateTime.now().year - 1995);
      final p = await foundation.load();
      expect(p?.birthYear, 1995);
      expect(p?.birthDate, isNull);
    });

    test('C2 — تاريخ ميلاد كامل مفضّل', () async {
      await foundation.saveBasicProfile(
        fullName: 'علي محمود جاسم',
        birthDate: DateTime(1992, 3, 10),
        sex: ProfileSexSelection.male,
      );
      final p = await foundation.load();
      expect(p?.birthDate?.year, 1992);
      expect(p?.birthYear, isNull);
      expect(p?.ageYears, isNotNull);
    });

    test('C3 — عمر صريح يُحوَّل لسنة ميلاد', () async {
      final now = DateTime(2026, 6, 1);
      await foundation.saveBasicProfile(
        fullName: 'نور قاسم علي',
        ageYears: 30,
        sex: ProfileSexSelection.female,
        now: now,
      );
      expect((await foundation.load())?.birthYear, 1996);
      expect(await foundation.ageYears(now: now), 30);
    });

    test('D — حفظ ذكر', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      expect(await foundation.sex(), ProfileSexSelection.male);
    });

    test('E — حفظ أنثى', () async {
      await foundation.saveBasicProfile(
        fullName: 'زينب حسن علي',
        birthYear: 1992,
        sex: ProfileSexSelection.female,
      );
      expect(await foundation.sex(), ProfileSexSelection.female);
    });
  });

  group('F — إعادة التحميل من SharedPreferences', () {
    test('persist + reload', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthDate: DateTime(1990, 1, 1),
        sex: ProfileSexSelection.male,
      );
      final reloaded = PersonalProfileFoundation(
        profiles: PersonalCompanionProfileService(
          repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
        ),
      );
      expect(await reloaded.fullName(), 'محمد علي حسن');
      expect(await reloaded.sex(), ProfileSexSelection.male);
      expect(await reloaded.isBasicProfileComplete(), isTrue);
    });
  });

  group('G/H/I — التعديل لاحقاً', () {
    test('G — تعديل الاسم', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      await service.savePreferredName('أحمد علي حسن');
      expect(await foundation.fullName(), 'أحمد علي حسن');
    });

    test('H — تعديل الميلاد/العمر', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      await service.setBirthYear(1988);
      expect((await foundation.load())?.birthYear, 1988);
    });

    test('I — تعديل الجنس', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      await service.setSexSelection(ProfileSexSelection.female);
      expect(await foundation.sex(), ProfileSexSelection.female);
    });
  });

  group('J — لا أعراض/بيانات سريرية في الملف', () {
    test('خريطة التخزين بلا أعراض', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      final map = (await foundation.load())!.toStorageMap();
      expect(map.keys, isNot(contains('symptoms')));
      expect(map.keys, isNot(contains('diagnoses')));
      expect(map.keys, isNot(contains('medications')));
      expect(map.keys, isNot(contains('allergies')));
      expect(map.containsKey('preferredName'), isTrue);
      expect(map.containsKey('birthYear'), isTrue);
      expect(map.containsKey('sexSelection'), isTrue);
    });
  });

  group('K/L — ConversationContext و healthSubject', () {
    test('حفظ الملف لا يكتب healthSubject ولا يلوّث السياق', () async {
      final ctx = ConversationContext();
      expect(ctx.healthSubject.isKnown, isFalse);

      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );

      expect(ctx.healthSubject.isKnown, isFalse);
      expect(ctx.healthSubject.type, HealthSubjectType.unknown);
      expect(ctx.mskSession.active, isFalse);
      expect(ctx.respiratorySession.active, isFalse);
    });

    test('healthSubject الجلسة لا يُستبدل بالملف', () async {
      final ctx = ConversationContext();
      ctx.setHealthSubject(
        const HealthSubjectContext(
          sessionKey: 'subj_child',
          type: HealthSubjectType.child,
          evidence: HealthSubjectEvidence.explicitRelationship,
          isChild: true,
          ageYears: 8,
          ageGroup: 'child',
        ),
      );

      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );

      expect(ctx.healthSubject.type, HealthSubjectType.child);
      expect(ctx.healthSubject.ageYears, 8);
      expect(await foundation.ageYears(), DateTime.now().year - 1990);
    });
  });

  group('تحقق بسيط', () {
    test('اسم فارغ مرفوض', () async {
      expect(
        () => foundation.saveBasicProfile(
          fullName: '   ',
          birthYear: 1990,
          sex: ProfileSexSelection.male,
        ),
        throwsA(isA<ProfileValidationException>()),
      );
    });

    test('عمر غير معقول مرفوض', () async {
      expect(
        () => foundation.saveBasicProfile(
          fullName: 'محمد علي حسن',
          ageYears: 200,
          sex: ProfileSexSelection.male,
        ),
        throwsA(isA<ProfileValidationException>()),
      );
    });
  });

  group('UserProfileService Phase 3A', () {
    test('foundation + markFirstLaunchFinished يغلق بوابة أول تشغيل', () async {
      expect(await userProfile.isOnboardingDone(), isFalse);
      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      await userProfile.markFirstLaunchFinished();
      expect(await userProfile.isOnboardingDone(), isTrue);
      expect(await userProfile.getDisplayName(), 'محمد علي حسن');
    });
  });

  group('M — Phase 2G لا يتأثر', () {
    test('تحويل صريح من MSK ما زال يعمل مع وجود ملف', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد علي حسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      final ctx = ConversationContext();
      final planner = SmartBrainPlanner(
        nluClient: NluClient.disabled,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        analysisLookup: (_) async => const [],
        packagesLookup: (_) async => const [],
        packagesForAnalysisLookup: (_) async => const [],
        activePackagesLookup: ({labId, nameQuery}) async => const [],
        discountedPackagesLookup: ({labId}) async => const [],
      );
      await planner.plan(query: 'اني عندي ألم بالظهر', context: ctx);
      expect(ctx.mskSession.lastQuestionKey, isNotNull);
      final gen = ctx.conversationGeneration;
      await planner.plan(query: 'أريد طبيب عظام', context: ctx);
      expect(ctx.mskSession.active, isFalse);
      expect(ctx.conversationGeneration, gen + 1);
      // Phase 3C: عمر الملف جائز للذات فقط — لا يكسر تحويل 2G.
      expect(ctx.healthSubject.type, HealthSubjectType.self);
      expect(ctx.healthSubject.ageYears, 36);
    });
  });

  group('parseBirthOrAgeInput', () {
    test('يفسّر العمر والسنة والتاريخ', () {
      expect(
        PersonalProfileFoundation.parseBirthOrAgeInput('35')?.ageYears,
        35,
      );
      expect(
        PersonalProfileFoundation.parseBirthOrAgeInput('1990')?.birthYear,
        1990,
      );
      expect(
        PersonalProfileFoundation.parseBirthOrAgeInput('1990-06-15')
            ?.birthDate
            ?.day,
        15,
      );
    });
  });
}
