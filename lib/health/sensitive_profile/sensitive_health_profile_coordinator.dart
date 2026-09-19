import '../../companion/companion_command_domain.dart';
import 'health_consent_coordinator.dart';
import 'health_profile_command_interpreter.dart';
import 'health_profile_command_models.dart';
import 'sensitive_health_profile_models.dart';
import 'sensitive_health_profile_service.dart';
import 'sensitive_health_retrieval_policy.dart';

/// منسّق أوامر/موافقة ملف الصحة الحسّاس.
class SensitiveHealthProfileCoordinator {
  SensitiveHealthProfileCoordinator({
    SensitiveHealthProfileService? service,
    HealthProfileCommandInterpreter? interpreter,
    HealthConsentCoordinator? consent,
    SensitiveHealthRetrievalPolicy? retrieval,
    CompanionCommandRouter? router,
  })  : _service = service ?? SensitiveHealthProfileService(),
        _interpreter = interpreter ?? HealthProfileCommandInterpreter(),
        _consent = consent ?? const HealthConsentCoordinator(),
        _retrieval = retrieval ?? const SensitiveHealthRetrievalPolicy(),
        _router = router ?? const CompanionCommandRouter();

  final SensitiveHealthProfileService _service;
  final HealthProfileCommandInterpreter _interpreter;
  final HealthConsentCoordinator _consent;
  final SensitiveHealthRetrievalPolicy _retrieval;
  final CompanionCommandRouter _router;

  SensitiveHealthProfileService get service => _service;
  HealthProfileCommandInterpreter get interpreter => _interpreter;
  SensitiveHealthRetrievalPolicy get retrieval => _retrieval;

  bool mayHandle({
    required String query,
    required HealthProfilePendingOp pending,
  }) {
    if (pending.isActive) return true;
    final route = _router.route(query);
    if (route != null &&
        route.matched &&
        route.domain == CompanionCommandDomain.sensitiveHealthMemory) {
      return true;
    }
    return _interpreter.looksLikeHealthCommand(query);
  }

  Future<HealthProfileCommandTurnResult> handle({
    required String text,
    required HealthProfilePendingOp pending,
    bool preferUrgentSafety = false,
  }) async {
    if (preferUrgentSafety) {
      return const HealthProfileCommandTurnResult(
        handled: false,
        message: '',
        deferToUrgentSafety: true,
        textFirstOnly: true,
      );
    }

    final interp = _interpreter.interpret(raw: text, pending: pending);
    if (!interp.isHealthCommand) {
      return HealthProfileCommandTurnResult.notHandled();
    }

    try {
      return await _execute(interp, pending);
    } catch (_) {
      return HealthProfileCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما كدرت أكمّل طلب الملف الصحي هسه. ما تم الحفظ.',
        commandKind: interp.kind,
        textFirstOnly: true,
      );
    }
  }

  Future<HealthProfileCommandTurnResult> _execute(
    HealthProfileCommandInterpretation interp,
    HealthProfilePendingOp pending,
  ) async {
    switch (interp.kind) {
      case HealthProfileCommandKind.showHealthProfile:
        return HealthProfileCommandTurnResult(
          handled: true,
          message: await _formatShow(),
          commandKind: interp.kind,
          recordCount: (await _service.loadProfile())?.conditions.length ?? 0,
        );

      case HealthProfileCommandKind.rememberCandidates:
        final pendingConsent = _consent.begin(interp.candidates);
        if (!pendingConsent.isActive) {
          return const HealthProfileCommandTurnResult(
            handled: true,
            success: false,
            message: 'ما في حالة مؤهّلة للحفظ الآن.',
            commandKind: HealthProfileCommandKind.rejectIneligible,
          );
        }
        return HealthProfileCommandTurnResult(
          handled: true,
          success: true,
          message: _consent.buildConsentPrompt(pendingConsent.candidates),
          pending: HealthProfilePendingOp(
            kind: HealthProfilePendingKind.rememberConsent,
            consent: pendingConsent,
          ),
          commandKind: interp.kind,
          recordCount: pendingConsent.candidates.length,
        );

      case HealthProfileCommandKind.consentWhy:
        return HealthProfileCommandTurnResult(
          handled: true,
          message:
              '${HealthConsentCoordinator.whyExplanation}\n${_consent.buildConsentPrompt(pending.consent.candidates)}',
          pending: HealthProfilePendingOp(
            kind: HealthProfilePendingKind.rememberConsent,
            consent: pending.consent,
          ),
          commandKind: interp.kind,
        );

      case HealthProfileCommandKind.consentLater:
      case HealthProfileCommandKind.consentNo:
        return HealthProfileCommandTurnResult(
          handled: true,
          message: 'تمام، ما حفظت أي معلومة صحية دائمة.',
          pending: HealthProfilePendingOp.none,
          commandKind: interp.kind,
          success: true,
          recordCount: 0,
        );

      case HealthProfileCommandKind.consentYes:
        final candidates = interp.candidates.isNotEmpty
            ? interp.candidates
            : pending.consent.candidates;
        if (candidates.isEmpty) {
          return const HealthProfileCommandTurnResult(
            handled: true,
            success: false,
            message: 'ما في شيء للحفظ.',
            commandKind: HealthProfileCommandKind.consentYes,
          );
        }
        final now = DateTime.now();
        final records = [
          for (final c in candidates)
            HealthConditionRecord(
              id: 'hc_${c.canonicalConditionKey}_${now.millisecondsSinceEpoch}',
              canonicalConditionKey: c.canonicalConditionKey,
              displayName: c.displayName,
              diagnosisStatus: c.diagnosisStatus,
              diagnosisSource: c.diagnosisSource,
              approximateSince: c.approximateSince,
              consentState: HealthConsentState.granted,
              createdAt: now,
              updatedAt: now,
              followUpPermission: false,
            ),
        ];
        try {
          final saved = await _service.upsertConditions(records);
          return HealthProfileCommandTurnResult(
            handled: true,
            success: true,
            message:
                'تم الحفظ. راح أراعي هالمعلومات بالمحادثات الصحية عند الحاجة فقط.',
            pending: HealthProfilePendingOp.none,
            commandKind: interp.kind,
            recordCount: saved.conditions.length,
          );
        } catch (_) {
          return const HealthProfileCommandTurnResult(
            handled: true,
            success: false,
            message: 'ما كدرت أحفظ المعلومة الصحية. ما تم الحفظ.',
            pending: HealthProfilePendingOp.none,
            commandKind: HealthProfileCommandKind.consentYes,
            recordCount: 0,
          );
        }

      case HealthProfileCommandKind.forgetCondition:
        final key = interp.conditionKey!;
        await _service.removeConditionByKey(key);
        final after = await _service.loadProfile();
        return HealthProfileCommandTurnResult(
          handled: true,
          success: true,
          message: 'تم مسح السجل المطلوب من معلوماتك الصحية فقط.',
          commandKind: interp.kind,
          recordCount: after?.conditions.length ?? 0,
        );

      case HealthProfileCommandKind.deleteAllRequest:
        return const HealthProfileCommandTurnResult(
          handled: true,
          message:
              'متأكد تريد مسح كل معلوماتك الصحية الدائمة؟ قل نعم للتأكيد أو لا للإلغاء.',
          pending: HealthProfilePendingOp(
            kind: HealthProfilePendingKind.deleteWholeHealthProfile,
          ),
          commandKind: HealthProfileCommandKind.deleteAllRequest,
        );

      case HealthProfileCommandKind.confirmDelete:
        await _service.deleteProfileExplicitly();
        return const HealthProfileCommandTurnResult(
          handled: true,
          success: true,
          message: 'تم مسح الملف الصحي الحسّاس. ملفك الشخصي الأساسي ما انمسح.',
          pending: HealthProfilePendingOp.none,
          commandKind: HealthProfileCommandKind.confirmDelete,
          recordCount: 0,
        );

      case HealthProfileCommandKind.cancelDelete:
        return HealthProfileCommandTurnResult(
          handled: true,
          message: 'تمام، ما مسحت معلوماتك الصحية.',
          pending: HealthProfilePendingOp.none,
          commandKind: interp.kind,
          recordCount: (await _service.loadProfile())?.conditions.length,
        );

      case HealthProfileCommandKind.disableHealthPersonalization:
        await _service.disablePersonalization();
        return const HealthProfileCommandTurnResult(
          handled: true,
          message:
              'تم تعطيل استخدام معلوماتك الصحية بالتخصيص. البيانات محفوظة وما انمسحت.',
          commandKind: HealthProfileCommandKind.disableHealthPersonalization,
        );

      case HealthProfileCommandKind.enableHealthPersonalization:
        await _service.enablePersonalization();
        return const HealthProfileCommandTurnResult(
          handled: true,
          message: 'تم تفعيل استخدام معلوماتك الصحية عند الحاجة فقط.',
          commandKind: HealthProfileCommandKind.enableHealthPersonalization,
        );

      case HealthProfileCommandKind.rejectNonOwner:
      case HealthProfileCommandKind.rejectIneligible:
      case HealthProfileCommandKind.clarifyAmbiguous:
      case HealthProfileCommandKind.notImplementedChronic:
        return HealthProfileCommandTurnResult(
          handled: true,
          success: false,
          message: interp.message,
          commandKind: interp.kind,
        );

      case HealthProfileCommandKind.none:
        return HealthProfileCommandTurnResult.notHandled();
    }
  }

  Future<String> _formatShow() async {
    final p = await _service.loadProfile();
    if (p == null || p.conditions.isEmpty) {
      return 'حالياً ما عندي معلومات صحية دائمة محفوظة عنك.';
    }
    final lines = <String>['المعلومات الصحية الدائمة اللي محفوظة:'];
    for (final c in p.conditions) {
      final tag = c.diagnosisStatus == HealthDiagnosisStatus.diagnosed
          ? 'مشخّصة'
          : 'ثابتة حسب ما وافقت';
      lines.add('- ${c.displayName} ($tag)');
    }
    if (!p.healthPersonalizationEnabled) {
      lines.add('ملاحظة: استخدام التخصيص الصحي معطّل حالياً.');
    }
    lines.add('تكدر تمسح أي سجل أو تعطّل الاستخدام بأي وقت.');
    return lines.join('\n');
  }
}

// تم إبقاء الامتداد الداخلي محذوفاً — النسخ يتم عبر HealthProfilePendingOp مباشرة.
