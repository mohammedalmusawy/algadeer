import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_navigation.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';

void main() {
  group('ArabicTextUtils doctor search', () {
    test('strips doctor honorifics including الدكتورة', () {
      expect(
        ArabicTextUtils.stripHonorifics('الدكتورة اساور'),
        'اساور',
      );
      expect(
        ArabicTextUtils.stripHonorifics('الدكتورة أساور'),
        'أساور',
      );
      expect(
        ArabicTextUtils.stripHonorifics('د. علي'),
        'علي',
      );
      expect(
        ArabicTextUtils.stripHonorifics('دكتور محمد'),
        'محمد',
      );
    });

    test('normalizes alef forms for fuzzy compare', () {
      expect(
        ArabicTextUtils.normalize('أساور'),
        ArabicTextUtils.normalize('اساور'),
      );
      expect(
        ArabicTextUtils.scoreMatch('أساور زين العابدين المصور', 'اساور'),
        greaterThanOrEqualTo(70),
      );
      expect(
        ArabicTextUtils.scoreMatch(
          'أساور زين العابدين المصور',
          'الدكتورة اساور',
        ),
        greaterThanOrEqualTo(70),
      );
    });

    test('doctorSearchVariants covers titles and alef forms', () {
      final variants =
          ArabicTextUtils.doctorSearchVariants('الدكتورة اساور');
      expect(variants, contains('اساور'));
      expect(variants.any((v) => v.contains('أساور') || v == 'أساور'), isTrue);

      final variants2 =
          ArabicTextUtils.doctorSearchVariants('أساور زين العابدين');
      expect(variants2, contains('أساور'));
      expect(variants2, contains('اساور'));
      expect(variants2.any((v) => v.contains('زين')), isTrue);
    });

    test('strips glued honorific without space', () {
      expect(
        ArabicTextUtils.stripHonorifics('الدكتورعلي ناصر'),
        'علي ناصر',
      );
      expect(
        ArabicTextUtils.scoreDoctorNameMatch(
          'الدكتور علي ناصر السعيدي',
          'الدكتورعلي ناصر السعيدي',
        ),
        greaterThanOrEqualTo(90),
      );
    });

    test('multi-word name requires every token on the same doctor', () {
      const saeedi = 'الدكتور علي ناصر السعيدي';
      const fleih = 'الدكتور علي فليح جودة';

      expect(
        ArabicTextUtils.scoreDoctorNameMatch(saeedi, 'الدكتور علي ناصر السعيدي'),
        100,
      );
      expect(
        ArabicTextUtils.scoreDoctorNameMatch(fleih, 'الدكتور علي ناصر السعيدي'),
        0,
      );

      expect(
        ArabicTextUtils.scoreDoctorNameMatch(saeedi, 'علي ناصر'),
        greaterThanOrEqualTo(90),
      );
      expect(ArabicTextUtils.scoreDoctorNameMatch(fleih, 'علي ناصر'), 0);

      expect(
        ArabicTextUtils.scoreDoctorNameMatch(fleih, 'علي فليح'),
        greaterThanOrEqualTo(90),
      );
      expect(ArabicTextUtils.scoreDoctorNameMatch(saeedi, 'علي فليح'), 0);

      expect(
        ArabicTextUtils.scoreDoctorNameMatch(saeedi, 'ناصر السعيدي'),
        greaterThanOrEqualTo(90),
      );
      expect(
        ArabicTextUtils.scoreDoctorNameMatch(fleih, 'فليح جودة'),
        greaterThanOrEqualTo(90),
      );

      final aliSaeedi = ArabicTextUtils.scoreDoctorNameMatch(saeedi, 'علي');
      final aliFleih = ArabicTextUtils.scoreDoctorNameMatch(fleih, 'علي');
      expect(aliSaeedi, greaterThanOrEqualTo(75));
      expect(aliFleih, greaterThanOrEqualTo(75));
    });

    test('shows doctor while typing name progressively', () {
      const saeedi = 'الدكتور علي ناصر السعيدي';

      expect(
        ArabicTextUtils.scoreDoctorNameMatch(saeedi, 'عل'),
        greaterThanOrEqualTo(40),
      );
      expect(
        ArabicTextUtils.scoreDoctorNameMatch(saeedi, 'علي'),
        greaterThanOrEqualTo(75),
      );
      expect(
        ArabicTextUtils.scoreDoctorNameMatch(saeedi, 'علي ناص'),
        greaterThanOrEqualTo(80),
      );
      expect(
        ArabicTextUtils.scoreDoctorNameMatch(saeedi, 'محم'),
        0,
      );
    });

    test('normalizes Persian yeh from speech and optional al- article', () {
      const doctor = 'الدكتور علي ناصر السعيدي';
      // ی = U+06CC (Persian), often produced by macOS speech.
      const spokenSaeedi = 'الدكتور عل\u06cc ناصر السعيد\u06cc';
      expect(
        ArabicTextUtils.normalize('عل\u06cc'),
        ArabicTextUtils.normalize('علي'),
      );
      expect(
        ArabicTextUtils.scoreDoctorNameMatch(doctor, spokenSaeedi),
        greaterThanOrEqualTo(90),
      );
      expect(
        ArabicTextUtils.scoreDoctorNameMatch('علي ناصر سعيدي', 'ناصر السعيدي'),
        greaterThanOrEqualTo(90),
      );
      expect(ArabicTextUtils.looksLikeDoctorNameQuery(doctor), isTrue);
    });
  });

  group('SmartNavigation with female doctor title', () {
    test('opens single doctor for الدكتورة أساور', () {
      final decision = SmartNavigationResolver().resolve(
        query: 'الدكتورة أساور',
        results: const [
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'أساور زين العابدين المصور',
            subtitle: 'نسائية',
            doctorId: 'd-asawer',
            score: 90,
          ),
        ],
      );

      expect(decision.shouldNavigateDirectly, isTrue);
      expect(decision.action, SmartNavAction.openDoctor);
      expect(decision.target?.doctorId, 'd-asawer');
    });
  });
}
