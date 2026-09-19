import '../../../health/subject/health_subject_models.dart';
import '../family_person_profile.dart';

/// من نتحدث عنه في هذه الدورة — PC-1.9.
enum ConversationSubjectKind {
  accountOwner,
  persistentPerson,
  temporaryOtherPerson,
  ambiguousPerson,
  unknownPerson,
}

/// حالة حلّ الشخص — منفصلة عن PersonReferenceResolver.status.
enum ConversationPersonResolutionStatus {
  resolved,
  ambiguous,
  unknown,
  failed,
}

/// عقد downstream للطبقات الصحية المستقبلية — PC-1.9.
class ResolvedConversationSubject {
  const ResolvedConversationSubject({
    required this.subjectKind,
    required this.status,
    required this.healthSubjectType,
    this.persistentPersonId,
    this.relationship,
    this.isAccountOwner = false,
  });

  final ConversationSubjectKind subjectKind;
  final ConversationPersonResolutionStatus status;
  final HealthSubjectType healthSubjectType;
  final String? persistentPersonId;
  final PersonRelationship? relationship;
  final bool isAccountOwner;

  static const unknown = ResolvedConversationSubject(
    subjectKind: ConversationSubjectKind.unknownPerson,
    status: ConversationPersonResolutionStatus.unknown,
    healthSubjectType: HealthSubjectType.unknown,
  );

  /// صاحب الحساب بعد علامة ذات صريحة — تعريف واحد يستعمله حلّ الشخص وأي
  /// طبقة تحسم المالك قبله، حتى لا تتفرّع دلالتان لنفس الحالة.
  static const accountOwner = ResolvedConversationSubject(
    subjectKind: ConversationSubjectKind.accountOwner,
    status: ConversationPersonResolutionStatus.resolved,
    healthSubjectType: HealthSubjectType.self,
    isAccountOwner: true,
  );

  bool get hasPersistentBinding =>
      subjectKind == ConversationSubjectKind.persistentPerson &&
      persistentPersonId != null &&
      persistentPersonId!.isNotEmpty;

  Map<String, Object?> debugMap() => {
        'personResolutionStatus': status.name,
        'subjectKind': subjectKind.name,
        'relationshipType': relationship?.name,
        'hasPersistentPersonBinding': hasPersistentBinding,
        'isAccountOwner': isAccountOwner,
      };
}

/// توضيح شخص معلّق — جلسة RAM فقط.
class PendingPersonClarification {
  const PendingPersonClarification({
    this.candidatePersonIds = const [],
    this.originalQuery = '',
    this.intentKind = 'health',
    this.createdTurnId = 0,
  });

  final List<String> candidatePersonIds;
  final String originalQuery;
  final String intentKind;
  final int createdTurnId;

  static const inactive = PendingPersonClarification();

  bool get isActive =>
      candidatePersonIds.isNotEmpty && originalQuery.trim().isNotEmpty;

  int get candidateCount => candidatePersonIds.length;

  Map<String, Object?> debugMap() => {
        'pendingPersonClarification': isActive,
        'candidateCount': candidateCount,
        'intentKind': intentKind,
      };
}

class ConversationPersonResolution {
  const ConversationPersonResolution({
    required this.resolved,
    this.linkedPersonId,
    this.healthSubject,
    this.needsClarification = false,
    this.clarificationMessage = '',
    this.clarificationCandidates = const [],
    this.deferredToEntityPipeline = false,
    this.continuationQuery,
  });

  final ResolvedConversationSubject resolved;
  final String? linkedPersonId;
  final HealthSubjectContext? healthSubject;
  final bool needsClarification;
  final String clarificationMessage;
  final List<String> clarificationCandidates;
  final bool deferredToEntityPipeline;
  final String? continuationQuery;

  static const deferred = ConversationPersonResolution(
    resolved: ResolvedConversationSubject.unknown,
    deferredToEntityPipeline: true,
  );
}

class SubjectBindingDecision {
  const SubjectBindingDecision({
    required this.resolution,
    this.pending = PendingPersonClarification.inactive,
    this.subjectChanged = false,
    this.applyBinding = true,
  });

  final ConversationPersonResolution resolution;
  final PendingPersonClarification pending;
  final bool subjectChanged;
  final bool applyBinding;

  bool get needsClarification => resolution.needsClarification;
  String get message => resolution.clarificationMessage;
  String? get linkedPersonId => resolution.linkedPersonId;
  ResolvedConversationSubject get subject => resolution.resolved;
}

class SubjectBindingTurnResult {
  const SubjectBindingTurnResult({
    this.handled = false,
    this.needsClarification = false,
    this.message = '',
    this.pending = PendingPersonClarification.inactive,
    this.linkedPersonId,
    this.resolved = ResolvedConversationSubject.unknown,
    this.deferredToEntityPipeline = false,
    this.continuationQuery,
    this.subjectChanged = false,
    this.enrichedHealthSubject,
  });

  final bool handled;
  final bool needsClarification;
  final String message;
  final PendingPersonClarification pending;
  final String? linkedPersonId;
  final ResolvedConversationSubject resolved;
  final bool deferredToEntityPipeline;
  final String? continuationQuery;
  final bool subjectChanged;
  final HealthSubjectContext? enrichedHealthSubject;

  static SubjectBindingTurnResult defer() => const SubjectBindingTurnResult(
        deferredToEntityPipeline: true,
      );

  static SubjectBindingTurnResult clarify({
    required String message,
    required PendingPersonClarification pending,
  }) =>
      SubjectBindingTurnResult(
        handled: true,
        needsClarification: true,
        message: message,
        pending: pending,
        resolved: const ResolvedConversationSubject(
          subjectKind: ConversationSubjectKind.ambiguousPerson,
          status: ConversationPersonResolutionStatus.ambiguous,
          healthSubjectType: HealthSubjectType.child,
        ),
      );
}
