/// عتبات ثقة مركزية لـ Smart Brain — قابلة للاختبار والتعديل من مكان واحد.
///
/// لا تغيّر سلوك المطابقات الحالية؛ تُستخدم لتصنيف القرار:
/// تنفيذ مباشر / تأكيد / توضيح.
enum SmartBrainConfidenceBand {
  high,
  medium,
  low,
}

class SmartBrainConfidencePolicy {
  SmartBrainConfidencePolicy._();

  /// درجة نية (0–100) من IntentResult.
  static const int intentHighMin = 80;
  static const int intentMediumMin = 55;

  /// درجة مطابقة اسم كيان (matcher score).
  static const int matchHighMin = 90;
  static const int matchMediumMin = 70;

  static SmartBrainConfidenceBand fromIntentScore(int score) {
    if (score >= intentHighMin) return SmartBrainConfidenceBand.high;
    if (score >= intentMediumMin) return SmartBrainConfidenceBand.medium;
    return SmartBrainConfidenceBand.low;
  }

  static SmartBrainConfidenceBand fromMatchScore(num score) {
    if (score >= matchHighMin) return SmartBrainConfidenceBand.high;
    if (score >= matchMediumMin) return SmartBrainConfidenceBand.medium;
    return SmartBrainConfidenceBand.low;
  }

  /// قرار موحّد: تطابق قوي + نية قوية → تنفيذ؛ وإلا تأكيد أو توضيح.
  static SmartBrainConfidenceBand combine({
    required int intentScore,
    num? matchScore,
  }) {
    final intentBand = fromIntentScore(intentScore);
    if (matchScore == null) return intentBand;
    final matchBand = fromMatchScore(matchScore);
    // الأضعف يفوز — لا ننفّذ بحماس زائد.
    if (intentBand == SmartBrainConfidenceBand.low ||
        matchBand == SmartBrainConfidenceBand.low) {
      return SmartBrainConfidenceBand.low;
    }
    if (intentBand == SmartBrainConfidenceBand.medium ||
        matchBand == SmartBrainConfidenceBand.medium) {
      return SmartBrainConfidenceBand.medium;
    }
    return SmartBrainConfidenceBand.high;
  }

  /// حل اسم كيان داخل [SmartBrainPlanner._planExplicitName].
  ///
  /// المطابقة تقود القرار لأن نية `doctorSearch` الافتراضية (~75) متوسطة
  /// دائماً ولا يجب أن تمنع التنفيذ عند تطابق اسم قوي ووحيد.
  /// نية LOW تبقى تمنع التنفيذ (توضيح).
  static SmartBrainConfidenceBand forNameResolution({
    required int intentScore,
    required num matchScore,
  }) {
    if (fromIntentScore(intentScore) == SmartBrainConfidenceBand.low) {
      return SmartBrainConfidenceBand.low;
    }
    return fromMatchScore(matchScore);
  }

  /// مثل [forNameResolution] مع رفع تطابق وحيد غير غامض من MEDIUM → HIGH
  /// فقط عند تلميح نوع صريح (دكتور/صيدلية/…) في العبارة.
  ///
  /// «اتصل بعلي» بلا لقب → يبقى تأكيداً (اسم أول شائع).
  /// «واتساب لدكتور ناجي» مع لقب + وحيد على المنصة → تنفيذ مباشر.
  static SmartBrainConfidenceBand forUniqueNameResolution({
    required int intentScore,
    required num matchScore,
    required bool isUniqueNonAmbiguous,
    bool hasExplicitTypeHint = false,
  }) {
    final band = forNameResolution(
      intentScore: intentScore,
      matchScore: matchScore,
    );
    if (band == SmartBrainConfidenceBand.medium &&
        isUniqueNonAmbiguous &&
        hasExplicitTypeHint &&
        matchScore >= matchMediumMin) {
      return SmartBrainConfidenceBand.high;
    }
    return band;
  }

  static bool shouldExecuteDirectly(SmartBrainConfidenceBand band) =>
      band == SmartBrainConfidenceBand.high;

  static bool shouldConfirm(SmartBrainConfidenceBand band) =>
      band == SmartBrainConfidenceBand.medium;

  static bool shouldClarify(SmartBrainConfidenceBand band) =>
      band == SmartBrainConfidenceBand.low;
}
