import '../../../health/subject/health_subject_detector.dart';
import '../../../health/subject/health_subject_models.dart';
import '../../../health/understanding/health_understanding_engine.dart';
import '../../../search/arabic_text_utils.dart';
import '../../../voice/intent/assistant_intent.dart';
import '../family_person_profile.dart';
import '../person_reference_resolver.dart';
import 'subject_binding_models.dart';

/// حلّ حتمي: لغة المستخدم → شخص محادثة — PC-1.9.
class ConversationPersonResolver {
  ConversationPersonResolver({
    PersonReferenceResolver? referenceResolver,
    HealthSubjectDetector? subjectDetector,
    HealthUnderstandingEngine? understanding,
  })  : _refs = referenceResolver ?? const PersonReferenceResolver(),
        _subjects = subjectDetector ?? const HealthSubjectDetector(),
        _understanding = understanding ?? HealthUnderstandingEngine();

  final PersonReferenceResolver _refs;
  final HealthSubjectDetector _subjects;
  final HealthUnderstandingEngine _understanding;

  bool shouldDeferToEntityPipeline({
    required String query,
    required AssistantIntent intent,
  }) {
    switch (intent) {
      case AssistantIntent.findLab:
      case AssistantIntent.findAnalysis:
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.specialtySearch:
        return true;
      case AssistantIntent.doctorSearch:
        final n = ArabicTextUtils.normalize(query);
        if (RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور).{0,16}(?:طبيب|دكتور)|'
          r'(?:^|\s)(?:ال)?(?:دكتور|طبيب|د\.)\s+\S{2,}',
        ).hasMatch(n)) {
          return true;
        }
        return false;
      default:
        break;
    }
    final n = ArabicTextUtils.normalize(query);
    if (RegExp(r'(?:دكتور|طبيب|د\.)\s+\S{2,}').hasMatch(n)) return true;
    if (RegExp(r'(?:أريد|اريد|ابي|دور)\s*(?:طبيب|دكتور|مختبر)').hasMatch(n)) {
      return true;
    }
    if (RegExp(r'(?:^|\s)(?:مختبر|تحليل|باقة|عرض)\s').hasMatch(n)) {
      return true;
    }
    return false;
  }

  ConversationPersonResolution resolve({
    required String query,
    required AssistantIntent intent,
    required List<FamilyPersonProfile> profiles,
    required HealthSubjectDetection detection,
    required HealthSubjectContext currentHealthSubject,
    String? activeLinkedPersonId,
    bool repositoryFailed = false,
  }) {
    if (shouldDeferToEntityPipeline(query: query, intent: intent)) {
      return ConversationPersonResolution.deferred;
    }
    if (repositoryFailed) {
      return _temporaryFromDetection(detection);
    }

    final n = ArabicTextUtils.normalize(query);
    final hasHealth = _understanding.looksLikeHealthLanguage(query) ||
        detection.isExplicitSwitchSignal ||
        detection.returnToPrevious;

    // 1 — self صريح
    if (detection.evidence == HealthSubjectEvidence.explicitSelf ||
        _isExplicitSelfPhrase(n)) {
      return ConversationPersonResolution(
        resolved: ResolvedConversationSubject.accountOwner,
        linkedPersonId: null,
        healthSubject: _buildHealthSubject(
          type: HealthSubjectType.self,
          evidence: HealthSubjectEvidence.explicitSelf,
          linkedPersonId: null,
          clearLinked: true,
          current: currentHealthSubject,
        ),
      );
    }

    // 2 — علاقة + اسم
    final relHint = _relationshipFromText(n);
    final nameHint = _extractPersonName(n, relHint);
    if (relHint != null && nameHint.isNotEmpty) {
      final ref = _refs.resolve(
        query: query,
        profiles: profiles,
        relationshipHint: relHint,
        nameHint: nameHint,
      );
      if (ref.isResolved && ref.profile != null) {
        return _persistent(ref.profile!, detection);
      }
      if (ref.isAmbiguous) {
        return _ambiguous(ref, query);
      }
    }

    // 3 — اسم فريد مع سياق صحي/شخص
    if (nameHint.isNotEmpty && (hasHealth || activeLinkedPersonId != null)) {
      final byName = profiles
          .where((p) => _nameEq(p.effectiveName, nameHint))
          .toList();
      if (byName.length == 1) {
        return _persistent(byName.first, detection);
      }
      if (byName.length > 1) {
        return _ambiguousByProfiles(byName, query);
      }
    }

    // 4 — علاقة فريدة
    if (relHint != null && nameHint.isEmpty && hasHealth) {
      final relPool = _profilesForRelationship(profiles, relHint);
      if (relPool.length == 1) {
        return _persistent(relPool.first, detection);
      }
      if (relPool.length > 1) {
        return _ambiguousByProfiles(relPool, query);
      }
    }

    // 5 — استمرار مع شخص مرتبط (لا يتجاوز علاقة صريحة جديدة)
    if (activeLinkedPersonId != null &&
        relHint == null &&
        !detection.isExplicitSwitchSignal &&
        detection.evidence != HealthSubjectEvidence.explicitRelationship &&
        (_subjects.looksLikeContinuation(query) ||
            detection.evidence == HealthSubjectEvidence.ambiguous)) {
      final p = profiles.cast<FamilyPersonProfile?>().firstWhere(
            (e) => e?.personId == activeLinkedPersonId,
            orElse: () => null,
          );
      if (p != null && p.profileEnabled) {
        return _persistent(p, detection, continuation: true);
      }
    }

    // 6 — ضمير غامض بلا موضوع نشط
    if (_isVagueThirdPerson(n) && activeLinkedPersonId == null) {
      return ConversationPersonResolution(
        resolved: const ResolvedConversationSubject(
          subjectKind: ConversationSubjectKind.unknownPerson,
          status: ConversationPersonResolutionStatus.unknown,
          healthSubjectType: HealthSubjectType.unknown,
        ),
      );
    }

    // 7 — ضمير مع موضوع نشط
    if (_isVagueThirdPerson(n) && activeLinkedPersonId != null) {
      final p = profiles.where((e) => e.personId == activeLinkedPersonId);
      if (p.length == 1) {
        return _persistent(p.first, detection, continuation: true);
      }
    }

    // 8 — علاقة مؤقتة (جلسة) بلا ملف دائم
    if (detection.evidence == HealthSubjectEvidence.explicitRelationship) {
      return _temporaryFromDetection(detection);
    }

    // 9 — استمرار health subject مع linked id
    if (currentHealthSubject.linkedPersonId != null &&
        _subjects.looksLikeContinuation(query)) {
      final p = profiles.where(
        (e) => e.personId == currentHealthSubject.linkedPersonId,
      );
      if (p.length == 1) {
        return _persistent(p.first, detection, continuation: true);
      }
    }

    if (detection.evidence == HealthSubjectEvidence.ambiguous) {
      return ConversationPersonResolution(
        resolved: const ResolvedConversationSubject(
          subjectKind: ConversationSubjectKind.unknownPerson,
          status: ConversationPersonResolutionStatus.unknown,
          healthSubjectType: HealthSubjectType.unknown,
        ),
      );
    }

    return ConversationPersonResolution(
      resolved: ResolvedConversationSubject(
        subjectKind: activeLinkedPersonId != null
            ? ConversationSubjectKind.persistentPerson
            : ConversationSubjectKind.temporaryOtherPerson,
        status: ConversationPersonResolutionStatus.resolved,
        healthSubjectType: currentHealthSubject.type,
        persistentPersonId: activeLinkedPersonId,
      ),
      linkedPersonId: activeLinkedPersonId,
    );
  }

  /// حلّ إجابة توضيح: اسم مرشّح فقط.
  ConversationPersonResolution? resolveClarificationAnswer({
    required String answer,
    required PendingPersonClarification pending,
    required List<FamilyPersonProfile> profiles,
  }) {
    final n = ArabicTextUtils.normalize(answer.trim());
    if (n.isEmpty) return null;
    final pool = profiles
        .where((p) => pending.candidatePersonIds.contains(p.personId))
        .toList();
    if (pool.isEmpty) return null;

    final matches = pool.where((p) => _nameEq(p.effectiveName, n)).toList();
    if (matches.length == 1) {
      return ConversationPersonResolution(
        resolved: _resolvedFromProfile(matches.first),
        linkedPersonId: matches.first.personId,
        healthSubject: _buildHealthSubject(
          type: _refs.toHealthSubjectType(matches.first.relationship),
          evidence: HealthSubjectEvidence.explicitRelationship,
          linkedPersonId: matches.first.personId,
          current: HealthSubjectContext.unknown,
        ),
        continuationQuery: pending.originalQuery,
      );
    }
    if (matches.length > 1) {
      return _ambiguousByProfiles(matches, pending.originalQuery);
    }
    return null;
  }

  ConversationPersonResolution _persistent(
    FamilyPersonProfile profile,
    HealthSubjectDetection detection, {
    bool continuation = false,
  }) {
    final type = _refs.toHealthSubjectType(profile.relationship);
    return ConversationPersonResolution(
      resolved: _resolvedFromProfile(profile),
      linkedPersonId: profile.personId,
      healthSubject: _buildHealthSubject(
        type: type,
        evidence: continuation
            ? HealthSubjectEvidence.contextualContinuation
            : detection.evidence == HealthSubjectEvidence.unknown
                ? HealthSubjectEvidence.explicitRelationship
                : detection.evidence,
        linkedPersonId: profile.personId,
        ageYears: detection.ageYears,
        isChild: detection.isChildHint,
        current: HealthSubjectContext.unknown,
      ),
    );
  }

  ConversationPersonResolution _temporaryFromDetection(
    HealthSubjectDetection detection,
  ) {
    return ConversationPersonResolution(
      resolved: ResolvedConversationSubject(
        subjectKind: ConversationSubjectKind.temporaryOtherPerson,
        status: ConversationPersonResolutionStatus.resolved,
        healthSubjectType: detection.type,
        relationship: _typeToRelationship(detection.type),
      ),
      linkedPersonId: null,
      healthSubject: _buildHealthSubject(
        type: detection.type,
        evidence: detection.evidence,
        linkedPersonId: null,
        clearLinked: true,
        ageYears: detection.ageYears,
        isChild: detection.isChildHint,
        current: HealthSubjectContext.unknown,
      ),
    );
  }

  ConversationPersonResolution _ambiguous(
    PersonReferenceResolution ref,
    String query,
  ) {
    return ConversationPersonResolution(
      resolved: const ResolvedConversationSubject(
        subjectKind: ConversationSubjectKind.ambiguousPerson,
        status: ConversationPersonResolutionStatus.ambiguous,
        healthSubjectType: HealthSubjectType.child,
      ),
      needsClarification: true,
      clarificationMessage: ref.message.isNotEmpty
          ? ref.message
          : 'أي شخص تقصد؟',
      clarificationCandidates: [
        for (final p in ref.candidates) p.personId,
      ],
    );
  }

  ConversationPersonResolution _ambiguousByProfiles(
    List<FamilyPersonProfile> list,
    String query,
  ) {
    final names = list
        .map((p) => p.effectiveName ?? p.relationship.name)
        .join('، ');
    return ConversationPersonResolution(
      resolved: const ResolvedConversationSubject(
        subjectKind: ConversationSubjectKind.ambiguousPerson,
        status: ConversationPersonResolutionStatus.ambiguous,
        healthSubjectType: HealthSubjectType.child,
      ),
      needsClarification: true,
      clarificationMessage: 'أي واحد تقصد؟ $names',
      clarificationCandidates: [for (final p in list) p.personId],
    );
  }

  ResolvedConversationSubject _resolvedFromProfile(FamilyPersonProfile p) {
    return ResolvedConversationSubject(
      subjectKind: ConversationSubjectKind.persistentPerson,
      status: ConversationPersonResolutionStatus.resolved,
      healthSubjectType: _refs.toHealthSubjectType(p.relationship),
      persistentPersonId: p.personId,
      relationship: p.relationship,
    );
  }

  HealthSubjectContext _buildHealthSubject({
    required HealthSubjectType type,
    required HealthSubjectEvidence evidence,
    required HealthSubjectContext current,
    String? linkedPersonId,
    bool clearLinked = false,
    int? ageYears,
    bool? isChild,
  }) {
    final isChildVal = isChild ??
        (type == HealthSubjectType.child
            ? true
            : (ageYears != null ? ageYears < 18 : null));
    return HealthSubjectContext(
      sessionKey: current.isKnown && !clearLinked
          ? current.sessionKey
          : 'subj_${type.name}_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      evidence: evidence,
      isChild: isChildVal,
      ageGroup: isChildVal == true
          ? 'child'
          : (isChildVal == false ? 'adult' : current.ageGroup),
      ageYears: ageYears,
      linkedPersonId: clearLinked ? null : linkedPersonId,
    );
  }

  PersonRelationship? _relationshipFromText(String n) {
    if (RegExp(r'(?:ابني|ولدي)').hasMatch(n)) return PersonRelationship.son;
    if (RegExp(r'(?:بنتي|بنيتي)').hasMatch(n)) {
      return PersonRelationship.daughter;
    }
    if (RegExp(r'(?:ابني|ابنتي|طفلي|ولدي)').hasMatch(n)) {
      return PersonRelationship.child;
    }
    if (RegExp(r'(?:امي|أمي|والدتي)').hasMatch(n)) {
      return PersonRelationship.mother;
    }
    if (RegExp(r'(?:ابوي|أبوي|والدي|ابي|أبي)').hasMatch(n)) {
      return PersonRelationship.father;
    }
    if (RegExp(r'(?:زوجتي|مراتي)').hasMatch(n)) return PersonRelationship.wife;
    if (RegExp(r'(?:زوجي)').hasMatch(n)) return PersonRelationship.husband;
    return null;
  }

  String _extractPersonName(String n, PersonRelationship? rel) {
    if (rel != null) {
      final m1 = RegExp(
        r'(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي|بنتي|ولدي)\s+([^\s،,]+)',
      ).firstMatch(n);
      final g1 = m1?.group(1)?.trim() ?? '';
      if (g1.isNotEmpty && !_isRelWord(g1) && !_isHealthWord(g1)) return g1;
      final m2 = RegExp(r'([^\s،,]+)\s+(?:ابني|ابنتي)').firstMatch(n);
      final g2 = m2?.group(1)?.trim() ?? '';
      if (g2.isNotEmpty && !_isRelWord(g2) && !_isHealthWord(g2)) return g2;
    }
    final m3 = RegExp(r'(?:^|\s)([a-zA-Z\u0600-\u06FF]{2,})\s+عند').firstMatch(n);
    return m3?.group(1)?.trim() ?? '';
  }

  bool _isRelWord(String w) =>
      RegExp(r'^(?:ابني|ابنتي|امي|ابوي|زوجتي|عنده|عندها|حرار|الم)$').hasMatch(w);

  bool _isHealthWord(String w) => RegExp(
        r'^(?:عنده|عندها|حرار|حمى|دوخ|سعال|الم|ألم|صداع|تعب|تعبان|خايف)$',
      ).hasMatch(w);

  bool _isExplicitSelfPhrase(String n) =>
      RegExp(r'(?:نرجع\s*(?:ل|الى|إلي|الي)?\s*(?:الي|إلي|لي|إل|ال))').hasMatch(n) ||
      RegExp(r'(?:هذا\s*عني|مو\s*عن\s*(?:ابني|ابنتي|امي))').hasMatch(n);

  bool _isVagueThirdPerson(String n) =>
      RegExp(r'(?:^|\s)(?:هو|هي)\s+(?:تعبان|تعبان|خايف|عنده|عندها)').hasMatch(n);

  bool _nameEq(String? stored, String queryName) {
    if (stored == null) return false;
    final a = ArabicTextUtils.normalize(stored);
    final b = ArabicTextUtils.normalize(queryName);
    return a == b;
  }

  List<FamilyPersonProfile> _profilesForRelationship(
    List<FamilyPersonProfile> profiles,
    PersonRelationship rel,
  ) {
    return profiles.where((p) => _matchesRelationship(p.relationship, rel)).toList();
  }

  bool _isChildRel(PersonRelationship r) =>
      r == PersonRelationship.son ||
      r == PersonRelationship.daughter ||
      r == PersonRelationship.child;

  bool _matchesRelationship(PersonRelationship a, PersonRelationship b) {
    if (a == b) return true;
    if (b == PersonRelationship.child && _isChildRel(a)) return true;
    if (b == PersonRelationship.son &&
        (a == PersonRelationship.son || a == PersonRelationship.child)) {
      return true;
    }
    if (b == PersonRelationship.daughter &&
        (a == PersonRelationship.daughter || a == PersonRelationship.child)) {
      return true;
    }
    return false;
  }

  PersonRelationship? _typeToRelationship(HealthSubjectType type) {
    switch (type) {
      case HealthSubjectType.child:
        return PersonRelationship.child;
      case HealthSubjectType.mother:
        return PersonRelationship.mother;
      case HealthSubjectType.father:
        return PersonRelationship.father;
      case HealthSubjectType.spouse:
        return PersonRelationship.spouse;
      default:
        return null;
    }
  }
}
