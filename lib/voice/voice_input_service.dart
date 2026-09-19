import 'dart:async';

import 'package:flutter/foundation.dart';

import 'speech_recognition_service.dart';
import 'voice_assistant_state.dart';

/// سبب إنهاء دورة الميكروفون الحالية.
enum VoiceTurnFinalizeReason {
  manualStop,
  silenceTimeout,
  engineFinal,
}

/// طبقة إدخال صوت موحّدة فوق [SpeechRecognitionService] الحالي.
///
/// دورة واحدة (turn):
/// ready → listening → (speech) → silence/manual → finalizing → processing
/// → result/idle (الجاهزية من الواجهة)
///
/// ConversationContext يبقى خارج هذه الطبقة.
class VoiceInputService extends ChangeNotifier {
  VoiceInputService({
    SpeechRecognitionService? stt,
    this.silenceAfterSpeech = const Duration(milliseconds: 2800),
  }) : _stt = stt ?? DeviceSpeechRecognitionService();

  final SpeechRecognitionService _stt;

  /// صمت بعد بدء الكلام الفعلي — حوالي 2.5–3 ثوانٍ.
  final Duration silenceAfterSpeech;

  VoiceAssistantState _state = VoiceAssistantState.idle;
  bool _sessionActive = false;
  bool _busy = false;
  bool _manualStopRequested = false;
  bool _finalConsumedThisSession = false;
  bool _speechStarted = false;
  bool _finalizing = false;
  int _sessionToken = 0;
  String _transcript = '';
  String? _lastError;
  Timer? _silenceTimer;

  void Function(String text, {required bool isFinal})? onTranscript;
  void Function(String lastText)? onCaptureEnded;

  /// طلب إنهاء الدورة — الواجهة تستدعي [finalizeTurn] عبر مسار واحد.
  void Function(VoiceTurnFinalizeReason reason)? onTurnFinalizeRequested;
  void Function(String message)? onError;

  SpeechRecognitionService get stt => _stt;
  VoiceAssistantState get state => _state;
  bool get sessionActive => _sessionActive;
  bool get busy => _busy;
  bool get isListeningUi =>
      _sessionActive || _state == VoiceAssistantState.listening;
  String get transcript => _transcript;
  String? get lastError => _lastError;
  bool get manualStopRequested => _manualStopRequested;
  bool get speechStarted => _speechStarted;
  bool get isFinalizing => _finalizing;
  int get sessionToken => _sessionToken;
  bool get finalConsumedThisSession => _finalConsumedThisSession;

  @visibleForTesting
  bool get silenceTimerActiveForTest => _silenceTimer?.isActive ?? false;

  void _setState(VoiceAssistantState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  void setProcessing() => _setState(VoiceAssistantState.processing);

  void setResult() => _setState(VoiceAssistantState.result);

  void setSpeaking() => _setState(VoiceAssistantState.speaking);

  void setWaitingForConfirmation() =>
      _setState(VoiceAssistantState.waitingForConfirmation);

  /// جاهز لضغطة ميكروفون جديدة — لا يعيد فتح الاستماع.
  void setIdle() {
    _cancelSilenceTimer();
    _sessionActive = false;
    _finalizing = false;
    _setState(VoiceAssistantState.idle);
  }

  void setError(String message) {
    _lastError = message;
    _cancelSilenceTimer();
    _sessionActive = false;
    _finalizing = false;
    _setState(VoiceAssistantState.error);
    onError?.call(message);
  }

  void enterErrorState(String message) {
    _lastError = message;
    _cancelSilenceTimer();
    _sessionActive = false;
    _finalizing = false;
    _setState(VoiceAssistantState.error);
  }

  /// يمنع إعادة تنفيذ نفس الجلسة الصوتية مرتين (إيقاف + final متأخر).
  bool consumeFinalQuery(String raw) {
    final key = raw.trim();
    if (key.isEmpty) return false;
    if (_finalConsumedThisSession) return false;
    _finalConsumedThisSession = true;
    return true;
  }

  void clearFinalDedupe() {
    _finalConsumedThisSession = false;
  }

  Future<bool> initialize() => _stt.initialize();

  Future<void> startSession({bool clearTranscript = true}) async {
    if (_busy) {
      debugPrint('[MIC] startSession ignored — busy');
      return;
    }
    // جلسة حية أو إنهاء جارٍ: لا تبدأ ثانية (منع الظهور/الاختفاء/إعادة التشغيل).
    if (_sessionActive || _finalizing) {
      debugPrint(
        '[MIC] startSession ignored — already active/finalizing '
        'session=$_sessionActive finalizing=$_finalizing state=$_state',
      );
      return;
    }
    _busy = true;
    try {
      _cancelSilenceTimer();
      _manualStopRequested = false;
      _finalConsumedThisSession = false;
      _speechStarted = false;
      _finalizing = false;
      _lastError = null;
      _sessionToken++;
      if (clearTranscript) {
        _transcript = '';
      }
      _sessionActive = true;
      _setState(VoiceAssistantState.listening);
      debugPrint('[MIC] startSession begin token=$_sessionToken');
      await _listenInternal();
    } finally {
      _busy = false;
    }
  }

  Future<void> _listenInternal() async {
    final token = _sessionToken;
    await _stt.startListening(
      onResult: (text, {isFinal = false}) {
        if (token != _sessionToken) return;
        final trimmed = text.trim();
        if (trimmed.isNotEmpty) {
          _transcript = trimmed;
        }
        if (_manualStopRequested || !_sessionActive || _finalizing) {
          return;
        }
        if (trimmed.isNotEmpty) {
          _markSpeechAndResetSilence();
        }
        notifyListeners();
        onTranscript?.call(trimmed, isFinal: isFinal);
        // لا نُنهِ عند كل isFinal — المحرك قد يُرسل finals جزئية أثناء الإملاء.
        // الإنهاء التلقائي: مؤقّت الصمت أو onSessionEnd بعد كلام حقيقي.
      },
      onSessionEnd: (lastText) {
        if (token != _sessionToken) return;
        final trimmed = lastText.trim();
        if (trimmed.isNotEmpty) {
          _transcript = trimmed;
        }
        if (_manualStopRequested || !_sessionActive || _finalizing) {
          return;
        }
        notifyListeners();
        onCaptureEnded?.call(trimmed.isNotEmpty ? trimmed : _transcript);
        if (_speechStarted) {
          onTurnFinalizeRequested?.call(VoiceTurnFinalizeReason.engineFinal);
        } else {
          // انتهى المحرك قبل كلام حقيقي — جاهزية بدون إعادة فتح تلقائي.
          debugPrint(
            '[MIC] engine ended before speech — idle (no auto-restart)',
          );
          _sessionActive = false;
          _setState(VoiceAssistantState.idle);
        }
      },
      onError: (msg) {
        if (token != _sessionToken) return;
        debugPrint('VoiceInputService STT error: $msg');
        if (_manualStopRequested || _finalizing) return;
        setError(msg);
      },
    );
  }

  void _markSpeechAndResetSilence() {
    _speechStarted = true;
    _cancelSilenceTimer();
    if (!_sessionActive || _manualStopRequested || _finalizing) return;
    _silenceTimer = Timer(silenceAfterSpeech, () {
      if (!_sessionActive ||
          _manualStopRequested ||
          _finalizing ||
          !_speechStarted) {
        return;
      }
      onTurnFinalizeRequested?.call(VoiceTurnFinalizeReason.silenceTimeout);
    });
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  /// مسار إنهاء موحّد — يدوي أو صمت أو final من المحرك.
  /// يُرجع النص؛ null إن كانت الدورة تُنهى مسبقاً.
  Future<String?> finalizeTurn({
    required VoiceTurnFinalizeReason reason,
  }) async {
    if (_finalizing) return null;
    if (!_sessionActive && reason != VoiceTurnFinalizeReason.manualStop) {
      return null;
    }
    // لا نُنهِ بصمت قبل أن يبدأ الكلام فعلياً.
    if (reason == VoiceTurnFinalizeReason.silenceTimeout && !_speechStarted) {
      return null;
    }

    _finalizing = true;
    _cancelSilenceTimer();
    if (reason == VoiceTurnFinalizeReason.manualStop) {
      _manualStopRequested = true;
    }

    if (_busy && !_sessionActive) {
      _finalizing = false;
      return _transcript.trim();
    }

    _busy = true;
    final beforeStop = _transcript.trim();
    try {
      try {
        await _stt.stopListening();
      } catch (e, st) {
        debugPrint('VoiceInputService finalize stop failed: $e\n$st');
      }
      _sessionActive = false;
      _setState(VoiceAssistantState.processing);
      final afterStop = _transcript.trim();
      if (afterStop.isNotEmpty) return afterStop;
      return beforeStop;
    } finally {
      _busy = false;
      // الإيقاف اكتمل — اسمح بـ startSession لدور جديد.
      // تكرار finalize لنفس الدورة يُمنع بـ !_sessionActive.
      _finalizing = false;
    }
  }

  /// توافق مع الاستدعاءات القديمة — نفس مسار الإنهاء اليدوي.
  Future<String> stopSession() async {
    final text = await finalizeTurn(
      reason: VoiceTurnFinalizeReason.manualStop,
    );
    return (text ?? _transcript).trim();
  }

  /// لم يعد يُستأنف الاستماع تلقائياً — الدورات يدوية بالضغط على الميكروفون.
  @Deprecated('Turn-based voice: do not auto-resume after capture end')
  Future<void> resumeIfNeeded() async {
    // مقصود: لا شيء — دورة جديدة تبدأ فقط عبر startSession من الواجهة.
  }

  Future<void> cancelSession() async {
    _manualStopRequested = true;
    _cancelSilenceTimer();
    _finalizing = false;
    _speechStarted = false;
    try {
      await _stt.cancel();
    } catch (e, st) {
      debugPrint('VoiceInputService cancel failed: $e\n$st');
    }
    _sessionActive = false;
    _transcript = '';
    _setState(VoiceAssistantState.idle);
  }

  @override
  void dispose() {
    _cancelSilenceTimer();
    onTranscript = null;
    onCaptureEnded = null;
    onTurnFinalizeRequested = null;
    onError = null;
    super.dispose();
  }
}
