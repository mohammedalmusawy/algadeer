import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/speech_recognition_service.dart';
import 'package:ghadeer_clinic/voice/voice_assistant_state.dart';
import 'package:ghadeer_clinic/voice/voice_input_service.dart';

class _FakeStt implements SpeechRecognitionService {
  bool listening = false;
  void Function(String text, {bool isFinal})? _onResult;
  void Function(String lastText)? _onSessionEnd;

  @override
  Future<bool> initialize() async => true;

  @override
  bool get isAvailable => true;

  @override
  bool get isListening => listening;

  @override
  Future<void> startListening({
    required void Function(String text, {bool isFinal}) onResult,
    void Function(String message)? onError,
    void Function(String lastText)? onSessionEnd,
  }) async {
    listening = true;
    _onResult = onResult;
    _onSessionEnd = onSessionEnd;
  }

  @override
  Future<void> stopListening() async {
    listening = false;
  }

  @override
  Future<void> cancel() async {
    listening = false;
  }

  void emit(String text, {bool isFinal = false}) {
    _onResult?.call(text, isFinal: isFinal);
  }

  void endSession([String? last]) {
    listening = false;
    _onSessionEnd?.call(last ?? '');
  }
}

SmartSearchResult _doc(String id, String title) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: 'اختصاص',
    doctorId: id,
    score: 90,
    clinicLocation: 'الحارثية',
    phone: '0770',
    whatsapp: '0770',
  );
}

void main() {
  group('Step 4 hotfix — silence finalize', () {
    test('TEST 1 — silence after speech finalizes once', () {
      fakeAsync((async) {
        final stt = _FakeStt();
        final input = VoiceInputService(
          stt: stt,
          silenceAfterSpeech: const Duration(milliseconds: 2800),
        );
        var finalizeCount = 0;
        input.onTurnFinalizeRequested = (reason) {
          finalizeCount++;
          input.finalizeTurn(reason: reason);
        };

        input.startSession();
        async.flushMicrotasks();
        stt.emit('أريد طبيب أطفال');
        expect(input.speechStarted, isTrue);
        expect(input.silenceTimerActiveForTest, isTrue);

        async.elapse(const Duration(milliseconds: 2800));
        async.flushMicrotasks();

        expect(finalizeCount, 1);
        expect(input.sessionActive, isFalse);
        expect(input.state, VoiceAssistantState.processing);
      });
    });

    test('TEST 2 — speech update resets silence timer', () {
      fakeAsync((async) {
        final stt = _FakeStt();
        final input = VoiceInputService(
          stt: stt,
          silenceAfterSpeech: const Duration(milliseconds: 2800),
        );
        var finalizeCount = 0;
        input.onTurnFinalizeRequested = (_) => finalizeCount++;

        input.startSession();
        async.flushMicrotasks();
        stt.emit('أريد');
        async.elapse(const Duration(milliseconds: 2000));
        stt.emit('أريد طبيب أطفال');
        async.elapse(const Duration(milliseconds: 2000));
        expect(finalizeCount, 0);
        async.elapse(const Duration(milliseconds: 2800));
        async.flushMicrotasks();
        expect(finalizeCount, 1);
      });
    });

    test('TEST 3 — manual stop cancels timer and finalizes once', () {
      fakeAsync((async) {
        final stt = _FakeStt();
        final input = VoiceInputService(
          stt: stt,
          silenceAfterSpeech: const Duration(milliseconds: 2800),
        );
        var finalizeCount = 0;
        input.onTurnFinalizeRequested = (_) => finalizeCount++;

        input.startSession();
        async.flushMicrotasks();
        stt.emit('طبيب أطفال');
        expect(input.silenceTimerActiveForTest, isTrue);

        String? text;
        input
            .finalizeTurn(reason: VoiceTurnFinalizeReason.manualStop)
            .then((v) => text = v);
        async.flushMicrotasks();

        expect(text, 'طبيب أطفال');
        expect(input.silenceTimerActiveForTest, isFalse);

        async.elapse(const Duration(seconds: 5));
        expect(finalizeCount, 0);
        expect(input.consumeFinalQuery(text!), isTrue);
        expect(input.consumeFinalQuery(text!), isFalse);
      });
    });

    test('TEST 4 — silence + engine race → single finalize', () {
      fakeAsync((async) {
        final stt = _FakeStt();
        final input = VoiceInputService(
          stt: stt,
          silenceAfterSpeech: const Duration(milliseconds: 2800),
        );
        var finalizeCalls = 0;
        input.onTurnFinalizeRequested = (reason) {
          finalizeCalls++;
          input.finalizeTurn(reason: reason);
        };

        input.startSession();
        async.flushMicrotasks();
        stt.emit('ناجي الركابي');
        async.elapse(const Duration(milliseconds: 2800));
        async.flushMicrotasks();
        stt.endSession('ناجي الركابي');
        async.flushMicrotasks();

        expect(finalizeCalls, 1);
        expect(input.consumeFinalQuery('ناجي الركابي'), isTrue);
        expect(input.consumeFinalQuery('ناجي الركابي'), isFalse);
      });
    });

    test('does not silence-finalize before speech starts', () {
      fakeAsync((async) {
        final stt = _FakeStt();
        final input = VoiceInputService(
          stt: stt,
          silenceAfterSpeech: const Duration(milliseconds: 2800),
        );
        var finalizeCount = 0;
        input.onTurnFinalizeRequested = (_) => finalizeCount++;

        input.startSession();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        expect(finalizeCount, 0);
        expect(input.sessionActive, isTrue);
        expect(input.speechStarted, isFalse);
      });
    });

    test('TEST 8 — identical transcript allowed across sessions', () async {
      final stt = _FakeStt();
      final input = VoiceInputService(stt: stt);
      await input.startSession();
      stt.emit('ناجي الركابي');
      await input.finalizeTurn(reason: VoiceTurnFinalizeReason.manualStop);
      expect(input.consumeFinalQuery('ناجي الركابي'), isTrue);

      await input.startSession(clearTranscript: true);
      stt.emit('ناجي الركابي');
      await input.finalizeTurn(reason: VoiceTurnFinalizeReason.manualStop);
      expect(input.consumeFinalQuery('ناجي الركابي'), isTrue);
    });

    test('TEST 15 — after finalize, not listening while ready for TTS', () async {
      final stt = _FakeStt();
      final input = VoiceInputService(stt: stt);
      await input.startSession();
      stt.emit('أريد طبيب أطفال');
      await input.finalizeTurn(reason: VoiceTurnFinalizeReason.manualStop);
      input.setIdle();
      expect(input.sessionActive, isFalse);
      expect(stt.listening, isFalse);
      expect(input.state, VoiceAssistantState.idle);
    });
  });

  group('Step 4 hotfix — multi-turn context', () {
    late ConversationContext ctx;
    late SmartBrainPlanner planner;

    setUp(() {
      ctx = ConversationContext();
      planner = SmartBrainPlanner(
        doctorLookup: (_) async => const <SmartSearchResult>[],
      );
    });

    test('TEST 5/6/7 — second/third/fourth voice turns share context', () async {
      ctx.rememberResults([
        _doc('a', 'A'),
        _doc('b', 'B'),
        _doc('c', 'C'),
      ], query: 'أريد طبيب أطفال');

      final t2 = await planner.plan(query: 'الثاني', context: ctx);
      expect(t2.kind, AssistantActionKind.selectEntity);
      expect(t2.target?.doctorId, 'b');

      final t3 = await planner.plan(query: 'وين عيادته؟', context: ctx);
      expect(t3.kind, AssistantActionKind.showLocation);
      expect(t3.target?.doctorId, 'b');

      final t4 = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(t4.kind, AssistantActionKind.prepareCall);
      expect(t4.target?.doctorId, 'b');
    });
  });

  group('Step 4 hotfix — ordinal precedence', () {
    final resolver = RuleBasedIntentResolver();

    test('TEST 9 — fresh ordinal', () {
      final r = resolver.resolve('الثاني');
      expect(r.intent, AssistantIntent.selectResult);
      expect(r.requiresContext, isTrue);
    });

    test('TEST 10 — pure contextual ordinal', () {
      expect(resolver.resolve('اختار الثاني').intent, AssistantIntent.selectResult);
      expect(resolver.resolve('الثاني منهم').intent, AssistantIntent.selectResult);
    });

    test('TEST 11 — أريد دكتور علي الثاني is NOT selectResult', () {
      final r = resolver.resolve('أريد دكتور علي الثاني');
      expect(r.intent, isNot(AssistantIntent.selectResult));
      expect(
        r.intent == AssistantIntent.doctorSearch ||
            r.intent == AssistantIntent.generalSearch,
        isTrue,
      );
      expect(r.entities.doctorName, isNotNull);
    });

    test('TEST 12 — دكتور علي → doctorSearch', () {
      final r = resolver.resolve('دكتور علي');
      expect(r.intent, AssistantIntent.doctorSearch);
      expect(r.isActionIntent, isFalse);
    });

    test('TEST 13 — علي → doctor matching path', () {
      final r = resolver.resolve('علي');
      expect(r.isActionIntent, isFalse);
      expect(r.intent, isNot(AssistantIntent.selectResult));
      expect(
        r.intent == AssistantIntent.doctorSearch ||
            r.intent == AssistantIntent.generalSearch,
        isTrue,
      );
    });

    test('TEST 14 — عل safe partial, no action/ordinal', () {
      final r = resolver.resolve('عل');
      expect(r.intent, isNot(AssistantIntent.selectResult));
      expect(r.isActionIntent, isFalse);
      expect(
        r.intent == AssistantIntent.generalSearch ||
            r.intent == AssistantIntent.doctorSearch ||
            r.intent == AssistantIntent.unknown,
        isTrue,
      );
    });
  });
}
