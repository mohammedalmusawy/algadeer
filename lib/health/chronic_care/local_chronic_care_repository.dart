import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../companion/visitor_identity_service.dart';
import 'chronic_care_models.dart';

/// مستودع زمني محلي للمتابعة المزمنة — منفصل عن التشخيص والملف الشخصي.
abstract class ChronicCareRepository {
  Future<ChronicCareStore> load();
  Future<ChronicCareStore> save(ChronicCareStore store);
  Future<void> clearAll();
}

class LocalChronicCareRepository implements ChronicCareRepository {
  LocalChronicCareRepository({
    SharedPreferences? prefs,
    VisitorIdentityService? identity,
  })  : _prefs = prefs,
        _identity = identity ?? VisitorIdentityService(prefs: prefs);

  SharedPreferences? _prefs;
  final VisitorIdentityService _identity;

  static const storageKey = 'pc_chronic_care_store_v1';

  void setPrefsForTesting(SharedPreferences prefs) {
    _prefs = prefs;
    _identity.setPrefsForTesting(prefs);
  }

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<ChronicCareStore> load() async {
    final p = await _ensure();
    final raw = p.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      final owner = await _identity.ownerKey();
      return ChronicCareStore(ownerKey: owner);
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final store = ChronicCareStore.fromStorageMap(map);
      if (store.ownerKey.isEmpty) {
        final owner = await _identity.ownerKey();
        return store.copyWith(ownerKey: owner);
      }
      return store;
    } catch (_) {
      final owner = await _identity.ownerKey();
      return ChronicCareStore(ownerKey: owner);
    }
  }

  @override
  Future<ChronicCareStore> save(ChronicCareStore store) async {
    final p = await _ensure();
    final owner = store.ownerKey.isEmpty
        ? await _identity.ownerKey()
        : store.ownerKey;
    final next = store.copyWith(ownerKey: owner, updatedAt: DateTime.now());
    await p.setString(storageKey, jsonEncode(next.toStorageMap()));
    return next;
  }

  @override
  Future<void> clearAll() async {
    final p = await _ensure();
    await p.remove(storageKey);
  }
}
