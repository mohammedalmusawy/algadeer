import '../doctors/doctor_today_availability.dart';
import '../voice/intent/search_modifiers.dart';
import 'smart_search_models.dart';

/// يطبّق مُعدِّلات «متوفر/اليوم» و«الأكثر طلبًا» على نتائج بحث حقيقية.
///
/// لا يضيف ولا يحذف نتائج ولا يخترع بيانات: يعيد ترتيب الأطباء/المختبرات
/// داخل مواضعها فقط، من حقول Supabase الموجودة في [SmartSearchResult].
class SearchRefiner {
  const SearchRefiner._();

  static DoctorTodayAvailability availabilityOf(
    SmartSearchResult r, {
    DateTime? nowUtc,
  }) {
    return DoctorTodayAvailability.evaluate(
      workingDays: r.workingDays ?? '',
      workingHours: r.workingHours ?? '',
      bookingStatus: r.bookingStatus ?? '',
      absenceFrom: r.absenceFrom ?? '',
      absenceTo: r.absenceTo ?? '',
      nowUtc: nowUtc,
    );
  }

  static List<SmartSearchResult> apply(
    List<SmartSearchResult> results,
    SearchModifiers mods, {
    DateTime? nowUtc,
  }) {
    if (mods.isNone || results.length < 2) return results;
    final out = List<SmartSearchResult>.of(results);
    _reorderType(out, SmartSearchResultType.doctor, mods, nowUtc);
    _reorderType(out, SmartSearchResultType.lab, mods, nowUtc);
    return out;
  }

  static void _reorderType(
    List<SmartSearchResult> out,
    SmartSearchResultType type,
    SearchModifiers mods,
    DateTime? nowUtc,
  ) {
    final indices = <int>[];
    final items = <SmartSearchResult>[];
    for (var i = 0; i < out.length; i++) {
      if (out[i].type == type) {
        indices.add(i);
        items.add(out[i]);
      }
    }
    if (items.length < 2) return;

    final tiers = <int>[
      for (final r in items)
        (mods.availableOnly && type == SmartSearchResultType.doctor)
            ? availabilityOf(r, nowUtc: nowUtc).tier
            : 0,
    ];
    final order = List<int>.generate(items.length, (i) => i);
    order.sort((a, b) {
      if (tiers[a] != tiers[b]) return tiers[a].compareTo(tiers[b]);
      if (mods.byDemand) {
        final d = items[b].demandScore.compareTo(items[a].demandScore);
        if (d != 0) return d;
      }
      return a.compareTo(b);
    });
    for (var k = 0; k < indices.length; k++) {
      out[indices[k]] = items[order[k]];
    }
  }

  /// جملة قصيرة تُلحق برد البحث — أرقامها من النتائج المعروضة نفسها.
  /// null عند عدم وجود مُعدِّل أو عدم وجود ما يُقال بصدق.
  static String? summary(
    List<SmartSearchResult> shown,
    SearchModifiers mods, {
    DateTime? nowUtc,
  }) {
    if (mods.isNone) return null;
    final parts = <String>[];

    final doctors =
        shown.where((r) => r.type == SmartSearchResultType.doctor).toList();
    if (mods.availableOnly && doctors.isNotEmpty) {
      final n = doctors
          .where((d) => availabilityOf(d, nowUtc: nowUtc).isAvailableToday)
          .length;
      if (n == 0) {
        parts.add('لا يوجد متاح مؤكد منهم اليوم.');
      } else if (n == 1) {
        parts.add('المتاح منهم اليوم واحد.');
      } else {
        parts.add('المتاحون منهم اليوم: $n.');
      }
    }

    if (mods.byDemand) {
      final hasDemand = shown.any(
        (r) =>
            (r.type == SmartSearchResultType.doctor ||
                r.type == SmartSearchResultType.lab) &&
            r.demandScore > 0,
      );
      parts.add(
        hasDemand
            ? 'الترتيب حسب الأكثر طلبًا.'
            : 'ما توجد بيانات طلب كافية للترتيب.',
      );
    }

    return parts.isEmpty ? null : parts.join(' ');
  }
}
