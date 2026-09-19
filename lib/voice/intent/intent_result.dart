import 'assistant_intent.dart';
import 'extracted_entities.dart';

/// مصدر تصنيف النية — يسمح لاحقاً بـ AIIntentResolver بنفس العقد.
enum IntentSource {
  rules,
  context,
  legacy,
}

/// نتيجة تحليل نية — لا تنفّذ إجراءات؛ للتصنيف والتخطيط فقط.
class IntentResult {
  const IntentResult({
    required this.intent,
    required this.originalText,
    required this.normalizedText,
    this.searchMeaning = '',
    this.entities = ExtractedEntities.empty,
    this.confidence = 0,
    this.requiresContext = false,
    this.requiresClarification = false,
    this.source = IntentSource.rules,
  });

  final AssistantIntent intent;
  final String originalText;
  final String normalizedText;

  /// تمثيل معنى البحث بعد aliases خفيفة (للمقارنة فقط).
  final String searchMeaning;
  final ExtractedEntities entities;
  final int confidence;

  /// الهدف يعتمد على ConversationContext (بيه / عيادته / ملفه…).
  final bool requiresContext;

  /// يحتاج توضيحاً لاحقاً (عدة مرشّحين) — لا تنفيذ مباشر.
  final bool requiresClarification;

  final IntentSource source;

  bool get isActionIntent =>
      intent == AssistantIntent.callDoctor ||
      intent == AssistantIntent.messageDoctor ||
      intent == AssistantIntent.callLab ||
      intent == AssistantIntent.messageLab ||
      intent == AssistantIntent.showLocation ||
      intent == AssistantIntent.showProfile ||
      intent == AssistantIntent.findPackage ||
      intent == AssistantIntent.findAnalysis ||
      intent == AssistantIntent.selectResult;

  static IntentResult unknown(String original, String normalized) {
    return IntentResult(
      intent: AssistantIntent.unknown,
      originalText: original,
      normalizedText: normalized,
      searchMeaning: normalized,
      confidence: 0,
    );
  }
}
