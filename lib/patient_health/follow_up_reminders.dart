import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// وقت تذكير يومي (ساعة:دقيقة بتوقيت الجهاز).
@immutable
class ReminderTime implements Comparable<ReminderTime> {
  const ReminderTime(this.hour, this.minute);

  final int hour;
  final int minute;

  static ReminderTime? parse(String raw) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return ReminderTime(h, min);
  }

  String get storage =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// عرض عراقي: 8:30 صباحاً / 9:00 مساءً.
  String get label {
    final period = hour < 12 ? 'صباحاً' : 'مساءً';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  int compareTo(ReminderTime other) =>
      (hour * 60 + minute) - (other.hour * 60 + other.minute);

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// أقصى عدد تذكيرات لكل مرض (مثلاً صبح وظهر وليل).
const maxRemindersPerCondition = 3;

/// نص الإشعار عام عمداً: شاشة القفل ما تكشف اسم المرض.
const reminderNotificationTitle = 'تذكير من الغدير';
const reminderNotificationBody =
    'وقت قياسك اليومي. سجّل القراءة ببطاقة المتابعة.';

/// معرّف ثابت لكل (مرض، رقم التذكير) — حتى نلغي ونعيد الجدولة بدون تكرار.
int reminderNotificationId(String userId, String conditionId, int slot) {
  // FNV-1a 32-bit — ثابت بين التشغيلات (مو hashCode).
  var h = 0x811c9dc5;
  for (final unit in utf8.encode('$userId|$conditionId')) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  // آخر رقم للـ slot، والنتيجة موجبة ضمن int32.
  return ((h & 0x0fffffff) * 10 + slot) & 0x7fffffff;
}

/// أقرب موعد قادم لوقت يومي.
DateTime nextDailyFire(DateTime now, ReminderTime time) {
  var at = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
  return at;
}

/// التخزين على الجهاز فقط.
class FollowUpReminderStore {
  const FollowUpReminderStore();

  static String keyFor(String userId, String conditionId) =>
      'follow_up_reminders_v1_${userId}_$conditionId';

  Future<List<ReminderTime>> load(String userId, String conditionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(keyFor(userId, conditionId)) ?? const [];
      final out = <ReminderTime>{
        for (final r in raw) ?ReminderTime.parse(r),
      }.toList()..sort();
      return out.take(maxRemindersPerCondition).toList();
    } catch (e) {
      debugPrint('FollowUpReminderStore.load failed: $e');
      return const [];
    }
  }

  Future<void> save(
    String userId,
    String conditionId,
    List<ReminderTime> times,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = keyFor(userId, conditionId);
    if (times.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setStringList(key, [for (final t in times) t.storage]);
  }
}

/// واجهة الجدولة — بالاختبار تنبدل بنسخة وهمية.
abstract class ReminderScheduler {
  bool get isSupported;
  Future<bool> requestPermission();
  Future<void> scheduleDaily(int id, ReminderTime time);
  Future<void> cancel(int id);
}

/// إشعارات محلية حقيقية (أندرويد وآيفون). لا خادم ولا إنترنت.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'follow_up_reminders',
    'تذكير القياس',
    channelDescription: 'تذكير يومي بتسجيل قراءات بطاقة المتابعة',
    importance: Importance.high,
    priority: Priority.high,
  );

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _init() async {
    if (_ready) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<void> scheduleDaily(int id, ReminderTime time) async {
    if (!isSupported) return;
    await _init();
    // بتوقيت الجهاز: نحوّل الموعد المحلي القادم لـ UTC ونكرره يومياً بنفس
    // الساعة (العراق بلا توقيت صيفي، فالساعة ثابتة).
    final next = nextDailyFire(DateTime.now(), time).toUtc();
    await _plugin.zonedSchedule(
      id: id,
      title: reminderNotificationTitle,
      body: reminderNotificationBody,
      scheduledDate: tz.TZDateTime.from(next, tz.UTC),
      notificationDetails: const NotificationDetails(
        android: _channel,
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!isSupported) return;
    await _init();
    await _plugin.cancel(id: id);
  }
}

/// يحفظ الأوقات ويعيد جدولة تذكيرات مرض واحد (يلغي القديمة أولاً).
Future<void> applyFollowUpReminders({
  required ReminderScheduler scheduler,
  required FollowUpReminderStore store,
  required String userId,
  required String conditionId,
  required List<ReminderTime> times,
}) async {
  final sorted = (times.toSet().toList()..sort())
      .take(maxRemindersPerCondition)
      .toList();
  for (var slot = 0; slot < maxRemindersPerCondition; slot++) {
    await scheduler.cancel(reminderNotificationId(userId, conditionId, slot));
  }
  for (var slot = 0; slot < sorted.length; slot++) {
    await scheduler.scheduleDaily(
      reminderNotificationId(userId, conditionId, slot),
      sorted[slot],
    );
  }
  await store.save(userId, conditionId, sorted);
}
