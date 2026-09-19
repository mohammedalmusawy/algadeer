import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../visitor_identity_service.dart';
import 'personal_memory_models.dart';
import 'personal_memory_repository.dart';

/// تخزين محلي — مفتاح منفصل عن الملف الأساسي والصحة والمتابعة.
class LocalPersonalMemoryRepository implements PersonalMemoryRepository {
  LocalPersonalMemoryRepository({
    SharedPreferences? prefs,
    VisitorIdentityService? identity,
  })  : _prefs = prefs,
        _identity = identity ?? VisitorIdentityService(prefs: prefs);

  SharedPreferences? _prefs;
  final VisitorIdentityService _identity;

  static const storageKey = 'pc_personal_memory_v1';

  void setPrefsForTesting(SharedPreferences prefs) {
    _prefs = prefs;
    _identity.setPrefsForTesting(prefs);
  }

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String> ownerKey() => _identity.ownerKey();

  @override
  Future<CompanionPersonalMemoryStore?> loadStore() async {
    final p = await _ensure();
    final raw = p.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return CompanionPersonalMemoryStore.fromStorageMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CompanionPersonalMemoryStore> saveStore(
    CompanionPersonalMemoryStore store,
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
}
