import 'package:supabase_flutter/supabase_flutter.dart';

import '../doctors/doctor_availability_service.dart';
import '../models/doctor_item.dart';
import '../models/lab_models.dart';
import 'arabic_text_utils.dart';
import 'smart_search_models.dart';

/// بحث محلي عبر Supabase — بدون AI.
/// نفس المسار للبحث النصي والصوتي.
class SmartSearchService {
  SmartSearchService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<SmartSearchResult>> search(
    String rawQuery, {
    int limit = 24,
  }) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return [];

    final pattern = _ilikePattern(query);
    final results = <SmartSearchResult>[];
    final intent = _detectLocalIntent(query);

    final doctorVariants = _doctorQueryVariants(query);
    final futures = <Future<void>>[];

    for (final v in doctorVariants) {
      futures.add(
        _searchDoctors(_ilikePattern(v), results, originalQuery: query),
      );
    }

    final analysisQuery = _stripBoilerplateForAnalyses(query);
    final analysisPattern =
        analysisQuery.isEmpty ? pattern : _ilikePattern(analysisQuery);

    futures.add(_searchLabs(rawQuery, pattern, results));
    futures.add(
      _searchPackages(
        rawQuery,
        pattern,
        results,
        offerOnly: intent.activeOffersOnly,
        cheapestFirst: intent.cheapestFirst,
        labNameHint: intent.labNameHint,
      ),
    );
    futures.add(_searchAnalyses(analysisPattern, results, originalQuery: query));

    await Future.wait(futures);

    // بعد إيجاد التحاليل: اجلب الباقات التي تحتويها.
    final analysisHits = results
        .where((r) => r.type == SmartSearchResultType.analysis && r.analysisId != null)
        .toList();
    if (analysisHits.isNotEmpty) {
      await _attachPackagesForAnalyses(analysisHits, results);
    }

    // إن كان الاستعلام اسم طبيب ولم تُرجع مرشحات ilike شيئاً، امسح جدول الأطباء محلياً.
    // نفس مصدر البيانات المستخدم في بقية التطبيق (جدول doctors).
    final hasDoctor = results.any((r) => r.type == SmartSearchResultType.doctor);
    if (!hasDoctor && ArabicTextUtils.looksLikeDoctorNameQuery(query)) {
      await _scanDoctorsByName(query, results);
    }

    final byKey = <String, SmartSearchResult>{};
    for (final r in results) {
      final key =
          '${r.type}:${r.doctorId ?? ''}:${r.labId ?? ''}:${r.packageId ?? ''}:${r.analysisId ?? ''}:${r.title}';
      final existing = byKey[key];
      if (existing == null || r.score > existing.score) {
        byKey[key] = r;
      }
    }
    final deduped = byKey.values.toList();

    deduped.sort((a, b) {
      if (intent.cheapestFirst &&
          a.newPrice != null &&
          b.newPrice != null &&
          a.isOffer &&
          b.isOffer) {
        final byPrice = a.newPrice!.compareTo(b.newPrice!);
        if (byPrice != 0) return byPrice;
      }
      // الأطباء في إجازة يتأخرون في الترتيب العام للبحث أيضاً.
      if (a.type == SmartSearchResultType.doctor &&
          b.type == SmartSearchResultType.doctor) {
        if (a.isOnLeave != b.isOnLeave) {
          return a.isOnLeave ? 1 : -1;
        }
      }
      return b.score.compareTo(a.score);
    });

    if (deduped.length > limit) {
      return deduped.sublist(0, limit);
    }
    return deduped;
  }

  _LocalSearchIntent _detectLocalIntent(String query) {
    final q = query.trim().toLowerCase();
    final activeOffersOnly =
        q.contains('عرض') || q.contains('عروض') || q.contains('خصم');
    final cheapestFirst = q.contains('أرخص') ||
        q.contains('ارخص') ||
        q.contains('أقل سعر') ||
        q.contains('اقل سعر');

    String? labNameHint;
    final labMatch = RegExp(
      r'(?:مختبر|عرض\s+مختبر)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(query.trim());
    if (labMatch != null) {
      labNameHint = labMatch.group(1)?.trim();
      if (labNameHint != null && labNameHint.isEmpty) labNameHint = null;
    }

    return _LocalSearchIntent(
      activeOffersOnly: activeOffersOnly,
      cheapestFirst: cheapestFirst,
      labNameHint: labNameHint,
    );
  }

  String _ilikePattern(String query) {
    final escaped = query.replaceAll('%', r'\%').replaceAll('_', r'\_');
    return '%$escaped%';
  }

  /// اقتباس قيمة PostgREST داخل `.or(...)` حتى لا تُكسَر المسافات/الفواصل.
  String _quotedOrIlike(String column, String pattern) {
    final escaped = pattern.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '$column.ilike."$escaped"';
  }

  int _scoreMatch(String haystack, String needle) {
    return ArabicTextUtils.scoreMatch(haystack, needle);
  }

  String _normalize(String input) => ArabicTextUtils.normalize(input);

  /// متغيرات بحث الأطباء: إزالة الألقاب + أشكال الهمزة + رموز الاسم.
  List<String> _doctorQueryVariants(String query) {
    final variants = <String>{
      ...ArabicTextUtils.doctorSearchVariants(query),
      ..._queryVariants(query),
    };
    // لا نُرسل عبارات أطول من اللازم لـ ilike إن وُجدت رموز أقصر أوضح.
    return variants.toList();
  }

  List<String> _queryVariants(String query) {
    final q = query.trim();
    final lower = _normalize(q);
    final variants = <String>{q};

    if (lower.contains('اطفال')) {
      variants.add(q.replaceAll(RegExp(r'اطفال|أطفال'), 'أطفال'));
      variants.add('أطفال');
    }

    final entHints = ['اذن', 'أذن', 'انف', 'أنف', 'حلق', 'لوز', 'ent'];
    if (entHints.any((k) => lower.contains(_normalize(k)))) {
      variants.add('أنف وأذن وحنجرة');
      variants.add('انف واذن');
    }

    if (lower.contains('كبد') || lower.contains('liver')) {
      variants.add('كبد');
      variants.add('فحوصات الكبد');
    }

    if (lower.contains('قلب') || lower.contains('heart')) {
      variants.add('قلب');
    }

    if (lower.contains('سكر') ||
        lower.contains('glucose') ||
        lower.contains('diabetes')) {
      variants.add('سكر');
    }

    // تعبيرات عراقية شائعة للبحث.
    if (lower.contains('اكو')) {
      final cleaned = ArabicTextUtils.stripHonorifics(
        q.replaceAll(RegExp(r'أكو|اكو'), ''),
      );
      if (cleaned.isNotEmpty) variants.add(cleaned);
    }

    if (lower.contains('عرض') ||
        lower.contains('عروض') ||
        lower.contains('خصم')) {
      variants.add('عرض');
    }

    return variants.toList();
  }

  String _stripBoilerplateForAnalyses(String query) {
    final cleaned = query
        .trim()
        .replaceAll(
          RegExp(r'(تحاليل|تحليل|أريد|اريد|عاوز|ابي|أبغى|اكو|أكو)',
              caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }

  Future<void> _searchDoctors(
    String pattern,
    List<SmartSearchResult> out, {
    required String originalQuery,
  }) async {
    try {
      // استخدم ilike على العمود مباشرة (أأمن من or غير المقتبس مع المسافات).
      List rows;
      try {
        rows = await _client
            .from('doctors')
            .select()
            .or('is_active.eq.true,is_active.is.null')
            .ilike('doctor_name', pattern)
            .limit(24) as List;
      } catch (_) {
        final nameFilter = _quotedOrIlike('doctor_name', pattern);
        final specialtyFilter = _quotedOrIlike('specialty', pattern);
        rows = await _client
            .from('doctors')
            .select()
            .or('is_active.eq.true,is_active.is.null')
            .or('$nameFilter,$specialtyFilter')
            .limit(24) as List;
      }

      // إن لم نجد بالاسم، جرّب الاختصاص بنفس الرمز (للبحث غير الاسمي).
      if (rows.isEmpty && !ArabicTextUtils.looksLikeDoctorNameQuery(originalQuery)) {
        try {
          rows = await _client
              .from('doctors')
              .select()
              .or('is_active.eq.true,is_active.is.null')
              .ilike('specialty', pattern)
              .limit(24) as List;
        } catch (_) {}
      }

      _appendDoctorRows(
        rows,
        out,
        originalQuery: originalQuery,
        variantNeedle: pattern.replaceAll('%', ''),
      );
    } catch (e, st) {
      assert(() {
        // ignore: avoid_print
        print('SmartSearchService._searchDoctors failed: $e\n$st');
        return true;
      }());
    }
  }

  /// مسح محلي لكل الأطباء النشطين عند فشل مرشحات ilike لاسم واضح.
  Future<void> _scanDoctorsByName(
    String originalQuery,
    List<SmartSearchResult> out,
  ) async {
    try {
      final rows = await _client
          .from('doctors')
          .select()
          .or('is_active.eq.true,is_active.is.null')
          .limit(300) as List;
      _appendDoctorRows(
        rows,
        out,
        originalQuery: originalQuery,
        variantNeedle: ArabicTextUtils.stripHonorifics(originalQuery),
      );
    } catch (e, st) {
      assert(() {
        // ignore: avoid_print
        print('SmartSearchService._scanDoctorsByName failed: $e\n$st');
        return true;
      }());
    }
  }

  void _appendDoctorRows(
    List rows,
    List<SmartSearchResult> out, {
    required String originalQuery,
    required String variantNeedle,
  }) {
    final seenSpecialties = <String>{};
    final needle = ArabicTextUtils.stripHonorifics(variantNeedle);
    final originalNeedle = ArabicTextUtils.stripHonorifics(originalQuery);
    final nameTokens = ArabicTextUtils.meaningfulNameTokens(originalNeedle);

    for (final row in rows) {
      final map = Map<String, dynamic>.from(row as Map);
      final doctor = DoctorItem.fromMap(map);
      if (doctor.name.isEmpty || doctor.id.isEmpty) continue;

      final leave = DoctorLeaveDisplay.fromDoctor(doctor);
      final nameScore =
          ArabicTextUtils.scoreDoctorNameMatch(doctor.name, originalNeedle);
      final specialtyScoreOriginal =
          _scoreMatch(doctor.specialty, originalNeedle);
      final specialtyScoreVariant = _scoreMatch(doctor.specialty, needle);
      final specialtyScore = specialtyScoreOriginal >= specialtyScoreVariant
          ? specialtyScoreOriginal
          : specialtyScoreVariant;

      var score = nameScore;
      if (specialtyScore > score) score = specialtyScore;

      // استعلام متعدد الأجزاء: لا تُبقَ طبيباً شارك كلمة واحدة فقط («علي»).
      if (nameTokens.length >= 2 &&
          !ArabicTextUtils.allDoctorNameTokensMatch(
            doctor.name,
            originalNeedle,
          ) &&
          specialtyScore < 70) {
        continue;
      }

      if (score <= 0) continue;

      if (leave.isOnLeave) score -= 15;

      String? availabilityLabel;
      if (leave.isOnLeave) {
        availabilityLabel = leave.badgeLabel;
      } else if (doctor.bookingStatus == 'available') {
        availabilityLabel = 'متاح';
      } else if (doctor.bookingStatus == 'full') {
        availabilityLabel = 'مكتمل اليوم';
      } else if (doctor.bookingStatus == 'walk_in_only') {
        availabilityLabel = 'حضور مباشر فقط';
      } else if (doctor.bookingStatus == 'unavailable') {
        availabilityLabel = 'غير متاح';
      }

      out.add(
        SmartSearchResult(
          type: SmartSearchResultType.doctor,
          title: doctor.name,
          subtitle: doctor.specialty.isNotEmpty ? doctor.specialty : 'طبيب',
          doctorId: doctor.id,
          score: score.clamp(0, 100),
          imageUrl: doctor.imageUrl.isNotEmpty ? doctor.imageUrl : null,
          specialty: doctor.specialty,
          absenceBadge: leave.isOnLeave ? leave.badgeLabel : null,
          availabilityLabel: availabilityLabel,
          bioSnippet: doctor.shortDescription.isNotEmpty
              ? doctor.shortDescription
              : (doctor.bio.isNotEmpty ? doctor.bio : null),
          isOnLeave: leave.isOnLeave,
        ),
      );

      if (doctor.specialty.isNotEmpty &&
          seenSpecialties.add(doctor.specialty.toLowerCase())) {
        out.add(
          SmartSearchResult(
            type: SmartSearchResultType.specialty,
            title: doctor.specialty,
            subtitle: 'اختصاص',
            score: (_scoreMatch(doctor.specialty, needle) - 5).clamp(0, 100),
            specialty: doctor.specialty,
          ),
        );
      }
    }
  }

  Future<void> _searchLabs(
    String rawQuery,
    String pattern,
    List<SmartSearchResult> out,
  ) async {
    final q = rawQuery.trim().toLowerCase();

    try {
      final isGenericLabQuery = q == 'مختبر' ||
          q == 'مختبرات' ||
          (q.contains('مختبر') &&
              q.replaceAll(RegExp(r'مختبر|المختبرات|المختبر'), '').trim().isEmpty);

      List rows;
      if (isGenericLabQuery) {
        rows = await _client
            .from('labs')
            .select()
            .eq('is_active', true)
            .order('display_order', ascending: true)
            .limit(8) as List;
      } else {
        // lab_name هو العمود الأساسي في الكتابة؛ name قد يوجد في بعض البيئات.
        try {
          rows = await _client
              .from('labs')
              .select()
              .eq('is_active', true)
              .or('lab_name.ilike.$pattern,name.ilike.$pattern,address.ilike.$pattern')
              .limit(8) as List;
        } catch (_) {
          rows = await _client
              .from('labs')
              .select()
              .eq('is_active', true)
              .ilike('lab_name', pattern)
              .limit(8) as List;
        }
      }

      final needle = pattern.replaceAll('%', '');
      for (final row in rows) {
        final lab = LabItem.fromMap(Map<String, dynamic>.from(row as Map));
        if (lab.name.isEmpty || lab.id.isEmpty) continue;

        out.add(
          SmartSearchResult(
            type: SmartSearchResultType.lab,
            title: lab.name,
            subtitle: lab.address.isNotEmpty
                ? lab.address
                : (lab.slogan.isNotEmpty ? lab.slogan : 'مختبر'),
            labId: lab.id,
            score: isGenericLabQuery ? 25 : _scoreMatch(lab.name, needle),
            imageUrl: lab.imageUrl.isNotEmpty ? lab.imageUrl : null,
            labName: lab.name,
            bioSnippet: lab.description.isNotEmpty ? lab.description : null,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _searchPackages(
    String rawQuery,
    String pattern,
    List<SmartSearchResult> out, {
    bool offerOnly = false,
    bool cheapestFirst = false,
    String? labNameHint,
  }) async {
    final q = rawQuery.trim().toLowerCase();
    final isOfferQuery =
        offerOnly || q.contains('عرض') || q.contains('عروض') || q.contains('خصم');
    final isGenericOfferQuery = isOfferQuery &&
        q
            .replaceAll(RegExp(r'(عرض|عروض|خصم|أريد|اريد|اكو|أكو|مختبرات|المختبرات)'), '')
            .trim()
            .isEmpty;

    try {
      List rows;
      if (isGenericOfferQuery) {
        rows = await _client
            .from('lab_packages')
            .select('*, labs(*)')
            .eq('is_active', true)
            .limit(24) as List;
      } else {
        try {
          rows = await _client
              .from('lab_packages')
              .select('*, labs(*)')
              .eq('is_active', true)
              .or('package_name.ilike.$pattern,name.ilike.$pattern,description.ilike.$pattern')
              .limit(16) as List;
        } catch (_) {
          rows = await _client
              .from('lab_packages')
              .select('*, labs(*)')
              .eq('is_active', true)
              .ilike('package_name', pattern)
              .limit(16) as List;
        }
      }

      final needle = pattern.replaceAll('%', '');
      final mapped = <SmartSearchResult>[];

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        final pkg = LabPackageItem.fromMap(map);
        if (pkg.name.isEmpty || pkg.id.isEmpty) continue;

        String labName = '';
        final labs = map['labs'];
        if (labs is Map) {
          labName = (labs['lab_name'] ?? labs['name'])?.toString() ?? '';
        }

        if (labNameHint != null && labNameHint.isNotEmpty) {
          if (!_normalize(labName).contains(_normalize(labNameHint))) {
            continue;
          }
        }

        final discount = pkg.discountPercent;
        final hasOffer = discount != null;

        if (isOfferQuery && !hasOffer) {
          continue; // العروض = خصم حقيقي فقط (is_active + old_price > price).
        }

        final baseScore = _scoreMatch(pkg.name, needle);
        final offerBoost = (isOfferQuery && hasOffer) ? 70 : 0;
        final type = hasOffer && isOfferQuery
            ? SmartSearchResultType.offer
            : (hasOffer ? SmartSearchResultType.offer : SmartSearchResultType.package);

        mapped.add(
          SmartSearchResult(
            type: type,
            title: pkg.name,
            subtitle: labName.isNotEmpty
                ? (hasOffer
                    ? 'عرض — $labName ($discount% خصم)'
                    : 'باقة — $labName')
                : (hasOffer ? 'عرض ($discount% خصم)' : 'باقة مختبر'),
            labId: pkg.labId.isNotEmpty ? pkg.labId : null,
            packageId: pkg.id,
            score: (baseScore + offerBoost).clamp(0, 170),
            imageUrl: pkg.imageUrl.isNotEmpty ? pkg.imageUrl : null,
            labName: labName.isNotEmpty ? labName : null,
            oldPrice: pkg.oldPrice,
            newPrice: pkg.newPrice,
            discountPercent: discount,
            bioSnippet:
                pkg.description.isNotEmpty ? pkg.description : null,
          ),
        );
      }

      if (cheapestFirst) {
        mapped.sort((a, b) {
          final ap = a.newPrice ?? 1 << 30;
          final bp = b.newPrice ?? 1 << 30;
          return ap.compareTo(bp);
        });
      }

      out.addAll(mapped);
    } catch (_) {}
  }

  Future<void> _searchAnalyses(
    String pattern,
    List<SmartSearchResult> out, {
    required String originalQuery,
  }) async {
    try {
      List rows;
      try {
        rows = await _client
            .from('analyses')
            .select()
            .or(
              'name.ilike.$pattern,name_ar.ilike.$pattern,short_name.ilike.$pattern,search_text.ilike.$pattern',
            )
            .limit(10) as List;
      } catch (_) {
        rows = await _client
            .from('analyses')
            .select()
            .or('name.ilike.$pattern,name_ar.ilike.$pattern')
            .limit(10) as List;
      }

      final needle = pattern.replaceAll('%', '');
      for (final row in rows) {
        final analysis =
            AnalysisItem.fromMap(Map<String, dynamic>.from(row as Map));
        if (!analysis.isActive) continue;

        final title = analysis.arabicDisplayName.isNotEmpty
            ? analysis.arabicDisplayName
            : analysis.name;
        if (title.isEmpty || analysis.id.isEmpty) continue;

        var score = _scoreMatch('$title ${analysis.name} ${analysis.shortName}', needle);
        for (final alias in analysis.aliases) {
          final a = _scoreMatch(alias, needle);
          if (a > score) score = a;
        }
        // اختصار إنكليزي مثل ALT
        if (_normalize(originalQuery) == _normalize(analysis.shortName) ||
            _normalize(originalQuery) == _normalize(analysis.name)) {
          score = 100;
        }

        out.add(
          SmartSearchResult(
            type: SmartSearchResultType.analysis,
            title: title,
            subtitle: analysis.englishDisplayName.isNotEmpty
                ? analysis.englishDisplayName
                : 'تحليل',
            analysisId: analysis.id,
            score: score,
            bioSnippet: analysis.arabicDescriptionDisplay.isNotEmpty
                ? analysis.arabicDescriptionDisplay
                : null,
          ),
        );
      }
    } catch (_) {}
  }

  /// التحليل → lab_package_analyses → packages + labs
  Future<void> _attachPackagesForAnalyses(
    List<SmartSearchResult> analyses,
    List<SmartSearchResult> out,
  ) async {
    for (final analysis in analyses.take(5)) {
      final analysisId = analysis.analysisId;
      if (analysisId == null || analysisId.isEmpty) continue;

      try {
        final links = await _client
            .from('lab_package_analyses')
            .select('package_id, lab_packages(*, labs(*))')
            .eq('analysis_id', analysisId)
            .limit(12);

        for (final row in links as List) {
          final map = Map<String, dynamic>.from(row as Map);
          final pkgRaw = map['lab_packages'];
          if (pkgRaw is! Map) continue;

          final pkgMap = Map<String, dynamic>.from(pkgRaw);
          final pkg = LabPackageItem.fromMap(pkgMap);
          if (!pkg.isActive || pkg.id.isEmpty) continue;

          String labName = '';
          final labs = pkgMap['labs'];
          if (labs is Map) {
            labName = (labs['lab_name'] ?? labs['name'])?.toString() ?? '';
          }

          final discount = pkg.discountPercent;
          final hasOffer = discount != null;

          out.add(
            SmartSearchResult(
              type: hasOffer
                  ? SmartSearchResultType.offer
                  : SmartSearchResultType.package,
              title: pkg.name,
              subtitle: labName.isNotEmpty
                  ? 'تحتوي ${analysis.title} — $labName'
                  : 'تحتوي ${analysis.title}',
              labId: pkg.labId.isNotEmpty ? pkg.labId : null,
              packageId: pkg.id,
              score: (analysis.score - 5).clamp(40, 95),
              imageUrl: pkg.imageUrl.isNotEmpty ? pkg.imageUrl : null,
              labName: labName.isNotEmpty ? labName : null,
              oldPrice: pkg.oldPrice,
              newPrice: pkg.newPrice,
              discountPercent: discount,
              relatedAnalysisId: analysisId,
              relatedAnalysisTitle: analysis.title,
              bioSnippet:
                  pkg.description.isNotEmpty ? pkg.description : null,
            ),
          );
        }
      } catch (_) {
        // جدول الربط قد لا يكون متاحاً — لا نكسر البحث.
      }
    }
  }
}

class _LocalSearchIntent {
  const _LocalSearchIntent({
    required this.activeOffersOnly,
    required this.cheapestFirst,
    this.labNameHint,
  });

  final bool activeOffersOnly;
  final bool cheapestFirst;
  final String? labNameHint;
}
