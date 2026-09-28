import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/radiology_name_matcher.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

SmartSearchResult _rad(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.radiology,
      title: title,
      subtitle: 'مركز أشعة',
      radiologyId: id,
      score: 90,
      phone: '07702222222',
      whatsapp: '07702222222',
    );

SmartSearchResult _lab(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: 'مختبر',
      labId: id,
      score: 90,
      phone: '07700000001',
      whatsapp: '07700000001',
    );

void main() {
  group('أشعة — واتساب/اتصال عام من القاعدة', () {
    final resolver = RuleBasedIntentResolver();

    test('وتساب أشعة الغدير → messageRadiology باسم نظيف', () {
      for (final q in const [
        'أرسل رسالة واتساب لأشعة الغدير',
        'أرسل رسالة وتساب لأشعة الغدير',
        'whatsapp أشعة الغدير',
        'واتساب اشعة الغدير',
      ]) {
        final c = VoiceContactCommand.tryParse(q);
        final i = resolver.resolve(q);
        expect(c?.kind, VoiceContactKind.whatsapp, reason: q);
        expect(i.intent, AssistantIntent.messageRadiology, reason: q);
        expect(i.entities.radiology, 'الغدير', reason: q);
        expect(i.requiresContext, isFalse, reason: q);
      }
    });

    test('اتصل بأشعة الغدير → callRadiology', () {
      final i = resolver.resolve('اتصل بأشعة الغدير');
      expect(i.intent, AssistantIntent.callRadiology);
      expect(i.entities.radiology, 'الغدير');
    });

    test('بعد مختبر عالق → واتساب أشعة الغدير يفتح الأشعة', () async {
      final ctx = ConversationContext();
      ctx.selectLaboratory(_lab('home', 'مختبر سحب المنزل'));
      final gadeer = _rad('rad1', 'أشعة الغدير');
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        labLookup: (_) async => [_lab('home', 'مختبر سحب المنزل')],
        radiologyLookup: (q) async {
          final n = ArabicTextUtils.normalize(q);
          if (n.contains('غدير') || n.contains('اشعه') || n.contains('اشعة')) {
            return [gadeer];
          }
          return const [];
        },
        doctorLookup: (_) async => const [],
      );
      final plan = await planner.plan(
        query: 'أرسل رسالة واتساب لأشعة الغدير',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.radiologyId, 'rad1');
      expect(plan.target?.labId, isNull);
      expect(ctx.activeEntityType, ConversationEntityType.radiology);
    });
  });

  group('مطابقة أشعة للمستقبل', () {
    const matcher = RadiologyNameMatcher();

    test('اسم جديد يُطابق دون قواعد ثابتة', () {
      final batch = matcher.matchCenters(
        query: 'الغدير',
        centers: const [
          (id: 'g', name: 'أشعة الغدير'),
          (id: 'n', name: 'أشعة النور'),
        ],
      );
      expect(batch.best?.centerId, 'g');
    });

    test('خطأ إملائي بسيط', () {
      final batch = matcher.matchCenters(
        query: ArabicTextUtils.normalize('الغدبر'),
        centers: const [(id: 'g', name: 'أشعة الغدير')],
      );
      expect(batch.best?.centerId, 'g');
    });
  });
}
