import 'package:flutter_test/flutter_test.dart';

import 'package:ghadeer_clinic/labs/lab_package_order_message.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';

void main() {
  test('LabPackageOrderMessage يتضمن اسم الباقة والتحاليل', () {
    const pkg = LabPackageItem(
      id: 'p1',
      labId: 'l1',
      name: 'باقة السكري',
      description: 'فحص شامل للسكر',
      newPrice: 45000,
      oldPrice: 60000,
      analyses: [
        AnalysisItem(id: 'a1', name: 'FBS', nameAr: 'سكر صائم'),
        AnalysisItem(id: 'a2', name: 'HbA1c', nameAr: 'تراكمي'),
      ],
    );

    final msg = LabPackageOrderMessage.build(
      labName: 'مختبر الغدير',
      package: pkg,
    );

    expect(msg, contains('طلب من منصة الغدير'));
    expect(msg, contains('مختبر الغدير'));
    expect(msg, contains('باقة السكري'));
    expect(msg, contains('سكر صائم'));
    expect(msg, contains('45,000'));
  });
}
