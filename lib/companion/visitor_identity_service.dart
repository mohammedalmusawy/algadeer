import 'package:shared_preferences/shared_preferences.dart';

/// هوية الجهاز/الزائر — مصدر واحد لـ ownerKey.
///
/// يعيد استخدام مفتاح `visitor_rating_key` الحالي للتوافق مع
/// app_users / التقييمات. ليس مفتاح مصادقة؛ للاستخدام المحلي فقط.
class VisitorIdentityService {
  VisitorIdentityService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  /// نفس المفتاح المستخدم تاريخياً في الإحصاءات والتقييمات.
  static const prefsKey = 'visitor_rating_key';

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// للاختبارات.
  void setPrefsForTesting(SharedPreferences prefs) {
    _prefs = prefs;
  }

  /// مفتاح مالك الملف الشخصي — ليس display name.
  Future<String> ownerKey() async {
    final p = await _ensure();
    var key = p.getString(prefsKey)?.trim() ?? '';
    if (key.length < 8) {
      final now = DateTime.now();
      key =
          'u_${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch % 1000000}';
      await p.setString(prefsKey, key);
    }
    return key;
  }
}
