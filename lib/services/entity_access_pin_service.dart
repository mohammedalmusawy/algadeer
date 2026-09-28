import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// أرقام سرية محلية: صيدلية / مختبر + رقم إدارة (دخول صامت عند الحاجة).
/// لا يلمس إعدادات أخرى — تخزين منفصل في SharedPreferences.
class EntityAccessPinService {
  EntityAccessPinService._();
  static final EntityAccessPinService instance = EntityAccessPinService._();

  static const prefsKey = 'entity_access_pins_v1';
  /// الحد الأدنى فقط — الطول غير ثابت على 6.
  static const minPinLength = 4;
  static const maxPinLength = 32;
  static const adminKey = 'admin';

  /// واتساب إدارة الغدير عند نسيان الرقم السري.
  static const adminSupportWhatsApp = '07822202288';
  static const adminSupportWhatsAppDigits = '9647822202288';

  /// بعد نجاح الرقم السري تبقى الجلسة حتى الخروج من شاشة الإدارة.
  /// لا تنتهي أثناء العمل داخل الصفحة.
  Map<String, String> _pins = {};
  final Map<String, bool> _unlocked = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _pins = {
            for (final e in decoded.entries)
              if (e.key.toString().isNotEmpty && e.value != null)
                e.key.toString(): e.value.toString(),
          };
        }
      }
    } catch (e) {
      debugPrint('entity access pins load failed: $e');
      _pins = {};
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(_pins));
  }

  static String pharmacyKey(String id) => 'pharmacy:$id';
  static String labKey(String id) => 'lab:$id';

  /// يقبل طولاً مرناً (4–32) — أرقام أو حروف أو رموز بدون مسافات.
  static String? validatePinFormat(String raw) {
    final t = raw.trim();
    if (t.length < minPinLength) {
      return 'الرقم السري قصير جداً (أقل شيء $minPinLength خانات)';
    }
    if (t.length > maxPinLength) {
      return 'الرقم السري طويل جداً';
    }
    if (t.contains(RegExp(r'\s'))) {
      return 'بدون مسافات';
    }
    return null;
  }

  static String forgotPinWhatsAppMessage({
    required String entityTitle,
    required String entityKey,
  }) {
    return [
      'نسيت الرقم السري',
      'من منصة الغدير',
      'الاسم: $entityTitle',
      'المعرّف: $entityKey',
      'أرجو المساعدة بإعادة التعيين.',
    ].join('\n');
  }

  static String _encode(String pin) =>
      base64Url.encode(utf8.encode('v1|$pin'));

  static bool _matches(String stored, String input) {
    if (stored.isEmpty) return false;
    // دعم قيم قديمة غير مرمّزة إن وُجدت.
    if (stored == input.trim()) return true;
    return stored == _encode(input.trim());
  }

  Future<bool> hasAdminPin() async {
    await load();
    return (_pins[adminKey] ?? '').isNotEmpty;
  }

  Future<bool> hasEntityPin(String key) async {
    await load();
    return (_pins[key] ?? '').isNotEmpty;
  }

  Future<bool> verifyAdmin(String pin) async {
    await load();
    return _matches(_pins[adminKey] ?? '', pin);
  }

  Future<bool> verifyEntity(String key, String pin) async {
    await load();
    return _matches(_pins[key] ?? '', pin);
  }

  /// دخول الكيان أو رقم الإدارة — بصمت (بدون إخبار المستخدم).
  Future<bool> verifyEntityOrAdmin(String key, String pin) async {
    if (await verifyEntity(key, pin)) return true;
    if (await verifyAdmin(pin)) return true;
    return false;
  }

  Future<void> setAdminPin(String pin) async {
    final err = validatePinFormat(pin);
    if (err != null) throw ArgumentError(err);
    await load();
    _pins[adminKey] = _encode(pin.trim());
    await _persist();
  }

  Future<void> setEntityPin(String key, String pin) async {
    final err = validatePinFormat(pin);
    if (err != null) throw ArgumentError(err);
    await load();
    if (key == adminKey) {
      _pins[adminKey] = _encode(pin.trim());
    } else {
      _pins[key] = _encode(pin.trim());
    }
    await _persist();
  }

  Future<void> clearEntityPin(String key) async {
    await load();
    _pins.remove(key);
    await _persist();
  }

  bool hasValidSession(String key) => _unlocked[key] == true;

  void grantSession(String key) {
    _unlocked[key] = true;
  }

  void clearSession(String key) {
    _unlocked.remove(key);
  }

  /// للاختبارات فقط — إعادة تحميل من prefs.
  @visibleForTesting
  Future<void> debugReloadFromPrefs() async {
    _loaded = false;
    _pins = {};
    _unlocked.clear();
    await load();
  }
}
