import '../voice/startup_greeting.dart';

/// Phase 3B — بناء رسالة تواصل/حجز واتساب موحّد.
///
/// يعيد استخدام مسار الإطلاق القائم؛ يضيف الاسم من الملف الشخصي فقط.
/// لا يُدرج العمر ولا الجنس ولا أي بيانات سريرية.
class ClinicContactMessage {
  ClinicContactMessage._();

  static const String _genericBody = 'تواصل عبر تطبيق الغدير';

  /// الرسالة الافتراضية لفتح واتساب (طبيب/مختبر/نتيجة بحث).
  ///
  /// بدون اسم: قريبة من السلوك السابق.
  /// مع اسم: تُضاف سطر «الاسم: …» فقط.
  static String whatsAppPrefill({
    String? patientFullName,
    String? providerTitle,
    bool preferBookingWording = false,
  }) {
    final name = sanitizeGreetingName(patientFullName);
    final provider = (providerTitle ?? '').trim();
    final buf = StringBuffer('السلام عليكم،\n');
    if (preferBookingWording && provider.isNotEmpty) {
      buf.writeln('أرغب بحجز موعد لدى $provider.');
    } else {
      buf.writeln(_genericBody);
    }
    if (name != null) {
      buf.writeln('الاسم: $name');
    }
    return buf.toString().trimRight();
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
