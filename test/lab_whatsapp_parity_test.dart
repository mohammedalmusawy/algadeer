import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/doctor_name_matcher.dart';
import 'package:ghadeer_clinic/search/laboratory_name_matcher.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/entity_target_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

SmartSearchResult _lab(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: 'مختبر',
      labId: id,
      score: 90,
      phone: '07700000001',
      whatsapp: '07700000001',
      labName: title,
    );

SmartSearchResult _doc(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: 'أطفال',
      doctorId: id,
      score: 90,
      specialty: 'أطفال',
      phone: '07701111111',
      whatsapp: '07701111111',
    );

/// واتساب مختبر — تكافؤ + قطع السياق العالق + أخطاء إملائية.
void main() {
  group('واتساب مختبر — تكافؤ مع الأطباء', () {
    final resolver = RuleBasedIntentResolver();

    test('وتساب / whatsapp / مارسل → messageLab باسم نظيف لأي مختبر', () {
      for (final q in const [
        'أرسل رسالة وتساب لمختبر سحب المنزل',
        'ارسل رسالة واتساب لمختبر سحب المنزل',
        'ارسل رسالة whatsapp لمختبر سحب المنزل',
        'whatsapp مختبر سحب المنزل',
        'ارسل رسالة مارسل واتساب لمختبر سحب المنزل',
        'رسالة واتساب لمختبر الغدير',
        'ارسل واتساب مختبر الحياة',
      ]) {
        final c = VoiceContactCommand.tryParse(q);
        final i = resolver.resolve(q);
        expect(c?.kind, VoiceContactKind.whatsapp, reason: q);
        expect(i.intent, AssistantIntent.messageLab, reason: q);
        expect(i.entities.laboratory, isNotNull, reason: q);
        expect(i.entities.laboratory, isNot(contains('رسال')), reason: q);
        expect(i.entities.laboratory, isNot(contains('واتس')), reason: q);
        expect(i.entities.laboratory, isNot(contains('وتساب')), reason: q);
        expect(i.entities.laboratory, isNot(contains('مختبر')), reason: q);
        expect(i.requiresContext, isFalse, reason: q);
      }
    });

    test('لمختبر X يزيل حرف الجر ولقب المختبر من الهدف', () {
      final c = VoiceContactCommand.tryParse(
        'أرسل رسالة واتساب لمختبر سحب المنزل',
      );
      expect(c?.targetQuery, 'سحب المنزل');

      final i = resolver.resolve('أرسل رسالة واتساب لمختبر سحب المنزل');
      expect(i.entities.laboratory, 'سحب المنزل');
    });

    test('دزله واتساب للمختبر → سياقي بلا اسم', () {
      final i = resolver.resolve('دزله واتساب للمختبر');
      expect(i.intent, AssistantIntent.messageLab);
      expect(i.requiresContext, isTrue);
      expect(i.entities.laboratory, isNull);
    });

    test('اتصل بمختبر → callLab باسم نظيف', () {
      final i = resolver.resolve('اتصل بمختبر سحب المنزل');
      expect(i.intent, AssistantIntent.callLab);
      expect(i.entities.laboratory, 'سحب المنزل');
      expect(i.requiresContext, isFalse);
    });
  });

  group('قطع سياق المختبر العالق', () {
    final resolver = RuleBasedIntentResolver();
    final home = _lab('home', 'مختبر سحب المنزل');
    final naji = _doc('naji', 'ناجي عبد الله الركابي');

    test('اسم طبيب صريح لا يفضّل المختبر النشط', () {
      final ctx = ConversationContext();
      ctx.selectLaboratory(home);
      final intent = resolver.resolve('أرسل رسالة واتساب لدكتور ناجي');
      expect(intent.intent, AssistantIntent.messageDoctor);
      expect(intent.entities.doctorName, 'ناجي');
      expect(
        EntityTargetResolver.prefersLaboratory(
          intent: intent,
          context: ctx,
        ),
        isFalse,
      );
    });

    test('بعد سحب المنزلي → واتساب دكتور ناجي يفتح الطبيب لا المختبر', () async {
      final ctx = ConversationContext();
      ctx.selectLaboratory(home);
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        labLookup: (_) async => [home],
        doctorLookup: (q) async {
          final n = ArabicTextUtils.normalize(q);
          if (n.contains('ناجي') || n.contains('ناحي')) return [naji];
          return const [];
        },
      );

      final plan = await planner.plan(
        query: 'أرسل رسالة واتساب لدكتور ناجي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'naji');
      expect(plan.target?.labId, isNull);
      expect(ctx.activeEntityType, ConversationEntityType.doctor);
    });

    test('دزله واتساب بلا اسم يبقى على المختبر المحدد', () async {
      final ctx = ConversationContext();
      ctx.selectLaboratory(home);
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        labLookup: (_) async => [home],
        doctorLookup: (_) async => const [],
      );
      final plan = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.labId, 'home');
    });

    test('تبديل مختبر صريح: من سحب المنزل إلى الحياة', () async {
      final ctx = ConversationContext();
      ctx.selectLaboratory(home);
      final hayat = _lab('hayat', 'مختبر الحياة');
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        labLookup: (q) async {
          final n = ArabicTextUtils.normalize(q);
          if (n.contains('حيا')) return [hayat];
          if (n.contains('سحب')) return [home];
          return [home, hayat];
        },
        doctorLookup: (_) async => const [],
      );
      final plan = await planner.plan(
        query: 'واتساب مختبر الحياة',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.labId, 'hayat');
    });
  });

  group('مطابقة مختبر عامة للمستقبل', () {
    const matcher = LaboratoryNameMatcher();

    test('اسم جديد في القاعدة يُطابق دون قواعد ثابتة', () {
      final batch = matcher.matchLabs(
        query: 'سحب المنزل',
        labs: const [
          (id: 'home', name: 'مختبر سحب المنزل'),
          (id: 'hayat', name: 'مختبر الحياة'),
        ],
      );
      expect(batch.best?.labId, 'home');
      expect(batch.best!.score, greaterThanOrEqualTo(80));
    });

    test('خطأ إملائي صغير على توكن واحد', () {
      final typo = matcher.matchLabs(
        query: ArabicTextUtils.normalize('الحياه'),
        labs: const [
          (id: 'hayat', name: 'مختبر الحياة'),
        ],
      );
      expect(typo.best?.labId, 'hayat');
      expect(typo.best!.score, greaterThanOrEqualTo(80));
    });

    test('السحب المنزلي ≈ سحب المنزل', () {
      final batch = matcher.matchLabs(
        query: ArabicTextUtils.normalize('السحب المنزلي'),
        labs: const [
          (id: 'home', name: 'مختبر سحب المنزل'),
        ],
      );
      expect(batch.best?.labId, 'home');
      expect(batch.best!.score, greaterThanOrEqualTo(70));
    });

    test('prepareLabNameQuery يزيل ضجيج واتساب', () {
      expect(
        ArabicTextUtils.prepareLabNameQuery('وتساب لمختبر سحب المنزل'),
        'سحب المنزل',
      );
    });
  });

  group('أخطاء إملائية بسيطة للطبيب', () {
    test('ناحي ≈ ناجي', () {
      final typo = const DoctorNameMatcher().score(
        doctorName: 'ناجي عبد الله الركابي',
        query: ArabicTextUtils.normalize('ناحي'),
        doctorId: 'naji',
      );
      expect(typo.score, greaterThanOrEqualTo(80));
    });
  });
}
