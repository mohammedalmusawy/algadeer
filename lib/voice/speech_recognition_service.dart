import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// طبقة STT مستقلة — لا تمر عبر AI Logic.
abstract class SpeechRecognitionService {
  Future<bool> initialize();

  bool get isAvailable;

  bool get isListening;

  Future<void> startListening({
    required void Function(String text, {bool isFinal}) onResult,
    void Function(String message)? onError,
    void Function(String lastText)? onSessionEnd,
  });

  Future<void> stopListening();

  Future<void> cancel();
}

/// STT على الجهاز — جلسة مستمرة حتى الإيقاف اليدوي (سلوك شبيه بـ ChatGPT Voice).
class DeviceSpeechRecognitionService implements SpeechRecognitionService {
  DeviceSpeechRecognitionService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  bool _starting = false;
  Future<bool>? _initFuture;
  String _lastHeard = '';
  void Function(String message)? _activeError;
  void Function(String lastText)? _activeSessionEnd;
  bool _sessionEndedNotified = false;

  static const _macosTcc = MethodChannel('ghadeer_clinic/macos_tcc');

  /// مدة استماع طويلة — لا نغلق الجلسة بصمت قصير.
  /// الحزمة قد توقف الالتقاط داخليًا؛ الواجهة تبقى مفتوحة حتى إيقاف المستخدم.
  static const continuousPause = Duration(minutes: 5);
  static const continuousListen = Duration(minutes: 5);

  static const permissionMessage =
      'يلزم السماح بالوصول إلى الميكروفون لاستخدام البحث الصوتي.';
  static const enablePermissionMessage =
      'فعّل صلاحية الميكروفون والتعرف على الصوت من إعدادات النظام لاستخدام البحث الصوتي.';
  static const recognitionFailedMessage =
      'تعذر التعرف على الصوت، حاول مرة أخرى.';

  /// تظهر فقط عندما لا يمكن طلب صلاحية لأول مرة بأمان تحت الـ IDE
  /// (Flutter #70374). لا تُستخدم إذا كانت الصلاحيات ممنوحة مسبقًا.
  static const macosFirstGrantBlockedMessage =
      'لمنح صلاحية الصوت لأول مرة على macOS، افتح التطبيق من مجلد البناء مرة واحدة '
      '(open build/macos/Build/Products/Debug/ghadeer_clinic.app) واسمح بالوصول، '
      'ثم سيعمل الميكروفون من ضغطة واحدة داخل البحث الذكي.';

  static bool get isSupportedOnThisPlatform {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
      default:
        return false;
    }
  }

  @override
  bool get isAvailable => _speech.isAvailable;

  @override
  bool get isListening => _speech.isListening;

  /// حالة جاهزية Speech/Mic على macOS (قراءة فقط — بدون طلب صلاحية).
  static Future<MacosSpeechReadyState> macosSpeechReadyState() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return const MacosSpeechReadyState(
        canInitializeSafely: true,
        speech: 'authorized',
        microphone: 'authorized',
        usageDescriptionsPresent: true,
        launchServicesAttributed: true,
      );
    }
    try {
      final raw = await _macosTcc.invokeMethod<dynamic>('speechReadyState');
      if (raw is Map) {
        return MacosSpeechReadyState.fromMap(Map<Object?, Object?>.from(raw));
      }
    } on MissingPluginException catch (e, st) {
      debugPrint('macOS speechReadyState channel missing: $e\n$st');
    } catch (e, st) {
      debugPrint('macOS speechReadyState failed: $e\n$st');
    }
    // بدون قناة أصلية لا نخاطر بطلب صلاحية أول مرة تحت الـ IDE.
    return const MacosSpeechReadyState(
      canInitializeSafely: false,
      speech: 'unknown',
      microphone: 'unknown',
      usageDescriptionsPresent: false,
      launchServicesAttributed: false,
    );
  }

  /// true عندما يمكن استدعاء speech_to_text.initialize بأمان (بدون SIGABRT).
  static Future<bool> canInitializeSafely() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return true;
    final state = await macosSpeechReadyState();
    debugPrint(
      'STT macOS ready: canInit=${state.canInitializeSafely} '
      'speech=${state.speech} mic=${state.microphone} '
      'usage=${state.usageDescriptionsPresent} '
      'launchAttr=${state.launchServicesAttributed}',
    );
    return state.canInitializeSafely;
  }

  @Deprecated('Use canInitializeSafely / macosSpeechReadyState')
  static Future<bool> isMacosTccSafe() => canInitializeSafely();

  Future<bool> _hasMicPermission() async {
    try {
      return await _speech.hasPermission;
    } on PlatformException catch (e, st) {
      debugPrint('STT hasPermission PlatformException: $e\n$st');
      return false;
    } on StateError catch (e, st) {
      debugPrint('STT hasPermission StateError: $e\n$st');
      return false;
    } catch (e, st) {
      debugPrint('STT hasPermission failed: $e\n$st');
      return false;
    }
  }

  void _notifySessionEnd([String? text]) {
    if (_sessionEndedNotified) return;
    _sessionEndedNotified = true;
    final last = (text ?? _lastHeard).trim();
    _activeSessionEnd?.call(last);
  }

  @override
  Future<bool> initialize() {
    if (!isSupportedOnThisPlatform) {
      debugPrint('STT: platform not supported ($defaultTargetPlatform)');
      return Future.value(false);
    }
    if (_initialized) {
      return _hasMicPermission().then(
        (permitted) => _speech.isAvailable && permitted,
      );
    }
    // تهيئة واحدة مشتركة — الضغطة الأولى تكمل إلى listen في نفس الاستدعاء.
    return _initFuture ??= _initializeOnce();
  }

  Future<bool> _initializeOnce() async {
    try {
      final ready = await macosSpeechReadyState();
      if (!ready.canInitializeSafely) {
        debugPrint(
          'STT: skipped initialize — first TCC prompt unsafe under IDE parent '
          '(Flutter #70374). Permissions already-granted path remains open.',
        );
        _initFuture = null;
        return false;
      }

      final ok = await _speech.initialize(
        finalTimeout: const Duration(seconds: 2),
        onError: (error) {
          debugPrint(
            'STT plugin error: ${error.errorMsg} permanent=${error.permanent}',
          );
          _activeError?.call(_messageForSttError(error.errorMsg));
          _notifySessionEnd(_lastHeard);
        },
        onStatus: (status) {
          debugPrint('STT status: $status');
          if (status == SpeechToText.doneStatus) {
            _notifySessionEnd(
              _speech.lastRecognizedWords.isNotEmpty
                  ? _speech.lastRecognizedWords
                  : _lastHeard,
            );
          }
        },
      );
      final permitted = await _hasMicPermission();
      debugPrint(
        'STT initialize ok=$ok available=${_speech.isAvailable} '
        'hasPermission=$permitted',
      );
      if (!ok || !permitted) {
        _initialized = false;
        _initFuture = null;
        return false;
      }
      _initialized = true;
      return true;
    } on PlatformException catch (e, st) {
      _initialized = false;
      _initFuture = null;
      debugPrint('STT initialize PlatformException: $e\n$st');
      return false;
    } on StateError catch (e, st) {
      _initialized = false;
      _initFuture = null;
      debugPrint('STT initialize StateError: $e\n$st');
      return false;
    } catch (e, st) {
      _initialized = false;
      _initFuture = null;
      debugPrint('STT initialize failed: $e\n$st');
      return false;
    }
  }

  String _blockedReasonMessage(MacosSpeechReadyState ready) {
    if (ready.speech == 'denied' || ready.microphone == 'denied') {
      return enablePermissionMessage;
    }
    if (ready.speech == 'restricted' || ready.microphone == 'restricted') {
      return enablePermissionMessage;
    }
    // notDetermined تحت IDE بدون attribution آمن لطلب أول مرة.
    return macosFirstGrantBlockedMessage;
  }

  @override
  Future<void> startListening({
    required void Function(String text, {bool isFinal}) onResult,
    void Function(String message)? onError,
    void Function(String lastText)? onSessionEnd,
  }) async {
    _activeError = onError;
    _activeSessionEnd = onSessionEnd;
    _sessionEndedNotified = false;
    _lastHeard = '';

    if (!isSupportedOnThisPlatform) {
      onError?.call('التعرف على الصوت غير متاح على هذا الجهاز');
      return;
    }

    final ready = await macosSpeechReadyState();
    if (!ready.canInitializeSafely) {
      onError?.call(_blockedReasonMessage(ready));
      return;
    }

    if (_starting) {
      debugPrint('STT: listen ignored — already starting');
      return;
    }

    _starting = true;
    try {
      if (_speech.isListening) {
        await stopListening();
      }

      // نفس الضغطة: initialize (إن لزم) ثم listen مباشرة.
      final ok = await initialize();
      if (!ok) {
        final after = await macosSpeechReadyState();
        if (!after.canInitializeSafely) {
          onError?.call(_blockedReasonMessage(after));
          return;
        }
        final denied = !await _hasMicPermission();
        onError?.call(
          denied ? enablePermissionMessage : recognitionFailedMessage,
        );
        return;
      }

      if (_speech.isListening) return;

      final localeId = await _preferredLocaleId();
      debugPrint(
        'STT startListening locale=${localeId ?? 'default'} '
        'continuous pause=${continuousPause.inSeconds}s '
        'listenFor=${continuousListen.inSeconds}s',
      );
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          if (text.trim().isNotEmpty) {
            _lastHeard = text.trim();
          }
          onResult(text, isFinal: result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          pauseFor: continuousPause,
          listenFor: continuousListen,
        ),
      );
    } on PlatformException catch (e, st) {
      debugPrint('STT startListening PlatformException: $e\n$st');
      onError?.call(recognitionFailedMessage);
    } on StateError catch (e, st) {
      debugPrint('STT startListening StateError: $e\n$st');
      onError?.call(recognitionFailedMessage);
    } catch (e, st) {
      debugPrint('STT startListening failed: $e\n$st');
      onError?.call(recognitionFailedMessage);
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } on PlatformException catch (e, st) {
      debugPrint('STT stopListening PlatformException: $e\n$st');
    } on StateError catch (e, st) {
      debugPrint('STT stopListening StateError: $e\n$st');
    } catch (e, st) {
      debugPrint('STT stopListening failed: $e\n$st');
    }
  }

  @override
  Future<void> cancel() async {
    _sessionEndedNotified = true;
    try {
      await _speech.cancel();
    } on PlatformException catch (e, st) {
      debugPrint('STT cancel PlatformException: $e\n$st');
    } on StateError catch (e, st) {
      debugPrint('STT cancel StateError: $e\n$st');
    } catch (e, st) {
      debugPrint('STT cancel failed: $e\n$st');
    }
  }

  Future<String?> _preferredLocaleId() async {
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();
        if (id == 'ar_sa' || id == 'ar-sa') return locale.localeId;
      }
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('ar')) {
          return locale.localeId;
        }
      }
      debugPrint(
        'STT: no Arabic locale. available: '
        '${locales.map((e) => e.localeId).join(', ')}',
      );
    } catch (e, st) {
      debugPrint('STT locales lookup failed: $e\n$st');
    }
    return null;
  }

  String _messageForSttError(String errorMsg) {
    final lower = errorMsg.toLowerCase();
    if (lower.contains('permission') ||
        lower.contains('not_allowed') ||
        lower.contains('denied') ||
        lower.contains('notauthorized') ||
        lower.contains('error_insufficient_permissions')) {
      return enablePermissionMessage;
    }
    return recognitionFailedMessage;
  }
}

class MacosSpeechReadyState {
  const MacosSpeechReadyState({
    required this.canInitializeSafely,
    required this.speech,
    required this.microphone,
    required this.usageDescriptionsPresent,
    required this.launchServicesAttributed,
  });

  final bool canInitializeSafely;
  final String speech;
  final String microphone;
  final bool usageDescriptionsPresent;
  final bool launchServicesAttributed;

  bool get isFullyAuthorized =>
      speech == 'authorized' && microphone == 'authorized';

  factory MacosSpeechReadyState.fromMap(Map<Object?, Object?> map) {
    bool asBool(Object? v) => v == true || v == 1 || v == 'true';
    return MacosSpeechReadyState(
      canInitializeSafely: asBool(map['canInitializeSafely']),
      speech: '${map['speech'] ?? 'unknown'}',
      microphone: '${map['microphone'] ?? 'unknown'}',
      usageDescriptionsPresent: asBool(map['usageDescriptionsPresent']),
      launchServicesAttributed: asBool(map['launchServicesAttributed']),
    );
  }
}
