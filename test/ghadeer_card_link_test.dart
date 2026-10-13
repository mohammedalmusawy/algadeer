import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_card_links.dart';
import 'package:ghadeer_clinic/labs/lab_card_links.dart';
import 'package:ghadeer_clinic/utils/ghadeer_card_link.dart';

/// روابط المشاركة كانت تروح لدومين ميت (ghadeer-clinic.web.app)، والصيدليات
/// والعوينات وغيرها كانت تشارك نص بلا رابط. الآن رابط واحد لكل البطاقات.
void main() {
  test('كل البطاقات على الدومين المنشور بمسار /c/', () {
    for (final kind in GhadeerCardKind.values) {
      final url = GhadeerCardLink.url(kind, 'abc-123');
      expect(
        url,
        startsWith('https://frolicking-sawine-d5ecbb.netlify.app/c/'),
      );
      expect(url, isNot(contains('web.app')));
      expect(
        GhadeerCardLink.parse(Uri.parse(url)),
        GhadeerCardRef(kind, 'abc-123'),
      );
    }
    expect(DoctorCardLinks.forDoctor('d1'), endsWith('/c/doctor/d1'));
    expect(LabCardLinks.forLab('l1'), endsWith('/c/lab/l1'));
  });

  test('رابط التطبيق ghadeerclinic:// يُقرأ', () {
    expect(
      GhadeerCardLink.parse(Uri.parse('ghadeerclinic://pharmacy/p-9')),
      const GhadeerCardRef(GhadeerCardKind.pharmacy, 'p-9'),
    );
    expect(
      GhadeerCardLink.appUrl(GhadeerCardKind.center, 'x'),
      'ghadeerclinic://center/x',
    );
  });

  test('الروابط القديمة تبقى تشتغل', () {
    expect(
      DoctorCardLinks.parseDoctorId(
        Uri.parse('https://ghadeer-clinic.web.app/#/doctor/old-id'),
      ),
      'old-id',
    );
    expect(
      GhadeerCardLink.parse(Uri.parse('https://x.app/#/lab/l7')),
      const GhadeerCardRef(GhadeerCardKind.lab, 'l7'),
    );
    expect(
      GhadeerCardLink.parse(Uri.parse('https://x.app/#/c/supply/s1')),
      const GhadeerCardRef(GhadeerCardKind.supply, 's1'),
    );
    expect(
      DoctorCardLinks.parseDoctorId(Uri.parse('https://x.app/?doctor=q1')),
      'q1',
    );
  });

  test('روابط غير البطاقات ما تنقرأ كبطاقة', () {
    for (final raw in [
      'https://frolicking-sawine-d5ecbb.netlify.app/',
      'https://frolicking-sawine-d5ecbb.netlify.app/#/patient-health',
      'https://frolicking-sawine-d5ecbb.netlify.app/c/unknown/1',
      'https://frolicking-sawine-d5ecbb.netlify.app/assets/x.png',
    ]) {
      expect(GhadeerCardLink.parse(Uri.parse(raw)), isNull, reason: raw);
    }
    expect(
      DoctorCardLinks.parseDoctorId(Uri.parse('ghadeerclinic://lab/l1')),
      isNull,
    );
  });

  test('نص المشاركة: الاسم والوصف والرابط', () {
    final text = GhadeerCardLink.shareText(
      kind: GhadeerCardKind.pharmacy,
      id: 'p1',
      name: 'صيدلية الشفاء',
      subtitle: 'صيدلية · الشطرة',
    );
    expect(text, contains('صيدلية الشفاء'));
    expect(text, contains('/c/pharmacy/p1'));
  });
}
