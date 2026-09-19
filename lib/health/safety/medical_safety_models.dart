import '../../voice/guided_conversation/guided_conversation_models.dart';
import '../guidance/health_guidance_models.dart';
import '../understanding/symptom_models.dart';

/// فئة استجابة السلامة — بلا تشخيص مرضي.
enum MedicalSafetyResponseCategory {
  urgentEvaluation,
  emergencyEvaluation,
}

/// حالة قرار السلامة.
///
/// [noRedFlagDetected] تعني: لم تُطابق أي قاعدة حمراء مُعدَّة صراحةً.
/// لا تعني أن الحالة «آمنة طبياً» ولا تبرّر طمأنة المستخدم.
enum MedicalSafetyStatus {
  noRedFlagDetected,
  needSafetyInformation,
  urgentEvaluation,
  emergencyEvaluation,
}

/// قاعدة سلامة طبية حتمية — ليست تشخيصاً.
class MedicalSafetyRule {
  const MedicalSafetyRule({
    required this.id,
    required this.priority,
    required this.responseCategory,
    this.enabled = true,
    this.reviewed = true,
    this.version = 1,
    this.requiredSymptoms = const [],
    this.optionalSymptoms = const [],
    this.excludedSymptoms = const [],
    this.minSeverity,
    this.severityConceptIds = const [],
    this.requireOnset,
    this.requireKnownLaterality = false,
    this.requireLateralitySide,
    this.lateralityConceptId,
    this.requirePatientIsChild,
    this.requiredBodyRegions = const [],
    this.missingFactsIfIncomplete = const [],
    this.followUpQuestionBuilders = const {},
    this.missingSymptomQuestions = const {},
    this.rationaleCode = '',
    this.allowUncertainRequired = false,
  });

  final String id;
  final bool enabled;

  /// حوكمة مستقبلية — لا واجهة تعديل عشوائية الآن.
  final bool reviewed;
  final int version;
  final int priority;
  final List<SymptomRequirement> requiredSymptoms;
  final List<String> optionalSymptoms;
  final List<SymptomRequirement> excludedSymptoms;

  /// شدة مذكورة من المستخدم (ليست محسوبة طبياً).
  final UserStatedSeverity? minSeverity;

  /// إن وُجدت: تُفحص الشدة على هذه الأعراض عبر symptomFacts.
  /// إن فارغة: تُستخدم الشدة العامة للجلسة.
  final List<String> severityConceptIds;

  final OnsetPattern? requireOnset;

  /// أي جهة معروفة (يمين/يسار) — للضعف الأحادي مثلاً.
  final bool requireKnownLaterality;

  /// جهة محددة إن لزم (مثل يمين للبطن).
  final Laterality? requireLateralitySide;

  /// ربط الجانبية بعرض محدد عند الحاجة.
  final String? lateralityConceptId;

  final bool? requirePatientIsChild;
  final List<BodyRegionId> requiredBodyRegions;
  final List<HealthMissingFact> missingFactsIfIncomplete;
  final Map<HealthMissingFact, GuidedQuestion> followUpQuestionBuilders;

  /// أسئلة عند نقص عرض مطلوب جزئياً (مثال: ضيق النفس مع ألم صدر).
  final Map<String, GuidedQuestion> missingSymptomQuestions;
  final MedicalSafetyResponseCategory responseCategory;
  final String rationaleCode;

  /// افتراضياً false: uncertain لا يُرضي شرط PRESENT الصارم.
  final bool allowUncertainRequired;
}

/// نتيجة تقييم قاعدة سلامة واحدة.
class MedicalSafetyRuleEvaluation {
  const MedicalSafetyRuleEvaluation({
    required this.ruleId,
    required this.fullyMatched,
    this.partiallyMatched = false,
    this.excludedByFacts = false,
    this.matchedSymptomIds = const [],
    this.missingFacts = const [],
    this.missingSymptomConceptIds = const [],
    this.specificity = 0,
  });

  final String ruleId;
  final bool fullyMatched;
  final bool partiallyMatched;
  final bool excludedByFacts;
  final List<String> matchedSymptomIds;
  final List<HealthMissingFact> missingFacts;
  final List<String> missingSymptomConceptIds;
  final int specificity;
}

/// قرار سلامة — بلا حقل مرض وبلا احتمالات.
class MedicalSafetyDecision {
  const MedicalSafetyDecision({
    required this.status,
    this.matchedRuleId,
    this.responseCode,
    this.userMessage = '',
    this.nextQuestion,
    this.missingFact,
    this.suppressCommercialContent = false,
    this.interruptConversation = false,
    this.responseCategory,
  });

  final MedicalSafetyStatus status;
  final String? matchedRuleId;
  final String? responseCode;
  final String userMessage;
  final GuidedQuestion? nextQuestion;
  final HealthMissingFact? missingFact;

  /// عند العاجل/الطوارئ يجب أن يكون true.
  final bool suppressCommercialContent;
  final bool interruptConversation;
  final MedicalSafetyResponseCategory? responseCategory;

  /// لا توجد مطابقة صريحة لقاعدة حمراء مُعدَّة.
  /// هذا ليس «كل شيء بخير».
  static const none = MedicalSafetyDecision(
    status: MedicalSafetyStatus.noRedFlagDetected,
  );

  bool get isEscalation =>
      status == MedicalSafetyStatus.urgentEvaluation ||
      status == MedicalSafetyStatus.emergencyEvaluation;

  bool get needsQuestion =>
      status == MedicalSafetyStatus.needSafetyInformation &&
      nextQuestion != null;
}
