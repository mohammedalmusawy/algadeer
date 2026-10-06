import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final resolver = RuleBasedIntentResolver();

  group('ملفي الصحي — نية العقل المحلي', () {
    test('يفتح ملفي الصحي', () {
      final r = resolver.resolve('افتح ملفي الصحي');
      expect(r.intent, AssistantIntent.openPatientHealth);
      expect(r.entities.actionHint, 'health_file');
    });

    test('بطاقة المتابعة عبر البوابة', () {
      final r = resolver.resolve('عرض بطاقة المتابعة');
      expect(r.intent, AssistantIntent.openPatientHealth);
      expect(r.entities.actionHint, 'follow_up_card');
    });

    test('المخطّط يُرجع openPatientHealth بلا مشاركة تلقائية', () async {
      final planner = SmartBrainPlanner(clinicalEnabled: false);
      final plan = await planner.plan(
        query: 'ملفي الصحي',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.openPatientHealth);
      expect(plan.canExecute, isTrue);
      expect(plan.message, contains('تسجيل الدخول'));
      expect(plan.message.toLowerCase(), isNot(contains('http')));
    });

    test('رسالة بطاقة المتابعة تذكّر بالاختيار الصريح', () async {
      final planner = SmartBrainPlanner(clinicalEnabled: false);
      final plan = await planner.plan(
        query: 'بطاقة المتابعة',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.openPatientHealth);
      expect(plan.message, contains('اختيارك الصريح'));
    });
  });
}
