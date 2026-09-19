import 'health_consent_coordinator.dart';
import 'sensitive_health_profile_models.dart';

enum HealthProfileCommandKind {
  none,
  showHealthProfile,
  rememberCandidates,
  forgetCondition,
  deleteAllRequest,
  cancelDelete,
  confirmDelete,
  enableHealthPersonalization,
  disableHealthPersonalization,
  consentYes,
  consentNo,
  consentLater,
  consentWhy,
  rejectNonOwner,
  rejectIneligible,
  clarifyAmbiguous,
  notImplementedChronic,
}

enum HealthProfilePendingKind {
  none,
  deleteWholeHealthProfile,
  rememberConsent,
}

class HealthProfilePendingOp {
  const HealthProfilePendingOp({
    this.kind = HealthProfilePendingKind.none,
    this.consent = HealthMemoryConsentPending.none,
  });

  final HealthProfilePendingKind kind;
  final HealthMemoryConsentPending consent;

  static const none = HealthProfilePendingOp();

  bool get isActive =>
      kind != HealthProfilePendingKind.none || consent.isActive;

  Map<String, Object?> debugMap() => {
        'pendingHealthOp': kind.name,
        ...consent.debugMap(),
      };
}

class HealthProfileCommandInterpretation {
  const HealthProfileCommandInterpretation({
    required this.kind,
    this.candidates = const [],
    this.conditionKey,
    this.message = '',
  });

  final HealthProfileCommandKind kind;
  final List<HealthConditionCandidate> candidates;
  final String? conditionKey;
  final String message;

  static const none = HealthProfileCommandInterpretation(
    kind: HealthProfileCommandKind.none,
  );

  bool get isHealthCommand => kind != HealthProfileCommandKind.none;

  Map<String, Object?> debugMap() => {
        'healthProfileCommandType': kind.name,
        'pendingCandidateCount': candidates.length,
        // بلا أسماء.
      };
}

class HealthProfileCommandTurnResult {
  const HealthProfileCommandTurnResult({
    required this.handled,
    required this.message,
    this.pending = HealthProfilePendingOp.none,
    this.success = true,
    this.commandKind = HealthProfileCommandKind.none,
    this.recordCount,
    this.textFirstOnly = true,
    this.deferToUrgentSafety = false,
  });

  final bool handled;
  final String message;
  final HealthProfilePendingOp pending;
  final bool success;
  final HealthProfileCommandKind commandKind;
  final int? recordCount;
  final bool textFirstOnly;
  final bool deferToUrgentSafety;

  static HealthProfileCommandTurnResult notHandled() =>
      const HealthProfileCommandTurnResult(
        handled: false,
        message: '',
        textFirstOnly: true,
      );

  Map<String, Object?> debugMap() => {
        'healthProfileCommandType': commandKind.name,
        'operationSuccess': success,
        'recordCount': recordCount,
        'consentState': pending.consent.isActive
            ? HealthConsentState.pending.name
            : (pending.kind == HealthProfilePendingKind.none
                ? HealthConsentState.none.name
                : pending.kind.name),
        // بلا أسماء حالات.
      };
}
