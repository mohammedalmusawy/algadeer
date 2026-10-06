import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_package_form_page.dart';

String? _textOf(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) return null;
  final field = tester.widget<TextField>(finder);
  return field.controller?.text;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('اختيار اقتراح ثم الإلغاء لا يرجع باقة', (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    PharmacyBundle? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                saved = await Navigator.push<PharmacyBundle?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PharmacyPackageFormPage(
                      pharmacyId: 'p1',
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final suggestion = find.byKey(const ValueKey('template-bone_ca_d_k'));
    await tester.ensureVisible(suggestion);
    await tester.pumpAndSettle();
    await tester.tap(suggestion);
    await tester.pumpAndSettle();

    expect(_textOf(tester, const ValueKey('product-sug_bone_ca_d_k_mineral_calcium')), 'الكالسيوم');
    expect(_textOf(tester, const ValueKey('product-sug_bone_ca_d_k_vitamin_d')), 'فيتامين د');
    expect(_textOf(tester, const ValueKey('product-sug_bone_ca_d_k_vitamin_k')), 'فيتامين ك');
    expect(find.byKey(const ValueKey('product-sug_bone_ca_d_k_vitamin_a')), findsNothing);
    expect(find.text('بحث مكوّن'), findsNothing);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'إلغاء'));
    await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إلغاء'));
    await tester.pumpAndSettle();

    expect(saved, isNull);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('حفظ الباقة يرجع المسودة المعدّلة فقط', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    PharmacyBundle? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                saved = await Navigator.push<PharmacyBundle?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PharmacyPackageFormPage(
                      pharmacyId: 'p1',
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final suggestion = find.byKey(const ValueKey('template-bone_ca_d_k'));
    await tester.ensureVisible(suggestion);
    await tester.tap(suggestion);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('حذف العنصر').first);
    await tester.pumpAndSettle();

    final price = find.ancestor(
      of: find.text('السعر (د.ع)'),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(price);
    await tester.enterText(price, '15000');
    await tester.ensureVisible(find.text('حفظ الباقة'));
    await tester.tap(find.text('حفظ الباقة'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.title, 'عظام: كالسيوم + د + ك');
    expect(saved!.price, 15000);
    expect(saved!.templateId, 'bone_ca_d_k');
    expect(saved!.products.length, 2);
    expect(saved!.products.every((p) => p.strength.isEmpty && p.instructions.isEmpty), isTrue);
    expect(saved!.description, isEmpty);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('إعادة فتح باقة محفوظة تعرض عناصرها', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    const saved = PharmacyBundle(
      id: 'b1',
      title: 'باقتي',
      price: 9000,
      oldPrice: 0,
      description: 'وصف الصيدلي',
      templateId: 'bone_ca_d_k',
      products: [
        PharmacyPackageProduct(
          id: 'x',
          name: 'عنصر محفوظ',
          instructions: 'بدون جرعة',
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: PharmacyPackageFormPage(
          pharmacyId: 'p1',
          initial: saved,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_textOf(tester, const ValueKey('package-title')), 'باقتي');
    expect(_textOf(tester, const ValueKey('product-x')), 'عنصر محفوظ');
    expect(find.text('اعتماد المقترحات كما هي'), findsOneWidget);
    expect(find.byKey(const ValueKey('template-bone_ca_d_k')), findsNothing);
  });
}
