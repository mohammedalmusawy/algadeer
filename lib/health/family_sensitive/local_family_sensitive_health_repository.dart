import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../companion/visitor_identity_service.dart';
import 'family_sensitive_health_models.dart';
import 'family_sensitive_health_repository.dart';

/// تخزين محلي — مفتاح منفصل عن المالك والعائلة والهوية.
class LocalFamilySensitiveHealthRepository
    implements FamilySensitiveHealthRepository {
  LocalFamilySensitiveHealthRepository({
    SharedPreferences? prefs,
    VisitorIdentityService? identity,
  })  : _prefs = prefs,
        _identity = identity ?? VisitorIdentityService(prefs: prefs);

  SharedPreferences? _prefs;
  final VisitorIdentityService _identity;

  static const storageKey = 'pc_family_sensitive_health_v1';

  void setPrefsForTesting(SharedPreferences prefs) {
    _prefs = prefs;
    _identity.setPrefsForTesting(prefs);
  }

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<FamilySensitiveHealthStore?> loadStore() async {
    final p = await _ensure();
    final raw = p.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return FamilySensitiveHealthStore.fromStorageMap(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FamilySensitiveHealthStore> saveStore(
    FamilySensitiveHealthStore store,
  ) async {
    final p = await _ensure();
    await p.setString(storageKey, jsonEncode(store.toStorageMap()));
    return store;
  }

  @override
  Future<void> clearStore() async {
    final p = await _ensure();
    await p.remove(storageKey);
  }

  Future<String> ownerKey() => _identity.ownerKey();
}
