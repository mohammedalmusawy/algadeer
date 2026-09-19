import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';
import 'package:ghadeer_clinic/search/voice_specialty_search_command.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
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

void main() {
  group('Arabic search meaning (Phase 1)', () {
    test('pediatric doctor variants share the same search meaning', () {
      const variants = [
        'اريد طبيب اطفال',
        'أريد طبيب أطفال',
        'اريد دكتور اطفال',
        'دكتور اطفال',
        'طبيب أطفال',
      ];
      final meanings = variants.map(ArabicTextUtils.toSearchMeaning).toSet();
      expect(meanings.length, 1, reason: 'all variants → one meaning key');
      expect(meanings.single, contains('طبيب'));
      expect(meanings.single, contains('اطفال'));
    });

    test('prepareQuery keeps original separate from normalized', () {
      final q = ArabicTextUtils.prepareQuery('أريد طبيب أطفال');
      expect(q.originalText, 'أريد طبيب أطفال');
      expect(q.normalizedText, isNot(contains('أ')));
      expect(q.searchMeaning, ArabicTextUtils.toSearchMeaning(q.originalText));
    });

    test('normalizes Arabic digits', () {
      expect(ArabicTextUtils.normalizeDigits('الطبيب ١'), 'الطبيب 1');
      expect(ArabicTextUtils.normalize('الساعة ٥'), contains('5'));
    });

    test('Iraqi aliases map toward shared meaning', () {
      expect(ArabicTextUtils.sameSearchMeaning('اريدلي طبيب', 'طبيب'), isTrue);
      expect(ArabicTextUtils.toSearchMeaning('وين الموقع'), contains('اين'));
    });
  });

  group('QueryInputSource hotfix — typed never auto-speaks', () {
    test('typed and system disallow auto speak; voice allows', () {
      expect(QueryInputSource.typed.allowsAutoSpeak, isFalse);
      expect(QueryInputSource.system.allowsAutoSpeak, isFalse);
      expect(QueryInputSource.voice.allowsAutoSpeak, isTrue);
    });

    test('typed must not show voice processing UI', () {
      expect(QueryInputSource.typed.showsVoiceProcessingUi, isFalse);
      expect(QueryInputSource.system.showsVoiceProcessingUi, isFalse);
      expect(QueryInputSource.voice.showsVoiceProcessingUi, isTrue);
    });

    test('progressive typed queries stay silent by source policy', () {
      for (final q in ['ط', 'طب', 'طبيب']) {
        expect(
          QueryInputSource.typed.allowsAutoSpeak,
          isFalse,
          reason: 'typed "$q" must not request TTS',
        );
      }
    });
  });

  group('RuleBasedIntentResolver (Phase 1 foundation)', () {
    final resolver = RuleBasedIntentResolver();

    test('specialty command classifies as specialtySearch', () {
      final r = resolver.resolve('أطباء الأطفال');
      expect(r.intent, AssistantIntent.specialtySearch);
      expect(r.confidence, greaterThanOrEqualTo(80));
    });

    test('general pediatric phrasing is doctor/specialty search', () {
      final r = resolver.resolve('اريد طبيب اطفال');
      expect(
        r.intent == AssistantIntent.doctorSearch ||
            r.intent == AssistantIntent.specialtySearch,
        isTrue,
      );
      expect(r.searchMeaning, isNotEmpty);
    });

    test('empty → unknown', () {
      expect(resolver.resolve('   ').intent, AssistantIntent.unknown);
    });
  });

  group('existing voice commands preserved', () {
    test('VoiceSpecialtySearchCommand still parses', () {
      final cmd = VoiceSpecialtySearchCommand.tryParse('أطباء الأطفال');
      expect(cmd, isNotNull);
      expect(cmd!.resolvedSpecialtyName, 'طب الأطفال');
    });

    test('VoiceSpecialtySearchCommand parses اريد طبيب اطفال', () {
      final cmd = VoiceSpecialtySearchCommand.tryParse('اريد طبيب اطفال');
      expect(cmd, isNotNull);
      expect(cmd!.resolvedSpecialtyName, 'طب الأطفال');
    });

    test('VoiceContactCommand still parses', () {
      final cmd = VoiceContactCommand.tryParse('اتصل بالدكتور علي');
      expect(cmd, isNotNull);
      expect(cmd!.kind, VoiceContactKind.call);
    });
  });

  group('VoiceInputService final dedupe / stop transcript', () {
    test(
      'consumeFinalQuery once per session; new session allows same text',
      () async {
        final stt = _FakeStt();
        final input = VoiceInputService(stt: stt);
        await input.startSession();
        expect(input.consumeFinalQuery('اريد طبيب اطفال'), isTrue);
        expect(input.consumeFinalQuery('اريد طبيب اطفال'), isFalse);

        // جلسة جديدة بعد إنهاء الدورة — لا startSession فوق جلسة حية.
        await input.finalizeTurn(reason: VoiceTurnFinalizeReason.manualStop);
        input.setIdle();
        await input.startSession(clearTranscript: true);
        expect(input.consumeFinalQuery('اريد طبيب اطفال'), isTrue);
      },
    );

    test('manual stop preserves latest transcript', () async {
      final stt = _FakeStt();
      final input = VoiceInputService(stt: stt);
      await input.startSession();
      stt.emit('اريد طبيب', isFinal: false);
      stt.emit('اريد طبيب اطفال', isFinal: false);

      final text = await input.stopSession();
      expect(text, 'اريد طبيب اطفال');
      expect(input.state, VoiceAssistantState.processing);
    });

    test(
      'late final after stop updates transcript but consume stays once',
      () async {
        final stt = _FakeStt();
        final input = VoiceInputService(stt: stt);
        await input.startSession();
        stt.emit('اريد طبيب اطفال', isFinal: false);

        final stopped = await input.stopSession();
        expect(stopped, 'اريد طبيب اطفال');
        expect(input.consumeFinalQuery(stopped), isTrue);

        stt.emit('اريد طبيب اطفال', isFinal: true);
        expect(input.transcript, 'اريد طبيب اطفال');
        expect(input.consumeFinalQuery(input.transcript), isFalse);
      },
    );

    test('session stays listening until explicit stop', () async {
      final stt = _FakeStt();
      final input = VoiceInputService(stt: stt);
      await input.startSession();
      expect(input.state, VoiceAssistantState.listening);
      expect(input.sessionActive, isTrue);

      stt.emit('طبيب', isFinal: false);
      expect(input.transcript, 'طبيب');
      expect(input.sessionActive, isTrue);

      stt.endSession('طبيب اطفال');
      expect(input.sessionActive, isTrue);

      final text = await input.stopSession();
      expect(text, contains('طبيب'));
      expect(input.state, VoiceAssistantState.processing);
      expect(input.sessionActive, isFalse);
    });
  });

  group('ConversationContext session-only', () {
    test('remembers results and selection without persistence API', () {
      final ctx = ConversationContext();
      ctx.rememberQuery('اريد طبيب', intent: AssistantIntent.doctorSearch);
      expect(ctx.lastQuery, 'اريد طبيب');
      expect(ctx.lastIntent, AssistantIntent.doctorSearch);
      ctx.reset();
      expect(ctx.lastQuery, isNull);
      expect(ctx.hasResults, isFalse);
    });
  });
}
