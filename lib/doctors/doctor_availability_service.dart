import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/doctor_item.dart';
import 'doctor_gender.dart';

/// سجل إجازة لطبيب.
class DoctorAbsence {
  final String id;
  final String doctorId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DoctorAbsence({
    required this.id,
    required this.doctorId,
    required this.startDate,
    required this.endDate,
    this.reason = '',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory DoctorAbsence.fromMap(Map<String, dynamic> data) {
    DateTime parseDay(dynamic raw) {
      final parsed = DateTime.tryParse(raw?.toString() ?? '');
      if (parsed == null) {
        return DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
      }
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    return DoctorAbsence(
      id: data['id']?.toString() ?? '',
      doctorId: data['doctor_id']?.toString() ?? '',
      startDate: parseDay(data['start_date']),
      endDate: parseDay(data['end_date']),
      reason: data['reason']?.toString() ?? '',
      isActive: data['is_active'] != false,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {
      'doctor_id': doctorId,
      'start_date': ymd(startDate),
      'end_date': ymd(endDate),
      'reason': reason.trim(),
      'is_active': isActive,
    };
  }

  DoctorAbsence copyWith({
    String? id,
    String? doctorId,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    bool? isActive,
  }) {
    return DoctorAbsence(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// ملخص حالة الإجازة للعرض على البطاقة/الملف.
class DoctorLeaveDisplay {
  final bool isOnLeave;
  final DateTime? from;
  final DateTime? to;
  final String? reason;
  final String gender;

  const DoctorLeaveDisplay({
    required this.isOnLeave,
    this.from,
    this.to,
    this.reason,
    this.gender = DoctorGender.unspecified,
  });

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime? parseDay(String value) {
    if (value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return null;
    return dateOnly(parsed);
  }

  /// من حقول doctors.absence_* (المصدر المعروض للمستخدم).
  factory DoctorLeaveDisplay.fromDoctorFields({
    required String absenceFrom,
    required String absenceTo,
    String reason = '',
    String gender = DoctorGender.unspecified,
  }) {
    final from = parseDay(absenceFrom);
    final to = parseDay(absenceTo);
    if (from == null || to == null) {
      return DoctorLeaveDisplay(isOnLeave: false, gender: gender);
    }
    final today = dateOnly(DateTime.now());
    final onLeave = !today.isBefore(from) && !today.isAfter(to);
    return DoctorLeaveDisplay(
      isOnLeave: onLeave,
      from: from,
      to: to,
      reason: reason,
      gender: DoctorGender.normalize(gender),
    );
  }

  factory DoctorLeaveDisplay.fromDoctor(DoctorItem doctor) {
    return DoctorLeaveDisplay.fromDoctorFields(
      absenceFrom: doctor.absenceFrom,
      absenceTo: doctor.absenceTo,
      gender: doctor.gender,
    );
  }

  /// شارة قصيرة على البطاقة.
  String get badgeLabel {
    if (!isOnLeave || from == null || to == null) return '';
    final today = dateOnly(DateTime.now());
    if (from == to && from == today) return 'إجازة اليوم';
    if (to == today) return 'إجازة اليوم';
    return DoctorGender.unavailableUntil(gender, _fmt(to!));
  }

  /// سطر تفصيلي.
  String get detailLabel {
    if (!isOnLeave || from == null || to == null) return '';
    final today = dateOnly(DateTime.now());
    if (from == to && from == today) return 'إجازة اليوم';
    if (from == today) {
      return DoctorGender.unavailableUntil(gender, _fmt(to!));
    }
    return DoctorGender.unavailableFromTo(gender, _fmt(from!), _fmt(to!));
  }

  static String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

/// خدمة التواجد والإجازات — المصدر الإداري: doctor_absences
/// والعرض العام يبقى عبر doctors.absence_from/to بعد المزامنة.
class DoctorAvailabilityService {
  DoctorAvailabilityService({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client {
    if (_clientOverride != null) return _clientOverride;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated => _client?.auth.currentUser != null;

  Future<bool> hasAbsencesTable() async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('doctor_absences').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<DoctorAbsence>> fetchAbsencesForDoctor(String doctorId) async {
    final client = _client;
    if (client == null) throw StateError('Supabase غير جاهز');
    final data = await client
        .from('doctor_absences')
        .select()
        .eq('doctor_id', doctorId)
        .order('start_date', ascending: false);
    return (data as List)
        .map((e) => DoctorAbsence.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DoctorAbsence> upsertAbsence(
    DoctorAbsence absence, {
    String? existingId,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase غير جاهز');
    if (!isAuthenticated) {
      throw StateError('يجب تسجيل دخول الإدارة');
    }
    if (absence.endDate.isBefore(absence.startDate)) {
      throw ArgumentError('تاريخ النهاية قبل البداية');
    }

    final payload = absence.toMap();
    final id = existingId ?? absence.id;
    late final Map<String, dynamic> row;
    if (id.trim().isEmpty) {
      row = Map<String, dynamic>.from(
        await client.from('doctor_absences').insert(payload).select().single(),
      );
    } else {
      row = Map<String, dynamic>.from(
        await client
            .from('doctor_absences')
            .update(payload)
            .eq('id', id)
            .select()
            .single(),
      );
    }

    final saved = DoctorAbsence.fromMap(row);
    await syncDoctorAbsenceMirror(saved.doctorId);
    return saved;
  }

  Future<void> setAbsenceActive({
    required String id,
    required String doctorId,
    required bool isActive,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase غير جاهز');
    if (!isAuthenticated) throw StateError('يجب تسجيل دخول الإدارة');
    await client
        .from('doctor_absences')
        .update({'is_active': isActive})
        .eq('id', id);
    await syncDoctorAbsenceMirror(doctorId);
  }

  Future<void> deleteAbsence({
    required String id,
    required String doctorId,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase غير جاهز');
    if (!isAuthenticated) throw StateError('يجب تسجيل دخول الإدارة');
    await client.from('doctor_absences').delete().eq('id', id);
    await syncDoctorAbsenceMirror(doctorId);
  }

  /// يحدّث doctors.absence_from/to من الإجازة المفعّلة التي تغطي اليوم،
  /// أو أقرب إجازة مفعّلة قادمة إن لم يكن هناك إجازة حالية.
  Future<void> syncDoctorAbsenceMirror(String doctorId) async {
    final client = _client;
    if (client == null) return;

    try {
      final data = await client
          .from('doctor_absences')
          .select()
          .eq('doctor_id', doctorId)
          .eq('is_active', true)
          .order('start_date', ascending: true);

      final absences = (data as List)
          .map((e) => DoctorAbsence.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      final today = DoctorLeaveDisplay.dateOnly(DateTime.now());
      DoctorAbsence? current;
      DoctorAbsence? upcoming;

      for (final a in absences) {
        final coversToday =
            !today.isBefore(a.startDate) && !today.isAfter(a.endDate);
        if (coversToday) {
          current = a;
          break;
        }
        if (a.startDate.isAfter(today) && upcoming == null) {
          upcoming = a;
        }
      }

      final chosen = current ?? upcoming;
      if (chosen == null) {
        await client
            .from('doctors')
            .update({'absence_from': null, 'absence_to': null})
            .eq('id', doctorId);
        return;
      }

      String ymd(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      await client
          .from('doctors')
          .update({
            'absence_from': ymd(chosen.startDate),
            'absence_to': ymd(chosen.endDate),
          })
          .eq('id', doctorId);
    } catch (e) {
      debugPrint('syncDoctorAbsenceMirror failed: $e');
    }
  }

  /// تحديث مباشر لـ doctors.absence_from/to (احتياطي إن غاب جدول doctor_absences).
  Future<void> setDoctorLeaveDirect({
    required String doctorId,
    DateTime? from,
    DateTime? to,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase غير جاهز');
    if (!isAuthenticated) throw StateError('يجب تسجيل دخول الإدارة');

    if (from == null || to == null) {
      await client
          .from('doctors')
          .update({'absence_from': null, 'absence_to': null})
          .eq('id', doctorId);
      return;
    }

    final start = DoctorLeaveDisplay.dateOnly(from);
    final end = DoctorLeaveDisplay.dateOnly(to);
    if (end.isBefore(start)) {
      throw ArgumentError('تاريخ النهاية قبل البداية');
    }

    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await client
        .from('doctors')
        .update({
          'absence_from': ymd(start),
          'absence_to': ymd(end),
        })
        .eq('id', doctorId);
  }

  Future<({DateTime? from, DateTime? to})> fetchDoctorLeaveMirror(
    String doctorId,
  ) async {
    final client = _client;
    if (client == null) return (from: null, to: null);
    try {
      final row = await client
          .from('doctors')
          .select('absence_from, absence_to')
          .eq('id', doctorId)
          .maybeSingle();
      return (
        from: DoctorLeaveDisplay.parseDay(
          row?['absence_from']?.toString() ?? '',
        ),
        to: DoctorLeaveDisplay.parseDay(row?['absence_to']?.toString() ?? ''),
      );
    } catch (e) {
      debugPrint('fetchDoctorLeaveMirror failed: $e');
      return (from: null, to: null);
    }
  }
}
