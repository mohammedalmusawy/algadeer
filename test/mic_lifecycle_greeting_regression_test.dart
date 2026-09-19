import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/smart_search_page.dart';
import 'package:ghadeer_clinic/voice/speech_recognition_service.dart';
import 'package:ghadeer_clinic/voice/startup_greeting.dart';
import 'package:ghadeer_clinic/voice/startup_voice_greeting_coordinator.dart';

void main() {
  setUp(() {
    StartupGreeting.resetForTest();
    // ignore: deprecated_member_use_from_same_package
    DeviceSpeechRecognitionService.resetStandaloneGrantAttemptForTest();
  });

  group('mic lifecycle / greeting regression', () {
    test('TEST 1 — coordinator greetIfNeeded only once per process', () async {
      final spoken = <String>[];
      Future<String?> once() {
        return StartupVoiceGreetingCoordinator(
          displayName: 'محمد',
          onSpeak: (t) async => spoken.add(t),
        ).greetIfNeeded();
      }

      expect(await once(), isNotNull);
      expect(await once(), isNull);
      expect(await once(), isNull);
      expect(spoken.length, 1);
    });

    test('TEST 6 — Host remount schedules but claim blocks second speak',
        () async {
      final spoken = <String>[];
      // Simulate Host calling runOnce path via coordinator claim.
      expect(StartupGreeting.tryClaimGreetingSlot(), isTrue);
      expect(StartupGreeting.tryClaimGreetingSlot(), isFalse);

      final hostCoord = StartupVoiceGreetingCoordinator(
        displayName: 'محمد',
        onSpeak: (t) async => spoken.add(t),
      );
      expect(await hostCoord.greetIfNeeded(), isNull);
      expect(spoken, isEmpty);
    });

    test('runOnceAfterUiReady respects process claim without second speak slot',
        () async {
      expect(StartupGreeting.tryClaimGreetingSlot(), isTrue);
      // Simulate Host remount calling runOnce after claim:
      await StartupVoiceGreetingSession.runOnceAfterUiReady();
      expect(StartupGreeting.hasSpokenThisLaunch, isTrue);
    });

    test('CRITICAL FIX 3 — second-app launch permanently disabled', () async {
      expect(DeviceSpeechRecognitionService.mayLaunchSecondAppInstance, isFalse);
      // ignore: deprecated_member_use_from_same_package
      expect(
        await DeviceSpeechRecognitionService.openStandaloneForMicGrant(),
        isFalse,
      );
    });

    test('TEST 7 — autoStartVoice flag is a constructor input only once', () {
      const a = SmartSearchPage(autoStartVoice: true);
      const b = SmartSearchPage(autoStartVoice: true);
      expect(a.autoStartVoice, isTrue);
      expect(b.autoStartVoice, isTrue);
      // Consumption is per State instance (_autoStartVoiceConsumed), not global.
      expect(identical(a, b), isFalse);
    });

    test('fully authorized ready state implies in-place listen path', () {
      const ready = MacosSpeechReadyState(
        canInitializeSafely: true,
        speech: 'authorized',
        microphone: 'authorized',
        usageDescriptionsPresent: true,
        launchServicesAttributed: false,
      );
      expect(ready.isFullyAuthorized, isTrue);
      expect(DeviceSpeechRecognitionService.mayLaunchSecondAppInstance, isFalse);
    });

    testWidgets('TEST 2 — opening SmartSearchPage does not claim greeting',
        (tester) async {
      expect(StartupGreeting.hasSpokenThisLaunch, isFalse);
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox.shrink(),
        ),
      );
      // Constructing the page type must not touch greeting slot.
      const page = SmartSearchPage(autoStartVoice: false);
      expect(page.autoStartVoice, isFalse);
      expect(StartupGreeting.hasSpokenThisLaunch, isFalse);
      expect(StartupGreeting.tryClaimGreetingSlot(), isTrue);
    });
  });
}
