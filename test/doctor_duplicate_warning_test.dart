import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_admin_persist.dart';

/// إضافة طبيب مضاف أصلاً → تحذير للإدارة (بدل دمج صامت أو نسخة مكررة).
void main() {
  final rows = <Map<String, dynamic>>[
    {
      'id': 'ali',
      'doctor_name': 'الدكتور علي ناصر السعيدي',
      'phone': '0770 123 4567',
      'specialty': 'طب الأطفال',
    },
    {
      'id': 'sabah',
      'doctor_name': 'صباح مجيد العمري',
      'phone': '07801112233',
      'specialty': 'طب الأطفال',
    },
  ];

  test('same name with a different title is flagged', () {
    for (final name in [
      'علي ناصر السعيدي',
      'د. علي ناصر السعيدي',
      'دكتور علي ناصر السعيدي',
      'الدكتور  علي ناصر السعيدي',
    ]) {
      final d = findPossibleDuplicateDoctors(rows: rows, name: name, phone: '');
      expect(d.map((e) => e['id']), ['ali'], reason: name);
    }
  });

  test('same phone in another format is flagged', () {
    final d = findPossibleDuplicateDoctors(
      rows: rows,
      name: 'اسم جديد تماماً',
      phone: '+964 780 111 2233',
    );
    expect(d.map((e) => e['id']), ['sabah']);
  });

  test('a genuinely new doctor is not flagged', () {
    expect(
      findPossibleDuplicateDoctors(
        rows: rows,
        name: 'د. حسين كاظم',
        phone: '07900000000',
      ),
      isEmpty,
    );
  });

  test('editing a doctor does not flag itself', () {
    expect(
      findPossibleDuplicateDoctors(
        rows: rows,
        name: 'علي ناصر السعيدي',
        phone: '07701234567',
        excludeId: 'ali',
      ),
      isEmpty,
    );
  });
}
