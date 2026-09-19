/// كيانات مستخرجة من الاستعلام — هيكل Phase 1 خفيف للتوسّع لاحقًا.
class ExtractedEntities {
  const ExtractedEntities({
    this.doctorName,
    this.specialty,
    this.laboratory,
    this.packageName,
    this.offerName,
    this.analysis,
    this.analysisTerms = const [],
    this.symptomKeyword,
    this.dateText,
    this.dayText,
    this.timeText,
    this.availabilityHint,
    this.resultIndex,
    this.actionHint,
    this.rawTokens = const [],
  });

  final String? doctorName;
  final String? specialty;
  final String? laboratory;
  final String? packageName;
  final String? offerName;

  /// تعبير تحليل واحد (للتوافق مع Steps 4–7).
  final String? analysis;

  /// تحاليل متعددة صريحة من المستخدم (تقاطع الباقات) — بدون استنتاج طبي.
  final List<String> analysisTerms;

  final String? symptomKeyword;
  final String? dateText;
  final String? dayText;
  final String? timeText;
  final String? availabilityHint;
  final int? resultIndex;
  final String? actionHint;
  final List<String> rawTokens;

  static const empty = ExtractedEntities();
  static const _unset = Object();

  /// كل تعبيرات التحليل: analysisTerms إن وُجدت، وإلا analysis المفرد.
  List<String> get allAnalysisTerms {
    if (analysisTerms.isNotEmpty) {
      return analysisTerms
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    final one = (analysis ?? '').trim();
    if (one.isEmpty) return const [];
    return [one];
  }

  bool get isEmpty =>
      doctorName == null &&
      specialty == null &&
      laboratory == null &&
      packageName == null &&
      offerName == null &&
      analysis == null &&
      analysisTerms.isEmpty &&
      symptomKeyword == null &&
      dateText == null &&
      dayText == null &&
      timeText == null &&
      availabilityHint == null &&
      resultIndex == null &&
      actionHint == null;

  ExtractedEntities copyWith({
    Object? doctorName = _unset,
    Object? specialty = _unset,
    Object? laboratory = _unset,
    Object? packageName = _unset,
    Object? offerName = _unset,
    Object? analysis = _unset,
    List<String>? analysisTerms,
    Object? symptomKeyword = _unset,
    Object? dateText = _unset,
    Object? dayText = _unset,
    Object? timeText = _unset,
    Object? availabilityHint = _unset,
    Object? resultIndex = _unset,
    Object? actionHint = _unset,
    List<String>? rawTokens,
  }) {
    return ExtractedEntities(
      doctorName: identical(doctorName, _unset)
          ? this.doctorName
          : doctorName as String?,
      specialty: identical(specialty, _unset)
          ? this.specialty
          : specialty as String?,
      laboratory: identical(laboratory, _unset)
          ? this.laboratory
          : laboratory as String?,
      packageName: identical(packageName, _unset)
          ? this.packageName
          : packageName as String?,
      offerName:
          identical(offerName, _unset) ? this.offerName : offerName as String?,
      analysis:
          identical(analysis, _unset) ? this.analysis : analysis as String?,
      analysisTerms: analysisTerms ?? this.analysisTerms,
      symptomKeyword: identical(symptomKeyword, _unset)
          ? this.symptomKeyword
          : symptomKeyword as String?,
      dateText:
          identical(dateText, _unset) ? this.dateText : dateText as String?,
      dayText: identical(dayText, _unset) ? this.dayText : dayText as String?,
      timeText:
          identical(timeText, _unset) ? this.timeText : timeText as String?,
      availabilityHint: identical(availabilityHint, _unset)
          ? this.availabilityHint
          : availabilityHint as String?,
      resultIndex: identical(resultIndex, _unset)
          ? this.resultIndex
          : resultIndex as int?,
      actionHint: identical(actionHint, _unset)
          ? this.actionHint
          : actionHint as String?,
      rawTokens: rawTokens ?? this.rawTokens,
    );
  }
}
