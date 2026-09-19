/// أحداث خارجية مستقبلية — لا محاكاة في PC-1.11.
enum FollowUpExternalEventType {
  labResultAvailable,
  appointmentCompleted,
  doctorAvailabilityChanged,
}

class FollowUpExternalEvent {
  const FollowUpExternalEvent({
    required this.type,
    required this.occurredAt,
    this.relatedTopicKey,
  });

  final FollowUpExternalEventType type;
  final DateTime occurredAt;
  final String? relatedTopicKey;
}

/// واجهة مستقبلية لحقن أحداث خارجية في محرك المتابعة.
abstract class FollowUpEventContract {
  Future<void> signal(FollowUpExternalEvent event);
  bool get isImplemented => false;
}

class NoOpFollowUpEventSink implements FollowUpEventContract {
  const NoOpFollowUpEventSink();

  @override
  bool get isImplemented => false;

  @override
  Future<void> signal(FollowUpExternalEvent event) async {}
}
