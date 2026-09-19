/// تركيز حقل الكتابة في محادثة Smart Brain — UI/UX فقط.
///
/// يثبت: نص → إرسال → الحقل جاهز فوراً للرسالة التالية،
/// بلا إنشاء TextField أو FocusNode إضافي وبلا مساس بمنطق الدماغ.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/conversation/smart_brain_chat_widgets.dart';

void main() {
  group('composer keeps typing focus across turns', () {
    testWidgets('Enter (TextInputAction.send) does not dismiss focus',
        (tester) async {
      final harness = await _pumpComposer(tester);

      await tester.tap(harness.field);
      await tester.pump();
      await tester.enterText(harness.field, 'دكتور علي ناصر السعيدي');
      await tester.pump();
      expect(harness.focus.hasFocus, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(harness.submits, 1, reason: 'الإرسال بـ Enter ما زال يعمل');
      expect(
        harness.focus.hasFocus,
        isTrue,
        reason: 'الحقل يبقى جاهزاً للرسالة التالية بلا نقرة إضافية',
      );

      // الرسالة التالية تُكتب فوراً بلا إعادة نقر على الحقل.
      await tester.enterText(harness.field, 'اتصل');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(harness.submits, 2);
      expect(harness.focus.hasFocus, isTrue);
    });

    testWidgets('Enter keeps focus on desktop platform too', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final harness = await _pumpComposer(tester);

      await tester.tap(harness.field);
      await tester.pump();
      await tester.enterText(harness.field, 'دكتور علي ناصر السعيدي');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(harness.submits, 1);
      expect(harness.focus.hasFocus, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('send button still submits and keeps a single FocusNode',
        (tester) async {
      final harness = await _pumpComposer(tester);

      await tester.tap(harness.field);
      await tester.pump();
      await tester.enterText(harness.field, 'دكتور علي ناصر السعيدي');
      await tester.pump();

      await tester.tap(find.byKey(const Key('smart_brain_send')));
      await tester.pumpAndSettle();

      expect(harness.submits, 1);
      // حقل واحد فقط ولا إدخال محادثة ثانٍ.
      expect(find.byType(TextField), findsOneWidget);
      final field = tester.widget<TextField>(harness.field);
      expect(field.focusNode, same(harness.focus));
    });

    testWidgets('disposing the page while focused throws no focus exception',
        (tester) async {
      final harness = await _pumpComposer(tester);
      await tester.tap(harness.field);
      await tester.pump();
      expect(harness.focus.hasFocus, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('page-level focus restoration guards', () {
    test('typed send restores the existing FocusNode under safe guards', () {
      final page = File('lib/search/smart_search_page.dart').readAsStringSync();

      // يستخدم FocusNode الموجود نفسه — بلا FocusNode جديد.
      expect(page.contains('final _fieldFocus = FocusNode();'), isTrue);
      expect(
        RegExp('FocusNode\\(\\)').allMatches(page).length,
        1,
        reason: 'FocusNode واحد فقط في الصفحة',
      );
      expect(page.contains('_fieldFocus.requestFocus();'), isTrue);
      expect(page.contains('_restoreComposerFocusAfterTypedSend();'), isTrue);

      // مسار النص فقط، وبعد اكتمال دورة الإرسال.
      expect(
        page.contains(
          'await _runSearch(text, source: QueryInputSource.typed);\n'
          '    if (_externalContactLaunches != launchesBefore) return;\n'
          '    _restoreComposerFocusAfterTypedSend();',
        ),
        isTrue,
      );

      // استثناءات إلزامية: mounted / صوت / مايك / تنقّل / route / تركيز قائم.
      expect(page.contains('if (!mounted || !_restoresComposerFocusOnSend) return;'),
          isTrue);
      expect(
        page.contains('if (_listening || _voiceSessionActive || _voiceBusy) return;'),
        isTrue,
      );
      expect(
        page.contains(
          'if (_navigating || ModalRoute.of(context)?.isCurrent == false) return;',
        ),
        isTrue,
      );
      expect(page.contains('if (_fieldFocus.hasFocus) return;'), isTrue);

      // اتصال/واتساب خارجي يمنع سحب التركيز.
      expect(page.contains('_externalContactLaunches++;'), isTrue);
      expect(
        RegExp('_externalContactLaunches\\+\\+;').allMatches(page).length,
        2,
        reason: 'call + whatsapp',
      );

      // بلا تأخير اصطناعي لإخفاء المشكلة.
      expect(page.contains('Future.delayed'), isFalse);

      // منطق الدماغ لم يتغير في مسار الإرسال.
      expect(page.contains('await _brainPlanner.plan('), isTrue);
      expect(page.contains('context: _conversation'), isTrue);
    });

    test('composer overrides default Enter unfocus only', () {
      final composer =
          File('lib/search/conversation/smart_brain_chat_widgets.dart')
              .readAsStringSync();
      expect(composer.contains('onEditingComplete: controller.clearComposing'),
          isTrue);
      expect(composer.contains('onSubmitted: (_) => onSubmit(),'), isTrue);
      expect(composer.contains('textInputAction: TextInputAction.send'), isTrue);
      // حقل واحد ولا FocusNode داخلي.
      expect(RegExp('TextField\\(').allMatches(composer).length, 1);
      expect(composer.contains('FocusNode('), isFalse);
      expect(composer.contains('unfocus()'), isFalse);
    });
  });
}

class _ComposerHarness {
  _ComposerHarness({required this.focus, required this.field});

  final FocusNode focus;
  final Finder field;
  int submits = 0;
}

Future<_ComposerHarness> _pumpComposer(WidgetTester tester) async {
  final controller = TextEditingController();
  final focus = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focus.dispose);

  final harness = _ComposerHarness(
    focus: focus,
    field: find.byKey(const Key('smart_brain_composer_field')),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              SmartBrainComposerBar(
                controller: controller,
                focusNode: focus,
                onSubmit: () {
                  harness.submits++;
                  controller.clear();
                },
                onToggleVoice: () {},
                loading: false,
                voiceBusy: false,
                listening: false,
                voiceSessionActive: false,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return harness;
}
