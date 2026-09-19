import '../../search/arabic_text_utils.dart';
import '../../voice/intent/smart_brain_planner.dart';
import 'personalization_models.dart';
import 'personalization_recency_policy.dart';

/// يزيّن خطة Smart Brain القائمة — لا يستبدل المخطِّط.
class NaturalRecallResponseDecorator {
  const NaturalRecallResponseDecorator({
    PersonalizationRecencyPolicy? recency,
  }) : _recency = recency ?? const PersonalizationRecencyPolicy();

  final PersonalizationRecencyPolicy _recency;

  /// يطبّق ظرف التخصيص على رسالة موجودة.
  ({
    AssistantActionPlan plan,
    PersonalizationSessionState session,
    bool usedName,
  }) decorate({
    required AssistantActionPlan plan,
    required PersonalizationEnvelope envelope,
    required PersonalizationSessionState session,
  }) {
    // لا تستبدل خطط السلامة/التوجيه الطبي العاجل بمحتوى ذاكرة
    if (plan.kind == AssistantActionKind.healthGuidance &&
        envelope.containsSensitiveContext == false &&
        envelope.purpose != PersonalizationPurpose.healthGuidance) {
      // أبقِ الخطة؛ لا حقن أهداف
      final next = _recency.recordUse(
        session: session,
        envelope: envelope,
        usedName: false,
      );
      return (plan: plan, session: next, usedName: false);
    }

    if (envelope.decisionState == PersonalizationDecisionState.failedSafe ||
        envelope.decisionState == PersonalizationDecisionState.disabledByUser ||
        envelope.decisionState == PersonalizationDecisionState.blockedByPrivacy) {
      final next = _recency.recordUse(
        session: session,
        envelope: envelope,
        usedName: false,
      );
      return (plan: plan, session: next, usedName: false);
    }

    if (envelope.routeCorrectionToPersonalMemory) {
      // لا تجادل بالذاكرة القديمة — اترك مسار PC-1.12
      return (plan: plan, session: session, usedName: false);
    }

    if (!envelope.hasUsableContext &&
        envelope.turnPreferenceOverride == null &&
        envelope.clarificationHint.isEmpty) {
      final next = session.copyWith(
        turnsSinceNameUsed: session.turnsSinceNameUsed + 1,
      );
      return (plan: plan, session: next, usedName: false);
    }

    var message = plan.message;
    var usedName = false;

    if (envelope.clarificationHint.isNotEmpty &&
        envelope.decisionState ==
            PersonalizationDecisionState.needsClarification) {
      if (message.trim().isEmpty) {
        message = envelope.clarificationHint;
      } else if (!message.contains(envelope.clarificationHint)) {
        message = '${envelope.clarificationHint}\n$message';
      }
    }

    // تفضيل مؤقت: لا نعلن المصدر
    if (envelope.turnPreferenceOverride == 'brief') {
      // التأثير صامت — لا جملة «لأنك قلت…»
      // إن كانت الرسالة طويلة جداً نتركها للمخطّط؛ لا اختصار عدواني هنا.
    }

    if (envelope.mentionMode == PersonalizationMentionMode.explicit &&
        envelope.selectedCandidates.isNotEmpty) {
      final labels = envelope.selectedCandidates
          .where((c) => !c.sensitive)
          .map((c) => c.displaySafeLabel)
          .where((s) => s.trim().isNotEmpty)
          .take(2)
          .toList();
      if (labels.isNotEmpty) {
        final recall = labels.length == 1
            ? 'المحفوظ عندي: ${labels.first}.'
            : 'المحفوظ عندي: ${labels.join('، ')}.';
        // صدق عرضي — بلا ادّعاء ذاكرة حوارية كاملة
        if (!_claimsEpisodicOmniscience(recall) &&
            !message.contains(recall)) {
          message = message.trim().isEmpty ? recall : '$recall\n$message';
        }
      }
    } else if (envelope.mentionMode == PersonalizationMentionMode.implicit) {
      // تأثير صامت: استمرارية طبيعية خفيفة بدون «بما أنك قلت»
      final goal = envelope.selectedCandidates
          .where(
            (c) =>
                c.source == PersonalizationSource.personalMemory &&
                !c.sensitive &&
                c.category != 'preference',
          )
          .toList();
      if (goal.isNotEmpty &&
          message.trim().isNotEmpty &&
          !_alreadyMentionsTopic(message, goal.first.displaySafeLabel) &&
          envelope.purpose == PersonalizationPurpose.learningSupport) {
        // لا بادئة متكررة إن ذُكر صراحةً مؤخراً
        final key = goal.first.opaqueKey;
        if (!session.recentExplicitMentions.contains(key)) {
          // ضمني: لا تضف جملة تذكير؛ أبقِ الرسالة كما خطّطها الدماغ
        }
      }

      // اسم مفضّل بحذر
      final nameCand = envelope.selectedCandidates
          .where((c) => c.category == 'preferredName')
          .toList();
      if (nameCand.isNotEmpty &&
          message.trim().isNotEmpty &&
          !message.startsWith(nameCand.first.displaySafeLabel)) {
        // لا تُسبق كل رد بالاسم — استخدم فقط إن الرسالة قصيرة تحية/تأكيد
        if (_isLightSocialMessage(message)) {
          message = '${nameCand.first.displaySafeLabel}، $message';
          usedName = true;
        }
      }
    }

    // حظر صياغات ضغط / تسويق / ادّعاء ذاكرة كاملة
    if (_containsForbiddenPersonalizationLanguage(message)) {
      message = _stripForbiddenPersonalizationLanguage(message);
      if (message.trim().isEmpty) {
        message = 'أكيد، أكدر أساعدك.';
      }
      usedName = false;
    }

    final decorated = _clonePlan(plan, message);
    final next = _recency.recordUse(
      session: session,
      envelope: envelope,
      usedName: usedName,
    );
    return (plan: decorated, session: next, usedName: usedName);
  }

  bool _claimsEpisodicOmniscience(String s) => RegExp(
        r'(?:أتذكر\s*كل|أتذكر\s*بالضبط|كنت\s*أفكر\s*بيك|انتظرت\s*رجعتك)',
      ).hasMatch(s);

  bool _containsForbiddenPersonalizationLanguage(String s) {
    final n = ArabicTextUtils.normalize(s);
    return RegExp(
      r'(?:بما\s*انك\s*قلت\s*لي\s*سابقا)|'
      r'(?:لا\s*تتركني)|'
      r'(?:اشتقت\s*لك)|'
      r'(?:لا\s*تخيب\s*ظني)|'
      r'(?:باقه\s*مدفوعه|باقة\s*مدفوعة|اعلان|إعلان)|'
      r'(?:لأنك\s*(?:ذكر|انثى|أنثى))|'
      r'(?:أتذكر\s*كل\s*كلامنا)|'
      r'(?:فلا\s*تتركني)',
    ).hasMatch(n);
  }

  String _stripForbiddenPersonalizationLanguage(String s) {
    var out = s;
    out = out.replaceAll(
      RegExp(
        r'(?:أعرف أنك حزين،?\s*)?(?:وهدفك مهم،?\s*)?(?:فلا تتركني\.?)|'
        r'(?:لا تتركني\.?)|(?:اشتقت لك\.?)|(?:لا تخيب ظني\.?)|'
        r'(?:بما أنك قلت لي سابقاً[^.]*\.?)|'
        r'(?:أتذكر كل كلامنا\.?)',
      ),
      '',
    );
    return out.trim();
  }

  bool _alreadyMentionsTopic(String message, String label) {
    final m = ArabicTextUtils.normalize(message);
    final l = ArabicTextUtils.normalize(label);
    if (l.isEmpty) return false;
    return m.contains(l) ||
        (l.contains('flutter') && m.contains('flutter'));
  }

  bool _isLightSocialMessage(String message) {
    final t = message.trim();
    if (t.length > 80) return false;
    return RegExp(r'^(?:تمام|حاضر|اكيد|أكيد|اهلا|أهلا|مرحبا)').hasMatch(t);
  }

  AssistantActionPlan _clonePlan(AssistantActionPlan plan, String message) {
    if (identical(message, plan.message) || message == plan.message) {
      return plan;
    }
    return AssistantActionPlan(
      kind: plan.kind,
      intentResult: plan.intentResult,
      target: plan.target,
      candidates: plan.candidates,
      message: message,
      specialtyQuery: plan.specialtyQuery,
      doctorQuery: plan.doctorQuery,
      labQuery: plan.labQuery,
      analysisQuery: plan.analysisQuery,
      canExecute: plan.canExecute,
      contextResolution: plan.contextResolution,
      targetResolution: plan.targetResolution,
      labTargetResolution: plan.labTargetResolution,
      analysisTargetResolution: plan.analysisTargetResolution,
      packageTargetResolution: plan.packageTargetResolution,
      packages: plan.packages,
      analyses: plan.analyses,
      guidedResponse: plan.guidedResponse,
      healthDecision: plan.healthDecision,
      textFirstOnly: plan.textFirstOnly,
    );
  }
}
