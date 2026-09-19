import '../sensitive_profile/sensitive_health_profile_models.dart';

/// موافقة معلّقة لتذكّر صحة شخص عائلة — RAM فقط.
class FamilyHealthMemoryConsentPending {
  const FamilyHealthMemoryConsentPending({
    this.candidates = const [],
    this.persistentPersonId,
    this.displayLabel = '',
    this.awaitingAnswer = false,
  });

  final List<HealthConditionCandidate> candidates;
  final String? persistentPersonId;
  final String displayLabel;
  final bool awaitingAnswer;

  static const none = FamilyHealthMemoryConsentPending();

  bool get isActive =>
      awaitingAnswer &&
      candidates.isNotEmpty &&
      persistentPersonId != null &&
      persistentPersonId!.isNotEmpty;

  Map<String, Object?> debugMap() => {
        'consentState': awaitingAnswer
            ? HealthConsentState.pending.name
            : HealthConsentState.none.name,
        'eligibleConditionCount': candidates.length,
        'hasPersistentPersonBinding': persistentPersonId != null,
        // بلا أسماء / personId.
      };
}

/// منسّق موافقة صحة العائلة — صريح ومحايد للأطفال.
class FamilyHealthConsentCoordinator {
  const FamilyHealthConsentCoordinator();

  static const whyExplanation =
      'حتى ما تحتاج تكرر الحالات المشخّصة المهمة عن هذا الشخص، '
      'وحتى تكون المحادثات الصحية القادمة أوضح — فقط إذا وافقت. '
      'المعلومة تُحفظ محلياً ومرتبطة بملف الشخص، مو بملفك الصحي الشخصي.';

  String buildConsentPrompt({
    required List<HealthConditionCandidate> candidates,
    required String personLabel,
    bool isChild = false,
  }) {
    if (candidates.isEmpty) return '';
    final label = personLabel.trim().isEmpty ? 'هذا الشخص' : personLabel.trim();

    if (candidates.length == 1) {
      final c = candidates.first;
      final status = c.diagnosisStatus == HealthDiagnosisStatus.diagnosed
          ? 'مشخّص'
          : 'ثابت حسب ما ذكرت';
      if (isChild) {
        return 'إذا تريد الغدير يتذكر أن $label $status بـ${c.displayName} '
            'حتى يراعي هذه المعلومة بالمحادثات الصحية المستقبلية. تريد أحفظها؟';
      }
      return 'أنت طلبت من الغدير يتذكر أن $label $status بـ${c.displayName} '
          'حتى يراعي هذه المعلومة بالمحادثات الصحية المستقبلية. تريد أحفظها؟';
    }

    final names = candidates.map((c) => c.displayName).join(' و');
    if (isChild) {
      return 'إذا تريد الغدير يتذكر أن $label مشخص بـ$names '
          'حتى يراعي هذه المعلومات بالمحادثات الصحية المستقبلية. تريد أحفظها؟';
    }
    return 'أنت طلبت من الغدير يتذكر أن $label مشخص بـ$names '
        'حتى يراعي هذه المعلومات بالمحادثات الصحية المستقبلية. تريد أحفظها؟';
  }

  String mixedClarifyPrompt({
    required List<HealthConditionCandidate> eligible,
    required String personLabel,
  }) {
    final label = personLabel.trim().isEmpty ? 'هذا الشخص' : personLabel.trim();
    final names = eligible.map((c) => c.displayName).join(' و');
    return 'بعض ما ذكرت مو واضح كتشخيص ثابت. '
        'اللي أقدر أحفظه عن $label بعد موافقتك: $names فقط. '
        'ما أحفظ الشك أو الملاحظات غير المشخّصة. تريد أحفظ هالجزء المؤهّل؟';
  }

  FamilyHealthMemoryConsentPending begin({
    required List<HealthConditionCandidate> candidates,
    required String persistentPersonId,
    required String displayLabel,
  }) {
    final eligible =
        candidates.where((c) => c.isEligibleForPersistence).toList();
    if (eligible.isEmpty || persistentPersonId.isEmpty) {
      return FamilyHealthMemoryConsentPending.none;
    }
    return FamilyHealthMemoryConsentPending(
      candidates: List.unmodifiable(eligible),
      persistentPersonId: persistentPersonId,
      displayLabel: displayLabel,
      awaitingAnswer: true,
    );
  }

  FamilyHealthMemoryConsentPending keepPending(
    FamilyHealthMemoryConsentPending current,
  ) =>
      current;

  FamilyHealthMemoryConsentPending clear() =>
      FamilyHealthMemoryConsentPending.none;
}
