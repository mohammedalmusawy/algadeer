import 'personalization_models.dart';

/// حداثة وتكرار — جلسة فقط.
class PersonalizationRecencyPolicy {
  const PersonalizationRecencyPolicy({
    this.staleAfterDays = 180,
  });

  final int staleAfterDays;

  PersonalizationFreshnessState freshnessFor({
    DateTime? updatedAt,
    DateTime? lastConfirmedAt,
    DateTime? now,
  }) {
    final ref = lastConfirmedAt ?? updatedAt;
    if (ref == null) return PersonalizationFreshnessState.unknownFreshness;
    final age = (now ?? DateTime.now()).difference(ref).inDays;
    if (age > staleAfterDays) {
      return PersonalizationFreshnessState.possiblyStale;
    }
    return PersonalizationFreshnessState.fresh;
  }

  bool shouldClarifyStaleHighImpact({
    required PersonalizationFreshnessState freshness,
    required PersonalizationPurpose purpose,
    required bool sensitive,
  }) {
    if (freshness != PersonalizationFreshnessState.possiblyStale) return false;
    if (!sensitive && purpose != PersonalizationPurpose.healthGuidance) {
      return false;
    }
    return purpose == PersonalizationPurpose.healthGuidance ||
        purpose == PersonalizationPurpose.chronicCare ||
        purpose == PersonalizationPurpose.preventiveGuidance;
  }

  PersonalizationSessionState recordUse({
    required PersonalizationSessionState session,
    required PersonalizationEnvelope envelope,
    required bool usedName,
  }) {
    final keys = [
      ...envelope.selectedCandidates.map((c) => c.opaqueKey),
      ...session.recentlyUsedMemoryKeys,
    ];
    final uniqueKeys = <String>{};
    final trimmedKeys = <String>[];
    for (final k in keys) {
      if (uniqueKeys.add(k)) trimmedKeys.add(k);
      if (trimmedKeys.length >= 8) break;
    }

    var explicit = [...session.recentExplicitMentions];
    if (envelope.mentionMode == PersonalizationMentionMode.explicit) {
      explicit = [
        ...envelope.selectedCandidates.map((c) => c.opaqueKey),
        ...explicit,
      ];
      final seen = <String>{};
      explicit = [
        for (final k in explicit)
          if (seen.add(k)) k,
      ].take(6).toList();
    }

    return session.copyWith(
      recentlyUsedMemoryKeys: trimmedKeys,
      recentExplicitMentions: explicit,
      lastPersonalizationPurpose: envelope.purpose,
      turnsSinceNameUsed: usedName ? 0 : session.turnsSinceNameUsed + 1,
      lastEnvelopeDebug: envelope.debugMap(),
    );
  }
}
