import '../health/subject/health_subject_models.dart';
import '../search/arabic_text_utils.dart';
import 'memory_candidate.dart';
import 'memory_category.dart';
import 'memory_consent.dart';
import 'memory_owner.dart';
import 'memory_session_policy.dart';

/// نتيجة تصنيف — مرشّحات RAM فقط، بلا إصرار.
class MemoryClassificationResult {
  const MemoryClassificationResult({
    this.candidates = const [],
    this.blockedReason,
    this.followUpDraft,
  });

  final List<MemoryCandidate> candidates;
  final String? blockedReason;
  final FollowUpCommitmentDraft? followUpDraft;

  static const empty = MemoryClassificationResult();
}

/// يصنّف النص إلى مرشّحات ذاكرة وفق سياسة PC-0.4 — بلا تخزين.
///
/// قواعد حرجة:
/// - محادثة أعراض لا تصبح ملفّاً صحياً دائماً تلقائياً.
/// - «يمكن عندي سكري» / «أحس ضغطي مرتفع» لا تُنتج diagnosedCondition.
/// - عبارة تشخيص صريحة منسوبة لطبيب قد تُنتج مرشّحاً يتطلب موافقة.
class MemoryCandidateClassifier {
  const MemoryCandidateClassifier();

  MemoryClassificationResult classify({
    required String text,
    required HealthSubjectContext subject,
    int turnId = 0,
  }) {
    final n = ArabicTextUtils.normalize(text);
    if (n.isEmpty) return MemoryClassificationResult.empty;

    // شكوى أعراض عامة → لا متابعة تلقائية ولا تشخيص دائم.
    if (_isSymptomComplaintOnly(n) && !_hasExplicitDiagnosisAttribution(n)) {
      return MemoryClassificationResult(
        blockedReason: 'symptom_conversation_not_auto_memory',
        followUpDraft: FollowUpCommitmentDraft(
          subjectRef: _ownerFor(subject),
          topicKey: 'symptom_follow_up',
          requiresConsent: true,
          status: FollowUpDraftStatus.notScheduled,
        ),
      );
    }

    // تخمين / إحساس بمرض → ممنوع كـ diagnosedCondition.
    if (_isSpeculativeOrFeelingCondition(n)) {
      return const MemoryClassificationResult(
        blockedReason: 'speculative_or_feeling_not_diagnosed_condition',
      );
    }

    if (_hasExplicitDiagnosisAttribution(n) ||
        _hasExplicitDiagnosedStatement(n)) {
      final keys = _extractConditionKeys(n);
      if (keys.isEmpty) {
        return const MemoryClassificationResult(
          blockedReason: 'explicit_diagnosis_without_safe_mapping',
        );
      }
      final owner = _ownerFor(subject);
      final candidates = [
        for (final key in keys)
          MemoryCandidate(
            id: 'mc_${turnId}_$key',
            category: MemoryCategory.sensitiveHealthProfile,
            subjectRef: owner,
            structuredKey: HealthMemoryStructuredKey.diagnosedCondition.name,
            structuredValue: key,
            sensitivity: MemorySensitivity.sensitiveHealth,
            sourceType: _hasExplicitDiagnosisAttribution(n)
                ? MemorySourceType.clinicianAttributedStatement
                : MemorySourceType.userExplicitStatement,
            requiresExplicitConsent: true,
            consentState: MemoryConsentState.required,
            evidenceCode: _hasExplicitDiagnosisAttribution(n)
                ? 'explicit_clinician_attributed'
                : 'explicit_user_diagnosed_statement',
            createdTurnId: turnId,
          ),
      ];
      return MemoryClassificationResult(candidates: candidates);
    }

    return MemoryClassificationResult.empty;
  }

  /// هل يجوز الإصرار الآن؟ دائماً false في PC-0.4.
  bool mayPersistCandidates(List<MemoryCandidate> candidates) {
    if (!const MemorySessionOnlyPolicy().mayAutoPersistSymptomConversation()) {
      // حتى المرشّحات بموافقة required لا تُحفظ هنا.
    }
    for (final c in candidates) {
      if (c.mayPersistNow) return true;
    }
    return false;
  }

  MemorySubjectRef _ownerFor(HealthSubjectContext subject) {
    if (subject.type == HealthSubjectType.self) {
      return MemorySubjectRef.accountSelf();
    }
    if (subject.type == HealthSubjectType.unknown) {
      return MemorySubjectRef.temporary(
        HealthSubjectType.unknown,
        key: subject.sessionKey,
      );
    }
    // طفل/أم/… → temporarySubject — ليس صاحب الحساب.
    return MemorySubjectRef.temporary(
      subject.type,
      key: subject.sessionKey,
    );
  }

  bool _isSpeculativeOrFeelingCondition(String n) {
    // يمكن عندي سكري / احس ضغطي مرتفع / يمكن ضغط
    if (RegExp(r'(?:يمكن|احتمال|يمكن يكون|يمكنني)\s*.{0,20}(?:سكري|ضغط|ربو)')
        .hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'(?:احس|أحس|يصير|احس ان|احس إن).{0,24}(?:ضغط|سكري|سكر)',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(r'ضغطي\s*(?:مرتفع|عالي|طالع)').hasMatch(n) &&
        !RegExp(r'مشخص').hasMatch(n)) {
      return true;
    }
    return false;
  }

  bool _isSymptomComplaintOnly(String n) {
    if (_hasExplicitDiagnosisAttribution(n) ||
        _hasExplicitDiagnosedStatement(n)) {
      return false;
    }
    return RegExp(
      r'(?:صداع|حرار|دوخ|سعال|الم|ألم|وجع|صدري|بطن|غثيان|تعب)',
    ).hasMatch(n);
  }

  bool _hasExplicitDiagnosisAttribution(String n) {
    return RegExp(
      r'(?:الدكتور|الطبيب|الدكتوره|الطبيبة).{0,32}مشخص|'
      r'مشخص(?:ني|ه|ها|ة)?\s*(?:ب)?(?:سكري|ضغط|ربو)|'
      r'مشخص\s*(?:ب)?(?:سكري|ضغط|ربو)',
    ).hasMatch(n);
  }

  bool _hasExplicitDiagnosedStatement(String n) {
    // عندي ضغط وسكري ومشخص بيهن / مشخصني سكري / مشخصة ضغط
    if (RegExp(r'مشخص').hasMatch(n) &&
        RegExp(r'(?:سكري|ضغط|ربو)').hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'عندي\s+(?:سكري|ضغط|ربو)(?:\s+و\s*(?:سكري|ضغط|ربو))*\s+ومشخص',
    ).hasMatch(n)) {
      return true;
    }
    return false;
  }

  List<String> _extractConditionKeys(String n) {
    final out = <String>[];
    if (RegExp(r'سكري|السكر\b').hasMatch(n)) out.add('diabetes');
    if (RegExp(r'ضغط').hasMatch(n)) out.add('hypertension');
    if (RegExp(r'ربو').hasMatch(n)) out.add('asthma');
    return out;
  }
}
