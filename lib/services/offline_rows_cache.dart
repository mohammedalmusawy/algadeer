import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نسخة محلية لآخر صفوف ناجحة من سوبربيس (مثل إنستا/فيس: بدون نت
/// تظهر آخر بيانات شافها المستخدم بدل شاشة فارغة).
///
/// قراءة عامة فقط — لا تُستخدم لبيانات المريض أو الإدارة.
abstract final class OfflineRowsCache {
  static const _prefix = 'offline_rows_v1_';
  static const _atSuffix = '__at';

  /// آخر مرة استُخدمت فيها النسخة المحلية بدل الشبكة (لإظهار تنبيه).
  static final ValueNotifier<DateTime?> lastOfflineServe =
      ValueNotifier<DateTime?>(null);

  static Object? _encodable(Object? v) => v?.toString();

  static Future<void> save(String key, List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefix$key',
        jsonEncode(rows, toEncodable: _encodable),
      );
      await prefs.setString(
        '$_prefix$key$_atSuffix',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('OfflineRowsCache.save($key) failed: $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return [
        for (final e in decoded)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (e) {
      debugPrint('OfflineRowsCache.read($key) failed: $e');
      return null;
    }
  }

  static Future<DateTime?> savedAt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(prefs.getString('$_prefix$key$_atSuffix') ?? '');
  }

  /// أقصى انتظار للشبكة قبل ما نعرض النسخة المحفوظة (نت ضعيف = لا تعليق).
  static const defaultTimeout = Duration(seconds: 10);

  /// يجرب الشبكة؛ عند النجاح يحفظ نسخة، وعند الفشل أو التأخر يرجع آخر نسخة.
  /// إن لم توجد نسخة يُعاد رمي الخطأ الأصلي حتى تبقى رسائل الخطأ كما هي.
  static Future<List<Map<String, dynamic>>> fetchOrCache(
    String key,
    Future<List<Map<String, dynamic>>> Function() fetch, {
    Duration timeout = defaultTimeout,
  }) async {
    try {
      final rows = await fetch().timeout(timeout);
      await save(key, rows);
      return rows;
    } catch (e) {
      final cached = await read(key);
      if (cached == null) rethrow;
      debugPrint('OfflineRowsCache: serving $key from device (${cached.length})');
      lastOfflineServe.value = DateTime.now();
      return cached;
    }
  }
}
