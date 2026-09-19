import '../sensitive_profile/sensitive_health_profile_models.dart';
import 'family_health_consent_coordinator.dart';

enum FamilyHealthCommandKind {
  none,
  rememberCandidates,
  showPersonHealth,
  showFamilyHealthOverview,
  forgetCondition,
  deleteAllHealthRequest,
  confirmDeleteAllHealth,
  cancelDelete,
  consentYes,
  consentNo,
  consentLater,
  consentWhy,
  clarifyPerson,
  needsPersistentProfile,
  rejectIneligible,
  rejectTemporarySubject,
  notImplementedChronic,
  notImplementedAllergy,
  notImplementedMedication,
  deferToUrgentSafety,
  deferToMentalSafety,
  deferToProvider,
}

enum FamilyHealthPendingKind {
  none,
  rememberConsent,
  deleteAllHealthForPerson,
  clarifyPersonBeforeConsent,
  deletePersonWithHealth,
}

class FamilyHealthPendingOp {
  const FamilyHealthPendingOp({
    this.kind = FamilyHealthPendingKind.none,
    this.consent = FamilyHealthMemoryConsentPending.none,
    this.targetPersonId,
    this.candidatePersonIds = const [],
    this.pendingCandidates = const [],
    this.originalQuery = '',
  });

  final FamilyHealthPendingKind kind;
  final FamilyHealthMemoryConsentPending consent;
  final String? targetPersonId;
  final List<String> candidatePersonIds;
  final List<HealthConditionCandidate> pendingCandidates;
  final String originalQuery;

  static const none = FamilyHealthPendingOp();

  bool get isActive =>
      kind != FamilyHealthPendingKind.none || consent.isActive;

  Map<String, Object?> debugMap() => {
        'pendingFamilyHealthOp': kind.name,
        'eligibleConditionCount':
            consent.candidates.length + pendingCandidates.length,
        'candidateCount': candidatePersonIds.length,
        'hasTargetPerson': targetPersonId != null,
        ...consent.debugMap(),
      };
}

class FamilyHealthCommandInterpretation {
  const FamilyHealthCommandInterpretation({
    required this.kind,
    this.candidates = const [],
    this.conditionKey,
    this.message = '',
    this.personNameHint,
    this.relationshipHint,
    this.mixedClarify = false,
  });

  final FamilyHealthCommandKind kind;
  final List<HealthConditionCandidate> candidates;
  final String? conditionKey;
  final String message;
  final String? personNameHint;
  final String? relationshipHint;
  final bool mixedClarify;

  static const none = FamilyHealthCommandInterpretation(
    kind: FamilyHealthCommandKind.none,
  );

  bool get isCommand => kind != FamilyHealthCommandKind.none;

  Map<String, Object?> debugMap() => {
        'familyHealthCommandType': kind.name,
        'eligibleConditionCount': candidates.length,
      };
}

class FamilyHealthCommandTurnResult {
  const FamilyHealthCommandTurnResult({
    required this.handled,
    required this.message,
    this.pending = FamilyHealthPendingOp.none,
    this.success = true,
    this.commandKind = FamilyHealthCommandKind.none,
    this.recordCount,
    this.textFirstOnly = true,
    this.linkedPersonId,
    this.resolutionStatus = 'none',
    this.deferToUrgentSafety = false,
    this.deferToMentalSafety = false,
    this.deferToProvider = false,
  });

  final bool handled;
  final String message;
  final FamilyHealthPendingOp pending;
  final bool success;
  final FamilyHealthCommandKind commandKind;
  final int? recordCount;
  final bool textFirstOnly;
  final String? linkedPersonId;
  final String resolutionStatus;
  final bool deferToUrgentSafety;
  final bool deferToMentalSafety;
  final bool deferToProvider;

  static FamilyHealthCommandTurnResult notHandled() =>
      const FamilyHealthCommandTurnResult(handled: false, message: '');

  Map<String, Object?> debugMap() => {
        'familyHealthCommandType': commandKind.name,
        'resolutionStatus': resolutionStatus,
        'eligibleConditionCount': pending.consent.candidates.length,
        'consentState': pending.consent.isActive
            ? HealthConsentState.pending.name
            : (pending.kind == FamilyHealthPendingKind.none
                ? HealthConsentState.none.name
                : pending.kind.name),
        'operationSuccess': success,
        'recordCount': recordCount,
        // بلا personId / أسماء / حالات.
      };
}
