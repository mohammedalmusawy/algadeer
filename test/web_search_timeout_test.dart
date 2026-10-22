import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/utils/web_timeout.dart';

// نسخة الويب: طلب أطباء معلّق على نت ضعيف كان يخلّي «الغدير يفكر» للأبد.
void main() {
  group('webTimed', () {
    test('web: a request that never answers fails after the limit', () {
      fakeAsync((async) {
        final never = Completer<List<int>>().future;
        Object? error;
        webTimed(never, isWeb: true).catchError((Object e) {
          error = e;
          return <int>[];
        });
        async.elapse(const Duration(seconds: 7));
        expect(error, isNull);
        async.elapse(const Duration(seconds: 2));
        expect(error, isA<TimeoutException>());
      });
    });

    test('web: a normal answer passes through', () async {
      final rows = await webTimed(Future.value([1, 2, 3]), isWeb: true);
      expect(rows, [1, 2, 3]);
    });

    test('mobile: the same request is returned untouched (no limit)', () {
      final never = Completer<int>().future;
      expect(identical(webTimed(never, isWeb: false), never), isTrue);
    });
  });
}
