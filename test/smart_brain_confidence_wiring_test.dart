import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/confidence_policy.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

SmartSearchResult _doc({
  required String id,
  required String title,
  String specialty = 'طب الأطفال',
  int score = 96,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty,
    doctorId: id,
    score: score,
    specialty: specialty,
    phone: '07701111111',
    whatsapp: '07701111111',
    clinicLocation: 'الكرادة',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final saeedi = _doc(
    id: 'saeedi',
    title: 'الدكتور علي ناصر السعيدي',
  );

  SmartBrainPlanner planner() => SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => [saeedi],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
      );

  group('M2 — Confidence Policy في حل الاسم', () {
    test('HIGH: اسم كامل + اتصال → تنفيذ مباشر بلا تأكيد', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(
        query: 'اتصل بالدكتور علي ناصر السعيدي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.canExecute, isTrue);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(plan.message.contains('تقصد'), isFalse);
    });

    test('HIGH: بحث اسم كامل فريد → تنفيذ بلا «تقصد»', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(
        query: 'الدكتور علي ناصر السعيدي',
        context: ctx,
      );
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(plan.message.contains('تقصد'), isFalse);
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.runDoctorSearch,
          AssistantActionKind.selectEntity,
          AssistantActionKind.openProfile,
        ),
      );
      expect(plan.canExecute || plan.target != null, isTrue);
    });

    test('MEDIUM: اتصال باسم جزئي وحيد → تأكيد «تقصد…؟»', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(
        query: 'اتصل بعلي',
        context: ctx,
      );
      expect(plan.message, contains('تقصد'));
      expect(plan.canExecute, isFalse);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(ctx.hasPendingDoctorSuggestion, isTrue);
      expect(ctx.pendingDoctorSuggestion?.doctorId, 'saeedi');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
    });

    test('MEDIUM: بحث «علي» وحيد → تأكيد لا اختيار أعمى', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(query: 'علي', context: ctx);
      expect(plan.message, contains('تقصد'));
      expect(ctx.hasPendingDoctorSuggestion, isTrue);
      expect(plan.canExecute, isFalse);
    });

    test('نعم على اقتراح متوسط → اختيار فقط بلا اتصال', () async {
      final ctx = ConversationContext();
      ctx.setPendingDoctorSuggestion(
        PendingDoctorSuggestion(
          doctorId: 'saeedi',
          doctorName: saeedi.title,
        ),
      );
      final plan = await planner().plan(query: 'اي', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.doctorId, 'saeedi');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.kind, isNot(AssistantActionKind.prepareWhatsApp));
    });

    test('forNameResolution: تطابق قوي + نية متوسطة → HIGH', () {
      expect(
        SmartBrainConfidencePolicy.forNameResolution(
          intentScore: 75,
          matchScore: 96,
        ),
        SmartBrainConfidenceBand.high,
      );
      expect(
        SmartBrainConfidencePolicy.forNameResolution(
          intentScore: 75,
          matchScore: 85,
        ),
        SmartBrainConfidenceBand.medium,
      );
      expect(
        SmartBrainConfidencePolicy.forNameResolution(
          intentScore: 40,
          matchScore: 100,
        ),
        SmartBrainConfidenceBand.low,
      );
    });

    test('LOW combine → shouldClarify', () {
      expect(
        SmartBrainConfidencePolicy.combine(intentScore: 90, matchScore: 50),
        SmartBrainConfidenceBand.low,
      );
      expect(
        SmartBrainConfidencePolicy.shouldClarify(
          SmartBrainConfidenceBand.low,
        ),
        isTrue,
      );
    });
  });
}
