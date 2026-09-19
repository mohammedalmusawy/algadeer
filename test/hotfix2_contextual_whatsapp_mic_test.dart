import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/speech_recognition_service.dart';
import 'package:ghadeer_clinic/voice/voice_assistant_state.dart';
import 'package:ghadeer_clinic/voice/voice_input_service.dart';

SmartSearchResult _doc(String id, String title) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: 'اختصاص',
    doctorId: id,
    score: 95,
    phone: '0770',
    whatsapp: '0770',
    clinicLocation: 'بغداد',
  );
}

class _FakeStt implements SpeechRecognitionService {
  bool listening = false;
  int startCount = 0;
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
    startCount++;
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

void main() {
  group('Hotfix 2 — contextual WhatsApp / role reference', () {
    final resolver = RuleBasedIntentResolver();

    test('أرسل رسالة واتساب للدكتور → messageDoctor + requiresContext', () {
      final r = resolver.resolve('أرسل رسالة واتساب للدكتور');
      expect(r.intent, AssistantIntent.messageDoctor);
      expect(r.requiresContext, isTrue);
      expect(r.entities.doctorName, isNull);
    });

    test('راسل الدكتور → messageDoctor contextual', () {
      final r = resolver.resolve('راسل الدكتور');
      expect(r.intent, AssistantIntent.messageDoctor);
      expect(r.requiresContext, isTrue);
    });

    test('واتساب للدكتور → messageDoctor contextual', () {
      final r = resolver.resolve('واتساب للدكتور');
      expect(r.intent, AssistantIntent.messageDoctor);
      expect(r.requiresContext, isTrue);
    });

    test('VoiceContactCommand strips role-only target', () {
      final cmd = VoiceContactCommand.tryParse('أرسل رسالة واتساب للدكتور');
      expect(cmd, isNotNull);
      expect(cmd!.kind, VoiceContactKind.whatsapp);
      expect(cmd.targetQuery.trim(), isEmpty);
    });

    test('selected doctor → prepareWhatsApp same entity', () async {
      final ctx = ConversationContext();
      final ali = _doc('ali', 'علي ناصر');
      ctx.rememberResults([ali], query: 'علي');
      expect(ctx.selectedEntity?.doctorId, 'ali');

      final planner = SmartBrainPlanner(
        doctorLookup: (_) async {
          fail('must not search for role word الدكتور');
        },
      );
      final plan = await planner.plan(
        query: 'أرسل رسالة واتساب للدكتور',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'ali');
      expect(plan.canExecute, isTrue);
      expect(ctx.selectedEntity?.doctorId, 'ali');
    });

    test('دزله واتساب with selection', () async {
      final ctx = ConversationContext();
      ctx.rememberResults([_doc('a', 'A')]);
      final plan = await SmartBrainPlanner(
        doctorLookup: (_) async => const [],
      ).plan(query: 'دزله واتساب', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'a');
    });

    test('fresh context → clarification, no search', () async {
      final ctx = ConversationContext();
      var lookedUp = false;
      final plan = await SmartBrainPlanner(
        doctorLookup: (_) async {
          lookedUp = true;
          return const [];
        },
      ).plan(query: 'أرسل رسالة واتساب للدكتور', context: ctx);
      expect(lookedUp, isFalse);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.message, contains('أي طبيب'));
    });

    test('explicit Naji wins over selected Ali', () async {
      final ctx = ConversationContext();
      ctx.rememberResults([_doc('ali', 'علي ناصر')]);
      final naji = _doc('naji', 'ناجي عبد الله الركابي');
      final plan = await SmartBrainPlanner(
        doctorLookup: (_) async => [naji],
      ).plan(
        query: 'أرسل واتساب للدكتور ناجي عبدالله الركابي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'naji');
      expect(plan.target?.doctorId, isNot('ali'));
    });
  });

  group('Hotfix 2 — single microphone start', () {
    test('ONE startSession per physical start', () async {
      final stt = _FakeStt();
      final input = VoiceInputService(stt: stt);
      await input.startSession();
      expect(stt.startCount, 1);
      await input.startSession();
      expect(stt.startCount, 1, reason: 'second startSession ignored');
      expect(input.sessionActive, isTrue);
    });

    test('STT session end without speech → idle, NO auto-restart', () async {
      final stt = _FakeStt();
      final input = VoiceInputService(stt: stt);
      var finalizeCalls = 0;
      input.onTurnFinalizeRequested = (_) => finalizeCalls++;

      await input.startSession();
      expect(stt.startCount, 1);
      stt.endSession('');
      expect(input.sessionActive, isFalse);
      expect(input.state, VoiceAssistantState.idle);
      expect(finalizeCalls, 0);
      expect(stt.startCount, 1);
    });

    test('silence finalize does NOT restart', () {
      fakeAsync((async) {
        final stt = _FakeStt();
        final input = VoiceInputService(
          stt: stt,
          silenceAfterSpeech: const Duration(milliseconds: 2800),
        );
        input.onTurnFinalizeRequested = (reason) {
          input.finalizeTurn(reason: reason);
        };
        input.startSession();
        async.flushMicrotasks();
        stt.emit('طبيب');
        async.elapse(const Duration(milliseconds: 2800));
        async.flushMicrotasks();
        expect(stt.startCount, 1);
        expect(input.sessionActive, isFalse);
      });
    });

    test('second deliberate session after complete turn', () async {
      final stt = _FakeStt();
      final input = VoiceInputService(stt: stt);
      await input.startSession();
      stt.emit('ناجي');
      await input.finalizeTurn(reason: VoiceTurnFinalizeReason.manualStop);
      input.setIdle();
      expect(stt.startCount, 1);

      await input.startSession(clearTranscript: true);
      expect(stt.startCount, 2);
      expect(input.sessionActive, isTrue);
    });

    test('overlapping startSession while busy is ignored', () async {
      final stt = _FakeStt();
      final input = VoiceInputService(stt: stt);
      final a = input.startSession();
      final b = input.startSession();
      await Future.wait([a, b]);
      expect(stt.startCount, 1);
    });
  });
}
