/// عقد NLU الإصدار 1 — فهم لغوي فقط، بلا قرار طبي.
///
/// القيم الثلاثية تطابق [RespiratoryTriState] القائم.
library;

import '../clinical_knowledge/packs/respiratory/respiratory_models.dart';

const int kNluSchemaVersion = 1;

/// حد الثقة الأدنى لقبول الدفعة كاملة.
const double kNluMinOverallConfidence = 0.6;

/// حد الثقة الأدنى لقبول خانة واحدة.
const double kNluMinSlotConfidence = 0.5;

enum NluIntent {
  clinicalContinuation,
  clinicalComplaint,
  careDirection,
  doctorSearch,
  labSearch,
  offerSearch,
  appAction,
  unknown,
}

enum NluSubject {
  self,
  child,
  other,
  inherit,
  unknown,
}

enum NluRequestedAction {
  none,
  careDirection,
  call,
  whatsapp,
  showProfile,
  unknown,
}

/// نتيجة تحليل لغوي مصدَّقة — ليست توجيهاً طبياً.
class NluParse {
  const NluParse({
    this.schemaVersion = kNluSchemaVersion,
    this.intent = NluIntent.unknown,
    this.continuation = false,
    this.subject = NluSubject.unknown,
    this.population = RespiratoryPopulation.unknown,
    this.ageYears,
    this.durationBucket = RespiratoryDurationBucket.unknown,
    this.cough = RespiratoryTriState.unknown,
    this.fever = RespiratoryTriState.unknown,
    this.breathlessness = RespiratoryTriState.unknown,
    this.sputum = RespiratoryTriState.unknown,
    this.hemoptysis = RespiratoryTriState.unknown,
    this.requestedAction = NluRequestedAction.unknown,
    this.overallConfidence = 0,
    this.slotConfidence = const {},
  });

  final int schemaVersion;
  final NluIntent intent;
  final bool continuation;
  final NluSubject subject;
  final RespiratoryPopulation population;
  final int? ageYears;
  final RespiratoryDurationBucket durationBucket;
  final RespiratoryTriState cough;
  final RespiratoryTriState fever;
  final RespiratoryTriState breathlessness;
  final RespiratoryTriState sputum;
  final RespiratoryTriState hemoptysis;
  final NluRequestedAction requestedAction;
  final double overallConfidence;
  final Map<String, double> slotConfidence;

  bool get meetsOverallConfidence =>
      overallConfidence >= kNluMinOverallConfidence;

  double confidenceFor(String slot) =>
      slotConfidence[slot] ?? overallConfidence;
}

/// لقطة جلسة مضغوطة تُرسل للمفسّر — بلا أطباء/مختبرات/ذاكرة حسّاسة.
class NluSessionSnapshot {
  const NluSessionSnapshot({
    required this.activePack,
    required this.continuationExpected,
    this.population = 'unknown',
    this.ageKnown = false,
    this.lastQuestionKey,
    this.cough = 'unknown',
    this.fever = 'unknown',
    this.breathlessness = 'unknown',
    this.sputum = 'unknown',
    this.hemoptysis = 'unknown',
    this.durationBucket = 'unknown',
  });

  final String activePack;
  final bool continuationExpected;
  final String population;
  final bool ageKnown;
  final String? lastQuestionKey;
  final String cough;
  final String fever;
  final String breathlessness;
  final String sputum;
  final String hemoptysis;
  final String durationBucket;

  Map<String, Object?> toJson() => {
        'active_pack': activePack,
        'continuation_expected': continuationExpected,
        'population': population,
        'age_known': ageKnown,
        'last_question_key': lastQuestionKey,
        'slots': {
          'cough': cough,
          'fever': fever,
          'breathlessness': breathlessness,
          'sputum': sputum,
          'hemoptysis': hemoptysis,
        },
        'duration_bucket': durationBucket,
      };
}

class NluRequest {
  const NluRequest({
    required this.userMessage,
    required this.session,
  });

  final String userMessage;
  final NluSessionSnapshot session;

  Map<String, Object?> toJson() => {
        'schema_version': kNluSchemaVersion,
        'user_message': userMessage,
        'session': session.toJson(),
      };
}

/// خانات مسموح دمجها فوق التفسير الحتمي — بلا عمر/مدة/طفل.
class NluSlotOverlay {
  const NluSlotOverlay({
    this.cough = RespiratoryTriState.unknown,
    this.fever = RespiratoryTriState.unknown,
    this.breathlessness = RespiratoryTriState.unknown,
    this.sputum = RespiratoryTriState.unknown,
    this.hemoptysis = RespiratoryTriState.unknown,
  });

  final RespiratoryTriState cough;
  final RespiratoryTriState fever;
  final RespiratoryTriState breathlessness;
  final RespiratoryTriState sputum;
  final RespiratoryTriState hemoptysis;

  bool get hasAnyKnown =>
      cough != RespiratoryTriState.unknown ||
      fever != RespiratoryTriState.unknown ||
      breathlessness != RespiratoryTriState.unknown ||
      sputum != RespiratoryTriState.unknown ||
      hemoptysis != RespiratoryTriState.unknown;
}

enum NluSkipReason {
  notConfigured,
  noActiveRespiratorySession,
  noPendingQuestion,
  appAction,
  deterministicComplete,
  deterministicAge,
  notPhase1Question,
  timeout,
  httpFailure,
  invalidJson,
  schemaRejected,
  lowConfidence,
  unsupportedFields,
  overlayEmpty,
}

class NluDebugTrace {
  const NluDebugTrace({
    required this.called,
    this.skipReason,
    this.fallbackReason,
    this.gateReason = '',
    this.deterministicFever = RespiratoryTriState.unknown,
    this.deterministicBreathlessness = RespiratoryTriState.unknown,
    this.acceptedSlots = const [],
    this.rejectedSlots = const [],
    this.mergedFever = RespiratoryTriState.unknown,
    this.mergedBreathlessness = RespiratoryTriState.unknown,
    this.finalPopulation = RespiratoryPopulation.unknown,
    this.finalHasCough = false,
    this.finalDuration = RespiratoryDurationBucket.unknown,
    this.responseCameFromPlanner = true,
  });

  final bool called;
  final NluSkipReason? skipReason;
  final NluSkipReason? fallbackReason;
  final String gateReason;
  final RespiratoryTriState deterministicFever;
  final RespiratoryTriState deterministicBreathlessness;
  final List<String> acceptedSlots;
  final List<String> rejectedSlots;
  final RespiratoryTriState mergedFever;
  final RespiratoryTriState mergedBreathlessness;
  final RespiratoryPopulation finalPopulation;
  final bool finalHasCough;
  final RespiratoryDurationBucket finalDuration;

  /// الرد النهائي يبقى من مخطِّط غدير لا من النموذج.
  final bool responseCameFromPlanner;
}
