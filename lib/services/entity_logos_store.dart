import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// شعارات مشتركة للكتالوج المحلي (علاج طبيعي / مستلزمات).
/// المحتوى يبقى على الجهاز؛ الشعار يصل لكل المستخدمين عبر هذا الجدول.
class EntityLogosStore {
  EntityLogosStore._();
  static final EntityLogosStore instance = EntityLogosStore._();

  static const physio = 'physio';
  static const supplies = 'supplies';

  final Map<String, Map<String, String>> _byKind = {};
  final Set<String> _loadedKinds = {};

  Map<String, String> logosFor(String kind) =>
      Map.unmodifiable(_byKind[kind] ?? const {});

  bool isKindLoaded(String kind) => _loadedKinds.contains(kind);

  Future<Map<String, String>> loadKind(String kind, {bool force = false}) async {
    if (_loadedKinds.contains(kind) && !force) {
      return logosFor(kind);
    }
    try {
      final rows = await Supabase.instance.client
          .from('entity_logos')
          .select('entity_id,logo_url')
          .eq('entity_type', kind);
      final map = <String, String>{};
      for (final row in rows as List) {
        final id = row['entity_id']?.toString() ?? '';
        final url = row['logo_url']?.toString() ?? '';
        if (id.isNotEmpty && url.trim().isNotEmpty) {
          map[id] = url.trim();
        }
      }
      _byKind[kind] = map;
      _loadedKinds.add(kind);
    } catch (e) {
      debugPrint('entity_logos load failed ($kind): $e');
      _byKind[kind] ??= {};
      // لا نضع _loadedKinds حتى ينجح مرة؛ إعادة المحاولة ممكنة.
    }
    return logosFor(kind);
  }

  Future<void> upsert({
    required String kind,
    required String entityId,
    required String logoUrl,
  }) async {
    final id = entityId.trim();
    if (id.isEmpty) {
      throw StateError('معرّف المركز مطلوب لحفظ الشعار.');
    }
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw StateError('سجّل دخول الإدارة قبل حفظ الشعار المشترك.');
    }
    final url = logoUrl.trim();
    if (url.isEmpty) {
      await client
          .from('entity_logos')
          .delete()
          .eq('entity_type', kind)
          .eq('entity_id', id);
      final map = Map<String, String>.of(_byKind[kind] ?? {});
      map.remove(id);
      _byKind[kind] = map;
      return;
    }
    await client.from('entity_logos').upsert({
      'entity_type': kind,
      'entity_id': id,
      'logo_url': url,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    final map = Map<String, String>.of(_byKind[kind] ?? {});
    map[id] = url;
    _byKind[kind] = map;
    _loadedKinds.add(kind);
  }

  /// يطبّق الشعارات المشتركة فوق قائمة محلية دون تغيير بقية الحقول.
  /// عند [clearMissing] يُزال الشعار المحلي إن لم يُنشر في الجدول المشترك.
  static List<T> applyLogos<T>({
    required List<T> items,
    required Map<String, String> logos,
    required String Function(T item) idOf,
    required T Function(T item, String logoUrl) withLogo,
    bool clearMissing = false,
  }) {
    if (!clearMissing && logos.isEmpty) return List.of(items);
    return [
      for (final item in items)
        logos.containsKey(idOf(item))
            ? withLogo(item, logos[idOf(item)]!)
            : clearMissing
                ? withLogo(item, '')
                : item,
    ];
  }
}
