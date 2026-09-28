import '../../search/conversation/smart_brain_suggested_actions.dart';
import '../../search/smart_search_models.dart';

/// نتيجة الوصول لبيانات المنصة — Fail Closed.
enum PlatformGroundingOutcome {
  /// وُجدت نتائج حقيقية من المنصة.
  ok,

  /// البحث نجح لكن القائمة فارغة / لا تطابق.
  noResults,

  /// فشل شبكة / مهلة عند جلب البيانات.
  networkError,

  /// بيانات تالفة أو شكل غير متوقع.
  dataError,

  /// فهم النية غامض — يحتاج توضيح (ليس اختراع بيانات).
  understandingError,

  /// الحقل موجود على الكيان لكن القيمة فارغة (هاتف/موقع…).
  fieldUnavailable,
}

/// نوع نتيجة grounded للتتبع الداخلي.
enum PlatformGroundedResultType {
  none,
  doctor,
  laboratory,
  radiology,
  pharmacy,
  physio,
  supply,
  package,
  analysis,
  offer,
  messageOnly,
}

/// جواب مربوط بكيانات المنصة فقط — بلا اختراع.
class GroundedResponse {
  const GroundedResponse({
    required this.text,
    required this.outcome,
    this.resultType = PlatformGroundedResultType.messageOnly,
    this.sourceEntityIds = const [],
    this.suggestedActions = const [],
  });

  final String text;
  final PlatformGroundingOutcome outcome;
  final PlatformGroundedResultType resultType;
  final List<String> sourceEntityIds;
  final List<SmartBrainSuggestedAction> suggestedActions;

  bool get isGroundedOk =>
      outcome == PlatformGroundingOutcome.ok && sourceEntityIds.isNotEmpty;

  bool get isFailClosed => outcome != PlatformGroundingOutcome.ok;
}

/// سياسة «بيانات الغدير فقط» — أعلى أولوية من جمال الرد.
///
/// LLM يفهم اللغة فقط؛ كل حقيقة عن المنصة من Platform Data.
class PlatformGrounding {
  PlatformGrounding._();

  static const String accessProblemMessage =
      'صار عندي مشكلة بالوصول لبيانات الغدير، حاول مرة ثانية.';

  static const String noResultsMessage =
      'ما لكيت نتيجة مطابقة حاليًا داخل منصة الغدير.';

  static const String emptyCatalogMessage =
      'ما عندي بيانات معروضة حالياً داخل منصة الغدير لهذا الطلب.';

  static const String phoneUnavailableMessage =
      'رقم الاتصال مو متوفر حالياً بالمنصة.';

  static const String whatsappUnavailableMessage =
      'واتساب مو متوفر حالياً بالمنصة.';

  static const String locationUnavailableMessage =
      'موقع العيادة مو مسجل حالياً بالمنصة.';

  static const String pharmacyPackagesEmptyMessage =
      'حاليًا ما موجودة باقات مسجلة لهذه الصيدلية داخل منصة الغدير.';

  /// رسالة لا تطابق اسم كيان — من البيانات فقط، بلا اقتراح بديل.
  static String noMatchFor({
    required String entityLabelAr,
    required String nameQuery,
  }) {
    final q = nameQuery.trim();
    if (q.isEmpty) return noResultsMessage;
    return 'لم أجد $entityLabelAr مطابقاً لـ «$q» داخل منصة الغدير.';
  }

  static String phoneUnavailableFor(String title) {
    final t = title.trim();
    if (t.isEmpty) return phoneUnavailableMessage;
    return 'رقم اتصال $t غير متوفر حالياً بالمنصة.';
  }

  static String whatsappUnavailableFor(String title) {
    final t = title.trim();
    if (t.isEmpty) return whatsappUnavailableMessage;
    return 'واتساب $t غير متوفر حالياً بالمنصة.';
  }

  static String locationUnavailableFor(String title) {
    final t = title.trim();
    if (t.isEmpty) return locationUnavailableMessage;
    return 'موقع $t مو مسجل حالياً بالمنصة.';
  }

  static String messageForOutcome(PlatformGroundingOutcome outcome) {
    switch (outcome) {
      case PlatformGroundingOutcome.ok:
        return '';
      case PlatformGroundingOutcome.noResults:
        return noResultsMessage;
      case PlatformGroundingOutcome.networkError:
      case PlatformGroundingOutcome.dataError:
        return accessProblemMessage;
      case PlatformGroundingOutcome.understandingError:
        return 'ما فهمت طلبك تماماً. تگدر تعيد الصياغة؟';
      case PlatformGroundingOutcome.fieldUnavailable:
        return phoneUnavailableMessage;
    }
  }

  /// معرّفات كيانات حقيقية فقط من نتائج المنصة.
  static List<String> entityIdsFromResults(List<SmartSearchResult> results) {
    final out = <String>[];
    for (final r in results) {
      final id = _idOf(r);
      if (id != null && id.isNotEmpty) out.add(id);
    }
    return List<String>.unmodifiable(out);
  }

  static String? _idOf(SmartSearchResult r) {
    switch (r.type) {
      case SmartSearchResultType.doctor:
        return r.doctorId;
      case SmartSearchResultType.lab:
        return r.labId;
      case SmartSearchResultType.radiology:
        return r.radiologyId;
      case SmartSearchResultType.pharmacy:
        return r.pharmacyId;
      case SmartSearchResultType.physio:
        return r.physioId;
      case SmartSearchResultType.supply:
        return r.supplyId;
      case SmartSearchResultType.package:
      case SmartSearchResultType.offer:
        return r.packageId;
      case SmartSearchResultType.analysis:
        return r.analysisId;
      case SmartSearchResultType.specialty:
        return null;
    }
  }

  static GroundedResponse fromResults({
    required String text,
    required List<SmartSearchResult> results,
    PlatformGroundedResultType resultType =
        PlatformGroundedResultType.messageOnly,
    int maxActions = 4,
  }) {
    if (results.isEmpty) {
      return GroundedResponse(
        text: text.trim().isNotEmpty ? text : noResultsMessage,
        outcome: PlatformGroundingOutcome.noResults,
        resultType: PlatformGroundedResultType.none,
      );
    }
    return GroundedResponse(
      text: text,
      outcome: PlatformGroundingOutcome.ok,
      resultType: resultType,
      sourceEntityIds: entityIdsFromResults(results),
      suggestedActions: SmartBrainSuggestedActionsBuilder.forResults(
        results,
        maxActions: maxActions,
      ),
    );
  }

  /// هل الرسالة تبدو وكأنها اخترعت مزوداً برقم؟ (لاختبارات الانحدار)
  static bool looksLikeHallucinatedProvider(String message) {
    final m = message.trim();
    if (m.isEmpty) return false;
    if (RegExp(r'07\d{8,}').hasMatch(m) &&
        RegExp(r'(?:د\.|دكتور|مختبر|صيدلية|أشعة)').hasMatch(m) &&
        !m.contains('منصة الغدير') &&
        !m.contains('غير متوفر') &&
        !m.contains('مو متوفر')) {
      return true;
    }
    if (RegExp(r'وجدت\s+د\.\s*\S+').hasMatch(m) &&
        m.contains('عيادته في')) {
      return true;
    }
    return false;
  }
}
