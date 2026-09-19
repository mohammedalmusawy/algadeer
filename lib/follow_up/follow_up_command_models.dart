import 'follow_up_models.dart';

enum FollowUpCommandKind {
  none,
  createCommitment,
  listCommitments,
  pauseCommitment,
  resumeCommitment,
  completeCommitment,
  cancelCommitment,
  deleteCommitment,
  stopAsking,
  consentYes,
  consentNo,
  consentLater,
  correctPendingTopic,
  rejectIneligible,
  deferToUrgentSafety,
  deferToMentalSafety,
  deferToEntityIntent,
}

enum FollowUpPendingKind {
  none,
  createConsent,
  correctTopic,
}

class FollowUpPendingOp {
  const FollowUpPendingOp({
    this.kind = FollowUpPendingKind.none,
    this.domain,
    this.topicKey,
    this.displayTopic = '',
    this.timingIntent = FollowUpTimingIntent.unspecified,
    this.subjectKind = FollowUpSubjectKind.accountOwner,
    this.persistentPersonId,
  });

  final FollowUpPendingKind kind;
  final FollowUpDomain? domain;
  final String? topicKey;
  final String displayTopic;
  final FollowUpTimingIntent timingIntent;
  final FollowUpSubjectKind subjectKind;
  final String? persistentPersonId;

  static const none = FollowUpPendingOp();

  bool get isActive => kind != FollowUpPendingKind.none;

  FollowUpSubjectRef get subjectRef {
    if (subjectKind == FollowUpSubjectKind.persistentPerson &&
        persistentPersonId != null &&
        persistentPersonId!.isNotEmpty) {
      return FollowUpSubjectRef.persistentPerson(persistentPersonId!);
    }
    return FollowUpSubjectRef.accountOwner;
  }

  Map<String, Object?> debugMap() => {
        'pendingFollowUpOp': kind.name,
        'followUpDomain': domain?.name,
        'subjectKind': subjectKind.name,
        'permissionState': kind == FollowUpPendingKind.createConsent
            ? FollowUpPermissionState.pending.name
            : FollowUpPermissionState.none.name,
      };
}

class FollowUpCommandInterpretation {
  const FollowUpCommandInterpretation({
    required this.kind,
    this.domain,
    this.topicKey,
    this.displayTopic = '',
    this.timingIntent = FollowUpTimingIntent.unspecified,
    this.message = '',
    this.correctedTopicKey,
  });

  final FollowUpCommandKind kind;
  final FollowUpDomain? domain;
  final String? topicKey;
  final String displayTopic;
  final FollowUpTimingIntent timingIntent;
  final String message;
  final String? correctedTopicKey;

  static const none = FollowUpCommandInterpretation(
    kind: FollowUpCommandKind.none,
  );

  bool get isCommand => kind != FollowUpCommandKind.none;

  Map<String, Object?> debugMap() => {
        'operationType': kind.name,
        'followUpDomain': domain?.name,
      };
}

class FollowUpCommandTurnResult {
  const FollowUpCommandTurnResult({
    required this.handled,
    required this.message,
    this.pending = FollowUpPendingOp.none,
    this.success = true,
    this.commandKind = FollowUpCommandKind.none,
    this.textFirstOnly = true,
    this.deferToUrgentSafety = false,
    this.deferToMentalSafety = false,
    this.deferToEntityIntent = false,
    this.isDue,
  });

  final bool handled;
  final String message;
  final FollowUpPendingOp pending;
  final bool success;
  final FollowUpCommandKind commandKind;
  final bool textFirstOnly;
  final bool deferToUrgentSafety;
  final bool deferToMentalSafety;
  final bool deferToEntityIntent;
  final bool? isDue;

  static FollowUpCommandTurnResult notHandled() =>
      const FollowUpCommandTurnResult(handled: false, message: '');

  Map<String, Object?> debugMap() => {
        'operationType': commandKind.name,
        'operationSuccess': success,
        'followUpDomain': pending.domain?.name,
        'permissionState': pending.isActive
            ? FollowUpPermissionState.pending.name
            : FollowUpPermissionState.none.name,
        'isDue': isDue,
        // بلا personId / أسماء حالات / محتوى.
      };
}
