import '../../search/arabic_text_utils.dart';
import '../clarification/clarification_resolver.dart';
import '../intent/assistant_intent.dart';
import '../intent/intent_result.dart';
import 'arabic_answer_normalizer.dart';

enum GuidedTopicChangeKind {
  none,
  cancelOnly,
  topicChanged,
}

class GuidedTopicChangeResult {
  const GuidedTopicChangeResult({
    required this.kind,
    this.forwardQuery,
  });

  final GuidedTopicChangeKind kind;
  final String? forwardQuery;

  static const none = GuidedTopicChangeResult(kind: GuidedTopicChangeKind.none);
}

/// كاشف تغيير موضوع حتمي ومحافظ — بدون LLM.
///
/// مهم: نيات قصيرة مثل «إي» قد تُصنَّف خطأً كـ doctorSearch —
/// لذلك نهروب فقط عند أدلة نصية صريحة أو نية فعل واضحة.
class GuidedTopicChangeDetector {
  const GuidedTopicChangeDetector();

  GuidedTopicChangeResult detect({
    required String query,
    IntentResult? intentResult,
  }) {
    final original = query.trim();
    if (original.isEmpty) return GuidedTopicChangeResult.none;

    final n = ArabicTextUtils.normalize(original)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final stripped = _stripCancelLeadIn(n);
    final hasCancelLeadIn = stripped != n;
    final remaining = stripped.trim();
    final forwardOriginal = hasCancelLeadIn
        ? _stripCancelLeadInOriginal(original)
        : original;

    // إلغاء صريح بدون أمر تطبيق متبقٍ.
    if (ArabicAnswerNormalizer.isCancelCommand(original)) {
      if (remaining.isEmpty ||
          !_looksLikeStrongAppCommand(remaining, intentResult)) {
        // «خلاص» / «الغاء» / «خلينا من هذا» وحدها.
        if (!hasCancelLeadIn || remaining.isEmpty) {
          return const GuidedTopicChangeResult(
            kind: GuidedTopicChangeKind.cancelOnly,
          );
        }
      }
    }

    final commandText = remaining.isNotEmpty ? remaining : n;
    if (_looksLikeStrongAppCommand(commandText, intentResult)) {
      return GuidedTopicChangeResult(
        kind: GuidedTopicChangeKind.topicChanged,
        forwardQuery: forwardOriginal.trim().isEmpty
            ? original
            : forwardOriginal.trim(),
      );
    }

    // isClearNewSearchIntent وحده لا يكفي لكلمة «مختبر» العارية —
    // يتطلب فعل بحث صريح أو اسماً مركّباً.
    if (intentResult != null &&
        ClarificationResolver.isClearNewSearchIntent(
          intentResult,
          commandText,
        ) &&
        _hasExplicitSearchCue(commandText)) {
      return GuidedTopicChangeResult(
        kind: GuidedTopicChangeKind.topicChanged,
        forwardQuery: forwardOriginal.trim().isEmpty
            ? original
            : forwardOriginal.trim(),
      );
    }

    if (hasCancelLeadIn && remaining.isEmpty) {
      return const GuidedTopicChangeResult(
        kind: GuidedTopicChangeKind.cancelOnly,
      );
    }

    return GuidedTopicChangeResult.none;
  }

  bool _hasExplicitSearchCue(String n) {
    if (RegExp(r'(?:أريد|اريد|ابي|ابحث|دور|افتح|اتصل|دز)').hasMatch(n)) {
      return true;
    }
    // «مختبر الحياة» اسم مركّب — ليس خيار اختيار عاري.
    return n.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= 2;
  }

  bool _looksLikeStrongAppCommand(String n, IntentResult? intent) {
    if (n.trim().isEmpty) return false;

    // أدلة نصية صريحة أولاً — لا تعتمد على تصنيف نية هش لإجابات قصيرة.
    if (RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور).{0,20}(?:طبيب|دكتور|طبيبه|طبيبة|اختصاص)',
        ).hasMatch(n) ||
        RegExp(
          r'(?:أريد|اريد|ابي|ابحث).{0,20}(?:مختبر|مختبرات)',
        ).hasMatch(n) ||
        RegExp(
          r'(?:أريد|اريد|ابي|ابحث).{0,20}(?:تحليل|تحاليل)',
        ).hasMatch(n) ||
        RegExp(
          r'(?:أريد|اريد|ابي|ابحث).{0,20}(?:باقه|باقة|باقات|عرض|عروض)',
        ).hasMatch(n) ||
        RegExp(
          r'(?:اتصل|دز|دزله|واتساب|whatsapp).{0,24}(?:دكتور|طبيب|مختبر)',
        ).hasMatch(n) ||
        RegExp(r'(?:افتح\s*واتساب)').hasMatch(n)) {
      return true;
    }

    if (intent == null) return false;

    switch (intent.intent) {
      case AssistantIntent.specialtySearch:
        return n.length >= 4;
      case AssistantIntent.findLab:
      case AssistantIntent.findAnalysis:
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
        return ClarificationResolver.isClearNewSearchIntent(intent, n) &&
            _hasExplicitSearchCue(n);
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.showLocation:
      case AssistantIntent.showProfile:
        return true;
      case AssistantIntent.doctorSearch:
        // لا نهرب بإجابة قصيرة صُنِّفت خطأً كبحث طبيب.
        return RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور).{0,16}(?:طبيب|دكتور)|(?:^|\s)(?:ال)?(?:دكتور|طبيب)\s+\S{2,}',
        ).hasMatch(n);
      default:
        return false;
    }
  }

  String _stripCancelLeadIn(String n) {
    var s = n
        .replaceFirst(
          RegExp(
            r'^(?:خلينا\s*(?:من\s*)?(?:هذا|هاي|الموضوع)|اترك\s*(?:الموضوع|هذا|هاي)|خلاص|الغاء|إلغاء)\s*[,،.]?\s*',
          ),
          '',
        )
        .trim();
    // «لا، أريد تحليل/مختبر…» أثناء تأكيد — تغيير موضوع وليس رفضاً فقط.
    final noLead = s.replaceFirst(RegExp(r'^لا\s*[,،.]?\s*'), '').trim();
    if (noLead.isNotEmpty &&
        noLead != s &&
        _looksLikeStrongAppCommand(noLead, null)) {
      return noLead;
    }
    return s;
  }

  String _stripCancelLeadInOriginal(String original) {
    final n = ArabicTextUtils.normalize(original);
    final stripped = _stripCancelLeadIn(n);
    if (stripped == n.trim()) return original.trim();
    final want =
        RegExp(r'(أريد|اريد|ابي|ابحث|دور|اتصل|دز)').firstMatch(original);
    if (want != null) {
      return original.substring(want.start).trim();
    }
    return stripped;
  }
}
