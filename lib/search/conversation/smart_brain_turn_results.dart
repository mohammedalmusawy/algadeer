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

  /// يثبّت نتائج أنتجها [turn].
  void remember(List<SmartSearchResult> results, {required int turn}) {
    _results = List<SmartSearchResult>.unmodifiable(results);
    _producedInTurn = turn;
  }
}
