import '../../search/smart_search_models.dart';
import '../intent/assistant_intent.dart';

/// نوع كيان التوضيح — جاهز للتوسّع لاحقاً (مختبرات/تحاليل/باقات…).
enum ClarificationEntityType {
  doctor,
  laboratory,
  analysis,
  package,
  offer,
  radiology,
  pharmacy,
  physio,
  supply,
  unknown,
}

/// سبب فتح حالة التوضيح.
enum ClarificationReason {
  ambiguousName,
  multipleMatches,
  incompleteReference,
  missingTarget,
}

/// مرشّح توضيحي عام — لا يعتمد على نوع طبيب فقط.
class ClarificationCandidate {
  const ClarificationCandidate({
    required this.id,
    required this.entityType,
    required this.primaryLabel,
    this.secondaryLabel,
    this.payload,
  });

  final String id;
  final ClarificationEntityType entityType;

  /// الاسم المعروض الأساسي.
  final String primaryLabel;

  /// اختصاص / موقع / وصف ثانوي.
  final String? secondaryLabel;

  /// الحمولة الأصلية (مثلاً SmartSearchResult) — للاستخدام الداخلي فقط.
  final Object? payload;

  SmartSearchResult? get asDoctorResult {
    final p = payload;
    if (p is SmartSearchResult && p.type == SmartSearchResultType.doctor) {
      return p;
    }
    return null;
  }

  SmartSearchResult? get asLabResult {
    final p = payload;
    if (p is SmartSearchResult && p.type == SmartSearchResultType.lab) {
      return p;
    }
    return null;
  }

  SmartSearchResult? get asAnalysisResult {
    final p = payload;
    if (p is SmartSearchResult && p.type == SmartSearchResultType.analysis) {
      return p;
    }
    return null;
  }

  SmartSearchResult? get asPackageResult {
    final p = payload;
    if (p is SmartSearchResult &&
        (p.type == SmartSearchResultType.package ||
            p.type == SmartSearchResultType.offer)) {
      return p;
    }
    return null;
  }

  SmartSearchResult? get asRadiologyResult {
    final p = payload;
    if (p is SmartSearchResult && p.type == SmartSearchResultType.radiology) {
      return p;
    }
    return null;
  }

  SmartSearchResult? get asPharmacyResult {
    final p = payload;
    if (p is SmartSearchResult && p.type == SmartSearchResultType.pharmacy) {
      return p;
    }
    return null;
  }

  SmartSearchResult? get asPhysioResult {
    final p = payload;
    if (p is SmartSearchResult && p.type == SmartSearchResultType.physio) {
      return p;
    }
    return null;
  }

  SmartSearchResult? get asSupplyResult {
    final p = payload;
    if (p is SmartSearchResult && p.type == SmartSearchResultType.supply) {
      return p;
    }
    return null;
  }
}

/// حالة توضيح معلّقة — مصدر حقيقة واحد داخل ConversationContext.
class PendingClarification {
  PendingClarification({
    required this.entityType,
    required this.reason,
    required List<ClarificationCandidate> candidates,
    this.originalIntent,
    this.originalQuery,
    this.pendingAction,
    DateTime? createdAt,
  })  : candidates = List<ClarificationCandidate>.unmodifiable(candidates),
        createdAt = createdAt ?? DateTime.now();

  final ClarificationEntityType entityType;
  final ClarificationReason reason;
  final List<ClarificationCandidate> candidates;
  final AssistantIntent? originalIntent;
  final String? originalQuery;

  /// الإجراء الذي يُستأنف بعد حل الغموض (call/whatsapp/…).
  final AssistantIntent? pendingAction;
  final DateTime createdAt;

  bool get isMultiOption => candidates.length >= 2;
  bool get isYesNoConfirmation => candidates.length == 1;

  List<SmartSearchResult> get doctorResults => candidates
      .map((c) => c.asDoctorResult)
      .whereType<SmartSearchResult>()
      .toList(growable: false);

  List<SmartSearchResult> get labResults => candidates
      .map((c) => c.asLabResult)
      .whereType<SmartSearchResult>()
      .toList(growable: false);

  List<SmartSearchResult> get analysisResults => candidates
      .map((c) => c.asAnalysisResult)
      .whereType<SmartSearchResult>()
      .toList(growable: false);

  List<SmartSearchResult> get packageResults => candidates
      .map((c) => c.asPackageResult)
      .whereType<SmartSearchResult>()
      .toList(growable: false);

  List<SmartSearchResult> get radiologyResults => candidates
      .map((c) => c.asRadiologyResult)
      .whereType<SmartSearchResult>()
      .toList(growable: false);

  List<SmartSearchResult> get pharmacyResults => candidates
      .map((c) => c.asPharmacyResult)
      .whereType<SmartSearchResult>()
      .toList(growable: false);

  List<SmartSearchResult> get physioResults => candidates
      .map((c) => c.asPhysioResult)
      .whereType<SmartSearchResult>()
      .toList(growable: false);

  List<SmartSearchResult> get supplyResults => candidates
      .map((c) => c.asSupplyResult)
      .whereType<SmartSearchResult>()
      .toList(growable: false);
}

/// اقتراح تصحيح اسم طبيب معلّق — «هل تقصد د. …؟» بمرشّح واحد واثق.
///
/// دلالياً منفصل عن [PendingClarification]: لا قائمة مرشّحين، لا ترتيب
/// («الأول/الثاني»)، ولا `pendingAction` قابل للتنفيذ. «نعم» عليه تعني
/// اختيار الطبيب فقط — لا تفتح اتصالاً ولا واتساب أبداً.
class PendingDoctorSuggestion {
  const PendingDoctorSuggestion({
    required this.doctorId,
    required this.doctorName,
  });

  /// المعرّف المستقر للطبيب — مصدر الحقيقة عند التأكيد (لا نص العرض).
  final String doctorId;

  /// الاسم المخزَّن كما ورد من فهرس الأطباء الحقيقيين.
  final String doctorName;
}

/// اقتراح كيان معلّق عام (فيزيو/صيدلية/…) — نفس دلالة PendingDoctorSuggestion.
class PendingEntitySuggestion {
  const PendingEntitySuggestion({
    required this.entityType,
    required this.entityId,
    required this.entityName,
  });

  final ClarificationEntityType entityType;
  final String entityId;
  final String entityName;
}

/// نتيجة محاولة الإجابة على توضيح معلّق.
enum ClarificationResolveStatus {
  /// حُلّ مرشّح واحد بثقة.
  resolved,

  /// ما زال غامضاً — الإبقاء على التوضيح.
  stillAmbiguous,

  /// ترتيب خارج النطاق — الإبقاء على التوضيح.
  invalidOrdinal,

  /// «نعم»/«لا» غير آمن في سؤال متعدد — الإبقاء.
  unsafeYesNo,

  /// العبارة ليست جواباً على التوضيح (قد تكون بحثاً جديداً).
  notAnAnswer,
}

class ClarificationResolveResult {
  const ClarificationResolveResult({
    required this.status,
    this.candidate,
    this.message = '',
  });

  final ClarificationResolveStatus status;
  final ClarificationCandidate? candidate;
  final String message;

  bool get isResolved =>
      status == ClarificationResolveStatus.resolved && candidate != null;

  static const notAnAnswer = ClarificationResolveResult(
    status: ClarificationResolveStatus.notAnAnswer,
  );
}
