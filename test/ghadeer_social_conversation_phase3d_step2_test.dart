/// Phase 3D STEP 2 — محادثة اجتماعية standalone + انحدار الهوية.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const social = GhadeerSocialConversation();
  const identity = GhadeerIdentity();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

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

  group('اجتماعي standalone', () {
    test('تحية / صباح / مساء / شلونك / شكر / وداع', () {
      expect(social.tryAnswer('هلا'), GhadeerSocialConversation.answerGreeting);
      expect(
        social.tryAnswer('مرحبا'),
        GhadeerSocialConversation.answerGreeting,
      );
      expect(
        social.tryAnswer('صباح الخير'),
        GhadeerSocialConversation.answerMorning,
      );
      expect(
        social.tryAnswer('مساء الخير'),
        GhadeerSocialConversation.answerEvening,
      );
      expect(
        social.tryAnswer('شلونك'),
        GhadeerSocialConversation.answerHowAreYou,
      );
      expect(
        social.tryAnswer('شخبارك'),
        GhadeerSocialConversation.answerHowAreYou,
      );
      expect(
        social.tryAnswer('شكو ماكو'),
        GhadeerSocialConversation.answerHowAreYou,
      );
      expect(social.tryAnswer('شكرا'), GhadeerSocialConversation.answerThanks);
      expect(social.tryAnswer('ممنون'), GhadeerSocialConversation.answerThanks);
      expect(
        social.tryAnswer('عاشت ايدك'),
        GhadeerSocialConversation.answerThanks,
      );
      expect(social.tryAnswer('تسلم'), GhadeerSocialConversation.answerThanks);
      expect(
        social.tryAnswer('احبك'),
        GhadeerSocialConversation.answerAffection,
      );
      expect(
        social.tryAnswer('احبك'),
        isNot(contains('وأنا أحبك')),
      );
      expect(
        social.tryAnswer('خوش تطبيق'),
        GhadeerSocialConversation.answerPositiveFeedback,
      );
      expect(
        social.tryAnswer('انت خوش مساعد'),
        GhadeerSocialConversation.answerPositiveFeedback,
      );
      expect(
        social.tryAnswer('مع السلامة'),
        GhadeerSocialConversation.answerGoodbye,
      );
      expect(social.tryAnswer('باي'), GhadeerSocialConversation.answerGoodbye);
      expect(
        social.tryAnswer('تصبح على خير'),
        GhadeerSocialConversation.answerGoodNight,
      );
    });

    test('مخطّط يعيد ردوداً اجتماعية', () async {
      final cases = {
        'شلونك؟': GhadeerSocialConversation.answerHowAreYou,
        'شكراً': GhadeerSocialConversation.answerThanks,
        'احبك': GhadeerSocialConversation.answerAffection,
        'مع السلامة': GhadeerSocialConversation.answerGoodbye,
      };
      for (final e in cases.entries) {
        final ctx = ConversationContext();
        final plan = await planner().plan(query: e.key, context: ctx);
        expect(plan.kind, AssistantActionKind.showMessage, reason: e.key);
        expect(plan.message, e.value, reason: e.key);
        expect(plan.textFirstOnly, isTrue);
        expect(ctx.healthSubject.type, HealthSubjectType.unknown);
      }
    });
  });

  group('مختلط — الفعل/الطب يفوز', () {
    test('جمل مختلطة لا تطابق الاجتماعي', () {
      for (final q in [
        'هلا اريد طبيب اطفال',
        'صباح الخير اريد مختبر',
        'شكرا اتصل بالدكتور',
        'شلونك عندي ألم بالركبة',
        'مساء الخير اريد طبيب عصبية',
        'ممنون بس اريد احجز موعد',
        'حبيبي اريد عروض المختبرات',
        'شلونك عندي ضيق بالتنفس',
      ]) {
        expect(social.tryAnswer(q), isNull, reason: q);
      }
    });

    test('هلا اريد طبيب اطفال → بحث لا اجتماعي', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(
        query: 'هلا اريد طبيب اطفال',
        context: ctx,
      );
      expect(plan.message, isNot(GhadeerSocialConversation.answerGreeting));
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.runSpecialtySearch,
          AssistantActionKind.runDoctorSearch,
          AssistantActionKind.runGeneralSearch,
        ),
      );
    });

    test('شلونك عندي ألم بالركبة → مسار طبي لا اجتماعي', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(
        query: 'شلونك عندي ألم بالركبة',
        context: ctx,
      );
      expect(plan.message, isNot(GhadeerSocialConversation.answerHowAreYou));
      expect(plan.kind, isNot(AssistantActionKind.runGeneralSearch));
    });
  });

  group('جلسة سريرية + اجتماعي', () {
    test('شلونك أثناء MSK يحفظ الجلسة ثم يستمر الجواب', () async {
      final ctx = ConversationContext();
      final p = planner();
      await p.plan(query: 'اني عندي ألم بالظهر', context: ctx);
      expect(ctx.mskSession.active, isTrue);
      final qKey = ctx.mskSession.lastQuestionKey;
      final gen = ctx.conversationGeneration;
      expect(qKey, isNotNull);

      final socialPlan = await p.plan(query: 'شلونك؟', context: ctx);
      expect(socialPlan.message, GhadeerSocialConversation.answerHowAreYou);
      expect(ctx.mskSession.active, isTrue);
      expect(ctx.mskSession.lastQuestionKey, qKey);
      expect(ctx.conversationGeneration, gen);
      expect(ctx.healthSubject.type, HealthSubjectType.self);

      await p.plan(query: 'اي خفيف', context: ctx);
      expect(ctx.mskSession.active, isTrue);
      expect(ctx.conversationGeneration, gen);
    });

    test('شكرا أثناء MSK لا تمسح السؤال المعلّق', () async {
      final ctx = ConversationContext();
      final p = planner();
      await p.plan(query: 'اني عندي ألم بالظهر', context: ctx);
      final qKey = ctx.mskSession.lastQuestionKey;
      expect(qKey, isNotNull);

      final plan = await p.plan(query: 'شكرا', context: ctx);
      expect(plan.message, GhadeerSocialConversation.answerThanks);
      expect(ctx.mskSession.active, isTrue);
      expect(ctx.mskSession.lastQuestionKey, qKey);
    });

    test('عاشت ايدك أثناء MSK تحفظ الحالة', () async {
      final ctx = ConversationContext();
      final p = planner();
      await p.plan(query: 'اني عندي ألم بالظهر', context: ctx);
      final qKey = ctx.mskSession.lastQuestionKey;

      final plan = await p.plan(query: 'عاشت ايدك', context: ctx);
      expect(plan.message, GhadeerSocialConversation.answerThanks);
      expect(ctx.mskSession.lastQuestionKey, qKey);
      expect(ctx.mskSession.active, isTrue);
    });
  });

  group('هوية غير معروفة', () {
    test('صنعك/برمجك/طورك/صاحب → رد آمن', () {
      for (final q in [
        'من صنعك؟',
        'منو صنعك؟',
        'من برمجك؟',
        'منو برمجك؟',
        'من طورك؟',
        'منو طورك؟',
        'من صاحب التطبيق؟',
        'من المدير؟',
      ]) {
        final a = identity.tryAnswer(q);
        expect(a, GhadeerIdentity.answerUnknownIdentity, reason: q);
        expect(a, isNot(contains('حيدر')));
        expect(a, isNot(contains('مصطفى')));
        expect(a, isNot(contains('محمد عبد الحسن')));
      }
    });

    test('كلمات طور/برمجة داخل جمل أخرى لا تُخطف', () {
      expect(identity.tryAnswer('أريد أطور لياقتي'), isNull);
      expect(identity.tryAnswer('دورة برمجة للمبتدئين'), isNull);
    });
  });

  group('انحدار STEP 1', () {
    test('حقائق الهوية المعتمدة ما زالت', () {
      expect(
        identity.tryAnswer('منو ابوك الروحي'),
        contains(GhadeerIdentity.spiritualFatherName),
      );
      expect(
        identity.tryAnswer('من الداعم للتطبيق'),
        contains(GhadeerIdentity.supporterName),
      );
      final assistants = identity.tryAnswer('من المساعدين');
      expect(assistants, contains(GhadeerIdentity.buildingAssistantName));
      expect(
        assistants,
        contains('الصديق العزيز مصطفى كامل سعود العبودي'),
      );
      expect(
        identity.tryAnswer('من الراعي الرسمي'),
        contains('أبو سعدية للموبايلات'),
      );
    });
  });
}
