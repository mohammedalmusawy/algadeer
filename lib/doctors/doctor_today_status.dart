import 'package:flutter/material.dart';

import '../models/doctor_item.dart';
import '../theme/ghadeer_tokens.dart';
import 'doctor_availability_service.dart';
import 'doctor_gender.dart';
import 'doctor_today_availability.dart';

/// حالة الطبيب «اليوم» للبطاقات (Phase 5C) — من الدوام المسجّل + حالة الحجز.
///
/// قبل: البطاقة تگول «متوفر اليوم» إذا الحجز متاح حتى لو اليوم عطلته.
/// هسه: إذا اليوم عطلة يطلع «عطلة اليوم»، وإذا معروفة فترة الدوام تنضاف
/// («متوفر اليوم · مساءً»). ما نگول «موجود هسه» أبد — نعرف الفترة مو الساعة.
({String text, Color color, Color bg}) doctorTodayStatus(
  DoctorItem doctor, {
  DateTime? nowUtc,
}) {
  final leave = DoctorLeaveDisplay.fromDoctor(doctor);
  if (leave.isOnLeave) {
    return (
      text: leave.badgeLabel.isNotEmpty
          ? leave.badgeLabel
          : DoctorGender.unavailable(doctor.gender),
      color: GhadeerTokens.danger,
      bg: GhadeerTokens.dangerWash,
    );
  }

  final today = DoctorTodayAvailability.evaluate(
    workingDays: doctor.workingDays,
    workingHours: doctor.workingHours,
    bookingStatus: doctor.bookingStatus,
    absenceFrom: doctor.absenceFrom,
    absenceTo: doctor.absenceTo,
    nowUtc: nowUtc,
  );
  if (today.state == DoctorTodayState.dayOff) {
    return (
      text: 'عطلة اليوم',
      color: GhadeerTokens.inkMuted,
      bg: const Color(0xFFEEF2F3),
    );
  }

  final period = today.period;
  String withPeriod(String base) =>
      (period == null || period.isEmpty) ? base : '$base · $period';

  switch (doctor.bookingStatus) {
    case 'available':
      return (
        text: withPeriod(DoctorGender.availableToday(doctor.gender)),
        color: GhadeerTokens.ok,
        bg: GhadeerTokens.okWash,
      );
    case 'walk_in_only':
      return (
        text: withPeriod('حضوري فقط'),
        color: GhadeerTokens.warn,
        bg: GhadeerTokens.warnWash,
      );
    case 'full':
      return (
        text: 'مكتمل',
        color: GhadeerTokens.danger,
        bg: GhadeerTokens.dangerWash,
      );
    default:
      return (
        text: DoctorGender.unavailable(doctor.gender),
        color: GhadeerTokens.danger,
        bg: GhadeerTokens.dangerWash,
      );
  }
}
