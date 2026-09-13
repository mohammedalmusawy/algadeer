import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorRatingSummary {
  final double average;
  final int count;

  const DoctorRatingSummary({this.average = 0, this.count = 0});

  String get label {
    if (count <= 0) return 'لا تقييمات بعد';
    return '${average.toStringAsFixed(1)} من الجمهور ($count)';
  }

  String get shortLabel {
    if (count <= 0) return 'تقييم من الجمهور';
    return 'تقييم ${average.toStringAsFixed(1)} من الجمهور';
  }
}

class DoctorEngagementService {
  DoctorEngagementService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> recordProfileView(String doctorId) async {
    if (doctorId.isEmpty) return;
    try {
      await _client.rpc(
        'increment_doctor_profile_views',
        params: {'p_doctor_id': doctorId},
      );
    } catch (_) {
      // الحقل/الدالة قد لا تكون موجودة قبل تنفيذ SQL
    }
  }

  Future<DoctorRatingSummary> fetchRatingSummary(String doctorId) async {
    try {
      final data = await _client
          .from('doctor_ratings')
          .select('rating')
          .eq('doctor_id', doctorId);
      final rows = data as List;
      if (rows.isEmpty) return const DoctorRatingSummary();
      var sum = 0;
      for (final row in rows) {
        sum += (row['rating'] as num?)?.toInt() ?? 0;
      }
      return DoctorRatingSummary(
        average: sum / rows.length,
        count: rows.length,
      );
    } catch (e, st) {
      debugPrint('fetchRatingSummary failed for doctor_id=$doctorId: $e\n$st');
      return const DoctorRatingSummary();
    }
  }

  Future<int?> fetchMyRating(String doctorId) async {
    try {
      final key = await _visitorKey();
      final row = await _client
          .from('doctor_ratings')
          .select('rating')
          .eq('doctor_id', doctorId)
          .eq('visitor_key', key)
          .maybeSingle();
      if (row == null) return null;
      return (row['rating'] as num?)?.toInt();
    } catch (e, st) {
      debugPrint('fetchMyRating failed for doctor_id=$doctorId: $e\n$st');
      return null;
    }
  }

  Future<DoctorRatingSummary> submitRating({
    required String doctorId,
    required int rating,
    String comment = '',
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'يجب أن يكون التقييم بين 1 و 5');
    }
    final key = await _visitorKey();
    try {
      await _client.from('doctor_ratings').upsert({
        'doctor_id': doctorId,
        'rating': rating,
        'comment': comment,
        'visitor_key': key,
      }, onConflict: 'doctor_id,visitor_key');
    } catch (e, st) {
      debugPrint(
        'submitRating failed doctor_id=$doctorId rating=$rating '
        'visitor_key=$key: $e\n$st',
      );
      rethrow;
    }
    return fetchRatingSummary(doctorId);
  }

  Future<String> _visitorKey() async {
    final prefs = await SharedPreferences.getInstance();
    var key = prefs.getString('visitor_rating_key');
    if (key == null || key.isEmpty) {
      key = 'v_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('visitor_rating_key', key);
    }
    return key;
  }
}

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? doctorId;
  final bool isActive;
  final bool sendPushSuggested;
  final DateTime? createdAt;
  /// إن وُجد: draft/scheduled لا يظهران للمستخدم.
  final String? status;

  const AppNotificationItem({
    required this.id,
    required this.title,
    this.body = '',
    this.type = 'general',
    this.doctorId,
    this.isActive = true,
    this.sendPushSuggested = false,
    this.createdAt,
    this.status,
  });

  factory AppNotificationItem.fromMap(Map<String, dynamic> data) {
    return AppNotificationItem(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      type: data['type']?.toString() ?? 'general',
      doctorId: data['doctor_id']?.toString(),
      isActive: data['is_active'] != false,
      sendPushSuggested: data['send_push_suggested'] == true,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      status: data['status']?.toString(),
    );
  }

  bool get visibleToUsers {
    if (!isActive) return false;
    final s = status;
    if (s == null || s.isEmpty) return true; // سجلات قديمة
    return s == 'sent';
  }
}

class NotificationsService {
  NotificationsService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AppNotificationItem>> fetchActive() async {
    try {
      // للمستخدم: المرسل والمفعّل فقط — المسودات/المجدولة لا تظهر.
      final data = await _client
          .from('app_notifications')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(80);
      return (data as List)
          .map(
            (row) => AppNotificationItem.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .where((item) => item.visibleToUsers)
          .take(50)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AppNotificationItem>> fetchAll() async {
    final data = await _client
        .from('app_notifications')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map(
          (row) => AppNotificationItem.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> createNotification({
    required String title,
    required String body,
    String type = 'general',
    String? doctorId,
    bool sendPushSuggested = true,
  }) async {
    await _client.from('app_notifications').insert({
      'title': title,
      'body': body,
      'type': type,
      'doctor_id': doctorId,
      'is_active': true,
      'send_push_suggested': sendPushSuggested,
    });
  }

  Future<void> setActive(String id, bool active) async {
    await _client
        .from('app_notifications')
        .update({'is_active': active})
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('app_notifications').delete().eq('id', id);
  }

  Future<Set<String>> readIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('read_notification_ids') ?? []).toSet();
  }

  Future<void> markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList('read_notification_ids') ?? []).toSet()
      ..add(id);
    await prefs.setStringList('read_notification_ids', ids.toList());
  }
}
