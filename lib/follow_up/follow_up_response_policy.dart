import 'follow_up_models.dart';

/// صياغة صادقة للقدرات — بلا ادّعاء جدولة/إشعار/كشف نتائج.
class FollowUpResponsePolicy {
  const FollowUpResponsePolicy();

  String capabilityLimitNote(FollowUpTimingIntent timing) {
    switch (timing) {
      case FollowUpTimingIntent.tomorrow:
        return 'أكدر أتذكر نرجع لهذا الموضوع من ترجع للغدير. '
            'ما أسوي تذكير تلقائي على الجهاز حالياً.';
      case FollowUpTimingIntent.whenResultAvailable:
        return 'أكدر أتذكر نرجع لنتيجة التحليل من ترجع تحچي بالموضوع. '
            'ما أكدر أعرف تلقائياً من تطلع النتيجة.';
      case FollowUpTimingIntent.whenUserReturns:
      case FollowUpTimingIntent.later:
      case FollowUpTimingIntent.afterAWeek:
      case FollowUpTimingIntent.nextVisit:
      case FollowUpTimingIntent.customDate:
      case FollowUpTimingIntent.unspecified:
        return 'أكدر أتذكر نرجع لهذا الموضوع من ترجع للغدير.';
    }
  }

  String listLine(FollowUpCommitment c, {bool minimizeHealth = true}) {
    final topic = c.displayTopic.trim().isNotEmpty
        ? c.displayTopic
        : _safeTopicLabel(c, minimizeHealth: minimizeHealth);
    final status = switch (c.status) {
      FollowUpStatus.active => 'نشطة',
      FollowUpStatus.paused => 'موقوفة',
      FollowUpStatus.completed => 'مكتملة',
      FollowUpStatus.cancelled => 'ملغاة',
    };
    return '• $topic ($status)';
  }

  String _safeTopicLabel(
    FollowUpCommitment c, {
    required bool minimizeHealth,
  }) {
    if (minimizeHealth && c.domain == FollowUpDomain.chronicHealth) {
      return 'متابعة صحية';
    }
    switch (c.domain) {
      case FollowUpDomain.doctorVisit:
        return 'متابعة مراجعة الطبيب';
      case FollowUpDomain.labResult:
        return 'متابعة نتيجة تحليل';
      case FollowUpDomain.labTest:
        return 'متابعة فحص مختبر';
      case FollowUpDomain.preventive:
        return 'متابعة وقائية';
      case FollowUpDomain.personalGoal:
        return 'هدف شخصي';
      case FollowUpDomain.healthCheck:
        return 'متابعة فحص صحي';
      case FollowUpDomain.chronicHealth:
        return 'متابعة مزمنة';
      case FollowUpDomain.generalCommitment:
        return 'التزام عام';
    }
  }

  String createdAck({
    required FollowUpCommitment c,
    required bool honestCapability,
  }) {
    final base = 'تمام، سجّلت نرجع لـ'
        '${c.displayTopic.isNotEmpty ? c.displayTopic : "هذا الموضوع"}.';
    if (!honestCapability) return base;
    return '$base\n${capabilityLimitNote(c.timingIntent)}';
  }
}
