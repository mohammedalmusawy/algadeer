/// كتالوج أوامر صوتية — مسار نص=صوت بعد STT (بدون تعديل محرك المايك).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final resolver = RuleBasedIntentResolver();

  SmartSearchResult doc(String id, String title) => SmartSearchResult(
        type: SmartSearchResultType.doctor,
        title: title,
        subtitle: 'طب الأطفال',
        doctorId: id,
        specialty: 'طب الأطفال',
        phone: '0700$id',
        whatsapp: '0700$id',
        clinicLocation: 'الكرادة',
        workingHours:
            'السبت: مساءً، الأحد: مساءً، الاثنين: مساءً، الثلاثاء: مساءً، '
            'الأربعاء: مساءً، الخميس: مساءً، الجمعة: عطلة',
        bookingStatus: 'available',
        gender: 'male',
        score: 90,
      );

  SmartBrainPlanner planner() => SmartBrainPlanner(
        nluClient: NluClient.disabled,
        doctorLookup: (q) async {
          if (q.contains('ميعاد') || q.contains('علي')) {
            return [doc('ali', 'د. علي ناصر')];
          }
          return [doc('a', 'A'), doc('b', 'B'), doc('c', 'C')];
        },
        labLookup: (_) async => const [],
        analysisLookup: (_) async => const [],
        packagesLookup: (_) async => const [],
        packagesForAnalysisLookup: (_) async => const [],
        activePackagesLookup: ({labId, nameQuery}) async => const [],
        discountedPackagesLookup: ({labId}) async => const [],
      );

  group('3 — عرض المزيد ≠ عروض', () {
    test('عرض المزيد → showMore وليس findOffer', () {
      expect(resolver.resolve('عرض المزيد').intent, AssistantIntent.showMore);
      expect(resolver.resolve('اعرض المزيد').intent, AssistantIntent.showMore);
      expect(resolver.resolve('المزيد').intent, AssistantIntent.showMore);
      expect(resolver.resolve('عروض').intent, AssistantIntent.findOffer);
      expect(resolver.resolve('اكو عروض').intent, AssistantIntent.findOffer);
    });

    test('عرض المزيد مع نتائج جلسة لا يفتح عروضاً', () async {
      final ctx = ConversationContext();
      ctx.rememberResults(
        [doc('a', 'A'), doc('b', 'B')],
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await planner().plan(query: 'عرض المزيد', context: ctx);
      expect(plan.intentResult.intent, AssistantIntent.showMore);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, contains('النتائج الحالية'));
      expect(plan.candidates.length, 2);
    });

    test('عرض المزيد بلا نتائج يوضح', () async {
      final plan =
          await planner().plan(query: 'عرض المزيد', context: ConversationContext());
      expect(plan.message, contains('ما عندي نتائج إضافية'));
    });
  });

  group('4 — توفّر / متوفر اليوم', () {
    test('متوفر اليوم سياقي على الطبيب المحدد', () async {
      final ctx = ConversationContext();
      ctx.rememberResults(
        [doc('a', 'A'), doc('b', 'B')],
        intent: AssistantIntent.specialtySearch,
      );
      await planner().plan(query: 'الثاني', context: ctx);
      expect(ctx.selectedDoctor?.doctorId, 'b');

      final plan = await planner().plan(query: 'متوفر اليوم', context: ctx);
      expect(plan.intentResult.intent, AssistantIntent.doctorAvailability);
      expect(plan.target?.doctorId, 'b');
      expect(plan.message, isNotEmpty);
      expect(plan.kind, isNot(AssistantActionKind.runDoctorSearch));
    });

    test('موجود اليوم؟ سياقي أيضاً', () async {
      final ctx = ConversationContext();
      ctx.rememberResults([doc('a', 'A')], intent: AssistantIntent.doctorSearch);
      final plan = await planner().plan(query: 'موجود اليوم؟', context: ctx);
      expect(plan.intentResult.intent, AssistantIntent.doctorAvailability);
      expect(plan.target?.doctorId, 'a');
    });
  });

  group('5 — مسار أوامر أساسية (نص=صوت)', () {
    test('اختصاص / اتصال / واتساب / ترتيب / وقف / كرر', () async {
      final ctx = ConversationContext();
      final p = planner();

      final specialty = await p.plan(query: 'اريد طبيب اطفال', context: ctx);
      expect(specialty.kind, AssistantActionKind.runSpecialtySearch);

      ctx.rememberResults(
        [doc('a', 'A'), doc('b', 'B'), doc('c', 'C')],
        intent: AssistantIntent.specialtySearch,
      );
      final pick = await p.plan(query: 'الثاني', context: ctx);
      expect(pick.target?.doctorId, 'b');

      final call = await p.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'b');

      final wa = await p.plan(query: 'اريد واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);

      final stop = await p.plan(query: 'وقف', context: ctx);
      expect(stop.kind, AssistantActionKind.stopSpeaking);

      ctx.setAssistantResponse('رد تجريبي للإعادة.');
      final repeat = await p.plan(query: 'كرر', context: ctx);
      expect(repeat.kind, AssistantActionKind.repeatResponse);
      expect(repeat.message, 'رد تجريبي للإعادة.');
    });
  });

  group('6 — مشاركة / مفضلة (توضيح آمن)', () {
    test('بلا هدف — توضيح بدون بحث', () async {
      final plan =
          await planner().plan(query: 'شاركه', context: ConversationContext());
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.kind, isNot(AssistantActionKind.runDoctorSearch));
      expect(plan.message, contains('البطاقة'));
    });

    test('مع طبيب محدد — يوضح البطاقة ويستهدف نفس الطبيب', () async {
      final ctx = ConversationContext();
      ctx.rememberResults([doc('b', 'B')], intent: AssistantIntent.doctorSearch);
      final plan = await planner().plan(query: 'ضيفه للمفضلة', context: ctx);
      expect(plan.target?.doctorId, 'b');
      expect(plan.message, contains('B'));
      expect(plan.message, contains('التطبيق'));
      expect(plan.canExecute, isFalse);
    });
  });
}
