import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/voice/startup_greeting.dart';
import 'package:ghadeer_clinic/voice/startup_voice_greeting_coordinator.dart';

void main() {
  setUp(StartupGreeting.resetForTest);

  group('PersonalizedGreeting', () {
    test('CASE 1 — name exists (محمد)', () {
      final g = PersonalizedGreeting.fromDisplayName('محمد');
      expect(g.displayGreeting, 'مرحباً بك، محمد 👋');
      expect(g.subtitle, 'كيف يمكنني مساعدتك؟');
      expect(
        g.spokenGreeting,
        'مرحباً بك محمد في تطبيق الغدير، كيف يمكنني مساعدتك اليوم؟',
      );
      expect(g.firstName, 'محمد');
      expect(g.spokenGreeting.startsWith('مرحباً بك'), isTrue);
      expect(g.spokenGreeting.contains('صباح الخير'), isFalse);
      expect(g.spokenGreeting.contains('مساء الخير'), isFalse);
      expect(g.spokenGreeting.contains('أهلاً'), isFalse);
    });

    test('CASE 1b — Phase 3B full name uses first token only', () {
      final g = PersonalizedGreeting.fromDisplayName('محمد علي حسن');
      expect(g.firstName, 'محمد');
      expect(g.displayGreeting, 'مرحباً بك، محمد 👋');
      expect(g.spokenGreeting.contains('محمد علي'), isFalse);
    });

    test('CASE 2 — no valid name', () {
      final g = PersonalizedGreeting.fromDisplayName(null);
      expect(g.displayGreeting, 'مرحباً بك 👋');
      expect(g.subtitle, 'كيف يمكنني مساعدتك؟');
      expect(
        g.spokenGreeting,
        'مرحباً بك في تطبيق الغدير، كيف يمكنني مساعدتك اليوم؟',
      );
      expect(g.firstName, isNull);
    });

    test('rejects email / phone / empty / placeholders', () {
      expect(sanitizeGreetingName(''), isNull);
      expect(sanitizeGreetingName('   '), isNull);
      expect(sanitizeGreetingName(null), isNull);
      expect(sanitizeGreetingName('null'), isNull);
      expect(sanitizeGreetingName('user@mail.com'), isNull);
      expect(sanitizeGreetingName('+9647701234567'), isNull);
      expect(sanitizeGreetingName('07701234567'), isNull);
      expect(sanitizeGreetingName('user'), isNull);
      expect(sanitizeGreetingName('اسم'), isNull);

      expect(
        PersonalizedGreeting.fromDisplayName('ali@x.com').spokenGreeting,
        'مرحباً بك في تطبيق الغدير، كيف يمكنني مساعدتك اليوم؟',
      );
    });

    test('CASE 8 — no active morning/evening/night strings in model', () {
      for (final raw in [null, 'محمد', '', 'test@x.com']) {
        final spoken = PersonalizedGreeting.fromDisplayName(raw).spokenGreeting;
        expect(spoken.contains('صباح الخير'), isFalse);
        expect(spoken.contains('مساء الخير'), isFalse);
        expect(spoken.contains('أهلاً بك'), isFalse);
        expect(spoken.startsWith('مرحباً بك'), isTrue);
      }
    });
  });

  group('once-per-launch guard', () {
    test('tryClaimGreetingSlot only once', () {
      expect(StartupGreeting.tryClaimGreetingSlot(), isTrue);
      expect(StartupGreeting.hasSpokenThisLaunch, isTrue);
      expect(StartupGreeting.tryClaimGreetingSlot(), isFalse);
    });

    test('CASE 3 — rebuild / second coordinator call does not greet again',
        () async {
      final spoken = <String>[];
      const expected =
          'مرحباً بك محمد في تطبيق الغدير، كيف يمكنني مساعدتك اليوم؟';

      final c1 = StartupVoiceGreetingCoordinator(
        displayName: 'محمد',
        onSpeak: (t) async => spoken.add(t),
      );
      final c2 = StartupVoiceGreetingCoordinator(
        displayName: 'محمد',
        onSpeak: (t) async => spoken.add(t),
      );

      final first = await c1.greetIfNeeded();
      final second = await c2.greetIfNeeded();
      final third = await c1.greetIfNeeded();

      expect(first, expected);
      expect(second, isNull);
      expect(third, isNull);
      expect(spoken, [expected]);
    });

    test('CASE 4 — navigation-style repeated greetIfNeeded stays once',
        () async {
      final spoken = <String>[];
      final coord = StartupVoiceGreetingCoordinator(
        displayName: null,
        onSpeak: (t) async => spoken.add(t),
      );

      for (var i = 0; i < 5; i++) {
        await coord.greetIfNeeded();
      }
      expect(spoken, [
        'مرحباً بك في تطبيق الغدير، كيف يمكنني مساعدتك اليوم؟',
      ]);
    });

    test('CASE 5 — reset allows greeting again (new launch)', () async {
      final spoken = <String>[];
      Future<void> launch() async {
        final c = StartupVoiceGreetingCoordinator(
          displayName: 'محمد',
          onSpeak: (t) async => spoken.add(t),
        );
        await c.greetIfNeeded();
      }

      await launch();
      expect(spoken, hasLength(1));

      StartupGreeting.resetForTest();
      await launch();
      expect(spoken, hasLength(2));
      expect(
        spoken.last,
        'مرحباً بك محمد في تطبيق الغدير، كيف يمكنني مساعدتك اليوم؟',
      );
    });
  });
}
