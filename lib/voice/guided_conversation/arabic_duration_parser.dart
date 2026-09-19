import '../../search/arabic_text_utils.dart';
import 'arabic_answer_normalizer.dart';
import 'guided_conversation_models.dart';

/// محلّل مدة عربي خفيف — بدون NLP ضخم أو اختراع أرقام.
class ArabicDurationParser {
  const ArabicDurationParser();

  DurationValue? parse(String raw) {
    final original = raw.trim();
    if (original.isEmpty) return null;
    final n = ArabicTextUtils.normalize(original).replaceAll(RegExp(r'\s+'), ' ').trim();

    // غامض بدون رقم.
    if (RegExp(r'(?:من\s*)?(?:فتره|فترة|زمان|مده\s*طويله|مدة\s*طويله)').hasMatch(n) &&
        ArabicAnswerNormalizer.tryNumber(n) == null &&
        !RegExp(r'\d').hasMatch(n)) {
      return DurationValue(
        approximate: true,
        unit: 'unknown',
        rawText: original,
      );
    }

    if (RegExp(r'(?:^|\s)(?:من\s*)?(?:اليوم|هذا\s*اليوم)(?:\s|$)').hasMatch(n) ||
        RegExp(r'^اليوم$').hasMatch(n) ||
        RegExp(r'^من\s*اليوم$').hasMatch(n)) {
      return DurationValue(
        amount: 0,
        unit: 'relative_today',
        rawText: original,
      );
    }

    if (RegExp(
      r'(?:^|\s)(?:من\s*)?(?:البارحه|البارحة|امس|أمس|الامس|الأمس)(?:\s|$)',
    ).hasMatch(n)) {
      return DurationValue(
        amount: 1,
        unit: 'relative_yesterday',
        approximate: false,
        rawText: original,
      );
    }

    // أسبوعين / شهرين قبل الكمية العامة.
    if (RegExp(r'(?:اسبوعين|أسبوعين)').hasMatch(n)) {
      return DurationValue(amount: 2, unit: 'week', rawText: original);
    }
    if (RegExp(r'(?:شهرين)').hasMatch(n)) {
      return DurationValue(amount: 2, unit: 'month', rawText: original);
    }
    if (RegExp(r'(?:يومين)').hasMatch(n)) {
      return DurationValue(amount: 2, unit: 'day', rawText: original);
    }
    if (RegExp(r'(?:سنتين)').hasMatch(n)) {
      return DurationValue(amount: 2, unit: 'year', rawText: original);
    }

    final amount = _extractAmount(n);
    final unit = _extractUnit(n);
    if (unit != null && amount != null) {
      return DurationValue(amount: amount, unit: unit, rawText: original);
    }
    if (unit != null && amount == null) {
      // «يوم» / «أسبوع» بدون عدد → 1 غالباً إن وُجدت «من» أو كلمة وحدة.
      if (RegExp(r'(?:^|\s)(?:يوم|اسبوع|أسبوع|شهر|سنه|سنة)(?:\s|$)').hasMatch(n) &&
          !RegExp(r'(?:ايام|أيام|اسابيع|أسابيع|اشهر|أشهر)').hasMatch(n)) {
        return DurationValue(amount: 1, unit: unit, rawText: original);
      }
      return DurationValue(
        approximate: true,
        unit: unit,
        rawText: original,
      );
    }

    // نص يبدو مدة لكن غير قابل للهيكلة الآمنة.
    if (RegExp(r'(?:يوم|ايام|أسبوع|اسبوع|شهر|سنه|سنة|بارح|امس)').hasMatch(n)) {
      return DurationValue(
        approximate: true,
        unit: 'unknown',
        rawText: original,
      );
    }

    return null;
  }

  int? _extractAmount(String n) {
    final asNum = ArabicAnswerNormalizer.tryNumber(n);
    if (asNum != null) return asNum.round();

    // ثلاث أيام / 3 ايام
    final m = RegExp(
      r'(\d+)\s*(?:يوم|ايام|أيام|اسبوع|أسبوع|اسابيع|أسابيع|شهر|اشهر|أشهر|سنه|سنة|سنوات)',
    ).firstMatch(n);
    if (m != null) return int.tryParse(m.group(1)!);

    const wordAmounts = <String, int>{
      'واحد': 1,
      'واحدة': 1,
      'يوم': 1, // handled with unit separately
      'ثلاث': 3,
      'ثلاثة': 3,
      'ثلاثه': 3,
      'اربع': 4,
      'اربعة': 4,
      'أربعة': 4,
      'خمس': 5,
      'خمسة': 5,
      'ست': 6,
      'ستة': 6,
      'سبع': 7,
      'سبعة': 7,
      'ثمان': 8,
      'ثمانية': 8,
      'تسع': 9,
      'تسعة': 9,
      'عشر': 10,
      'عشرة': 10,
    };
    for (final e in wordAmounts.entries) {
      if (e.key == 'يوم') continue;
      if (RegExp('(?:^|\\s)${RegExp.escape(e.key)}(?:\\s|\$)').hasMatch(n)) {
        return e.value;
      }
    }
    return null;
  }

  String? _extractUnit(String n) {
    if (RegExp(r'(?:يوم|ايام|أيام)').hasMatch(n)) return 'day';
    if (RegExp(r'(?:اسبوع|أسبوع|اسابيع|أسابيع)').hasMatch(n)) return 'week';
    if (RegExp(r'(?:شهر|اشهر|أشهر)').hasMatch(n)) return 'month';
    if (RegExp(r'(?:سنه|سنة|سنوات|اعوام|أعوام)').hasMatch(n)) return 'year';
    return null;
  }
}
