import 'personal_memory_models.dart';

class PersonalMemoryConsentPending {
  const PersonalMemoryConsentPending({
    this.candidate,
    this.awaitingAnswer = false,
  });

  final PersonalMemoryCandidate? candidate;
  final bool awaitingAnswer;

  static const none = PersonalMemoryConsentPending();

  bool get isActive => awaitingAnswer && candidate != null;

  Map<String, Object?> debugMap() => {
        'consentState': awaitingAnswer
            ? PersonalMemoryConsentState.pending.name
            : PersonalMemoryConsentState.none.name,
        'memoryType': candidate?.memoryType.name,
      };
}

class PersonalMemoryConsentCoordinator {
  const PersonalMemoryConsentCoordinator();

  String buildConfirmPrompt(PersonalMemoryCandidate c) {
    switch (c.memoryType) {
      case PersonalMemoryType.goal:
        return 'تحب أحفظ هدف «${c.displayLabel}» بذاكرتك الشخصية؟';
      case PersonalMemoryType.interest:
        return 'تحب أحفظ اهتمامك بـ«${c.displayLabel}»؟';
      case PersonalMemoryType.preference:
        return 'تحب أحفظ تفضيلك: ${c.displayLabel}؟';
    }
  }
}
