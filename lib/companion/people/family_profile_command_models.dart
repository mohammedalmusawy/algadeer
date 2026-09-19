import 'family_person_profile.dart';
import 'person_reference_resolver.dart';

enum FamilyProfileCommandKind {
  none,
  rememberPerson,
  showAllPeople,
  showPerson,
  updateName,
  updateBirthYear,
  disablePerson,
  deletePersonRequest,
  confirmDelete,
  cancelOperation,
  clarifyAmbiguous,
  rejectHealthOnly,
  progressiveAskBirthYear,
  unknownCommand,
}

enum FamilyProfilePendingKind {
  none,
  deletePerson,
}

class FamilyProfilePendingOp {
  const FamilyProfilePendingOp({
    this.kind = FamilyProfilePendingKind.none,
    this.targetPersonId,
    this.alsoDeletesFamilyHealth = false,
  });

  final FamilyProfilePendingKind kind;
  final String? targetPersonId;

  /// PC-1.10 — الحذف المؤكد يشمل صحة العائلة التابعة.
  final bool alsoDeletesFamilyHealth;

  static const none = FamilyProfilePendingOp();

  bool get isActive => kind != FamilyProfilePendingKind.none;

  Map<String, Object?> debugMap() => {
        'pendingFamilyOp': kind.name,
        'hasTargetPerson': targetPersonId != null,
        'alsoDeletesFamilyHealth': alsoDeletesFamilyHealth,
      };
}

class FamilyProfileCommandInterpretation {
  const FamilyProfileCommandInterpretation({
    required this.kind,
    this.relationship,
    this.preferredName,
    this.birthYear,
    this.targetName,
    this.newName,
    this.message = '',
  });

  final FamilyProfileCommandKind kind;
  final PersonRelationship? relationship;
  final String? preferredName;
  final int? birthYear;
  final String? targetName;
  final String? newName;
  final String message;

  static const none = FamilyProfileCommandInterpretation(
    kind: FamilyProfileCommandKind.none,
  );

  bool get isCommand => kind != FamilyProfileCommandKind.none;
}

class FamilyProfileCommandTurnResult {
  const FamilyProfileCommandTurnResult({
    required this.handled,
    required this.message,
    this.pending = FamilyProfilePendingOp.none,
    this.success = true,
    this.textFirstOnly = true,
    this.linkedPersonId,
    this.resolutionStatus = PersonResolutionStatus.none,
    this.operationType = '',
  });

  final bool handled;
  final String message;
  final FamilyProfilePendingOp pending;
  final bool success;
  final bool textFirstOnly;
  final String? linkedPersonId;
  final PersonResolutionStatus resolutionStatus;
  final String operationType;

  static FamilyProfileCommandTurnResult notHandled() =>
      const FamilyProfileCommandTurnResult(handled: false, message: '');

  Map<String, Object?> debugMap() => {
        'resolutionStatus': resolutionStatus.name,
        'operationType': operationType,
        'personProfileCount': 0,
      };
}
