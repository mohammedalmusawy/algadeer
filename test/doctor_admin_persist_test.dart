import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_admin_persist.dart';

void main() {
  group('doctorSavePayloadForProduction', () {
    test('strips pending profile columns and keeps production fields', () {
      final payload = doctorSavePayloadForProduction({
        'doctor_name': 'د. علي',
        'specialty': 'باطنية',
        'bio': 'نبذة',
        'gender': 'male',
        'notifications_enabled': true,
        'booking_status': 'available',
        'image_url': 'https://example.com/a.jpg',
        'age_group': 'للبالغين',
        'years_experience': 12,
        'patients_served': 500,
        'languages': 'العربية',
        'qualifications': 'بورد',
        'profile_quote': 'اقتباس',
      });

      expect(payload['doctor_name'], 'د. علي');
      expect(payload['specialty'], 'باطنية');
      expect(payload['bio'], 'نبذة');
      expect(payload['gender'], 'male');
      expect(payload['notifications_enabled'], isTrue);
      expect(payload['booking_status'], 'available');
      expect(payload['image_url'], 'https://example.com/a.jpg');

      for (final column in kDoctorProfileColumnsPendingMigration) {
        expect(payload.containsKey(column), isFalse, reason: column);
      }
    });
  });

  group('missingDoctorColumnFromPostgrest', () {
    test('parses PGRST204 missing-column message', () {
      expect(
        missingDoctorColumnFromPostgrest(
          "Could not find the 'age_group' column of 'doctors' in the schema cache",
        ),
        'age_group',
      );
      expect(
        missingDoctorColumnFromPostgrest(
          "Could not find the 'years_experience' column of 'doctors' in the schema cache",
        ),
        'years_experience',
      );
      expect(missingDoctorColumnFromPostgrest('unrelated'), isNull);
    });
  });

  group('doctor duplicate identity', () {
    test('same name+phone matches despite spacing/hamza', () {
      expect(
        isSameDoctorIdentity(
          nameA: 'صباح  مجيد العمري',
          phoneA: '0788 487 7685',
          nameB: 'صباح مجيد العمري',
          phoneB: '07884877685',
        ),
        isTrue,
      );
    });

    test('different phone does not match', () {
      expect(
        isSameDoctorIdentity(
          nameA: 'صباح مجيد العمري',
          phoneA: '07884877685',
          nameB: 'صباح مجيد العمري',
          phoneB: '07880000000',
        ),
        isFalse,
      );
    });

    test('findExistingDoctorIdByNamePhone returns first match', () {
      final id = findExistingDoctorIdByNamePhone(
        rows: [
          {
            'id': 'keep-me',
            'doctor_name': 'صباح مجيد العمري',
            'phone': '07884877685',
          },
          {
            'id': 'other',
            'doctor_name': 'مريم عباس كريدي',
            'phone': '07857420112',
          },
        ],
        name: 'صباح مجيد العمري',
        phone: '07884877685',
      );
      expect(id, 'keep-me');
    });
  });
}
