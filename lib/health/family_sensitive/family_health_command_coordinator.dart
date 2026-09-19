import '../../companion/people/family_person_profile.dart';
import '../../companion/people/family_person_profile_service.dart';
import '../../companion/people/person_reference_resolver.dart';
import '../../search/arabic_text_utils.dart';
import '../sensitive_profile/sensitive_health_profile_models.dart';
import 'family_health_command_interpreter.dart';
import 'family_health_command_models.dart';
import 'family_health_consent_coordinator.dart';
import 'family_sensitive_health_retrieval_policy.dart';
import 'family_sensitive_health_service.dart';

/// منسّق صحة العائلة الحسّاسة — PC-1.10.
class FamilyHealthCommandCoordinator {
  FamilyHealthCommandCoordinator({
    FamilySensitiveHealthService? service,
    FamilyPersonProfileService? people,
    FamilyHealthCommandInterpreter? interpreter,
    FamilyHealthConsentCoordinator? consent,
    FamilySensitiveHealthRetrievalPolicy? retrieval,
    PersonReferenceResolver? resolver,
  })  : _service = service ?? FamilySensitiveHealthService(),
        _people = people ?? FamilyPersonProfileService(),
        _interpreter = interpreter ?? FamilyHealthCommandInterpreter(),
        _consent = consent ?? const FamilyHealthConsentCoordinator(),
        _retrieval = retrieval ?? const FamilySensitiveHealthRetrievalPolicy(),
        _resolver = resolver ?? const PersonReferenceResolver();

  final FamilySensitiveHealthService _service;
  final FamilyPersonProfileService _people;
  final FamilyHealthCommandInterpreter _interpreter;
  final FamilyHealthConsentCoordinator _consent;
  final FamilySensitiveHealthRetrievalPolicy _retrieval;
  final PersonReferenceResolver _resolver;

  FamilySensitiveHealthService get service => _service;
  FamilyHealthCommandInterpreter get interpreter => _interpreter;
  FamilySensitiveHealthRetrievalPolicy get retrieval => _retrieval;
  FamilyPersonProfileService get people => _people;

  bool mayHandle({
    required String query,
    required FamilyHealthPendingOp pending,
  }) {
    if (pending.isActive) return true;
    return _interpreter.looksLikeFamilyHealthCommand(query);
  }

  bool shouldEscapeToProvider(String query) {
    final n = ArabicTextUtils.normalize(query);
    return RegExp(
      r'(?:أريد|اريد|ابي|دور)\s*(?:طبيب|دكتور|مختبر)',
    ).hasMatch(n);
  }

  Future<FamilyHealthCommandTurnResult> handle({
    required String text,
    required FamilyHealthPendingOp pending,
    String? linkedFamilyPersonId,
    bool preferUrgentSafety = false,
    bool preferMentalSafety = false,
  }) async {
    if (preferUrgentSafety) {
      return const FamilyHealthCommandTurnResult(
        handled: false,
        message: '',
        deferToUrgentSafety: true,
        textFirstOnly: true,
      );
    }
    if (preferMentalSafety) {
      return const FamilyHealthCommandTurnResult(
        handled: false,
        message: '',
        deferToMentalSafety: true,
        textFirstOnly: true,
      );
    }
    if (shouldEscapeToProvider(text) && !pending.isActive) {
      return const FamilyHealthCommandTurnResult(
        handled: false,
        message: '',
        deferToProvider: true,
        textFirstOnly: true,
      );
    }

    final interp = _interpreter.interpret(raw: text, pending: pending);
    if (!interp.isCommand) {
      return FamilyHealthCommandTurnResult.notHandled();
    }

    try {
      return await _execute(
        interp: interp,
        pending: pending,
        linkedFamilyPersonId: linkedFamilyPersonId,
        originalText: text,
      );
    } catch (_) {
      return FamilyHealthCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما كدرت أكمّل طلب صحة العائلة هسه. ما تم الحفظ.',
        commandKind: interp.kind,
        textFirstOnly: true,
      );
    }
  }

  Future<FamilyHealthCommandTurnResult> _execute({
    required FamilyHealthCommandInterpretation interp,
    required FamilyHealthPendingOp pending,
    required String? linkedFamilyPersonId,
    required String originalText,
  }) async {
    switch (interp.kind) {
      case FamilyHealthCommandKind.deferToUrgentSafety:
        return const FamilyHealthCommandTurnResult(
          handled: false,
          message: '',
          deferToUrgentSafety: true,
        );
      case FamilyHealthCommandKind.deferToMentalSafety:
        return const FamilyHealthCommandTurnResult(
          handled: false,
          message: '',
          deferToMentalSafety: true,
        );
      case FamilyHealthCommandKind.deferToProvider:
        return const FamilyHealthCommandTurnResult(
          handled: false,
          message: '',
          deferToProvider: true,
        );

      case FamilyHealthCommandKind.consentWhy:
        return FamilyHealthCommandTurnResult(
          handled: true,
          message:
              '${FamilyHealthConsentCoordinator.whyExplanation}\n'
              '${_consent.buildConsentPrompt(
            candidates: pending.consent.candidates,
            personLabel: pending.consent.displayLabel,
            isChild: _isChildLabel(pending.consent.displayLabel),
          )}',
          pending: pending,
          commandKind: interp.kind,
          linkedPersonId: pending.consent.persistentPersonId,
          resolutionStatus: 'resolved',
        );

      case FamilyHealthCommandKind.consentLater:
      case FamilyHealthCommandKind.consentNo:
        return FamilyHealthCommandTurnResult(
          handled: true,
          success: true,
          message: 'تمام، ما حفظت أي معلومة صحية دائمة عن العائلة.',
          pending: FamilyHealthPendingOp.none,
          commandKind: interp.kind,
          recordCount: 0,
        );

      case FamilyHealthCommandKind.consentYes:
        return _persistConsent(pending, interp);

      case FamilyHealthCommandKind.rememberCandidates:
        return _beginRemember(
          interp: interp,
          linkedFamilyPersonId: linkedFamilyPersonId,
          originalText: originalText,
        );

      case FamilyHealthCommandKind.clarifyPerson:
        return _resolveClarifiedPerson(
          answer: originalText,
          pending: pending,
        );

      case FamilyHealthCommandKind.showPersonHealth:
        return _showPersonHealth(
          interp: interp,
          linkedFamilyPersonId: linkedFamilyPersonId,
        );

      case FamilyHealthCommandKind.showFamilyHealthOverview:
        return _showOverview();

      case FamilyHealthCommandKind.forgetCondition:
        return _forgetOne(
          interp: interp,
          linkedFamilyPersonId: linkedFamilyPersonId,
        );

      case FamilyHealthCommandKind.deleteAllHealthRequest:
        return _requestDeleteAll(
          interp: interp,
          linkedFamilyPersonId: linkedFamilyPersonId,
        );

      case FamilyHealthCommandKind.confirmDeleteAllHealth:
        return _confirmDeleteAll(pending);

      case FamilyHealthCommandKind.cancelDelete:
        return const FamilyHealthCommandTurnResult(
          handled: true,
          message: 'تمام، ما مسحت المعلومات الصحية.',
          pending: FamilyHealthPendingOp.none,
          commandKind: FamilyHealthCommandKind.cancelDelete,
        );

      case FamilyHealthCommandKind.rejectIneligible:
      case FamilyHealthCommandKind.rejectTemporarySubject:
      case FamilyHealthCommandKind.needsPersistentProfile:
      case FamilyHealthCommandKind.notImplementedChronic:
      case FamilyHealthCommandKind.notImplementedAllergy:
      case FamilyHealthCommandKind.notImplementedMedication:
        return FamilyHealthCommandTurnResult(
          handled: true,
          success: false,
          message: interp.message,
          commandKind: interp.kind,
        );

      case FamilyHealthCommandKind.none:
        return FamilyHealthCommandTurnResult.notHandled();
    }
  }

  Future<FamilyHealthCommandTurnResult> _beginRemember({
    required FamilyHealthCommandInterpretation interp,
    required String? linkedFamilyPersonId,
    required String originalText,
  }) async {
    final resolved = await _resolvePerson(
      nameHint: interp.personNameHint,
      relationshipHint: interp.relationshipHint,
      linkedFamilyPersonId: linkedFamilyPersonId,
      query: originalText,
    );

    if (resolved.status == _PersonResolveStatus.ambiguous) {
      return FamilyHealthCommandTurnResult(
        handled: true,
        message: resolved.message,
        pending: FamilyHealthPendingOp(
          kind: FamilyHealthPendingKind.clarifyPersonBeforeConsent,
          candidatePersonIds: resolved.candidateIds,
          pendingCandidates: interp.candidates,
          originalQuery: originalText,
        ),
        commandKind: FamilyHealthCommandKind.clarifyPerson,
        resolutionStatus: 'ambiguous',
      );
    }

    if (resolved.status == _PersonResolveStatus.temporaryOnly) {
      return FamilyHealthCommandTurnResult(
        handled: true,
        success: false,
        message:
            'أكدر أساعدك بهالمحادثة الآن، لكن لحفظ الحالة للمستقبل '
            'لازم يكون عندك ملف شخص محفوظ أولاً (مثل: تذكر ابني علي). '
            'ما أنشئ ملف صحة بدون ملف شخص.',
        commandKind: FamilyHealthCommandKind.needsPersistentProfile,
        resolutionStatus: 'temporary',
      );
    }

    if (resolved.profile == null) {
      return FamilyHealthCommandTurnResult(
        handled: true,
        success: false,
        message: resolved.message.isNotEmpty
            ? resolved.message
            : 'ما قدرت أحدد أي شخص عائلة محفوظ لهالمعلومة.',
        commandKind: FamilyHealthCommandKind.needsPersistentProfile,
        resolutionStatus: 'unknown',
      );
    }

    final person = resolved.profile!;
    if (!person.profileEnabled) {
      return FamilyHealthCommandTurnResult(
        handled: true,
        success: false,
        message:
            'ملف ${person.effectiveName ?? "هذا الشخص"} معطّل. '
            'ما أحفظ صحة تلقائياً لملف معطّل، وما أعيد تفعيله بدون طلبك.',
        commandKind: FamilyHealthCommandKind.rejectIneligible,
        resolutionStatus: 'disabled',
      );
    }

    final label = _personLabel(person);
    final isChild = person.relationship == PersonRelationship.son ||
        person.relationship == PersonRelationship.daughter ||
        person.relationship == PersonRelationship.child;

    final prompt = interp.mixedClarify
        ? _consent.mixedClarifyPrompt(
            eligible: interp.candidates,
            personLabel: label,
          )
        : _consent.buildConsentPrompt(
            candidates: interp.candidates,
            personLabel: label,
            isChild: isChild,
          );

    final pendingConsent = _consent.begin(
      candidates: interp.candidates,
      persistentPersonId: person.personId,
      displayLabel: label,
    );
    if (!pendingConsent.isActive) {
      return const FamilyHealthCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما في حالة مؤهّلة للحفظ الآن.',
        commandKind: FamilyHealthCommandKind.rejectIneligible,
      );
    }

    return FamilyHealthCommandTurnResult(
      handled: true,
      success: true,
      message: prompt,
      pending: FamilyHealthPendingOp(
        kind: FamilyHealthPendingKind.rememberConsent,
        consent: pendingConsent,
        targetPersonId: person.personId,
      ),
      commandKind: FamilyHealthCommandKind.rememberCandidates,
      linkedPersonId: person.personId,
      recordCount: pendingConsent.candidates.length,
      resolutionStatus: 'resolved',
    );
  }

  Future<FamilyHealthCommandTurnResult> _resolveClarifiedPerson({
    required String answer,
    required FamilyHealthPendingOp pending,
  }) async {
    final profiles = await _people.loadEnabledProfiles();
    final candidates = profiles
        .where((p) => pending.candidatePersonIds.contains(p.personId))
        .toList();
    final n = ArabicTextUtils.normalize(answer);
    FamilyPersonProfile? match;
    for (final p in candidates) {
      final name = ArabicTextUtils.normalize(p.effectiveName ?? '');
      if (name.isNotEmpty && (n == name || n.contains(name) || name.contains(n))) {
        match = p;
        break;
      }
    }
    if (match == null && candidates.length == 1 && _isYes(n)) {
      match = candidates.first;
    }
    if (match == null) {
      return FamilyHealthCommandTurnResult(
        handled: true,
        message: 'ما فهمت أي شخص. قل الاسم بوضوح.',
        pending: pending,
        commandKind: FamilyHealthCommandKind.clarifyPerson,
        resolutionStatus: 'ambiguous',
      );
    }

    final label = _personLabel(match);
    final isChild = match.relationship == PersonRelationship.son ||
        match.relationship == PersonRelationship.daughter ||
        match.relationship == PersonRelationship.child;
    final pendingConsent = _consent.begin(
      candidates: pending.pendingCandidates,
      persistentPersonId: match.personId,
      displayLabel: label,
    );
    return FamilyHealthCommandTurnResult(
      handled: true,
      message: _consent.buildConsentPrompt(
        candidates: pending.pendingCandidates,
        personLabel: label,
        isChild: isChild,
      ),
      pending: FamilyHealthPendingOp(
        kind: FamilyHealthPendingKind.rememberConsent,
        consent: pendingConsent,
        targetPersonId: match.personId,
      ),
      commandKind: FamilyHealthCommandKind.rememberCandidates,
      linkedPersonId: match.personId,
      resolutionStatus: 'resolved',
    );
  }

  Future<FamilyHealthCommandTurnResult> _persistConsent(
    FamilyHealthPendingOp pending,
    FamilyHealthCommandInterpretation interp,
  ) async {
    final personId =
        pending.consent.persistentPersonId ?? pending.targetPersonId;
    final candidates = interp.candidates.isNotEmpty
        ? interp.candidates
        : pending.consent.candidates;
    if (personId == null || personId.isEmpty || candidates.isEmpty) {
      return const FamilyHealthCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما في شيء للحفظ.',
        commandKind: FamilyHealthCommandKind.consentYes,
      );
    }
    try {
      final saved = await _service.upsertConditions(
        persistentPersonId: personId,
        candidates: candidates,
      );
      return FamilyHealthCommandTurnResult(
        handled: true,
        success: true,
        message:
            'تم الحفظ. راح أراعي هالمعلومات بالمحادثات الصحية عن هذا الشخص عند الحاجة فقط.',
        pending: FamilyHealthPendingOp.none,
        commandKind: FamilyHealthCommandKind.consentYes,
        recordCount: saved.conditions.length,
        linkedPersonId: personId,
        resolutionStatus: 'resolved',
      );
    } catch (_) {
      return const FamilyHealthCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما كدرت أحفظ المعلومة الصحية. ما تم الحفظ.',
        pending: FamilyHealthPendingOp.none,
        commandKind: FamilyHealthCommandKind.consentYes,
        recordCount: 0,
      );
    }
  }

  Future<FamilyHealthCommandTurnResult> _showPersonHealth({
    required FamilyHealthCommandInterpretation interp,
    required String? linkedFamilyPersonId,
  }) async {
    final resolved = await _resolvePerson(
      nameHint: interp.personNameHint,
      relationshipHint: interp.relationshipHint,
      linkedFamilyPersonId: linkedFamilyPersonId,
      query: interp.personNameHint ?? '',
      includeDisabled: true,
    );
    if (resolved.profile == null) {
      return FamilyHealthCommandTurnResult(
        handled: true,
        message: resolved.message.isNotEmpty
            ? resolved.message
            : 'ما قدرت أحدد الشخص.',
        resolutionStatus: resolved.status.name,
        commandKind: FamilyHealthCommandKind.showPersonHealth,
      );
    }
    final person = resolved.profile!;
    final records = await _retrieval.retrieveRelevant(
      service: _service,
      purpose: FamilyHealthRetrievalPurpose.showFamilyHealth,
      activePersistentPersonId: person.personId,
      personProfile: person.profileEnabled ? person : null,
    );
    // العرض الصريح يسمح حتى لو معطّل بعد حلّ صريح — لكن الاسترجاع التلقائي لا.
    final profile = await _service.loadForPerson(person.personId);
    final show = profile?.conditions
            .where((c) => c.consentState == HealthConsentState.granted)
            .toList() ??
        records;
    if (show.isEmpty) {
      return FamilyHealthCommandTurnResult(
        handled: true,
        message:
            'ما عندي معلومات صحية دائمة محفوظة عن ${_personLabel(person)} حالياً.',
        linkedPersonId: person.personId,
        recordCount: 0,
        commandKind: FamilyHealthCommandKind.showPersonHealth,
        resolutionStatus: 'resolved',
      );
    }
    final lines = show.map((c) => '• ${c.displayName}').join('\n');
    return FamilyHealthCommandTurnResult(
      handled: true,
      message:
          'المعلومات الصحية المحفوظة عن ${_personLabel(person)}:\n$lines',
      linkedPersonId: person.personId,
      recordCount: show.length,
      commandKind: FamilyHealthCommandKind.showPersonHealth,
      resolutionStatus: 'resolved',
    );
  }

  Future<FamilyHealthCommandTurnResult> _showOverview() async {
    final ids = await _service.personIdsWithHealth();
    if (ids.isEmpty) {
      return const FamilyHealthCommandTurnResult(
        handled: true,
        message: 'ما عندي معلومات صحية دائمة محفوظة عن أشخاص العائلة حالياً.',
        commandKind: FamilyHealthCommandKind.showFamilyHealthOverview,
        recordCount: 0,
      );
    }
    final all = await _people.loadAllProfiles();
    final labels = <String>[];
    for (final id in ids) {
      final p = all.cast<FamilyPersonProfile?>().firstWhere(
            (e) => e?.personId == id,
            orElse: () => null,
          );
      if (p != null) labels.add(_personLabel(p));
    }
    if (labels.isEmpty) {
      return const FamilyHealthCommandTurnResult(
        handled: true,
        message:
            'عندي معلومات صحية محفوظة لبعض الأشخاص. '
            'قل لي عن أي شخص تريد تعرف؟',
        commandKind: FamilyHealthCommandKind.showFamilyHealthOverview,
      );
    }
    return FamilyHealthCommandTurnResult(
      handled: true,
      message:
          'عندي معلومات صحية محفوظة عن: ${labels.join('، ')}.\n'
          'عن أي شخص تريد التفاصيل؟ '
          '(ما أعرض كل التشخيصات دفعة واحدة للحفاظ على الخصوصية.)',
      commandKind: FamilyHealthCommandKind.showFamilyHealthOverview,
      recordCount: ids.length,
    );
  }

  Future<FamilyHealthCommandTurnResult> _forgetOne({
    required FamilyHealthCommandInterpretation interp,
    required String? linkedFamilyPersonId,
  }) async {
    final key = interp.conditionKey;
    if (key == null) {
      return const FamilyHealthCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما فهمت أي حالة تريد تمسحها.',
        commandKind: FamilyHealthCommandKind.forgetCondition,
      );
    }
    final resolved = await _resolvePerson(
      nameHint: interp.personNameHint,
      relationshipHint: interp.relationshipHint,
      linkedFamilyPersonId: linkedFamilyPersonId,
      query: interp.personNameHint ?? '',
      includeDisabled: true,
    );
    if (resolved.profile == null) {
      return FamilyHealthCommandTurnResult(
        handled: true,
        message: 'ما قدرت أحدد الشخص.',
        commandKind: FamilyHealthCommandKind.forgetCondition,
        resolutionStatus: resolved.status.name,
      );
    }
    await _service.removeCondition(
      persistentPersonId: resolved.profile!.personId,
      canonicalKey: key,
    );
    final after = await _service.countForPerson(resolved.profile!.personId);
    return FamilyHealthCommandTurnResult(
      handled: true,
      success: true,
      message:
          'تم مسح السجل المطلوب من المعلومات الصحية عن ${_personLabel(resolved.profile!)} فقط. ملف الشخص ما انمسح.',
      linkedPersonId: resolved.profile!.personId,
      recordCount: after,
      commandKind: FamilyHealthCommandKind.forgetCondition,
      resolutionStatus: 'resolved',
    );
  }

  Future<FamilyHealthCommandTurnResult> _requestDeleteAll({
    required FamilyHealthCommandInterpretation interp,
    required String? linkedFamilyPersonId,
  }) async {
    final resolved = await _resolvePerson(
      nameHint: interp.personNameHint,
      relationshipHint: interp.relationshipHint,
      linkedFamilyPersonId: linkedFamilyPersonId,
      query: interp.personNameHint ?? '',
      includeDisabled: true,
    );
    if (resolved.profile == null) {
      return FamilyHealthCommandTurnResult(
        handled: true,
        message: 'ما قدرت أحدد الشخص.',
        commandKind: FamilyHealthCommandKind.deleteAllHealthRequest,
      );
    }
    return FamilyHealthCommandTurnResult(
      handled: true,
      message:
          'متأكد تريد مسح كل المعلومات الصحية المحفوظة عن ${_personLabel(resolved.profile!)}؟ '
          'ملف الشخص نفسه ما ينمسح. قل نعم للتأكيد أو لا للإلغاء.',
      pending: FamilyHealthPendingOp(
        kind: FamilyHealthPendingKind.deleteAllHealthForPerson,
        targetPersonId: resolved.profile!.personId,
      ),
      linkedPersonId: resolved.profile!.personId,
      commandKind: FamilyHealthCommandKind.deleteAllHealthRequest,
      resolutionStatus: 'resolved',
    );
  }

  Future<FamilyHealthCommandTurnResult> _confirmDeleteAll(
    FamilyHealthPendingOp pending,
  ) async {
    final id = pending.targetPersonId;
    if (id == null || id.isEmpty) {
      return const FamilyHealthCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما عندي شخص محدد للحذف.',
        commandKind: FamilyHealthCommandKind.confirmDeleteAllHealth,
      );
    }
    if (pending.kind == FamilyHealthPendingKind.deletePersonWithHealth) {
      // يُكمّل من مسار حذف ملف الشخص.
      await _service.cascadeDeleteForPerson(id);
      return FamilyHealthCommandTurnResult(
        handled: true,
        success: true,
        message: 'ready_cascade',
        pending: FamilyHealthPendingOp.none,
        linkedPersonId: id,
        commandKind: FamilyHealthCommandKind.confirmDeleteAllHealth,
        recordCount: 0,
      );
    }
    await _service.deleteAllForPerson(id);
    return const FamilyHealthCommandTurnResult(
      handled: true,
      success: true,
      message:
          'تم مسح المعلومات الصحية المحفوظة عن هذا الشخص. ملف الهوية ما انمسح.',
      pending: FamilyHealthPendingOp.none,
      commandKind: FamilyHealthCommandKind.confirmDeleteAllHealth,
      recordCount: 0,
    );
  }

  Future<_ResolvedFamilyPerson> _resolvePerson({
    required String? nameHint,
    required String? relationshipHint,
    required String? linkedFamilyPersonId,
    required String query,
    bool includeDisabled = false,
  }) async {
    final profiles = includeDisabled
        ? await _people.loadAllProfiles()
        : await _people.loadEnabledProfiles();
    final rel = _interpreter.relationshipFromHint(relationshipHint);

    if (nameHint != null || rel != null) {
      final ref = _resolver.resolve(
        query: query,
        profiles: profiles,
        relationshipHint: rel,
        nameHint: nameHint,
        includeDisabled: includeDisabled,
      );
      if (ref.isAmbiguous) {
        return _ResolvedFamilyPerson(
          status: _PersonResolveStatus.ambiguous,
          message: ref.message,
          candidateIds: ref.candidates.map((c) => c.personId).toList(),
        );
      }
      if (ref.isResolved && ref.profile != null) {
        return _ResolvedFamilyPerson(
          status: _PersonResolveStatus.resolved,
          profile: ref.profile,
        );
      }
    }

    if (linkedFamilyPersonId != null && linkedFamilyPersonId.isNotEmpty) {
      final p = profiles.cast<FamilyPersonProfile?>().firstWhere(
            (e) => e?.personId == linkedFamilyPersonId,
            orElse: () => null,
          );
      if (p != null) {
        return _ResolvedFamilyPerson(
          status: _PersonResolveStatus.resolved,
          profile: p,
        );
      }
    }

    // علاقة بدون ملف دائم
    if (rel != null ||
        RegExp(r'(?:ابني|ابنتي|امي|ابوي)').hasMatch(
          ArabicTextUtils.normalize(query),
        )) {
      return const _ResolvedFamilyPerson(
        status: _PersonResolveStatus.temporaryOnly,
        message: '',
      );
    }

    return const _ResolvedFamilyPerson(
      status: _PersonResolveStatus.notFound,
      message: 'ما قدرت أحدد الشخص المحفوظ.',
    );
  }

  String _personLabel(FamilyPersonProfile p) {
    if (p.effectiveName != null && p.effectiveName!.trim().isNotEmpty) {
      return p.effectiveName!;
    }
    switch (p.relationship) {
      case PersonRelationship.son:
        return 'ابنك';
      case PersonRelationship.daughter:
        return 'بنتك';
      case PersonRelationship.child:
        return 'طفلك';
      case PersonRelationship.mother:
        return 'أمك';
      case PersonRelationship.father:
        return 'أبوك';
      case PersonRelationship.wife:
        return 'زوجتك';
      case PersonRelationship.husband:
        return 'زوجك';
      default:
        return 'هذا الشخص';
    }
  }

  bool _isChildLabel(String label) =>
      label.contains('ابن') || label.contains('بنت') || label.contains('طفل');

  bool _isYes(String n) =>
      RegExp(r'^(?:نعم|اي|أي|موافق|اوك|ok|yes)$').hasMatch(n);

  /// للتكامل مع حذف ملف الشخص — هل توجد سجلات صحة تابعة؟
  Future<bool> hasDependentHealth(String personId) =>
      _service.hasHealthForPerson(personId);

  Future<void> cascadeDeleteHealth(String personId) =>
      _service.cascadeDeleteForPerson(personId);
}

enum _PersonResolveStatus {
  resolved,
  ambiguous,
  temporaryOnly,
  notFound,
  disabled,
}

class _ResolvedFamilyPerson {
  const _ResolvedFamilyPerson({
    required this.status,
    this.profile,
    this.message = '',
    this.candidateIds = const [],
  });

  final _PersonResolveStatus status;
  final FamilyPersonProfile? profile;
  final String message;
  final List<String> candidateIds;
}
