import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/content_conflict.dart';
import 'service_center_models.dart';

/// كتالوج مشترك في `service_centers`.
///
/// ذاكرة الجهاز تحفظ آخر جلب ناجح فقط لتعذّر الشبكة، ولا تُنشئ مراكز
/// ولا تُظهر مسودة لم تُكتب في الجدول.
class ServiceCentersStore {
  ServiceCentersStore._();
  static final ServiceCentersStore instance = ServiceCentersStore._();

  static const _cacheKey = 'service_centers_shared_cache_v1';

  List<ServiceCenter> _items = const [];
  bool _sharedReady = false;
  bool _loaded = false;
  String? loadError;

  List<ServiceCenter> get sharedItems => List.unmodifiable(_items);
  bool get sharedReady => _sharedReady;

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final rows = await Supabase.instance.client
          .from('service_centers')
          .select(
            'id,kind,name,is_active,display_order,profile,content_revision',
          );
      final parsed = <ServiceCenter>[];
      for (final row in rows) {
        try {
          parsed.add(
            ServiceCenter.fromSharedRow(Map<String, dynamic>.from(row as Map)),
          );
        } catch (e) {
          debugPrint('service center row skipped: $e');
        }
      }
      _items = parsed;
      _sharedReady = true;
      loadError = null;
      await prefs.setString(
        _cacheKey,
        jsonEncode(_items.map((e) => e.toMap()).toList()),
      );
    } catch (e) {
      debugPrint('service centers shared load failed: $e');
      final cached = _readCache(prefs.getString(_cacheKey));
      if (cached.isNotEmpty) {
        _items = cached;
        _sharedReady = true;
        loadError = 'offline';
      } else {
        _items = const [];
        _sharedReady = false;
        loadError = '$e';
      }
    }
    _loaded = true;
  }

  void invalidate() {
    _loaded = false;
  }

  Future<void> reload() async {
    _loaded = false;
    await load(force: true);
  }

  Future<ServiceCenter> upsert(ServiceCenter item) async {
    await load();
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw StateError('سجّل دخول الإدارة قبل حفظ المركز.');
    }
    final hosted = await _hostDataImages(item);
    final published = await _pushShared(hosted);
    _replace(published);
    await _writeCache();
    return published;
  }

  Future<void> setActive(ServiceCenter item, bool active) {
    return upsert(item.copyWith(isActive: active));
  }

  Future<void> delete(ServiceCenter item) async {
    await load();
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw StateError('سجّل دخول الإدارة قبل حذف المركز.');
    }
    await client.from('service_centers').delete().eq('id', item.id);
    _items = [
      for (final center in _items)
        if (center.id != item.id) center,
    ];
    await _writeCache();
  }

  Future<String> uploadImage({
    required String centerId,
    required Uint8List bytes,
    required bool png,
  }) async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw StateError('سجّل دخول الإدارة قبل رفع الصورة.');
    }
    final path =
        'service-centers/$centerId/${DateTime.now().microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
    await client.storage.from('clinic-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: png ? 'image/png' : 'image/jpeg',
            upsert: false,
          ),
        );
    return client.storage.from('clinic-media').getPublicUrl(path);
  }

  ServiceCenter? byId(String id) {
    for (final center in _items) {
      if (center.id == id) return center;
    }
    return null;
  }

  List<ServiceCenter> _readCache(String? raw) => decodeCache(raw);

  /// آخر جلب ناجح كما يُعاد فتحه من ذاكرة الجهاز. لا ينشئ مراكز.
  static List<ServiceCenter> decodeCache(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            ServiceCenter.fromMap(Map<String, dynamic>.from(item)),
      ];
    } catch (e) {
      debugPrint('service centers cache parse failed: $e');
      return const [];
    }
  }

  void _replace(ServiceCenter item) {
    final next = List<ServiceCenter>.of(_items);
    final index = next.indexWhere((c) => c.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    _items = next;
    _sharedReady = true;
    loadError = null;
  }

  Future<void> _writeCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(_items.map((e) => e.toMap()).toList()),
    );
  }

  Future<ServiceCenter> _pushShared(ServiceCenter item) async {
    final client = Supabase.instance.client;
    final payload = {
      'kind': item.kind.dbValue,
      'name': item.name.trim(),
      'is_active': item.isActive,
      'display_order': item.displayOrder,
      'profile': item.profileMap(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (item.contentRevision <= 0) {
      try {
        await client.from('service_centers').insert({
          'id': item.id,
          ...payload,
          'content_revision': 1,
        });
      } on PostgrestException catch (e) {
        if (e.code == '23505') throw const ContentConflictException();
        rethrow;
      }
      return item.copyWith(contentRevision: 1);
    }
    final nextRevision = item.contentRevision + 1;
    final updated = await client
        .from('service_centers')
        .update({
          ...payload,
          'content_revision': nextRevision,
        })
        .eq('id', item.id)
        .eq('content_revision', item.contentRevision)
        .select('id');
    if ((updated as List).isEmpty) {
      throw const ContentConflictException();
    }
    return item.copyWith(contentRevision: nextRevision);
  }

  Future<ServiceCenter> _hostDataImages(ServiceCenter item) async {
    Future<String> host(String value) async {
      final raw = value.trim();
      if (!raw.startsWith('data:')) return value;
      final comma = raw.indexOf(',');
      if (comma < 0) return value;
      final bytes = base64Decode(raw.substring(comma + 1));
      final png = raw.contains('image/png');
      return uploadImage(
        centerId: item.id,
        bytes: Uint8List.fromList(bytes),
        png: png,
      );
    }

    return item.copyWith(
      imageUrl: await host(item.imageUrl),
      logoUrl: await host(item.logoUrl),
    );
  }
}
