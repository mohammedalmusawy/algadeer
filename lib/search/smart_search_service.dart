import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../doctors/doctor_availability_service.dart';
import '../doctors/doctor_gender.dart';
import '../home/trending_entity.dart';
import '../models/doctor_item.dart';
import '../models/lab_models.dart';
import 'arabic_text_utils.dart';
import 'doctor_name_matcher.dart';
import 'smart_search_models.dart';

/// بحث محلي عبر Supabase — بدون AI.
/// نفس المسار للبحث النصي والصوتي.
class SmartSearchService {
  final SupabaseClient _client;
  final DoctorNameMatcher _doctorNameMatcher;

  SmartSearchService({
    SupabaseClient? client,
    this._doctorNameMatcher = const DoctorNameMatcher(),
  }) : _client = client ?? Supabase.instance.client;

  /// كاش أطباء للبحث المحلي السريع (بدون نت بعد أول جلب).
  List<Map<String, dynamic>>? _doctorsCache;
  DateTime? _doctorsCacheAt;
  Future<List<Map<String, dynamic>>>? _doctorsLoadFuture;
  static const _doctorsCacheTtl = Duration(minutes: 10);

  /// يفرض إعادة جلب الأطباء من السيرفر في المرة القادمة.
  void invalidateDoctorsCache() {
    _doctorsCache = null;
    _doctorsCacheAt = null;
    _doctorsLoadFuture = null;
  }

  /// تسخين الكاش عند فتح صفحة البحث.
  Future<void> prefetchDoctorsCache() => _cachedDoctors();

  /// فهرس أسماء الأطباء الحقيقيين من نفس الكاش — بلا استعلام إضافي.
  ///
  /// يُستخدم لاقتراح «هل تقصد …؟» فقط؛ لا يختلق أطباء ولا يضيف نتائج.
  Future<List<({String id, String name})>> doctorNameIndex() async {
    final rows = await _cachedDoctors();
    final out = <({String id, String name})>[];
    for (final row in rows) {
      final id = (row['id']?.toString() ?? '').trim();
      var name = (row['doctor_name']?.toString() ?? '').trim();
      if (name.isEmpty) name = (row['name']?.toString() ?? '').trim();
      if (id.isEmpty || name.isEmpty) continue;
      out.add((id: id, name: name));
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _cachedDoctors() {
    final cached = _doctorsCache;
    final at = _doctorsCacheAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _doctorsCacheTtl) {
      return Future.value(cached);
    }
    final inFlight = _doctorsLoadFuture;
    if (inFlight != null) return inFlight;

    final future = _fetchDoctorsIntoCache();
    _doctorsLoadFuture = future;
    future.whenComplete(() {
      if (identical(_doctorsLoadFuture, future)) {
        _doctorsLoadFuture = null;
      }
    });
    return future;
  }

  Future<List<Map<String, dynamic>>> _fetchDoctorsIntoCache() async {
    try {
      List data;
      try {
        data = await _client
            .from('doctors')
            .select()
            .or('is_active.eq.true,is_active.is.null')
            .limit(500) as List;
      } catch (e) {
        debugPrint('SmartSearchService doctors filter query failed, plain: $e');
        data = await _client.from('doctors').select().limit(500) as List;
      }
      final rows = data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _doctorsCache = rows;
      _doctorsCacheAt = DateTime.now();
      return rows;
    } catch (e, st) {
      debugPrint('SmartSearchService doctors cache fetch failed: $e\n$st');
      return _doctorsCache ?? const [];
    }
  }

  Future<List<SmartSearchResult>> search(
    String rawQuery, {
    int limit = 24,
  }) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return [];

    final pattern = _ilikePattern(query);
    final results = <SmartSearchResult>[];
    final intent = _detectLocalIntent(query);

    // الأطباء أولاً وبشكل متسلسل — الجدول صغير؛ لا نضيع الاسم بسبب سباق/كاش فارغ.
    await _searchDoctorsReliable(query, results);

    await Future.wait<void>([
      _searchLabs(rawQuery, pattern, results),
      _searchPackages(
        rawQuery,
        pattern,
        results,
        offerOnly: intent.activeOffersOnly,
        cheapestFirst: intent.cheapestFirst,
        labNameHint: intent.labNameHint,
      ),
      _searchAnalyses(
        _stripBoilerplateForAnalyses(query).isEmpty
            ? pattern
            : _ilikePattern(_stripBoilerplateForAnalyses(query)),
        results,
        originalQuery: query,
      ),
    ]);

    // بعد إيجاد التحاليل: اجلب الباقات التي تحتويها.
    final analysisHits = results
        .where((r) => r.type == SmartSearchResultType.analysis && r.analysisId != null)
        .toList();
    if (analysisHits.isNotEmpty) {
      await _attachPackagesForAnalyses(analysisHits, results);
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

  int _scoreMatch(String haystack, String needle) {
    return ArabicTextUtils.scoreMatch(haystack, needle);
  }

  String _normalize(String input) => ArabicTextUtils.normalize(input);

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

  /// بحث أطباء موثوق: كاش → جلب كامل → ilike بالاسم المجرّد.
  Future<void> _searchDoctorsReliable(
    String originalQuery,
    List<SmartSearchResult> out,
  ) async {
    final before = out.where((r) => r.type == SmartSearchResultType.doctor).length;

    await _searchDoctorsLocal(originalQuery, out);
    var doctorHits =
        out.where((r) => r.type == SmartSearchResultType.doctor).length - before;
    if (doctorHits > 0) return;

    invalidateDoctorsCache();
    await _scanDoctorsByName(originalQuery, out);
    doctorHits =
        out.where((r) => r.type == SmartSearchResultType.doctor).length - before;
    if (doctorHits > 0) return;

    // مسار ilike المباشر — أشكال مفصولة/موصولة لمركّبات عبد + ألقاب.
    final variants = ArabicTextUtils.doctorNameIlikeNeedles(originalQuery)
        .where((e) => e.trim().length >= 2)
        .toList();

    for (final v in variants.take(6)) {
      await _searchDoctorsIlike(
        _ilikePattern(v),
        out,
        originalQuery: originalQuery,
      );
      doctorHits =
          out.where((r) => r.type == SmartSearchResultType.doctor).length -
              before;
      if (doctorHits > 0) {
        debugPrint('SmartSearch doctors via ilike variant="$v" hits=$doctorHits');
        return;
      }
    }

    debugPrint(
      'SmartSearch doctors MISS query="$originalQuery" '
      'prepared="${ArabicTextUtils.prepareDoctorNameQuery(originalQuery)}"',
    );
  }

  /// بحث الأطباء على الكاش المحلي — بدون ilike لكل حرف.
  Future<void> _searchDoctorsLocal(
    String originalQuery,
    List<SmartSearchResult> out,
  ) async {
    var rows = await _cachedDoctors();
    if (rows.isEmpty) {
      invalidateDoctorsCache();
      rows = await _cachedDoctors();
    }
    if (rows.isEmpty) return;
    _appendDoctorRows(
      rows,
      out,
      originalQuery: originalQuery,
      variantNeedle: ArabicTextUtils.stripHonorifics(originalQuery),
    );
  }

  /// مسح مباشر لجدول الأطباء عند فشل الكاش لاسم واضح.
  Future<void> _scanDoctorsByName(
    String originalQuery,
    List<SmartSearchResult> out,
  ) async {
    try {
      List rows;
      try {
        rows = await _client
            .from('doctors')
            .select()
            .or('is_active.eq.true,is_active.is.null')
            .limit(500) as List;
      } catch (_) {
        rows = await _client.from('doctors').select().limit(500) as List;
      }
      final mapped = rows
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mapped.isNotEmpty) {
        _doctorsCache = mapped;
        _doctorsCacheAt = DateTime.now();
      }
      debugPrint('SmartSearch scan doctors rows=${mapped.length}');
      _appendDoctorRows(
        mapped,
        out,
        originalQuery: originalQuery,
        variantNeedle: ArabicTextUtils.stripHonorifics(originalQuery),
      );
    } catch (e, st) {
      debugPrint('SmartSearchService._scanDoctorsByName failed: $e\n$st');
    }
  }

  Future<void> _searchDoctorsIlike(
    String pattern,
    List<SmartSearchResult> out, {
    required String originalQuery,
  }) async {
    try {
      List rows;
      try {
        rows = await _client
            .from('doctors')
            .select()
            .or('is_active.eq.true,is_active.is.null')
            .ilike('doctor_name', pattern)
            .limit(24) as List;
      } catch (_) {
        rows = await _client
            .from('doctors')
            .select()
            .ilike('doctor_name', pattern)
            .limit(24) as List;
      }
      if (rows.isEmpty) return;
      _appendDoctorRows(
        rows,
        out,
        originalQuery: originalQuery,
        variantNeedle: ArabicTextUtils.stripHonorifics(originalQuery),
      );
    } catch (e, st) {
      debugPrint('SmartSearchService._searchDoctorsIlike failed: $e\n$st');
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
    var appended = 0;

    // ألقاب فقط («دكتور») — ليست بحث اسم.
    if (_doctorNameMatcher.isTitleOnlyQuery(originalQuery)) {
      debugPrint('SmartSearch append doctors skip title-only query');
      return;
    }

    for (final row in rows) {
      try {
        final map = Map<String, dynamic>.from(row as Map);
        // بعض الصفوف قد تستخدم name بدل doctor_name.
        if ((map['doctor_name']?.toString() ?? '').trim().isEmpty) {
          final alt = map['name']?.toString().trim() ?? '';
          if (alt.isNotEmpty) map['doctor_name'] = alt;
        }
        final doctor = DoctorItem.fromMap(map);
        if (doctor.name.isEmpty || doctor.id.isEmpty) continue;

        final leave = DoctorLeaveDisplay.fromDoctor(doctor);
        final nameMatch = _doctorNameMatcher.score(
          doctorName: doctor.name,
          query: originalNeedle,
          doctorId: doctor.id,
        );
        final nameScore = nameMatch.score;
        final specialtyScoreOriginal =
            _scoreMatch(doctor.specialty, originalNeedle);
        final specialtyScoreVariant = _scoreMatch(doctor.specialty, needle);
        final specialtyScore = specialtyScoreOriginal >= specialtyScoreVariant
            ? specialtyScoreOriginal
            : specialtyScoreVariant;

        var score = nameScore;
        if (specialtyScore > score) score = specialtyScore;

        // استعلام متعدد الأجزاء: لا تُسقط مرشحاً له تطابق اسم عبر المحرّك.
        if (nameTokens.length >= 2 &&
            nameScore < DoctorNameMatcher.minPlausibleScore &&
            specialtyScore < 70) {
          continue;
        }

        if (score <= 0) continue;

        if (leave.isOnLeave) score -= 15;

        String? availabilityLabel;
        if (leave.isOnLeave) {
          availabilityLabel = leave.badgeLabel;
        } else if (doctor.bookingStatus == 'available') {
          availabilityLabel = DoctorGender.availableShort(doctor.gender);
        } else if (doctor.bookingStatus == 'full') {
          availabilityLabel = 'مكتمل اليوم';
        } else if (doctor.bookingStatus == 'walk_in_only') {
          availabilityLabel = 'حضور مباشر فقط';
        } else if (doctor.bookingStatus == 'unavailable') {
          availabilityLabel = DoctorGender.notAvailable(doctor.gender);
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
            phone: doctor.phone.trim().isNotEmpty ? doctor.phone.trim() : null,
            whatsapp:
                doctor.whatsapp.trim().isNotEmpty ? doctor.whatsapp.trim() : null,
            clinicLocation: doctor.location.trim().isNotEmpty
                ? doctor.location.trim()
                : null,
            bookingStatus: doctor.bookingStatus,
            workingDays: doctor.workingDays,
            workingHours: doctor.workingHours,
            absenceFrom: doctor.absenceFrom,
            absenceTo: doctor.absenceTo,
            gender: doctor.gender,
            demandScore: _demandFromRow(map),
          ),
        );
        appended++;

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
      } catch (e, st) {
        debugPrint('SmartSearch append doctor row failed: $e\n$st');
      }
    }
    debugPrint(
      'SmartSearch append doctors query="$originalNeedle" '
      'rows=${rows.length} appended=$appended tokens=$nameTokens '
      'matcher=DoctorNameMatcher',
    );
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
              .or('lab_name.ilike.$pattern,address.ilike.$pattern')
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
            phone: lab.phone.trim().isNotEmpty ? lab.phone.trim() : null,
            whatsapp:
                lab.whatsapp.trim().isNotEmpty ? lab.whatsapp.trim() : null,
            clinicLocation:
                lab.address.trim().isNotEmpty ? lab.address.trim() : null,
            demandScore: _demandFromRow(
              Map<String, dynamic>.from(row),
            ),
          ),
        );
      }
    } catch (_) {}
  }

  /// مؤشر الطلب الحقيقي من أعمدة الصف (نفس وزن قسم «الأكثر طلبًا»).
  static int _demandFromRow(Map<String, dynamic> m) {
    int asInt(dynamic v) =>
        v is num ? v.toInt() : (int.tryParse('${v ?? 0}') ?? 0);
    return TrendingEntity.score(
      views: asInt(m['profile_views']),
      calls: asInt(m['call_taps']),
      whatsapp: asInt(m['whatsapp_taps']),
    );
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
              .or('package_name.ilike.$pattern,description.ilike.$pattern')
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
        String? labPhone;
        String? labWhatsapp;
        final labs = map['labs'];
        if (labs is Map) {
          labName = (labs['lab_name'] ?? labs['name'])?.toString() ?? '';
          final p = labs['phone']?.toString().trim() ?? '';
          final w = labs['whatsapp']?.toString().trim() ?? '';
          if (p.isNotEmpty) labPhone = p;
          if (w.isNotEmpty) labWhatsapp = w;
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
            phone: labPhone,
            whatsapp: labWhatsapp,
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
