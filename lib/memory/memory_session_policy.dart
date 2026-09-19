import 'memory_category.dart';

/// سياسة: ما يبقى جلسة فقط وما يُمنع من التسلسل الدائم.
///
/// PC-0.4 invariant:
/// Persistent Personal Companion must NOT serialize ConversationContext wholesale.
class MemorySessionOnlyPolicy {
  const MemorySessionOnlyPolicy();

  /// مفاتيح مفاهيمية لحالة المحادثة — جلسة فقط.
  static const sessionOnlyKeys = <String>{
    'ConversationContext',
    'ResultContext',
    'recentReferences',
    'pendingClarification',
    'pendingAction',
    'GuidedConversationState',
    'rawGuidedAnswers',
    'HealthGuidanceSession',
    'symptoms',
    'duration',
    'severity',
    'onset',
    'safetyEvaluation',
    'ConductState',
    'healthHandoff',
    'HealthSubjectContext',
    'temporaryOtherPersonFacts',
    'sessionMemoryCandidates',
  };

  bool isSessionOnlyKey(String key) => sessionOnlyKeys.contains(key);

  bool isSessionOnlyCategory(MemoryCategory category) =>
      category == MemoryCategory.sessionConversation;

  /// أي محاولة لتسلسل ConversationContext كذاكرة دائمة مرفوضة معمارياً.
  bool maySerializeConversationContextAsMemory() => false;

  /// ConductState لا يصبح سمعة مستخدم طويلة الأمد.
  bool mayPersistConductAsReputation() => false;

  /// أعراض الجلسة لا تُحوَّل تلقائياً إلى ملف صحي دائم.
  bool mayAutoPersistSymptomConversation() => false;
}

/// علامة معمارية على حالة جلسة — تُستخدم في الاختبارات والحراسة.
mixin SessionOnlyStateMarker {
  /// يجب أن تبقى false دائماً لـ ConversationContext ومشتقاته.
  bool get allowsPersistentMemorySerialization => false;

  MemoryCategory get memoryCategory => MemoryCategory.sessionConversation;
}
