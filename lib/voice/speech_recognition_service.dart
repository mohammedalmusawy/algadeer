import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../utils/app_pid.dart';

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

  /// مدة صمت المحرك بعد الكلام — متوافقة مع مؤقّت الإكمال في VoiceInputService (~3ث).
  /// الجلسة ليست استماعاً مستمراً لدقائق؛ كل ضغطة ميكروفون = دورة واحدة.
  static const continuousPause = Duration(seconds: 3);
  static const continuousListen = Duration(minutes: 2);

  static const permissionMessage =
      'يلزم السماح بالوصول إلى الميكروفون لاستخدام البحث الصوتي.';

  /// رسالة موحّدة عند غياب/رفض الصلاحية — لا تذكر فتح نافذة مستقلة.
  static const enablePermissionMessage =
      'يحتاج تطبيق الغدير إلى صلاحية الميكروفون والتعرف على الكلام. '
      'فعّل الصلاحية من إعدادات النظام ثم حاول مرة أخرى.';

  static const recognitionFailedMessage =
      'تعذر التعرف على الصوت، حاول مرة أخرى.';

  /// تشغيل تحت IDE/Flutter tools — استدعاء Speech يسبب SIGABRT (TCC).
  /// لا نعيد فتح التطبيق ولا نطلق نسخة ثانية؛ رسالة فقط.
  static const macosDevHostBlockedMessage =
      'البحث الصوتي غير متاح عند تشغيل التطبيق من بيئة التطوير. '
      'افتح تطبيق الغدير مباشرة (ملف .app) ثم استخدم الميكروفون.';

  @Deprecated('Second-app grant removed — use enablePermissionMessage')
  static const macosFirstGrantBlockedMessage = enablePermissionMessage;

  @Deprecated('Second-app grant removed — never opens another Ghadeer instance')
  static const macosGrantOpenedMessage = enablePermissionMessage;

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

  /// PID التشخيصي من الطبقة الأصلية (macOS) — للتحقق أن المايك لا يطلق عملية جديدة.
  static Future<String> diagnosticPidLabel() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return appPidLabel;
    try {
      final raw = await _macosTcc.invokeMethod<dynamic>('processId');
      if (raw is int) return '$raw';
      if (raw != null) return '$raw';
    } catch (e, st) {
      debugPrint('[MIC] processId channel failed: $e\n$st');
    }
    return appPidLabel;
  }

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
        final state =
            MacosSpeechReadyState.fromMap(Map<Object?, Object?>.from(raw));
        debugPrint(
          '[PERMISSION] PID=${state.pid ?? 'n/a'} speechReadyState '
          'speech=${state.speech} mic=${state.microphone} '
          'canInit=${state.canInitializeSafely} auth=${state.isFullyAuthorized} '
          'launchAttr=${state.launchServicesAttributed}',
        );
        return state;
      }
    } on MissingPluginException catch (e, st) {
      debugPrint('macOS speechReadyState channel missing: $e\n$st');
    } catch (e, st) {
      debugPrint('macOS speechReadyState failed: $e\n$st');
    }
    debugPrint(
      '[PERMISSION] speechReadyState unknown — no second-app fallback',
    );
    return const MacosSpeechReadyState(
      canInitializeSafely: false,
      speech: 'unknown',
      microphone: 'unknown',
      usageDescriptionsPresent: false,
      launchServicesAttributed: false,
    );
  }

  /// true عندما يمكن استدعاء speech_to_text.initialize (usage descriptions موجودة).
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

  /// CRITICAL FIX 3: معطل بالكامل — لا يطلق نسخة ثانية من التطبيق أبداً.
  /// يبقى الرمز كـ no-op آمن حتى لا يستدعي أي مسار قديم فتح .app.
  @Deprecated('Second Ghadeer instance launch permanently disabled')
  static Future<bool> openStandaloneForMicGrant() async {
    final pid = await diagnosticPidLabel();
    debugPrint(
      '[PERMISSION] PID=$pid openStandaloneForMicGrant REJECTED — '
      'second-app launch permanently disabled',
    );
    return false;
  }

  /// طلب صلاحيات الميكروفون/الكلام في نفس العملية عبر APIs الأصلية.
  static Future<MacosSpeechReadyState> requestPermissionsInProcess() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return macosSpeechReadyState();
    }
    final beforePid = await diagnosticPidLabel();
    debugPrint('[PERMISSION] PID=$beforePid requestPermissionsInProcess begin');
    try {
      final raw =
          await _macosTcc.invokeMethod<dynamic>('requestPermissionsInProcess');
      if (raw is Map) {
        final state =
            MacosSpeechReadyState.fromMap(Map<Object?, Object?>.from(raw));
        debugPrint(
          '[PERMISSION] PID=${state.pid ?? beforePid} '
          'requestPermissionsInProcess done auth=${state.isFullyAuthorized} '
          'speech=${state.speech} mic=${state.microphone}',
        );
        return state;
      }
    } on MissingPluginException catch (e, st) {
      debugPrint('macOS requestPermissionsInProcess missing: $e\n$st');
    } catch (e, st) {
      debugPrint('macOS requestPermissionsInProcess failed: $e\n$st');
    }
    return macosSpeechReadyState();
  }

  /// يفتح إعدادات خصوصية النظام فقط — ليس تطبيق الغدير.
  static Future<bool> openSystemPrivacySettings() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return false;
    final pid = await diagnosticPidLabel();
    try {
      final raw =
          await _macosTcc.invokeMethod<dynamic>('openSystemPrivacySettings');
      final ok = raw == true;
      debugPrint(
        '[PERMISSION] PID=$pid openSystemPrivacySettings ok=$ok '
        '(System Settings only — never Ghadeer.app)',
      );
      return ok;
    } on MissingPluginException catch (e, st) {
      debugPrint('macOS openSystemPrivacySettings missing: $e\n$st');
      return false;
    } catch (e, st) {
      debugPrint('macOS openSystemPrivacySettings failed: $e\n$st');
      return false;
    }
  }

  /// هل يوجد أي مسار نشط يطلق نسخة ثانية؟ دائماً false بعد FIX 3.
  static bool get mayLaunchSecondAppInstance => false;

  @Deprecated('Standalone grant removed — always false')
  static bool get standaloneGrantAttemptedThisProcess => false;

  @visibleForTesting
  @Deprecated('Standalone grant removed')
  static bool tryClaimStandaloneGrantAttemptForTest() => false;

  @visibleForTesting
  @Deprecated('Standalone grant removed — no-op')
  static void resetStandaloneGrantAttemptForTest() {}

  /// ينتظر حتى تُمنح صلاحيتا الميكروفون والكلام (نفس العملية — بدون فتح .app).
  static Future<bool> waitUntilSpeechAuthorized({
    Duration timeout = const Duration(seconds: 90),
    Duration pollEvery = const Duration(seconds: 1),
  }) async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return true;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final state = await macosSpeechReadyState();
      if (state.isFullyAuthorized) return true;
      if (state.speech == 'denied' || state.microphone == 'denied') {
        return false;
      }
      await Future<void>.delayed(pollEvery);
    }
    final last = await macosSpeechReadyState();
    return last.isFullyAuthorized;
  }

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
    final pid = await diagnosticPidLabel();
    debugPrint('[STT] PID=$pid initialize begin');
    try {
      final ready = await macosSpeechReadyState();
      if (!ready.canInitializeSafely) {
        debugPrint(
          '[STT] PID=$pid skipped initialize — usage descriptions missing '
          'or ready state unsafe (NO second-app fallback)',
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
        '[STT] PID=$pid initialize ok=$ok available=${_speech.isAvailable} '
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
      debugPrint('[STT] PID=$pid initialize PlatformException: $e\n$st');
      return false;
    } on StateError catch (e, st) {
      _initialized = false;
      _initFuture = null;
      debugPrint('[STT] PID=$pid initialize StateError: $e\n$st');
      return false;
    } catch (e, st) {
      _initialized = false;
      _initFuture = null;
      debugPrint('[STT] PID=$pid initialize failed: $e\n$st');
      return false;
    }
  }

  String _blockedReasonMessage(MacosSpeechReadyState ready) {
    if (!ready.launchServicesAttributed && ready.usageDescriptionsPresent) {
      return macosDevHostBlockedMessage;
    }
    if (ready.speech == 'denied' ||
        ready.microphone == 'denied' ||
        ready.speech == 'restricted' ||
        ready.microphone == 'restricted' ||
        ready.speech == 'notDetermined' ||
        ready.microphone == 'notDetermined') {
      return enablePermissionMessage;
    }
    return enablePermissionMessage;
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

    final pid = await diagnosticPidLabel();
    debugPrint('[STT] PID=$pid startListening enter');

    if (!isSupportedOnThisPlatform) {
      onError?.call('التعرف على الصوت غير متاح على هذا الجهاز');
      return;
    }

    var ready = await macosSpeechReadyState();

    // Under IDE/Flutter tools: never touch Speech/AV permission APIs (SIGABRT).
    if (!ready.canInitializeSafely) {
      debugPrint(
        '[STT] PID=$pid blocked — canInit=false '
        'launchAttr=${ready.launchServicesAttributed} '
        '(NO Speech API call, NO second-app launch)',
      );
      onError?.call(_blockedReasonMessage(ready));
      return;
    }

    // notDetermined: اطلب في نفس العملية ثم أعد الفحص — لا تفتح .app.
    if (!ready.isFullyAuthorized &&
        (ready.speech == 'notDetermined' ||
            ready.microphone == 'notDetermined') &&
        ready.usageDescriptionsPresent) {
      debugPrint(
        '[STT] PID=$pid notDetermined — requestPermissionsInProcess (same PID)',
      );
      ready = await requestPermissionsInProcess();
    }

    if (!ready.canInitializeSafely) {
      onError?.call(_blockedReasonMessage(ready));
      return;
    }

    if (ready.speech == 'denied' ||
        ready.microphone == 'denied' ||
        ready.speech == 'restricted' ||
        ready.microphone == 'restricted') {
      onError?.call(enablePermissionMessage);
      return;
    }

    if (_starting) {
      debugPrint('[STT] PID=$pid listen ignored — already starting');
      return;
    }

    // لا stop+restart إن كان الاستماع جارياً — ذلك يسبب وميض المايك (يختفي ثم يعود).
    if (_speech.isListening) {
      debugPrint(
        '[MIC] PID=$pid STT already listening — skip duplicate startListening',
      );
      return;
    }

    _starting = true;
    try {
      // نفس الضغطة: initialize (إن لزم) ثم listen مباشرة — نفس العملية.
      final ok = await initialize();
      if (!ok) {
        final after = await macosSpeechReadyState();
        if (after.speech == 'denied' ||
            after.microphone == 'denied' ||
            !after.canInitializeSafely) {
          onError?.call(_blockedReasonMessage(after));
          return;
        }
        final denied = !await _hasMicPermission();
        onError?.call(
          denied ? enablePermissionMessage : recognitionFailedMessage,
        );
        return;
      }

      if (_speech.isListening) {
        debugPrint(
          '[MIC] PID=$pid STT became listening during init — skip re-listen',
        );
        return;
      }

      final localeId = await _preferredLocaleId();
      debugPrint(
        '[STT] PID=$pid startListening locale=${localeId ?? 'default'} '
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
      debugPrint('[STT] PID=$pid listen() returned — same process');
    } on PlatformException catch (e, st) {
      debugPrint('[STT] PID=$pid startListening PlatformException: $e\n$st');
      onError?.call(recognitionFailedMessage);
    } on StateError catch (e, st) {
      debugPrint('[STT] PID=$pid startListening StateError: $e\n$st');
      onError?.call(recognitionFailedMessage);
    } catch (e, st) {
      debugPrint('[STT] PID=$pid startListening failed: $e\n$st');
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
    this.pid,
  });

  final bool canInitializeSafely;
  final String speech;
  final String microphone;
  final bool usageDescriptionsPresent;
  final bool launchServicesAttributed;
  final int? pid;

  bool get isFullyAuthorized =>
      speech == 'authorized' && microphone == 'authorized';

  bool get isDeniedOrRestricted =>
      speech == 'denied' ||
      microphone == 'denied' ||
      speech == 'restricted' ||
      microphone == 'restricted';

  bool get isNotDetermined =>
      speech == 'notDetermined' || microphone == 'notDetermined';

  factory MacosSpeechReadyState.fromMap(Map<Object?, Object?> map) {
    bool asBool(Object? v) => v == true || v == 1 || v == 'true';
    int? asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v');
    }

    return MacosSpeechReadyState(
      canInitializeSafely: asBool(map['canInitializeSafely']),
      speech: '${map['speech'] ?? 'unknown'}',
      microphone: '${map['microphone'] ?? 'unknown'}',
      usageDescriptionsPresent: asBool(map['usageDescriptionsPresent']),
      launchServicesAttributed: asBool(map['launchServicesAttributed']),
      pid: asInt(map['pid']),
    );
  }
}
