import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة أيقونات الواجهة القابلة للتغيير من الإدارة.
/// - بدون جدول/شبكة: التطبيق يعمل بالرموز الافتراضية كما كان.
/// - شعار الغدير غير قابل للتغيير هنا.
class AppIconsService extends ChangeNotifier {
  AppIconsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _table = 'app_ui_icons';
  static const _prefsKey = 'app_ui_icons_v1';
  static const mediaBucket = 'clinic-media';

  static final AppIconsService instance = AppIconsService();

  /// slotId → image URL (http أو assets/)
  Map<String, String> _urls = {};
  bool _loaded = false;
  bool tableAvailable = false;

  bool get isLoaded => _loaded;
  Map<String, String> get urls => Map.unmodifiable(_urls);

  String? urlFor(String slotId) {
    final u = _urls[slotId]?.trim();
    if (u == null || u.isEmpty) return null;
    return u;
  }

  Future<void> load() async {
    // 1) كاش محلي فوري — التطبيق لا ينتظر الشبكة.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _urls = {
            for (final e in decoded.entries)
              if (e.key.toString().isNotEmpty &&
                  e.value != null &&
                  e.value.toString().trim().isNotEmpty)
                e.key.toString(): e.value.toString().trim(),
          };
        }
      }
    } catch (e) {
      debugPrint('app icons prefs load failed: $e');
    }

    _loaded = true;
    notifyListeners();

    // 2) مزامنة اختيارية من Supabase — فشل صامت.
    try {
      tableAvailable = await hasTable();
      if (!tableAvailable) return;
      final rows = await _client.from(_table).select('slot_id, image_url');
      final next = <String, String>{};
      for (final row in (rows as List)) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = m['slot_id']?.toString().trim() ?? '';
        final url = m['image_url']?.toString().trim() ?? '';
        if (id.isEmpty || url.isEmpty) continue;
        // حماية: لا نسمح بتجاوز شعار الغدير عبر هذه الخدمة.
        if (id.startsWith('brand.logo') || id == 'logo') continue;
        next[id] = url;
      }
      _urls = next;
      await _persistLocal();
      notifyListeners();
    } catch (e) {
      debugPrint('app icons supabase load failed: $e');
    }
  }

  Future<bool> hasTable() async {
    try {
      await _client.from(_table).select('slot_id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setUrl(String slotId, String imageUrl) async {
    final id = slotId.trim();
    final url = imageUrl.trim();
    if (id.isEmpty || url.isEmpty) return;
    if (id.startsWith('brand.logo') || id == 'logo') {
      throw StateError('شعار الغدير ثابت ولا يُغيَّر من إدارة الأيقونات');
    }

    _urls[id] = url;
    await _persistLocal();
    notifyListeners();

    if (!await hasTable()) return;
    await _client.from(_table).upsert({
      'slot_id': id,
      'image_url': url,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> clearUrl(String slotId) async {
    final id = slotId.trim();
    if (id.isEmpty) return;
    _urls.remove(id);
    await _persistLocal();
    notifyListeners();

    if (!await hasTable()) return;
    try {
      await _client.from(_table).delete().eq('slot_id', id);
    } catch (e) {
      debugPrint('app icons clear remote failed: $e');
    }
  }

  Future<String> uploadIconImage({
    required Uint8List bytes,
    required String originalName,
    required String slotId,
  }) async {
    final extension = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'png';
    final safeExtension =
        ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(extension)
            ? extension
            : 'png';
    final safeSlot = slotId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final fileName =
        'ui_icons/$safeSlot/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await _client.storage.from(mediaBucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: switch (safeExtension) {
              'png' => 'image/png',
              'webp' => 'image/webp',
              'heic' => 'image/heic',
              _ => 'image/jpeg',
            },
          ),
        );

    return _client.storage.from(mediaBucket).getPublicUrl(fileName);
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_urls));
  }
}
