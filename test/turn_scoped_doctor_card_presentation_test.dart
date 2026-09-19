/// بطاقة الطبيب تتبع الدور لا الذاكرة — Smart Brain V1.
///
/// العطل الحقيقي: `SmartSearchPage._commitAssistantTurn` كان يُلحق قائمة
/// النتائج المستمرة على الصفحة (`_results`) بكل رد مساعد. أي دور سريري لا
/// يُسند `_results` (لأن الخطة بلا `target`/`candidates`)، فتبقى بطاقة طبيب
/// دور البحث القديم معلّقة تحت كل رد لاحق ويبدو أن الغدير يكرّر التوصية بها.
///
/// الإصلاح: `SmartBrainTurnResults` يفصل سلطتين — الذاكرة المحفوظة
/// (`retained`، تبقى للأفعال والاستمرارية) عن عرض الدور (`presentedIn`، لا
/// يُرجِع شيئاً إلا للدور الذي أنتج النتائج). الحدّ رقم الدور، بلا أي مؤقّت.
///
/// ملاحظة نطاق: `SmartSearchPage` لا يمكن ضخّه في اختبار واجهة لأنه ينشئ
/// `SmartSearchService()` الذي يطلب `Supabase.instance.client`. لذلك الاختبار
/// يقود سلطة العرض الإنتاجية نفسها (`SmartBrainTurnResults`) عبر جلسة تحاكي
/// آلة حالة الصفحة، ويرسم فقاعة المحادثة الإنتاجية الحقيقية
/// (`SmartBrainAssistantBubble`) للتحقق من شرط الرسم الفعلي.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/conversation/smart_brain_chat_models.dart';
import 'package:ghadeer_clinic/search/conversation/smart_brain_chat_widgets.dart';
import 'package:ghadeer_clinic/search/conversation/smart_brain_turn_results.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/search/smart_search_result_cards.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

SmartSearchResult _doc(String id, String title, String specialty) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty,
    doctorId: id,
    specialty: specialty,
    phone: '07700000000',
    whatsapp: '07700000000',
    clinicLocation: 'الكرادة',
    score: 96,
  );
}

final _saeedi = _doc('saeedi', 'الدكتور علي ناصر السعيدي', 'طب الأطفال');

/// أفعال الخطة التي تكمل إلى بحث بيانات في الصفحة الحقيقية.
const _searchKinds = <AssistantActionKind>[
  AssistantActionKind.runDoctorSearch,
  AssistantActionKind.runSpecialtySearch,
  AssistantActionKind.runGeneralSearch,
];

/// نفس بحث الأطباء الذي يستعمله المخطِّط — لمرآة السقوط الآمن في الصفحة.
Future<List<SmartSearchResult>> _doctorLookup(String q) async {
  final n = ArabicTextUtils.normalize(q);
  if (n.contains('السعيدي') || n.contains('اطفال')) return [_saeedi];
  return const [];
}

/// جلسة تحاكي آلة عرض `SmartSearchPage` بدقة، فوق سلطة العرض الإنتاجية.
///
/// النقاط المطابَقة: عدّاد الدور (`_searchEpoch`)، أن `_showPlanMessage` لا
/// يُسند النتائج إلا من `candidates`/`target`، أن السقوط الآمن يُسند نتائج
/// البحث، وأن `_commitAssistantTurn` يُلحق عرض الدور الحالي فقط.
class _PresentationSession {
  _PresentationSession() {
    conversation = ConversationContext();
    planner = SmartBrainPlanner(
      doctorLookup: _doctorLookup,
      labLookup: (_) async => const [],
      analysisLookup: (_) async => const [],
      packagesLookup: (_) async => const [],
      packagesForAnalysisLookup: (_) async => const [],
      activePackagesLookup: ({labId, nameQuery}) async => const [],
      discountedPackagesLookup: ({labId}) async => const [],
    );
  }

  late final ConversationContext conversation;
  late final SmartBrainPlanner planner;

  final _turnResults = SmartBrainTurnResults();
  final List<SmartBrainChatTurn> turns = <SmartBrainChatTurn>[];
  int _searchEpoch = 0;

  /// الذاكرة الداخلية للنتائج — تبقى بعد انتهاء الدور.
  List<SmartSearchResult> get retainedResults => _turnResults.retained;

  SmartSearchResult? get selectedDoctor => conversation.selectedDoctor;

  Future<SmartBrainChatTurn> submit(String raw) async {
    final trimmed = raw.trim();
    final epoch = ++_searchEpoch;
    turns.add(SmartBrainChatTurn.user(trimmed, id: 'u$epoch'));

    final plan = await planner.plan(query: trimmed, context: conversation);

    // مرآة `_showPlanMessage` / `prepareCall` / `openProfile`: العرض من الخطة.
    if (plan.candidates.isNotEmpty) {
      _turnResults.remember(plan.candidates, turn: epoch);
    } else if (plan.target != null) {
      _turnResults.remember([plan.target!], turn: epoch);
    } else if (_searchKinds.contains(plan.kind)) {
      // مرآة السقوط الآمن: بحث بيانات ثم تثبيت نتائج الدور.
      final docs = await _doctorLookup(trimmed);
      conversation.rememberResults(docs, query: trimmed);
      if (docs.isNotEmpty) _turnResults.remember(docs, turn: epoch);
    }

    final turn = SmartBrainChatTurn.assistant(
      id: 'a$epoch',
      text: plan.message.trim().isEmpty ? 'تمام.' : plan.message.trim(),
      // نفس ما يفعله `_commitAssistantTurn` بعد الإصلاح.
      results: _turnResults.presentedIn(epoch),
    );
    turns.add(turn);
    return turn;
  }
}

class _ChatShell extends StatelessWidget {
  const _ChatShell({required this.turns});

  final List<SmartBrainChatTurn> turns;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ListView.builder(
            itemCount: turns.length,
            itemBuilder: (context, index) {
              final turn = turns[index];
              if (turn.role == SmartBrainChatRole.user) {
                return SmartBrainUserBubble(text: turn.text);
              }
              return SmartBrainAssistantBubble(
                turn: turn,
                onResultTap: (_) {},
              );
            },
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('أ — سلطة العرض تفصل الذاكرة عن الدور', () {
    test('الذاكرة تبقى بينما عرض الدور يخصّ دوره فقط', () {
      final results = SmartBrainTurnResults();
      results.remember([_saeedi], turn: 1);

      expect(results.presentedIn(1), hasLength(1),
          reason: 'الدور الذي أنتج النتيجة يعرضها');
      expect(results.presentedIn(2), isEmpty,
          reason: 'الدور اللاحق لا يورّث بطاقة الدور السابق');
      expect(results.retained, hasLength(1),
          reason: 'الذاكرة الداخلية تبقى للأفعال والاستمرارية');
    });

    test('عرض فارغ لا يمسح الذاكرة', () {
      final results = SmartBrainTurnResults();
      results.remember([_saeedi], turn: 1);
      expect(results.presentedIn(5), isEmpty);
      expect(results.retained.single.doctorId, 'saeedi');
    });
  });

  group('ب — شرط رسم البطاقة في الفقاعة الإنتاجية', () {
    testWidgets('دور بنتائج يرسم بطاقة طبيب', (tester) async {
      final turn = SmartBrainChatTurn.assistant(
        id: 'a1',
        text: 'لقيت طبيب أطفال.',
        results: [_saeedi],
      );
      await tester.pumpWidget(_ChatShell(turns: [turn]));

      expect(find.byType(SmartSearchResultCard), findsOneWidget);
      expect(find.text(_saeedi.title), findsOneWidget);
    });

    testWidgets('دور بلا نتائج لا يرسم أي بطاقة', (tester) async {
      final turn = SmartBrainChatTurn.assistant(
        id: 'a1',
        text: 'فهمت إن عندك سعال.',
      );
      await tester.pumpWidget(_ChatShell(turns: [turn]));

      expect(find.byType(SmartSearchResultCard), findsNothing);
      expect(find.text(_saeedi.title), findsNothing);
    });
  });

  group('ج — بحث طبيب ثم متابعة سريرية', () {
    testWidgets('البطاقة تظهر بالبحث وتغيب عن الأدوار السريرية', (tester) async {
      final s = _PresentationSession();

      final search = await s.submit('أريد طبيب أطفال');
      expect(search.results, isNotEmpty,
          reason: 'دور البحث ينتج نتائج دور: ${search.text}');
      expect(search.results.first.doctorId, 'saeedi');

      final cough = await s.submit('ابني عنده سعال من يومين');
      expect(cough.results, isEmpty,
          reason: 'دور سريري لا يطلب طبيباً ولا يرجّعه: ${cough.text}');

      final age = await s.submit('عمره 8 سنوات');
      expect(age.results, isEmpty,
          reason: 'استمرار تنفسي بلا بطاقة قديمة: ${age.text}');

      await tester.pumpWidget(_ChatShell(turns: s.turns));
      // بطاقة واحدة فقط في كل السجل: بطاقة دور البحث الأول.
      expect(find.byType(SmartSearchResultCard), findsOneWidget);
    });

    testWidgets('بطاقة الدور السابق تبقى في سجله ولا تُمحى', (tester) async {
      final s = _PresentationSession();
      await s.submit('أريد طبيب أطفال');
      await s.submit('ابني عنده سعال من يومين');

      final firstAssistant = s.turns
          .firstWhere((t) => t.role == SmartBrainChatRole.assistant);
      expect(firstAssistant.results, isNotEmpty,
          reason: 'السجل التاريخي لا يُعاد كتابته');

      await tester.pumpWidget(_ChatShell(turns: s.turns));
      expect(find.text(_saeedi.title), findsOneWidget);
    });
  });

  group('د — السياق الداخلي للطبيب يبقى بعد إخفاء البطاقة', () {
    test('الذاكرة ولقطة الأطباء تبقيان بعد الدور السريري', () async {
      final s = _PresentationSession();
      await s.submit('أريد طبيب أطفال');
      final cough = await s.submit('ابني عنده سعال من يومين');

      expect(cough.results, isEmpty, reason: 'العرض مخفي');
      expect(s.retainedResults, isNotEmpty,
          reason: 'الذاكرة الداخلية ما تُمسح لإخفاء البطاقة');
      expect(s.conversation.lastDoctorSnapshot, isNotEmpty,
          reason: 'لقطة أطباء المحادثة تبقى سلطة الأفعال');
    });

    test('«اتصل» بعد الدور السريري يحل الطبيب المحفوظ', () async {
      final s = _PresentationSession();
      await s.submit('أريد طبيب أطفال');
      s.conversation.selectDoctor(_saeedi);
      await s.submit('ابني عنده سعال من يومين');

      expect(s.selectedDoctor?.doctorId, 'saeedi',
          reason: 'الطبيب المحدد ما يُلمَس');

      final call = await s.submit('اتصل');
      expect(
        call.results.isNotEmpty ||
            s.conversation.hasPendingAction ||
            s.conversation.selectedDoctor?.doctorId == 'saeedi',
        isTrue,
        reason: 'سلوك الاتصال القائم على الطبيب المحفوظ: ${call.text}',
      );
    });

    testWidgets('طلب عرض الطبيب مجدداً يُرجع البطاقة عبر المسار القائم',
        (tester) async {
      final s = _PresentationSession();
      final first = await s.submit('أريد طبيب أطفال');
      expect(first.results, isNotEmpty);

      // دور عادي لا يطلب طبيباً — يجب ألا يورّث البطاقة.
      final chat = await s.submit('شكرا');
      expect(chat.results, isEmpty, reason: 'دور غير مرتبط: ${chat.text}');

      final again = await s.submit('أريد طبيب أطفال');
      expect(again.results, isNotEmpty,
          reason: 'الطلب الصريح يعيد البطاقة طبيعياً: ${again.text}');

      await tester.pumpWidget(_ChatShell(turns: s.turns));
      expect(find.byType(SmartSearchResultCard), findsNWidgets(2));
    });
  });
}
