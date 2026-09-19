import 'memory_candidate.dart';
import 'memory_category.dart';
import 'memory_consent.dart';

/// جدار ناري للتحليلات — يمنع تسريب محتوى حسّاس.
///
/// أحداث تقنية مستقبلية مسموحة بالاسم فقط بدون قيمة حسّاسة:
/// memory_candidate_created, consent_prompt_shown, memory_deleted
class MemoryAnalyticsFirewall {
  const MemoryAnalyticsFirewall();

  static const allowedTechnicalEventNames = <String>{
    'memory_candidate_created',
    'consent_prompt_shown',
    'memory_deleted',
  };

  /// هل الحمولة آمنة للإرسال؟
  bool isSafeAnalyticsPayload(Map<String, Object?> payload) {
    for (final e in payload.entries) {
      final k = e.key.toLowerCase();
      if (k.contains('symptom') ||
          k.contains('condition') ||
          k.contains('medication') ||
          k.contains('allergy') ||
          k.contains('raw') ||
          k.contains('diagnosis') ||
          k.contains('name') ||
          k.contains('text') ||
          k.contains('emotion') ||
          k.contains('feeling') ||
          k.contains('distress') ||
          k.contains('suicid')) {
        return false;
      }
      final v = e.value;
      if (v is String && v.trim().length > 64) return false;
    }
    return true;
  }

  /// بناء حمولة تقنية من مرشّح — بلا قيم حسّاسة.
  Map<String, Object?> technicalEventPayload(MemoryCandidate c) {
    return {
      'event': 'memory_candidate_created',
      'category': c.category.name,
      'sensitivity': c.sensitivity.name,
      'consentState': c.consentState.name,
      'subjectType': c.subjectRef.subjectType.name,
      // لا structuredValue
    };
  }

  bool mayEmitForCandidate(MemoryCandidate c) {
    if (c.sensitivity == MemorySensitivity.sensitiveHealth) {
      // مسموح حدث تقني بلا قيمة الحالة.
      return isSafeAnalyticsPayload(technicalEventPayload(c));
    }
    return isSafeAnalyticsPayload(technicalEventPayload(c));
  }

  /// PC-0.4 لا يُصدر أحداثاً — العقد جاهز فقط.
  bool get emitsEventsInPc04 => false;
}

/// حقول ملف مستقبلي — توثيق حدودي بلا تخزين.
class FutureProfileFieldCatalog {
  const FutureProfileFieldCatalog();

  static const conceptualFields = <String>{
    'preferredName',
    'profilePhoto',
    'birthDate',
    'birthYear',
    'sexSelection',
    'userContext',
    'interests',
    'goals',
    'conversationPreferences',
  };

  /// لا استدلال جنس من اسم/صوت/صورة.
  bool mayInferSexFromName() => false;
  bool mayInferSexFromTtsVoice() => false;
  bool mayInferSexFromPhoto() => false;
  bool mayInferBirthFromAppearance() => false;

  /// عمر الجلسة ≠ تاريخ ميلاد دائم.
  bool sessionAgeEqualsPersistentDob() => false;
}
