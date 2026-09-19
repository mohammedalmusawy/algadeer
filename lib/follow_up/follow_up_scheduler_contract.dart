/// عقد جدولة مستقبلي — بلا تنفيذ في PC-1.11.
class FollowUpSchedulerSnapshot {
  const FollowUpSchedulerSnapshot({
    required this.commitmentId,
    required this.subjectKind,
    required this.status,
    required this.permissionState,
    required this.timingIntent,
    this.notBeforeAt,
    this.dueWindow,
  });

  final String commitmentId;
  final String subjectKind;
  final String status;
  final String permissionState;
  final String timingIntent;
  final DateTime? notBeforeAt;
  final String? dueWindow;

  Map<String, Object?> toMap() => {
        'commitmentId': commitmentId,
        'subjectKind': subjectKind,
        'status': status,
        'permissionState': permissionState,
        'timingIntent': timingIntent,
        'notBeforeAt': notBeforeAt?.toIso8601String(),
        'dueWindow': dueWindow,
      };
}

/// واجهة مستقبلية — لا جدولة خلفية ولا push.
abstract class FollowUpSchedulerContract {
  /// يستهلك لقطات التزام بدون نص محادثة خام.
  Future<void> enqueue(FollowUpSchedulerSnapshot snapshot);

  /// PC-1.11: غير مفعّل.
  bool get isImplemented => false;
}

class NoOpFollowUpScheduler implements FollowUpSchedulerContract {
  const NoOpFollowUpScheduler();

  @override
  bool get isImplemented => false;

  @override
  Future<void> enqueue(FollowUpSchedulerSnapshot snapshot) async {
    // عمداً لا شيء — لا OS reminder.
  }
}
