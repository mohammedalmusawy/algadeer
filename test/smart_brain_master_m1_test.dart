import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_resolver.dart';
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
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('M1 — pharmacy list candidates grounded', () {
    test('ابحثلي عن صيدلية → candidates من المنصة وليس اختراع', () async {
      final a = _pharm('rehab', 'صيدلية رحاب');
      final b = _pharm('shatra', 'صيدلية الشطرة');
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        pharmacyLookup: (_) async => [a, b],
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
      );
      final plan = await planner.plan(
        query: 'ابحثلي عن صيدلية',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.runGeneralSearch);
      expect(plan.candidates.length, 2);
      expect(plan.candidates.every((c) => c.pharmacyId != null), isTrue);
      expect(plan.message, contains('صيدليات'));
    });
  });

  group('M1 — interrupt clears pending confirmation', () {
    test('نية صيدلية واضحة تلغي توضيح طبيب معلّق', () async {
      final ctx = ConversationContext();
      final doc = SmartSearchResult(
        type: SmartSearchResultType.doctor,
        title: 'د. علي',
        subtitle: 'أطفال',
        doctorId: 'ali',
        specialty: 'أطفال',
      );
      ctx.setPendingClarification(
        PendingClarification(
          entityType: ClarificationEntityType.doctor,
          reason: ClarificationReason.multipleMatches,
          candidates: [
            ClarificationCandidate(
              id: 'ali',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: 'د. علي',
              payload: doc,
            ),
            ClarificationCandidate(
              id: 'ali2',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: 'د. علي ناصر',
              payload: doc,
            ),
          ],
          originalIntent: AssistantIntent.callDoctor,
          originalQuery: 'اتصل بعلي',
          pendingAction: AssistantIntent.callDoctor,
        ),
      );
      expect(ctx.hasPendingClarification, isTrue);

      final intent = RuleBasedIntentResolver().resolve('ابحثلي عن صيدلية');
      expect(
        ClarificationResolver.isClearNewSearchIntent(intent, 'ابحثلي عن صيدلية'),
        isTrue,
      );

      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        pharmacyLookup: (_) async => [_pharm('rehab', 'صيدلية رحاب')],
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
      );
      final plan = await planner.plan(
        query: 'ابحثلي عن صيدلية',
        context: ctx,
      );
      expect(ctx.hasPendingClarification, isFalse);
      expect(plan.intentResult.intent, AssistantIntent.findPharmacy);
    });
  });
}
