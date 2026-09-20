// Phase 4A — رسالة واتساب التلقائية: قالب قابل للتعديل من الإعدادات.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/settings/settings_page.dart';
import 'package:ghadeer_clinic/settings/whatsapp_message_settings.dart';
import 'package:ghadeer_clinic/settings/whatsapp_message_settings_page.dart';
import 'package:ghadeer_clinic/utils/clinic_contact_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _defaultText = 'السلام عليكم 🌿\n'
    'أني {اسم} — أتواصل وياكم من تطبيق الغدير\n'
    'أريد أستفسر عن موعد عند {طبيب}\n'
    'الله يعطيكم العافية 🙏';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClinicContactMessage.render — القالب الافتراضي', () {
    test('الافتراضي حرفيًا كما اعتُمد', () {
      expect(ClinicContactMessage.defaultTemplate, _defaultText);
    });

    test('طبيب + اسم: استبدال المتغيّرين وبادئة «د.»', () {
      expect(
        ClinicContactMessage.whatsAppPrefill(
          patientFullName: 'محمد عبد الحسن',
          providerTitle: 'ناجي السعيدي',
        ),
        'السلام عليكم 🌿\n'
        'أني محمد عبد الحسن — أتواصل وياكم من تطبيق الغدير\n'
        'أريد أستفسر عن موعد عند د. ناجي السعيدي\n'
        'الله يعطيكم العافية 🙏',
      );
    });

    test('بدون اسم: يُحذف «أني {اسم} —» ويبقى التعريف بالتطبيق', () {
      final msg = ClinicContactMessage.whatsAppPrefill(
        providerTitle: 'د. ناجي السعيدي',
      );
      expect(
        msg,
        'السلام عليكم 🌿\n'
        'أتواصل وياكم من تطبيق الغدير\n'
        'أريد أستفسر عن موعد عند د. ناجي السعيدي\n'
        'الله يعطيكم العافية 🙏',
      );
    });

    test('اسم غير صالح (رقم/بريد/placeholder) يعامل كغائب', () {
      for (final bad in const ['07701234567', 'a@b.com', 'guest', 'null']) {
        final msg = ClinicContactMessage.whatsAppPrefill(
          patientFullName: bad,
          providerTitle: 'د. علي',
        );
        expect(msg, isNot(contains('أني')), reason: bad);
        expect(msg, contains('أتواصل وياكم من تطبيق الغدير'), reason: bad);
      }
    });

    test('بادئة «د.» تُضاف عند غيابها ولا تُقتطع أحرف الاسم', () {
      String at(String title) =>
          ClinicContactMessage.whatsAppPrefill(providerTitle: title);
      expect(at('ناجي السعيدي'), contains('عند د. ناجي السعيدي\n'));
      expect(at('دينا حسن'), contains('عند د. دينا حسن\n'));
      expect(at('د. ناجي السعيدي'), contains('عند د. ناجي السعيدي\n'));
      expect(at('دكتورة ميعاد'), contains('عند دكتورة ميعاد\n'));
      expect(at('الدكتور علي'), contains('عند الدكتور علي\n'));
    });

    test('مختبر/مركز: {طبيب} = الاسم كما هو بلا «د.»', () {
      final msg = ClinicContactMessage.whatsAppPrefill(
        patientFullName: 'محمد',
        providerTitle: 'مختبر الحياة',
        providerIsDoctor: false,
      );
      expect(msg, contains('أريد أستفسر عن موعد عند مختبر الحياة\n'));
      expect(msg, isNot(contains('د. مختبر')));
    });

    test('بلا اسم جهة: يُحذف سطر {طبيب}', () {
      final msg = ClinicContactMessage.whatsAppPrefill(
        patientFullName: 'محمد',
      );
      expect(msg, isNot(contains('{طبيب}')));
      expect(msg, isNot(contains('موعد')));
      expect(msg, contains('أني محمد'));
    });

    test('لا عمر ولا جنس ولا بيانات سريرية', () {
      final msg = ClinicContactMessage.whatsAppPrefill(
        patientFullName: 'محمد',
        providerTitle: 'د. علي',
      );
      for (final w in const ['عمر', 'ذكر', 'أنثى', 'male', 'sex']) {
        expect(msg, isNot(contains(w)), reason: w);
      }
    });
  });

  group('ClinicContactMessage.render — قوالب مخصّصة', () {
    test('قالب مخصّص يُستبدل فيه المتغيّران', () {
      expect(
        ClinicContactMessage.render(
          template: 'مرحبا، معكم {اسم}.\nأريد موعد عند {طبيب}.',
          patientFullName: 'سارة',
          providerTitle: 'ميعاد',
        ),
        'مرحبا، معكم سارة.\nأريد موعد عند د. ميعاد.',
      );
    });

    test('سطر {اسم} بلا فاصل: يُحذف كله عند غياب الاسم', () {
      expect(
        ClinicContactMessage.render(
          template: 'معكم {اسم}\nموعد عند {طبيب}',
          providerTitle: 'علي',
        ),
        'موعد عند د. علي',
      );
    });

    test('متغيّر غير معروف يبقى كما كتبه المستخدم', () {
      expect(
        ClinicContactMessage.render(
          template: 'أهلًا {شيء} عند {طبيب}',
          providerTitle: 'علي',
        ),
        'أهلًا {شيء} عند د. علي',
      );
    });

    test('قالب فارغ = الافتراضي', () {
      expect(
        ClinicContactMessage.render(
          template: '   ',
          patientFullName: 'محمد',
          providerTitle: 'علي',
        ),
        ClinicContactMessage.render(
          patientFullName: 'محمد',
          providerTitle: 'علي',
        ),
      );
    });
  });

  group('WhatsAppMessageSettingsService — shared_preferences', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('غير محفوظ → الافتراضي', () async {
      final s = WhatsAppMessageSettingsService();
      expect(await s.loadTemplate(), _defaultText);
      expect(await s.hasCustomTemplate(), isFalse);
    });

    test('حفظ ثم تحميل', () async {
      final s = WhatsAppMessageSettingsService();
      expect(await s.saveTemplate('أهلًا، موعد عند {طبيب}'), isTrue);
      expect(await s.loadTemplate(), 'أهلًا، موعد عند {طبيب}');
      expect(await s.hasCustomTemplate(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('whatsapp_message_template'),
          'أهلًا، موعد عند {طبيب}');
    });

    test('إرجاع للافتراضي يحذف المفتاح', () async {
      final s = WhatsAppMessageSettingsService();
      await s.saveTemplate('نص مخصّص {طبيب}');
      await s.resetTemplate();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('whatsapp_message_template'), isFalse);
      expect(await s.loadTemplate(), _defaultText);
    });

    test('فارغ أو مطابق للافتراضي لا يُخزَّن', () async {
      final s = WhatsAppMessageSettingsService();
      await s.saveTemplate('نص {طبيب}');
      expect(await s.saveTemplate('  '), isTrue);
      expect(await s.hasCustomTemplate(), isFalse);
      await s.saveTemplate('نص {طبيب}');
      expect(await s.saveTemplate(_defaultText), isTrue);
      expect(await s.hasCustomTemplate(), isFalse);
    });

    test('أطول من الحد لا يُحفظ', () async {
      final s = WhatsAppMessageSettingsService();
      final tooLong = 'ا' * (WhatsAppMessageSettingsService.maxLength + 1);
      expect(await s.saveTemplate(tooLong), isFalse);
      expect(await s.hasCustomTemplate(), isFalse);
    });

    test('buildPrefill: القالب المحفوظ + اسم الـ onboarding من ملف الرفيق',
        () async {
      SharedPreferences.setMockInitialValues({});
      final s = WhatsAppMessageSettingsService();
      await s.saveTemplate('معكم {اسم}، موعد عند {طبيب}');
      final msg = await s.buildPrefill(providerTitle: 'علي');
      // بلا ملف محفوظ: لا اسم → يُحذف سطر {اسم} بلا فاصل.
      expect(msg, isNot(contains('{اسم}')));
      expect(msg, contains('موعد عند د. علي'));
    });
  });

  group('صفحة الإعدادات — رسالة الواتساب', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: WhatsAppMessageSettingsPage()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('تعرض الافتراضي ومعاينة بلا overflow على شاشة صغيرة',
        (tester) async {
      await pumpPage(tester);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('whatsapp_template_field')),
      );
      expect(field.controller!.text, _defaultText);
      expect(find.byKey(const ValueKey('whatsapp_template_preview')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('تعديل ثم حفظ يخزّن القالب؛ إرجاع للافتراضي يمسحه',
        (tester) async {
      await pumpPage(tester);
      await tester.enterText(
        find.byKey(const ValueKey('whatsapp_template_field')),
        'رسالتي {طبيب}',
      );
      await tester.pump();
      await tester.ensureVisible(
          find.byKey(const ValueKey('whatsapp_template_save')));
      await tester.tap(find.byKey(const ValueKey('whatsapp_template_save')));
      await tester.pumpAndSettle();
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('whatsapp_message_template'), 'رسالتي {طبيب}');

      // رسالة الحفظ (SnackBar) تغطي أسفل الشاشة الصغيرة حتى تختفي.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
          find.byKey(const ValueKey('whatsapp_template_reset')));
      await tester.tap(find.byKey(const ValueKey('whatsapp_template_reset')));
      await tester.pumpAndSettle();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('whatsapp_message_template'), isFalse);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('whatsapp_template_field')),
      );
      expect(field.controller!.text, _defaultText);
    });

    testWidgets('زر إدراج المتغيّر يضيفه للنص', (tester) async {
      await pumpPage(tester);
      final fieldFinder =
          find.byKey(const ValueKey('whatsapp_template_field'));
      await tester.enterText(fieldFinder, 'أ');
      await tester.pump();
      await tester.ensureVisible(
          find.byKey(const ValueKey('insert_provider_variable')));
      await tester
          .tap(find.byKey(const ValueKey('insert_provider_variable')));
      await tester.pump();
      final field = tester.widget<TextField>(fieldFinder);
      expect(field.controller!.text, contains('{طبيب}'));
    });
  });

  group('SettingsPage — البطاقة موجودة', () {
    testWidgets('بطاقة «رسالة الواتساب» تفتح الصفحة', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('رسالة الواتساب'));
      await tester.tap(find.text('رسالة الواتساب'));
      await tester.pumpAndSettle();
      expect(find.byType(WhatsAppMessageSettingsPage), findsOneWidget);
    });
  });
}
