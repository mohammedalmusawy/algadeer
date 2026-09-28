import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/pharmacy_name_matcher.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

SmartSearchResult _pharm(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.pharmacy,
      title: title,
      subtitle: 'صيدلية',
      pharmacyId: id,
      score: 90,
      phone: '07801234567',
      whatsapp: '07801234567',
      clinicLocation: 'الشطرة',
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
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('صيدليات — واتساب/اتصال عام من الكتالوج', () {
    final resolver = RuleBasedIntentResolver();

    test('وتساب صيدلية رحاب → messagePharmacy باسم نظيف', () {
      for (final q in const [
        'أرسل رسالة واتساب لصيدلية رحاب',
        'أرسل رسالة وتساب لصيدلية رحاب',
        'whatsapp صيدلية رحاب',
        'واتساب صيدليه رحاب',
      ]) {
        final c = VoiceContactCommand.tryParse(q);
        final i = resolver.resolve(q);
        expect(c?.kind, VoiceContactKind.whatsapp, reason: q);
        expect(i.intent, AssistantIntent.messagePharmacy, reason: q);
        expect(i.entities.pharmacy, 'رحاب', reason: q);
        expect(i.requiresContext, isFalse, reason: q);
      }
    });

    test('اتصل بصيدلية رحاب → callPharmacy', () {
      final i = resolver.resolve('اتصل بصيدلية رحاب');
      expect(i.intent, AssistantIntent.callPharmacy);
      expect(i.entities.pharmacy, 'رحاب');
    });

    test('ابحثلي عن صيدلية → findPharmacy', () {
      final i = resolver.resolve('ابحثلي عن صيدلية');
      expect(i.intent, AssistantIntent.findPharmacy);
    });

    test('بعد مختبر عالق → واتساب صيدلية رحاب يفتح الصيدلية', () async {
      final ctx = ConversationContext();
      ctx.selectLaboratory(_lab('home', 'مختبر سحب المنزل'));
      final rehab = _pharm('rehab', 'صيدلية رحاب');
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        labLookup: (_) async => [_lab('home', 'مختبر سحب المنزل')],
        pharmacyLookup: (q) async {
          final n = ArabicTextUtils.normalize(q);
          if (n.contains('رحاب') || n.contains('صيدل')) {
            return [rehab];
          }
          return const [];
        },
        doctorLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
      );
      final plan = await planner.plan(
        query: 'أرسل رسالة واتساب لصيدلية رحاب',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.pharmacyId, 'rehab');
      expect(plan.target?.labId, isNull);
      expect(ctx.activeEntityType, ConversationEntityType.pharmacy);
    });
  });

  group('مطابقة صيدلية للمستقبل', () {
    const matcher = PharmacyNameMatcher();

    test('اسم جديد يُطابق دون قواعد ثابتة', () {
      final batch = matcher.matchPharmacies(
        query: 'رحاب',
        pharmacies: const [
          (id: 'rehab', name: 'صيدلية رحاب'),
          (id: 'shatra', name: 'صيدلية الشطرة'),
        ],
      );
      expect(batch.best?.pharmacyId, 'rehab');
    });

    test('preparePharmacyNameQuery يزيل لقب الصيدلية', () {
      expect(
        ArabicTextUtils.preparePharmacyNameQuery('صيدلية رحاب'),
        'رحاب',
      );
    });
  });
}
