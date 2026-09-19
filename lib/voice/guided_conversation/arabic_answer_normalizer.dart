import '../../search/arabic_text_utils.dart';

/// تطبيع إجابات عربية/عراقية عامة — ليس chatbot طبي.
class ArabicAnswerNormalizer {
  ArabicAnswerNormalizer._();

  static final RegExp _ws = RegExp(r'\s+');

  /// نعم عراقية/فصحى — بدون «لا، الثاني».
  static bool? tryYesNo(String raw) {
    final n = _prep(raw);
    if (n.isEmpty) return null;

    // تصحيح/اختيار ترتيبي — ليس NO بسيطاً.
    if (_hasOrdinalAfterNo(n)) return null;
    if (_looksLikeCorrection(n)) return null;

    if (_isYes(n)) return true;
    if (_isNo(n)) return false;
    return null;
  }

  static bool isBareYes(String raw) {
    final n = _prep(raw);
    return _isYes(n);
  }

  static bool isBareNo(String raw) {
    final n = _prep(raw);
    if (_hasOrdinalAfterNo(n) || _looksLikeCorrection(n)) return false;
    return _isNo(n);
  }

  static bool isCancelCommand(String raw) {
    final n = _prep(raw);
    if (n.isEmpty) return false;
    // «لا» وحدها ليست إلغاء.
    if (_isNo(n) && !_hasCancelLexeme(n)) return false;
    return _hasCancelLexeme(n);
  }

  static bool _hasCancelLexeme(String n) {
    return RegExp(
      r'(?:^|\s)(?:الغاء|إلغاء|الغاء|خلاص|وقف|ايقاف|إيقاف)(?:\s|$)|'
      r'اترك\s*(?:الموضوع|هذا|هاي)|'
      r'خلينا\s*(?:من\s*)?(?:هذا|هاي|الموضوع)|'
      r'ما\s*(?:اريد|أريد)\s*(?:اكمل|أكمل|نكمل)|'
      r'ما\s*اكمل|ما\s*أكمل',
    ).hasMatch(n);
  }

  /// كلمات أرقام بسيطة + أرقام عربية/لاتينية.
  static num? tryNumber(String raw) {
    final n = _prep(raw);
    if (n.isEmpty) return null;

    final digit = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(n);
    if (digit != null) return num.tryParse(digit.group(1)!);

    const words = <String, int>{
      'صفر': 0,
      'واحد': 1,
      'واحدة': 1,
      'واحده': 1,
      'اثنين': 2,
      'اثنان': 2,
      'اثنتين': 2,
      'ثنين': 2,
      'ثلاث': 3,
      'ثلاثة': 3,
      'ثلاثه': 3,
      'اربع': 4,
      'اربعة': 4,
      'أربعة': 4,
      'اربعه': 4,
      'خمس': 5,
      'خمسة': 5,
      'خمسه': 5,
      'ست': 6,
      'ستة': 6,
      'سته': 6,
      'سبع': 7,
      'سبعة': 7,
      'سبعه': 7,
      'ثمان': 8,
      'ثمانية': 8,
      'ثمانيه': 8,
      'تسع': 9,
      'تسعة': 9,
      'تسعه': 9,
      'عشر': 10,
      'عشرة': 10,
      'عشره': 10,
    };

    for (final e in words.entries) {
      if (RegExp('(?:^|\\s)${RegExp.escape(e.key)}(?:\\s|\$)').hasMatch(n) ||
          n == e.key) {
        return e.value;
      }
    }
    return null;
  }

  /// هل النص يبدو تصحيحاً صريحاً لإجابة سابقة؟
  static bool looksLikeCorrection(String raw) => _looksLikeCorrection(_prep(raw));

  /// يستخرج الجزء بعد علامة التصحيح إن وُجدت.
  static String stripCorrectionPrefix(String raw) {
    final original = raw.trim();
    final n = ArabicTextUtils.normalize(original);
    final m = RegExp(
      r'(?:^|\s)(?:لا\s*[,،]?\s*)?(?:قصدي|اقصد|أقصد|اعني|أعني)\s*[:：]?\s*(.+)$',
    ).firstMatch(n);
    if (m != null) {
      final rest = (m.group(1) ?? '').trim();
      if (rest.isNotEmpty) return rest;
    }
    return original;
  }

  static String _prep(String raw) {
    return ArabicTextUtils.normalize(raw)
        .replaceAll(_ws, ' ')
        .trim();
  }

  static bool _isYes(String n) {
    if (RegExp(
      r'^(?:نعم|اي|إي|ايوه|أيوه|ايوه|اي\s*نعم|اكيد|أكيد|تمام|هيه|اييه|ايي|'
      r'اوكي|أوكي|ok|okay)$',
    ).hasMatch(n)) {
      return true;
    }
    return RegExp(
      r'^(?:نعم|اي|إي|ايوه|أيوه)\s*(?:من\s*فضلك|لو\s*سمحت)?$',
    ).hasMatch(n);
  }

  static bool _isNo(String n) {
    if (RegExp(
      r'^(?:لا|كلا|مو|لأ|لا\s*شكرا|لا\s*شكراً|لا\s*ما\s*(?:اريد|أريد)|ما\s*(?:اريد|أريد))$',
    ).hasMatch(n)) {
      return true;
    }
    return false;
  }

  static bool _hasOrdinalAfterNo(String n) {
    return RegExp(
      r'^لا\s*[,،]?\s*(?:ال)?(?:اول|أول|اولي|أولى|ثاني|ثانيه|ثانية|ثالث|ثالثه|ثالثة|رابع|خامس|اخير|أخير)',
    ).hasMatch(n);
  }

  static bool _looksLikeCorrection(String n) {
    return RegExp(
      r'(?:قصدي|اقصد|أقصد|اعني|أعني)',
    ).hasMatch(n);
  }
}
