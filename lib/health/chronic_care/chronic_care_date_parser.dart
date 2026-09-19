import '../../search/arabic_text_utils.dart';
import 'chronic_care_models.dart';

/// تحليل توقيت نسبي حتمي — بلا اختلاق تواريخ غير مدعومة.
class ChronicCareDateParser {
  const ChronicCareDateParser();

  ({ChronicRelativeTiming timing, DateTime? exact}) parse(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (RegExp(r'(?:اليوم|هسه|الحين)').hasMatch(n)) {
      return (timing: ChronicRelativeTiming.today, exact: today);
    }
    if (RegExp(r'(?:امس|أمس)').hasMatch(n)) {
      return (
        timing: ChronicRelativeTiming.yesterday,
        exact: today.subtract(const Duration(days: 1)),
      );
    }
    if (RegExp(r'(?:قبل\s*اسبوع|قبل\s*أسبوع|اسبوع|أسبوع)').hasMatch(n)) {
      return (timing: ChronicRelativeTiming.aboutAWeekAgo, exact: null);
    }
    if (RegExp(r'(?:قبل\s*شهر|الشهر\s*الماضي)').hasMatch(n)) {
      return (timing: ChronicRelativeTiming.aboutAMonthAgo, exact: null);
    }
    if (RegExp(r'(?:قبل\s*ثلاث(?:ة)?\s*اشهر|قبل\s*ثلاثة\s*أشهر|ثلاث\s*اشهر)')
        .hasMatch(n)) {
      return (timing: ChronicRelativeTiming.aboutThreeMonthsAgo, exact: null);
    }
    return (timing: ChronicRelativeTiming.unknown, exact: null);
  }
}
