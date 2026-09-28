import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pharmacy_models.dart';

/// تخزين محلي لإدارة الصيدليات — لا يكسر التطبيق إن غاب الجدول/الشبكة.
class PharmaciesStore {
  PharmaciesStore._();
  static final PharmaciesStore instance = PharmaciesStore._();

  static const _prefsKey = 'pharmacies_local_v1';

  List<PharmacyItem> _items = List.of(PharmaciesCatalog.items);
  bool _loaded = false;

  List<PharmacyItem> get items =>
      _items.where((p) => p.isActive).toList(growable: false);

  List<PharmacyItem> get allForAdmin => List.unmodifiable(_items);

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
                PharmacyItem.fromMap(Map<String, dynamic>.from(e)),
          ];
        }
      }
    } catch (e) {
      debugPrint('pharmacies store load failed: $e');
      _items = List.of(PharmaciesCatalog.items);
    }
    // دمج الكتالوج الجديد مع المحفوظ (باقات ناقصة + مكملات).
    _items = [
      for (final p in _items)
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
    _items = List.of(items);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_items.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> upsert(PharmacyItem item) async {
    await load();
    final next = List<PharmacyItem>.of(_items);
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

  PharmacyItem? byId(String id) {
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }
}
