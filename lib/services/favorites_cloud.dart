import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// مفاتيح المفضلة المحلية (نفس اللي يستخدمها التطبيق من قبل).
abstract final class FavoriteKeys {
  static const doctors = 'favoriteDoctorIds';
  static const labs = 'favoriteLabIds';
  static const radiology = 'favoriteRadiologyIds';
  static const pharmacies = 'favoritePharmacyIds';
}

/// يدمج قائمتين بدون تكرار، ويحافظ على ترتيب الأولى.
List<String> unionFavorites(List<String> a, List<String> b) {
  final out = <String>[];
  final seen = <String>{};
  for (final id in [...a, ...b]) {
    final v = id.trim();
    if (v.isEmpty || !seen.add(v)) continue;
    out.add(v);
  }
  return out;
}

/// المفضلة بحساب المستخدم (جدول user_favorites) حتى ما تضيع إذا انمسح
/// التطبيق أو تبدّل الموبايل. بدون تسجيل دخول تبقى محلية مثل قبل.
class FavoritesCloud {
  FavoritesCloud._();
  static final FavoritesCloud instance = FavoritesCloud._();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// معرّف المستخدم المسجّل، أو null.
  String? get userId {
    try {
      return _client?.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  bool get isSignedIn => userId != null;

  /// يرفع القائمة لحساب المستخدم (إذا مسجّل). ما يرمي أخطاء.
  Future<void> push(String key, List<String> ids) async {
    final uid = userId;
    final client = _client;
    if (uid == null || client == null) return;
    try {
      await client.from('user_favorites').upsert({
        'user_id': uid,
        'list_key': key,
        'ids': ids,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('favorites push $key failed: $e');
    }
  }

  /// يدمج المحفوظ محلياً ويا الحساب، يحفظ النتيجة محلياً ويرفعها.
  /// يرجع القائمة النهائية (المحلية لو ماكو حساب أو نت).
  Future<List<String>> merge(String key, List<String> local) async {
    final uid = userId;
    final client = _client;
    if (uid == null || client == null) return local;
    try {
      final row = await client
          .from('user_favorites')
          .select('ids')
          .eq('user_id', uid)
          .eq('list_key', key)
          .maybeSingle();
      final cloud = [
        for (final v in (row?['ids'] as List?) ?? const []) v.toString(),
      ];
      final merged = unionFavorites(local, cloud);
      if (merged.length != local.length) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(key, merged);
      }
      if (merged.length != cloud.length) await push(key, merged);
      return merged;
    } catch (e) {
      debugPrint('favorites merge $key failed: $e');
      return local;
    }
  }

  /// بعد تسجيل الدخول: يدمج كل القوائم.
  Future<void> syncAll() async {
    if (!isSignedIn) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      FavoriteKeys.doctors,
      FavoriteKeys.labs,
      FavoriteKeys.radiology,
      FavoriteKeys.pharmacies,
    ]) {
      await merge(key, prefs.getStringList(key) ?? const []);
    }
  }
}
