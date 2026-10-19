// Phase 5D — اسم التطبيق «منصة الغدير» بكل النصوص اللي يشوفها المستخدم.
// «عيادة الغدير» هي عيادة الأشعة نفسها (جهة وحدة على المنصة)، مو اسم التطبيق.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ماكو نص ظاهر «عيادة الغدير» بالواجهة', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//')) continue;
        if (line.contains('عيادة الغدير')) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });

  test('اسم الويب ووصف المايك بالآيفون', () {
    expect(
      File('web/manifest.json').readAsStringSync(),
      contains('منصة الغدير'),
    );
    expect(
      File('web/index.html').readAsStringSync(),
      isNot(contains('عيادة الغدير')),
    );
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      isNot(contains('عيادة الغدير')),
    );
  });

  test('شاشة الافتتاح بلون الغدير وبيها الشعار', () {
    final bg = File('android/app/src/main/res/drawable/launch_background.xml')
        .readAsStringSync();
    expect(bg, contains('@drawable/splash_logo'));
    expect(bg, contains('@color/ghadeer_splash_bg'));
    expect(
      File('android/app/src/main/res/drawable-xxhdpi/splash_logo.png')
          .existsSync(),
      isTrue,
    );
    expect(
      File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync(),
      isNot(contains('red="1" green="1" blue="1"')),
    );
  });
}
