/// مبدأ مكافحة التلاعب بالذاكرة — سياسة منتج.

class MemoryAntiManipulationPolicy {
  const MemoryAntiManipulationPolicy();

  /// استخدامات ممنوعة للذاكرة الشخصية.
  static const forbiddenUses = <String>{
    'guilt',
    'jealousy',
    'pressure_to_return',
    'fake_emotional_dependency',
    'punish_absence',
    'اشتقتلك',
    'ليش_ما_رجعت',
  };

  bool isForbiddenUse(String useCode) => forbiddenUses.contains(useCode);

  /// الذاكرة لتقليل التكرار وتحسين الفائدة — لا للتعلّق الزائف.
  String get purposeStatement =>
      'Memory exists to reduce repetition and improve usefulness.';
}

/// سياسة الاسترجاع المستقبلي — حد أدنى وغرض محدد.
class MemoryUsePolicy {
  const MemoryUsePolicy();

  bool mayInjectAllKnownFactsEveryTurn() => false;

  /// الذاكرة الصحية الحساسة تُسترجع فقط في سياق صحي مناسب.
  bool mayRetrieveSensitiveHealthOutsideHealthContext() => false;

  bool retrievalMustBeRelevantMinimalPurposeLimited() => true;
}
