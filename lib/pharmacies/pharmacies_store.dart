import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/content_conflict.dart';
import 'pharmacy_models.dart';

/// ما يراه الزائر بعد أول جلب ناجح هو الصفوف المنشورة النشطة فقط.
/// قبل ذلك: النسخة المحلية ثم الكتالوج المضمّن.
List<PharmacyItem> pharmacyPublicItems({
  required List<PharmacyItem> shared,
  required bool sharedReady,
  required List<PharmacyItem> local,
}) {
  if (sharedReady) {
    return [for (final item in shared) if (item.isActive) item];
  }
  final source = local.isNotEmpty ? local : PharmaciesCatalog.items;
  return [for (final item in source) if (item.isActive) item];
}

/// الإدارة ترى المنشور، وتُبقي الصيدليات الموجودة على الجهاز فقط حتى تُنشر.
List<PharmacyItem> pharmacyAdminItems({
  required List<PharmacyItem> shared,
  required bool sharedReady,
  required List<PharmacyItem> local,
}) {
  final base = local.isNotEmpty ? local : PharmaciesCatalog.items;
  final byId = <String, PharmacyItem>{for (final item in base) item.id: item};
  if (sharedReady && shared.isNotEmpty) {
    for (final item in shared) {
      byId[item.id] = item;
    }
  }
  return byId.values.toList(growable: false);
}

/// الكتالوج المشترك في `pharmacies` هو ما يراه الزوار. النسخة المحلية لا تُحذف.
class PharmaciesStore {
  PharmaciesStore._();
  static final PharmaciesStore instance = PharmaciesStore._();

  static const _prefsKey = 'pharmacies_local_v1';
  static const _sharedCacheKey = 'pharmacies_shared_cache_v1';
  static const _sharedSeenKey = 'pharmacies_catalog_seen_v1';

  List<PharmacyItem> _local = [];
  List<PharmacyItem> _shared = [];
  bool _sharedReady = false;
  bool _loaded = false;
  String? lastShareError;

  List<PharmacyItem> get items => pharmacyPublicItems(
        shared: _shared,
        sharedReady: _sharedReady,
        local: _local,
      );

  List<PharmacyItem> get allForAdmin => pharmacyAdminItems(
        shared: _shared,
        sharedReady: _sharedReady,
        local: _local,
      );

  bool get hasSharedCatalog => _sharedReady && _shared.isNotEmpty;

  /// أول جلب مشترك نجح (حتى لو كانت النتيجة فارغة).
  bool get sharedCatalogReady => _sharedReady;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _local = _readList(prefs.getString(_prefsKey));
    _shared = _readList(prefs.getString(_sharedCacheKey));
    final seen = prefs.getBool(_sharedSeenKey) ?? false;
    _sharedReady = seen;
    try {
      final rows = await Supabase.instance.client
          .from('pharmacies')
          .select('id,name,is_active,profile,content_revision');
      _shared = [
        for (final row in rows) _fromSharedRow(Map<String, dynamic>.from(row)),
      ];
      _sharedReady = true;
      await prefs.setBool(_sharedSeenKey, true);
      await prefs.setString(
        _sharedCacheKey,
        jsonEncode(_shared.map((e) => e.toMap()).toList()),
      );
    } catch (e) {
      debugPrint('pharmacies shared load failed: $e');
      _sharedReady = seen;
    }
    _local = [
      for (final p in _local)
        p.copyWith(bundles: PharmaciesCatalog.mergeWithCatalog(p.bundles)),
    ];
    _loaded = true;
  }

  /// يُبطِل الكاش المحلي — التعديلات الإدارية تظهر بعد [reload]/[load].
  void invalidate() {
    _loaded = false;
  }

  Future<void> reload() async {
    _loaded = false;
    await load();
  }

  Future<void> saveAll(List<PharmacyItem> items) async {
    _local = List.of(items);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_local.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> upsert(PharmacyItem item) async {
    await load();
    lastShareError = null;
    final next = List<PharmacyItem>.of(_local);
    final i = next.indexWhere((p) => p.id == item.id);
    if (i >= 0) {
      next[i] = item;
    } else {
      next.add(item);
    }
    await saveAll(next);
    try {
      final hosted = await _hostDataImages(item);
      await _pushShared(hosted);
      if (hosted != item) {
        final refreshed = List<PharmacyItem>.of(_local);
        final at = refreshed.indexWhere((p) => p.id == hosted.id);
        if (at >= 0) refreshed[at] = hosted;
        await saveAll(refreshed);
      }
    } on ContentConflictException {
      rethrow;
    } catch (e) {
      lastShareError = '$e';
      debugPrint('pharmacy shared publish failed: $e');
    }
  }

  /// ينشر النسخة المحلية إن وُجدت، وإلا الكتالوج المضمّن. لا يمسح النسخة المحلية.
  Future<String?> publishDeviceCopy() async {
    await load();
    final source = _local.isNotEmpty
        ? List<PharmacyItem>.of(_local)
        : List<PharmacyItem>.of(PharmaciesCatalog.items);
    String? error;
    for (final item in source) {
      try {
        final hosted = await _hostDataImages(item);
        await _pushShared(hosted);
      } on ContentConflictException {
        error = contentConflictMessage;
        debugPrint('pharmacy publish copy conflict: $error');
      } catch (e) {
        error = '$e';
        debugPrint('pharmacy publish copy failed: $e');
      }
    }
    lastShareError = error;
    return error;
  }

  /// بعد حفظ المالك عبر الدالة: تُحدَّث النسخة المنشورة دون كتابة عامة من العميل.
  Future<void> cachePublished(PharmacyItem item) async {
    await load();
    _replaceShared(item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sharedCacheKey,
      jsonEncode(_shared.map((e) => e.toMap()).toList()),
    );
    final next = List<PharmacyItem>.of(_local);
    final i = next.indexWhere((p) => p.id == item.id);
    if (i >= 0) {
      next[i] = item;
    } else {
      next.add(item);
    }
    await saveAll(next);
  }

  Future<void> setActive(String id, bool active) async {
    await load();
    final current = byId(id);
    if (current == null) return;
    await upsert(current.copyWith(isActive: active));
  }

  PharmacyItem? byId(String id) {
    for (final p in allForAdmin) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<PharmacyItem> _readList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final e in decoded)
          if (e is Map) PharmacyItem.fromMap(Map<String, dynamic>.from(e)),
      ];
    } catch (e) {
      debugPrint('pharmacies list parse failed: $e');
      return [];
    }
  }

  PharmacyItem _fromSharedRow(Map<String, dynamic> row) {
    final profile = row['profile'];
    final map = profile is Map
        ? Map<String, dynamic>.from(profile)
        : <String, dynamic>{};
    map['id'] = row['id']?.toString() ?? map['id']?.toString() ?? '';
    if (row['name'] != null) map['name'] = row['name'].toString();
    if (row.containsKey('is_active')) map['isActive'] = row['is_active'] == true;
    if (row.containsKey('content_revision')) {
      map['content_revision'] = row['content_revision'];
      map['contentRevision'] = row['content_revision'];
    }
    return PharmacyItem.fromMap(map);
  }

  void _replaceShared(PharmacyItem item) {
    final next = List<PharmacyItem>.of(_shared);
    final i = next.indexWhere((p) => p.id == item.id);
    if (i >= 0) {
      next[i] = item;
    } else {
      next.add(item);
    }
    _shared = next;
    _sharedReady = true;
  }

  Future<void> _pushShared(PharmacyItem item) async {
    final client = Supabase.instance.client;
    final nextRevision = item.contentRevision + 1;
    final payload = {
      'name': item.name,
      'is_active': item.isActive,
      'profile': item.toMap(),
      'content_revision': nextRevision,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final updated = await client
        .from('pharmacies')
        .update(payload)
        .eq('id', item.id)
        .eq('content_revision', item.contentRevision)
        .select('id');
    if ((updated as List).isEmpty) {
      final existing = await client.from('pharmacies').select('id').eq('id', item.id);
      if ((existing as List).isNotEmpty) {
        throw const ContentConflictException();
      }
      try {
        await client.from('pharmacies').insert({
          'id': item.id,
          ...payload,
          'content_revision': 1,
        });
      } on PostgrestException catch (e) {
        if (e.code == '23505') throw const ContentConflictException();
        rethrow;
      }
    }
    final published = item.copyWith(
      contentRevision: (updated as List).isEmpty ? 1 : nextRevision,
    );
    _replaceShared(published);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sharedSeenKey, true);
    await prefs.setString(
      _sharedCacheKey,
      jsonEncode(_shared.map((e) => e.toMap()).toList()),
    );
  }

  bool _containsDataImage(PharmacyItem item) {
    bool data(String value) => value.trim().startsWith('data:');
    if (data(item.imageUrl) ||
        data(item.logoUrl) ||
        data(item.offerImageUrl) ||
        data(item.offerIconUrl)) {
      return true;
    }
    return item.bundles.any((bundle) => data(bundle.imageUrl));
  }

  Future<PharmacyItem> _hostDataImages(PharmacyItem item) async {
    if (!_containsDataImage(item)) return item;
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw StateError(
        'الصور ما زالت على هذا الجهاز. سجّل دخول الإدارة ثم أعد النشر.',
      );
    }
    Future<String> host(String value) async {
      if (!value.trim().startsWith('data:')) return value;
      final comma = value.indexOf(',');
      if (comma < 0) return value;
      final bytes = base64Decode(value.substring(comma + 1));
      final png = value.contains('image/png');
      final path =
          'pharmacies/${item.id}/${DateTime.now().microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
      await client.storage.from('clinic-media').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: png ? 'image/png' : 'image/jpeg',
              upsert: false,
            ),
          );
      return client.storage.from('clinic-media').getPublicUrl(path);
    }

    final bundles = <PharmacyBundle>[];
    for (final bundle in item.bundles) {
      bundles.add(bundle.copyWith(imageUrl: await host(bundle.imageUrl)));
    }
    return item.copyWith(
      imageUrl: await host(item.imageUrl),
      logoUrl: await host(item.logoUrl),
      offerImageUrl: await host(item.offerImageUrl),
      offerIconUrl: await host(item.offerIconUrl),
      bundles: bundles,
    );
  }
}
