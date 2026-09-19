/// PC-0.3 — سياق الشخص الخاضع للنقاش الصحي (جلسة فقط).
///
/// Invariants:
/// - SYMPTOM ≠ DIAGNOSIS
/// - SUBJECT HEALTH FACT ≠ ACCOUNT OWNER HEALTH FACT
/// - SESSION SUBJECT ≠ PERSISTENT PERSON PROFILE
///
/// Future Personal Companion may attach a PersistentPersonProfile to a
/// subject identity without making ConversationContext itself persistent.
/// Sex/gender, chronic conditions, and family profiles are NOT implemented here.

/// من نتحدث عنه صحياً في هذه الجلسة.
enum HealthSubjectType {
  self,
  child,
  mother,
  father,
  spouse,
  familyMember,
  otherPerson,
  unknown,
}

/// دليل حتمي — بلا درجات احتمالية تشخيصية.
enum HealthSubjectEvidence {
  explicitSelf,
  explicitRelationship,
  contextualContinuation,
  ambiguous,
  unknown,
}

/// الشخص الخاضع للنقاش الصحي — RAM فقط، بلا اسم خام في الـ debug.
class HealthSubjectContext {
  const HealthSubjectContext({
    required this.sessionKey,
    required this.type,
    required this.evidence,
    this.isChild,
    this.ageGroup,
    this.ageYears,
    // Future: optional sex/gender attaches HERE (to the subject), never as a
    // global ConversationContext field. Always null in PC-0.3.
    this.reservedSexHint,
    /// PC-1.8 — ربط اختياري بشخص دائم (personId) — جلسة فقط.
    this.linkedPersonId,
  });

  /// مفتاح جلسة مؤقت (ليس معرف شخص دائم).
  final String sessionKey;
  final HealthSubjectType type;
  final HealthSubjectEvidence evidence;

  /// مشتق من النوع أو تلميح عمر صريح في الجلسة.
  final bool? isChild;
  final String? ageGroup;

  /// عمر اختياري جلسة فقط — لا ملف دائم.
  final int? ageYears;

  /// محجوز للمستقبل — لا يُملأ في PC-0.3.
  final String? reservedSexHint;

  /// معرف شخص دائم عند الربط الصريح — لا يُعرض في debug عام.
  final String? linkedPersonId;

  static const unknown = HealthSubjectContext(
    sessionKey: 'subj_unknown',
    type: HealthSubjectType.unknown,
    evidence: HealthSubjectEvidence.unknown,
  );

  bool get isKnown => type != HealthSubjectType.unknown;

  bool get isExplicit =>
      evidence == HealthSubjectEvidence.explicitSelf ||
      evidence == HealthSubjectEvidence.explicitRelationship;

  bool get allowsPronounContinuation =>
      isKnown && type != HealthSubjectType.unknown;

  HealthSubjectContext copyWith({
    String? sessionKey,
    HealthSubjectType? type,
    HealthSubjectEvidence? evidence,
    bool? isChild,
    String? ageGroup,
    int? ageYears,
    String? reservedSexHint,
    String? linkedPersonId,
    bool clearAgeYears = false,
    bool clearIsChild = false,
    bool clearLinkedPersonId = false,
  }) {
    return HealthSubjectContext(
      sessionKey: sessionKey ?? this.sessionKey,
      type: type ?? this.type,
      evidence: evidence ?? this.evidence,
      isChild: clearIsChild ? null : (isChild ?? this.isChild),
      ageGroup: ageGroup ?? this.ageGroup,
      ageYears: clearAgeYears ? null : (ageYears ?? this.ageYears),
      reservedSexHint: reservedSexHint ?? this.reservedSexHint,
      linkedPersonId:
          clearLinkedPersonId ? null : (linkedPersonId ?? this.linkedPersonId),
    );
  }

  /// ميتاداتا آمنة فقط — بلا أعراض وبلا أسماء.
  Map<String, Object?> debugMap() => {
        'subjectType': type.name,
        'subjectEvidence': evidence.name,
        'subjectSessionKey': sessionKey,
        'subjectIsChild': isChild,
        'subjectAgeGroup': ageGroup,
        'subjectHasAgeYears': ageYears != null,
        'subjectHasLinkedPerson': linkedPersonId != null,
        // reservedSexHint intentionally omitted from debug when null / unused
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthSubjectContext &&
          sessionKey == other.sessionKey &&
          type == other.type &&
          evidence == other.evidence &&
          isChild == other.isChild &&
          ageGroup == other.ageGroup &&
          ageYears == other.ageYears &&
          linkedPersonId == other.linkedPersonId;

  @override
  int get hashCode => Object.hash(
        sessionKey,
        type,
        evidence,
        isChild,
        ageGroup,
        ageYears,
        linkedPersonId,
      );
}

/// نتيجة كشف الموضوع من نص واحد.
class HealthSubjectDetection {
  const HealthSubjectDetection({
    required this.type,
    required this.evidence,
    this.returnToPrevious = false,
    this.returnTarget,
    this.ageYears,
    this.isChildHint,
  });

  final HealthSubjectType type;
  final HealthSubjectEvidence evidence;
  final bool returnToPrevious;
  final HealthSubjectType? returnTarget;
  final int? ageYears;
  final bool? isChildHint;

  static const none = HealthSubjectDetection(
    type: HealthSubjectType.unknown,
    evidence: HealthSubjectEvidence.unknown,
  );

  bool get isExplicitSwitchSignal =>
      evidence == HealthSubjectEvidence.explicitSelf ||
      evidence == HealthSubjectEvidence.explicitRelationship ||
      returnToPrevious;
}

/// قرار المنسّق حول استمرار/تبديل الموضوع.
class HealthSubjectResolution {
  const HealthSubjectResolution({
    required this.subject,
    required this.switched,
    this.returnRequested = false,
    this.ambiguous = false,
    this.previousType,
  });

  final HealthSubjectContext subject;
  final bool switched;
  final bool returnRequested;
  final bool ambiguous;
  final HealthSubjectType? previousType;
}
