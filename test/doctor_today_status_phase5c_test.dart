// Phase 5C — بطاقة الطبيب ما تگول «متاح اليوم» إذا اليوم عطلته،
// وتضيف فترة الدوام إذا معروفة. ما نگول «موجود هسه» أبد.
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_today_status.dart';
import 'package:ghadeer_clinic/models/doctor_item.dart';

DoctorItem _doc({
  String hours = '',
  String days = '',
  String booking = 'available',
}) => DoctorItem(
  id: 'd1',
  name: 'د. تجربة',
  specialty: 'باطنية',
  location: 'الشطرة',
  available: true,
  phone: '',
  whatsapp: '',
  imageUrl: '',
  ghadeerBadge: false,
  bio: '',
  shortDescription: '',
  workingDays: days,
  workingHours: hours,
  bookingStatus: booking,
  absenceFrom: '',
  absenceTo: '',
);

void main() {
  // الاثنين 19 أكتوبر 2026، الساعة 1 الظهر ببغداد.
  final monday = DateTime.utc(2026, 10, 19, 10);

  test('اليوم عطلته ← «عطلة اليوم» مو «متاح اليوم»', () {
    final s = doctorTodayStatus(
      _doc(hours: 'يومياً مساءً عدا الاثنين'),
      nowUtc: monday,
    );
    expect(s.text, 'عطلة اليوم');
  });

  test('دوامه اليوم ← «متاح اليوم · الفترة»', () {
    final s = doctorTodayStatus(
      _doc(hours: 'السبت مساءً، الاثنين صباحًا'),
      nowUtc: monday,
    );
    expect(s.text, 'متاح اليوم · صباحًا');
  });

  test('بدون جدول ← نفس الكلام القديم بدون فترة', () {
    final s = doctorTodayStatus(_doc(), nowUtc: monday);
    expect(s.text, 'متاح اليوم');
  });

  test('حضوري فقط مع الفترة، والمكتمل يبقى مكتمل', () {
    expect(
      doctorTodayStatus(
        _doc(hours: 'يومياً مساءً', booking: 'walk_in_only'),
        nowUtc: monday,
      ).text,
      'حضوري فقط · مساءً',
    );
    expect(
      doctorTodayStatus(
        _doc(hours: 'يومياً مساءً', booking: 'full'),
        nowUtc: monday,
      ).text,
      'مكتمل',
    );
  });

  test('ما نگول «موجود هسه» أو «الآن» أبد', () {
    final s = doctorTodayStatus(_doc(hours: 'يومياً مساءً'), nowUtc: monday);
    expect(s.text.contains('الآن'), isFalse);
    expect(s.text.contains('هسه'), isFalse);
  });
}
