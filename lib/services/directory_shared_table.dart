import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// جدول دليل مشترك بشكل الصيدليات: {id, name, is_active, profile, content_revision}.
/// يُستخدم للعلاج الطبيعي (physio_centers) والتجهيزات (supply_vendors) حتى
/// تعديلات الإدارة والمالك توصل لكل الأجهزة، مع نسخة محفوظة للعمل بدون نت.
class DirectorySharedTable {
  const DirectorySharedTable(this.table);

  final String table;

  String get _cacheKey => 'directory_shared_cache_v1_$table';

  /// صفوف الدليل المشترك، أو آخر نسخة محفوظة إذا ماكو نت، أو null إذا ماكو شي.
  Future<List<Map<String, dynamic>>?> fetch() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      prefs = null;
    }
    try {
      final rows = await Supabase.instance.client
          .from(table)
          .select('id,name,is_active,profile,content_revision');
      final list = [for (final r in rows) Map<String, dynamic>.from(r)];
      try {
        await prefs?.setString(_cacheKey, jsonEncode(list));
      } catch (_) {}
      return list;
    } catch (e) {
      debugPrint('$table shared load failed: $e');
      final raw = prefs?.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) return null;
        return [
          for (final r in decoded)
            if (r is Map) Map<String, dynamic>.from(r),
        ];
      } catch (_) {
        return null;
      }
    }
  }

  /// يحوّل صف الدليل لخريطة النموذج: بيانات الجهاز ثم الملف المشترك فوكها.
  static Map<String, dynamic> mergeRow(
    Map<String, dynamic> base,
    Map<String, dynamic> row,
  ) {
    final profile = row['profile'] is Map
        ? Map<String, dynamic>.from(row['profile'] as Map)
        : <String, dynamic>{};
    final merged = <String, dynamic>{...base, ...profile};
    // شعار فارغ بالملف المشترك ما يمسح شعار الجهاز.
    final logo = profile['logoUrl']?.toString().trim() ?? '';
    if (logo.isEmpty && base['logoUrl'] != null) {
      merged['logoUrl'] = base['logoUrl'];
    }
    merged['id'] = row['id']?.toString() ?? base['id'];
    final name = row['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) merged['name'] = name;
    merged['isActive'] = row['is_active'] != false;
    merged['contentRevision'] =
        int.tryParse('${row['content_revision'] ?? 1}') ?? 1;
    return merged;
  }

  /// نشر نسخة الإدارة. يرجع رقم النسخة الجديد.
  Future<int> upsert({
    required String id,
    required String name,
    required bool isActive,
    required Map<String, dynamic> profile,
    required int contentRevision,
  }) async {
    final clean = Map<String, dynamic>.from(profile)..remove('contentRevision');
    final next = contentRevision <= 0 ? 1 : contentRevision + 1;
    await Supabase.instance.client.from(table).upsert({
      'id': id,
      'name': name,
      'is_active': isActive,
      'profile': clean,
      'content_revision': next,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    return next;
  }
}
