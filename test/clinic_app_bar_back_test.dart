import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/widgets/clinic_app_bar.dart';

void main() {
  testWidgets('الرجوع أعلى اليمين في RTL ويُبقي الصفحة السابقة', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (context) => Scaffold(
              appBar: const ClinicAppBar(title: Text('الرئيسية')),
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          appBar: ClinicAppBar(title: Text('داخلية')),
                          body: Center(child: Text('محتوى داخلي')),
                        ),
                      ),
                    );
                  },
                  child: const Text('افتح'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('clinic_app_bar_back')), findsNothing);

    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    expect(find.text('داخلية'), findsOneWidget);

    final back = find.byKey(const Key('clinic_app_bar_back'));
    expect(back, findsOneWidget);
    final backCenter = tester.getCenter(back);
    final titleCenter = tester.getCenter(find.text('داخلية'));
    expect(backCenter.dx, greaterThan(titleCenter.dx));

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('داخلية'), findsNothing);
  });
}
