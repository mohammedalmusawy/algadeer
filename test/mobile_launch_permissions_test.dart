import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// أزرار الاتصال/واتساب في الصيدليات والعلاج الطبيعي والمستلزمات تستدعي
/// canLaunchUrl، وهذا يرجع false على Android 11+ و iOS إن لم تُصرَّح الروابط.
void main() {
  test('Android manifest declares tel/https/whatsapp/speech queries', () {
    final xml = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final scheme in ['tel', 'https', 'http', 'whatsapp', 'geo']) {
      expect(xml, contains('android:scheme="$scheme"'), reason: scheme);
    }
    expect(xml, contains('android.intent.action.DIAL'));
    expect(xml, contains('android.speech.RecognitionService'));
  });

  test('iOS Info.plist declares query schemes and photo/camera usage', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('LSApplicationQueriesSchemes'));
    for (final scheme in ['tel', 'https', 'whatsapp']) {
      expect(plist, contains('<string>$scheme</string>'), reason: scheme);
    }
    // image_picker يُغلق التطبيق على iOS بدون هذين المفتاحين.
    expect(plist, contains('NSCameraUsageDescription'));
    expect(plist, contains('NSPhotoLibraryUsageDescription'));
    expect(plist, contains('NSMicrophoneUsageDescription'));
  });
}
