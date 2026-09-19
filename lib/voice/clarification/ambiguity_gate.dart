import '../../search/smart_search_models.dart';
import '../intent/assistant_intent.dart';
import 'clarification_models.dart';

/// بوابة الغموض — تُنشئ PendingClarification عند الحاجة فقط.
class AmbiguityGate {
  const AmbiguityGate();

  /// يفتح توضيحاً عندما يوجد أكثر من مرشّح طبيب ذي معنى.
  PendingClarification? fromDoctorResults({
    required List<SmartSearchResult> doctors,
    AssistantIntent? originalIntent,
    String? originalQuery,
    AssistantIntent? pendingAction,
    ClarificationReason reason = ClarificationReason.multipleMatches,
  }) {
    final list = doctors
        .where((d) => d.type == SmartSearchResultType.doctor)
        .toList(growable: false);
    if (list.length < 2) return null;

    final candidates = [
      for (final d in list)
        ClarificationCandidate(
          id: d.doctorId ?? d.title,
          entityType: ClarificationEntityType.doctor,
          primaryLabel: d.title,
          secondaryLabel: (d.specialty ?? d.subtitle).trim().isEmpty
              ? null
              : (d.specialty ?? d.subtitle).trim(),
          payload: d,
        ),
    ];

    final action = pendingAction ??
        (_isContinuableDoctorAction(originalIntent) ? originalIntent : null);

    return PendingClarification(
      entityType: ClarificationEntityType.doctor,
      reason: reason,
      candidates: candidates,
      originalIntent: originalIntent,
      originalQuery: originalQuery,
      pendingAction: action,
    );
  }

  /// يفتح توضيحاً عندما يوجد أكثر من مختبر مطابق.
  PendingClarification? fromLabResults({
    required List<SmartSearchResult> labs,
    AssistantIntent? originalIntent,
    String? originalQuery,
    AssistantIntent? pendingAction,
    ClarificationReason reason = ClarificationReason.multipleMatches,
  }) {
    final list = labs
        .where((d) => d.type == SmartSearchResultType.lab)
        .toList(growable: false);
    if (list.length < 2) return null;

    final candidates = [
      for (final lab in list)
        ClarificationCandidate(
          id: lab.labId ?? lab.title,
          entityType: ClarificationEntityType.laboratory,
          primaryLabel: lab.title,
          secondaryLabel: _labSecondary(lab),
          payload: lab,
        ),
    ];

    final action = pendingAction ??
        (_isContinuableLabAction(originalIntent) ? originalIntent : null);

    return PendingClarification(
      entityType: ClarificationEntityType.laboratory,
      reason: reason,
      candidates: candidates,
      originalIntent: originalIntent,
      originalQuery: originalQuery,
      pendingAction: action,
    );
  }

  /// يفتح توضيحاً عندما يوجد أكثر من تحليل مطابق.
  PendingClarification? fromAnalysisResults({
    required List<SmartSearchResult> analyses,
    AssistantIntent? originalIntent,
    String? originalQuery,
    AssistantIntent? pendingAction,
    ClarificationReason reason = ClarificationReason.multipleMatches,
  }) {
    final list = analyses
        .where((d) => d.type == SmartSearchResultType.analysis)
        .toList(growable: false);
    if (list.length < 2) return null;

    final candidates = [
      for (final a in list)
        ClarificationCandidate(
          id: a.analysisId ?? a.title,
          entityType: ClarificationEntityType.analysis,
          primaryLabel: a.title,
          secondaryLabel: _analysisSecondary(a),
          payload: a,
        ),
    ];

    final action = pendingAction ??
        (_isContinuableAnalysisAction(originalIntent) ? originalIntent : null);

    return PendingClarification(
      entityType: ClarificationEntityType.analysis,
      reason: reason,
      candidates: candidates,
      originalIntent: originalIntent,
      originalQuery: originalQuery,
      pendingAction: action,
    );
  }

  static bool _isContinuableDoctorAction(AssistantIntent? intent) {
    switch (intent) {
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.showLocation:
      case AssistantIntent.showProfile:
        return true;
      default:
        return false;
    }
  }

  static bool _isContinuableLabAction(AssistantIntent? intent) {
    switch (intent) {
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.showLocation:
      case AssistantIntent.showProfile:
      case AssistantIntent.findPackage:
      case AssistantIntent.findAnalysis:
        return true;
      default:
        return false;
    }
  }

  static bool _isContinuableAnalysisAction(AssistantIntent? intent) {
    switch (intent) {
      case AssistantIntent.findAnalysis:
      case AssistantIntent.findPackage:
      case AssistantIntent.findLab:
        return true;
      default:
        return false;
    }
  }

  /// يفتح توضيحاً عندما يوجد أكثر من باقة مطابقة (نفس الاسم في مختبرات مختلفة).
  PendingClarification? fromPackageResults({
    required List<SmartSearchResult> packages,
    AssistantIntent? originalIntent,
    String? originalQuery,
    AssistantIntent? pendingAction,
    ClarificationReason reason = ClarificationReason.multipleMatches,
  }) {
    final list = packages
        .where(
          (d) =>
              d.type == SmartSearchResultType.package ||
              d.type == SmartSearchResultType.offer,
        )
        .toList(growable: false);
    if (list.length < 2) return null;

    final candidates = [
      for (final p in list)
        ClarificationCandidate(
          id: p.packageId ?? p.title,
          entityType: ClarificationEntityType.package,
          primaryLabel: p.title,
          secondaryLabel: _packageSecondary(p),
          payload: p,
        ),
    ];

    final action = pendingAction ??
        (_isContinuablePackageAction(originalIntent) ? originalIntent : null);

    return PendingClarification(
      entityType: ClarificationEntityType.package,
      reason: reason,
      candidates: candidates,
      originalIntent: originalIntent,
      originalQuery: originalQuery,
      pendingAction: action,
    );
  }

  static bool _isContinuablePackageAction(AssistantIntent? intent) {
    switch (intent) {
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
      case AssistantIntent.showLocation:
      case AssistantIntent.showProfile:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
        return true;
      default:
        return false;
    }
  }

  static String? _labSecondary(SmartSearchResult lab) {
    final loc = (lab.clinicLocation ?? lab.subtitle).trim();
    if (loc.isEmpty || loc == 'مختبر') return null;
    return loc;
  }

  static String? _analysisSecondary(SmartSearchResult a) {
    final s = a.subtitle.trim();
    if (s.isEmpty || s == 'تحليل') return null;
    return s;
  }

  static String? _packageSecondary(SmartSearchResult p) {
    final lab = (p.labName ?? p.subtitle).trim();
    if (lab.isEmpty || lab == 'باقة') return null;
    return lab.startsWith('مختبر') ? lab : 'مختبر $lab';
  }
}
