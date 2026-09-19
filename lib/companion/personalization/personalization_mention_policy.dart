import 'personalization_models.dart';

/// متى يُذكر التخصيص صراحةً مقابل التأثير الصامت.
class PersonalizationMentionPolicy {
  const PersonalizationMentionPolicy();

  PersonalizationMentionMode decide({
    required PersonalizationPurpose purpose,
    required List<PersonalizationCandidate> selected,
    required PersonalizationSessionState session,
    required bool userAskedExplicitly,
  }) {
    if (selected.isEmpty) return PersonalizationMentionMode.none;

    if (purpose == PersonalizationPurpose.explicitMemoryQuery ||
        userAskedExplicitly) {
      return PersonalizationMentionMode.explicit;
    }

    // تفضيلات → ضمني دائماً
    final onlyPrefs = selected.every(
      (c) => c.category == 'preference' || c.influenceOnly,
    );
    if (onlyPrefs) return PersonalizationMentionMode.implicit;

    // تكرار ذكر صريح حديث → ضمني أو لا شيء
    final recent = session.recentExplicitMentions.toSet();
    final overlap = selected.any((c) => recent.contains(c.opaqueKey));
    if (overlap) return PersonalizationMentionMode.implicit;

    // أهداف/اهتمامات في دعم التعلم/المحتوى → ضمني افتراضياً
    if (purpose == PersonalizationPurpose.learningSupport ||
        purpose == PersonalizationPurpose.contentSupport ||
        purpose == PersonalizationPurpose.goalSupport ||
        purpose == PersonalizationPurpose.conversationContinuity) {
      return PersonalizationMentionMode.implicit;
    }

    if (purpose == PersonalizationPurpose.followUpContinuation) {
      return PersonalizationMentionMode.explicit;
    }

    return PersonalizationMentionMode.none;
  }

  /// هل يُسمح بذكر الاسم المفضّل هذه الدورة؟
  bool mayUsePreferredName(PersonalizationSessionState session) {
    return session.turnsSinceNameUsed >= 3;
  }
}
