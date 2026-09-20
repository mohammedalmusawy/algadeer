import 'package:supabase_flutter/supabase_flutter.dart';

/// أنواع إشعارات الغدير (إدارة).
class NotificationTypes {
  static const doctorLeaveStart = 'doctor_leave_start';
  static const doctorLeaveEnd = 'doctor_leave_end';
  static const doctorBackTomorrow = 'doctor_back_tomorrow';
  static const doctorPresentToday = 'doctor_present_today';
  static const doctorScheduleChange = 'doctor_schedule_change';
  static const doctorManual = 'doctor_manual';
  static const labNewOffer = 'lab_new_offer';
  static const labNewPackage = 'lab_new_package';
  static const labPriceDrop = 'lab_price_drop';
  static const labOfferExpiring = 'lab_offer_expiring';
  static const labOfferEnded = 'lab_offer_ended';
  static const labManual = 'lab_manual';
  static const ghadeerAnnouncement = 'ghadeer_announcement';
  static const ghadeerHealthTip = 'ghadeer_health_tip';
  static const ghadeerNews = 'ghadeer_news';
  static const ghadeerManual = 'ghadeer_manual';
  static const adCampaign = 'ad_campaign';
  // توافق مع السجلات القديمة
  static const legacyGeneral = 'general';
  static const legacyDoctorLeave = 'doctor_leave';
  static const legacyLabPackage = 'lab_package';
  static const legacySuggestion = 'suggestion';

  static const List<({String value, String label, String source})> adminChoices =
      [
        (value: doctorLeaveStart, label: 'بداية عطلة طبيب', source: 'doctor'),
        (value: doctorLeaveEnd, label: 'العودة من العطلة', source: 'doctor'),
        (value: doctorBackTomorrow, label: 'متواجد غدًا', source: 'doctor'),
        (value: doctorPresentToday, label: 'متواجد اليوم', source: 'doctor'),
        (
          value: doctorScheduleChange,
          label: 'تغيير أيام/أوقات التواجد',
          source: 'doctor',
        ),
        (value: doctorManual, label: 'إشعار يدوي لطبيب', source: 'doctor'),
        (value: labNewOffer, label: 'عرض مختبر جديد', source: 'lab'),
        (value: labNewPackage, label: 'باقة مختبر جديدة', source: 'lab'),
        (value: labPriceDrop, label: 'تخفيض سعر', source: 'lab'),
        (value: labOfferExpiring, label: 'قرب انتهاء العرض', source: 'lab'),
        (value: labOfferEnded, label: 'انتهاء العرض', source: 'lab'),
        (value: labManual, label: 'إشعار يدوي لمختبر', source: 'lab'),
        (value: ghadeerAnnouncement, label: 'إعلان عام', source: 'ghadeer'),
        (value: adCampaign, label: 'إعلان في منصة الغدير', source: 'ghadeer'),
        (value: ghadeerHealthTip, label: 'تنبيه صحي', source: 'ghadeer'),
        (value: ghadeerNews, label: 'خبر / رسالة مهمة', source: 'ghadeer'),
        (value: ghadeerManual, label: 'إشعار يدوي للجميع', source: 'ghadeer'),
      ];

  static String labelOf(String type) {
    for (final c in adminChoices) {
      if (c.value == type) return c.label;
    }
    switch (type) {
      case legacyDoctorLeave:
        return 'عطلة طبيب';
      case legacyLabPackage:
        return 'باقة مختبر';
      case legacySuggestion:
        return 'مقترح';
      case legacyGeneral:
        return 'عام';
      default:
        return type;
    }
  }

  static String sourceOf(String type) {
    for (final c in adminChoices) {
      if (c.value == type) return c.source;
    }
    if (type.startsWith('doctor') || type == legacyDoctorLeave) return 'doctor';
    if (type.startsWith('lab') || type == legacyLabPackage) return 'lab';
    return 'ghadeer';
  }
}

class NotificationStatus {
  static const draft = 'draft';
  static const scheduled = 'scheduled';
  static const sent = 'sent';
  static const cancelled = 'cancelled';
  static const expired = 'expired';

  static String labelOf(String status) {
    switch (status) {
      case draft:
        return 'مسودة';
      case scheduled:
        return 'مجدولة';
      case sent:
        return 'مرسلة';
      case cancelled:
        return 'ملغاة';
      case expired:
        return 'منتهية';
      default:
        return status;
    }
  }
}

class NotificationTemplates {
  static ({String title, String body}) build({
    required String type,
    String doctorName = 'الطبيب',
    String labName = 'المختبر',
    String packageName = 'الباقة',
    int? leaveDays,
    String doctorGender = '',
  }) {
    final d = doctorName.trim().isEmpty ? 'الطبيب' : doctorName.trim();
    final l = labName.trim().isEmpty ? 'المختبر' : labName.trim();
    final p = packageName.trim().isEmpty ? 'الباقة' : packageName.trim();
    final days = leaveDays == null ? '' : ' لمدة $leaveDays أيام';
    final female = doctorGender.trim().toLowerCase() == 'female';
    final doc = female ? 'الدكتورة' : 'الدكتور';
    final present = female ? 'متواجدة' : 'متواجد';
    final returnTitle = female ? 'عودة الطبيبة' : 'عودة الطبيب';
    final leaveTitle = female ? 'عطلة طبيبة' : 'عطلة طبيب';

    switch (type) {
      case NotificationTypes.doctorLeaveStart:
      case NotificationTypes.legacyDoctorLeave:
        return (
          title: leaveTitle,
          body: '$doc $d في عطلة$days.',
        );
      case NotificationTypes.doctorLeaveEnd:
        return (title: returnTitle, body: '$doc $d عاد${female ? 'ت' : ''} للتواجد.');
      case NotificationTypes.doctorBackTomorrow:
        return (
          title: '$present غدًا',
          body: '$doc $d $present غدًا.',
        );
      case NotificationTypes.doctorPresentToday:
        return (
          title: '$present اليوم',
          body: '$doc $d $present اليوم.',
        );
      case NotificationTypes.doctorScheduleChange:
        return (
          title: 'تحديث جدول التواجد',
          body: 'تم تحديث أيام/أوقات تواجد $doc $d.',
        );
      case NotificationTypes.doctorManual:
        return (
          title: 'إشعار من عيادة الغدير',
          body: 'رسالة بخصوص $doc $d.',
        );
      case NotificationTypes.labNewOffer:
        return (
          title: 'عرض جديد',
          body: 'عرض جديد من مختبر $l على $p.',
        );
      case NotificationTypes.labNewPackage:
      case NotificationTypes.legacyLabPackage:
        return (
          title: 'باقة جديدة',
          body: 'باقة جديدة من مختبر $l: $p.',
        );
      case NotificationTypes.labPriceDrop:
        return (
          title: 'تخفيض سعر',
          body: 'تخفيض على $p من مختبر $l.',
        );
      case NotificationTypes.labOfferExpiring:
        return (
          title: 'العرض ينتهي قريبًا',
          body: 'عرض $p من مختبر $l يوشك على الانتهاء.',
        );
      case NotificationTypes.labOfferEnded:
        return (
          title: 'انتهى العرض',
          body: 'انتهى عرض $p من مختبر $l.',
        );
      case NotificationTypes.labManual:
        return (title: 'إشعار مختبر', body: 'رسالة من مختبر $l.');
      case NotificationTypes.ghadeerHealthTip:
        return (
          title: 'تنبيه صحي',
          body: 'نصيحة صحية من عيادة الغدير.',
        );
      case NotificationTypes.ghadeerNews:
        return (
          title: 'خبر مهم',
          body: 'رسالة مهمة من عيادة الغدير.',
        );
      case NotificationTypes.ghadeerAnnouncement:
      case NotificationTypes.adCampaign:
        return (
          title: 'إعلان في منصة الغدير',
          body: 'يوجد إعلان جديد في منصة الغدير.',
        );
      case NotificationTypes.ghadeerManual:
      default:
        return (
          title: 'عيادة الغدير',
          body: 'إعلان من عيادة الغدير.',
        );
    }
  }
}

class AdminNotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final String status;
  final String origin;
  final String source;
  final String audience;
  final String destinationKind;
  final String? destinationId;
  final String? doctorId;
  final String? labId;
  final String? packageId;
  final bool isActive;
  final bool sendPushSuggested;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime? createdAt;
  final String? idempotencyKey;
  final String? templateKey;
  final bool repeatEnabled;
  final List<String> repeatDays;
  final int repeatHour;
  final int repeatMinute;

  const AdminNotificationItem({
    required this.id,
    required this.title,
    this.body = '',
    this.type = 'general',
    this.status = NotificationStatus.sent,
    this.origin = 'manual',
    this.source = 'ghadeer',
    this.audience = 'all',
    this.destinationKind = 'home',
    this.destinationId,
    this.doctorId,
    this.labId,
    this.packageId,
    this.isActive = true,
    this.sendPushSuggested = false,
    this.scheduledAt,
    this.sentAt,
    this.createdAt,
    this.idempotencyKey,
    this.templateKey,
    this.repeatEnabled = false,
    this.repeatDays = const [],
    this.repeatHour = 9,
    this.repeatMinute = 0,
  });

  bool get isAuto => origin == 'auto' || repeatEnabled;

  static const weekDays = [
    'السبت',
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  factory AdminNotificationItem.fromMap(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? 'general';
    final daysRaw = data['repeat_days'];
    final days = <String>[];
    if (daysRaw is List) {
      for (final d in daysRaw) {
        final s = d?.toString().trim() ?? '';
        if (s.isNotEmpty) days.add(s);
      }
    }
    return AdminNotificationItem(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      type: type,
      status: (data['status']?.toString().isNotEmpty == true)
          ? data['status'].toString()
          : NotificationStatus.sent,
      origin: data['origin']?.toString() ?? 'manual',
      source: data['source']?.toString() ??
          NotificationTypes.sourceOf(type),
      audience: data['audience']?.toString() ?? 'all',
      destinationKind: data['destination_kind']?.toString() ?? 'home',
      destinationId: data['destination_id']?.toString(),
      doctorId: data['doctor_id']?.toString(),
      labId: data['lab_id']?.toString(),
      packageId: data['package_id']?.toString(),
      isActive: data['is_active'] != false,
      sendPushSuggested: data['send_push_suggested'] == true,
      scheduledAt: DateTime.tryParse(data['scheduled_at']?.toString() ?? ''),
      sentAt: DateTime.tryParse(data['sent_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      idempotencyKey: data['idempotency_key']?.toString(),
      templateKey: data['template_key']?.toString(),
      repeatEnabled: data['repeat_enabled'] == true,
      repeatDays: days,
      repeatHour: int.tryParse(data['repeat_hour']?.toString() ?? '') ?? 9,
      repeatMinute: int.tryParse(data['repeat_minute']?.toString() ?? '') ?? 0,
    );
  }
}

class NotificationSettings {
  final String timezone;
  final int doctorTomorrowHour;
  final int doctorTomorrowMinute;
  final int doctorTodayHour;
  final int doctorTodayMinute;
  final int labExpiryHoursBefore;
  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietEndHour;

  const NotificationSettings({
    this.timezone = 'Asia/Baghdad',
    this.doctorTomorrowHour = 21,
    this.doctorTomorrowMinute = 0,
    this.doctorTodayHour = 8,
    this.doctorTodayMinute = 0,
    this.labExpiryHoursBefore = 24,
    this.quietHoursEnabled = false,
    this.quietStartHour = 0,
    this.quietEndHour = 6,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> data) {
    return NotificationSettings(
      timezone: data['timezone']?.toString() ?? 'Asia/Baghdad',
      doctorTomorrowHour: _asInt(data['doctor_tomorrow_hour'], 21),
      doctorTomorrowMinute: _asInt(data['doctor_tomorrow_minute'], 0),
      doctorTodayHour: _asInt(data['doctor_today_hour'], 8),
      doctorTodayMinute: _asInt(data['doctor_today_minute'], 0),
      labExpiryHoursBefore: _asInt(data['lab_expiry_hours_before'], 24),
      quietHoursEnabled: data['quiet_hours_enabled'] == true,
      quietStartHour: _asInt(data['quiet_start_hour'], 0),
      quietEndHour: _asInt(data['quiet_end_hour'], 6),
    );
  }

  Map<String, dynamic> toMap() => {
        'timezone': timezone,
        'doctor_tomorrow_hour': doctorTomorrowHour,
        'doctor_tomorrow_minute': doctorTomorrowMinute,
        'doctor_today_hour': doctorTodayHour,
        'doctor_today_minute': doctorTodayMinute,
        'lab_expiry_hours_before': labExpiryHoursBefore,
        'quiet_hours_enabled': quietHoursEnabled,
        'quiet_start_hour': quietStartHour,
        'quiet_end_hour': quietEndHour,
        'updated_at': DateTime.now().toIso8601String(),
      };

  static int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}

/// خدمة إدارة الإشعارات فقط — لا ترسل Push خارجي.
class NotificationsAdminService {
  NotificationsAdminService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AdminNotificationItem>> fetchAll() async {
    final data = await _client
        .from('app_notifications')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map(
          (row) => AdminNotificationItem.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<AdminNotificationItem> upsert({
    String? id,
    required String title,
    required String body,
    required String type,
    required String status,
    String origin = 'manual',
    String audience = 'all',
    String destinationKind = 'home',
    String? destinationId,
    String? doctorId,
    String? labId,
    String? packageId,
    DateTime? scheduledAt,
    bool sendPushSuggested = false,
    String? idempotencyKey,
    String? templateKey,
    bool repeatEnabled = false,
    List<String> repeatDays = const [],
    int repeatHour = 9,
    int repeatMinute = 0,
  }) async {
    final source = NotificationTypes.sourceOf(type);
    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      'type': type,
      'status': status,
      'origin': origin,
      'source': source,
      'audience': audience,
      'destination_kind': destinationKind,
      'destination_id': destinationId,
      'doctor_id': doctorId,
      'lab_id': labId,
      'package_id': packageId,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'send_push_suggested': sendPushSuggested,
      'idempotency_key': idempotencyKey,
      'template_key': templateKey ?? type,
      'repeat_enabled': repeatEnabled,
      'repeat_days': repeatDays,
      'repeat_hour': repeatHour,
      'repeat_minute': repeatMinute,
      'is_active': status == NotificationStatus.sent,
      'updated_at': DateTime.now().toIso8601String(),
      if (status == NotificationStatus.sent)
        'sent_at': DateTime.now().toIso8601String(),
      if (status == NotificationStatus.cancelled)
        'cancelled_at': DateTime.now().toIso8601String(),
    };

    // تجاهل أعمدة غير موجودة في Schema تدريجيًا.
    final saved = await _persistFlexible(id: id, payload: payload);
    return AdminNotificationItem.fromMap(saved);
  }

  Future<Map<String, dynamic>> _persistFlexible({
    String? id,
    required Map<String, dynamic> payload,
  }) async {
    var data = Map<String, dynamic>.from(payload);
    for (var i = 0; i < 12; i++) {
      try {
        if (id == null || id.isEmpty) {
          final row =
              await _client.from('app_notifications').insert(data).select().single();
          return Map<String, dynamic>.from(row);
        }
        final row = await _client
            .from('app_notifications')
            .update(data)
            .eq('id', id)
            .select()
            .single();
        return Map<String, dynamic>.from(row);
      } on PostgrestException catch (e) {
        if (e.code != 'PGRST204') rethrow;
        final missing = _missingColumn(e.message);
        if (missing == null || !data.containsKey(missing)) rethrow;
        data.remove(missing);
      }
    }
    throw Exception('تعذر حفظ الإشعار بعد تجاهل أعمدة مفقودة');
  }

  String? _missingColumn(String message) {
    return RegExp(
      r"Could not find the '([^']+)' column",
      caseSensitive: false,
    ).firstMatch(message)?.group(1);
  }

  Future<void> setStatus(String id, String status) async {
    final payload = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
      'is_active': status == NotificationStatus.sent,
      if (status == NotificationStatus.sent)
        'sent_at': DateTime.now().toIso8601String(),
      if (status == NotificationStatus.cancelled)
        'cancelled_at': DateTime.now().toIso8601String(),
    };
    await _persistFlexible(id: id, payload: payload);
  }

  Future<void> delete(String id) async {
    await _client.from('app_notifications').delete().eq('id', id);
  }

  Future<NotificationSettings> fetchSettings() async {
    try {
      final row = await _client
          .from('notification_settings')
          .select()
          .eq('id', 'default')
          .maybeSingle();
      if (row == null) return const NotificationSettings();
      return NotificationSettings.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return const NotificationSettings();
    }
  }

  Future<void> saveSettings(NotificationSettings settings) async {
    await _client.from('notification_settings').upsert({
      'id': 'default',
      ...settings.toMap(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchDoctorsLite() async {
    List<dynamic> data;
    try {
      data = await _client
          .from('doctors')
          .select('id, doctor_name, specialty, notifications_enabled, is_active, display_order')
          .order('display_order', ascending: true);
    } catch (_) {
      data = await _client
          .from('doctors')
          .select('id, doctor_name, specialty, is_active')
          .order('doctor_name', ascending: true);
    }
    return data.map((row) {
      final m = Map<String, dynamic>.from(row as Map);
      final name = (m['doctor_name'] ?? m['name'] ?? '').toString().trim();
      m['doctor_name'] = name.isEmpty ? 'بدون اسم' : name;
      return m;
    }).toList();
  }

  Future<void> setDoctorNotifications(String doctorId, bool enabled) async {
    await _client
        .from('doctors')
        .update({'notifications_enabled': enabled})
        .eq('id', doctorId);
  }

  /// كل المختبرات — يدعم عمود lab_name أو name.
  Future<List<Map<String, dynamic>>> fetchLabsLite() async {
    List<dynamic> data;
    try {
      data = await _client
          .from('labs')
          .select()
          .order('display_order', ascending: true);
    } catch (_) {
      try {
        data = await _client.from('labs').select().order('lab_name');
      } catch (_) {
        data = await _client.from('labs').select();
      }
    }
    return data.map((row) {
      final m = Map<String, dynamic>.from(row as Map);
      final name =
          (m['lab_name'] ?? m['name'] ?? '').toString().trim();
      m['name'] = name.isEmpty ? 'مختبر بدون اسم' : name;
      m['lab_name'] = m['name'];
      return m;
    }).toList();
  }

  Future<void> setLabNotifications(String labId, bool enabled) async {
    await _client
        .from('labs')
        .update({'notifications_enabled': enabled})
        .eq('id', labId);
  }

  Future<List<Map<String, dynamic>>> fetchPackagesLite({String? labId}) async {
    try {
      if (labId != null && labId.isNotEmpty) {
        final data = await _client
            .from('lab_packages')
            .select('id, name:package_name, lab_id, notify_enabled, is_active')
            .eq('lab_id', labId)
            .order('package_name');
        return List<Map<String, dynamic>>.from(data);
      }
      final data = await _client
          .from('lab_packages')
          .select('id, name:package_name, lab_id, notify_enabled, is_active')
          .order('package_name');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      if (labId != null && labId.isNotEmpty) {
        final data = await _client
            .from('lab_packages')
            .select('id, name:package_name, lab_id, is_active')
            .eq('lab_id', labId)
            .order('package_name');
        return List<Map<String, dynamic>>.from(data);
      }
      final data = await _client
          .from('lab_packages')
          .select('id, name:package_name, lab_id, is_active')
          .order('package_name');
      return List<Map<String, dynamic>>.from(data);
    }
  }

  Future<void> setPackageNotify(String packageId, bool enabled) async {
    await _client
        .from('lab_packages')
        .update({'notify_enabled': enabled})
        .eq('id', packageId);
  }
}
