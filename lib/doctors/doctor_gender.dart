/// جنس الطبيب للعرض اللغوي فقط.
/// فارغ / غير معروف → نفس النصوص الحالية (مذكر) بدون أي تغيير.
class DoctorGender {
  static const unspecified = '';
  static const male = 'male';
  static const female = 'female';

  static String normalize(String? raw) {
    final v = raw?.trim().toLowerCase() ?? '';
    if (v == male || v == female) return v;
    return unspecified;
  }

  static bool isFemale(String? raw) => normalize(raw) == female;

  static String labelAr(String? raw) {
    switch (normalize(raw)) {
      case female:
        return 'أنثى';
      case male:
        return 'ذكر';
      default:
        return 'غير محدد';
    }
  }

  /// لقب مهني: طبيب / طبيبة
  static String profession(String? raw) =>
      isFemale(raw) ? 'الطبيبة' : 'الطبيب';

  /// لقب احترام: الدكتور / الدكتورة
  static String honorific(String? raw) =>
      isFemale(raw) ? 'الدكتورة' : 'الدكتور';

  static String availableToday(String? raw) =>
      isFemale(raw) ? 'متاحة اليوم' : 'متاح اليوم';

  static String availableShort(String? raw) =>
      isFemale(raw) ? 'متاحة' : 'متاح';

  static String unavailable(String? raw) =>
      isFemale(raw) ? 'غير متواجدة' : 'غير متواجد';

  static String notAvailable(String? raw) =>
      isFemale(raw) ? 'غير متاحة' : 'غير متاح';

  static String unavailableUntil(String? raw, String date) =>
      isFemale(raw) ? 'غير متواجدة حتى $date' : 'غير متواجد حتى $date';

  static String unavailableFromTo(String? raw, String from, String to) =>
      isFemale(raw)
          ? 'غير متواجدة من $from إلى $to'
          : 'غير متواجد من $from إلى $to';

  static String onLeaveToday(String? raw, String date) =>
      '${profession(raw)} في إجازة اليوم ($date)';

  static String onLeaveRange(String? raw, String from, String to) =>
      '${profession(raw)} في إجازة من $from إلى $to';

  static String onLeaveOrAway(String? raw) =>
      isFemale(raw)
          ? 'الطبيبة في إجازة أو غير متواجدة حاليًا'
          : 'الطبيب في إجازة أو غير متواجد حاليًا';

  static String onLeaveNow(String? raw) =>
      '${profession(raw)} في إجازة حاليًا';

  static String bookingFull(String? raw) =>
      isFemale(raw)
          ? 'الحجز مكتمل حاليًا لهذه الطبيبة'
          : 'الحجز مكتمل حاليًا لهذا الطبيب';

  static String walkInOnly(String? raw) =>
      isFemale(raw)
          ? 'مراجعة الطبيبة تكون بالحضور مباشرة'
          : 'مراجعة الطبيب تكون بالحضور مباشرة';

  static String currentlyUnavailable(String? raw) =>
      '${profession(raw)} غير ${isFemale(raw) ? 'متاحة' : 'متاح'} حالياً';
}
