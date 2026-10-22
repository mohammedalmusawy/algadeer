import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/specialty_catalog.dart';
import 'package:ghadeer_clinic/models/doctor_item.dart';
import 'package:ghadeer_clinic/utils/ghadeer_card_link.dart';

// نسخة الويب (22 أكتوبر): رابط البطاقة بنفس الموقع، والتقسيم التلقائي
// لطبيب ما انحطله اختصاص.
void main() {
  group('رابط مشاركة البطاقة', () {
    test('الرابط يطلع بنفس عنوان الموقع المفتوح', () {
      expect(
        GhadeerCardLink.url(
          GhadeerCardKind.doctor,
          'abc',
          origin: 'https://alghadeer-clinic.netlify.app',
        ),
        'https://alghadeer-clinic.netlify.app/c/doctor/abc',
      );
    });

    test('الموبايل يبقى على الموقع الثابت مثل قبل', () {
      expect(
        GhadeerCardLink.url(GhadeerCardKind.doctor, 'abc'),
        '${GhadeerCardLink.webBase}/c/doctor/abc',
      );
    });
  });

  group('طبيب حضوري فقط', () {
    test('الاتصال والواتساب يطلّعون رسالة الحجز الحضوري (الموقع والتطبيق)', () {
      expect(DoctorItem.walkInBlocksContact('walk_in_only'), isTrue);
      expect(DoctorItem.walkInBlocksContact(' WALK_IN_ONLY '), isTrue);
    });

    test('باقي الحالات ما تتغيّر', () {
      expect(DoctorItem.walkInBlocksContact('available'), isFalse);
      expect(DoctorItem.walkInBlocksContact('full'), isFalse);
      expect(DoctorItem.walkInBlocksContact(null), isFalse);
    });
  });

  group('التقسيم التلقائي للاختصاص', () {
    test('عيادة أسنان اسمها بيه «تجميل» تطلع أسنان مو تجميلية', () {
      final s = SpecialtyCatalog.inferFromText(
        'عيادة فانيست لطب وتجميل الأسنان تقدم العيادة خدمات تقويم '
        'وزراعة الأسنان، الحشوات الضوئية الدائمة، وتركيب الأسنان',
      );
      expect(s?.nameAr, 'طب الأسنان');
    });

    test('نبذة طبيبة أعصاب تطلع الجملة العصبية', () {
      final s = SpecialtyCatalog.inferFromText(
        'الدكتورة جيهان فلاح ثامر ( شهادة البورد ) الدكتوراه في طب '
        'الجملة العصبية زميلة المجلس العراقي للاختصاصات الطبية',
      );
      expect(s?.nameAr, 'الجملة العصبية');
    });

    test('إذا اختصاصين بنفس القوة ما نخمّن', () {
      expect(SpecialtyCatalog.inferFromText('أطفال، قلب'), isNull);
    });

    test('الاختصاص المحفوظ ما يتغيّر أبد', () {
      final row = {
        'doctor_name': 'د. س',
        'specialty': 'الباطنية',
        'bio': 'أمراض القلب والدم',
      };
      expect(DoctorItem.specialtyOrInferred(row, infer: true), 'الباطنية');
    });

    test('الفارغ يتعبّى بالويب بس، والموبايل يبقى فارغ', () {
      final row = {
        'doctor_name': 'عيادة لطب الأسنان',
        'specialty': '',
        'bio': 'تقويم وزراعة الأسنان',
      };
      expect(DoctorItem.specialtyOrInferred(row, infer: true), 'طب الأسنان');
      expect(DoctorItem.specialtyOrInferred(row, infer: false), '');
    });
  });
}
