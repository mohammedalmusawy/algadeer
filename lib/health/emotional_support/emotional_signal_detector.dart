import '../../health/subject/health_subject_detector.dart';
import '../../health/subject/health_subject_models.dart';
import '../../search/arabic_text_utils.dart';
import 'emotional_support_models.dart';

/// كاشف إشارات عاطفية — حتمي ومحافظ.
class EmotionalSignalDetector {
  EmotionalSignalDetector({
    HealthSubjectDetector? subjects,
  }) : _subjects = subjects ?? const HealthSubjectDetector();

  final HealthSubjectDetector _subjects;

  EmotionalSignal detect(String raw, {bool hasTaskIntent = false}) {
    final original = raw.trim();
    final n = ArabicTextUtils.normalize(original);
    if (n.isEmpty) return EmotionalSignal.neutral;

    final subj = _subjects.detect(original);
    final aboutOther = subj.type != HealthSubjectType.self &&
        subj.type != HealthSubjectType.unknown &&
        subj.evidence == HealthSubjectEvidence.explicitRelationship;

    EmotionalSignalCategory? cat;
    var intensity = EmotionalIntensity.unknown;

    if (_isExamStress(n)) {
      cat = EmotionalSignalCategory.examStress;
    } else if (_isResultAnxiety(n)) {
      cat = EmotionalSignalCategory.resultAnxiety;
    } else if (_isProcedureFear(n)) {
      cat = EmotionalSignalCategory.procedureFear;
    } else if (_isHealthAnxiety(n)) {
      cat = EmotionalSignalCategory.healthAnxiety;
    } else if (_isOverwhelmed(n)) {
      cat = EmotionalSignalCategory.overwhelmed;
    } else if (_isLoneliness(n)) {
      cat = EmotionalSignalCategory.loneliness;
    } else if (_isFrustration(n)) {
      cat = EmotionalSignalCategory.frustration;
    } else if (_isSadness(n)) {
      cat = EmotionalSignalCategory.sadness;
    } else if (_isStress(n)) {
      cat = EmotionalSignalCategory.stress;
    } else if (_isWorry(n)) {
      cat = EmotionalSignalCategory.worry;
    } else if (_isFear(n)) {
      cat = EmotionalSignalCategory.fear;
    } else if (_isUnknownDistress(n)) {
      cat = EmotionalSignalCategory.unknownDistress;
    }

    if (cat == null) return EmotionalSignal.neutral;

    if (RegExp(r'(?:جدا|مرة|هواي|كثير|ما\s*اتحمل)').hasMatch(n)) {
      intensity = EmotionalIntensity.strong;
    } else if (RegExp(r'(?:شوي|قليل)').hasMatch(n)) {
      intensity = EmotionalIntensity.mild;
    } else {
      intensity = EmotionalIntensity.moderate;
    }

    return EmotionalSignal(
      category: cat,
      intensity: intensity,
      aboutOtherPerson: aboutOther,
      hasTaskIntent: hasTaskIntent,
    );
  }

  bool _isExamStress(String n) => RegExp(
        r'(?:امتحان|الامتحانات|دراس|اختبار).{0,24}(?:خايف|قلق|متوتر|ضاغط)|'
        r'(?:خايف|قلق|متوتر|ضاغط).{0,24}(?:امتحان|دراس)',
      ).hasMatch(n);

  bool _isResultAnxiety(String n) => RegExp(
        r'(?:نتيجه|نتيجة|التحليل|الفحص).{0,20}(?:خايف|قلق)|'
        r'(?:خايف|قلق).{0,20}(?:نتيجه|نتيجة|التحليل)',
      ).hasMatch(n);

  bool _isProcedureFear(String n) => RegExp(
        r'(?:خايف|فزع).{0,16}(?:ابر|إبر|ابره|إبرة|عمليه|عملية|فحص)|'
        r'(?:ابر|إبر|ابره|إبرة|عمليه|عملية).{0,16}(?:خايف|فزع)',
      ).hasMatch(n);

  bool _isHealthAnxiety(String n) => RegExp(
        r'(?:خايف|قلق).{0,24}(?:خطير|مرض|الالم|الألم|هذا\s*الالم)|'
        r'(?:هذا\s*(?:الالم|الألم|الشي)).{0,16}(?:خطير|خايف)',
      ).hasMatch(n);

  bool _isOverwhelmed(String n) => RegExp(
        r'(?:ضايع|مضغوط\s*هواي|ما\s*ألحق|ما\s*الحق|كلشي\s*فوق\s*راسي|'
        r'محتار\s*هواي|Overwhelm|منهار)',
      ).hasMatch(n);

  bool _isLoneliness(String n) => RegExp(
        r'(?:وحيد|وحداني|ما\s*اكو\s*احد|ما\s*أكو\s*أحد|حاس\s*بالغربه|'
        r'حاس\s*بالغربة)',
      ).hasMatch(n);

  bool _isFrustration(String n) => RegExp(
        r'(?:زهقان|منزعج|معصب|مستاء|يأسان|يائس|تعبان\s*من)',
      ).hasMatch(n);

  bool _isSadness(String n) => RegExp(
        r'(?:حزين|زعلان|مكتئب\s*شوي|قلبي\s*مقبوض|ضايق\s*صدري)',
      ).hasMatch(n);

  bool _isStress(String n) =>
      RegExp(r'(?:متوتر|توتر|ضغط\s*نفسي|متضايق|مضغوط)').hasMatch(n);

  bool _isWorry(String n) =>
      RegExp(r'(?:قلقان|قلق|مقلق|خايف\s*شوي)').hasMatch(n);

  bool _isFear(String n) =>
      RegExp(r'(?:خايف|خوف|فزعان|مرعوب)').hasMatch(n);

  bool _isUnknownDistress(String n) =>
      RegExp(r'(?:مو\s*بخير|تعبان\s*نفسيا|ما\s*مرتح)').hasMatch(n);
}
