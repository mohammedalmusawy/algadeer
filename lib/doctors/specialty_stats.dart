import '../home/trending_entity.dart';
import 'doctor_today_availability.dart';
import 'specialty_catalog.dart';

/// أرقام حقيقية لكل اختصاص من صفوف الأطباء نفسها:
/// - [demand]: مشاهدات + اتصال + واتساب (نفس وزن قسم «الأكثر طلباً» بالرئيسية).
/// - [availableToday]: كم طبيب دوامه اليوم ومو مجاز (بتوقيت العيادة).
class SpecialtyStats {
  const SpecialtyStats({
    this.demand = const {},
    this.availableToday = const {},
  });

  final Map<String, int> demand;
  final Map<String, int> availableToday;

  /// نفس مفتاح [SpecialtyCatalog.countBySpecialty] حتى تتطابق الشبكة.
  static String keyFor(String raw) {
    final s = raw.trim();
    return SpecialtyCatalog.match(s)?.nameAr ?? s;
  }

  static SpecialtyStats fromDoctorRows(
    Iterable<Map<String, dynamic>> rows, {
    DateTime? nowUtc,
  }) {
    int asInt(dynamic v) =>
        v is num ? v.toInt() : (int.tryParse('${v ?? 0}') ?? 0);
    String text(dynamic v) => v?.toString() ?? '';

    final demand = <String, int>{};
    final today = <String, int>{};
    for (final m in rows) {
      final raw = text(m['specialty']).trim();
      if (raw.isEmpty) continue;
      final key = keyFor(raw);
      demand[key] = (demand[key] ?? 0) +
          TrendingEntity.score(
            views: asInt(m['profile_views']),
            calls: asInt(m['call_taps']),
            whatsapp: asInt(m['whatsapp_taps']),
          );
      final status = DoctorTodayAvailability.evaluate(
        workingDays: text(m['working_days']),
        workingHours: text(m['working_hours']),
        bookingStatus: m['booking_status']?.toString() ?? 'available',
        absenceFrom: text(m['absence_from']),
        absenceTo: text(m['absence_to']),
        nowUtc: nowUtc,
      );
      if (status.isAvailableToday) today[key] = (today[key] ?? 0) + 1;
    }
    return SpecialtyStats(demand: demand, availableToday: today);
  }
}
