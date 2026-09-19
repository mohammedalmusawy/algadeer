import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../companion/visitor_identity_service.dart';
import 'follow_up_models.dart';
import 'follow_up_repository.dart';

/// تخزين محلي — مفتاح منفصل عن الصحة/العائلة/المزمن.
class LocalFollowUpRepository implements FollowUpRepository {
  LocalFollowUpRepository({
    SharedPreferences? prefs,
    VisitorIdentityService? identity,
  })  : _prefs = prefs,
        _identity = identity ?? VisitorIdentityService(prefs: prefs);

  SharedPreferences? _prefs;
  final VisitorIdentityService _identity;

  static const storageKey = 'pc_follow_up_commitments_v1';

  void setPrefsForTesting(SharedPreferences prefs) {
    _prefs = prefs;
    _identity.setPrefsForTesting(prefs);
  }

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<String> ownerKey() => _identity.ownerKey();

  @override
  Future<FollowUpStore?> loadStore() async {
    final p = await _ensure();
    final raw = p.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return FollowUpStore.fromStorageMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FollowUpStore> saveStore(FollowUpStore store) async {
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
