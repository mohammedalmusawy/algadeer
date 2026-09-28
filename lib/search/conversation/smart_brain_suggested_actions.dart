import '../../search/smart_search_models.dart';

/// نوع اقتراح خطوة تالية بعد نتيجة Smart Brain.
enum SmartBrainSuggestedActionKind {
  openDetails,
  call,
  whatsapp,
  showMoreResults,
  showLocation,
  showPackages,
  showOffers,
}

/// اقتراح ديناميكي — يظهر فقط إن توفّرت بيانات حقيقية للكيان.
class SmartBrainSuggestedAction {
  const SmartBrainSuggestedAction({
    required this.kind,
    required this.label,
    this.result,
  });

  final SmartBrainSuggestedActionKind kind;
  final String label;

  /// الكيان المستهدف (إن وُجد) — نفس مصدر بطاقة النتيجة.
  final SmartSearchResult? result;
}

/// بناء اقتراحات من نتائج المنصة فقط — بلا أزرار وهمية.
class SmartBrainSuggestedActionsBuilder {
  SmartBrainSuggestedActionsBuilder._();

  static List<SmartBrainSuggestedAction> forResults(
    List<SmartSearchResult> results, {
    int maxActions = 4,
  }) {
    if (results.isEmpty) return const [];

    final primary = results.first;
    final out = <SmartBrainSuggestedAction>[];

    out.add(
      SmartBrainSuggestedAction(
        kind: SmartBrainSuggestedActionKind.openDetails,
        label: 'عرض التفاصيل',
        result: primary,
      ),
    );

    if (primary.canCall) {
      out.add(
        SmartBrainSuggestedAction(
          kind: SmartBrainSuggestedActionKind.call,
          label: 'اتصال',
          result: primary,
        ),
      );
    }
    if (primary.canWhatsApp) {
      out.add(
        SmartBrainSuggestedAction(
          kind: SmartBrainSuggestedActionKind.whatsapp,
          label: 'واتساب',
          result: primary,
        ),
      );
    }

    final loc = primary.clinicLocation?.trim() ?? '';
    if (loc.isNotEmpty) {
      out.add(
        SmartBrainSuggestedAction(
          kind: SmartBrainSuggestedActionKind.showLocation,
          label: 'الموقع',
          result: primary,
        ),
      );
    }

    // باقات/عروض — للمختبر فقط عندما يكون النوع مختبر (التنفيذ يفتح الملف).
    if (primary.type == SmartSearchResultType.lab) {
      out.add(
        SmartBrainSuggestedAction(
          kind: SmartBrainSuggestedActionKind.showPackages,
          label: 'الباقات',
          result: primary,
        ),
      );
    }

    if (results.length > 1) {
      out.add(
        const SmartBrainSuggestedAction(
          kind: SmartBrainSuggestedActionKind.showMoreResults,
          label: 'المزيد',
        ),
      );
    }

    // إزالة تكرار الأنواع مع الإبقاء على الترتيب.
    final seen = <SmartBrainSuggestedActionKind>{};
    final unique = <SmartBrainSuggestedAction>[];
    for (final a in out) {
      if (seen.add(a.kind)) unique.add(a);
    }
    return unique.take(maxActions).toList(growable: false);
  }
}
