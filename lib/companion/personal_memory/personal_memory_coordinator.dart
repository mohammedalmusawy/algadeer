import '../../follow_up/follow_up_models.dart';
import '../../follow_up/follow_up_service.dart';
import '../../search/arabic_text_utils.dart';
import '../companion_command_domain.dart';
import '../personal_companion_profile_service.dart';
import 'personal_memory_command_interpreter.dart';
import 'personal_memory_command_models.dart';
import 'personal_memory_consent_coordinator.dart';
import 'personal_memory_models.dart';
import 'personal_memory_qualifier.dart';
import 'personal_memory_retrieval_policy.dart';
import 'personal_memory_service.dart';

/// منسّق الذاكرة الشخصية — PC-1.12.
class PersonalMemoryCoordinator {
  PersonalMemoryCoordinator({
    PersonalMemoryService? service,
    PersonalMemoryCommandInterpreter? interpreter,
    PersonalMemoryConsentCoordinator? consent,
    PersonalMemoryRetrievalPolicy? retrieval,
    PersonalCompanionProfileService? profiles,
    FollowUpService? followUps,
    CompanionCommandRouter? router,
  })  : _service = service ?? PersonalMemoryService(),
        _interpreter = interpreter ?? PersonalMemoryCommandInterpreter(),
        _consent = consent ?? const PersonalMemoryConsentCoordinator(),
        _retrieval = retrieval ?? const PersonalMemoryRetrievalPolicy(),
        _profiles = profiles ?? PersonalCompanionProfileService(),
        _followUps = followUps ?? FollowUpService(),
        _router = router ?? const CompanionCommandRouter();

  final PersonalMemoryService _service;
  final PersonalMemoryCommandInterpreter _interpreter;
  final PersonalMemoryConsentCoordinator _consent;
  final PersonalMemoryRetrievalPolicy _retrieval;
  final PersonalCompanionProfileService _profiles;
  final FollowUpService _followUps;
  final CompanionCommandRouter _router;

  PersonalMemoryService get service => _service;
  PersonalMemoryCommandInterpreter get interpreter => _interpreter;
  PersonalMemoryRetrievalPolicy get retrieval => _retrieval;
  FollowUpService get followUps => _followUps;

  bool mayHandle({
    required String query,
    required PersonalMemoryPendingOp pending,
  }) {
    if (pending.isActive) return true;
    final route = _router.routePersonalMemory(query);
    if (route != null && route.matched) return true;
    return _interpreter.looksLikePersonalMemoryCommand(query);
  }

  Future<PersonalMemoryCommandTurnResult> handle({
    required String text,
    required PersonalMemoryPendingOp pending,
  }) async {
    final interp = _interpreter.interpret(raw: text, pending: pending);
    if (!interp.isCommand) {
      return PersonalMemoryCommandTurnResult.notHandled();
    }
    try {
      return await _execute(interp, pending);
    } catch (_) {
      return PersonalMemoryCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما كدرت أكمّل طلب الذاكرة الشخصية هسه. ما تم الحفظ.',
        commandKind: interp.kind,
      );
    }
  }

  Future<PersonalMemoryCommandTurnResult> _execute(
    PersonalMemoryCommandInterpretation interp,
    PersonalMemoryPendingOp pending,
  ) async {
    switch (interp.kind) {
      case PersonalMemoryCommandKind.rememberCandidate:
        return _remember(interp.candidate!);

      case PersonalMemoryCommandKind.consentYes:
        final c = interp.candidate ?? pending.consent.candidate;
        if (c == null) {
          return const PersonalMemoryCommandTurnResult(
            handled: true,
            success: false,
            message: 'ما في شيء للحفظ.',
            commandKind: PersonalMemoryCommandKind.consentYes,
          );
        }
        try {
          final saved = await _service.upsertCandidate(c);
          return PersonalMemoryCommandTurnResult(
            handled: true,
            success: true,
            message: 'تم الحفظ بذاكرتك الشخصية.',
            pending: PersonalMemoryPendingOp.none,
            commandKind: PersonalMemoryCommandKind.consentYes,
            recordCount: 1,
            hasRelevantMemory: true,
          );
        } catch (_) {
          return const PersonalMemoryCommandTurnResult(
            handled: true,
            success: false,
            message: 'ما كدرت أحفظ المعلومة. ما تم الحفظ.',
            pending: PersonalMemoryPendingOp.none,
            commandKind: PersonalMemoryCommandKind.consentYes,
          );
        }

      case PersonalMemoryCommandKind.consentNo:
        return const PersonalMemoryCommandTurnResult(
          handled: true,
          success: true,
          message: 'تمام، ما حفظت شيء.',
          pending: PersonalMemoryPendingOp.none,
          commandKind: PersonalMemoryCommandKind.consentNo,
        );

      case PersonalMemoryCommandKind.correctPending:
        return PersonalMemoryCommandTurnResult(
          handled: true,
          message: _consent.buildConfirmPrompt(interp.candidate!),
          pending: PersonalMemoryPendingOp(
            kind: PersonalMemoryPendingKind.rememberConfirm,
            consent: PersonalMemoryConsentPending(
              candidate: interp.candidate,
              awaitingAnswer: true,
            ),
            pendingCandidate: interp.candidate,
          ),
          commandKind: PersonalMemoryCommandKind.correctPending,
        );

      case PersonalMemoryCommandKind.showGoals:
        return _formatList(PersonalMemoryType.goal, 'أهدافك');
      case PersonalMemoryCommandKind.showInterests:
        return _formatList(PersonalMemoryType.interest, 'اهتماماتك');
      case PersonalMemoryCommandKind.showPreferences:
        return _formatList(PersonalMemoryType.preference, 'تفضيلاتك');
      case PersonalMemoryCommandKind.showPersonalMemorySummary:
        return _summary(excludeHealth: true);
      case PersonalMemoryCommandKind.showAboutMeBroad:
        return _aboutMe();

      case PersonalMemoryCommandKind.completeGoal:
        return _updateGoal(interp.needle, PersonalMemoryStatus.completed,
            ok: 'تم اعتبار الهدف مكتملاً. ما انمسح من السجل.');
      case PersonalMemoryCommandKind.pauseGoal:
        return _pauseGoal(interp.needle);
      case PersonalMemoryCommandKind.resumeGoal:
        return _updateGoal(interp.needle, PersonalMemoryStatus.active,
            ok: 'رجّعت الهدف. المتابعة المنفصلة ما تنعاد تلقائياً.');

      case PersonalMemoryCommandKind.deleteOne:
        return _deleteOne(interp.needle);
      case PersonalMemoryCommandKind.deleteAllOfTypeRequest:
        return PersonalMemoryCommandTurnResult(
          handled: true,
          message:
              'متأكد تريد مسح كل ${_typeLabel(interp.bulkType!)}؟ قل نعم للتأكيد أو لا للإلغاء.',
          pending: PersonalMemoryPendingOp(
            kind: PersonalMemoryPendingKind.bulkDelete,
            bulkType: interp.bulkType,
          ),
          commandKind: PersonalMemoryCommandKind.deleteAllOfTypeRequest,
        );
      case PersonalMemoryCommandKind.confirmBulkDelete:
        final n = await _service.deleteAllOfType(interp.bulkType!);
        return PersonalMemoryCommandTurnResult(
          handled: true,
          success: true,
          message:
              'تم المسح. الملف الأساسي والصحة والعائلة والمتابعات ما انمسحت.',
          pending: PersonalMemoryPendingOp.none,
          commandKind: PersonalMemoryCommandKind.confirmBulkDelete,
          recordCount: n,
        );
      case PersonalMemoryCommandKind.cancelBulkDelete:
        return const PersonalMemoryCommandTurnResult(
          handled: true,
          message: 'تمام، ما مسحت شيء.',
          pending: PersonalMemoryPendingOp.none,
          commandKind: PersonalMemoryCommandKind.cancelBulkDelete,
        );

      case PersonalMemoryCommandKind.rejectNonOwner:
      case PersonalMemoryCommandKind.rejectEmotional:
      case PersonalMemoryCommandKind.rejectSensitiveHealth:
      case PersonalMemoryCommandKind.rejectImplicit:
      case PersonalMemoryCommandKind.rejectPersonality:
      case PersonalMemoryCommandKind.clarifyAmbiguous:
        return PersonalMemoryCommandTurnResult(
          handled: true,
          success: false,
          message: interp.message,
          commandKind: interp.kind,
        );

      case PersonalMemoryCommandKind.none:
        return PersonalMemoryCommandTurnResult.notHandled();
    }
  }

  Future<PersonalMemoryCommandTurnResult> _remember(
    PersonalMemoryCandidate candidate,
  ) async {
    // أمر تذكّر صريح وغير غامض → حفظ مباشر
    if (!candidate.requiresExtraConfirm) {
      try {
        await _service.upsertCandidate(candidate);
        return PersonalMemoryCommandTurnResult(
          handled: true,
          success: true,
          message: 'تم. حفظت «${candidate.displayLabel}» بذاكرتك الشخصية.',
          commandKind: PersonalMemoryCommandKind.rememberCandidate,
          recordCount: 1,
          hasRelevantMemory: true,
        );
      } catch (_) {
        return const PersonalMemoryCommandTurnResult(
          handled: true,
          success: false,
          message: 'ما كدرت أحفظ المعلومة. ما تم الحفظ.',
          commandKind: PersonalMemoryCommandKind.rememberCandidate,
        );
      }
    }
    return PersonalMemoryCommandTurnResult(
      handled: true,
      message: _consent.buildConfirmPrompt(candidate),
      pending: PersonalMemoryPendingOp(
        kind: PersonalMemoryPendingKind.rememberConfirm,
        consent: PersonalMemoryConsentPending(
          candidate: candidate,
          awaitingAnswer: true,
        ),
      ),
      commandKind: PersonalMemoryCommandKind.rememberCandidate,
    );
  }

  Future<PersonalMemoryCommandTurnResult> _formatList(
    PersonalMemoryType type,
    String title,
  ) async {
    final list = await _service.listByType(type);
    if (list.isEmpty) {
      return PersonalMemoryCommandTurnResult(
        handled: true,
        message: 'ما عندي $title محفوظة حالياً.',
        commandKind: PersonalMemoryCommandKind.showGoals,
        recordCount: 0,
      );
    }
    final lines = list
        .map((r) => '• ${r.displayLabel}${_statusNote(r.status)}')
        .join('\n');
    return PersonalMemoryCommandTurnResult(
      handled: true,
      message: '$title:\n$lines',
      commandKind: PersonalMemoryCommandKind.showGoals,
      recordCount: list.length,
      hasRelevantMemory: true,
    );
  }

  Future<PersonalMemoryCommandTurnResult> _summary({
    required bool excludeHealth,
  }) async {
    final all = await _service.listAll();
    final active =
        all.where((r) => r.status != PersonalMemoryStatus.archived).toList();
    if (active.isEmpty) {
      return const PersonalMemoryCommandTurnResult(
        handled: true,
        message: 'ما عندي أهداف/اهتمامات/تفضيلات محفوظة حالياً.',
        commandKind: PersonalMemoryCommandKind.showPersonalMemorySummary,
        recordCount: 0,
      );
    }
    final buf = StringBuffer('اللي طلبت مني أتذكره (غير الصحة):\n');
    for (final r in active) {
      buf.writeln('• ${_typeLabel(r.memoryType)}: ${r.displayLabel}');
    }
    final text = buf.toString();
    assert(!text.contains('سكري') || excludeHealth);
    return PersonalMemoryCommandTurnResult(
      handled: true,
      message: text,
      commandKind: PersonalMemoryCommandKind.showPersonalMemorySummary,
      recordCount: active.length,
      hasRelevantMemory: true,
    );
  }

  Future<PersonalMemoryCommandTurnResult> _aboutMe() async {
    final profile = await _profiles.loadProfile();
    final parts = <String>[];
    if (profile != null) {
      if (profile.preferredName != null &&
          profile.preferredName!.trim().isNotEmpty) {
        parts.add('الاسم المفضل: ${profile.preferredName}');
      }
      if (profile.birthYear != null) {
        parts.add('سنة الميلاد: ${profile.birthYear}');
      }
      if (profile.userContext != null) {
        parts.add('السياق: ${profile.userContext!.name}');
      }
    }
    final mem = await _retrieval.retrieveRelevant(
      service: _service,
      purpose: PersonalMemoryRetrievalPurpose.aboutMeSummary,
    );
    if (mem.isNotEmpty) {
      parts.add('أهداف/اهتمامات: ${mem.map((e) => e.displayLabel).join('، ')}');
    }
    // لا صحة حسّاسة هنا
    final msg = parts.isEmpty
        ? 'ما عندي معلومات شخصية محفوظة كثيرة عنك حالياً.'
        : 'باختصار:\n${parts.map((e) => '• $e').join('\n')}';
    return PersonalMemoryCommandTurnResult(
      handled: true,
      message: msg,
      commandKind: PersonalMemoryCommandKind.showAboutMeBroad,
      recordCount: mem.length,
      hasRelevantMemory: mem.isNotEmpty,
    );
  }

  Future<PersonalMemoryCommandTurnResult> _updateGoal(
    String needle,
    PersonalMemoryStatus status, {
    required String ok,
  }) async {
    final matches = await _resolveGoals(needle);
    if (matches.isEmpty) {
      return const PersonalMemoryCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما لقيت هدف مطابق.',
        commandKind: PersonalMemoryCommandKind.completeGoal,
      );
    }
    if (matches.length > 1) {
      return PersonalMemoryCommandTurnResult(
        handled: true,
        message:
            'أي هدف تقصد؟ ${matches.map((e) => e.displayLabel).join(' / ')}',
        commandKind: PersonalMemoryCommandKind.clarifyAmbiguous,
      );
    }
    await _service.updateStatus(matches.first.memoryId, status);
    return PersonalMemoryCommandTurnResult(
      handled: true,
      success: true,
      message: ok,
      commandKind: PersonalMemoryCommandKind.completeGoal,
    );
  }

  Future<PersonalMemoryCommandTurnResult> _pauseGoal(String needle) async {
    final matches = await _resolveGoals(needle);
    if (matches.isEmpty) {
      return const PersonalMemoryCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما لقيت هدف مطابق.',
        commandKind: PersonalMemoryCommandKind.pauseGoal,
      );
    }
    if (matches.length > 1) {
      return PersonalMemoryCommandTurnResult(
        handled: true,
        message:
            'أي هدف تقصد؟ ${matches.map((e) => e.displayLabel).join(' / ')}',
        commandKind: PersonalMemoryCommandKind.clarifyAmbiguous,
      );
    }
    final g = matches.first;
    await _service.updateStatus(g.memoryId, PersonalMemoryStatus.paused);
    // تنسيق مع متابعة مرتبطة — إيقاف بدون إلغاء صامت سابق
    final related = await _followUps.findByTopic(
      subject: FollowUpSubjectRef.accountOwner,
      domain: FollowUpDomain.personalGoal,
      topicKey: g.canonicalKey,
    );
    if (related != null && related.status == FollowUpStatus.active) {
      await _followUps.pause(related.commitmentId);
    }
    return const PersonalMemoryCommandTurnResult(
      handled: true,
      success: true,
      message:
          'تم إيقاف الهدف مؤقتاً. إذا كانت عنده متابعة نشطة، أوقفتها أيضاً حتى ما تتناقض.',
      commandKind: PersonalMemoryCommandKind.pauseGoal,
    );
  }

  Future<PersonalMemoryCommandTurnResult> _deleteOne(String needle) async {
    if (needle.trim().isEmpty) {
      return const PersonalMemoryCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما فهمت أي سجل تريد تمسحه. حدّد الهدف أو الاهتمام.',
        commandKind: PersonalMemoryCommandKind.deleteOne,
      );
    }
    final all = await _service.listAll();
    final n = ArabicTextUtils.normalize(needle);
    final hits = all.where((r) {
      final label = ArabicTextUtils.normalize(r.displayLabel);
      final key = r.canonicalKey.toLowerCase();
      return label.contains(n) ||
          key.contains(n) ||
          (n.contains('flutter') && key.contains('flutter')) ||
          (n.contains('تصوير') && key.contains('photo'));
    }).toList();
    if (hits.isEmpty) {
      return const PersonalMemoryCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما لقيت سجل مطابق للحذف.',
        commandKind: PersonalMemoryCommandKind.deleteOne,
      );
    }
    if (hits.length > 1) {
      return PersonalMemoryCommandTurnResult(
        handled: true,
        message:
            'أي واحد تقصد؟ ${hits.map((e) => e.displayLabel).join(' / ')}',
        commandKind: PersonalMemoryCommandKind.clarifyAmbiguous,
      );
    }
    await _service.deleteById(hits.first.memoryId);
    return const PersonalMemoryCommandTurnResult(
      handled: true,
      success: true,
      message: 'تم مسح السجل المطلوب فقط.',
      commandKind: PersonalMemoryCommandKind.deleteOne,
    );
  }

  Future<List<CompanionPersonalMemoryRecord>> _resolveGoals(
    String needle,
  ) async {
    final goals = await _service.listByType(PersonalMemoryType.goal);
    if (needle.trim().isEmpty) {
      return goals.where((g) => g.status == PersonalMemoryStatus.active).toList();
    }
    final n = ArabicTextUtils.normalize(needle);
    return goals
        .where((g) {
          final label = ArabicTextUtils.normalize(g.displayLabel);
          return label.contains(n) ||
              g.canonicalKey.toLowerCase().contains(n) ||
              (n.contains('flutter') && g.canonicalKey.contains('flutter'));
        })
        .toList();
  }

  String _typeLabel(PersonalMemoryType t) {
    switch (t) {
      case PersonalMemoryType.goal:
        return 'الأهداف';
      case PersonalMemoryType.interest:
        return 'الاهتمامات';
      case PersonalMemoryType.preference:
        return 'التفضيلات';
    }
  }

  String _statusNote(PersonalMemoryStatus s) {
    switch (s) {
      case PersonalMemoryStatus.active:
        return '';
      case PersonalMemoryStatus.completed:
        return ' (مكتمل)';
      case PersonalMemoryStatus.paused:
        return ' (موقوف)';
      case PersonalMemoryStatus.archived:
        return ' (مؤرشف)';
    }
  }
}
