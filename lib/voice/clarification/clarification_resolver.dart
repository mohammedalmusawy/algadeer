import '../../doctors/specialty_catalog.dart';
import '../../models/lab_models.dart';
import '../../search/analysis_name_matcher.dart';
import '../../search/arabic_text_utils.dart';
import '../../search/doctor_name_matcher.dart';
import '../../search/laboratory_name_matcher.dart';
import '../../search/package_name_matcher.dart';
import '../context_resolver.dart';
import '../intent/assistant_intent.dart';
import '../intent/intent_result.dart';
import 'clarification_models.dart';
import 'clarification_response_builder.dart';

/// يحل إجابات المستخدم على PendingClarification — عام وليس خاصاً بطبيب واحد.
class ClarificationResolver {
  const ClarificationResolver({
    DoctorNameMatcher? matcher,
    LaboratoryNameMatcher? labMatcher,
    AnalysisNameMatcher? analysisMatcher,
    PackageNameMatcher? packageMatcher,
    ClarificationResponseBuilder? responseBuilder,
  })  : _matcher = matcher ?? const DoctorNameMatcher(),
        _labMatcher = labMatcher ?? const LaboratoryNameMatcher(),
        _analysisMatcher = analysisMatcher ?? const AnalysisNameMatcher(),
        _packageMatcher = packageMatcher ?? const PackageNameMatcher(),
        _responses = responseBuilder ?? const ClarificationResponseBuilder();

  final DoctorNameMatcher _matcher;
  final LaboratoryNameMatcher _labMatcher;
  final AnalysisNameMatcher _analysisMatcher;
  final PackageNameMatcher _packageMatcher;
  final ClarificationResponseBuilder _responses;

  ClarificationResolveResult resolve({
    required String query,
    required PendingClarification pending,
    IntentResult? intentResult,
  }) {
    final original = query.trim();
    if (original.isEmpty || pending.candidates.isEmpty) {
      return ClarificationResolveResult.notAnAnswer;
    }

    final normalized = ArabicTextUtils.normalize(original);
    final compact = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (_isBareYes(compact)) {
      if (pending.isYesNoConfirmation) {
        return ClarificationResolveResult(
          status: ClarificationResolveStatus.resolved,
          candidate: pending.candidates.first,
        );
      }
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.unsafeYesNo,
        message: _responses.unsafeYesNo(pending),
      );
    }

    if (_isBareNo(compact)) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.unsafeYesNo,
        message: _responses.unsafeYesNo(pending),
      );
    }

    final correctedOrdinal = _extractCorrectedOrdinal(compact);
    if (correctedOrdinal != null) {
      return _resolveOrdinal(correctedOrdinal, pending);
    }

    final ordinal = ContextResolver.extractOrdinal(normalized) ??
        intentResult?.entities.resultIndex;
    if (ordinal != null && _looksLikeOrdinalAnswer(compact, intentResult)) {
      return _resolveOrdinal(ordinal, pending);
    }

    ClarificationResolveResult? nameHit;
    switch (pending.entityType) {
      case ClarificationEntityType.laboratory:
        nameHit = _resolveByLabName(original, pending);
        break;
      case ClarificationEntityType.analysis:
        nameHit = _resolveByAnalysisName(original, pending);
        break;
      case ClarificationEntityType.package:
      case ClarificationEntityType.offer:
        nameHit = _resolveByPackageName(original, pending);
        break;
      default:
        nameHit = _resolveByName(original, pending);
    }
    if (nameHit != null) return nameHit;

    final specialtyHit = _resolveBySecondaryLabel(normalized, pending);
    if (specialtyHit != null) return specialtyHit;

    final tokenHit = _resolveByUniqueToken(normalized, pending);
    if (tokenHit != null) return tokenHit;

    if (_looksLikeClarificationAttempt(compact, intentResult)) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.stillAmbiguous,
        message: _responses.stillAmbiguous(pending),
      );
    }

    return ClarificationResolveResult.notAnAnswer;
  }

  ClarificationResolveResult _resolveOrdinal(
    int ordinal,
    PendingClarification pending,
  ) {
    final n = pending.candidates.length;
    final index = ordinal == -1 ? n : ordinal;
    if (index < 1 || index > n) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.invalidOrdinal,
        message: _responses.invalidOrdinal(pending),
      );
    }
    return ClarificationResolveResult(
      status: ClarificationResolveStatus.resolved,
      candidate: pending.candidates[index - 1],
    );
  }

  ClarificationResolveResult? _resolveByName(
    String query,
    PendingClarification pending,
  ) {
    final doctors = [
      for (final c in pending.candidates) (id: c.id, name: c.primaryLabel),
    ];
    if (doctors.isEmpty) return null;

    final prepared = ArabicTextUtils.prepareDoctorNameQuery(query);
    if (prepared.trim().length < 2) return null;

    final batch = _matcher.matchDoctors(query: prepared, doctors: doctors);
    if (batch.matches.isEmpty) return null;

    if (batch.isAmbiguous) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.stillAmbiguous,
        message: _responses.stillAmbiguous(pending),
      );
    }

    final best = batch.best!;
    if (!best.isStrong && best.score < 80) return null;

    final hit = pending.candidates.cast<ClarificationCandidate?>().firstWhere(
      (c) => c?.id == best.doctorId || c?.primaryLabel == best.doctorName,
      orElse: () => null,
    );
    if (hit == null) return null;
    return ClarificationResolveResult(
      status: ClarificationResolveStatus.resolved,
      candidate: hit,
    );
  }

  ClarificationResolveResult? _resolveByLabName(
    String query,
    PendingClarification pending,
  ) {
    final labs = [
      for (final c in pending.candidates) (id: c.id, name: c.primaryLabel),
    ];
    if (labs.isEmpty) return null;

    final prepared = _labMatcher.prepareQuery(query);
    if (prepared.trim().length < 2) return null;

    final batch = _labMatcher.matchLabs(query: prepared, labs: labs);
    if (batch.matches.isEmpty) return null;

    if (batch.isAmbiguous) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.stillAmbiguous,
        message: _responses.stillAmbiguous(pending),
      );
    }

    final best = batch.best!;
    if (!best.isStrong && best.score < 80) return null;

    final hit = pending.candidates.cast<ClarificationCandidate?>().firstWhere(
      (c) => c?.id == best.labId || c?.primaryLabel == best.labName,
      orElse: () => null,
    );
    if (hit == null) return null;
    return ClarificationResolveResult(
      status: ClarificationResolveStatus.resolved,
      candidate: hit,
    );
  }

  ClarificationResolveResult? _resolveByAnalysisName(
    String query,
    PendingClarification pending,
  ) {
    final items = <AnalysisItem>[
      for (final c in pending.candidates)
        AnalysisItem(
          id: c.id,
          name: c.secondaryLabel?.trim().isNotEmpty == true
              ? c.secondaryLabel!.trim()
              : c.primaryLabel,
          nameAr: c.primaryLabel,
          shortName: c.secondaryLabel ?? '',
        ),
    ];
    if (items.isEmpty) return null;

    final batch = _analysisMatcher.matchAnalyses(query: query, analyses: items);
    if (batch.matches.isEmpty) return null;
    if (batch.isAmbiguous) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.stillAmbiguous,
        message: _responses.stillAmbiguous(pending),
      );
    }
    final best = batch.best!;
    if (!best.isStrong && best.score < 80) return null;

    final hit = pending.candidates.cast<ClarificationCandidate?>().firstWhere(
      (c) => c?.id == best.analysisId || c?.primaryLabel == best.analysisName,
      orElse: () => null,
    );
    if (hit != null) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.resolved,
        candidate: hit,
      );
    }
    return null;
  }

  ClarificationResolveResult? _resolveByPackageName(
    String query,
    PendingClarification pending,
  ) {
    final packages = [
      for (final c in pending.candidates)
        (
          id: c.id,
          name: c.primaryLabel,
          labId: null as String?,
        ),
    ];
    if (packages.isEmpty) return null;

    final prepared = _packageMatcher.prepareQuery(query);
    if (prepared.trim().length < 2) return null;

    final batch =
        _packageMatcher.matchPackages(query: prepared, packages: packages);
    if (batch.matches.isEmpty) {
      // ثانوي: اسم المختبر في secondaryLabel.
      final n = ArabicTextUtils.normalize(query);
      final byLab = <ClarificationCandidate>[];
      for (final c in pending.candidates) {
        final sec = ArabicTextUtils.normalize(c.secondaryLabel ?? '');
        if (sec.isNotEmpty &&
            (sec.contains(n) || n.contains(sec) || ArabicTextUtils.scoreMatch(sec, n) >= 70)) {
          byLab.add(c);
        }
      }
      if (byLab.length == 1) {
        return ClarificationResolveResult(
          status: ClarificationResolveStatus.resolved,
          candidate: byLab.first,
        );
      }
      return null;
    }
    if (batch.isAmbiguous) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.stillAmbiguous,
        message: _responses.stillAmbiguous(pending),
      );
    }
    final best = batch.best!;
    if (!best.isStrong && best.score < 80) return null;
    final hit = pending.candidates.cast<ClarificationCandidate?>().firstWhere(
      (c) => c?.id == best.packageId || c?.primaryLabel == best.packageName,
      orElse: () => null,
    );
    if (hit != null) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.resolved,
        candidate: hit,
      );
    }
    return null;
  }

  ClarificationResolveResult? _resolveBySecondaryLabel(
    String normalizedQuery,
    PendingClarification pending,
  ) {
    final q = normalizedQuery.trim();
    if (q.length < 2) return null;

    final cleaned = q
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:ال)?(?:دكتور|طبيب|طبيبه|طبيبة|اختصاص|تخصص|مختبر|مختبرات|تحليل|تحاليل)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length < 2) return null;

    final catalog = SpecialtyCatalog.match(cleaned);
    final catalogNorm = catalog == null
        ? null
        : ArabicTextUtils.normalize(catalog.nameAr);

    final hits = <ClarificationCandidate>[];
    for (final c in pending.candidates) {
      final secondary = ArabicTextUtils.normalize(c.secondaryLabel ?? '');
      if (secondary.isEmpty) continue;
      final matched = SpecialtyCatalog.match(c.secondaryLabel ?? '');
      final secCanon = ArabicTextUtils.normalize(
        matched?.nameAr ?? c.secondaryLabel ?? '',
      );

      final ok = secondary.contains(cleaned) ||
          cleaned.contains(secondary) ||
          (catalogNorm != null &&
              (secCanon.contains(catalogNorm) ||
                  catalogNorm.contains(secCanon) ||
                  secondary.contains(catalogNorm))) ||
          ArabicTextUtils.scoreMatch(c.secondaryLabel ?? '', cleaned) >= 70;
      if (ok) hits.add(c);
    }

    if (hits.length == 1) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.resolved,
        candidate: hits.first,
      );
    }
    if (hits.length > 1) {
      return ClarificationResolveResult(
        status: ClarificationResolveStatus.stillAmbiguous,
        message: _responses.stillAmbiguous(pending),
      );
    }
    return null;
  }

  ClarificationResolveResult? _resolveByUniqueToken(
    String normalizedQuery,
    PendingClarification pending,
  ) {
    final isLab = pending.entityType == ClarificationEntityType.laboratory;
    final isAnalysis = pending.entityType == ClarificationEntityType.analysis;
    final isPackage = pending.entityType == ClarificationEntityType.package ||
        pending.entityType == ClarificationEntityType.offer;
    final prepared = isLab
        ? _labMatcher.prepareQuery(normalizedQuery)
        : isAnalysis
            ? _analysisMatcher.prepareQuery(normalizedQuery)
            : isPackage
                ? _packageMatcher.prepareQuery(normalizedQuery)
                : ArabicTextUtils.prepareDoctorNameQuery(normalizedQuery);
    final tokens = prepared
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .where((t) => !_isNoiseToken(t))
        .toList();
    if (tokens.isEmpty) return null;

    ClarificationCandidate? unique;
    for (final token in tokens) {
      final hits = <ClarificationCandidate>[];
      for (final c in pending.candidates) {
        final name = isLab || isAnalysis || isPackage
            ? ArabicTextUtils.normalize(
                '${c.primaryLabel} ${c.secondaryLabel ?? ''}',
              )
            : ArabicTextUtils.prepareDoctorStoredName(c.primaryLabel);
        final parts = name.split(RegExp(r'\s+'));
        final match = parts.any(
              (p) =>
                  p == token ||
                  p.contains(token) ||
                  token.contains(p) && p.length >= 3,
            ) ||
            name.contains(token);
        if (match) hits.add(c);
      }
      if (hits.length == 1) {
        if (unique != null && unique.id != hits.first.id) {
          return ClarificationResolveResult(
            status: ClarificationResolveStatus.stillAmbiguous,
            message: _responses.stillAmbiguous(pending),
          );
        }
        unique = hits.first;
      } else if (hits.length > 1 && tokens.length == 1) {
        return ClarificationResolveResult(
          status: ClarificationResolveStatus.stillAmbiguous,
          message: _responses.stillAmbiguous(pending),
        );
      }
    }
    if (unique == null) return null;
    return ClarificationResolveResult(
      status: ClarificationResolveStatus.resolved,
      candidate: unique,
    );
  }

  bool _looksLikeOrdinalAnswer(String compact, IntentResult? intent) {
    if (intent?.intent == AssistantIntent.selectResult) return true;
    if (ContextResolver.extractOrdinal(compact) == null) return false;
    if (intent != null &&
        intent.isActionIntent &&
        intent.intent != AssistantIntent.selectResult) {
      return true;
    }
    final stripped = compact
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:لا|لاء|مو|بدل|اقصد|أقصد|اختار|اريد|أريد|اتصل|اتصال|دقله|دزله|دز|راسل|ارسل|أرسل|واتساب|واتس|whatsapp|وين|عيادة|مختبر|تحليل|على|ل)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:الاول|الأول|اول|أول|الاولى|الأولى|الثاني|ثاني|الثانيه|الثانية|الثالث|ثالث|الثالثه|الثالثة|الرابع|رابع|الخامس|خامس|الاخير|الأخير|الاخيره|الأخيرة)(?:\s*واحد)?(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped.isEmpty || stripped.length <= 8;
  }

  bool _looksLikeClarificationAttempt(String compact, IntentResult? intent) {
    if (compact.split(RegExp(r'\s+')).length <= 5) return true;
    if (intent?.intent == AssistantIntent.selectResult) return true;
    if (intent?.intent == AssistantIntent.doctorSearch) return true;
    if (intent?.intent == AssistantIntent.findLab) return true;
    if (intent?.intent == AssistantIntent.findAnalysis) return true;
    return false;
  }

  int? _extractCorrectedOrdinal(String compact) {
    final hasNegation =
        RegExp(r'(?:^|\s)(?:لا|لاء|مو|بدل)(?=\s|$)').hasMatch(compact);
    if (!hasNegation) return null;
    return ContextResolver.extractOrdinal(compact);
  }

  static bool _isBareYes(String n) {
    return RegExp(r'^(?:نعم|اي|إي|ايوه|أيوه|صح|تمام|اوكي|موافق)$')
        .hasMatch(n);
  }

  static bool _isBareNo(String n) {
    return RegExp(r'^(?:لا|لاء|لاا|مو)$').hasMatch(n);
  }

  static bool _isNoiseToken(String t) {
    return RegExp(
      r'^(?:ال)?(?:دكتور|دكتورة|طبيب|طبيبة|اختصاص|تخصص|مختبر|مختبرات|تحليل|تحاليل)$',
    ).hasMatch(t);
  }

  static bool isClearNewSearchIntent(IntentResult intent, String query) {
    switch (intent.intent) {
      case AssistantIntent.specialtySearch:
      case AssistantIntent.findLab:
        return true;
      case AssistantIntent.findAnalysis:
        return (intent.entities.analysis ?? '').trim().isNotEmpty ||
            intent.entities.analysisTerms.isNotEmpty;
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
        return (intent.entities.packageName ?? '').trim().isNotEmpty ||
            intent.entities.analysisTerms.length >= 2;
      case AssistantIntent.generalSearch:
        final n = ArabicTextUtils.normalize(query);
        return RegExp(
              r'(?:أريد|اريد|ابي).{0,12}(?:طبيب|دكتور|اختصاص)',
            ).hasMatch(n) ||
            RegExp(
              r'(?:أريد|اريد|ابي).{0,12}(?:مختبر|مختبرات)',
            ).hasMatch(n) ||
            RegExp(
              r'(?:أريد|اريد|ابي).{0,12}(?:تحليل|تحاليل)',
            ).hasMatch(n);
      case AssistantIntent.doctorSearch:
        final n = ArabicTextUtils.normalize(query);
        if (RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور).{0,16}(?:طبيب|دكتور)',
        ).hasMatch(n)) {
          return true;
        }
        return false;
      default:
        return false;
    }
  }
}
