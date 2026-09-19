import 'conversation_conduct_models.dart';

/// صياغة حدود حوار قصيرة — عراقية مهذبة بلا محاضرة.
class ConversationEthicsResponseBuilder {
  const ConversationEthicsResponseBuilder();

  static const gentle =
      'أنا موجود حتى أساعدك، خلّينا نكمل الحوار بأسلوب محترم. شنو أگدر أساعدك؟';

  static const repeated =
      'أگدر أكمل وياك وأساعدك، لكن خلّينا نحافظ على أسلوب محترم بالحوار.';

  static const severe =
      'راح أبقى أساعدك بالمطلوب، لكن بدون إساءة بالحوار.';

  String? build(ConversationEthicsResponseCode code) {
    switch (code) {
      case ConversationEthicsResponseCode.none:
        return null;
      case ConversationEthicsResponseCode.gentleBoundary:
        return gentle;
      case ConversationEthicsResponseCode.repeatedBoundary:
        return repeated;
      case ConversationEthicsResponseCode.severeBoundary:
        return severe;
    }
  }

  ConversationEthicsResponseCode codeFor({
    required ConversationConductLevel level,
    required int recentAbuseCount,
  }) {
    if (level == ConversationConductLevel.severeAbuse) {
      return ConversationEthicsResponseCode.severeBoundary;
    }
    if (recentAbuseCount >= 2) {
      return ConversationEthicsResponseCode.repeatedBoundary;
    }
    if (level == ConversationConductLevel.abusive ||
        level == ConversationConductLevel.rude) {
      return ConversationEthicsResponseCode.gentleBoundary;
    }
    return ConversationEthicsResponseCode.none;
  }

  /// حارس لغة ردود غدير — يمنع الإساءة/السخرية في النصوص المولَّدة هنا.
  bool violatesOwnLanguagePolicy(String reply) {
    final t = reply.trim();
    if (t.isEmpty) return false;
    final bad = RegExp(
      r'(?:غبي|احمق|أحمق|حمار|كلب|تافه|حقير|يا\s*غبي|'
      r'اخرس|اسكت\s*يا|من\s*انت|ما\s*تفهم|'
      r'هها+|هههه\s*غبي)',
    );
    return bad.hasMatch(t);
  }
}
