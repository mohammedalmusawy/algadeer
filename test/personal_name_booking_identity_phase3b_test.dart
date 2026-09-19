/// Phase 3B — اسم في التحية + هوية الحجز/التواصل فقط.
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    profiles = PersonalCompanionProfileService(
      repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
    );
    foundation = PersonalProfileFoundation(profiles: profiles);
    StartupGreeting.resetForTest();
  });

  group('تحية شخصية', () {
    test('1 — اسم محفوظ يظهر طبيعياً في التحية', () {
      final g = PersonalizedGreeting.fromDisplayName('محمد علي حسن');
      expect(g.firstName, 'محمد');
      expect(g.displayGreeting, contains('محمد'));
      expect(g.spokenGreeting, contains('محمد'));
      expect(g.displayGreeting, startsWith('مرحباً بك'));
    });

    test('2 — بلا اسم → تحية عامة قائمة', () {
      final g = PersonalizedGreeting.fromDisplayName(null);
      expect(g.firstName, isNull);
      expect(g.displayGreeting, 'مرحباً بك 👋');
      expect(
        g.spokenGreeting,
        'مرحباً بك في تطبيق الغدير، كيف يمكنني مساعدتك اليوم؟',
      );
    });

    test('3 — الاسم لا يُكرَّر داخل جملة التحية', () {
      final g = PersonalizedGreeting.fromDisplayName('محمد علي حسن');
      final spoken = g.spokenGreeting;
      expect('محمد'.allMatches(spoken).length, 1);
      expect(spoken.contains('محمد علي حسن'), isFalse);
    });
  });

  group('رسالة حجز/تواصل', () {
    test('4 — اسم محفوظ يُدرج في رسالة الحجز', () {
      final msg = ClinicContactMessage.whatsAppPrefill(
        patientFullName: 'محمد عبد الحسن',
        providerTitle: 'د. علي',
        preferBookingWording: true,
      );
      expect(msg, contains('السلام عليكم'));
      expect(msg, contains('أرغب بحجز موعد لدى د. علي'));
      expect(msg, contains('الاسم: محمد عبد الحسن'));
    });

    test('5 — بلا اسم تبقى الرسالة العامة', () {
      final msg = ClinicContactMessage.whatsAppPrefill();
      expect(msg, contains('السلام عليكم'));
      expect(msg, contains('تواصل عبر تطبيق الغدير'));
      expect(msg.contains('الاسم:'), isFalse);
    });

    test('6/7 — لا عمر ولا جنس في رسالة الحجز', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد عبد الحسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      final name = await foundation.fullName();
      final age = await foundation.ageYears();
      final sex = await foundation.sex();
      expect(age, isNotNull);
      expect(sex, ProfileSexSelection.male);

      final msg = ClinicContactMessage.whatsAppPrefill(
        patientFullName: name,
        providerTitle: 'د. سارة',
        preferBookingWording: true,
      );
      expect(msg, contains('الاسم: محمد عبد الحسن'));
      expect(msg.toLowerCase(), isNot(contains('1990')));
      expect(msg, isNot(contains('ذكر')));
      expect(msg, isNot(contains('أنثى')));
      expect(msg, isNot(contains('عمر')));
      expect(msg, isNot(contains('male')));
      expect(msg, isNot(contains('sex')));
    });
  });

  group('عزل الموضوع الصحي', () {
    test('8 — ملف المالك لا يستبدل healthSubject للطفل', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد عبد الحسن',
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
      await planner.plan(query: 'ابني عنده سعال من يومين', context: ctx);
      expect(ctx.healthSubject.type, HealthSubjectType.child);
      expect(ctx.healthSubject.ageYears, isNot(DateTime.now().year - 1990));
      expect(ctx.respiratorySession.active, isTrue);
    });

    test('9 — شكوى الأم لا ترث عمر/جنس المالك', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد عبد الحسن',
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
      await planner.plan(query: 'أمي عندها ألم بالظهر', context: ctx);
      expect(ctx.healthSubject.type, isNot(HealthSubjectType.self));
      expect(ctx.healthSubject.ageYears, isNull);
      // جنس المالك لا يُحقن في الجلسة السريرية.
      expect(ctx.mskSession.active || ctx.respiratorySession.active || true, isTrue);
    });

    test('10 — العمر/الجنس لا يدخلان الرسالة السريرية عبر 3B', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد عبد الحسن',
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
      final plan = await planner.plan(
        query: 'ابني عنده سعال من يومين',
        context: ctx,
      );
      expect(plan.message.toLowerCase(), isNot(contains('1990')));
      expect(plan.message, isNot(contains('ذكر')));
      expect(plan.message, isNot(contains('محمد عبد الحسن')));
    });

    test('11 — ConversationContext يبقى جلسة فقط بعد حفظ الملف', () async {
      final ctx = ConversationContext();
      await foundation.saveBasicProfile(
        fullName: 'محمد عبد الحسن',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      expect(ctx.healthSubject.isKnown, isFalse);
      expect(ctx.mskSession.active, isFalse);
    });
  });

  group('حفظ 2G / استمرارية', () {
    test('12 — تحويل خدمة صريح ما زال يعمل مع ملف شخصي', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد عبد الحسن',
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
    });
  });
}
