// Phase 5C — الدوام بصيغة «يومياً مساءً عدا الجمعة» ينقرأ صح، ويطلع ملخص قصير.
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_week_schedule.dart';

Map<String, String> _week(String hours, {String days = ''}) => {
  for (final e in parseDoctorWeekSchedule(
    workingDays: days,
    workingHours: hours,
  ))
    e.day: e.status,
};

void main() {
  test('يومياً مساءً عدا الجمعة ← ٦ أيام مساءً والجمعة عطلة', () {
    final w = _week('يومياً مساءً عدا الجمعة');
    expect(w.length, 7);
    expect(w['السبت'], 'مساءً');
    expect(w['الخميس'], 'مساءً');
    expect(w['الجمعة'], 'عطلة');
  });

  test('يومياً مساءً عدا الجمعة صباحاً ← الجمعة صباحاً', () {
    final w = _week('يوميا مساء ماعدا الجمعة صباحا');
    expect(w['الاثنين'], 'مساءً');
    expect(w['الجمعة'], 'صباحًا');
  });

  test('يومياً مساءً، الجمعة صباحاً', () {
    final w = _week('يومياً مساءً، الجمعة صباحاً');
    expect(w['الأحد'], 'مساءً');
    expect(w['الجمعة'], 'صباحًا');
  });

  test('يومياً عدا الجمعة والسبت مساءً ← الفترة للكل والجمعة والسبت عطلة', () {
    final w = _week('يومياً عدا الجمعة والسبت مساءً');
    expect(w['الأحد'], 'مساءً');
    expect(w['الجمعة'], 'عطلة');
    expect(w['السبت'], 'عطلة');
  });

  test('«الاثنين» ما تنقرأ كأنها «إلا»', () {
    final w = _week('يومياً مساءً');
    expect(w['الاثنين'], 'مساءً');
    expect(w.values.toSet(), {'مساءً'});
  });

  test('الصيغة القديمة يوم يوم تبقى مثل ما جانت', () {
    final w = _week('السبت مساءً، الأحد عطلة');
    expect(w, {'السبت': 'مساءً', 'الأحد': 'عطلة'});
  });

  test('الملخص: يومياً مساءً + الجمعة صباحاً كملاحظة + العطل', () {
    final s = summarizeDoctorWeek(
      parseDoctorWeekSchedule(
        workingDays: '',
        workingHours: 'يومياً مساءً عدا الجمعة صباحاً',
      ),
    );
    expect(s.headline, 'يومياً مساءً');
    expect(s.notes, ['الجمعة صباحًا']);
    expect(s.offDays, isEmpty);

    final off = summarizeDoctorWeek(
      parseDoctorWeekSchedule(
        workingDays: '',
        workingHours: 'يومياً مساءً عدا الجمعة',
      ),
    );
    expect(off.headline, 'يومياً مساءً');
    expect(off.offDays, ['الجمعة']);
  });

  test('جدول ناقص يطلع أسماء الأيام مو «يومياً»', () {
    final s = summarizeDoctorWeek(
      parseDoctorWeekSchedule(
        workingDays: '',
        workingHours: 'السبت مساءً، الأحد مساءً، الثلاثاء عطلة',
      ),
    );
    expect(s.headline, 'السبت، الأحد: مساءً');
    expect(s.offDays, ['الثلاثاء']);
  });
}
