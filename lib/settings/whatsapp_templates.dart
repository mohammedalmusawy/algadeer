import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../centers/service_center_kind.dart';
import '../services/offline_rows_cache.dart';
import '../utils/clinic_contact_message.dart';

/// الأقسام اللي تفتح واتساب برسالة جاهزة. القيمة = عمود section بسوبربيس.
enum WhatsAppSection {
  doctors,
  labs,
  radiology,
  pharmacies,
  physio,
  supplies,
  optics,
  beauty,
  nursing;

  String get dbValue => name;

  String get arabicLabel => switch (this) {
    WhatsAppSection.doctors => 'الأطباء',
    WhatsAppSection.labs => 'المختبرات',
    WhatsAppSection.radiology => 'الأشعة',
    WhatsAppSection.pharmacies => 'الصيدليات',
    WhatsAppSection.physio => 'العلاج الطبيعي',
    WhatsAppSection.supplies => 'التجهيزات الطبية',
    WhatsAppSection.optics => 'العوينات',
    WhatsAppSection.beauty => 'التجميل',
    WhatsAppSection.nursing => 'التمريض المنزلي',
  };

  /// اسم الطبيب ينكتب «د. الاسم»، والباقي اسم المكان كما هو.
  bool get providerIsDoctor => this == WhatsAppSection.doctors;

  static WhatsAppSection fromServiceCenterKind(ServiceCenterKind kind) =>
      switch (kind) {
        ServiceCenterKind.optics => WhatsAppSection.optics,
        ServiceCenterKind.beauty => WhatsAppSection.beauty,
        ServiceCenterKind.nursing => WhatsAppSection.nursing,
      };

  static WhatsAppSection? fromDb(String? raw) {
    final v = (raw ?? '').trim();
    for (final s in WhatsAppSection.values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

/// نموذج رسالة واحد (حجز، استفسار، ...).
@immutable
class WhatsAppTemplate {
  const WhatsAppTemplate({
    required this.key,
    required this.title,
    required this.body,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String key;
  final String title;
  final String body;
  final int sortOrder;
  final bool isActive;

  static WhatsAppTemplate? fromRow(Map<String, dynamic> row) {
    final key = (row['key'] ?? '').toString().trim();
    final body = (row['body'] ?? '').toString();
    if (key.isEmpty || body.trim().isEmpty) return null;
    final title = (row['title'] ?? '').toString().trim();
    return WhatsAppTemplate(
      key: key,
      title: title.isEmpty ? key : title,
      body: body,
      sortOrder: int.tryParse('${row['sort_order'] ?? 0}') ?? 0,
      isActive: row['is_active'] != false && '${row['is_active']}' != 'false',
    );
  }
}

/// النماذج + الافتراضي لكل قسم، مع نص احتياطي ثابت إذا ما وصل شي.
@immutable
class WhatsAppTemplateCatalog {
  const WhatsAppTemplateCatalog({
    required this.templates,
    required this.sectionDefaults,
  });

  static const String bookingKey = 'booking';
  static const String inquiryKey = 'inquiry';

  static const WhatsAppTemplate builtInBooking = WhatsAppTemplate(
    key: bookingKey,
    title: 'حجز',
    body:
        'السلام عليكم\n'
        'أنا ${ClinicContactMessage.nameVariable}، أريد حجز عندكم\n'
        'حجز عن طريق منصة الغدير',
    sortOrder: 10,
  );

  static const WhatsAppTemplate builtInInquiry = WhatsAppTemplate(
    key: inquiryKey,
    title: 'استفسار',
    body:
        'السلام عليكم\n'
        'أنا ${ClinicContactMessage.nameVariable}، أريد استفسار عندكم\n'
        'استفسار عن طريق منصة الغدير',
    sortOrder: 20,
  );

  static const Map<WhatsAppSection, String> builtInDefaults = {
    WhatsAppSection.doctors: bookingKey,
    WhatsAppSection.radiology: bookingKey,
    WhatsAppSection.labs: bookingKey,
    WhatsAppSection.physio: bookingKey,
    WhatsAppSection.nursing: bookingKey,
    WhatsAppSection.pharmacies: inquiryKey,
    WhatsAppSection.supplies: inquiryKey,
    WhatsAppSection.optics: inquiryKey,
    WhatsAppSection.beauty: inquiryKey,
  };

  static const WhatsAppTemplateCatalog builtIn = WhatsAppTemplateCatalog(
    templates: [builtInBooking, builtInInquiry],
    sectionDefaults: builtInDefaults,
  );

  final List<WhatsAppTemplate> templates;
  final Map<WhatsAppSection, String> sectionDefaults;

  /// النماذج المفعّلة مرتبة.
  List<WhatsAppTemplate> get active {
    final list = templates.where((t) => t.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  WhatsAppTemplate? byKey(String? key) {
    if (key == null) return null;
    for (final t in templates) {
      if (t.key == key && t.isActive) return t;
    }
    return null;
  }

  /// نموذج القسم: الافتراضي اللي حددته الإدارة، وإلا الثابت للقسم،
  /// وإلا أول نموذج مفعّل، وإلا «حجز» الثابت.
  WhatsAppTemplate templateFor(WhatsAppSection section) {
    return byKey(sectionDefaults[section]) ??
        byKey(builtInDefaults[section]) ??
        (active.isNotEmpty ? active.first : null) ??
        (builtInDefaults[section] == inquiryKey
            ? builtInInquiry
            : builtInBooking);
  }

  /// يبني الكتالوج من صفوف سوبربيس؛ الناقص يُكمَّل من الثابت.
  static WhatsAppTemplateCatalog fromRows({
    required List<Map<String, dynamic>> templateRows,
    required List<Map<String, dynamic>> defaultRows,
  }) {
    final templates = <WhatsAppTemplate>[
      for (final r in templateRows) ?WhatsAppTemplate.fromRow(r),
    ];
    if (templates.isEmpty) return builtIn;
    final defaults = Map<WhatsAppSection, String>.of(builtInDefaults);
    for (final r in defaultRows) {
      final section = WhatsAppSection.fromDb(r['section']?.toString());
      final key = (r['template_key'] ?? '').toString().trim();
      if (section != null && key.isNotEmpty) defaults[section] = key;
    }
    return WhatsAppTemplateCatalog(
      templates: templates,
      sectionDefaults: defaults,
    );
  }
}

typedef WhatsAppRowsFetcher = Future<List<Map<String, dynamic>>> Function();

/// يجيب نماذج الإدارة من سوبربيس، ويحفظ آخر نسخة بالجهاز للشغل بدون إنترنت.
/// أي فشل = آخر نسخة محفوظة، وإذا ما أكو = النص الثابت. ما يرمي خطأ أبداً.
class WhatsAppTemplateRepository {
  WhatsAppTemplateRepository({
    WhatsAppRowsFetcher? fetchTemplates,
    WhatsAppRowsFetcher? fetchDefaults,
  }) : _fetchTemplates = fetchTemplates ?? _supabaseTemplates,
       _fetchDefaults = fetchDefaults ?? _supabaseDefaults;

  static const String templatesTable = 'whatsapp_message_templates';
  static const String defaultsTable = 'whatsapp_template_section_defaults';
  static const String templatesCacheKey = 'whatsapp_templates';
  static const String defaultsCacheKey = 'whatsapp_template_defaults';

  final WhatsAppRowsFetcher _fetchTemplates;
  final WhatsAppRowsFetcher _fetchDefaults;

  /// نسخة بالذاكرة لنفس التشغيل حتى ما نطلب الشبكة بكل ضغطة.
  static WhatsAppTemplateCatalog? _memory;
  static DateTime? _memoryAt;
  static const Duration memoryTtl = Duration(minutes: 10);

  @visibleForTesting
  static void resetMemoryForTest() {
    _memory = null;
    _memoryAt = null;
  }

  /// يمسح النسخة بالذاكرة (بعد ما الإدارة تحفظ تعديل).
  static void invalidate() => resetMemoryForTest();

  static Future<List<Map<String, dynamic>>> _supabaseTemplates() async {
    final rows = await Supabase.instance.client
        .from(templatesTable)
        .select('key,title,body,sort_order,is_active');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> _supabaseDefaults() async {
    final rows = await Supabase.instance.client
        .from(defaultsTable)
        .select('section,template_key');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<WhatsAppTemplateCatalog> load({bool forceRefresh = false}) async {
    final cached = _memory;
    final at = _memoryAt;
    if (!forceRefresh &&
        cached != null &&
        at != null &&
        DateTime.now().difference(at) < memoryTtl) {
      return cached;
    }
    WhatsAppTemplateCatalog catalog;
    try {
      final templateRows = await OfflineRowsCache.fetchOrCache(
        templatesCacheKey,
        _fetchTemplates,
        timeout: const Duration(seconds: 6),
      );
      List<Map<String, dynamic>> defaultRows;
      try {
        defaultRows = await OfflineRowsCache.fetchOrCache(
          defaultsCacheKey,
          _fetchDefaults,
          timeout: const Duration(seconds: 6),
        );
      } catch (_) {
        defaultRows = const [];
      }
      catalog = WhatsAppTemplateCatalog.fromRows(
        templateRows: templateRows,
        defaultRows: defaultRows,
      );
    } catch (e) {
      debugPrint('WhatsAppTemplateRepository: using built-in ($e)');
      catalog = WhatsAppTemplateCatalog.builtIn;
    }
    _memory = catalog;
    _memoryAt = DateTime.now();
    return catalog;
  }
}
