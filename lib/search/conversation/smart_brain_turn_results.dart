import '../smart_search_models.dart';

/// سياق النتائج المحفوظ مقابل نتائج عرض الدور — سلطتان منفصلتان.
///
/// كانت الصفحة تُلحق قائمة النتائج المستمرة (`_results`) بكل رد مساعد، فبطاقة
/// طبيب من دور بحث قديم تبقى معلّقة تحت أجوبة سريرية لاحقة لا تطلب طبيباً ولا
/// ترجّعه، فيبدو كأن الغدير يكرّر التوصية بنفس الطبيب.
///
/// السياق المحفوظ ([retained]) ضروري ويبقى: منه تُحلّ أوامر «اتصل» و«ارسل
/// واتساب» والاختيار بالترتيب. أما العرض فمرتبط بالدور: [presentedIn] لا
/// تُرجِع شيئاً إلا للدور الذي أنتج النتائج فعلاً. الحدّ هو رقم الدور، لا
/// مؤقّت ولا تأخير.
class SmartBrainTurnResults {
  List<SmartSearchResult> _results = const [];
  int _producedInTurn = -1;

  /// آخر نتائج معروفة للجلسة — ذاكرة داخلية للأفعال والاستمرارية.
  List<SmartSearchResult> get retained => _results;

  /// النتائج التي أنتجها [turn] نفسه — مصدر بطاقات الرد الوحيد.
  ///
  /// ذاكرة المحادثة التاريخية ليست نتيجة دور، فترجع فارغة لأي دور آخر.
  List<SmartSearchResult> presentedIn(int turn) =>
      turn == _producedInTurn ? _results : const [];

  /// يثبّت نتائج أنتجها [turn] بعد إزالة تكرار نفس الكيان في الرد الواحد.
  void remember(List<SmartSearchResult> results, {required int turn}) {
    _results = List<SmartSearchResult>.unmodifiable(dedupeByEntityId(results));
    _producedInTurn = turn;
  }

  /// يمنع بطاقة الطبيب/الكيان نفسها مرتين في نفس قائمة العرض.
  static List<SmartSearchResult> dedupeByEntityId(
    List<SmartSearchResult> results,
  ) {
    if (results.length <= 1) return results;
    final seen = <String>{};
    final out = <SmartSearchResult>[];
    for (final r in results) {
      final id = _entityId(r);
      if (id.isEmpty) {
        out.add(r);
        continue;
      }
      final key = '${r.type.name}:$id';
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(r);
    }
    return out;
  }

  static String _entityId(SmartSearchResult r) {
    switch (r.type) {
      case SmartSearchResultType.doctor:
        return (r.doctorId ?? '').trim();
      case SmartSearchResultType.lab:
        return (r.labId ?? '').trim();
      case SmartSearchResultType.radiology:
        return (r.radiologyId ?? '').trim();
      case SmartSearchResultType.pharmacy:
        return (r.pharmacyId ?? '').trim();
      case SmartSearchResultType.physio:
        return (r.physioId ?? '').trim();
      case SmartSearchResultType.supply:
        return (r.supplyId ?? '').trim();
      case SmartSearchResultType.optics:
        return (r.opticsId ?? '').trim();
      case SmartSearchResultType.beauty:
        return (r.beautyId ?? '').trim();
      case SmartSearchResultType.nursing:
        return (r.nursingId ?? '').trim();
      case SmartSearchResultType.package:
      case SmartSearchResultType.offer:
        return (r.packageId ?? '').trim();
      case SmartSearchResultType.analysis:
        return (r.analysisId ?? '').trim();
      case SmartSearchResultType.specialty:
        return '';
    }
  }
}
