import 'package:ghadeer_clinic/unified_brain/unified_brain_models.dart';

/// تحكيم مرشّحي السلطات — يحدد الأساسي مقابل السياقي مقابل المكبوت.
///
/// لا يملك قواعد طبية رقمية؛ يستهلك قرارات المرشّحين فقط.
class UnifiedBrainArbitrator {
  const UnifiedBrainArbitrator();

  /// أولوية أعلى = أسبق.
  static const Map<BrainAuthorityId, int> _basePriority = {
    BrainAuthorityId.safety10E: 1000,
    BrainAuthorityId.mentalCrisis: 990,
    BrainAuthorityId.followUp: 800,
    BrainAuthorityId.serviceEntity: 750,
    BrainAuthorityId.dental: 620,
    BrainAuthorityId.respiratory: 610,
    BrainAuthorityId.msk: 600,
    BrainAuthorityId.chronicClinical: 580,
    BrainAuthorityId.pregnancy: 560,
    BrainAuthorityId.adolescent: 540,
    BrainAuthorityId.clinicalKnowledge: 500,
    BrainAuthorityId.emotional: 400,
    BrainAuthorityId.dailyContext: 350,
    BrainAuthorityId.wellbeingPlanner: 340,
    BrainAuthorityId.activity: 330,
    BrainAuthorityId.goals: 320,
    BrainAuthorityId.personalization: 200,
    BrainAuthorityId.fallback: 1,
    BrainAuthorityId.none: 0,
  };

  UnifiedBrainResponsePlan arbitrate({
    required UnifiedBrainTurnContext turn,
    required List<UnifiedBrainCandidate> candidates,
    BrainContribution? primaryContribution,
    List<BrainContribution> contextualContributions = const [],
    bool safetyInvoked = false,
    bool mentalCrisisInvoked = false,
    bool fallbackUsed = false,
    bool serviceHandoff = false,
  }) {
    final active = candidates
        .where((c) => c.role != BrainAuthorityRole.suppressed)
        .toList(growable: false);

    final suppressed = candidates
        .where((c) => c.role == BrainAuthorityRole.suppressed)
        .map((c) => c.authority)
        .toList();

    // دورة خدمة/تحية: كبح المرشّحات السريرية اللاصقة.
    if (turn.isForeignToClinicalSessions) {
      final clinical = {
        BrainAuthorityId.pregnancy,
        BrainAuthorityId.dental,
        BrainAuthorityId.msk,
        BrainAuthorityId.respiratory,
        BrainAuthorityId.chronicClinical,
        BrainAuthorityId.adolescent,
      };
      for (final c in active) {
        if (clinical.contains(c.authority) &&
            c.mayHandleReason == 'sessionContinuation') {
          suppressed.add(c.authority);
        }
      }
    }

    BrainAuthorityId primary = BrainAuthorityId.none;
    final contextual = <BrainAuthorityId>[];

    if (mentalCrisisInvoked) {
      primary = BrainAuthorityId.mentalCrisis;
    } else if (safetyInvoked) {
      primary = BrainAuthorityId.safety10E;
    } else if (primaryContribution != null) {
      primary = primaryContribution.authority;
    } else if (active.isNotEmpty) {
      final sorted = [...active]
        ..sort((a, b) {
          final pa = a.priority != 0
              ? a.priority
              : (_basePriority[a.authority] ?? 0);
          final pb = b.priority != 0
              ? b.priority
              : (_basePriority[b.authority] ?? 0);
          final byP = pb.compareTo(pa);
          if (byP != 0) return byP;
          return a.authority.name.compareTo(b.authority.name);
        });
      primary = sorted.first.authority;
      for (final c in sorted.skip(1)) {
        if (c.role == BrainAuthorityRole.contextual ||
            c.role == BrainAuthorityRole.supportOnly ||
            c.role == BrainAuthorityRole.emotional) {
          if (!contextual.contains(c.authority)) {
            contextual.add(c.authority);
          }
        } else if (c.role == BrainAuthorityRole.primary) {
          // منافس أساسي → يُكبَت لصالح الفائز.
          if (!suppressed.contains(c.authority)) {
            suppressed.add(c.authority);
          }
        }
      }
    }

    for (final c in contextualContributions) {
      if (c.authority != primary && !contextual.contains(c.authority)) {
        contextual.add(c.authority);
      }
    }

    // ميزانية سؤال واحدة.
    String? question;
    var questionUsed = false;
    final questions = <_QuestionCandidate>[];
    if (primaryContribution?.clarificationQuestion != null &&
        primaryContribution!.clarificationQuestion!.trim().isNotEmpty) {
      questions.add(
        _QuestionCandidate(
          text: primaryContribution.clarificationQuestion!.trim(),
          rank: _questionRank(primaryContribution),
        ),
      );
    }
    for (final c in contextualContributions) {
      final q = c.clarificationQuestion?.trim();
      if (q != null && q.isNotEmpty) {
        questions.add(_QuestionCandidate(text: q, rank: _questionRank(c)));
      }
    }
    if (questions.isNotEmpty) {
      questions.sort((a, b) {
        final byR = b.rank.compareTo(a.rank);
        if (byR != 0) return byR;
        return a.text.compareTo(b.text);
      });
      question = questions.first.text;
      questionUsed = true;
    }

    final core = primaryContribution?.message.trim() ?? '';
    final message = _composeOneMessage(
      core: core,
      question: question,
      mentalCrisis: mentalCrisisInvoked,
      safety: safetyInvoked,
    );

    return UnifiedBrainResponsePlan(
      primaryAuthority: primary,
      contextualAuthorities: List.unmodifiable(contextual),
      suppressedAuthorities: List.unmodifiable(suppressed.toSet().toList()
        ..sort((a, b) => a.name.compareTo(b.name))),
      safetyMode: safetyInvoked,
      mentalCrisisMode: mentalCrisisInvoked,
      coreAnswer: core,
      clarificationQuestion: question,
      questionBudgetUsed: questionUsed,
      serviceHandoff: serviceHandoff,
      fallbackUsed: fallbackUsed,
      message: message,
    );
  }

  /// يصنّف مرشّحاً: أساسي / سياقي / مكبوت حسب الدورة والإشارات.
  UnifiedBrainCandidate classifyCandidate({
    required BrainAuthorityId authority,
    required UnifiedBrainTurnContext turn,
    required bool mayHandle,
    String mayHandleReason = 'explicitIntent',
  }) {
    if (!mayHandle) {
      return UnifiedBrainCandidate(
        authority: authority,
        role: BrainAuthorityRole.suppressed,
        priority: 0,
        mayHandleReason: 'notRelevant',
        suppressionReason: 'notRelevant',
      );
    }

    if (turn.isForeignToClinicalSessions &&
        _isClinicalPack(authority) &&
        mayHandleReason == 'sessionContinuation') {
      return UnifiedBrainCandidate(
        authority: authority,
        role: BrainAuthorityRole.suppressed,
        priority: 0,
        mayHandleReason: 'foreignTurn',
        suppressionReason: 'foreignTurn',
      );
    }

    // أزمة / سلامة تُعالَج خارجياً — هنا تصنيف الحزم.
    final role = _roleFor(authority, turn);
    final priority = _priorityFor(authority, turn, role);
    return UnifiedBrainCandidate(
      authority: authority,
      role: role,
      priority: priority,
      mayHandleReason: mayHandleReason,
    );
  }

  BrainAuthorityRole _roleFor(
    BrainAuthorityId authority,
    UnifiedBrainTurnContext turn,
  ) {
    // حامل + سعال → تنفسي أساسي، حمل سياقي
    if (authority == BrainAuthorityId.pregnancy) {
      if (turn.hasMskCue ||
          turn.hasRespiratoryCue ||
          turn.hasDentalCue ||
          turn.isServiceOrNavigationIntent) {
        return BrainAuthorityRole.contextual;
      }
      if (turn.primaryIntent == BrainPrimaryIntent.pregnancyCare) {
        return BrainAuthorityRole.primary;
      }
      return BrainAuthorityRole.contextual;
    }

    if (authority == BrainAuthorityId.adolescent) {
      if (turn.hasDentalCue ||
          turn.hasMskCue ||
          turn.hasRespiratoryCue ||
          turn.hasChronicCue) {
        return BrainAuthorityRole.contextual;
      }
      if (turn.primaryIntent == BrainPrimaryIntent.adolescentLifeConcern) {
        return BrainAuthorityRole.primary;
      }
      return BrainAuthorityRole.contextual;
    }

    if (authority == BrainAuthorityId.emotional) {
      return BrainAuthorityRole.emotional;
    }

    if (authority == BrainAuthorityId.serviceEntity) {
      return BrainAuthorityRole.service;
    }

    if (authority == BrainAuthorityId.followUp) {
      return BrainAuthorityRole.followUp;
    }

    // شكاوى سريرية متعددة: أولوية تنفسي > أسنان > مسك > مزمن عند التعادل النسبي
    if (turn.hasRespiratoryCue && authority == BrainAuthorityId.respiratory) {
      return BrainAuthorityRole.primary;
    }
    if (turn.hasDentalCue && authority == BrainAuthorityId.dental) {
      return BrainAuthorityRole.primary;
    }
    if (turn.hasMskCue && authority == BrainAuthorityId.msk) {
      return BrainAuthorityRole.primary;
    }
    if (turn.hasChronicCue && authority == BrainAuthorityId.chronicClinical) {
      return BrainAuthorityRole.primary;
    }

    return BrainAuthorityRole.primary;
  }

  int _priorityFor(
    BrainAuthorityId authority,
    UnifiedBrainTurnContext turn,
    BrainAuthorityRole role,
  ) {
    var base = _basePriority[authority] ?? 0;
    if (role == BrainAuthorityRole.contextual) {
      base = (base * 0.4).round();
    }
    if (role == BrainAuthorityRole.emotional) {
      base = 150;
    }
    // نية خدمة مباشرة تفوز على خلفية سريرية.
    if (turn.isServiceOrNavigationIntent &&
        authority == BrainAuthorityId.serviceEntity) {
      base = 900;
    }
    if (turn.isExplicitFollowUp && authority == BrainAuthorityId.followUp) {
      base = 920;
    }
    return base;
  }

  bool _isClinicalPack(BrainAuthorityId id) =>
      id == BrainAuthorityId.pregnancy ||
      id == BrainAuthorityId.dental ||
      id == BrainAuthorityId.msk ||
      id == BrainAuthorityId.respiratory ||
      id == BrainAuthorityId.chronicClinical ||
      id == BrainAuthorityId.adolescent;

  int _questionRank(BrainContribution c) {
    // SAFETY-CHANGING > SUBJECT > ROUTING > ACTION > PERSONALIZATION
    if (c.safetyDeferred || c.mentalSafetyDeferred) return 100;
    if (c.role == BrainAuthorityRole.safety ||
        c.role == BrainAuthorityRole.safetyOnly) {
      return 90;
    }
    if (c.clarificationQuestion != null &&
        (c.clarificationQuestion!.contains('شخص') ||
            c.clarificationQuestion!.contains('الك') ||
            c.clarificationQuestion!.contains('ابن'))) {
      return 80;
    }
    if (c.role == BrainAuthorityRole.primary) return 60;
    if (c.role == BrainAuthorityRole.contextual) return 40;
    return 20;
  }

  String _composeOneMessage({
    required String core,
    String? question,
    required bool mentalCrisis,
    required bool safety,
  }) {
    // رسالة واحدة فقط — لا لصق ردود متعددة.
    final buf = StringBuffer();
    if (core.isNotEmpty) {
      buf.write(core);
    }
    if (question != null &&
        question.isNotEmpty &&
        !core.contains(question)) {
      if (buf.isNotEmpty) buf.writeln();
      buf.write(question);
    }
    return buf.toString().trim();
  }
}

class _QuestionCandidate {
  const _QuestionCandidate({required this.text, required this.rank});
  final String text;
  final int rank;
}
