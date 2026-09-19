/// Phase 3D STEP 3 — تخصيص اجتماعي بالاسم + تنويع حتمي + استمرارية خفيفة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/startup_greeting.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const social = GhadeerSocialConversation();
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

  group('اسم من الملف القائم', () {
    test('greetingAddressName يستخرج الاسم الأول فقط', () {
      expect(greetingAddressName('محمد الموسوي'), 'محمد');
      expect(greetingAddressName(null), isNull);
      expect(greetingAddressName(''), isNull);
    });

    test('مع اسم: هلا قد تتضمن محمد', () {
      final r = social.resolve(
        'هلا',
        firstName: 'محمد',
        socialContext: GhadeerSocialContext.empty,
      )!;
      expect(r.usedName, isTrue);
      expect(r.message, contains('محمد'));
      expect(r.message, isNot(contains('الموسوي')));
      expect(
        GhadeerSocialConversation.catalogs[r.category]!
            .any((b) => r.message.contains(b.split('،').first) || r.usedName),
        isTrue,
      );
    });

    test('بلا اسم: رد عام من الكتالوج', () {
      final r = social.resolve('هلا')!;
      expect(r.usedName, isFalse);
      expect(r.message, GhadeerSocialConversation.answerGreeting);
      expect(r.message.contains('محمد'), isFalse);
    });

    test('لا اختراع اسم من النص', () {
      final r = social.resolve('هلا', firstName: null)!;
      expect(r.message, isNot(contains('علي')));
      expect(r.usedName, isFalse);
    });
  });

  group('منع تكرار الاسم', () {
    test('هلا بالاسم ثم شلونك بدون ثم شكرا بالاسم', () {
      var ctx = GhadeerSocialContext.empty;
      final a = social.resolve('هلا', firstName: 'محمد', socialContext: ctx)!;
      expect(a.usedName, isTrue);
      expect(a.message, contains('محمد'));
      ctx = a.nextContext;

      final b = social.resolve('شلونك', firstName: 'محمد', socialContext: ctx)!;
      expect(b.usedName, isFalse);
      expect(b.message, isNot(contains('محمد')));
      ctx = b.nextContext;

      final c = social.resolve('شكرا', firstName: 'محمد', socialContext: ctx)!;
      expect(c.usedName, isTrue);
      expect(c.message, contains('محمد'));
    });
  });

  group('تنويع حتمي', () {
    test('كل رد ضمن الكتالوج المسموح', () {
      var ctx = GhadeerSocialContext.empty;
      for (final q in ['هلا', 'هلا', 'هلا']) {
        final r = social.resolve(q, socialContext: ctx)!;
        final catalog = GhadeerSocialConversation.catalogs[r.category]!;
        expect(catalog, contains(r.message), reason: q);
        ctx = r.nextContext;
      }
    });

    test('نفس المدخلات تعطي نفس النتيجة (determinism)', () {
      const input = GhadeerSocialContext(
        lastCategory: GhadeerSocialCategory.greeting,
        lastVariantIndex: 0,
        socialTurnCount: 1,
        nameUsedOnLastTurn: true,
      );
      final a = social.resolve('هلا', firstName: 'محمد', socialContext: input)!;
      final b = social.resolve('هلا', firstName: 'محمد', socialContext: input)!;
      expect(a.message, b.message);
      expect(a.variantIndex, b.variantIndex);
      expect(a.usedName, b.usedName);
    });
  });

  group('مخطّط + ملف', () {
    test('مع ملف محمد الموسوي — هلا تتضمن محمد', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد الموسوي',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      final ctx = ConversationContext();
      final plan = await planner().plan(query: 'هلا', context: ctx);
      expect(plan.message, contains('محمد'));
      expect(plan.message, isNot(contains('الموسوي')));
      expect(ctx.ghadeerSocial.socialTurnCount, 1);
      expect(ctx.ghadeerSocial.nameUsedOnLastTurn, isTrue);
    });

    test('بلا ملف — رد عام', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(query: 'هلا', context: ctx);
      expect(plan.message, GhadeerSocialConversation.answerGreeting);
    });

    test('تكرار اجتماعي لا يضع الاسم في كل رد', () async {
      await foundation.saveBasicProfile(
        fullName: 'محمد الموسوي',
        birthYear: 1990,
        sex: ProfileSexSelection.male,
      );
      final ctx = ConversationContext();
      final p = planner();
      final a = await p.plan(query: 'هلا', context: ctx);
      final b = await p.plan(query: 'شلونك', context: ctx);
      final c = await p.plan(query: 'شكرا', context: ctx);
      expect(a.message, contains('محمد'));
      expect(b.message, isNot(contains('محمد')));
      expect(c.message, contains('محمد'));
    });
  });

  group('مختلط + سريري + سلامة STEP 2', () {
    test('هلا اريد طبيب اطفال لا يُستهلك اجتماعياً', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(
        query: 'هلا اريد طبيب اطفال',
        context: ctx,
      );
      expect(plan.message, isNot(contains('هلا بيك')));
      expect(social.tryAnswer('هلا اريد طبيب اطفال'), isNull);
    });

    test('شكرا اريد مختبر لا يبقى شكرا فقط', () {
      expect(social.tryAnswer('شكرا اريد مختبر'), isNull);
    });

    test('شلونك أثناء MSK يحفظ الجلسة', () async {
      final ctx = ConversationContext();
      final p = planner();
      await p.plan(query: 'اني عندي ألم بالظهر', context: ctx);
      final qKey = ctx.mskSession.lastQuestionKey;
      final gen = ctx.conversationGeneration;
      expect(qKey, isNotNull);

      final socialPlan = await p.plan(query: 'شلونك؟', context: ctx);
      expect(socialPlan.kind, AssistantActionKind.showMessage);
      expect(
        GhadeerSocialConversation.catalogs[GhadeerSocialCategory.howAreYou],
        contains(socialPlan.message),
      );
      expect(ctx.mskSession.active, isTrue);
      expect(ctx.mskSession.lastQuestionKey, qKey);
      expect(ctx.conversationGeneration, gen);
      expect(ctx.healthSubject.type, HealthSubjectType.self);

      await p.plan(query: 'اي خفيف', context: ctx);
      expect(ctx.mskSession.active, isTrue);
    });
  });

  group('انحدار هوية', () {
    test('STEP 1 facts + unknown', () {
      const id = GhadeerIdentity();
      expect(
        id.tryAnswer('منو ابوك الروحي'),
        contains(GhadeerIdentity.spiritualFatherName),
      );
      expect(
        id.tryAnswer('من برمجك؟'),
        GhadeerIdentity.answerUnknownIdentity,
      );
    });
  });
}
