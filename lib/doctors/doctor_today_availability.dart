import '../search/arabic_text_utils.dart';
import 'doctor_gender.dart';
import 'doctor_profile_page.dart' show parseDoctorWeekSchedule;

/// حالة تواجد الطبيب «اليوم» — مصدرها حقول Supabase فقط:
/// `working_days` / `working_hours` / `booking_status` / `absence_from` / `absence_to`.
///
/// لا تخمين: عند غياب معلومة مؤكدة تكون الحالة [DoctorTodayState.unknown].
/// اليوم يُحسب بتوقيت العيادة (بغداد UTC+3 بلا توقيت صيفي) لا بتوقيت الجهاز.
/// المتاح لدينا هو فترة الدوام (صباحًا/مساءً) لا الساعة الدقيقة، لذلك لا نؤكد
/// «متواجد الآن» أبدًا — فقط دوام اليوم.
enum DoctorTodayState {
  onLeave,
  dayOff,
  presentBookable,
  presentFull,
  presentWalkIn,
  presentBookingUnknown,
  bookingUnavailable,
  unknown,
}

class DoctorTodayAvailability {
  const DoctorTodayAvailability({required this.state, this.period});

  final DoctorTodayState state;

  /// صباحًا | مساءً | صباحًا ومساءً — فقط إن كانت مقروءة من working_hours.
  final String? period;

  static const Duration clinicUtcOffset = Duration(hours: 3);

  static const Map<int, String> _dayByWeekday = {
    6: 'السبت',
    7: 'الأحد',
    1: 'الاثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
  };

  /// لحظة بتوقيت العيادة (حقول UTC للنتيجة = ساعة الحائط في بغداد).
  static DateTime clinicNow(DateTime nowUtc) =>
      nowUtc.toUtc().add(clinicUtcOffset);

  static int? _ymd(String raw) {
    final m = RegExp(r'^\s*(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (m == null) return null;
    return int.parse(m.group(1)!) * 10000 +
        int.parse(m.group(2)!) * 100 +
        int.parse(m.group(3)!);
  }

  static DoctorTodayAvailability evaluate({
    required String workingDays,
    required String workingHours,
    required String bookingStatus,
    required String absenceFrom,
    required String absenceTo,
    DateTime? nowUtc,
  }) {
    final now = clinicNow(nowUtc ?? DateTime.now().toUtc());
    final today = now.year * 10000 + now.month * 100 + now.day;

    final from = _ymd(absenceFrom);
    final to = _ymd(absenceTo);
    if (from != null && to != null && today >= from && today <= to) {
      return const DoctorTodayAvailability(state: DoctorTodayState.onLeave);
    }

    final dayName = _dayByWeekday[now.weekday] ?? '';
    var week = parseDoctorWeekSchedule(
      workingDays: '',
      workingHours: workingHours,
    );
    final periodKnown = week.isNotEmpty;
    if (week.isEmpty) {
      week = parseDoctorWeekSchedule(
        workingDays: workingDays,
        workingHours: '',
      );
    }
    if (week.isEmpty) {
      // لا جدول مقروء. حالة الحجز «غير متاح» تبقى معلومة صريحة.
      if (bookingStatus.trim() == 'unavailable') {
        return const DoctorTodayAvailability(
          state: DoctorTodayState.bookingUnavailable,
        );
      }
      return const DoctorTodayAvailability(state: DoctorTodayState.unknown);
    }

    var found = false;
    var isOff = false;
    String? status;
    for (final entry in week) {
      if (entry.day == dayName) {
        found = true;
        isOff = entry.isOff;
        status = entry.status;
      }
    }
    if (!found || isOff) {
      return const DoctorTodayAvailability(state: DoctorTodayState.dayOff);
    }

    final period = periodKnown ? status : null;
    switch (bookingStatus.trim()) {
      case 'available':
        return DoctorTodayAvailability(
          state: DoctorTodayState.presentBookable,
          period: period,
        );
      case 'full':
        return DoctorTodayAvailability(
          state: DoctorTodayState.presentFull,
          period: period,
        );
      case 'walk_in_only':
        return DoctorTodayAvailability(
          state: DoctorTodayState.presentWalkIn,
          period: period,
        );
      case 'unavailable':
        return DoctorTodayAvailability(
          state: DoctorTodayState.bookingUnavailable,
          period: period,
        );
      default:
        return DoctorTodayAvailability(
          state: DoctorTodayState.presentBookingUnknown,
          period: period,
        );
    }
  }

  /// متاح اليوم فعليًا (دوام + حجز متاح أو حضور مباشر).
  bool get isAvailableToday =>
      state == DoctorTodayState.presentBookable ||
      state == DoctorTodayState.presentWalkIn;

  /// ترتيب «متوفر أولاً»: الأصغر أولاً.
  int get tier {
    switch (state) {
      case DoctorTodayState.presentBookable:
      case DoctorTodayState.presentWalkIn:
        return 0;
      case DoctorTodayState.presentFull:
      case DoctorTodayState.presentBookingUnknown:
        return 1;
      case DoctorTodayState.unknown:
        return 2;
      case DoctorTodayState.dayOff:
      case DoctorTodayState.bookingUnavailable:
      case DoctorTodayState.onLeave:
        return 3;
    }
  }

  static String _label(String rawName) {
    final stripped = ArabicTextUtils.stripHonorifics(rawName).trim();
    return stripped.isEmpty ? 'الطبيب' : 'د. $stripped';
  }

  /// جواب قصير من الحالة الحقيقية فقط.
  String describe({required String doctorName, String gender = ''}) {
    final name = _label(doctorName);
    final female = DoctorGender.isFemale(gender);
    final present = female ? 'متواجدة' : 'متواجد';
    final hers = female ? 'دوامها' : 'دوامه';

    switch (state) {
      case DoctorTodayState.onLeave:
        return '$name اليوم في إجازة.';
      case DoctorTodayState.dayOff:
        return female
            ? '$name ما عندها دوام اليوم حسب الجدول.'
            : '$name ما عنده دوام اليوم حسب الجدول.';
      case DoctorTodayState.presentBookable:
        return period == null
            ? 'نعم، $name $present اليوم، وحالة الحجز متاحة.'
            : 'نعم، $name $present اليوم. $hers $period، وحالة الحجز متاحة.';
      case DoctorTodayState.presentFull:
        return '$name $present اليوم لكن الحجز مكتمل.';
      case DoctorTodayState.presentWalkIn:
        return period == null
            ? 'نعم، $name $present اليوم، والاستقبال حضور مباشر فقط.'
            : 'نعم، $name $present اليوم. $hers $period، والاستقبال حضور مباشر فقط.';
      case DoctorTodayState.presentBookingUnknown:
        return period == null
            ? '$name $present اليوم حسب الجدول.'
            : '$name $present اليوم حسب الجدول. $hers $period.';
      case DoctorTodayState.bookingUnavailable:
        return female
            ? '$name غير متاحة حالياً حسب حالة الحجز.'
            : '$name غير متاح حالياً حسب حالة الحجز.';
      case DoctorTodayState.unknown:
        return 'لا توجد لدي معلومة مؤكدة عن دوام $name اليوم.';
    }
  }
}
