import 'personal_companion_profile_repository.dart';

/// أنواع أوامر ملف Personal Companion — PC-1.3.
enum CompanionProfileCommandKind {
  none,
  showProfile,
  showSpecificField,
  updatePreferredName,
  updateBirth,
  updateSexSelection,
  updateUserContext,
  clearField,
  enableProfile,
  disableProfile,
  deleteProfileRequest,
  cancelProfileOperation,
  clarifyAmbiguous,
  rejectNonOwner,
  notPersistentMemory,
  unknownProfileCommand,
}

enum CompanionProfileFieldKind {
  preferredName,
  birth,
  age,
  sexSelection,
  userContext,
  profileEnabled,
}

/// عملية معلّقة تتطلب تأكيداً (حذف كامل).
enum CompanionProfilePendingKind {
  none,
  deleteWholeProfile,
}

class CompanionProfilePendingOp {
  const CompanionProfilePendingOp({
    this.kind = CompanionProfilePendingKind.none,
  });

  final CompanionProfilePendingKind kind;

  static const none = CompanionProfilePendingOp();

  bool get isActive => kind != CompanionProfilePendingKind.none;

  Map<String, Object?> debugMap() => {
        'pendingProfileOp': kind.name,
      };
}

/// تفسير حتمي لأمر ملف.
class CompanionProfileCommandInterpretation {
  const CompanionProfileCommandInterpretation({
    required this.kind,
    this.field,
    this.clearField,
    this.preferredName,
    this.birthYear,
    this.birthDate,
    this.sexSelectionName,
    this.userContextName,
    this.message = '',
    this.confidenceHigh = true,
  });

  final CompanionProfileCommandKind kind;
  final CompanionProfileFieldKind? field;
  final ProfileOptionalField? clearField;
  final String? preferredName;
  final int? birthYear;
  final DateTime? birthDate;
  final String? sexSelectionName;
  final String? userContextName;
  final String message;
  final bool confidenceHigh;

  static const none = CompanionProfileCommandInterpretation(
    kind: CompanionProfileCommandKind.none,
  );

  bool get isProfileCommand => kind != CompanionProfileCommandKind.none;

  Map<String, Object?> debugMap() => {
        'profileCommandType': kind.name,
        'fieldType': field?.name ?? clearField?.name,
        // بلا قيم الحقول.
      };
}

/// نتيجة تنفيذ أمر ملف.
class CompanionProfileCommandTurnResult {
  const CompanionProfileCommandTurnResult({
    required this.handled,
    required this.message,
    this.pending = CompanionProfilePendingOp.none,
    this.success = true,
    this.pauseOnboarding = false,
    this.deferToHealth = false,
    this.commandKind = CompanionProfileCommandKind.none,
    this.fieldType,
    this.textFirstOnly = true,
  });

  final bool handled;
  final String message;
  final CompanionProfilePendingOp pending;
  final bool success;
  final bool pauseOnboarding;
  final bool deferToHealth;
  final CompanionProfileCommandKind commandKind;
  final String? fieldType;
  final bool textFirstOnly;

  static CompanionProfileCommandTurnResult notHandled() =>
      const CompanionProfileCommandTurnResult(
        handled: false,
        message: '',
        textFirstOnly: true,
      );

  Map<String, Object?> debugMap() => {
        'profileCommandType': commandKind.name,
        'success': success,
        'fieldType': fieldType,
        'pendingProfileOp': pending.kind.name,
        // بلا قيم.
      };
}
