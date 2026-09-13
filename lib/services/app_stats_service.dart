import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// فترة الإحصائية القابلة للاختيار في الإدارة.
enum StatsPeriod { day, week, month, year }

extension StatsPeriodX on StatsPeriod {
  String get labelAr {
    switch (this) {
      case StatsPeriod.day:
        return 'يومي';
      case StatsPeriod.week:
        return 'أسبوعي';
      case StatsPeriod.month:
        return 'شهري';
      case StatsPeriod.year:
        return 'سنوي';
    }
  }

  IconData get icon {
    switch (this) {
      case StatsPeriod.day:
        return Icons.today_rounded;
      case StatsPeriod.week:
        return Icons.date_range_rounded;
      case StatsPeriod.month:
        return Icons.calendar_month_rounded;
      case StatsPeriod.year:
        return Icons.calendar_today_rounded;
    }
  }

  /// بداية الفترة حسب التوقيت المحلي.
  DateTime get since {
    final now = DateTime.now();
    switch (this) {
      case StatsPeriod.day:
        return DateTime(now.year, now.month, now.day);
      case StatsPeriod.week:
        return now.subtract(const Duration(days: 7));
      case StatsPeriod.month:
        return DateTime(now.year, now.month, 1);
      case StatsPeriod.year:
        return DateTime(now.year, 1, 1);
    }
  }
}

/// إحصائيات عامة للتطبيق + تفاعل كل طبيب من داخل الغدير.
class AppStatsService {
  AppStatsService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _visitorPrefsKey = 'visitor_rating_key';

  Future<String> visitorKey() async {
    final prefs = await SharedPreferences.getInstance();
    var key = prefs.getString(_visitorPrefsKey);
    if (key == null || key.length < 8) {
      key =
          'u_${DateTime.now().millisecondsSinceEpoch}_'
          '${DateTime.now().microsecondsSinceEpoch % 1000000}';
      await prefs.setString(_visitorPrefsKey, key);
    }
    return key;
  }

  /// يُستدعى عند فتح التطبيق لتسجيل/تحديث مستخدم فريد.
  Future<void> touchCurrentUser() async {
    try {
      final key = await visitorKey();
      await _client.rpc('touch_app_user', params: {'p_visitor_key': key});
    } catch (e) {
      debugPrint('touchCurrentUser failed (run app_stats_schema.sql?): $e');
    }
  }

  Future<AppPeriodStats> fetchPeriodStats({
    required StatsPeriod period,
    String? doctorId,
    String? labId,
  }) async {
    final sinceIso = period.since.toUtc().toIso8601String();
    try {
      var query = _client
          .from('app_stat_events')
          .select('event_type, visitor_key, doctor_id, lab_id')
          .gte('created_at', sinceIso);

      if (doctorId != null && doctorId.isNotEmpty) {
        query = query.eq('doctor_id', doctorId);
      }
      if (labId != null && labId.isNotEmpty) {
        query = query.eq('lab_id', labId);
      }

      final rows = await query;
      final list = rows as List;

      var opens = 0;
      var views = 0;
      var calls = 0;
      var whatsapp = 0;
      var ratings = 0;
      var labViews = 0;
      var labCalls = 0;
      var labWhatsapp = 0;
      final uniqueUsers = <String>{};

      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw as Map);
        final type = m['event_type']?.toString() ?? '';
        final visitor = m['visitor_key']?.toString().trim() ?? '';
        if (visitor.isNotEmpty) uniqueUsers.add(visitor);

        switch (type) {
          case 'app_open':
            opens++;
            break;
          case 'profile_view':
            views++;
            break;
          case 'call_tap':
            calls++;
            break;
          case 'whatsapp_tap':
            whatsapp++;
            break;
          case 'rating':
            ratings++;
            break;
          case 'lab_profile_view':
            labViews++;
            break;
          case 'lab_call_tap':
            labCalls++;
            break;
          case 'lab_whatsapp_tap':
            labWhatsapp++;
            break;
        }
      }

      final scopedDoctor = doctorId != null && doctorId.isNotEmpty;
      final scopedLab = labId != null && labId.isNotEmpty;

      final usersInPeriod = (!scopedDoctor && !scopedLab)
          ? await _countUsersInPeriod(sinceIso, fallback: uniqueUsers.length)
          : uniqueUsers.length;

      final doctorsCount = (!scopedDoctor && !scopedLab)
          ? await _countDoctors()
          : (scopedDoctor ? 1 : 0);
      final labsCount = (!scopedDoctor && !scopedLab)
          ? await _countLabs()
          : (scopedLab ? 1 : 0);

      return AppPeriodStats(
        period: period,
        users: usersInPeriod,
        appOpens: opens,
        profileViews: views,
        callTaps: calls,
        whatsappTaps: whatsapp,
        ratingsCount: ratings,
        doctorsCount: doctorsCount,
        labProfileViews: labViews,
        labCallTaps: labCalls,
        labWhatsappTaps: labWhatsapp,
        labsCount: labsCount,
      );
    } catch (e) {
      debugPrint('fetchPeriodStats failed (run app_stats_periods_schema.sql?): $e');
      if (labId != null && labId.isNotEmpty) {
        final all = await fetchLabStats(labId);
        return AppPeriodStats(
          period: period,
          users: 0,
          appOpens: 0,
          profileViews: 0,
          callTaps: 0,
          whatsappTaps: 0,
          ratingsCount: 0,
          doctorsCount: 0,
          labProfileViews: all.profileViews,
          labCallTaps: all.callTaps,
          labWhatsappTaps: all.whatsappTaps,
          labsCount: 1,
          isLifetimeFallback: true,
        );
      }
      if (doctorId != null && doctorId.isNotEmpty) {
        final all = await fetchDoctorStats(doctorId);
        return AppPeriodStats(
          period: period,
          users: 0,
          appOpens: 0,
          profileViews: all.profileViews,
          callTaps: all.callTaps,
          whatsappTaps: all.whatsappTaps,
          ratingsCount: all.ratingsCount,
          doctorsCount: 1,
          isLifetimeFallback: true,
        );
      }
      final users = await fetchAppUsersCount();
      final summary = await fetchDoctorsViewsSummary();
      final labSummary = await fetchLabsViewsSummary();
      return AppPeriodStats(
        period: period,
        users: users,
        appOpens: 0,
        profileViews: summary.totalViews,
        callTaps: 0,
        whatsappTaps: 0,
        ratingsCount: 0,
        doctorsCount: summary.doctorsCount,
        labProfileViews: labSummary.totalViews,
        labCallTaps: labSummary.totalCalls,
        labWhatsappTaps: labSummary.totalWhatsapp,
        labsCount: labSummary.labsCount,
        isLifetimeFallback: true,
      );
    }
  }

  Future<int> _countUsersInPeriod(String sinceIso, {required int fallback}) async {
    try {
      final data = await _client
          .from('app_users')
          .select('visitor_key')
          .gte('last_seen_at', sinceIso);
      return (data as List).length;
    } catch (_) {
      return fallback;
    }
  }

  Future<int> _countDoctors() async {
    try {
      final data = await _client.from('doctors').select('id');
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countLabs() async {
    try {
      final data = await _client.from('labs').select('id');
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> fetchAppUsersCount() async {
    try {
      final data = await _client.from('app_users').select('visitor_key');
      return (data as List).length;
    } catch (e) {
      debugPrint('fetchAppUsersCount failed: $e');
      return 0;
    }
  }

  Future<({int doctorsCount, int totalViews})> fetchDoctorsViewsSummary() async {
    try {
      final data = await _client.from('doctors').select('profile_views');
      final rows = data as List;
      var views = 0;
      for (final r in rows) {
        final m = Map<String, dynamic>.from(r as Map);
        views += int.tryParse('${m['profile_views'] ?? 0}') ?? 0;
      }
      return (doctorsCount: rows.length, totalViews: views);
    } catch (e) {
      debugPrint('fetchDoctorsViewsSummary failed: $e');
      return (doctorsCount: 0, totalViews: 0);
    }
  }

  Future<
      ({
        int labsCount,
        int totalViews,
        int totalCalls,
        int totalWhatsapp,
      })> fetchLabsViewsSummary() async {
    try {
      final data = await _client
          .from('labs')
          .select('profile_views, call_taps, whatsapp_taps');
      final rows = data as List;
      var views = 0;
      var calls = 0;
      var wa = 0;
      for (final r in rows) {
        final m = Map<String, dynamic>.from(r as Map);
        views += int.tryParse('${m['profile_views'] ?? 0}') ?? 0;
        calls += int.tryParse('${m['call_taps'] ?? 0}') ?? 0;
        wa += int.tryParse('${m['whatsapp_taps'] ?? 0}') ?? 0;
      }
      return (
        labsCount: rows.length,
        totalViews: views,
        totalCalls: calls,
        totalWhatsapp: wa,
      );
    } catch (e) {
      debugPrint('fetchLabsViewsSummary failed: $e');
      return (
        labsCount: 0,
        totalViews: 0,
        totalCalls: 0,
        totalWhatsapp: 0,
      );
    }
  }

  Future<DoctorAdminStats> fetchDoctorStats(String doctorId) async {
    if (doctorId.isEmpty) return const DoctorAdminStats();
    try {
      final row = await _client
          .from('doctors')
          .select('profile_views, call_taps, whatsapp_taps')
          .eq('id', doctorId)
          .maybeSingle();

      var ratings = 0;
      try {
        final ratingRows = await _client
            .from('doctor_ratings')
            .select('id')
            .eq('doctor_id', doctorId);
        ratings = (ratingRows as List).length;
      } catch (_) {}

      return DoctorAdminStats(
        profileViews: _asInt(row?['profile_views']),
        callTaps: _asInt(row?['call_taps']),
        whatsappTaps: _asInt(row?['whatsapp_taps']),
        ratingsCount: ratings,
      );
    } catch (e) {
      debugPrint('fetchDoctorStats failed: $e');
      return const DoctorAdminStats();
    }
  }

  Future<LabAdminStats> fetchLabStats(String labId) async {
    if (labId.isEmpty) return const LabAdminStats();
    try {
      final row = await _client
          .from('labs')
          .select('profile_views, call_taps, whatsapp_taps')
          .eq('id', labId)
          .maybeSingle();
      return LabAdminStats(
        profileViews: _asInt(row?['profile_views']),
        callTaps: _asInt(row?['call_taps']),
        whatsappTaps: _asInt(row?['whatsapp_taps']),
      );
    } catch (e) {
      debugPrint('fetchLabStats failed: $e');
      return const LabAdminStats();
    }
  }

  Future<void> recordCallTap(String doctorId) async {
    if (doctorId.isEmpty) return;
    try {
      await _client.rpc(
        'increment_doctor_call_taps',
        params: {'p_doctor_id': doctorId},
      );
    } catch (e) {
      debugPrint('recordCallTap failed: $e');
    }
  }

  Future<void> recordWhatsAppTap(String doctorId) async {
    if (doctorId.isEmpty) return;
    try {
      await _client.rpc(
        'increment_doctor_whatsapp_taps',
        params: {'p_doctor_id': doctorId},
      );
    } catch (e) {
      debugPrint('recordWhatsAppTap failed: $e');
    }
  }

  Future<void> recordLabProfileView(String labId) async {
    if (labId.isEmpty) return;
    try {
      await _client.rpc(
        'increment_lab_profile_views',
        params: {'p_lab_id': labId},
      );
    } catch (e) {
      debugPrint('recordLabProfileView failed (run lab_stats_schema.sql?): $e');
    }
  }

  Future<void> recordLabCallTap(String labId) async {
    if (labId.isEmpty) return;
    try {
      await _client.rpc(
        'increment_lab_call_taps',
        params: {'p_lab_id': labId},
      );
    } catch (e) {
      debugPrint('recordLabCallTap failed: $e');
    }
  }

  Future<void> recordLabWhatsAppTap(String labId) async {
    if (labId.isEmpty) return;
    try {
      await _client.rpc(
        'increment_lab_whatsapp_taps',
        params: {'p_lab_id': labId},
      );
    } catch (e) {
      debugPrint('recordLabWhatsAppTap failed: $e');
    }
  }

  static int _asInt(dynamic v) => int.tryParse('$v') ?? 0;
}

class AppPeriodStats {
  const AppPeriodStats({
    required this.period,
    this.users = 0,
    this.appOpens = 0,
    this.profileViews = 0,
    this.callTaps = 0,
    this.whatsappTaps = 0,
    this.ratingsCount = 0,
    this.doctorsCount = 0,
    this.labProfileViews = 0,
    this.labCallTaps = 0,
    this.labWhatsappTaps = 0,
    this.labsCount = 0,
    this.isLifetimeFallback = false,
  });

  final StatsPeriod period;
  final int users;
  final int appOpens;
  final int profileViews;
  final int callTaps;
  final int whatsappTaps;
  final int ratingsCount;
  final int doctorsCount;
  final int labProfileViews;
  final int labCallTaps;
  final int labWhatsappTaps;
  final int labsCount;
  final bool isLifetimeFallback;
}

class DoctorAdminStats {
  const DoctorAdminStats({
    this.profileViews = 0,
    this.callTaps = 0,
    this.whatsappTaps = 0,
    this.ratingsCount = 0,
  });

  final int profileViews;
  final int callTaps;
  final int whatsappTaps;
  final int ratingsCount;
}

class LabAdminStats {
  const LabAdminStats({
    this.profileViews = 0,
    this.callTaps = 0,
    this.whatsappTaps = 0,
  });

  final int profileViews;
  final int callTaps;
  final int whatsappTaps;
}

/// صف اختيار الفترة بأيقونات (يومي/أسبوعي/شهري/سنوي).
class StatsPeriodSelector extends StatelessWidget {
  const StatsPeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final StatsPeriod value;
  final ValueChanged<StatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0FAFA3);
    return Row(
      children: StatsPeriod.values.map((p) {
        final selected = p == value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Material(
              color: selected ? teal : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? teal : const Color(0xFFE0E8EA),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        p.icon,
                        size: 22,
                        color: selected ? Colors.white : teal,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.labelAr,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : const Color(0xFF456066),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
