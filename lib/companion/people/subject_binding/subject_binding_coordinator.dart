import '../../../health/subject/health_subject_coordinator.dart';
import '../../../health/subject/health_subject_models.dart';
import '../../../voice/conversation_context.dart';
import '../../../voice/intent/intent_result.dart';
import '../../../health/guidance/health_guidance_models.dart';
import '../family_person_profile.dart';
import '../family_person_profile_service.dart';
import 'conversation_person_resolver.dart';
import 'subject_binding_models.dart';

/// يربط حلّ الشخص الدائم بسياق المحادثة والموضوع الصحي — PC-1.9.
class SubjectBindingCoordinator {
  SubjectBindingCoordinator({
    FamilyPersonProfileService? people,
    ConversationPersonResolver? resolver,
    HealthSubjectCoordinator? subjects,
  })  : _people = people ?? FamilyPersonProfileService(),
        _resolver = resolver ?? ConversationPersonResolver(),
        _subjects = subjects ?? HealthSubjectCoordinator();

  final FamilyPersonProfileService _people;
  final ConversationPersonResolver _resolver;
  final HealthSubjectCoordinator _subjects;

  ConversationPersonResolver get resolver => _resolver;
  HealthSubjectCoordinator get subjectCoordinator => _subjects;

  Future<SubjectBindingTurnResult> processTurn({
    required String query,
    required ConversationContext context,
    required IntentResult intent,
    required HealthGuidanceSession healthSession,
  }) async {
    if (context.pendingPersonClarification.isActive) {
      return _handleClarificationAnswer(
        answer: query,
        context: context,
        pending: context.pendingPersonClarification,
      );
    }

    if (_resolver.shouldDeferToEntityPipeline(
      query: query,
      intent: intent.intent,
    )) {
      return SubjectBindingTurnResult.defer();
    }

    var repositoryFailed = false;
    List<FamilyPersonProfile> profiles;
    try {
      profiles = await _people.loadEnabledProfiles();
    } catch (_) {
      repositoryFailed = true;
      profiles = const [];
    }

    await _validateActiveBinding(context, profiles);

    final current = context.healthSubject.isKnown
        ? context.healthSubject
        : (healthSession.isActive
            ? healthSession.facts.subject
            : _subjectFromContext(context));

    final detection = _subjects.detector.detect(query);
    final subjectResolution = _subjects.resolve(
      current: current.isKnown ? current : null,
      text: query,
      previousType: healthSession.previousSubjectType,
    );

    final resolution = _resolver.resolve(
      query: query,
      intent: intent.intent,
      profiles: profiles,
      detection: detection,
      currentHealthSubject: current,
      activeLinkedPersonId: context.linkedFamilyPersonId,
      repositoryFailed: repositoryFailed,
    );

    if (resolution.deferredToEntityPipeline) {
      return SubjectBindingTurnResult.defer();
    }

    if (resolution.needsClarification) {
      return SubjectBindingTurnResult.clarify(
        message: resolution.clarificationMessage,
        pending: PendingPersonClarification(
          candidatePersonIds: resolution.clarificationCandidates,
          originalQuery: query,
          intentKind: 'health',
          createdTurnId: context.turnId,
        ),
      );
    }

    final previousId = context.linkedFamilyPersonId;
    final newId = resolution.linkedPersonId;
    final subjectChanged = previousId != newId || subjectResolution.switched;

    final enriched = _mergeSubjectContexts(
      subjectResolution: subjectResolution,
      personResolution: resolution,
      current: current,
    );

    return SubjectBindingTurnResult(
      linkedPersonId: newId,
      resolved: resolution.resolved,
      subjectChanged: subjectChanged,
      enrichedHealthSubject: enriched,
      continuationQuery: resolution.continuationQuery,
    );
  }

  Future<SubjectBindingTurnResult> _handleClarificationAnswer({
    required String answer,
    required ConversationContext context,
    required PendingPersonClarification pending,
  }) async {
    List<FamilyPersonProfile> profiles;
    try {
      profiles = await _people.loadEnabledProfiles();
    } catch (_) {
      context.setPendingPersonClarification(PendingPersonClarification.inactive);
      return const SubjectBindingTurnResult(
        handled: true,
        needsClarification: true,
        message: 'ما كدرت أحدد الشخص. جرّب مرة ثانية.',
      );
    }

    final resolved = _resolver.resolveClarificationAnswer(
      answer: answer,
      pending: pending,
      profiles: profiles,
    );
    if (resolved == null) {
      return SubjectBindingTurnResult.clarify(
        message: 'ما فهمت أي شخص. ${pending.candidatePersonIds.length > 1 ? "قل الاسم مثل: علي أو حسين" : "قل الاسم"}',
        pending: pending,
      );
    }

    context.setPendingPersonClarification(PendingPersonClarification.inactive);
    return SubjectBindingTurnResult(
      handled: true,
      linkedPersonId: resolved.linkedPersonId,
      resolved: resolved.resolved,
      subjectChanged: true,
      enrichedHealthSubject: resolved.healthSubject,
      continuationQuery: resolved.continuationQuery ?? pending.originalQuery,
    );
  }

  Future<void> _validateActiveBinding(
    ConversationContext context,
    List<FamilyPersonProfile> enabled,
  ) async {
    final id = context.linkedFamilyPersonId;
    if (id == null || id.isEmpty) return;
    final stillValid = enabled.any((p) => p.personId == id);
    if (!stillValid) {
      context.setLinkedFamilyPersonId(null);
      context.setResolvedConversationSubject(ResolvedConversationSubject.unknown);
    }
  }

  HealthSubjectContext _subjectFromContext(ConversationContext context) {
    if (context.healthSubject.isKnown) return context.healthSubject;
    if (context.linkedFamilyPersonId != null) {
      return HealthSubjectContext.unknown.copyWith(
        linkedPersonId: context.linkedFamilyPersonId,
      );
    }
    return HealthSubjectContext.unknown;
  }

  HealthSubjectContext _mergeSubjectContexts({
    required HealthSubjectResolution subjectResolution,
    required ConversationPersonResolution personResolution,
    required HealthSubjectContext current,
  }) {
    final personSubject = personResolution.healthSubject;
    if (personSubject != null) {
      if (personResolution.resolved.isAccountOwner) {
        return personSubject;
      }
      return personSubject.copyWith(
        sessionKey: subjectResolution.switched
            ? personSubject.sessionKey
            : (current.isKnown ? current.sessionKey : personSubject.sessionKey),
        type: personSubject.type != HealthSubjectType.unknown
            ? personSubject.type
            : subjectResolution.subject.type,
        evidence: personSubject.evidence,
        linkedPersonId: personResolution.linkedPersonId,
        ageYears: subjectResolution.subject.ageYears ?? personSubject.ageYears,
        isChild: subjectResolution.subject.isChild ?? personSubject.isChild,
      );
    }
    return subjectResolution.subject.copyWith(
      linkedPersonId: personResolution.linkedPersonId,
      clearLinkedPersonId: personResolution.resolved.isAccountOwner,
    );
  }

  void applyToContext(
    ConversationContext context,
    SubjectBindingTurnResult result,
  ) {
    if (result.deferredToEntityPipeline) return;
    if (result.needsClarification) {
      context.setPendingPersonClarification(result.pending);
      return;
    }
    final previousId = context.linkedFamilyPersonId;
    final previousOwner = context.resolvedConversationSubject.isAccountOwner;
    context.setPendingPersonClarification(PendingPersonClarification.inactive);
    context.setLinkedFamilyPersonId(result.linkedPersonId);
    context.setResolvedConversationSubject(result.resolved);

    // PC-1.25: مسح الجلسات السريرية عند تبديل شخص فعلي فقط.
    final nowOwner = result.resolved.isAccountOwner;
    final idChanged = previousId != result.linkedPersonId;
    final ownerFlip = previousOwner != nowOwner;
    if (result.subjectChanged && (idChanged || ownerFlip)) {
      context.clearClinicalPackSessionsForSubjectSwitch();
      final scope = nowOwner
          ? 'owner'
          : 'person:${result.linkedPersonId ?? result.resolved.subjectKind.name}';
      context.lastClinicalSubjectScopeKey = scope;
    }
    final enriched = result.enrichedHealthSubject;
    if (enriched != null) {
      // يحافظ على عمر/جنس المالك المُثرى (Phase 3C) عند بقاء الموضوع ذاتاً فقط.
      final keepOwnerHints = enriched.type == HealthSubjectType.self;
      context.setHealthSubject(
        enriched.copyWith(
          ageYears: enriched.ageYears ??
              (keepOwnerHints ? context.healthSubject.ageYears : null),
          reservedSexHint: keepOwnerHints
              ? (enriched.reservedSexHint ??
                  context.healthSubject.reservedSexHint)
              : null,
          clearReservedSexHint: !keepOwnerHints,
          clearAgeYears: !keepOwnerHints && enriched.ageYears == null,
        ),
      );
    }
  }
}
