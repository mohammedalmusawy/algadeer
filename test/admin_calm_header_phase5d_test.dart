// Phase 5D — رؤوس صفحات الإدارة صارت هادية (ضبابي + حبر) مثل باقي التطبيق.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _appBar = RegExp(r'appBar:\s*(ClinicAppBar|AppBar)\(');

/// يرجّع نص كل appBar(...) بالملف.
List<String> _appBarBlocks(String s) {
  final out = <String>[];
  for (final m in _appBar.allMatches(s)) {
    var i = m.end;
    var depth = 1;
    while (depth > 0 && i < s.length) {
      final c = s[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      i++;
    }
    out.add(s.substring(m.start, i));
  }
  return out;
}

void main() {
  test('ماكو رأس إدارة فيروزي بكتابة بيضاء', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.path.contains('admin') || f.path.endsWith('main.dart'));
    final offenders = <String>[];
    for (final f in files) {
      for (final block in _appBarBlocks(f.readAsStringSync())) {
        if (block.contains('foregroundColor: Colors.white')) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
