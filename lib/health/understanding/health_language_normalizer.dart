import '../../search/arabic_text_utils.dart';

/// تطبيع نص صحي يعيد استخدام ArabicTextUtils دون تغيير دلالاته العامة.
class HealthLanguageNormalizer {
  const HealthLanguageNormalizer();

  String normalize(String raw) {
    var t = ArabicTextUtils.normalize(raw)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // فصل واو العطف الملتصقة في بداية الكلمة فقط — لا تلمس وسط الكلمة (يوجعني/يومين).
    // ولا تُقسَّم «ولا».
    t = t.replaceAllMapped(
      RegExp(r'(^|\s)و(?!لا(?:\s|$))(?=[\u0600-\u06FF]{2,})'),
      (m) => '${m.group(1)}و ',
    );
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// مسافات حول علامات لتسهيل حدود العبارات.
  String prepareForMatching(String raw) {
    final n = normalize(raw);
    return ' $n ';
  }
}
