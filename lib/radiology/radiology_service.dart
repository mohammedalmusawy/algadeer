import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../doctors/doctor_admin_persist.dart';
import '../models/radiology_models.dart';
import '../services/content_conflict.dart';
import '../services/offline_rows_cache.dart';

class RadiologyService {
  RadiologyService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String mediaBucket = 'clinic-media';

  Future<List<RadiologyCenter>> fetchPublicCenters() async {
    final data = await OfflineRowsCache.fetchOrCache(
      'radiology_centers',
      () async {
        final remote = await _client
            .from('radiology_centers')
            .select()
            .eq('is_active', true)
            .order('display_order', ascending: true);
        return List<Map<String, dynamic>>.from(remote as List);
      },
    );
    return data.map(RadiologyCenter.fromMap).toList();
  }

  Future<RadiologyCenter?> fetchCenterById(
    String id, {
    bool publicOnly = true,
  }) async {
    if (id.trim().isEmpty) return null;
    try {
      var query = _client.from('radiology_centers').select().eq('id', id);
      if (publicOnly) query = query.eq('is_active', true);
      final row = await query.maybeSingle();
      if (row == null) return null;
      return RadiologyCenter.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<List<RadiologyCenter>> fetchAllCenters() async {
    final data = await _client
        .from('radiology_centers')
        .select()
        .order('display_order', ascending: true);
    return (data as List)
        .map(
          (row) =>
              RadiologyCenter.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<RadiologyCenter> upsertCenter(
    RadiologyCenter center, {
    String? existingId,
  }) async {
    final payload = Map<String, dynamic>.from(center.toMap());
    // حماية «اثنين يعدّلون بنفس الوقت»: الحفظ ينجح فقط إن لم يتغيّر الرقم.
    // قبل تطبيق radiology_content_revision.sql يرجع للحفظ العادي.
    var useRevision = true;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        if (existingId == null || existingId.isEmpty) {
          if (useRevision) payload['content_revision'] = 1;
          final row = await _client
              .from('radiology_centers')
              .insert(payload)
              .select()
              .single();
          return RadiologyCenter.fromMap(Map<String, dynamic>.from(row));
        }
        if (useRevision) {
          payload['content_revision'] = center.contentRevision + 1;
          final rows = await _client
              .from('radiology_centers')
              .update(payload)
              .eq('id', existingId)
              .eq('content_revision', center.contentRevision)
              .select();
          if ((rows as List).isEmpty) throw const ContentConflictException();
          return RadiologyCenter.fromMap(
            Map<String, dynamic>.from(rows.first as Map),
          );
        }
        final row = await _client
            .from('radiology_centers')
            .update(payload)
            .eq('id', existingId)
            .select()
            .single();
        return RadiologyCenter.fromMap(Map<String, dynamic>.from(row));
      } on PostgrestException catch (e) {
        if (useRevision &&
            (e.code == '42703' || '${e.message}'.contains('content_revision'))) {
          useRevision = false;
          payload.remove('content_revision');
          debugPrint('radiology upsertCenter: content_revision missing — plain save');
          continue;
        }
        if (e.code != 'PGRST204') rethrow;
        final missing = missingDoctorColumnFromPostgrest(e.message);
        if (missing == null || !payload.containsKey(missing)) rethrow;
        payload.remove(missing);
        debugPrint('radiology upsertCenter: stripped missing column $missing');
      }
    }
    throw StateError('تعذر حفظ مركز الأشعة بعد تجاهل الأعمدة الاختيارية');
  }

  Future<void> deleteCenter(String id) async {
    await _client.from('radiology_centers').delete().eq('id', id);
  }

  Future<String> uploadCenterImage({
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
        'radiology/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

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

  Future<void> tryDeleteStorageUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      const marker = '/object/public/clinic-media/';
      final index = uri.path.indexOf(marker);
      if (index == -1) return;
      final path = Uri.decodeComponent(
        uri.path.substring(index + marker.length),
      );
      await _client.storage.from(mediaBucket).remove([path]);
    } catch (_) {}
  }
}
