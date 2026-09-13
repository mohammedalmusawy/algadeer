import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/utils/responsive.dart';

void main() {
  testWidgets('wide scaffold body keeps non-zero scroll height', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1400, 900);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: 0,
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) {
                          final pad = AppResponsive.pagePadding(context);
                          return Padding(
                            padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
                            child: const Text('الغدير'),
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) {
                          final cols = AppResponsive.doctorColumns(context);
                          const gap = 12.0;
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final itemW =
                                  (constraints.maxWidth - gap * (cols - 1)) /
                                      cols;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  for (var i = 0; i < 4; i++)
                                    SizedBox(
                                      width: itemW,
                                      height: 80,
                                      child: Text('card-$i'),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          bottomNavigationBar: const SizedBox(height: 56, child: Text('nav')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('الغدير'), findsOneWidget);
    final size = tester.getSize(find.text('الغدير'));
    expect(size.height, greaterThan(0));
    expect(find.text('card-0'), findsOneWidget);
    expect(tester.getSize(find.text('card-0')).height, greaterThan(0));
  });
}
