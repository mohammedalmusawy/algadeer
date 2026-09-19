import '../../voice/guided_conversation/guided_conversation_models.dart';

/// قطبية العرض للأعراض — حتمية وليست احتمالية AI.
enum SymptomPolarity {
  present,
  absent,
  uncertain,
}

/// مستوى ثقة المطابقة — حتمي بدون نسب مئوية.
enum SymptomMatchConfidence {
  exactAlias,
  normalizedAlias,
  phrasePattern,
  ambiguous,
}

enum BodyRegionId {
  head,
  face,
  eye,
  ear,
  nose,
  throat,
  neck,
  chest,
  abdomen,
  back,
  lowerBack,
  shoulder,
  arm,
  hand,
  hip,
  leg,
  knee,
  foot,
  unknown,
}

enum Laterality {
  right,
  left,
  bilateral,
  unknown,
}

enum UserStatedSeverity {
  mild,
  moderate,
  severe,
  unknown,
}

enum OnsetPattern {
  sudden,
  gradual,
  unknown,
}

/// مفهوم عرض مستقر قابل للتوسّع من كتالوج لاحق (Supabase/Admin).
class SymptomConcept {
  const SymptomConcept({
    required this.id,
    required this.canonicalArabicName,
    this.aliases = const [],
    this.bodyRegions = const [],
    this.metadata = const {},
    this.enabled = true,
  });

  final String id;
  final String canonicalArabicName;
  final List<String> aliases;
  final List<BodyRegionId> bodyRegions;
  final Map<String, Object?> metadata;
  final bool enabled;
}

/// مرادف عرض مع نوع اللهجة اختياري للمستقبل.
class SymptomAliasEntry {
  const SymptomAliasEntry({
    required this.symptomId,
    required this.alias,
    this.dialect = 'iraqi_ar',
    this.enabled = true,
  });

  final String symptomId;
  final String alias;
  final String dialect;
  final bool enabled;
}

/// منطقة جسم في الكتالوج.
class BodyRegionConcept {
  const BodyRegionConcept({
    required this.id,
    required this.canonicalArabicName,
    this.aliases = const [],
    this.enabled = true,
  });

  final BodyRegionId id;
  final String canonicalArabicName;
  final List<String> aliases;
  final bool enabled;
}

/// عرض مكتشف في النص — بدون تشخيص.
class DetectedSymptom {
  const DetectedSymptom({
    required this.conceptId,
    required this.status,
    required this.matchedText,
    required this.confidence,
    this.bodyRegion,
    this.laterality = Laterality.unknown,
    this.userSeverity = UserStatedSeverity.unknown,
    this.duration,
    this.onset = OnsetPattern.unknown,
    this.temporalModifiers = const [],
    this.spanStart = 0,
    this.spanEnd = 0,
  });

  final String conceptId;
  final SymptomPolarity status;
  final String matchedText;
  final SymptomMatchConfidence confidence;
  final BodyRegionId? bodyRegion;
  final Laterality laterality;
  final UserStatedSeverity userSeverity;
  final DurationValue? duration;
  final OnsetPattern onset;
  final List<String> temporalModifiers;
  final int spanStart;
  final int spanEnd;

  DetectedSymptom copyWith({
    SymptomPolarity? status,
    BodyRegionId? bodyRegion,
    Laterality? laterality,
    UserStatedSeverity? userSeverity,
    DurationValue? duration,
    OnsetPattern? onset,
    List<String>? temporalModifiers,
  }) {
    return DetectedSymptom(
      conceptId: conceptId,
      status: status ?? this.status,
      matchedText: matchedText,
      confidence: confidence,
      bodyRegion: bodyRegion ?? this.bodyRegion,
      laterality: laterality ?? this.laterality,
      userSeverity: userSeverity ?? this.userSeverity,
      duration: duration ?? this.duration,
      onset: onset ?? this.onset,
      temporalModifiers: temporalModifiers ?? this.temporalModifiers,
      spanStart: spanStart,
      spanEnd: spanEnd,
    );
  }
}

/// نتيجة فهم صحي هيكلية — فهم فقط، بلا توصية أو تشخيص.
class HealthUnderstandingResult {
  const HealthUnderstandingResult({
    required this.originalText,
    required this.normalizedText,
    this.symptoms = const [],
    this.bodyRegions = const [],
    this.duration,
    this.laterality = Laterality.unknown,
    this.userSeverity = UserStatedSeverity.unknown,
    this.onset = OnsetPattern.unknown,
    this.temporalModifiers = const [],
    this.userStatedConditions = const [],
    this.containsHealthLanguage = false,
    this.unmatchedHealthPhrases = const [],
  });

  final String originalText;
  final String normalizedText;
  final List<DetectedSymptom> symptoms;
  final List<BodyRegionId> bodyRegions;
  final DurationValue? duration;
  final Laterality laterality;
  final UserStatedSeverity userSeverity;
  final OnsetPattern onset;
  final List<String> temporalModifiers;

  /// ذكر حالة من المستخدم كنص — ليس تأكيداً تشخيصياً.
  final List<String> userStatedConditions;
  final bool containsHealthLanguage;
  final List<String> unmatchedHealthPhrases;

  bool get hasPresentSymptoms =>
      symptoms.any((s) => s.status == SymptomPolarity.present);

  DetectedSymptom? symptomById(String id) {
    for (final s in symptoms) {
      if (s.conceptId == id) return s;
    }
    return null;
  }

  static HealthUnderstandingResult empty(String original) =>
      HealthUnderstandingResult(
        originalText: original,
        normalizedText: original,
      );
}
