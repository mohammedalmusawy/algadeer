import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<double> pumpAndReadBodyHeight(
    WidgetTester tester, {
    required Widget bottomNavigationBar,
  }) async {
    final view = tester.view;
    view.physicalSize = const Size(1400, 900);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    double? bodyH;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                bodyH = constraints.maxHeight;
                return ColoredBox(
                  color: Colors.red,
                  child: Center(child: Text('h=${constraints.maxHeight}')),
                );
              },
            ),
          ),
          bottomNavigationBar: bottomNavigationBar,
        ),
      ),
    );
    await tester.pump();
    return bodyH ?? -1;
  }

  testWidgets('Row bottom nav leaves body usable height', (tester) async {
    final h = await pumpAndReadBodyHeight(
      tester,
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Row(
            children: List.generate(
              4,
              (i) => const Expanded(
                child: SizedBox(height: 56, child: Icon(Icons.home)),
              ),
            ),
          ),
        ),
      ),
    );
    expect(h, greaterThan(500));
  });

  testWidgets('Center in bottom nav collapses body height', (tester) async {
    final h = await pumpAndReadBodyHeight(
      tester,
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Row(
                children: List.generate(
                  4,
                  (i) => const Expanded(
                    child: SizedBox(height: 56, child: Icon(Icons.home)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // إذا كان Center يتمدد، ارتفاع الجسم ينهار.
    expect(h, lessThan(100));
  });
}
