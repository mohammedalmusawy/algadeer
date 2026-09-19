import '../../voice/guided_conversation/guided_conversation_models.dart';
import 'health_guidance_models.dart';

/// مفتاح حقيقة صحية للأسئلة — بلا تشخيص.
enum HealthFactKey {
  laterality,
  severity,
  duration,
  onset,
  pattern,
  symptomPresence,
  bodyRegion,
  abdominalLocation,
  patientIsChild,
}

enum HealthQuestionPurpose {
  location,
  duration,
  severity,
  onset,
  symptomPresence,
  patientContext,
  pattern,
  providerDiscoveryConfirmation,
}

/// نتيجة تخطيط سؤال واحد أو لا سؤال.
class FollowUpQuestionPlan {
  const FollowUpQuestionPlan({
    this.question,
    this.missingFact,
    this.factKey,
    this.symptomConceptId,
    this.purpose,
    this.noQuestionNeeded = false,
    this.budgetExhausted = false,
  });

  final GuidedQuestion? question;
  final HealthMissingFact? missingFact;
  final HealthFactKey? factKey;
  final String? symptomConceptId;
  final HealthQuestionPurpose? purpose;
  final bool noQuestionNeeded;
  final bool budgetExhausted;

  static const none = FollowUpQuestionPlan(noQuestionNeeded: true);
}

/// نتيجة تفسير جواب سياقي.
class HealthFollowUpInterpretation {
  const HealthFollowUpInterpretation({
    required this.kind,
    this.updatedFacts,
    this.explanation,
    this.keepPendingQuestion = false,
    this.skipCurrentQuestion = false,
    this.cancelFlow = false,
    this.refuseAnswerOnly = false,
  });

  final HealthFollowUpInterpretKind kind;
  final HealthSessionFacts? updatedFacts;
  final String? explanation;
  final bool keepPendingQuestion;
  final bool skipCurrentQuestion;
  final bool cancelFlow;
  final bool refuseAnswerOnly;
}

enum HealthFollowUpInterpretKind {
  factUpdated,
  uncertain,
  unknownSkip,
  refuseQuestion,
  whyAsk,
  rephrase,
  cancelFlow,
  unresolved,
}

/// نتيجة دورة محادثة صحية موحّدة للواجهة لاحقاً.
class HealthConversationTurnResult {
  const HealthConversationTurnResult({
    required this.status,
    this.question,
    this.guidanceDecision,
    this.explanation,
    this.awaitingAnswer = false,
  });

  final HealthGuidanceSessionStatus status;
  final GuidedQuestion? question;
  final HealthGuidanceDecision? guidanceDecision;
  final String? explanation;
  final bool awaitingAnswer;
}

/// ميتاداتا سؤال صحي على GuidedQuestion.metadata.
class HealthQuestionMeta {
  const HealthQuestionMeta({
    required this.factKey,
    required this.purpose,
    this.missingFact,
    this.symptomConceptId,
    this.clarificationPrompt,
    this.whyExplanation,
  });

  final HealthFactKey factKey;
  final HealthQuestionPurpose purpose;
  final HealthMissingFact? missingFact;
  final String? symptomConceptId;
  final String? clarificationPrompt;
  final String? whyExplanation;

  Map<String, Object?> toMap() => {
        'healthFactKey': factKey.name,
        'purpose': purpose.name,
        if (missingFact != null) 'missingFact': missingFact!.name,
        if (symptomConceptId != null) 'symptomConceptId': symptomConceptId,
        if (clarificationPrompt != null)
          'clarificationPrompt': clarificationPrompt,
        if (whyExplanation != null) 'whyExplanation': whyExplanation,
      };

  static HealthQuestionMeta? fromQuestion(GuidedQuestion q) {
    final m = q.metadata;
    if (m.isEmpty) return null;
    final keyName = m['healthFactKey']?.toString();
    if (keyName == null) return null;
    final factKey = HealthFactKey.values.firstWhere(
      (e) => e.name == keyName,
      orElse: () => HealthFactKey.duration,
    );
    final purposeName = m['purpose']?.toString();
    final purpose = HealthQuestionPurpose.values.firstWhere(
      (e) => e.name == purposeName,
      orElse: () => HealthQuestionPurpose.duration,
    );
    HealthMissingFact? missing;
    final mf = m['missingFact']?.toString();
    if (mf != null) {
      for (final e in HealthMissingFact.values) {
        if (e.name == mf) {
          missing = e;
          break;
        }
      }
    }
    return HealthQuestionMeta(
      factKey: factKey,
      purpose: purpose,
      missingFact: missing,
      symptomConceptId: m['symptomConceptId']?.toString(),
      clarificationPrompt: m['clarificationPrompt']?.toString(),
      whyExplanation: m['whyExplanation']?.toString(),
    );
  }
}
