import 'emotional_support_models.dart';

/// سياسة نبرة: أمل آمن + صدق. السلامة فوق التطمين.
class EmotionalSupportPolicy {
  const EmotionalSupportPolicy();

  static final _forbiddenReassurance = RegExp(
    r'(?:اكيد\s*ما\s*بيك\s*شي|أكيد\s*ما\s*بيك\s*شي|'
    r'مستحيل\s*يكون\s*خطير|راح\s*تكون\s*بخير\s*100|'
    r'النتيجه\s*سليمه|النتيجة\s*سليمة|'
    r'انا\s*انسان\s*مثلك|أنا\s*إنسان\s*مثلك|'
    r'انا\s*احبك|أنا\s*أحبك|'
    r'انا\s*الوحيد|لا\s*تحتاج\s*احد\s*غيري|'
    r'ابقى\s*وياي\s*ولا\s*تروح)',
  );

  bool containsForbiddenLanguage(String text) =>
      _forbiddenReassurance.hasMatch(text);

  EmotionalSupportStrategy strategyFor(EmotionalSignal signal) {
    if (signal.aboutOtherPerson) {
      // لا نخزّن عاطفة الغير كمالك — رد قصير فقط إن لزم
      return EmotionalSupportStrategy.acknowledgeCalmNextStep;
    }
    switch (signal.category) {
      case EmotionalSignalCategory.fear:
        return EmotionalSupportStrategy.acknowledgeCalmNextStep;
      case EmotionalSignalCategory.worry:
        return EmotionalSupportStrategy.acknowledgeCalmNextStep;
      case EmotionalSignalCategory.stress:
        return EmotionalSupportStrategy.reduceTaskSize;
      case EmotionalSignalCategory.examStress:
        return EmotionalSupportStrategy.examOrganize;
      case EmotionalSignalCategory.resultAnxiety:
        return EmotionalSupportStrategy.resultAnxietyNoPrediction;
      case EmotionalSignalCategory.procedureFear:
        return EmotionalSupportStrategy.procedureCalmPrep;
      case EmotionalSignalCategory.frustration:
        return EmotionalSupportStrategy.acknowledgeAndSolve;
      case EmotionalSignalCategory.sadness:
        return EmotionalSupportStrategy.supportiveOptionalQuestion;
      case EmotionalSignalCategory.healthAnxiety:
        return EmotionalSupportStrategy.acknowledgeCalmNextStep;
      case EmotionalSignalCategory.overwhelmed:
        return EmotionalSupportStrategy.oneThingAtATime;
      case EmotionalSignalCategory.loneliness:
        return EmotionalSupportStrategy.supportiveOptionalQuestion;
      case EmotionalSignalCategory.unknownDistress:
        return EmotionalSupportStrategy.supportiveOptionalQuestion;
      case EmotionalSignalCategory.neutral:
        return EmotionalSupportStrategy.none;
    }
  }

  /// لا تفرض سؤالاً عاطفياً إذا الهدف واضح (طبيب/مختبر…).
  bool shouldAskGentleClarification({
    required EmotionalSignal signal,
    required bool hasClearTaskIntent,
  }) {
    if (hasClearTaskIntent) return false;
    if (signal.aboutOtherPerson) return false;
    return signal.category == EmotionalSignalCategory.unknownDistress ||
        (signal.category == EmotionalSignalCategory.sadness &&
            signal.intensity == EmotionalIntensity.strong);
  }
}
