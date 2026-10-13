import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/voice/speech_recognition_service.dart';
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

/// المايك كان ينتظر 3.8ث صمت بعد كل سؤال؛ الجملة المكتملة صارت ثانيتين،
/// والجملة الناقصة («اتصل دكتور…») تبقى على المهلة الطويلة حتى لا يُقطع الاسم.
void main() {
  test('complete vs incomplete utterances', () {
    for (final t in [
      'أريد طبيب أطفال',
      'اتصل على الدكتور علي ناصر',
      'دز واتساب لصيدلية رحاب',
      'وين مختبر السحب المنزلي',
    ]) {
      expect(VoiceInputService.looksCompleteUtterance(t), isTrue, reason: t);
    }
    for (final t in [
      'أريد',
      'اتصل',
      'اتصل على',
      'اتصل دكتور',
      'دز واتساب لـ',
      'أريد طبيب',
      'اتصل على الدكتورة',
      '',
    ]) {
      expect(VoiceInputService.looksCompleteUtterance(t), isFalse, reason: t);
    }
  });

  test('complete sentence finalizes after the short silence', () {
    fakeAsync((async) {
      final stt = _FakeStt();
      final input = VoiceInputService(
        stt: stt,
        completeUtteranceSilence: const Duration(milliseconds: 2000),
      );
      var finalizeCount = 0;
      input.onTurnFinalizeRequested = (_) => finalizeCount++;
      input.startSession();
      async.flushMicrotasks();
      stt.emit('أريد طبيب أطفال');
      async.elapse(const Duration(milliseconds: 1900));
      expect(finalizeCount, 0);
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      expect(finalizeCount, 1);
    });
  });

  test('unfinished sentence keeps the long silence', () {
    fakeAsync((async) {
      final stt = _FakeStt();
      final input = VoiceInputService(
        stt: stt,
        completeUtteranceSilence: const Duration(milliseconds: 2000),
      );
      var finalizeCount = 0;
      input.onTurnFinalizeRequested = (_) => finalizeCount++;
      input.startSession();
      async.flushMicrotasks();
      stt.emit('اتصل دكتور');
      async.elapse(const Duration(milliseconds: 3000));
      expect(finalizeCount, 0);
      stt.emit('اتصل دكتور ناجي الركابي');
      async.elapse(const Duration(milliseconds: 2100));
      async.flushMicrotasks();
      expect(finalizeCount, 1);
    });
  });
}
