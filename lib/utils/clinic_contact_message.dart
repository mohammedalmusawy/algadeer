import '../voice/startup_greeting.dart';

/// Phase 3B / 4A — بناء رسالة تواصل واتساب موحّد من قالب قابل للتعديل.
///
/// يعيد استخدام مسار الإطلاق القائم؛ يضيف الاسم من الملف الشخصي فقط.
/// لا يُدرج العمر ولا الجنس ولا أي بيانات سريرية.
///
/// القالب المحلي يُحفظ ويُحمَّل عبر `WhatsAppMessageSettingsService`؛ هذا
/// الصنف يملك الافتراضي وقواعد الاستبدال فقط (نقي وقابل للاختبار).
class ClinicContactMessage {
  ClinicContactMessage._();

  /// متغيّر اسم المستخدم داخل القالب.
  static const String nameVariable = '{اسم}';

  /// متغيّر اسم الطبيب/المختبر/المركز داخل القالب.
  static const String providerVariable = '{طبيب}';

  static const String defaultTemplate =
      'السلام عليكم 🌿\n'
      'أني $nameVariable — أتواصل وياكم من تطبيق الغدير\n'
      'أريد أستفسر عن موعد عند $providerVariable\n'
      'الله يعطيكم العافية 🙏';

  static final RegExp _hasDoctorTitle = RegExp(
    r'^(?:(?:ال)?(?:دكتور|دكتورة|طبيب|طبيبة)|د\.?)(?:\s|$)',
  );

  static final RegExp _separator = RegExp(r'[—–\-،]');

  /// «د.» قبل الاسم إن لم يكن معه لقب — بلا اقتطاع أحرف من الاسم نفسه.
  static String _doctorLabel(String raw) {
    final t = raw.trim();
    return _hasDoctorTitle.hasMatch(t) ? t : 'د. $t';
  }

  /// يستبدل المتغيّرات في [template] (الافتراضي إن كان فارغًا).
  ///
  /// - `{اسم}`: الاسم الصالح فقط. إن غاب يُحذف من بداية السطر حتى أول فاصل
  ///   (— أو - أو ،) بعد المتغيّر ويبقى الباقي («أتواصل وياكم من تطبيق
  ///   الغدير»)، وإن لم يوجد فاصل يُحذف السطر كله.
  /// - `{طبيب}`: «د. الاسم» للطبيب، والاسم كما هو للمختبر/المركز. إن غاب
  ///   يُحذف سطره.
  /// - أي `{متغيّر}` آخر يبقى كما كتبه المستخدم.
  static String render({
    String? template,
    String? patientFullName,
    String? providerTitle,
    bool providerIsDoctor = true,
  }) {
    final raw = (template ?? '').trim().isEmpty ? defaultTemplate : template!;
    final name = sanitizeGreetingName(patientFullName);
    final providerRaw = (providerTitle ?? '').trim();
    final provider = providerRaw.isEmpty
        ? null
        : (providerIsDoctor ? _doctorLabel(providerRaw) : providerRaw);

    final out = <String>[];
    for (final original in raw.replaceAll('\r\n', '\n').split('\n')) {
      var line = original;

      if (line.contains(nameVariable)) {
        if (name != null) {
          line = line.replaceAll(nameVariable, name);
        } else {
          final at = line.indexOf(nameVariable) + nameVariable.length;
          final sep = _separator.firstMatch(line.substring(at));
          if (sep == null) continue;
          line = line
              .substring(at + sep.end)
              .replaceAll(nameVariable, '')
              .trim();
          if (line.isEmpty) continue;
        }
      }

      if (line.contains(providerVariable)) {
        if (provider == null) continue;
        line = line.replaceAll(providerVariable, provider);
      }

      out.add(line);
    }
    return out.join('\n').trim();
  }

  /// الرسالة الافتراضية لفتح واتساب (طبيب/مختبر/مركز) — تروح للسكرتير.
  static String whatsAppPrefill({
    String? patientFullName,
    String? providerTitle,
    bool providerIsDoctor = true,
    String? template,
  }) {
    return render(
      template: template,
      patientFullName: patientFullName,
      providerTitle: providerTitle,
      providerIsDoctor: providerIsDoctor,
    );
  }

  /// يلحق سطر الاسم برسالة واتساب موجودة (مثل طلب تحاليل) إن وُجد اسم.
  static String appendPatientNameIfPresent(
    String message, {
    String? patientFullName,
  }) {
    final name = sanitizeGreetingName(patientFullName);
    if (name == null) return message.trimRight();
    final body = message.trimRight();
    if (body.contains('الاسم:')) return body;
    return '$body\nالاسم: $name';
  }
}
