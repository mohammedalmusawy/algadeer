/// Phase 3D STEP 1 — هوية غدير الحتمية (محادثة فقط؛ بلا ملف مستخدم/موضوع طبي).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/core/app_config.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PersonalCompanionProfileService profiles;
  late PersonalProfileFoundation foundation;
  const identity = GhadeerIdentity();

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

  group('وحدة GhadeerIdentity', () {
    test('هوية أساسية ودور', () {
      expect(identity.tryAnswer('من انت'), contains('آني الغدير'));
      expect(identity.tryAnswer('منو انت'), contains('آني الغدير'));
      expect(identity.tryAnswer('شنو انت؟'), contains('مساعدك الصحي'));
      expect(identity.tryAnswer('شنو دورك'), contains('بدون ما أستبدل'));
      expect(identity.tryAnswer('عرفني بنفسك'), contains('آني الغدير'));
      expect(identity.tryAnswer('منو الغدير'), contains('آني الغدير'));
    });

    test('الأب الروحي — صيغ متعددة', () {
      for (final q in [
        'من ابوك الروحي',
        'منو أبوك الروحي',
        'من أبيك الروحي',
        'من الأب الروحي',
        'من الأب الروحي للتطبيق',
        'من الأب الروحي للغدير',
        'منو الأب الروحي لتطبيق الغدير',
      ]) {
        final a = identity.tryAnswer(q);
        expect(a, isNotNull, reason: q);
        expect(a, contains(GhadeerIdentity.spiritualFatherName), reason: q);
      }
    });

    test('الداعم', () {
      for (final q in [
        'من الداعم للتطبيق',
        'منو داعم الغدير',
        'من الداعم بتكوين التطبيق',
        'من الداعم للغدير',
      ]) {
        final a = identity.tryAnswer(q);
        expect(a, isNotNull, reason: q);
        expect(a, contains(GhadeerIdentity.supporterName), reason: q);
      }
    });

    test('المساعدون ببناء التطبيق — اسمان', () {
      for (final q in [
        'من المساعد',
        'منو المساعد',
        'من المساعدين',
        'منو المساعدين',
        'منو مساعدك',
        'منو مساعدك ببناء التطبيق',
        'من ساعدك ببناء التطبيق',
        'من ساعد ببناء الغدير',
        'من المساعدين ببناء التطبيق',
        'منو المساعدين ببناء الغدير',
        'من ساعد بتكوين تطبيق الغدير',
      ]) {
        final a = identity.tryAnswer(q);
        expect(a, isNotNull, reason: q);
        expect(a, contains(GhadeerIdentity.buildingAssistantName), reason: q);
        expect(
          a,
          contains(GhadeerIdentity.buildingAssistantFriendName),
          reason: q,
        );
        expect(a, contains('الصديق العزيز مصطفى كامل سعود العبودي'), reason: q);
      }
    });

    test('الراعي الرسمي الحالي — مصدر واحد', () {
      expect(
        GhadeerIdentity.currentOfficialSponsorName,
        AppConfig.ghadeerOfficialSponsor,
      );
      expect(
        AppConfig.ghadeerOfficialSponsor,
        'أبو سعدية للموبايلات',
      );
      for (final q in [
        'من الراعي الرسمي',
        'منو راعي التطبيق',
        'من الراعي الرسمي للغدير',
        'من يرعى تطبيق الغدير',
      ]) {
        final a = identity.tryAnswer(q);
        expect(a, isNotNull, reason: q);
        expect(a, contains('الحالي'), reason: q);
        expect(a, contains('أبو سعدية للموبايلات'), reason: q);
      }
    });

    test('حقائق غير معتمدة → رد آمن بلا اختراع أسماء', () {
      for (final q in [
        'من صنعك؟',
        'من برمجك؟',
        'من طورك؟',
        'من مدير شركة الغدير؟',
        'من مؤسس الشركة؟',
        'من صاحب التطبيق؟',
      ]) {
        final a = identity.tryAnswer(q);
        if (q == 'من مدير شركة الغدير؟' || q == 'من مؤسس الشركة؟') {
          // صيغ غير مطابقة للمحافظة — لا اختراع.
          expect(
            a,
            anyOf(isNull, GhadeerIdentity.answerUnknownIdentity),
            reason: q,
          );
          if (a != null) {
            expect(a, isNot(contains('حيدر')));
            expect(a, isNot(contains('محمد عبد الحسن')));
          }
        } else {
          expect(a, GhadeerIdentity.answerUnknownIdentity, reason: q);
          expect(a, isNot(contains('حيدر')));
          expect(a, isNot(contains('محمد عبد الحسن')));
          expect(a, isNot(contains('ليلى')));
        }
      }
    });
  });

  group('سلبيات — لا اختطاف', () {
    test('جمل عائلية/طبية/أوامر لا تُجاب كهوية', () {
      for (final q in [
        'ساعدني عندي ألم بالركبة',
        'أبوي عنده سعال',
        'أبي عنده حرارة',
        'والدي مريض',
        'شنو اسمي',
        'أريد طبيب أطفال',
        'أريد مختبر',
        'اتصل بالدكتور',
        'نعم',
        'لا',
        'عندي ضيق بالتنفس',
        'ممكن تساعدني',
        'ساعدني ألكه طبيب',
        'أريد مساعدتك',
      ]) {
        expect(identity.tryAnswer(q), isNull, reason: q);
      }
    });

    test('أبوي الطبي يبقى موضوع أب وليس أباً روحياً', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(
        query: 'ابوي عنده سعال من يومين',
        context: ctx,
      );
      expect(plan.message, isNot(contains(GhadeerIdentity.spiritualFatherName)));
      expect(ctx.healthSubject.type, HealthSubjectType.father);
    });

    test('ساعدني عندي ألم لا يُرجع المساعدين البنائيين', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(
        query: 'ساعدني عندي ألم بالركبة',
        context: ctx,
      );
      expect(
        plan.message,
        isNot(contains(GhadeerIdentity.buildingAssistantName)),
      );
      expect(
        plan.message,
        isNot(contains(GhadeerIdentity.buildingAssistantFriendName)),
      );
      expect(plan.kind, isNot(AssistantActionKind.runGeneralSearch));
    });
  });

  group('مخطّط — إجابات حتمية بلا بحث عام', () {
    test('من انت / شنو دورك / الأب / الداعم / المساعد / الراعي', () async {
      final cases = <String, String>{
        'من انت؟': 'آني الغدير',
        'شنو دورك؟': 'بدون ما أستبدل',
        'منو ابوك الروحي؟': GhadeerIdentity.spiritualFatherName,
        'من الداعم للتطبيق؟': GhadeerIdentity.supporterName,
        'من المساعد؟': GhadeerIdentity.buildingAssistantName,
        'من الراعي الرسمي؟': 'أبو سعدية للموبايلات',
      };
      for (final e in cases.entries) {
        final ctx = ConversationContext();
        final beforeSubject = ctx.healthSubject;
        final plan = await planner().plan(query: e.key, context: ctx);
        expect(plan.kind, AssistantActionKind.showMessage, reason: e.key);
        expect(plan.message, contains(e.value), reason: e.key);
        if (e.key == 'من المساعد؟') {
          expect(
            plan.message,
            contains(GhadeerIdentity.buildingAssistantFriendName),
          );
          expect(
            plan.message,
            contains('الصديق العزيز مصطفى كامل سعود العبودي'),
          );
        }
        expect(plan.kind, isNot(AssistantActionKind.runGeneralSearch));
        expect(ctx.healthSubject.type, beforeSubject.type, reason: e.key);
        expect(ctx.healthSubject.ageYears, beforeSubject.ageYears);
      }
    });

    test('لا يكتب حقائق غدير في PersonalCompanionProfile', () async {
      expect(await foundation.load(), isNull);
      final ctx = ConversationContext();
      await planner().plan(query: 'منو ابوك الروحي؟', context: ctx);
      await planner().plan(query: 'من الداعم للتطبيق؟', context: ctx);
      await planner().plan(query: 'من المساعد؟', context: ctx);
      await planner().plan(query: 'من الراعي الرسمي؟', context: ctx);
      expect(await foundation.load(), isNull);
      expect(await profiles.loadProfile(), isNull);
    });
  });

  group('جلسة سريرية — تحويلة هوية بلا تدمير', () {
    test('MSK معلّق + أب روحي ثم جواب سريري يستمر', () async {
      final ctx = ConversationContext();
      final p = planner();

      await p.plan(query: 'اني عندي ألم بالظهر', context: ctx);
      expect(ctx.mskSession.active, isTrue);
      final qKey = ctx.mskSession.lastQuestionKey;
      expect(qKey, isNotNull);
      final gen = ctx.conversationGeneration;
      final subjectType = ctx.healthSubject.type;

      final idPlan = await p.plan(query: 'منو ابوك الروحي؟', context: ctx);
      expect(idPlan.kind, AssistantActionKind.showMessage);
      expect(idPlan.message, contains(GhadeerIdentity.spiritualFatherName));
      expect(ctx.mskSession.active, isTrue);
      expect(ctx.mskSession.lastQuestionKey, qKey);
      expect(ctx.conversationGeneration, gen);
      expect(ctx.healthSubject.type, subjectType);

      final cont = await p.plan(query: 'اي خفيف', context: ctx);
      expect(ctx.mskSession.active, isTrue);
      expect(
        cont.message,
        isNot(contains(GhadeerIdentity.spiritualFatherName)),
      );
      // لم تُمسَح الجلسة كـ foreignTurn بسبب الهوية.
      expect(ctx.conversationGeneration, gen);
    });

    test('راعي التطبيق أيضاً لا يمسح MSK المعلّق', () async {
      final ctx = ConversationContext();
      final p = planner();
      await p.plan(query: 'اني عندي ألم بالظهر', context: ctx);
      final qKey = ctx.mskSession.lastQuestionKey;
      expect(qKey, isNotNull);

      final idPlan = await p.plan(query: 'منو راعي التطبيق؟', context: ctx);
      expect(idPlan.message, contains('أبو سعدية للموبايلات'));
      expect(ctx.mskSession.active, isTrue);
      expect(ctx.mskSession.lastQuestionKey, qKey);
    });

    test('المساعدون أثناء MSK لا يمسحون الجلسة', () async {
      final ctx = ConversationContext();
      final p = planner();
      await p.plan(query: 'اني عندي ألم بالظهر', context: ctx);
      final qKey = ctx.mskSession.lastQuestionKey;
      final gen = ctx.conversationGeneration;
      expect(qKey, isNotNull);

      final idPlan = await p.plan(
        query: 'منو المساعدين ببناء الغدير؟',
        context: ctx,
      );
      expect(idPlan.kind, AssistantActionKind.showMessage);
      expect(idPlan.message, contains(GhadeerIdentity.buildingAssistantName));
      expect(
        idPlan.message,
        contains('الصديق العزيز مصطفى كامل سعود العبودي'),
      );
      expect(ctx.mskSession.active, isTrue);
      expect(ctx.mskSession.lastQuestionKey, qKey);
      expect(ctx.conversationGeneration, gen);
      expect(ctx.healthSubject.type, HealthSubjectType.self);
    });
  });
}
