import 'package:flutter_test/flutter_test.dart';

import 'package:ghadeer_clinic/doctors/doctor_availability_service.dart';
import 'package:ghadeer_clinic/services/dynamic_message_service.dart';

void main() {
  test('leave badge: same-day leave', () {
    final today = DoctorLeaveDisplay.dateOnly(DateTime.now());
    final ymd =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final leave = DoctorLeaveDisplay.fromDoctorFields(
      absenceFrom: ymd,
      absenceTo: ymd,
    );
    expect(leave.isOnLeave, isTrue);
    expect(leave.badgeLabel, 'إجازة اليوم');
  });

  test('leave badge: multi-day period', () {
    final today = DoctorLeaveDisplay.dateOnly(DateTime.now());
    final end = today.add(const Duration(days: 5));
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final leave = DoctorLeaveDisplay.fromDoctorFields(
      absenceFrom: ymd(today),
      absenceTo: ymd(end),
    );
    expect(leave.isOnLeave, isTrue);
    expect(leave.badgeLabel, contains('غير متواجد حتى'));
  });

  test('dynamic message emergency fallback still available', () {
    expect(DynamicMessageService.emergencyFallback.body, isNotEmpty);
  });
}
