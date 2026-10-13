import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/services/dynamic_message_service.dart';
import 'package:ghadeer_clinic/voice/macos_arabic_tts_channel.dart';
import 'package:ghadeer_clinic/voice/startup_greeting.dart';

/// تحية الافتتاح: صباح/مساء الخير + الاسم + رعاية يكتبها المدير.
void main() {
  group('timedStartupSpokenGreeting', () {
    test('morning with first name only', () {
      final t = timedStartupSpokenGreeting(
        rawName: 'محمد علي حسن',
        now: DateTime(2026, 10, 13, 9, 30),
      );
      expect(t, 'صباح الخير محمد، أهلاً وسهلاً بك في منصة الغدير.');
    });

    test('evening and night use مساء الخير', () {
      for (final h in [12, 18, 23, 0, 3]) {
        final t = timedStartupSpokenGreeting(
          rawName: 'محمد',
          now: DateTime(2026, 10, 13, h),
        );
        expect(t, startsWith('مساء الخير محمد'), reason: 'hour $h');
      }
      expect(
        timedStartupSpokenGreeting(rawName: 'محمد', now: DateTime(2026, 1, 1, 4)),
        startsWith('صباح الخير'),
      );
    });

    test('no valid name → greeting without a name', () {
      for (final raw in [null, '', 'user@mail.com', '07701234567']) {
        expect(
          timedStartupSpokenGreeting(
            rawName: raw,
            now: DateTime(2026, 10, 13, 20),
          ),
          'مساء الخير، أهلاً وسهلاً بك في منصة الغدير.',
        );
      }
    });

    test('sponsor line appended once, with a full stop', () {
      final t = timedStartupSpokenGreeting(
        rawName: 'محمد',
        now: DateTime(2026, 10, 13, 10),
        sponsorLine: '  التطبيق برعاية أبو سعدية الشطرة للموبايلات ',
      );
      expect(
        t,
        'صباح الخير محمد، أهلاً وسهلاً بك في منصة الغدير. '
        'التطبيق برعاية أبو سعدية الشطرة للموبايلات.',
      );
      expect(
        timedStartupSpokenGreeting(
          rawName: null,
          now: DateTime(2026, 10, 13, 10),
          sponsorLine: '   ',
        ),
        isNot(contains('برعاية')),
      );
    });
  });

  test('admin can pick the sponsor voice placement', () {
    expect(
      DynamicMessagePlacement.all,
      contains(DynamicMessagePlacement.sponsorVoice),
    );
    expect(
      DynamicMessagePlacement.labelAr(DynamicMessagePlacement.sponsorVoice),
      contains('الرعاية الصوتية'),
    );
  });

  test('iPhone voice ids are not routed to the macOS-only channel', () {
    // في الاختبار المنصة ليست macOS — مثل الآيفون والأندرويد.
    expect(
      MacOSArabicTtsChannel.needsSystemVoiceSpeak(
        'com.apple.ttsbundle.Maged-compact',
      ),
      isFalse,
    );
  });
}
