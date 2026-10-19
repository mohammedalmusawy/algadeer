// Phase 5A — رسائل الواتساب من الإدارة (حجز/استفسار) + سؤال الاسم الثلاثي.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/centers/service_center_kind.dart';
import 'package:ghadeer_clinic/companion/local_personal_companion_profile_repository.dart';
import 'package:ghadeer_clinic/companion/personal_companion_profile_service.dart';
import 'package:ghadeer_clinic/settings/whatsapp_contact_flow.dart';
import 'package:ghadeer_clinic/settings/whatsapp_message_settings.dart';
import 'package:ghadeer_clinic/settings/whatsapp_templates.dart';
import 'package:ghadeer_clinic/utils/clinic_contact_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _booking =
    'السلام عليكم\n'
    'أنا {اسم}، أريد حجز عندكم\n'
    'حجز عن طريق منصة الغدير';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WhatsAppTemplateRepository.resetMemoryForTest();
  });

  group('النص الثابت الاحتياطي', () {
    test('حجز واستفسار بالصيغة المتفق عليها', () {
      expect(WhatsAppTemplateCatalog.builtInBooking.body, _booking);
      expect(
        WhatsAppTemplateCatalog.builtInInquiry.body,
        'السلام عليكم\n'
        'أنا {اسم}، أريد استفسار عندكم\n'
        'استفسار عن طريق منصة الغدير',
      );
    });

    test('الافتراضي: حجز للأطباء، واستفسار للصيدليات', () {
      const c = WhatsAppTemplateCatalog.builtIn;
      expect(c.templateFor(WhatsAppSection.doctors).key, 'booking');
      expect(c.templateFor(WhatsAppSection.radiology).key, 'booking');
      expect(c.templateFor(WhatsAppSection.pharmacies).key, 'inquiry');
      expect(c.templateFor(WhatsAppSection.optics).key, 'inquiry');
    });

    test('كل أقسام الدليل إلها قسم واتساب', () {
      for (final k in ServiceCenterKind.values) {
        expect(WhatsAppSection.fromServiceCenterKind(k).dbValue, k.dbValue);
      }
    });
  });

  group('العرض', () {
    test('مع الاسم الثلاثي', () {
      expect(
        ClinicContactMessage.render(
          template: _booking,
          patientFullName: 'محمد علي حسين',
        ),
        'السلام عليكم\n'
        'أنا محمد علي حسين، أريد حجز عندكم\n'
        'حجز عن طريق منصة الغدير',
      );
    });

    test('بدون اسم: يبقى «أريد حجز عندكم» بدون «أنا»', () {
      expect(
        ClinicContactMessage.render(template: _booking),
        'السلام عليكم\n'
        'أريد حجز عندكم\n'
        'حجز عن طريق منصة الغدير',
      );
    });

    test('{الجهة}: «د.» للطبيب واسم المكان كما هو', () {
      const t = 'أريد موعد عند {الجهة}';
      expect(
        ClinicContactMessage.render(template: t, providerTitle: 'علي ناصر'),
        'أريد موعد عند د. علي ناصر',
      );
      expect(
        ClinicContactMessage.render(
          template: t,
          providerTitle: 'صيدلية رحاب',
          providerIsDoctor: false,
        ),
        'أريد موعد عند صيدلية رحاب',
      );
    });
  });

  group('نماذج الإدارة', () {
    test('نص الإدارة والافتراضي يطغون على الثابت', () {
      final c = WhatsAppTemplateCatalog.fromRows(
        templateRows: [
          {'key': 'booking', 'title': 'حجز', 'body': 'نص حجز معدّل'},
          {'key': 'inquiry', 'title': 'استفسار', 'body': 'نص استفسار'},
        ],
        defaultRows: [
          {'section': 'doctors', 'template_key': 'inquiry'},
          {'section': 'unknown', 'template_key': 'booking'},
        ],
      );
      expect(c.templateFor(WhatsAppSection.doctors).body, 'نص استفسار');
      expect(c.templateFor(WhatsAppSection.labs).body, 'نص حجز معدّل');
    });

    test('نموذج مطفي أو افتراضي غلط يرجع لنموذج شغّال', () {
      final c = WhatsAppTemplateCatalog.fromRows(
        templateRows: [
          {'key': 'booking', 'title': 'حجز', 'body': 'حجز', 'is_active': false},
          {'key': 'inquiry', 'title': 'استفسار', 'body': 'استفسار'},
        ],
        defaultRows: [
          {'section': 'doctors', 'template_key': 'booking'},
        ],
      );
      expect(c.templateFor(WhatsAppSection.doctors).body, 'استفسار');
    });

    test('بدون نت وبدون نسخة محفوظة: النص الثابت', () async {
      final repo = WhatsAppTemplateRepository(
        fetchTemplates: () async => throw Exception('offline'),
        fetchDefaults: () async => throw Exception('offline'),
      );
      final c = await repo.load();
      expect(c.templateFor(WhatsAppSection.doctors).body, _booking);
    });

    test('بدون نت: آخر نسخة محفوظة بالجهاز', () async {
      var online = true;
      Future<List<Map<String, dynamic>>> templates() async {
        if (!online) throw Exception('offline');
        return [
          {'key': 'booking', 'title': 'حجز', 'body': 'نسخة السيرفر'},
        ];
      }

      final repo = WhatsAppTemplateRepository(
        fetchTemplates: templates,
        fetchDefaults: () async => [],
      );
      expect(
        (await repo.load()).templateFor(WhatsAppSection.doctors).body,
        'نسخة السيرفر',
      );
      online = false;
      WhatsAppTemplateRepository.resetMemoryForTest();
      expect(
        (await repo.load(forceRefresh: true))
            .templateFor(WhatsAppSection.doctors)
            .body,
        'نسخة السيرفر',
      );
    });
  });

  group('buildPrefill بالقسم', () {
    late PersonalCompanionProfileService profiles;

    setUp(() async {
      final prefs = await SharedPreferences.getInstance();
      profiles = PersonalCompanionProfileService(
        repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
      );
      await profiles.savePreferredName('محمد علي حسين');
    });

    final offlineRepo = WhatsAppTemplateRepository(
      fetchTemplates: () async => throw Exception('offline'),
      fetchDefaults: () async => throw Exception('offline'),
    );

    test('قسم الصيدليات = استفسار باسم المراجع', () async {
      final msg = await WhatsAppMessageSettingsService().buildPrefill(
        providerTitle: 'صيدلية رحاب',
        providerIsDoctor: false,
        profileService: profiles,
        section: WhatsAppSection.pharmacies,
        templates: offlineRepo,
      );
      expect(
        msg,
        'السلام عليكم\n'
        'أنا محمد علي حسين، أريد استفسار عندكم\n'
        'استفسار عن طريق منصة الغدير',
      );
    });

    test('قالب المستخدم الخاص يبقى مثل ما هو', () async {
      final settings = WhatsAppMessageSettingsService();
      await settings.saveTemplate('هلا، أنا {اسم}');
      final msg = await settings.buildPrefill(
        providerTitle: 'د. علي',
        profileService: profiles,
        section: WhatsAppSection.doctors,
        templates: offlineRepo,
      );
      expect(msg, 'هلا، أنا محمد علي حسين');
    });

    test('بدون قسم: السلوك القديم ما تغيّر', () async {
      final msg = await WhatsAppMessageSettingsService().buildPrefill(
        providerTitle: 'علي',
        profileService: profiles,
      );
      expect(msg, contains('أتواصل وياكم من تطبيق الغدير'));
    });
  });

  group('سؤال الاسم الثلاثي', () {
    Future<PersonalCompanionProfileService> freshProfiles() async {
      final prefs = await SharedPreferences.getInstance();
      return PersonalCompanionProfileService(
        repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
      );
    }

    Future<String?> Function()? runner;

    Widget harness(PersonalCompanionProfileService profiles) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              runner = () => WhatsAppNamePrompt.maybeAsk(
                context,
                profileService: profiles,
              );
              return const SizedBox.expand();
            },
          ),
        ),
      );
    }

    testWidgets('يحفظ الاسم المكتوب ويرجعه', (tester) async {
      final profiles = await freshProfiles();
      await tester.pumpWidget(harness(profiles));
      final future = runner!();
      await tester.pumpAndSettle();
      expect(find.text('اذكر اسمك الثلاثي'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const Key('whatsapp_name_field')),
        'محمد علي حسين',
      );
      await tester.tap(find.byKey(const Key('whatsapp_name_save')));
      await tester.pumpAndSettle();
      expect(await future, 'محمد علي حسين');
      expect(await profiles.preferredNameForPersonalization(), 'محمد علي حسين');
    });

    testWidgets('«تخطي» ما يحفظ شي، وما نسأل مرة ثانية', (tester) async {
      final profiles = await freshProfiles();
      await tester.pumpWidget(harness(profiles));
      final first = runner!();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('whatsapp_name_skip')));
      await tester.pumpAndSettle();
      expect(await first, isNull);
      expect(await profiles.preferredNameForPersonalization(), isNull);

      final second = runner!();
      await tester.pumpAndSettle();
      expect(find.text('اذكر اسمك الثلاثي'), findsNothing);
      expect(await second, isNull);
    });

    testWidgets('عنده اسم: ما نسأله', (tester) async {
      final profiles = await freshProfiles();
      await profiles.savePreferredName('زينب كاظم');
      await tester.pumpWidget(harness(profiles));
      final f = runner!();
      await tester.pumpAndSettle();
      expect(find.text('اذكر اسمك الثلاثي'), findsNothing);
      expect(await f, 'زينب كاظم');
    });
  });
}
