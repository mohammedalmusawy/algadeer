import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/user_profile_service.dart';
import 'macos_arabic_tts_channel.dart';
import 'startup_greeting.dart';
import 'text_to_speech_service.dart';
import 'voice_settings.dart';

/// ترحيب الإطلاق على مستوى العملية — لا يرتبط بـ dispose للودجت حتى لا يُقطع النطق.
class StartupVoiceGreetingSession {
  StartupVoiceGreetingSession._();

  static bool _inFlight = false;
  static DeviceTextToSpeechService? _tts;

  static bool get isInFlight => _inFlight;

  /// يُستدعى بعد أول إطار للواجهة الرئيسية.
  static Future<void> runOnceAfterUiReady() async {
    if (!StartupGreeting.tryClaimGreetingSlot()) {
      debugPrint(
        '[GREETING] skip — already claimed this process launch '
        '(Home remount / nav / mic must NOT re-greet)',
      );
      return;
    }
    if (_inFlight) {
      debugPrint('[GREETING] skip — already in flight');
      return;
    }
    _inFlight = true;
    debugPrint('[GREETING] claimed slot — starting once-per-process speak');

    try {
      final profile = UserProfileService();
      final rawName = await profile.getDisplayName();
      final greeting = PersonalizedGreeting.fromDisplayName(rawName);
      final text = greeting.spokenGreeting;

      assert(
        text.startsWith('مرحباً بك'),
        'startup spoken greeting must begin with مرحباً بك',
      );
      assert(
        !text.contains('صباح الخير') && !text.contains('مساء الخير'),
        'time-based greetings must not be spoken',
      );

      final scalars = text.runes
          .take(24)
          .map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}')
          .join(' ');
      debugPrint(
        'StartupGreeting: REQUESTED spoken="$text" '
        'display="${greeting.displayGreeting}" '
        'firstName=${greeting.firstName ?? "[none]"} '
        'len=${text.length} scalars=[$scalars]',
      );

      final settings = VoiceSettingsService();
      final gender = await settings.getGender();
      debugPrint('StartupGreeting: selectedGender=${gender.name}');

      final tts = DeviceTextToSpeechService(settings: settings);
      _tts = tts;

      final ready = await tts.prepareArabicSiriVoice(gender);
      if (ready == null) {
        debugPrint(
          'StartupGreeting: SKIP — Arabic Siri voice not ready for '
          '${gender.name}; NOT using English/default TTS',
        );
        return;
      }

      debugPrint(
        'StartupGreeting: READY name=${ready.name} locale=${ready.locale} '
        'id=${ready.identifier} gender=${ready.platformGender} '
        'path=macos_say_stdin_utf8',
      );

      debugPrint('StartupGreeting: SPEECH_START fullUtterance="$text"');
      final ok = await tts.speakPreparedSiriUtterance(text);
      debugPrint(
        'StartupGreeting: SPEECH_END ok=$ok identifier=${ready.identifier}',
      );
    } catch (e, st) {
      debugPrint('StartupGreeting: FAILED (no English fallback): $e\n$st');
    } finally {
      _inFlight = false;
    }
  }

  /// إيقاف اختياري من مسار الميكروفون/البحث الحالي عبر MacOSArabicTtsChannel.stop.
  static Future<void> stopIfSpeaking() async {
    debugPrint('StartupGreeting: stopIfSpeaking requested');
    try {
      await _tts?.stop();
    } catch (_) {}
    await MacOSArabicTtsChannel.stop();
  }
}

/// يشغّل الترحيب مرة واحدة بعد أول إطار — بدون نطق داخل [build]،
/// وبدون إيقاف TTS عند dispose (ذلك كان يقطع الجملة).
class StartupVoiceGreetingHost extends StatefulWidget {
  const StartupVoiceGreetingHost({super.key, required this.child});

  final Widget child;

  @override
  State<StartupVoiceGreetingHost> createState() =>
      _StartupVoiceGreetingHostState();
}

class _StartupVoiceGreetingHostState extends State<StartupVoiceGreetingHost> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[GREETING] Host initState scheduled=$_scheduled '
      'hasSpoken=${StartupGreeting.hasSpokenThisLaunch} hash=$hashCode',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scheduled) return;
      _scheduled = true;
      debugPrint(
        '[GREETING] Host post-frame → runOnceAfterUiReady '
        'hasSpoken=${StartupGreeting.hasSpokenThisLaunch}',
      );
      unawaited(StartupVoiceGreetingSession.runOnceAfterUiReady());
    });
  }

  @override
  void dispose() {
    debugPrint(
      '[GREETING] Host dispose hasSpoken=${StartupGreeting.hasSpokenThisLaunch}',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// منسّق قابل للاختبار — للحارس والترحيب الشخصي الموحّد.
class StartupVoiceGreetingCoordinator {
  StartupVoiceGreetingCoordinator({
    this.onSpeak,
    this.displayName,
  });

  /// إن وُجد يُستدعى مرة واحدة بالنص الكامل؛ للاختبار بدون TTS حقيقي.
  final Future<void> Function(String text)? onSpeak;

  /// نفس مصدر الاسم المستخدم في الواجهة (اختياري للاختبار).
  final String? displayName;

  Future<String?> greetIfNeeded() async {
    if (!StartupGreeting.tryClaimGreetingSlot()) return null;
    final greeting = PersonalizedGreeting.fromDisplayName(displayName);
    final text = greeting.spokenGreeting;
    final speak = onSpeak;
    if (speak != null) {
      await speak(text);
    }
    return text;
  }
}
