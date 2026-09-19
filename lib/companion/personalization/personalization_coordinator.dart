import '../../follow_up/follow_up_due_policy.dart';
import '../../follow_up/follow_up_models.dart';
import '../../follow_up/follow_up_service.dart';
import '../../health/family_sensitive/family_sensitive_health_retrieval_policy.dart';
import '../../health/family_sensitive/family_sensitive_health_service.dart';
import '../../health/sensitive_profile/sensitive_health_retrieval_policy.dart';
import '../../health/sensitive_profile/sensitive_health_profile_service.dart';
import '../../search/arabic_text_utils.dart';
import '../personal_companion_profile.dart';
import '../personal_companion_profile_service.dart';
import '../personal_memory/personal_memory_models.dart';
import '../personal_memory/personal_memory_retrieval_policy.dart';
import '../personal_memory/personal_memory_service.dart';
import 'personalization_mention_policy.dart';
import 'personalization_models.dart';
import 'personalization_privacy_policy.dart';
import 'personalization_recency_policy.dart';
import 'personalization_relevance_policy.dart';

/// منسّق التخصيص السياقي — PC-1.13.
///
/// يطلب الحد الأدنى من المصادر السلطوية؛ لا يدمج ملفاً عملاقاً.
class PersonalizationCoordinator {
  PersonalizationCoordinator({
    PersonalCompanionProfileService? profiles,
    PersonalMemoryService? personalMemory,
    SensitiveHealthProfileService? health,
    FamilySensitiveHealthService? familyHealth,
    FollowUpService? followUps,
    PersonalizationRelevancePolicy? relevance,
    PersonalizationPrivacyPolicy? privacy,
    PersonalizationMentionPolicy? mention,
    PersonalizationRecencyPolicy? recency,
    PersonalizationBudgetPolicy? budget,
    PersonalMemoryRetrievalPolicy? memoryRetrieval,
    SensitiveHealthRetrievalPolicy? healthRetrieval,
    FamilySensitiveHealthRetrievalPolicy? familyHealthRetrieval,
  })  : _profiles = profiles ?? PersonalCompanionProfileService(),
        _personalMemory = personalMemory ?? PersonalMemoryService(),
        _health = health ?? SensitiveHealthProfileService(),
        _familyHealth = familyHealth ?? FamilySensitiveHealthService(),
        _followUps = followUps ?? FollowUpService(),
        _relevance = relevance ?? const PersonalizationRelevancePolicy(),
        _privacy = privacy ?? const PersonalizationPrivacyPolicy(),
        _mention = mention ?? const PersonalizationMentionPolicy(),
        _recency = recency ?? const PersonalizationRecencyPolicy(),
        _budget = budget ?? const PersonalizationBudgetPolicy(),
        _memoryRetrieval =
            memoryRetrieval ?? const PersonalMemoryRetrievalPolicy(),
        _healthRetrieval =
            healthRetrieval ?? const SensitiveHealthRetrievalPolicy(),
        _familyHealthRetrieval = familyHealthRetrieval ??
            const FamilySensitiveHealthRetrievalPolicy();

  final PersonalCompanionProfileService _profiles;
  final PersonalMemoryService _personalMemory;
  final SensitiveHealthProfileService _health;
  final FamilySensitiveHealthService _familyHealth;
  final FollowUpService _followUps;
  final PersonalizationRelevancePolicy _relevance;
  final PersonalizationPrivacyPolicy _privacy;
  final PersonalizationMentionPolicy _mention;
  final PersonalizationRecencyPolicy _recency;
  final PersonalizationBudgetPolicy _budget;
  final PersonalMemoryRetrievalPolicy _memoryRetrieval;
  final SensitiveHealthRetrievalPolicy _healthRetrieval;
  final FamilySensitiveHealthRetrievalPolicy _familyHealthRetrieval;

  PersonalizationRelevancePolicy get relevance => _relevance;
  PersonalizationPrivacyPolicy get privacy => _privacy;
  PersonalizationRecencyPolicy get recency => _recency;
  PersonalMemoryService get personalMemory => _personalMemory;
  PersonalCompanionProfileService get profiles => _profiles;

  Future<PersonalizationEnvelope> buildEnvelope(
    PersonalizationTurnInput input,
  ) async {
    try {
      return await _build(input);
    } catch (_) {
      return PersonalizationEnvelope(
        purpose: PersonalizationPurpose.none,
        subjectKind: input.subjectKind,
        decisionState: PersonalizationDecisionState.failedSafe,
      );
    }
  }

  Future<PersonalizationEnvelope> _build(PersonalizationTurnInput input) async {
    if (input.urgentSafety || input.mentalSafety) {
      return PersonalizationEnvelope(
        purpose: PersonalizationPurpose.none,
        subjectKind: input.subjectKind,
        decisionState: PersonalizationDecisionState.blockedByPrivacy,
      );
    }

    if (input.emotionalDistress &&
        RegExp(r'(?:لا\s*تتركني|ارجع\s*لي|اشتقت)').hasMatch(
          ArabicTextUtils.normalize(input.query),
        )) {
      // لا ضغط عبر دمج عاطفة + ذاكرة
      return PersonalizationEnvelope(
        purpose: PersonalizationPurpose.none,
        subjectKind: input.subjectKind,
        decisionState: PersonalizationDecisionState.blockedByPrivacy,
      );
    }

    final noPers = input.userRequestsNoPersonalization ||
        _relevance.requestsNoPersonalization(input.query);
    if (noPers) {
      return PersonalizationEnvelope(
        purpose: PersonalizationPurpose.disabledByUser,
        subjectKind: input.subjectKind,
        decisionState: PersonalizationDecisionState.disabledByUser,
      );
    }

    if (_relevance.looksLikeMemoryCorrection(input.query)) {
      return PersonalizationEnvelope(
        purpose: PersonalizationPurpose.goalSupport,
        subjectKind: input.subjectKind,
        decisionState: PersonalizationDecisionState.relevant,
        routeCorrectionToPersonalMemory: true,
      );
    }

    final purpose = _relevance.purposeForQuery(
      input.query,
      planKindName: input.planKindName,
      intentName: input.intentName,
    );

    if (purpose == PersonalizationPurpose.disabledByUser) {
      return PersonalizationEnvelope(
        purpose: purpose,
        subjectKind: input.subjectKind,
        decisionState: PersonalizationDecisionState.disabledByUser,
      );
    }

    if (_privacy.blocksSensitiveRetrieval(input.subjectKind) &&
        (purpose == PersonalizationPurpose.healthGuidance ||
            purpose == PersonalizationPurpose.chronicCare)) {
      return PersonalizationEnvelope(
        purpose: purpose,
        subjectKind: input.subjectKind,
        decisionState: PersonalizationDecisionState.needsClarification,
        clarificationHint: 'حدّد عن مَن نتكلم قبل استخدام معلومات حسّاسة.',
      );
    }

    final useMemoryRequest = input.userRequestsUseMemory ||
        _relevance.requestsUseMemory(input.query);

    final raw = <PersonalizationCandidate>[];

    // —— ملف أساسي (حد أدنى) ——
    if (_relevance.isSourceRelevant(
      source: PersonalizationSource.companionProfile,
      purpose: purpose,
    )) {
      raw.addAll(await _profileCandidates(purpose, input));
    }

    // —— ذاكرة شخصية (PC-1.12) ——
    if (_relevance.isSourceRelevant(
          source: PersonalizationSource.personalMemory,
          purpose: purpose,
        ) &&
        _privacy.mayUseOwnerPersonalMemory(input.subjectKind)) {
      raw.addAll(await _personalMemoryCandidates(purpose, input.query));
    }

    // —— صحة المالك —— لا تُتجاوز السياسة ——
    if (_relevance.isSourceRelevant(
          source: PersonalizationSource.sensitiveHealth,
          purpose: purpose,
        ) &&
        _privacy.mayUseOwnerHealth(input.subjectKind)) {
      raw.addAll(await _healthCandidates(purpose, input.query));
    }

    // —— صحة عائلة —— شخص دائم + صلة صحية ——
    final healthRelevant = purpose == PersonalizationPurpose.healthGuidance ||
        purpose == PersonalizationPurpose.chronicCare ||
        purpose == PersonalizationPurpose.preventiveGuidance;
    if (_privacy.mayUseFamilyHealth(
      subject: input.subjectKind,
      purpose: purpose,
      hasPersistentPerson: (input.persistentPersonId ?? '').isNotEmpty,
      healthRelevant: healthRelevant,
    )) {
      raw.addAll(
        await _familyHealthCandidates(
          purpose,
          input.query,
          input.persistentPersonId!,
        ),
      );
    }

    // —— متابعة —— DuePolicy فقط ——
    if (_relevance.isSourceRelevant(
      source: PersonalizationSource.followUp,
      purpose: purpose,
    )) {
      raw.addAll(await _followUpCandidates(input));
    }

    // تفضيل مؤقت للدورة
    String? turnOverride;
    if (_relevance.looksLikeTemporaryPreferenceOverride(input.query)) {
      turnOverride = 'brief';
    }

    final containsSensitive = raw.any((c) => c.sensitive);
    final budget = _budget.budgetFor(
      purpose: purpose,
      containsSensitive: containsSensitive,
    );
    var selected = _budget.applyBudget(candidates: raw, budget: budget);

    // طلب استخدام الذاكرة لا يتجاوز ميزانية الصحة الحساسة ولا الموافقة
    if (useMemoryRequest && selected.isEmpty && !containsSensitive) {
      // قد يوسّع قليلاً لأهداف/اهتمامات إن وُجدت ضمن الغرض
      selected = _budget.applyBudget(candidates: raw, budget: budget);
    }

    // حداثة عالية الأثر
    final staleHigh = selected.any(
      (c) => _recency.shouldClarifyStaleHighImpact(
        freshness: c.freshness,
        purpose: purpose,
        sensitive: c.sensitive,
      ),
    );
    if (staleHigh) {
      return PersonalizationEnvelope(
        purpose: purpose,
        subjectKind: input.subjectKind,
        decisionState: PersonalizationDecisionState.needsClarification,
        selectedCandidates: selected,
        budgetUsed: selected.length,
        containsSensitiveContext: containsSensitive,
        freshnessState: PersonalizationFreshnessState.possiblyStale,
        clarificationHint: 'هل المعلومة المحفوظة ما زالت صحيحة؟',
        turnPreferenceOverride: turnOverride,
      );
    }

    final mention = _mention.decide(
      purpose: purpose,
      selected: selected,
      session: input.session,
      userAskedExplicitly:
          purpose == PersonalizationPurpose.explicitMemoryQuery ||
              useMemoryRequest,
    );

    PersonalizationDecisionState state;
    if (selected.isEmpty) {
      state = PersonalizationDecisionState.notRelevant;
    } else if (containsSensitive) {
      state = PersonalizationDecisionState.relevantButSensitive;
    } else {
      state = PersonalizationDecisionState.relevant;
    }

    // توفر الذاكرة ≠ استخدامها: providerDiscovery يفرّغ حتى لو وُجدت أهداف
    if (purpose == PersonalizationPurpose.providerDiscovery) {
      selected = const [];
      state = PersonalizationDecisionState.notRelevant;
    }

    return PersonalizationEnvelope(
      purpose: purpose,
      subjectKind: input.subjectKind,
      decisionState: state,
      selectedCandidates: selected,
      mentionMode: selected.isEmpty ? PersonalizationMentionMode.none : mention,
      budgetUsed: selected.length,
      containsSensitiveContext: selected.any((c) => c.sensitive),
      freshnessState: selected.isEmpty
          ? PersonalizationFreshnessState.unknownFreshness
          : selected.first.freshness,
      turnPreferenceOverride: turnOverride,
    );
  }

  Future<List<PersonalizationCandidate>> _profileCandidates(
    PersonalizationPurpose purpose,
    PersonalizationTurnInput input,
  ) async {
    final out = <PersonalizationCandidate>[];
    try {
      final p = await _profiles.loadProfile();
      if (p == null || !p.profileEnabled) return out;

      if (_relevance.ageRelevant(purpose) && p.birthYear != null) {
        out.add(
          PersonalizationCandidate(
            opaqueKey: 'profile_age',
            source: PersonalizationSource.companionProfile,
            category: 'age',
            displaySafeLabel: 'عمر تقريبي',
            influenceOnly: true,
          ),
        );
      }

      if (_relevance.studentContextRelevant(purpose, input.query) &&
          p.userContext == ProfileUserContext.student) {
        out.add(
          const PersonalizationCandidate(
            opaqueKey: 'profile_student',
            source: PersonalizationSource.companionProfile,
            category: 'userContext',
            displaySafeLabel: 'طالب',
            influenceOnly: true,
          ),
        );
      }

      // الاسم: مرشّح فقط إن سياسة الذكر تسمح — المنسّق لا يفرضه كل دورة
      final name = p.preferredName?.trim();
      if (name != null &&
          name.isNotEmpty &&
          _mention.mayUsePreferredName(input.session) &&
          purpose != PersonalizationPurpose.providerDiscovery) {
        out.add(
          PersonalizationCandidate(
            opaqueKey: 'profile_name',
            source: PersonalizationSource.companionProfile,
            category: 'preferredName',
            displaySafeLabel: name,
            influenceOnly: false,
          ),
        );
      }
    } catch (_) {}
    return out;
  }

  Future<List<PersonalizationCandidate>> _personalMemoryCandidates(
    PersonalizationPurpose purpose,
    String query,
  ) async {
    final memPurpose = switch (purpose) {
      PersonalizationPurpose.learningSupport ||
      PersonalizationPurpose.goalSupport =>
        PersonalMemoryRetrievalPurpose.learningAdvice,
      PersonalizationPurpose.contentSupport =>
        PersonalMemoryRetrievalPurpose.contentCreationHelp,
      PersonalizationPurpose.explicitMemoryQuery =>
        PersonalMemoryRetrievalPurpose.showPersonalMemory,
      _ => PersonalMemoryRetrievalPurpose.generalChat,
    };

    // generalChat → سياسة الذاكرة تُرجع فارغ (توفر ≠ استخدام)
    try {
      final records = await _memoryRetrieval.retrieveRelevant(
        service: _personalMemory,
        purpose: memPurpose,
        queryHint: query,
      );
      return [
        for (final r in records)
          PersonalizationCandidate(
            opaqueKey: 'pm_${r.memoryType.name}_${r.canonicalKey.hashCode.abs()}',
            source: PersonalizationSource.personalMemory,
            category: r.memoryType == PersonalMemoryType.preference
                ? 'preference'
                : r.category,
            displaySafeLabel: r.displayLabel,
            freshness: _recency.freshnessFor(
              updatedAt: r.updatedAt,
              lastConfirmedAt: r.lastConfirmedAt,
            ),
            influenceOnly: r.memoryType == PersonalMemoryType.preference,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<PersonalizationCandidate>> _healthCandidates(
    PersonalizationPurpose purpose,
    String query,
  ) async {
    if (purpose != PersonalizationPurpose.healthGuidance &&
        purpose != PersonalizationPurpose.chronicCare &&
        purpose != PersonalizationPurpose.preventiveGuidance) {
      return const [];
    }
    final hp = _healthRetrieval.purposeForQuery(query);
    // لا تجاوز: generalChat / unrelated → فارغ
    try {
      final list = await _healthRetrieval.retrieveRelevant(
        service: _health,
        purpose: hp,
        queryHint: query,
      );
      return [
        for (final c in list)
          PersonalizationCandidate(
            opaqueKey: 'health_${c.canonicalConditionKey}',
            source: PersonalizationSource.sensitiveHealth,
            category: 'healthCondition',
            displaySafeLabel: 'سياق صحي محفوظ',
            sensitive: true,
            freshness: _recency.freshnessFor(updatedAt: c.updatedAt),
            influenceOnly: true,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<PersonalizationCandidate>> _familyHealthCandidates(
    PersonalizationPurpose purpose,
    String query,
    String personId,
  ) async {
    final fp = switch (purpose) {
      PersonalizationPurpose.healthGuidance =>
        FamilyHealthRetrievalPurpose.healthConversation,
      _ => FamilyHealthRetrievalPurpose.generalChat,
    };
    try {
      final list = await _familyHealthRetrieval.retrieveRelevant(
        service: _familyHealth,
        purpose: fp,
        activePersistentPersonId: personId,
        queryHint: query,
      );
      return [
        for (final c in list)
          PersonalizationCandidate(
            opaqueKey: 'fh_${c.canonicalConditionKey}',
            source: PersonalizationSource.familySensitiveHealth,
            category: 'familyHealth',
            displaySafeLabel: 'سياق صحي لشخص مرتبط',
            sensitive: true,
            influenceOnly: true,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<PersonalizationCandidate>> _followUpCandidates(
    PersonalizationTurnInput input,
  ) async {
    try {
      final subject = input.subjectKind ==
              PersonalizationSubjectKind.persistentFamilyPerson
          ? FollowUpSubjectRef.persistentPerson(input.persistentPersonId ?? '')
          : FollowUpSubjectRef.accountOwner;
      final purpose = _relevance.purposeForQuery(input.query);
      final conversationRelevant =
          purpose == PersonalizationPurpose.followUpContinuation ||
              purpose == PersonalizationPurpose.goalSupport ||
              purpose == PersonalizationPurpose.conversationContinuity;
      final active = await _followUps.listActive(subject: subject);
      final dueCtx = FollowUpDueContext(
        now: DateTime.now(),
        currentSubject: subject,
        conversationRelevant: conversationRelevant,
        unrelatedEntityIntent: input.planKindName.contains('Doctor') ||
            input.planKindName.contains('Lab'),
        urgentSafety: input.urgentSafety,
        mentalSafety: input.mentalSafety,
        emotionalDistress: input.emotionalDistress,
      );
      final out = <PersonalizationCandidate>[];
      for (final c in active) {
        if (!_followUps.maySurfaceReturn(c, dueCtx)) continue;
        out.add(
          PersonalizationCandidate(
            opaqueKey: 'fu_${c.topicKey.hashCode.abs()}',
            source: PersonalizationSource.followUp,
            category: c.domain.name,
            displaySafeLabel: c.displayTopic,
            influenceOnly: false,
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
