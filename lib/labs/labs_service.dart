import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lab_models.dart';
import 'package_image_library.dart';
import 'package_templates.dart';

/// رسالة خطأ واضحة من Supabase (لا نخفي السبب الحقيقي).
String formatLabSupabaseError(Object error) {
  if (error is PostgrestException) {
    final parts = <String>[
      if (error.message.trim().isNotEmpty) error.message.trim(),
      if ((error.code ?? '').trim().isNotEmpty) 'code=${error.code}',
      if (error.details != null && '${error.details}'.trim().isNotEmpty)
        'details=${error.details}',
      if ((error.hint ?? '').trim().isNotEmpty) 'hint=${error.hint}',
    ];
    if (parts.isNotEmpty) return parts.join(' | ');
  }
  return error.toString();
}

class LabsService {
  LabsService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String mediaBucket = 'clinic-media';

  bool get isAuthenticated => _client.auth.currentUser != null;

  Future<List<LabItem>> fetchPublicLabs() async {
    final data = await _client
        .from('labs')
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true);
    return (data as List)
        .map((e) => LabItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// جلب مختبر واحد — أسرع من تحميل كل المختبرات ثم الفلترة.
  Future<LabItem?> fetchLabById(String labId, {bool publicOnly = true}) async {
    if (labId.trim().isEmpty) return null;
    try {
      var query = _client.from('labs').select().eq('id', labId);
      if (publicOnly) {
        query = query.eq('is_active', true);
      }
      final row = await query.maybeSingle();
      if (row == null) return null;
      return LabItem.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<List<LabItem>> fetchAllLabs() async {
    final data = await _client
        .from('labs')
        .select()
        .order('display_order', ascending: true);

    return (data as List)
        .map((row) => LabItem.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<LabItem> upsertLab(LabItem lab, {String? existingId}) async {
    final payload = lab.toMap();
    if (existingId == null || existingId.isEmpty) {
      final row = await _client.from('labs').insert(payload).select().single();
      return LabItem.fromMap(Map<String, dynamic>.from(row));
    }

    final row = await _client
        .from('labs')
        .update(payload)
        .eq('id', existingId)
        .select()
        .single();
    return LabItem.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteLab(String labId) async {
    await _client.from('labs').delete().eq('id', labId);
  }

  Future<List<LabPackageItem>> fetchPublicPackages(String labId) async {
    try {
      final data = await _client
          .from('lab_packages')
          .select('*, lab_package_analyses(display_order, analyses(*))')
          .eq('lab_id', labId)
          .eq('is_active', true)
          .order('display_order', ascending: true);

      return (data as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final links = map['lab_package_analyses'];
        if (links is List) {
          links.sort((a, b) {
            final ao = (a is Map) ? (a['display_order'] as num? ?? 0) : 0;
            final bo = (b is Map) ? (b['display_order'] as num? ?? 0) : 0;
            return ao.compareTo(bo);
          });
          map['lab_package_analyses'] = links;
        }
        return LabPackageItem.fromMap(map);
      }).toList();
    } catch (_) {
      try {
        final data = await _client
            .from('lab_packages')
            .select('*, lab_package_analyses(count)')
            .eq('lab_id', labId)
            .eq('is_active', true)
            .order('display_order', ascending: true);

        return (data as List).map(_mapPackageRow).toList();
      } catch (_) {
        final data = await _client
            .from('lab_packages')
            .select()
            .eq('lab_id', labId)
            .eq('is_active', true)
            .order('display_order', ascending: true);

        return (data as List)
            .map(
              (row) =>
                  LabPackageItem.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
      }
    }
  }

  Future<List<LabPackageItem>> fetchAllPackages({String? labId}) async {
    try {
      var query = _client
          .from('lab_packages')
          .select('*, lab_package_analyses(count)');

      if (labId != null && labId.isNotEmpty) {
        query = query.eq('lab_id', labId);
      }

      final data = await query.order('display_order', ascending: true);
      return (data as List).map(_mapPackageRow).toList();
    } catch (_) {
      var query = _client.from('lab_packages').select();
      if (labId != null && labId.isNotEmpty) {
        query = query.eq('lab_id', labId);
      }
      final data = await query.order('display_order', ascending: true);
      return (data as List)
          .map(
            (row) =>
                LabPackageItem.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    }
  }

  LabPackageItem _mapPackageRow(dynamic row) {
    final map = Map<String, dynamic>.from(row as Map);
    final links = map['lab_package_analyses'];
    if (links is List && links.isNotEmpty) {
      final first = links.first;
      if (first is Map && first['count'] != null) {
        map['analyses_count'] = first['count'];
      }
    }
    return LabPackageItem.fromMap(map);
  }

  Future<LabPackageItem> fetchPackageDetails(String packageId) async {
    try {
      final row = await _client
          .from('lab_packages')
          .select('*, lab_package_analyses(display_order, analyses(*))')
          .eq('id', packageId)
          .single();

      final map = Map<String, dynamic>.from(row);
      final links = map['lab_package_analyses'];
      if (links is List) {
        links.sort((a, b) {
          final ao = (a is Map) ? (a['display_order'] as num? ?? 0) : 0;
          final bo = (b is Map) ? (b['display_order'] as num? ?? 0) : 0;
          return ao.compareTo(bo);
        });
        map['lab_package_analyses'] = links;
      }
      return LabPackageItem.fromMap(map);
    } catch (_) {
      final row = await _client
          .from('lab_packages')
          .select()
          .eq('id', packageId)
          .single();
      return LabPackageItem.fromMap(Map<String, dynamic>.from(row));
    }
  }

  Future<LabPackageItem> upsertPackage(
    LabPackageItem package, {
    String? existingId,
    List<String> analysisIds = const [],
    List<String> testNames = const [],
  }) async {
    if (!isAuthenticated) {
      throw StateError(
        'يجب تسجيل دخول الإدارة قبل حفظ الباقة '
        '(RLS تمنع Insert/Update للمستخدم غير المسجّل).',
      );
    }

    final names = <String>[];
    final seenNames = <String>{};
    for (final name in [
      ...testNames,
      ...package.testNames,
      ...package.analyses.map((a) => a.name),
    ]) {
      final n = name.trim();
      if (n.isEmpty || seenNames.contains(n.toLowerCase())) continue;
      seenNames.add(n.toLowerCase());
      names.add(n);
    }

    final uniqueAnalysisIds = <String>[];
    final seenIds = <String>{};
    for (final id in [...analysisIds, ...package.analyses.map((a) => a.id)]) {
      final value = id.trim();
      // تجاهل المعرّفات الوهمية (أسماء وليست UUID)
      if (value.isEmpty || value.length < 32 || seenIds.contains(value)) {
        continue;
      }
      seenIds.add(value);
      uniqueAnalysisIds.add(value);
    }

    final payload = package.toMap(testsOverride: names);
    debugPrint(
      'labs upsertPackage '
      'old_price=${payload['old_price']}(${payload['old_price']?.runtimeType}) '
      'price=${payload['price']}(${payload['price']?.runtimeType}) '
      'display_order=${payload['display_order']}(${payload['display_order']?.runtimeType}) '
      'auth=${_client.auth.currentUser?.id}',
    );

    late final Map<String, dynamic> row;
    try {
      if (existingId == null || existingId.isEmpty) {
        row = Map<String, dynamic>.from(
          await _client.from('lab_packages').insert(payload).select().single(),
        );
      } else {
        row = Map<String, dynamic>.from(
          await _client
              .from('lab_packages')
              .update(payload)
              .eq('id', existingId)
              .select()
              .single(),
        );
      }
    } catch (e, st) {
      debugPrint('labs upsertPackage package-save error: $e\n$st');
      throw Exception(
        'فشل حفظ الباقة في lab_packages: ${formatLabSupabaseError(e)}',
      );
    }

    final packageId = row['id']?.toString() ?? existingId ?? '';
    if (packageId.isEmpty) {
      throw StateError('تم الحفظ لكن لم يُرجع معرف الباقة (id).');
    }

    final hasLinkTable = await hasPackageAnalysesTable();
    if (hasLinkTable) {
      try {
        await _syncPackageAnalyses(packageId, uniqueAnalysisIds);
      } catch (e, st) {
        debugPrint('labs upsertPackage link-save error: $e\n$st');
        throw Exception(
          'تم حفظ الباقة لكن فشل حفظ علاقات التحاليل في '
          'lab_package_analyses: ${formatLabSupabaseError(e)}',
        );
      }
    } else if (uniqueAnalysisIds.isNotEmpty) {
      throw Exception(
        'تم حفظ الباقة، لكن جدول lab_package_analyses غير موجود. '
        'نفّذ ملف supabase/labs_schema.sql في Supabase SQL Editor.',
      );
    }

    return fetchPackageDetails(packageId);
  }

  Future<void> _syncPackageAnalyses(
    String packageId,
    List<String> analysisIds,
  ) async {
    await _client
        .from('lab_package_analyses')
        .delete()
        .eq('package_id', packageId);

    if (analysisIds.isEmpty) return;

    final uniqueIds = <String>{};
    final rows = <Map<String, dynamic>>[];
    var order = 0;
    for (final id in analysisIds) {
      if (id.isEmpty || uniqueIds.contains(id)) continue;
      uniqueIds.add(id);
      rows.add({
        'package_id': packageId,
        'analysis_id': id,
        'display_order': order++,
      });
    }

    if (rows.isNotEmpty) {
      await _client.from('lab_package_analyses').insert(rows);
    }
  }

  Future<void> deletePackage(String packageId) async {
    await _client.from('lab_packages').delete().eq('id', packageId);
  }

  Future<List<String>> fetchKnownTestNames() async {
    final fromDict = await fetchAnalyses(activeOnly: true);
    if (fromDict.isNotEmpty) {
      return fromDict.map((a) => a.name).toList();
    }

    final packages = await fetchAllPackages();
    final names = <String>{};
    for (final pkg in packages) {
      names.addAll(pkg.testNames);
      names.addAll(pkg.analyses.map((a) => a.name));
    }
    final list = names.toList()..sort();
    return list;
  }

  Future<bool> hasAnalysesTable() async {
    try {
      await _client.from('analyses').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPackageAnalysesTable() async {
    try {
      await _client.from('lab_package_analyses').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPackageTemplatesTable() async {
    try {
      await _client.from('package_templates').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<PackageTemplateItem>> fetchPackageTemplates({
    String query = '',
  }) async {
    try {
      final data = await _client
          .from('package_templates')
          .select('*, package_template_analyses(display_order, analyses(*))')
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final items = (data as List)
          .map(
            (row) => PackageTemplateItem.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
      return rankPackageTemplates(items, query);
    } catch (e) {
      debugPrint('fetchPackageTemplates fallback: $e');
      return rankPackageTemplates(localFallbackPackageTemplates(), query);
    }
  }

  Future<List<AnalysisItem>> fetchAnalyses({
    String query = '',
    bool activeOnly = false,
  }) async {
    try {
      Future<List<dynamic>> load({required bool byPopularity}) async {
        var builder = _client.from('analyses').select();
        if (activeOnly) {
          builder = builder.eq('is_active', true);
        }
        if (byPopularity) {
          return await builder
              .order('display_order', ascending: true)
              .order('name', ascending: true) as List<dynamic>;
        }
        return await builder.order('name', ascending: true) as List<dynamic>;
      }

      List<dynamic> data;
      try {
        data = await load(byPopularity: true);
      } catch (_) {
        data = await load(byPopularity: false);
      }

      final items = data
          .map(
            (row) =>
                AnalysisItem.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList()
        ..sort((a, b) {
          final byOrder = a.displayOrder.compareTo(b.displayOrder);
          if (byOrder != 0) return byOrder;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

      final q = query.trim();
      if (q.isEmpty) return items;
      return rankAnalysisMatches(items, q, limit: 40);
    } catch (e) {
      debugPrint('fetchAnalyses fallback/error: $e');
      // جدول analyses غير موجود: نبني قاموسًا من عمود tests
      final names = <String>{};
      try {
        final data = await _client.from('lab_packages').select('tests');
        for (final row in data as List) {
          names.addAll(parseLabTests((row as Map)['tests']));
        }
      } catch (_) {}
      final items = names.map(AnalysisItem.fromName).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final q = query.trim();
      if (q.isEmpty) return items;
      return rankAnalysisMatches(items, q, limit: 40);
    }
  }

  Future<List<String>> fetchPackageAnalysisIds(String packageId) async {
    try {
      final data = await _client
          .from('lab_package_analyses')
          .select('analysis_id')
          .eq('package_id', packageId)
          .order('display_order', ascending: true);

      return (data as List)
          .map((row) => (row as Map)['analysis_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateAnalysisDescriptionAr({
    required String analysisId,
    required String descriptionAr,
  }) async {
    if (analysisId.trim().isEmpty || analysisId.length < 32) return;
    await _client
        .from('analyses')
        .update({'description_ar': descriptionAr.trim()})
        .eq('id', analysisId);
  }

  Future<AnalysisItem> upsertAnalysis(
    AnalysisItem analysis, {
    String? existingId,
  }) async {
    final payload = analysis.toMap();
    if (existingId == null || existingId.isEmpty) {
      final row = await _client
          .from('analyses')
          .insert(payload)
          .select()
          .single();
      return AnalysisItem.fromMap(Map<String, dynamic>.from(row));
    }

    final row = await _client
        .from('analyses')
        .update(payload)
        .eq('id', existingId)
        .select()
        .single();
    return AnalysisItem.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteAnalysis(String analysisId) async {
    await _client.from('analyses').delete().eq('id', analysisId);
  }

  Future<String> uploadPackageImage({
    required Uint8List bytes,
    required String originalName,
    String? packageId,
  }) async {
    final extension = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'jpg';
    final safeExtension =
        ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(extension)
        ? extension
        : 'jpg';
    final folder = (packageId != null && packageId.length >= 32)
        ? 'packages/$packageId'
        : 'packages';
    final fileName =
        '$folder/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await _client.storage
        .from(mediaBucket)
        .uploadBinary(
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

  Future<bool> hasPackageImagesTable() async {
    try {
      await _client.from('package_images').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<PackageImageItem>> fetchPackageImages() async {
    try {
      if (!await hasPackageImagesTable()) {
        return List<PackageImageItem>.from(kBuiltinPackageImages);
      }
      final data = await _client
          .from('package_images')
          .select()
          .eq('is_active', true)
          .order('category');
      final list = (data as List)
          .map((e) => PackageImageItem.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.imageUrl.trim().isNotEmpty)
          .toList();
      if (list.isEmpty) {
        return List<PackageImageItem>.from(kBuiltinPackageImages);
      }
      return list;
    } catch (_) {
      return List<PackageImageItem>.from(kBuiltinPackageImages);
    }
  }

  Future<String> uploadLabImage({
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
        'labs/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await _client.storage
        .from(mediaBucket)
        .uploadBinary(
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
