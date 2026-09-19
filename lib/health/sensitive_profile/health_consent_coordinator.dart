import 'sensitive_health_profile_models.dart';

/// حالة موافقة معلّقة لتذكّر حالات صحية.
class HealthMemoryConsentPending {
  const HealthMemoryConsentPending({
    this.candidates = const [],
    this.awaitingAnswer = false,
  });

  final List<HealthConditionCandidate> candidates;
  final bool awaitingAnswer;

  static const none = HealthMemoryConsentPending();

  bool get isActive => awaitingAnswer && candidates.isNotEmpty;

  Map<String, Object?> debugMap() => {
        'consentState': awaitingAnswer
            ? HealthConsentState.pending.name
            : HealthConsentState.none.name,
        'pendingCandidateCount': candidates.length,
        // بلا أسماء حالات.
      };
}

/// منسّق موافقة تذكّر الصحة — صريح ومحدود الغرض.
class HealthConsentCoordinator {
  const HealthConsentCoordinator();

  static const whyExplanation =
      'حتى ما تحتاج تكرر الحالات المشخّصة المهمة، وحتى تكون المحادثات الصحية القادمة أراعى لوضعك — فقط إذا وافقت.';

  String buildConsentPrompt(List<HealthConditionCandidate> candidates) {
    if (candidates.isEmpty) return '';
    if (candidates.length == 1) {
      final c = candidates.first;
      return 'فهمت منك أن عندك ${c.displayName} '
          '${c.diagnosisStatus == HealthDiagnosisStatus.diagnosed ? "مشخّص" : "ثابت حسب ما ذكرت"}.\n'
          'تحب الغدير يتذكر هالمعلومة حتى يراعيها بالمحادثات الصحية القادمة؟';
    }
    final names = candidates.map((c) => c.displayName).join(' و');
    return 'فهمت منك أن عندك $names مشخّصين.\n'
        'تحب الغدير يتذكر هالمعلومات حتى يراعيها بالمحادثات الصحية القادمة؟';
  }

  HealthMemoryConsentPending begin(List<HealthConditionCandidate> candidates) {
    final eligible =
        candidates.where((c) => c.isEligibleForPersistence).toList();
    if (eligible.isEmpty) return HealthMemoryConsentPending.none;
    return HealthMemoryConsentPending(
      candidates: List.unmodifiable(eligible),
      awaitingAnswer: true,
    );
  }

  /// بعد «ليش؟» نبقي الانتظار.
  HealthMemoryConsentPending keepPending(HealthMemoryConsentPending current) =>
      current;

  HealthMemoryConsentPending clear() => HealthMemoryConsentPending.none;
}
