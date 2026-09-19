import '../search/smart_search_models.dart';
import 'conversation_context.dart';
import 'result_context.dart';

/// Phase 3D STEP 4 — short structured follow-up over existing session state.
///
/// This is **not** a second memory store and not chatbot/AI memory.
/// Authoritative selectable results remain [ConversationContext.currentResultContext]
/// ([ResultContext]). Selected actionable targets remain the typed selected
/// entities on [ConversationContext].
///
/// Responsibilities (separate from [GhadeerSocialContext] and clinical state):
/// - read latest selectable result set
/// - clarify ordinal / pronoun ambiguity deterministically
class GhadeerFollowUpContext {
  const GhadeerFollowUpContext(this.conversation);

  final ConversationContext conversation;

  ResultContext? get resultContext => conversation.currentResultContext;

  bool get hasSelectableResults {
    final ctx = resultContext;
    return ctx != null &&
        ctx.isNotEmpty &&
        ctx.entityType != ConversationEntityType.none;
  }

  ConversationEntityType? get lastResultType => resultContext?.entityType;

  List<SmartSearchResult> get recentResults =>
      resultContext?.items ?? const [];

  SmartSearchResult? get selectedTarget => conversation.selectedEntity;

  ConversationEntityType get selectedTargetType =>
      conversation.activeEntityType;

  /// Definite ordinal label: الأول / الثاني / الثالث…
  static String ordinalDefinite(int oneBased) {
    return switch (oneBased) {
      1 => 'الأول',
      2 => 'الثاني',
      3 => 'الثالث',
      4 => 'الرابع',
      5 => 'الخامس',
      _ => 'رقم $oneBased',
    };
  }

  /// Bare ordinal for clarification: أول / ثاني / ثالث…
  static String ordinalBare(int oneBased) {
    return switch (oneBased) {
      1 => 'أول',
      2 => 'ثاني',
      3 => 'ثالث',
      4 => 'رابع',
      5 => 'خامس',
      _ => '$oneBased',
    };
  }

  /// No recent selectable result set.
  static String noSelectableResultsMessage({int? requestedOrdinal}) {
    if (requestedOrdinal != null &&
        requestedOrdinal >= 1 &&
        requestedOrdinal != -1) {
      return 'تقصد ${ordinalDefinite(requestedOrdinal)} من أي نتائج؟';
    }
    return 'تقصد أي نتائج؟';
  }

  /// Out-of-range ordinal against a known recent result count.
  static String outOfRangeMessage({
    required int requestedOrdinal,
    required int availableCount,
  }) {
    if (availableCount <= 0) {
      return noSelectableResultsMessage(requestedOrdinal: requestedOrdinal);
    }
    if (requestedOrdinal == -1) {
      return 'النتائج الحالية ما بيها خيار أخير إضافي.';
    }
    if (requestedOrdinal < 1) {
      return noSelectableResultsMessage(requestedOrdinal: requestedOrdinal);
    }
    return 'النتائج الحالية ما بيها خيار ${ordinalBare(requestedOrdinal)}.';
  }

  /// Pronoun / short action without an unambiguous selected target.
  static String noPronounTargetMessage({
    ConversationEntityType type = ConversationEntityType.doctor,
  }) {
    return switch (type) {
      ConversationEntityType.laboratory => 'تقصد أي مختبر؟',
      ConversationEntityType.package => 'تقصد أي باقة؟',
      ConversationEntityType.analysis => 'تقصد أي تحليل؟',
      ConversationEntityType.doctor || ConversationEntityType.none =>
        'تقصد أي طبيب؟',
    };
  }

  /// Existing booking policy: never auto-book; keep selected target explicit.
  static String bookingNotAutomaticMessage(SmartSearchResult doctor) {
    final name = doctor.title.trim();
    if (name.isEmpty) {
      return 'ما أحجز موعداً تلقائياً من هنا. أكدر أدلّك على الاتصال أو واتساب إن تحب.';
    }
    return 'ما أحجز موعداً تلقائياً من هنا لـ $name. أكدر أدلّك على الاتصال أو واتساب إن تحب.';
  }
}
