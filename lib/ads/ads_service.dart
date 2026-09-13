import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ad_campaign.dart';

class AdsService {
  AdsService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _table = 'ad_campaigns';
  static const mediaBucket = 'clinic-media';

  Future<bool> hasTable() async {
    try {
      await _client.from(_table).select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<AdCampaign>> fetchAllForAdmin() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('priority', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => AdCampaign.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// حملة واحدة جاهزة للعرض في فتحة معيّنة (أو null إن لا يوجد شيء مناسب).
  Future<AdCampaign?> fetchEligibleForPlacement(String placement) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('placement', placement)
          .eq('is_active', true)
          .order('priority', ascending: false)
          .limit(12);
      final list = (rows as List)
          .map((e) => AdCampaign.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((c) => c.isWithinSchedule && !c.hasReachedGlobalCap)
          .where((c) => c.hasImage || (c.isVideo && c.hasVideo))
          .toList();
      if (list.isEmpty) return null;

      final store = AdsFrequencyStore();
      for (final campaign in list) {
        if (await store.canShow(campaign)) return campaign;
      }
      return null;
    } catch (_) {
      // فشل صامت — التطبيق يكمل بدون إعلان
      return null;
    }
  }

  Future<AdCampaign> upsert(AdCampaign campaign, {String? existingId}) async {
    final payload = campaign.toMap();
    if (existingId != null && existingId.isNotEmpty) {
      final row = await _client
          .from(_table)
          .update(payload)
          .eq('id', existingId)
          .select()
          .single();
      return AdCampaign.fromMap(Map<String, dynamic>.from(row));
    }
    final row =
        await _client.from(_table).insert(payload).select().single();
    return AdCampaign.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from(_table).update({'is_active': active}).eq('id', id);
  }

  Future<String> uploadAdImage({
    required Uint8List bytes,
    required String originalName,
  }) async {
    final extension = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'jpg';
    final safeExtension =
        ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(extension)
        ? extension
        : 'jpg';
    final fileName =
        'ads/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await _client.storage.from(mediaBucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
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

  Future<void> recordImpression(String id) async {
    try {
      await _client.rpc('increment_ad_impression', params: {'p_id': id});
    } catch (_) {}
  }

  Future<void> recordClick(String id) async {
    try {
      await _client.rpc('increment_ad_click', params: {'p_id': id});
    } catch (_) {}
  }
}

/// حدود الظهور لكل جهاز/مستخدم محليًا (SharedPreferences).
class AdsFrequencyStore {
  static String _dayKey(String id) {
    final d = DateTime.now();
    final day = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'ad_day_${id}_$day';
  }

  static String _totalKey(String id) => 'ad_total_$id';
  static String _dismissKey(String id) => 'ad_dismiss_$id';

  Future<bool> canShow(AdCampaign campaign) async {
    final prefs = await SharedPreferences.getInstance();
    final id = campaign.id;
    if (id.isEmpty) return false;

    // إغلاق يدوي لنفس اليوم
    final dismissedDay = prefs.getString(_dismissKey(id));
    final today = _dayKey(id).split('_').last;
    if (dismissedDay == today) return false;

    final total = prefs.getInt(_totalKey(id)) ?? 0;
    if (campaign.maxPerUser > 0 && total >= campaign.maxPerUser) {
      return false;
    }

    final dayCount = prefs.getInt(_dayKey(id)) ?? 0;
    if (campaign.maxPerUserPerDay > 0 &&
        dayCount >= campaign.maxPerUserPerDay) {
      return false;
    }
    return true;
  }

  Future<void> markShown(AdCampaign campaign) async {
    final prefs = await SharedPreferences.getInstance();
    final id = campaign.id;
    final total = (prefs.getInt(_totalKey(id)) ?? 0) + 1;
    final day = (prefs.getInt(_dayKey(id)) ?? 0) + 1;
    await prefs.setInt(_totalKey(id), total);
    await prefs.setInt(_dayKey(id), day);
  }

  Future<void> markDismissedToday(AdCampaign campaign) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final day =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await prefs.setString(_dismissKey(campaign.id), day);
  }
}
