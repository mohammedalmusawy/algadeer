import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// macOS bridge: discovers Spoken Content / Siri neural Arabic voices and speaks them.
class MacOSArabicTtsChannel {
  MacOSArabicTtsChannel._();

  static const MethodChannel _channel = MethodChannel(
    'ghadeer_clinic/macos_arabic_tts',
  );

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static Future<List<Map<String, dynamic>>> discoverArabicVoices() async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'discoverArabicVoices',
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('MacOSArabicTtsChannel.discoverArabicVoices failed: $e\n$st');
      return const [];
    }
  }

  static Future<bool> speak({
    required String text,
    required String identifier,
    double? rate,
  }) async {
    if (!isSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('speak', {
        'text': text,
        'identifier': identifier,
        ?'rate': rate,
      });
      return ok == true;
    } catch (e, st) {
      debugPrint('MacOSArabicTtsChannel.speak failed: $e\n$st');
      return false;
    }
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e, st) {
      debugPrint('MacOSArabicTtsChannel.stop failed: $e\n$st');
    }
  }

  /// Voices that need the System Voice / `say` path (not AVSpeech/flutter_tts).
  static bool needsSystemVoiceSpeak(String? identifier) {
    if (identifier == null || identifier.isEmpty) return false;
    final id = identifier.toLowerCase();
    return id.contains('ttsbundle') || id.contains('gryphon');
  }
}
