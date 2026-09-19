import 'personal_memory_consent_coordinator.dart';
import 'personal_memory_models.dart';

enum PersonalMemoryCommandKind {
  none,
  rememberCandidate,
  showGoals,
  showInterests,
  showPreferences,
  showPersonalMemorySummary,
  showAboutMeBroad,
  completeGoal,
  pauseGoal,
  resumeGoal,
  correctPending,
  deleteOne,
  deleteAllOfTypeRequest,
  confirmBulkDelete,
  cancelBulkDelete,
  clarifyAmbiguous,
  rejectNonOwner,
  rejectEmotional,
  rejectSensitiveHealth,
  rejectImplicit,
  rejectPersonality,
  consentYes,
  consentNo,
}

enum PersonalMemoryPendingKind {
  none,
  rememberConfirm,
  bulkDelete,
  clarifyDelete,
  correctPending,
}

class PersonalMemoryPendingOp {
  const PersonalMemoryPendingOp({
    this.kind = PersonalMemoryPendingKind.none,
    this.consent = PersonalMemoryConsentPending.none,
    this.bulkType,
    this.candidateIds = const [],
    this.pendingCandidate,
  });

  final PersonalMemoryPendingKind kind;
  final PersonalMemoryConsentPending consent;
  final PersonalMemoryType? bulkType;
  final List<String> candidateIds;
  final PersonalMemoryCandidate? pendingCandidate;

  static const none = PersonalMemoryPendingOp();

  bool get isActive =>
      kind != PersonalMemoryPendingKind.none || consent.isActive;

  Map<String, Object?> debugMap() => {
        'pendingPersonalMemoryOp': kind.name,
        'memoryType': bulkType?.name ?? consent.candidate?.memoryType.name,
        ...consent.debugMap(),
      };
}

class PersonalMemoryCommandInterpretation {
  const PersonalMemoryCommandInterpretation({
    required this.kind,
    this.candidate,
    this.message = '',
    this.needle = '',
    this.bulkType,
  });

  final PersonalMemoryCommandKind kind;
  final PersonalMemoryCandidate? candidate;
  final String message;
  final String needle;
  final PersonalMemoryType? bulkType;

  static const none = PersonalMemoryCommandInterpretation(
    kind: PersonalMemoryCommandKind.none,
  );

  bool get isCommand => kind != PersonalMemoryCommandKind.none;

  Map<String, Object?> debugMap() => {
        'operationType': kind.name,
        'memoryType': candidate?.memoryType.name ?? bulkType?.name,
      };
}

class PersonalMemoryCommandTurnResult {
  const PersonalMemoryCommandTurnResult({
    required this.handled,
    required this.message,
    this.pending = PersonalMemoryPendingOp.none,
    this.success = true,
    this.commandKind = PersonalMemoryCommandKind.none,
    this.recordCount,
    this.textFirstOnly = true,
    this.hasRelevantMemory = false,
  });

  final bool handled;
  final String message;
  final PersonalMemoryPendingOp pending;
  final bool success;
  final PersonalMemoryCommandKind commandKind;
  final int? recordCount;
  final bool textFirstOnly;
  final bool hasRelevantMemory;

  static PersonalMemoryCommandTurnResult notHandled() =>
      const PersonalMemoryCommandTurnResult(handled: false, message: '');

  Map<String, Object?> debugMap() => {
        'operationType': commandKind.name,
        'operationSuccess': success,
        'recordCount': recordCount,
        'memoryType': pending.bulkType?.name ??
            pending.consent.candidate?.memoryType.name,
        'hasRelevantMemory': hasRelevantMemory,
        // بلا محتوى ذاكرة.
      };
}
