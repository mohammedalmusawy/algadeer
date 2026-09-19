import 'daily_context_models.dart';

/// سياسة انتهاء صلاحية السياق اليومي — حتمية.
class DailyContextExpiryPolicy {
  const DailyContextExpiryPolicy();

  DateTime expiresAt({
    required DailyContextTiming timing,
    required DateTime now,
  }) {
    switch (timing) {
      case DailyContextTiming.yesterday:
        // ينتهي بنهاية اليوم الحالي كمرجع قصير
        return _endOfDay(now);
      case DailyContextTiming.today:
      case DailyContextTiming.thisMorning:
      case DailyContextTiming.thisAfternoon:
      case DailyContextTiming.thisEvening:
      case DailyContextTiming.tonight:
      case DailyContextTiming.currentPeriod:
        return _endOfDay(now);
      case DailyContextTiming.tomorrow:
        return _endOfDay(now.add(const Duration(days: 1)));
      case DailyContextTiming.thisWeek:
        return now.add(const Duration(days: 7));
      case DailyContextTiming.unknown:
        return now.add(const Duration(hours: 12));
    }
  }

  List<DailyContextSignal> pruneExpired(
    List<DailyContextSignal> signals, [
    DateTime? now,
  ]) {
    final n = now ?? DateTime.now();
    return signals.where((s) => !s.isExpired(n)).toList(growable: false);
  }

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);
}

/// خصوصية — لا ترقية صامتة لذاكرة دائمة.
class DailyContextPrivacyPolicy {
  const DailyContextPrivacyPolicy();

  bool mayPersistToPersonalMemory() => false;
  bool mayPersistToSensitiveHealth() => false;
  bool mayCreateFollowUp() => false;
  bool mayCreateActivityRecord() => false;
  bool mayCreateMoodHistory() => false;

  Map<String, Object?> analyticsSafeMap(DailyLifeContext ctx) => ctx.debugMap();
}
