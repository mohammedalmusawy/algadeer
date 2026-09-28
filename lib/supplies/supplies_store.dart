import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supply_models.dart';

/// تخزين محلي لمحلات المستلزمات — لا يكسر التطبيق بدون جدول.
class SuppliesStore {
  SuppliesStore._();
  static final SuppliesStore instance = SuppliesStore._();

  static const _prefsKey = 'supplies_local_v1';

  List<SupplyVendor> _items = List.of(SuppliesCatalog.items);
  bool _loaded = false;

  List<SupplyVendor> get items =>
      _items.where((p) => p.isActive).toList(growable: false);

  List<SupplyVendor> get allForAdmin => List.unmodifiable(_items);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) {
          _items = [
            for (final e in decoded)
              if (e is Map)
                SupplyVendor.fromMap(Map<String, dynamic>.from(e)),
          ];
        }
      }
    } catch (e) {
      debugPrint('supplies store load failed: $e');
      _items = List.of(SuppliesCatalog.items);
    }
    // دمج الكتالوج الافتراضي: محلات جديدة تظهر دون مسح تعديلات الإدارة.
    _items = _mergeWithCatalog(_items);
    _loaded = true;
  }

  void invalidate() {
    _loaded = false;
  }

  Future<void> reload() async {
    _loaded = false;
    await load();
  }

  static List<SupplyVendor> _mergeWithCatalog(List<SupplyVendor> saved) {
    final byId = {for (final v in saved) v.id: v};
    final out = <SupplyVendor>[];
    for (final c in SuppliesCatalog.items) {
      final s = byId.remove(c.id);
      out.add(s ?? c);
    }
    out.addAll(byId.values);
    return out;
  }

  Future<void> saveAll(List<SupplyVendor> items) async {
    _items = List.of(items);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_items.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> upsert(SupplyVendor item) async {
    await load();
    final next = List<SupplyVendor>.of(_items);
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
    final next = [
      for (final p in _items)
        if (p.id == id) p.copyWith(isActive: active) else p,
    ];
    await saveAll(next);
  }

  SupplyVendor? byId(String id) {
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// ترتيب حسب القرب (نفس منطق الصيدليات).
class SupplyDistance {
  SupplyDistance._();

  static const shatraLat = 31.4095;
  static const shatraLng = 46.1718;

  static double kmBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthKm = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthKm * c;
  }

  static List<SupplyVendor> sortByDistance(
    List<SupplyVendor> items, {
    required double originLat,
    required double originLng,
  }) {
    final indexed = <({SupplyVendor p, double? d, int i})>[
      for (var i = 0; i < items.length; i++)
        (
          p: items[i],
          d: items[i].latitude == null || items[i].longitude == null
              ? null
              : kmBetween(
                  originLat,
                  originLng,
                  items[i].latitude!,
                  items[i].longitude!,
                ),
          i: i,
        ),
    ];
    indexed.sort((a, b) {
      if (a.d == null && b.d == null) return a.i.compareTo(b.i);
      if (a.d == null) return 1;
      if (b.d == null) return -1;
      final c = a.d!.compareTo(b.d!);
      return c != 0 ? c : a.i.compareTo(b.i);
    });
    return [for (final e in indexed) e.p];
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}
