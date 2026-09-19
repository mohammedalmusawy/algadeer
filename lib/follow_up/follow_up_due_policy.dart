import 'follow_up_eligibility_policy.dart';
import 'follow_up_models.dart';

/// سياق تقييم الاستحقاق عند تفاعل المستخدم الحالي فقط (لا خلفية).
class FollowUpDueContext {
  const FollowUpDueContext({
    required this.now,
    required this.currentSubject,
    this.conversationRelevant = false,
    this.unrelatedEntityIntent = false,
    this.urgentSafety = false,
    this.mentalSafety = false,
    this.emotionalDistress = false,
  });

  final DateTime now;
  final FollowUpSubjectRef currentSubject;
  final bool conversationRelevant;
  final bool unrelatedEntityIntent;
  final bool urgentSafety;
  final bool mentalSafety;

  /// الضيق العاطفي لا يزيد ضغط المتابعة.
  final bool emotionalDistress;
}

/// سياسة استحقاق حتمية — WHEN/WHETHER للعودة للموضوع.
class FollowUpDuePolicy {
  const FollowUpDuePolicy({
    this.minHoursBetweenAsks = 24,
    this.skipThresholdForReducedPressure = 2,
  });

  final int minHoursBetweenAsks;
  final int skipThresholdForReducedPressure;

  final FollowUpEligibilityPolicy _eligibility =
      const FollowUpEligibilityPolicy();

  bool isDue(FollowUpCommitment c, FollowUpDueContext ctx) {
    if (ctx.urgentSafety || ctx.mentalSafety) return false;
    if (ctx.unrelatedEntityIntent) return false;
    if (!ctx.conversationRelevant) return false;
    if (!c.subjectRef.matches(ctx.currentSubject)) return false;

    if (c.status != FollowUpStatus.active) return false;
    if (c.permissionState != FollowUpPermissionState.granted) return false;

    if (c.domain == FollowUpDomain.chronicHealth &&
        c.subjectRef.kind == FollowUpSubjectKind.persistentPerson &&
        !_eligibility.familyChronicFollowUpEnabled()) {
      return false;
    }

    if (c.notBeforeAt != null && ctx.now.isBefore(c.notBeforeAt!)) {
      return false;
    }

    if (c.consecutiveSkips >= skipThresholdForReducedPressure) {
      // ضغط أقل: لا يظهر تلقائياً بعد تخطّيين متتاليين.
      return false;
    }

    if (c.lastAskedAt != null) {
      final hours = ctx.now.difference(c.lastAskedAt!).inHours;
      if (hours < minHoursBetweenAsks) return false;
    }

    // الضيق العاطفي لا يمنع صراحةً هنا، لكنه لا يزيد الاستحقاق أيضاً.
    return true;
  }
}
