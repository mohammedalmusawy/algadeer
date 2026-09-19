/// Phase 3C — جسر آمن لسياق ملف المالك (عمر/جنس) عند تأكيد الذات فقط.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/utils/clinic_contact_message.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/startup_greeting.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PersonalCompanionProfileService profiles;
  late PersonalProfileFoundation foundation;
  late OwnerProfileContextBridge bridge;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    profiles = PersonalCompanionProfileService(
      repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
    );
    foundation = PersonalProfileFoundation(profiles: profiles);
    bridge = const OwnerProfileContextBridge();
  });

  Future<void> seedOwner({
    int birthYear = 1991,
    ProfileSexSelection sex = ProfileSexSelection.male,
  }) async {
    await foundation.saveBasicProfile(
      fullName: 'محمد عبد الحسن',
      birthYear: birthYear,
      sex: sex,
    );
  }

  SmartBrainPlanner planner() => SmartBrainPlanner(
        nluClient: NluClient.disabled,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        analysisLookup: (_) async => const [],
        packagesLookup: (_) async => const [],
        packagesForAnalysisLookup: (_) async => const [],
        activePackagesLookup: ({labId, nameQuery}) async => const [],
        discountedPackagesLookup: ({labId}) async => const [],
      );

  group('جسر المالك', () {
    test('1/2 — ذات المالك تحل عمر وجنس الملف', () async {
      await seedOwner(birthYear: 1991, sex: ProfileSexSelection.male);
      final ctx = ConversationContext();
      await planner().plan(query: 'اني عندي ألم بالظهر', context: ctx);
      expect(ctx.healthSubject.type, HealthSubjectType.self);
      expect(ctx.healthSubject.ageYears, DateTime.now().year - 1991);
      expect(ctx.healthSubject.reservedSexHint, 'male');
    });

    test('3/4 — الطفل لا يرث عمر/جنس المالك', () async {
      await seedOwner();
      final ctx = ConversationContext();
      await planner().plan(query: 'ابني عنده سعال من يومين', context: ctx);
      expect(ctx.healthSubject.type, HealthSubjectType.child);
      expect(ctx.healthSubject.ageYears, isNot(DateTime.now().year - 1991));
      expect(ctx.healthSubject.reservedSexHint, isNull);
    });

    test('5 — الأم لا ترث عمر/جنس المالك', () async {
      await seedOwner();
      final ctx = ConversationContext();
      await planner().plan(query: 'أمي عندها ألم بالركبة', context: ctx);
      expect(ctx.healthSubject.type, HealthSubjectType.mother);
      expect(ctx.healthSubject.ageYears, isNull);
      expect(ctx.healthSubject.reservedSexHint, isNull);
    });

    test('6 — الأب لا يرث عمر/جنس المالك', () async {
      await seedOwner();
      final ctx = ConversationContext();
      await planner().plan(query: 'ابوي عنده ألم بالظهر', context: ctx);
      expect(ctx.healthSubject.type, HealthSubjectType.father);
      expect(ctx.healthSubject.ageYears, isNull);
      expect(ctx.healthSubject.reservedSexHint, isNull);
    });

    test('7/8 — عمر صريح يغلب الملف ولا يعدّله', () async {
      await seedOwner(birthYear: 1991);
      final before = await foundation.load();
      expect(before?.birthYear, 1991);

      final ctx = ConversationContext();
      await planner().plan(query: 'اني عندي ألم بالظهر', context: ctx);
      await planner().plan(query: 'عمري 36', context: ctx);

      expect(ctx.healthSubject.type, HealthSubjectType.self);
      // العمر الصريح في الدورة له أسبقية على اشتقاق الملف في الجسر/العمر.
      final after = await foundation.load();
      expect(after?.birthYear, 1991);
      expect(after?.toStorageMap()['birthYear'], 1991);
    });

    test('9 — تبديل مالك → طفل يقطع صلاحية الملف', () async {
      await seedOwner();
      final ctx = ConversationContext();
      await planner().plan(query: 'اني عندي ألم بالظهر', context: ctx);
      expect(ctx.healthSubject.reservedSexHint, 'male');
      await planner().plan(query: 'ابني عنده سعال', context: ctx);
      expect(ctx.healthSubject.type, HealthSubjectType.child);
      expect(ctx.healthSubject.reservedSexHint, isNull);
      expect(ctx.healthSubject.ageYears, isNot(DateTime.now().year - 1991));
    });

    test('10 — عودة طفل → مالك تعيد صلاحية الملف', () async {
      await seedOwner(birthYear: 1990, sex: ProfileSexSelection.female);
      final ctx = ConversationContext();
      await planner().plan(query: 'ابني عنده سعال', context: ctx);
      expect(ctx.healthSubject.type, HealthSubjectType.child);
      await planner().plan(query: 'اني عندي صداع', context: ctx);
      expect(ctx.healthSubject.type, HealthSubjectType.self);
      expect(ctx.healthSubject.ageYears, DateTime.now().year - 1990);
      expect(ctx.healthSubject.reservedSexHint, 'female');
    });

    test('11/12 — تعديل الميلاد/الجنس يؤثر لاحقاً', () async {
      await seedOwner(birthYear: 1990, sex: ProfileSexSelection.male);
      await profiles.setBirthYear(1985);
      await profiles.setSexSelection(ProfileSexSelection.female);

      final ctx = ConversationContext();
      await planner().plan(query: 'اني عندي ألم بالظهر', context: ctx);
      expect(ctx.healthSubject.ageYears, DateTime.now().year - 1985);
      expect(ctx.healthSubject.reservedSexHint, 'female');
    });

    test('13 — موضوع مجهول لا يفترض المالك عبر الجسر', () {
      final profile = PersonalCompanionProfile(
        profileId: 'x',
        ownerKey: 'o',
        birthYear: 1990,
        sexSelection: ProfileSexSelection.male,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(
        bridge.mayApplyOwnerProfile(
          subject: HealthSubjectContext.unknown,
          resolved: ResolvedConversationSubject.unknown,
        ),
        isFalse,
      );
      final enriched = bridge.enrichSubjectIfAllowed(
        subject: HealthSubjectContext.unknown,
        resolved: ResolvedConversationSubject.unknown,
        profile: profile,
      );
      expect(enriched.ageYears, isNull);
      expect(enriched.reservedSexHint, isNull);
    });

    test('14 — الأعراض لا تُحفظ في الملف', () async {
      await seedOwner();
      final ctx = ConversationContext();
      await planner().plan(query: 'اني عندي ألم بالظهر', context: ctx);
      final map = (await foundation.load())!.toStorageMap();
      expect(map.keys, isNot(contains('symptoms')));
      expect(map.containsKey('preferredName'), isTrue);
    });

    test('15/16 — ConversationContext جلسة و healthSubject سلطة الموضوع', () async {
      await seedOwner();
      final ctx = ConversationContext();
      await planner().plan(query: 'ابني عنده سعال', context: ctx);
      expect(ctx.healthSubject.type, HealthSubjectType.child);
      expect(ctx.healthSubject.isKnown, isTrue);
      // لا يُفرض عمر المالك.
      expect(ctx.healthSubject.ageYears, isNull);
    });
  });

  group('حفظ 3B / 2G', () {
    test('21 — التحية ما زالت مرحباً بك، {name}', () {
      final g = PersonalizedGreeting.fromDisplayName('محمد عبد الحسن');
      expect(g.displayGreeting, 'مرحباً بك، محمد 👋');
      expect(g.spokenGreeting, startsWith('مرحباً بك'));
    });

    test('22 — الحجز name-only بلا عمر/جنس', () async {
      await seedOwner();
      final name = await foundation.fullName();
      final msg = ClinicContactMessage.whatsAppPrefill(
        patientFullName: name,
        providerTitle: 'د. علي',
        preferBookingWording: true,
      );
      expect(msg, contains('الاسم: محمد عبد الحسن'));
      expect(msg, isNot(contains('1991')));
      expect(msg, isNot(contains('ذكر')));
      expect(msg, isNot(contains('male')));
    });

    test('20 — 2G ما زال يعمل', () async {
      await seedOwner();
      final ctx = ConversationContext();
      await planner().plan(query: 'اني عندي ألم بالظهر', context: ctx);
      final gen = ctx.conversationGeneration;
      await planner().plan(query: 'أريد طبيب عظام', context: ctx);
      expect(ctx.mskSession.active, isFalse);
      expect(ctx.conversationGeneration, gen + 1);
    });
  });

  group('وحدة الجسر', () {
    test('explicit age overrides profile in resolveAge', () async {
      await seedOwner(birthYear: 1991);
      final p = await foundation.load();
      final r = bridge.resolveAge(
        profile: p,
        explicitAgeFromUtterance: 36,
      );
      expect(r.ageYears, 36);
      expect((await foundation.load())?.birthYear, 1991);
    });
  });
}
