import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// BUG-01: doctors / labs / lab_packages have no `name` column.
/// Real columns: doctors.doctor_name, labs.lab_name, lab_packages.package_name.
/// Explicit column lists / filters that mention `name` make PostgREST fail with
/// "column ... does not exist", so these queries must not reference it.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('BUG-01 no non-existent name column in Supabase queries', () {
    test('app_stats_service uses real columns for trending queries', () {
      final src = read('lib/services/app_stats_service.dart');
      expect(src, contains('name:doctor_name'));
      expect(src, isNot(contains("'id, name, specialty")));
      expect(src, isNot(contains('lab_name, name, address')));
      expect(src, isNot(contains('package_name, name,')));
      expect(src, isNot(contains('labs(lab_name, name)')));
      expect(src, contains('labs(lab_name)'));
    });

    test('fetchPackagesLite selects/orders by package_name (alias name)', () {
      final src = read('lib/doctors/notifications_admin_service.dart');
      expect(src, contains('name:package_name'));
      expect(src, isNot(contains("select('id, name, lab_id")));
      expect(src, isNot(contains(".order('name')")));
      expect(src, contains(".order('package_name')"));
    });

    test('smart search lab/package or() filters skip name.ilike', () {
      final src = read('lib/search/smart_search_service.dart');
      expect(
        src,
        contains(
          "lab_name.ilike.\$pattern,address.ilike.\$pattern",
        ),
      );
      expect(
        src,
        contains(
          "package_name.ilike.\$pattern,description.ilike.\$pattern",
        ),
      );
      expect(src, isNot(contains('lab_name.ilike.\$pattern,name.ilike')));
      expect(src, isNot(contains('package_name.ilike.\$pattern,name.ilike')));
    });
  });
}
