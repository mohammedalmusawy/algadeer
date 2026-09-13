import 'arabic_text_utils.dart';
import 'smart_search_models.dart';

/// يقرر التنقل المباشر فقط عند Match فريد وثقة عالية.
/// لا يختار عشوائياً عند الغموض.
class SmartNavigationResolver {
  static const int minDirectConfidence = 80;

  /// يستخرج الهدف المباشر من نتائج البحث المحلي.
  SmartNavigationDecision resolve({
    required String query,
    required List<SmartSearchResult> results,
    bool allowDirect = true,
    bool forceShowResults = false,
  }) {
    final q = query.trim();
    if (q.isEmpty || results.isEmpty) {
      return const SmartNavigationDecision(
        action: SmartNavAction.none,
        message: '',
        confidence: 0,
      );
    }

    if (forceShowResults || !allowDirect) {
      return SmartNavigationDecision(
        action: SmartNavAction.showResults,
        message: _multiMessage(results),
        confidence: results.first.score,
        ambiguous: true,
      );
    }

    // تحليل: لا نفتح مباشرة — نعرض التحليل + الباقات المرتبطة.
    final analyses = results
        .where((r) => r.type == SmartSearchResultType.analysis)
        .toList();
    final packagesForAnalysis = results
        .where(
          (r) =>
              (r.type == SmartSearchResultType.package ||
                  r.type == SmartSearchResultType.offer) &&
              r.relatedAnalysisId != null,
        )
        .toList();
    if (analyses.isNotEmpty &&
        _looksLikeAnalysisQuery(q) &&
        (packagesForAnalysis.isNotEmpty || analyses.length == 1)) {
      if (packagesForAnalysis.isEmpty && analyses.length == 1) {
        return SmartNavigationDecision(
          action: SmartNavAction.showAnalysisPackages,
          message:
              'وجدت التحليل «${analyses.first.title}». لا توجد باقات مرتبطة حالياً.',
          target: analyses.first,
          confidence: analyses.first.score,
          ambiguous: true,
        );
      }
      return SmartNavigationDecision(
        action: SmartNavAction.showAnalysisPackages,
        message: packagesForAnalysis.length == 1
            ? 'وجدت التحليل والباقة المرتبطة.'
            : 'وجدت التحليل والباقات التي تحتويه — اختر الباقة.',
        target: analyses.first,
        confidence: analyses.first.score,
        ambiguous: packagesForAnalysis.length != 1,
      );
    }

    final navigable = results.where((r) => r.hasNavigableEntity).toList();
    if (navigable.isEmpty) {
      return SmartNavigationDecision(
        action: SmartNavAction.showResults,
        message: 'اختر من النتائج.',
        confidence: results.first.score,
        ambiguous: true,
      );
    }

    // مجموعة نفس النوع في أعلى النتائج.
    final top = navigable.first;
    final sameType = navigable.where((r) => r.type == top.type).toList();

    // اختصاص: لا تفتح طبيباً عشوائياً.
    if (top.type == SmartSearchResultType.specialty) {
      return SmartNavigationDecision(
        action: SmartNavAction.showSpecialtyDoctors,
        message: 'عرض أطباء اختصاص ${top.title}',
        target: top,
        confidence: top.score,
        ambiguous: true,
      );
    }

    // اسم طبيب متعدد الأجزاء: لا تخلط أطباء يشتركون في الاسم الأول فقط.
    if (top.type == SmartSearchResultType.doctor) {
      final doctorDecision = _resolveDoctorNameMatch(q, sameType);
      if (doctorDecision != null) return doctorDecision;
    }

    // أكثر من نتيجة من نفس النوع بأسماء متقاربة → غموض.
    if (sameType.length > 1) {
      final strong = sameType.where((r) => r.score >= minDirectConfidence).toList();
      if (strong.length != 1) {
        return SmartNavigationDecision(
          action: SmartNavAction.showResults,
          message: _ambiguousMessage(top.type, sameType.length),
          confidence: top.score,
          ambiguous: true,
        );
      }
      // واحدة قوية فقط ضمن نفس النوع.
      return _direct(strong.first);
    }

    // نتيجة واحدة قابلة للتنقل وبثقة كافية.
    if (sameType.length == 1 && top.score >= minDirectConfidence) {
      return _direct(top);
    }

    // ثقة متوسطة مع نتيجة واحدة من نوع كيان واضح (اسم طويل / تطابق جيد).
    if (sameType.length == 1 &&
        top.score >= 50 &&
        _queryClearlyTargetsEntity(q, top)) {
      return _direct(top.copyWithBoostedScore(top.score < 80 ? 80 : top.score));
    }

    return SmartNavigationDecision(
      action: SmartNavAction.showResults,
      message: _multiMessage(results),
      confidence: top.score,
      ambiguous: true,
    );
  }

  SmartNavigationDecision _direct(SmartSearchResult target) {
    switch (target.type) {
      case SmartSearchResultType.doctor:
        return SmartNavigationDecision(
          action: SmartNavAction.openDoctor,
          message: 'فتح ملف الطبيب ${target.title}',
          target: target,
          confidence: target.score,
        );
      case SmartSearchResultType.lab:
        return SmartNavigationDecision(
          action: SmartNavAction.openLab,
          message: 'فتح ملف المختبر ${target.title}',
          target: target,
          confidence: target.score,
        );
      case SmartSearchResultType.offer:
        return SmartNavigationDecision(
          action: SmartNavAction.openOffer,
          message: 'فتح العرض ${target.title}',
          target: target,
          confidence: target.score,
        );
      case SmartSearchResultType.package:
        return SmartNavigationDecision(
          action: SmartNavAction.openPackage,
          message: 'فتح الباقة ${target.title}',
          target: target,
          confidence: target.score,
        );
      case SmartSearchResultType.analysis:
        return SmartNavigationDecision(
          action: SmartNavAction.showAnalysisPackages,
          message: 'نتائج التحليل ${target.title}',
          target: target,
          confidence: target.score,
          ambiguous: true,
        );
      case SmartSearchResultType.specialty:
        return SmartNavigationDecision(
          action: SmartNavAction.showSpecialtyDoctors,
          message: 'أطباء اختصاص ${target.title}',
          target: target,
          confidence: target.score,
          ambiguous: true,
        );
    }
  }

  /// عند وجود جزئين أو أكثر من الاسم: أظهر فقط من طابق كل الأجزاء.
  SmartNavigationDecision? _resolveDoctorNameMatch(
    String query,
    List<SmartSearchResult> doctors,
  ) {
    final tokens = ArabicTextUtils.meaningfulNameTokens(query);
    if (tokens.length < 2 || doctors.isEmpty) return null;

    final fullNameHits = doctors
        .where((r) => ArabicTextUtils.allDoctorNameTokensMatch(r.title, query))
        .toList();

    if (fullNameHits.length == 1) {
      final winner = fullNameHits.first;
      if (winner.score >= minDirectConfidence) {
        return _direct(winner);
      }
      return _direct(
        winner.copyWithBoostedScore(
          winner.score < minDirectConfidence ? minDirectConfidence : winner.score,
        ),
      );
    }

    if (fullNameHits.length > 1) {
      final strong = fullNameHits
          .where((r) => r.score >= minDirectConfidence)
          .toList();
      if (strong.length == 1) {
        return _direct(strong.first);
      }
      return SmartNavigationDecision(
        action: SmartNavAction.showResults,
        message: _ambiguousMessage(
          SmartSearchResultType.doctor,
          fullNameHits.length,
        ),
        confidence: fullNameHits.first.score,
        ambiguous: true,
      );
    }

    return null;
  }

  bool _looksLikeAnalysisQuery(String q) {
    final lower = q.toLowerCase();
    if (RegExp(r'\b(alt|ast|alp|tsh|cbc|hba1c|crp|urea|creatinine)\b',
            caseSensitive: false)
        .hasMatch(lower)) {
      return true;
    }
    return lower.contains('تحليل') || lower.contains('تحاليل');
  }

  bool _queryClearlyTargetsEntity(String query, SmartSearchResult result) {
    final q = ArabicTextUtils.normalize(
      ArabicTextUtils.stripHonorifics(query),
    );
    final title = ArabicTextUtils.normalize(
      ArabicTextUtils.stripHonorifics(result.title),
    );
    if (title.isEmpty || q.isEmpty) return false;
    if (title == q) return true;
    if (title.contains(q) && q.length >= 3) return true;
    if (q.contains(title) && title.length >= 3) return true;

    // إزالة كلمات الضجيج الشائعة.
    final stripped = q
        .replaceAll(
          RegExp(
            r'(افتح|اريد|أريد|اكو|أكو|مختبر|باقة|عرض|عروض|تحاليل|تحليل)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.isEmpty) return false;
    if (title.contains(stripped) || stripped.contains(title)) return true;

    final tokens =
        stripped.split(RegExp(r'\s+')).where((e) => e.length >= 3).toList();
    if (tokens.isEmpty) return false;
    final hits = tokens.where(title.contains).length;
    return hits > 0 && hits == tokens.length;
  }

  String _ambiguousMessage(SmartSearchResultType type, int count) {
    switch (type) {
      case SmartSearchResultType.doctor:
        return 'وجدت أكثر من طبيب ($count)، اختر الطبيب المقصود.';
      case SmartSearchResultType.lab:
        return 'وجدت أكثر من مختبر ($count)، اختر المختبر المقصود.';
      case SmartSearchResultType.package:
        return 'وجدت أكثر من باقة ($count)، اختر الباقة المقصودة.';
      case SmartSearchResultType.offer:
        return 'وجدت أكثر من عرض ($count)، اختر العرض المقصود.';
      case SmartSearchResultType.analysis:
        return 'وجدت أكثر من تحليل ($count)، اختر التحليل المقصود.';
      case SmartSearchResultType.specialty:
        return 'وجدت أكثر من اختصاص، اختر المقصود.';
    }
  }

  String _multiMessage(List<SmartSearchResult> results) {
    final doctors =
        results.where((r) => r.type == SmartSearchResultType.doctor).length;
    if (doctors > 1) {
      return 'وجدت أكثر من طبيب، اختر الطبيب المقصود.';
    }
    return 'وجدت ${results.length} نتيجة — اختر من القائمة.';
  }
}

extension on SmartSearchResult {
  SmartSearchResult copyWithBoostedScore(int newScore) {
    return SmartSearchResult(
      type: type,
      title: title,
      subtitle: subtitle,
      doctorId: doctorId,
      labId: labId,
      packageId: packageId,
      analysisId: analysisId,
      score: newScore,
      imageUrl: imageUrl,
      specialty: specialty,
      labName: labName,
      oldPrice: oldPrice,
      newPrice: newPrice,
      discountPercent: discountPercent,
      absenceBadge: absenceBadge,
      availabilityLabel: availabilityLabel,
      bioSnippet: bioSnippet,
      isOnLeave: isOnLeave,
      relatedAnalysisId: relatedAnalysisId,
      relatedAnalysisTitle: relatedAnalysisTitle,
    );
  }
}
