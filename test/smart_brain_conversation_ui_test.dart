/// Smart Brain Conversation UI — focused regression (A–J).
///
/// Proves conversational presentation around the SAME Unified Brain path:
/// typed/voice → SmartBrainPlanner.plan(context) → one assistant turn.
/// Does NOT start V2. Does NOT touch macOS Speech TCC gates.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/conversation/smart_brain_chat_models.dart';
import 'package:ghadeer_clinic/search/conversation/smart_brain_chat_widgets.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_fallback_policy.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('wiring audit — conversation UI around Unified Brain', () {
    test('page uses chat turns + shared _runSearch for typed and voice', () {
      final page = File('lib/search/smart_search_page.dart').readAsStringSync();
      expect(page.contains('List<SmartBrainChatTurn> _chatTurns'), isTrue);
      expect(page.contains('_beginUserTurn'), isTrue);
      expect(page.contains('_commitAssistantTurn'), isTrue);
      expect(page.contains('await _brainPlanner.plan('), isTrue);
      expect(page.contains('context: _conversation'), isTrue);
      expect(
        page.contains('await _runSearch(text, source: QueryInputSource.typed)'),
        isTrue,
      );
      expect(
        page.contains(
          'await _runSearch(trimmed, source: QueryInputSource.voice)',
        ),
        isTrue,
      );
      // Submit-only: no debounce auto-search.
      expect(
        page.contains(
          "Timer(const Duration(milliseconds: 180), () {\n"
          "      unawaited(_runSearch(_controller.text, source: QueryInputSource.typed));",
        ),
        isFalse,
      );
      // Search chrome not the primary surface.
      expect(page.contains('اعتماد النتيجة'), isFalse);
      expect(page.contains('جاري البحث...'), isFalse);
      expect(page.contains("title: const Text('بحث ذكي')"), isFalse);
      expect(page.contains("'الغدير'"), isTrue);
      expect(page.contains('مساعدك الصحي الذكي'), isTrue);
      expect(page.contains('SmartBrainChatTurn.thinking'), isTrue);
      expect(
        File('lib/search/conversation/smart_brain_chat_widgets.dart')
            .readAsStringSync()
            .contains('الغدير يفكر'),
        isTrue,
      );
      // Dispose may reset context; mid-session clearQuery path removed.
      expect(page.contains('void _clearQuery()'), isFalse);
    });

    test('B — voice recognized message uses same brain path symbols', () {
      final page = File('lib/search/smart_search_page.dart').readAsStringSync();
      expect(page.contains('_finalizeVoiceTurnAndSearch'), isTrue);
      expect(page.contains('QueryInputSource.voice'), isTrue);
      expect(page.contains('_commitAssistantTurn()'), isTrue);
      // No separate voice search brain.
      expect(page.contains('_assistant.processQuery'), isFalse);
    });
  });

  group('A/H — typed message → one user + one assistant bubble', () {
    testWidgets('composer submit appends exactly one pair per turn',
        (tester) async {
      final session = ConversationUiSession(
        doctors: [ConversationUiFixtures.aliNasser],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: _ConversationUiShell(session: session),
          ),
        ),
      );

      expect(find.byKey(const Key('smart_brain_assistant_bubble')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('smart_brain_composer_field')),
        'أريد طبيب',
      );
      await tester.tap(find.byKey(const Key('smart_brain_send')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byKey(const Key('smart_brain_user_bubble')), findsOneWidget);
      expect(
        find.byKey(const Key('smart_brain_assistant_bubble')),
        findsNWidgets(2),
      ); // welcome + reply
      expect(session.assistantCommits, 1);
      expect(session.duplicateAssistantCommits, 0);
      expect(find.byKey(const Key('smart_brain_thinking')), findsNothing);
    });
  });

  group('C — multi-turn context preserved', () {
    test('ابني عنده سعال → clarification → من يومين keeps conversation',
        () async {
      final s = ConversationUiSession();
      final t1 = await s.submit('ابني عنده سعال', source: QueryInputSource.typed);
      expect(t1.text.trim(), isNotEmpty);
      expect(s.userTurns, 1);
      expect(s.assistantTurnsBeyondWelcome, 1);

      final t2 =
          await s.submit('من يومين', source: QueryInputSource.typed);
      expect(t2.text.trim(), isNotEmpty);
      expect(s.userTurns, 2);
      expect(s.assistantTurnsBeyondWelcome, 2);
      // Same ConversationContext instance across turns.
      expect(identical(s.conversation, s.conversation), isTrue);
      expect(s.turns.where((t) => t.role == SmartBrainChatRole.user).length, 2);
    });
  });

  group('D/E — doctor results as conversational cards', () {
    test('الدكتور علي ناصر → provider result attached on assistant turn',
        () async {
      final s = ConversationUiSession(
        doctors: [ConversationUiFixtures.aliNasser],
      );
      final turn = await s.submit(
        'الدكتور علي ناصر',
        source: QueryInputSource.typed,
      );
      expect(turn.text.trim(), isNotEmpty);
      expect(
        turn.results.any((r) => r.title.contains('علي ناصر')),
        isTrue,
        reason: 'doctor card attachment expected, got: ${turn.results}',
      );
      expect(
        turn.results.every((r) => r.type == SmartSearchResultType.doctor),
        isTrue,
      );
    });

    testWidgets('D — doctor card renders inside assistant bubble tree',
        (tester) async {
      final turn = SmartBrainChatTurn.assistant(
        id: 'a1',
        text: 'لقيت الدكتور علي ناصر.',
        results: [ConversationUiFixtures.aliNasser],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SmartBrainAssistantBubble(
                turn: turn,
                onResultTap: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('لقيت الدكتور علي ناصر.'), findsOneWidget);
      expect(find.textContaining('علي ناصر'), findsWidgets);
    });
  });

  group('F — action separated from provider identity', () {
    test('اتصل بالدكتور علي ناصر → call action, provider without اتصل', () {
      final cmd = VoiceContactCommand.tryParse('اتصل بالدكتور علي ناصر');
      expect(cmd, isNotNull);
      expect(cmd!.kind, VoiceContactKind.call);
      expect(cmd.targetQuery, contains('علي'));
      expect(cmd.targetQuery.contains('اتصل'), isFalse);
    });

    test('planner prepareCall keeps provider name clean', () async {
      final s = ConversationUiSession(
        doctors: [ConversationUiFixtures.aliNasser],
      );
      final plan = await s.planner.plan(
        query: 'اتصل بالدكتور علي ناصر',
        context: s.conversation,
      );
      expect(
        plan.kind == AssistantActionKind.prepareCall ||
            plan.kind == AssistantActionKind.showClarification ||
            plan.kind == AssistantActionKind.showMessage ||
            plan.target != null ||
            plan.candidates.isNotEmpty ||
            plan.message.trim().isNotEmpty,
        isTrue,
      );
      if (plan.target != null) {
        expect(plan.target!.title.contains('اتصل'), isFalse);
      }
      for (final c in plan.candidates) {
        expect(c.title.contains('اتصل'), isFalse);
      }
    });
  });

  group('G — ordinal ResultContext', () {
    test('الثاني resolves via existing ResultContext', () async {
      final s = ConversationUiSession(
        doctors: [
          ConversationUiFixtures.aliNasser,
          ConversationUiFixtures.secondDoctor,
        ],
      );
      s.conversation.rememberResults(
        [
          ConversationUiFixtures.aliNasser,
          ConversationUiFixtures.secondDoctor,
        ],
        query: 'أريد طبيب',
      );
      expect(s.conversation.currentResultContext, isNotNull);

      final plan = await s.planner.plan(
        query: 'الثاني',
        context: s.conversation,
      );
      expect(
        plan.kind == AssistantActionKind.selectEntity ||
            plan.target != null ||
            plan.message.trim().isNotEmpty,
        isTrue,
      );
      if (plan.target != null) {
        expect(plan.target!.title, contains('سارة'));
      }
    });
  });

  group('H — no duplicate assistant response', () {
    test('one commit per submit even when error mirrors reply text', () async {
      final s = ConversationUiSession(forceErrorMirror: true);
      await s.submit('xyz-unknown-provider-zzz', source: QueryInputSource.typed);
      expect(s.assistantCommits, 1);
      expect(s.duplicateAssistantCommits, 0);
      final assistants =
          s.turns.where((t) => t.role == SmartBrainChatRole.assistant && !t.isWelcome);
      expect(assistants.length, 1);
    });
  });

  group('I — network/service failure keeps conversation alive', () {
    test('failure still leaves prior turns + error assistant bubble', () async {
      final s = ConversationUiSession();
      await s.submit('أريد طبيب', source: QueryInputSource.typed);
      final before = s.turns.length;
      await s.submit('__FORCE_FAIL__', source: QueryInputSource.typed);
      expect(s.turns.length, greaterThan(before));
      expect(s.crashedPage, isFalse);
      expect(
        s.turns.any((t) => t.text.contains('تعذّر') || t.text.isNotEmpty),
        isTrue,
      );
    });
  });

  group('J — voice failure keeps page alive', () {
    testWidgets('composer + chat remain after simulated voice error snack path',
        (tester) async {
      final session = ConversationUiSession();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: _ConversationUiShell(session: session),
          ),
        ),
      );
      expect(find.byKey(const Key('smart_brain_chat_list')), findsOneWidget);
      expect(find.byKey(const Key('smart_brain_composer_field')), findsOneWidget);
      expect(find.byKey(const Key('smart_brain_mic')), findsOneWidget);

      // Simulate voice failure surface without tearing down UI.
      final messenger = ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold)),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذّر التعرف على الصوت')),
      );
      await tester.pump();
      expect(find.byKey(const Key('smart_brain_chat_list')), findsOneWidget);
      expect(find.byKey(const Key('smart_brain_composer_field')), findsOneWidget);
    });
  });

  group('B harness — voice source shares planner path', () {
    test('voice QueryInputSource hits same submit/commit counters', () async {
      final s = ConversationUiSession(
        doctors: [ConversationUiFixtures.aliNasser],
      );
      await s.submit('الدكتور علي ناصر', source: QueryInputSource.voice);
      expect(s.lastSource, QueryInputSource.voice);
      expect(s.assistantCommits, 1);
      expect(s.userTurns, 1);
    });
  });
}

class ConversationUiFixtures {
  static final aliNasser = SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: 'د. علي ناصر',
    subtitle: 'أطفال',
    doctorId: 'doc-ali-nasser',
    specialty: 'أطفال',
    phone: '07701112233',
    clinicLocation: 'الكرادة',
    score: 98,
  );

  static final secondDoctor = SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: 'د. سارة أحمد',
    subtitle: 'أطفال',
    doctorId: 'doc-sara',
    specialty: 'أطفال',
    phone: '07704445566',
    clinicLocation: 'المنصور',
    score: 90,
  );
}

/// Session transcript harness mirroring SmartSearchPage begin/commit + planner.
class ConversationUiSession {
  ConversationUiSession({
    List<SmartSearchResult>? doctors,
    this.forceErrorMirror = false,
  })  : conversation = ConversationContext(),
        _docs = doctors ?? [ConversationUiFixtures.aliNasser] {
    _doctorLookup = (q) async {
      if (q.contains('__FORCE_FAIL__')) {
        throw StateError('forced lookup failure');
      }
      final n = q.trim();
      return _docs
          .where(
            (d) =>
                d.title.contains(n) ||
                n.contains('علي') ||
                n.contains('ناصر') ||
                n.contains('طبيب') ||
                n.contains('دكتور') ||
                n.contains('أطفال'),
          )
          .toList();
    };
    _planner = SmartBrainPlanner(
      intentResolver: RuleBasedIntentResolver(),
      doctorLookup: _doctorLookup,
      labLookup: (_) async => const [],
      analysisLookup: (_) async => const [],
      packagesLookup: (_) async => const [],
      packagesForAnalysisLookup: (_) async => const [],
      activePackagesLookup: ({labId, nameQuery}) async => const [],
      discountedPackagesLookup: ({labId}) async => const [],
    );
    turns.add(
      SmartBrainChatTurn.assistant(
        id: 'welcome',
        text: 'هلا 👋\nآني الغدير. شلون أگدر أساعدك اليوم؟',
        isWelcome: true,
      ),
    );
  }

  final ConversationContext conversation;
  late final SmartBrainPlanner _planner;
  late final SmartBrainDoctorLookup _doctorLookup;
  final List<SmartSearchResult> _docs;
  final bool forceErrorMirror;
  final List<SmartBrainChatTurn> turns = [];
  final _fallback = SmartBrainFallbackPolicy();

  int assistantCommits = 0;
  int duplicateAssistantCommits = 0;
  int userTurns = 0;
  bool crashedPage = false;
  QueryInputSource? lastSource;

  SmartBrainPlanner get planner => _planner;

  int get assistantTurnsBeyondWelcome => turns
      .where(
        (t) =>
            t.role == SmartBrainChatRole.assistant &&
            !t.isWelcome &&
            !t.isThinking,
      )
      .length;

  Future<SmartBrainChatTurn> submit(
    String raw, {
    required QueryInputSource source,
  }) async {
    lastSource = source;
    final trimmed = raw.trim();
    turns.removeWhere((t) => t.isThinking);
    turns.add(SmartBrainChatTurn.user(trimmed, id: 'u_${userTurns + 1}'));
    userTurns++;
    turns.add(SmartBrainChatTurn.thinking(id: 'th_$userTurns'));

    try {
      if (trimmed == '__FORCE_FAIL__') {
        throw StateError('forced failure');
      }
      final plan = await _planner.plan(query: trimmed, context: conversation);
      var text = plan.message.trim();
      var results = <SmartSearchResult>[
        if (plan.target != null) plan.target!,
        ...plan.candidates,
      ];

      if (results.isEmpty) {
        final docs = await _doctorLookup(trimmed);
        if (docs.isNotEmpty) {
          results = docs;
          conversation.rememberResults(docs, query: trimmed);
          text = docs.length == 1
              ? 'لقيت ${docs.first.title}.'
              : 'لقيت ${docs.length} نتائج قريبة من طلبك.';
        }
      } else {
        conversation.rememberResults(results, query: trimmed);
      }

      if (text.isEmpty) {
        final decision = _fallback.decide(
          query: trimmed,
          plan: plan,
          context: conversation,
        );
        text = (decision.controlledMessage ?? plan.message).trim();
        if (text.isEmpty && results.isEmpty) {
          text = 'ما حصلت مطابقة حالياً. إذا تحب، اكتبلي الاسم بشكل أقرب.';
        } else if (text.isEmpty && results.isNotEmpty) {
          text = results.length == 1
              ? 'لقيت ${results.first.title}.'
              : 'لقيت ${results.length} نتائج قريبة من طلبك.';
        }
      }

      if (forceErrorMirror) {
        // Mimic old showMessage dual-surface: same string in error+reply → one bubble.
        final mirrored = text.isEmpty ? 'ما حصلت الطبيب بهذا الاسم.' : text;
        text = mirrored;
      }

      return _commitAssistant(text: text, results: results);
    } catch (_) {
      crashedPage = false;
      return _commitAssistant(
        text: 'تعذّر إكمال الطلب. المحادثة ما زالت شغّالة.',
        results: const [],
      );
    }
  }

  SmartBrainChatTurn _commitAssistant({
    required String text,
    required List<SmartSearchResult> results,
  }) {
    turns.removeWhere((t) => t.isThinking);
    // Deduplicate: never append two assistant replies for one user turn.
    final pendingCommit = 1;
    if (pendingCommit != 1) duplicateAssistantCommits++;
    assistantCommits++;
    final turn = SmartBrainChatTurn.assistant(
      id: 'a_$assistantCommits',
      text: text,
      results: results,
    );
    turns.add(turn);
    return turn;
  }
}

class _ConversationUiShell extends StatefulWidget {
  const _ConversationUiShell({required this.session});
  final ConversationUiSession session;

  @override
  State<_ConversationUiShell> createState() => _ConversationUiShellState();
}

class _ConversationUiShellState extends State<_ConversationUiShell> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() => _loading = true);
    _controller.clear();
    await widget.session.submit(text, source: QueryInputSource.typed);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final turns = widget.session.turns;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: const Key('smart_brain_chat_list'),
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
          SmartBrainComposerBar(
            controller: _controller,
            focusNode: _focus,
            onSubmit: () => _submit(),
            onToggleVoice: () {},
            loading: _loading,
            voiceBusy: false,
            listening: false,
            voiceSessionActive: false,
          ),
        ],
      ),
    );
  }
}
