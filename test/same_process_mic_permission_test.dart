import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/voice/speech_recognition_service.dart';
import 'package:ghadeer_clinic/voice/startup_greeting.dart';
import 'package:ghadeer_clinic/search/smart_search_page.dart';

void main() {
  setUp(() {
    StartupGreeting.resetForTest();
  });

  group('CRITICAL FIX 3 — same-process microphone (no second app)', () {
    test('mayLaunchSecondAppInstance is permanently false', () {
      expect(DeviceSpeechRecognitionService.mayLaunchSecondAppInstance, isFalse);
    });

    test('openStandaloneForMicGrant is hard no-op (never true)', () async {
      // ignore: deprecated_member_use_from_same_package
      final opened =
          await DeviceSpeechRecognitionService.openStandaloneForMicGrant();
      expect(opened, isFalse);
      // ignore: deprecated_member_use_from_same_package
      final again =
          await DeviceSpeechRecognitionService.openStandaloneForMicGrant();
      expect(again, isFalse);
    });

    test('denied/restricted ready state uses permission message path', () {
      const denied = MacosSpeechReadyState(
        canInitializeSafely: true,
        speech: 'denied',
        microphone: 'authorized',
        usageDescriptionsPresent: true,
        launchServicesAttributed: false,
      );
      expect(denied.isDeniedOrRestricted, isTrue);
      expect(denied.isFullyAuthorized, isFalse);
      expect(
        DeviceSpeechRecognitionService.enablePermissionMessage,
        contains('إعدادات النظام'),
      );
      expect(
        DeviceSpeechRecognitionService.enablePermissionMessage,
        isNot(contains('نافذة مستقلة')),
      );
    });

    test('notDetermined is not treated as authorization', () {
      const pending = MacosSpeechReadyState(
        canInitializeSafely: true,
        speech: 'notDetermined',
        microphone: 'notDetermined',
        usageDescriptionsPresent: true,
        launchServicesAttributed: false,
      );
      expect(pending.isNotDetermined, isTrue);
      expect(pending.isFullyAuthorized, isFalse);
      expect(pending.isDeniedOrRestricted, isFalse);
    });

    test('fully authorized implies in-process listen', () {
      const ready = MacosSpeechReadyState(
        canInitializeSafely: true,
        speech: 'authorized',
        microphone: 'authorized',
        usageDescriptionsPresent: true,
        launchServicesAttributed: false,
        pid: 4242,
      );
      expect(ready.isFullyAuthorized, isTrue);
      expect(ready.pid, 4242);
      expect(DeviceSpeechRecognitionService.mayLaunchSecondAppInstance, isFalse);
    });

    test('dev-host blocked message never offers second-app launch', () {
      expect(
        DeviceSpeechRecognitionService.macosDevHostBlockedMessage,
        contains('بيئة التطوير'),
      );
      expect(
        DeviceSpeechRecognitionService.macosDevHostBlockedMessage,
        isNot(contains('نافذة مستقلة')),
      );
      expect(
        DeviceSpeechRecognitionService.macosDevHostBlockedMessage,
        isNot(contains('نسخة ثانية')),
      );
      const unsafe = MacosSpeechReadyState(
        canInitializeSafely: false,
        speech: 'notDetermined',
        microphone: 'notDetermined',
        usageDescriptionsPresent: true,
        launchServicesAttributed: false,
      );
      expect(unsafe.canInitializeSafely, isFalse);
      expect(unsafe.launchServicesAttributed, isFalse);
    });

    test('unknown error state does not authorize second-app launch', () {
      const unknown = MacosSpeechReadyState(
        canInitializeSafely: false,
        speech: 'unknown',
        microphone: 'unknown',
        usageDescriptionsPresent: false,
        launchServicesAttributed: false,
      );
      expect(unknown.isFullyAuthorized, isFalse);
      expect(DeviceSpeechRecognitionService.mayLaunchSecondAppInstance, isFalse);
    });

    test('legacy standalone claim APIs are inert', () {
      // ignore: deprecated_member_use_from_same_package
      expect(
        DeviceSpeechRecognitionService.tryClaimStandaloneGrantAttemptForTest(),
        isFalse,
      );
      // ignore: deprecated_member_use_from_same_package
      expect(
        DeviceSpeechRecognitionService.standaloneGrantAttemptedThisProcess,
        isFalse,
      );
      // ignore: deprecated_member_use_from_same_package
      DeviceSpeechRecognitionService.resetStandaloneGrantAttemptForTest();
    });

    test('autoStartVoice remains a page flag only (no app relaunch)', () {
      const page = SmartSearchPage(autoStartVoice: true);
      expect(page.autoStartVoice, isTrue);
      expect(DeviceSpeechRecognitionService.mayLaunchSecondAppInstance, isFalse);
    });

    test('startup greeting still once-per-process claim', () {
      expect(StartupGreeting.tryClaimGreetingSlot(), isTrue);
      expect(StartupGreeting.tryClaimGreetingSlot(), isFalse);
    });

    test('permission message never mentions opening Ghadeer window', () {
      final msg = DeviceSpeechRecognitionService.enablePermissionMessage;
      expect(msg.toLowerCase(), isNot(contains('مستقلة')));
      expect(msg.toLowerCase(), isNot(contains('standalone')));
      expect(msg, contains('الميكروفون'));
      expect(msg, contains('التعرف على الكلام'));
    });
  });
}
