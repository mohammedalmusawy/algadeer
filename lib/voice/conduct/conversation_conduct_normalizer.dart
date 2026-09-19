import '../../search/arabic_text_utils.dart';

/// تطبيع خاص بكشف السلوك — لا يُعيد كتابة أسماء الأطباء/المختبرات عالمياً.
class ConversationConductNormalizer {
  const ConversationConductNormalizer();

  String normalize(String raw) {
    var t = ArabicTextUtils.normalize(raw.trim());
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    // چ → ج / ك للمتغيرات الشائعة في الكتالوج فقط عند المقارنة
    t = t.replaceAll('چ', 'ج');
    // گ تبقى كما هي للمقارنة مع أنماط تحتوي گ أو ق عند الحاجة
    return t;
  }

  /// نص مقارنة متسامح قليلاً للمتغيرات الإملائية العراقية.
  String forMatch(String raw) {
    var t = normalize(raw);
    t = t.replaceAll('ة', 'ه');
    t = t.replaceAll('ى', 'ي');
    t = t.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
    return t;
  }
}
