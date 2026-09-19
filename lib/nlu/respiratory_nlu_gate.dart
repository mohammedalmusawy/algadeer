import '../clinical_knowledge/packs/respiratory/respiratory_models.dart';
import '../search/arabic_text_utils.dart';
import '../voice/intent/assistant_intent.dart';
import 'nlu_models.dart';

/// يقرر هل يُستدعى NLU في المرحلة 1 (استمرار تنفسي فقط).
class RespiratoryNluGate {
  const RespiratoryNluGate();

  NluGateDecision evaluate({
    required String query,
    required RespiratorySession session,
    required RespiratoryInterpretation deterministic,
    required AssistantIntent intent,
  }) {
    if (!session.active) {
      return const NluGateDecision.skip(
        NluSkipReason.noActiveRespiratorySession,
        'no_active_respiratory_session',
      );
    }
    if (session.lastQuestionKey == null ||
        session.lastQuestionKey!.trim().isEmpty) {
      return const NluGateDecision.skip(
        NluSkipReason.noPendingQuestion,
        'no_pending_question',
      );
    }
    if (_isExplicitAppAction(query, intent)) {
      return const NluGateDecision.skip(
        NluSkipReason.appAction,
        'explicit_app_action',
      );
    }
    if (_looksLikeAgeReply(query)) {
      return const NluGateDecision.skip(
        NluSkipReason.deterministicAge,
        'deterministic_age',
      );
    }

    final key = session.lastQuestionKey;
    if (key != 'childAssociated' && key != 'associatedRed') {
      return const NluGateDecision.skip(
        NluSkipReason.notPhase1Question,
        'not_phase1_question',
      );
    }

    final feverKnown = deterministic.fever != RespiratoryTriState.unknown ||
        session.fever != RespiratoryTriState.unknown;
    final breathKnown =
        deterministic.breathlessness != RespiratoryTriState.unknown ||
            session.breathlessness != RespiratoryTriState.unknown;
    final hemoKnown = deterministic.hemoptysis != RespiratoryTriState.unknown ||
        session.hemoptysis != RespiratoryTriState.unknown;

    if (key == 'childAssociated' && feverKnown && breathKnown) {
      return const NluGateDecision.skip(
        NluSkipReason.deterministicComplete,
        'deterministic_complete',
      );
    }
    if (key == 'associatedRed' && breathKnown && hemoKnown) {
      return const NluGateDecision.skip(
        NluSkipReason.deterministicComplete,
        'deterministic_complete',
      );
    }

    return const NluGateDecision.call('incomplete_or_ambiguous_continuation');
  }

  bool _isExplicitAppAction(String query, AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.showLocation:
      case AssistantIntent.showProfile:
      case AssistantIntent.selectResult:
      case AssistantIntent.findOffer:
      case AssistantIntent.findPackage:
      case AssistantIntent.findLab:
      case AssistantIntent.findAnalysis:
        return true;
      default:
        break;
    }
    final n = ArabicTextUtils.normalize(query);
    if (RegExp(
      r'(?:^|\s)(?:اتصل|واتساب|واتس|دزله|ارسل\s*واتساب)(?:\s|$)',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(r'(?:ال)?(?:دكتور|طبيب)\s+\S{2,}').hasMatch(n)) {
      return true;
    }
    return false;
  }

  bool _looksLikeAgeReply(String query) {
    final n = ArabicTextUtils.normalize(query.trim());
    return RegExp(
      r'(?:عمر[هة]\s*\d{1,2}\s*(?:سنه|سنة|سنوات|سنين)?|'
      r'\d{1,2}\s*(?:سنه|سنة|سنوات|سنين))',
    ).hasMatch(n);
  }
}

class NluGateDecision {
  const NluGateDecision.call(this.reason)
      : shouldCall = true,
        skipReason = null;

  const NluGateDecision.skip(this.skipReason, this.reason)
      : shouldCall = false;

  final bool shouldCall;
  final NluSkipReason? skipReason;
  final String reason;
}
