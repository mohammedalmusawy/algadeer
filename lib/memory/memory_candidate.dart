import 'memory_category.dart';
import 'memory_consent.dart';
import 'memory_owner.dart';

/// مرشّح ذاكرة — RAM فقط في PC-0.4.
///
/// لا يُكتب إلى تخزين محلي دائم أو جداول بعيدة.
/// يفضّل قيماً مهيكلة على نص حر خام.
class MemoryCandidate {
  const MemoryCandidate({
    required this.category,
    required this.subjectRef,
    required this.structuredKey,
    required this.structuredValue,
    required this.sensitivity,
    required this.sourceType,
    required this.requiresExplicitConsent,
    required this.consentState,
    required this.evidenceCode,
    required this.createdTurnId,
    this.id,
  });

  final String? id;
  final MemoryCategory category;
  final MemorySubjectRef subjectRef;
  final String structuredKey;
  final String structuredValue;
  final MemorySensitivity sensitivity;
  final MemorySourceType sourceType;
  final bool requiresExplicitConsent;
  final MemoryConsentState consentState;

  /// رمز دليل حتمي (مثل explicit_clinician_attributed) — ليس درجة تشخيص.
  final String evidenceCode;
  final int createdTurnId;

  bool get isRamOnly => true;

  bool get mayPersistNow =>
      const MemoryConsentPolicy().mayPersist(consentState) &&
      // PC-0.4: لا تخزين أبداً حتى مع granted — الطبقة غير مفعّلة.
      false;

  MemoryCandidate copyWith({
    MemoryConsentState? consentState,
    bool? requiresExplicitConsent,
  }) {
    return MemoryCandidate(
      id: id,
      category: category,
      subjectRef: subjectRef,
      structuredKey: structuredKey,
      structuredValue: structuredValue,
      sensitivity: sensitivity,
      sourceType: sourceType,
      requiresExplicitConsent:
          requiresExplicitConsent ?? this.requiresExplicitConsent,
      consentState: consentState ?? this.consentState,
      evidenceCode: evidenceCode,
      createdTurnId: createdTurnId,
    );
  }

  /// ميتاداتا آمنة — بلا نص حالة/دواء/أعراض خام.
  Map<String, Object?> debugMap() => {
        'candidateCategory': category.name,
        'sensitivity': sensitivity.name,
        'consentState': consentState.name,
        'requiresExplicitConsent': requiresExplicitConsent,
        'sourceType': sourceType.name,
        'structuredKey': structuredKey,
        // structuredValue عُمِد إخفاؤه من debug عند sensitiveHealth
        'hasStructuredValue': structuredValue.isNotEmpty,
        'evidenceCode': evidenceCode,
        'createdTurnId': createdTurnId,
        ...subjectRef.debugMap(),
      };
}

/// التزام متابعة مستقبلي — منفصل عن حقيقة الذاكرة.
class FollowUpCommitmentDraft {
  const FollowUpCommitmentDraft({
    required this.subjectRef,
    required this.topicKey,
    required this.requiresConsent,
    this.status = FollowUpDraftStatus.notScheduled,
  });

  final MemorySubjectRef subjectRef;
  final String topicKey;
  final bool requiresConsent;
  final FollowUpDraftStatus status;

  bool get isScheduled => status == FollowUpDraftStatus.scheduled;
}

enum FollowUpDraftStatus {
  notScheduled,
  awaitingConsent,
  scheduled,
  cancelled,
}

/// عمليات مستودع مستقبلية — مفاهيمية فقط.
enum PersonalMemoryOperation {
  list,
  add,
  update,
  delete,
  disableUse,
}
