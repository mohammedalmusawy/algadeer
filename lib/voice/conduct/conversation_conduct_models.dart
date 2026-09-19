/// نماذج أخلاقيات الحوار — بلا نص خام مسيء في التخزين/التصحيح.
enum ConversationConductLevel {
  normal,
  rude,
  abusive,
  severeAbuse,
}

enum ConversationConductTarget {
  assistant,
  thirdParty,
  quotedSpeech,
  unknown,
}

enum ConversationConductCategory {
  none,
  frustration,
  criticism,
  profanity,
  directInsult,
  sexualVulgarity,
  degrading,
  threateningTone,
}

enum ConversationEthicsResponseCode {
  none,
  gentleBoundary,
  repeatedBoundary,
  severeBoundary,
}

/// نتيجة كشف سلوك الحوار لدور واحد — بلا نص مسيء خام.
class ConversationConductResult {
  const ConversationConductResult({
    required this.level,
    required this.target,
    this.matchedCategory = ConversationConductCategory.none,
    this.shouldRespond = false,
    this.responseCode = ConversationEthicsResponseCode.none,
    this.remainderQuery = '',
    this.matchedEntryIds = const [],
  });

  final ConversationConductLevel level;
  final ConversationConductTarget target;
  final ConversationConductCategory matchedCategory;
  final bool shouldRespond;
  final ConversationEthicsResponseCode responseCode;

  /// نص مفيد متبقٍ بعد إزالة الإساءة الموجّهة للمساعد (إن وُجدت).
  final String remainderQuery;

  /// معرّفات إدخالات الكتالوج فقط — ليست العبارات الخام.
  final List<String> matchedEntryIds;

  static const normal = ConversationConductResult(
    level: ConversationConductLevel.normal,
    target: ConversationConductTarget.unknown,
  );

  bool get isAbuse =>
      level == ConversationConductLevel.abusive ||
      level == ConversationConductLevel.severeAbuse ||
      level == ConversationConductLevel.rude;

  bool get isQuotedOrThirdParty =>
      target == ConversationConductTarget.quotedSpeech ||
      target == ConversationConductTarget.thirdParty;

  Map<String, Object?> debugMap() => {
        'conductLevel': level.name,
        'conductTarget': target.name,
        'conductCategory': matchedCategory.name,
        'conductShouldRespond': shouldRespond,
        'conductResponseCode': responseCode.name,
        'conductMatchedEntryIds': matchedEntryIds,
        // عمداً: لا remainder إن احتوى إساءة — نكتفي بوجوده كطول
        'conductHasRemainder': remainderQuery.trim().isNotEmpty,
      };
}

/// حالة سلوك جلسة فقط — بلا Persistence.
class ConversationConductSessionState {
  const ConversationConductSessionState({
    this.recentAbuseCount = 0,
    this.lastConductLevel = ConversationConductLevel.normal,
    this.lastConductResponseTurnId,
    this.normalTurnsSinceAbuse = 0,
    this.lastResponseCode = ConversationEthicsResponseCode.none,
  });

  final int recentAbuseCount;
  final ConversationConductLevel lastConductLevel;
  final int? lastConductResponseTurnId;
  final int normalTurnsSinceAbuse;
  final ConversationEthicsResponseCode lastResponseCode;

  static const empty = ConversationConductSessionState();

  ConversationConductSessionState copyWith({
    int? recentAbuseCount,
    ConversationConductLevel? lastConductLevel,
    int? lastConductResponseTurnId,
    int? normalTurnsSinceAbuse,
    ConversationEthicsResponseCode? lastResponseCode,
    bool clearLastResponseTurn = false,
  }) {
    return ConversationConductSessionState(
      recentAbuseCount: recentAbuseCount ?? this.recentAbuseCount,
      lastConductLevel: lastConductLevel ?? this.lastConductLevel,
      lastConductResponseTurnId: clearLastResponseTurn
          ? null
          : (lastConductResponseTurnId ?? this.lastConductResponseTurnId),
      normalTurnsSinceAbuse:
          normalTurnsSinceAbuse ?? this.normalTurnsSinceAbuse,
      lastResponseCode: lastResponseCode ?? this.lastResponseCode,
    );
  }

  Map<String, Object?> debugMap() => {
        'recentAbuseCount': recentAbuseCount,
        'lastConductLevel': lastConductLevel.name,
        'lastConductResponseTurnId': lastConductResponseTurnId,
        'normalTurnsSinceAbuse': normalTurnsSinceAbuse,
        'lastConductResponseCode': lastResponseCode.name,
      };
}

/// إدخال كتالوج — عبارة مسيئة مُصنَّفة (ليست blacklist فقط).
class ConductCatalogEntry {
  const ConductCatalogEntry({
    required this.id,
    required this.category,
    required this.level,
    required this.patterns,
    this.enabled = true,
    this.requiresSecondPersonCue = true,
  });

  final String id;
  final ConversationConductCategory category;
  final ConversationConductLevel level;
  final List<String> patterns;
  final bool enabled;

  /// إن true: لا تُحتسب إساءة للمساعد إلا مع مؤشر موجّه (أنت/يا/…).
  final bool requiresSecondPersonCue;
}
