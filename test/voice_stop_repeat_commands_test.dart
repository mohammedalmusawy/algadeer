/// أوامر صوت قصيرة: إيقاف النطق / إعادة آخر رد.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final resolver = RuleBasedIntentResolver();

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

  group('IntentResolver — وقف / كرر', () {
    test('وقف → stopSpeaking', () {
      expect(resolver.resolve('وقف').intent, AssistantIntent.stopSpeaking);
      expect(resolver.resolve('وقف الصوت').intent, AssistantIntent.stopSpeaking);
      expect(resolver.resolve('اسكت').intent, AssistantIntent.stopSpeaking);
      expect(resolver.resolve('stop').intent, AssistantIntent.stopSpeaking);
    });

    test('وقف متابعة لا تُسرق كإيقاف نطق', () {
      expect(
        resolver.resolve('وقف متابعة').intent,
        isNot(AssistantIntent.stopSpeaking),
      );
      expect(
        resolver.resolve('وقف الهدف').intent,
        isNot(AssistantIntent.stopSpeaking),
      );
    });

    test('كرر → repeatResponse', () {
      expect(resolver.resolve('كرر').intent, AssistantIntent.repeatResponse);
      expect(resolver.resolve('كرر الرد').intent, AssistantIntent.repeatResponse);
      expect(resolver.resolve('عيد الكلام').intent, AssistantIntent.repeatResponse);
    });
  });

  group('Planner — وقف / كرر', () {
    test('وقف لا يفتح بحث طبيب', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(query: 'وقف', context: ctx);
      expect(plan.kind, AssistantActionKind.stopSpeaking);
      expect(plan.textFirstOnly, isTrue);
      expect(plan.kind, isNot(AssistantActionKind.runDoctorSearch));
      expect(plan.kind, isNot(AssistantActionKind.runGeneralSearch));
    });

    test('كرر بلا رد سابق يوضح', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(query: 'كرر', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, contains('ما عندي رد'));
      expect(plan.canExecute, isFalse);
    });

    test('كرر يعيد آخر رد محفوظ', () async {
      final ctx = ConversationContext();
      ctx.setAssistantResponse('وجدت ثلاثة أطباء أطفال.');
      final plan = await planner().plan(query: 'كرر', context: ctx);
      expect(plan.kind, AssistantActionKind.repeatResponse);
      expect(plan.message, 'وجدت ثلاثة أطباء أطفال.');
      expect(plan.canExecute, isTrue);
      // لا يُستبدل الرد المحفوظ برد جديد مختلف
      expect(ctx.lastAssistantResponse, 'وجدت ثلاثة أطباء أطفال.');
    });

    test('اتصل ما زال يعمل بعد أوامر الصوت القصيرة', () async {
      final ctx = ConversationContext();
      final plan = await planner().plan(query: 'اتصل بيه', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.stopSpeaking));
      expect(plan.kind, isNot(AssistantActionKind.repeatResponse));
    });
  });
}
