import 'follow_up_command_interpreter.dart';
import 'follow_up_command_models.dart';
import 'follow_up_due_policy.dart';
import 'follow_up_eligibility_policy.dart';
import 'follow_up_models.dart';
import 'follow_up_response_policy.dart';
import 'follow_up_scheduler_contract.dart';
import 'follow_up_service.dart';

/// منسّق أوامر المتابعة الموحّدة — PC-1.11.
class FollowUpCoordinator {
  FollowUpCoordinator({
    FollowUpService? service,
    FollowUpCommandInterpreter? interpreter,
    FollowUpResponsePolicy? responses,
    FollowUpEligibilityPolicy? eligibility,
    FollowUpSchedulerContract? scheduler,
  })  : _service = service ?? FollowUpService(),
        _interpreter = interpreter ?? const FollowUpCommandInterpreter(),
        _responses = responses ?? const FollowUpResponsePolicy(),
        _eligibility = eligibility ?? const FollowUpEligibilityPolicy(),
        _scheduler = scheduler ?? const NoOpFollowUpScheduler();

  final FollowUpService _service;
  final FollowUpCommandInterpreter _interpreter;
  final FollowUpResponsePolicy _responses;
  final FollowUpEligibilityPolicy _eligibility;
  final FollowUpSchedulerContract _scheduler;

  FollowUpService get service => _service;
  FollowUpCommandInterpreter get interpreter => _interpreter;
  FollowUpSchedulerContract get scheduler => _scheduler;

  bool mayHandle({
    required String query,
    required FollowUpPendingOp pending,
  }) {
    if (pending.isActive) return true;
    return _interpreter.looksLikeFollowUpCommand(query);
  }

  Future<FollowUpCommandTurnResult> handle({
    required String text,
    required FollowUpPendingOp pending,
    FollowUpSubjectRef currentSubject = FollowUpSubjectRef.accountOwner,
    bool preferUrgentSafety = false,
    bool preferMentalSafety = false,
  }) async {
    if (preferUrgentSafety) {
      return const FollowUpCommandTurnResult(
        handled: false,
        message: '',
        deferToUrgentSafety: true,
      );
    }
    if (preferMentalSafety) {
      return const FollowUpCommandTurnResult(
        handled: false,
        message: '',
        deferToMentalSafety: true,
      );
    }

    final interp = _interpreter.interpret(raw: text, pending: pending);
    if (!interp.isCommand) {
      return FollowUpCommandTurnResult.notHandled();
    }

    try {
      return await _execute(
        interp: interp,
        pending: pending,
        currentSubject: currentSubject,
      );
    } catch (_) {
      return FollowUpCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما كدرت أكمّل طلب المتابعة هسه. ما تم الحفظ.',
        commandKind: interp.kind,
      );
    }
  }

  Future<FollowUpCommandTurnResult> _execute({
    required FollowUpCommandInterpretation interp,
    required FollowUpPendingOp pending,
    required FollowUpSubjectRef currentSubject,
  }) async {
    switch (interp.kind) {
      case FollowUpCommandKind.deferToUrgentSafety:
        return const FollowUpCommandTurnResult(
          handled: false,
          message: '',
          deferToUrgentSafety: true,
        );
      case FollowUpCommandKind.deferToMentalSafety:
        return const FollowUpCommandTurnResult(
          handled: false,
          message: '',
          deferToMentalSafety: true,
        );
      case FollowUpCommandKind.deferToEntityIntent:
        return const FollowUpCommandTurnResult(
          handled: false,
          message: '',
          deferToEntityIntent: true,
        );

      case FollowUpCommandKind.listCommitments:
        return _list(currentSubject);

      case FollowUpCommandKind.createCommitment:
        return _beginCreate(interp, currentSubject);

      case FollowUpCommandKind.consentYes:
        return _persistFromPending(pending);

      case FollowUpCommandKind.consentNo:
      case FollowUpCommandKind.consentLater:
        return FollowUpCommandTurnResult(
          handled: true,
          success: true,
          message: 'تمام، ما فعّلت متابعة لهذا الموضوع.',
          pending: FollowUpPendingOp.none,
          commandKind: interp.kind,
        );

      case FollowUpCommandKind.correctPendingTopic:
        final next = FollowUpPendingOp(
          kind: FollowUpPendingKind.createConsent,
          domain: interp.domain ?? pending.domain,
          topicKey: interp.correctedTopicKey ?? interp.topicKey,
          displayTopic: interp.displayTopic,
          timingIntent: pending.timingIntent,
          subjectKind: pending.subjectKind,
          persistentPersonId: pending.persistentPersonId,
        );
        return FollowUpCommandTurnResult(
          handled: true,
          message:
              'تمام، تقصد ${next.displayTopic}. '
              'تحب أسجّل متابعة لهذا الموضوع؟',
          pending: next,
          commandKind: FollowUpCommandKind.correctPendingTopic,
        );

      case FollowUpCommandKind.pauseCommitment:
        return _mutateByTopic(
          interp,
          currentSubject,
          (id) => _service.pause(id),
          ok: 'تم إيقاف المتابعة. ما راح أرجع للموضوع تلقائياً.',
        );

      case FollowUpCommandKind.resumeCommitment:
        return _mutateByTopic(
          interp,
          currentSubject,
          (id) => _service.resume(id),
          ok: 'رجعت المتابعة نشطة. أكدر أتذكر نرجع للموضوع من ترجع للغدير.',
        );

      case FollowUpCommandKind.completeCommitment:
        return _mutateByTopic(
          interp,
          currentSubject,
          (id) => _service.complete(id),
          ok: 'تم اعتبار الموضوع مكتملاً. ما راح يظهر تلقائياً.',
        );

      case FollowUpCommandKind.cancelCommitment:
        return _mutateByTopic(
          interp,
          currentSubject,
          (id) => _service.cancel(id),
          ok: 'تم إلغاء المتابعة.',
        );

      case FollowUpCommandKind.deleteCommitment:
        return _deleteByTopic(interp, currentSubject);

      case FollowUpCommandKind.stopAsking:
        return _stopAsking(interp, currentSubject);

      case FollowUpCommandKind.rejectIneligible:
        return FollowUpCommandTurnResult(
          handled: true,
          success: false,
          message: interp.message,
          commandKind: interp.kind,
        );

      case FollowUpCommandKind.none:
        return FollowUpCommandTurnResult.notHandled();
    }
  }

  Future<FollowUpCommandTurnResult> _beginCreate(
    FollowUpCommandInterpretation interp,
    FollowUpSubjectRef currentSubject,
  ) async {
    final domain = interp.domain ?? FollowUpDomain.generalCommitment;
    if (!_eligibility.mayCreateForSubject(
      subject: currentSubject,
      domain: domain,
    )) {
      return const FollowUpCommandTurnResult(
        handled: true,
        success: false,
        message:
            'متابعة هذا الموضوع لهذا الشخص لسه مو مفعّلة. '
            'ذاكرة الصحة العائلية وحدها ما تفوّض متابعة تلقائية.',
        commandKind: FollowUpCommandKind.rejectIneligible,
      );
    }

    // موافقة صريحة قبل التفعيل إن لم تكن أمر تأكيد مباشر جداً
    final pending = FollowUpPendingOp(
      kind: FollowUpPendingKind.createConsent,
      domain: domain,
      topicKey: interp.topicKey ?? domain.name,
      displayTopic: interp.displayTopic,
      timingIntent: interp.timingIntent,
      subjectKind: currentSubject.kind,
      persistentPersonId: currentSubject.persistentPersonId,
    );

    return FollowUpCommandTurnResult(
      handled: true,
      message:
          'تحب أسجّل متابعة لـ${interp.displayTopic.isNotEmpty ? interp.displayTopic : "هذا الموضوع"}؟\n'
          '${_responses.capabilityLimitNote(interp.timingIntent)}',
      pending: pending,
      commandKind: FollowUpCommandKind.createCommitment,
    );
  }

  Future<FollowUpCommandTurnResult> _persistFromPending(
    FollowUpPendingOp pending,
  ) async {
    if (pending.domain == null || pending.topicKey == null) {
      return const FollowUpCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما في موضوع واضح للمتابعة.',
        commandKind: FollowUpCommandKind.consentYes,
      );
    }
    try {
      final notBefore = pending.timingIntent == FollowUpTimingIntent.tomorrow
          ? DateTime.now().add(const Duration(hours: 20))
          : null;
      final c = await _service.create(
        subject: pending.subjectRef,
        domain: pending.domain!,
        topicKey: pending.topicKey!,
        displayTopic: pending.displayTopic,
        permission: FollowUpPermissionState.granted,
        status: FollowUpStatus.active,
        timing: pending.timingIntent,
        notBeforeAt: notBefore,
      );
      // لا ندّعي جدولة — NoOp فقط.
      await _scheduler.enqueue(
        FollowUpSchedulerSnapshot(
          commitmentId: c.commitmentId,
          subjectKind: c.subjectRef.kind.name,
          status: c.status.name,
          permissionState: c.permissionState.name,
          timingIntent: c.timingIntent.name,
          notBeforeAt: c.notBeforeAt,
          dueWindow: c.dueWindow,
        ),
      );
      return FollowUpCommandTurnResult(
        handled: true,
        success: true,
        message: _responses.createdAck(c: c, honestCapability: true),
        pending: FollowUpPendingOp.none,
        commandKind: FollowUpCommandKind.consentYes,
      );
    } catch (_) {
      return const FollowUpCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما كدرت أحفظ المتابعة. ما تم الحفظ.',
        pending: FollowUpPendingOp.none,
        commandKind: FollowUpCommandKind.consentYes,
      );
    }
  }

  Future<FollowUpCommandTurnResult> _list(FollowUpSubjectRef subject) async {
    final active = await _service.listActive(subject: subject);
    if (active.isEmpty) {
      return const FollowUpCommandTurnResult(
        handled: true,
        message: 'ما عندي متابعات نشطة حالياً.',
        commandKind: FollowUpCommandKind.listCommitments,
      );
    }
    final lines = active
        .map((c) => _responses.listLine(c, minimizeHealth: true))
        .join('\n');
    final text = 'هذول المتابعات النشطة:\n$lines';
    // لا IDs داخلية
    assert(!text.contains('fu_'));
    return FollowUpCommandTurnResult(
      handled: true,
      message: text,
      commandKind: FollowUpCommandKind.listCommitments,
    );
  }

  Future<FollowUpCommandTurnResult> _mutateByTopic(
    FollowUpCommandInterpretation interp,
    FollowUpSubjectRef subject,
    Future<FollowUpCommitment?> Function(String id) op, {
    required String ok,
  }) async {
    final c = await _resolveTarget(interp, subject);
    if (c == null) {
      return FollowUpCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما لقيت متابعة مطابقة لهذا الموضوع.',
        commandKind: interp.kind,
      );
    }
    await op(c.commitmentId);
    return FollowUpCommandTurnResult(
      handled: true,
      success: true,
      message: ok,
      commandKind: interp.kind,
    );
  }

  Future<FollowUpCommandTurnResult> _deleteByTopic(
    FollowUpCommandInterpretation interp,
    FollowUpSubjectRef subject,
  ) async {
    final c = await _resolveTarget(interp, subject);
    if (c == null) {
      return FollowUpCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما لقيت متابعة للحذف.',
        commandKind: FollowUpCommandKind.deleteCommitment,
      );
    }
    await _service.deleteCommitment(c.commitmentId);
    return const FollowUpCommandTurnResult(
      handled: true,
      success: true,
      message:
          'تم مسح سجل المتابعة فقط. ما انمسح التشخيص ولا ملف الصحة ولا ملف الشخص.',
      commandKind: FollowUpCommandKind.deleteCommitment,
    );
  }

  Future<FollowUpCommandTurnResult> _stopAsking(
    FollowUpCommandInterpretation interp,
    FollowUpSubjectRef subject,
  ) async {
    final specific = await _resolveTarget(interp, subject);
    if (specific != null) {
      await _service.pause(specific.commitmentId);
      return const FollowUpCommandTurnResult(
        handled: true,
        success: true,
        message: 'تمام، ما راح أسألك عن هذا الموضوع بعد.',
        commandKind: FollowUpCommandKind.stopAsking,
      );
    }
    final active = await _service.listActive(subject: subject);
    if (active.isEmpty) {
      return const FollowUpCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما عندي متابعة نشطة لأوقف سؤالها.',
        commandKind: FollowUpCommandKind.stopAsking,
      );
    }
    for (final c in active) {
      await _service.pause(c.commitmentId);
    }
    return const FollowUpCommandTurnResult(
      handled: true,
      success: true,
      message: 'تمام، ما راح أسألك عن المتابعات النشطة بعد.',
      commandKind: FollowUpCommandKind.stopAsking,
    );
  }

  Future<FollowUpCommitment?> _resolveTarget(
    FollowUpCommandInterpretation interp,
    FollowUpSubjectRef subject,
  ) async {
    final domain = interp.domain;
    final topic = interp.topicKey;
    if (domain != null && topic != null) {
      return _service.findByTopic(
        subject: subject,
        domain: domain,
        topicKey: topic,
      );
    }
    final active = await _service.listActive(subject: subject);
    if (active.length == 1) return active.first;
    if (topic == 'current_topic' && active.isNotEmpty) return active.first;
    return null;
  }

  /// هل يستحق الالتزام الظهور الآن؟ (WHETHER)
  bool mayReturnNow(FollowUpCommitment c, FollowUpDueContext ctx) =>
      _service.maySurfaceReturn(c, ctx);
}
