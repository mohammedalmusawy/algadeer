import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('الإدارة والمالك يستخدمان PharmacyBundlesManagePage للباقات', () {
    final admin = File('lib/pharmacies/pharmacies_admin_page.dart').readAsStringSync();
    final owner =
        File('lib/pharmacies/pharmacy_owner_editor_page.dart').readAsStringSync();
    final manage =
        File('lib/pharmacies/pharmacy_bundles_manage_page.dart').readAsStringSync();

    expect(admin.contains('PharmacyBundlesManagePage'), isTrue);
    expect(admin.contains('_BundleEditors'), isFalse);
    expect(admin.contains('_bundleCard'), isFalse);
    expect(admin.contains("'الباقات"), isTrue);
    expect(admin.contains('فتح محرّر الباقات'), isFalse);
    expect(admin.contains('الباقات والمنتجات'), isFalse);
    expect(admin.contains('_BundleEditors'), isFalse);

    expect(owner.contains('PharmacyBundlesManagePage'), isTrue);
    expect(owner.contains("const Text('الباقات')"), isTrue);
    expect(owner.contains('الباقات والمنتجات والأسعار'), isFalse);

    expect(manage.contains('PharmacyPackageFormPage'), isTrue);
    expect(manage.contains('إضافة باقة'), isTrue);
  });
}
