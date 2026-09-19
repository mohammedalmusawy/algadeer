import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/doctor_name_matcher.dart';

void main() {
  const matcher = DoctorNameMatcher();

  group('compound عبد normalization', () {
    test('عبدالله ↔ عبد الله canonicalize to same form', () {
      expect(
        ArabicTextUtils.canonicalizeCompoundNames('ناجي عبدالله الركابي'),
        ArabicTextUtils.canonicalizeCompoundNames('ناجي عبد الله الركابي'),
      );
      expect(
        ArabicTextUtils.prepareDoctorNameQuery('دكتور ناجي عبدالله الركابي'),
        'ناجي عبدالله الركابي',
      );
      expect(
        ArabicTextUtils.prepareDoctorStoredName('ناجي عبد الله الركابي'),
        'ناجي عبدالله الركابي',
      );
    });

    test('does not blindly split unrelated عبد prefixes', () {
      // كلمة ليست من قائمة المكمّلات تبقى كما هي.
      expect(
        ArabicTextUtils.canonicalizeCompoundNames('عبدشمس القبيلة'),
        'عبدشمس القبيلة',
      );
    });
  });

  group('DoctorNameMatcher golden suite', () {
    test('A) stored spaced — query joined with title', () {
      final m = matcher.score(
        doctorName: 'ناجي عبد الله الركابي',
        query: 'دكتور ناجي عبدالله الركابي',
      );
      expect(m.score, greaterThanOrEqualTo(90));
      expect(m.matchType, isNot(DoctorNameMatchType.none));
    });

    test('B) stored joined — query spaced', () {
      final m = matcher.score(
        doctorName: 'ناجي عبدالله الركابي',
        query: 'ناجي عبد الله الركابي',
      );
      expect(m.score, greaterThanOrEqualTo(90));
    });

    test('C) first + family', () {
      final m = matcher.score(
        doctorName: 'ناجي عبد الله الركابي',
        query: 'ناجي الركابي',
      );
      expect(m.score, greaterThanOrEqualTo(90));
      expect(
        m.matchType == DoctorNameMatchType.firstAndFamily ||
            m.matchType == DoctorNameMatchType.orderedTokens,
        isTrue,
      );
    });

    test('D) title + first name unique', () {
      final batch = matcher.matchDoctors(
        query: 'دكتور ناجي',
        doctors: const [
          (id: '1', name: 'ناجي عبد الله الركابي'),
          (id: '2', name: 'علي فليح جودة'),
        ],
      );
      expect(batch.matches, hasLength(1));
      expect(batch.matches.first.doctorId, '1');
      expect(batch.isAmbiguous, isFalse);
    });

    test('E) دكتور علي — AMBIGUOUS', () {
      final batch = matcher.matchDoctors(
        query: 'دكتور علي',
        doctors: const [
          (id: 'a', name: 'علي ناصر السعيدي'),
          (id: 'b', name: 'علي فليح جودة'),
        ],
      );
      expect(batch.matches.length, greaterThanOrEqualTo(2));
      expect(batch.isAmbiguous, isTrue);
      expect(batch.best?.isStrong, isFalse);
    });

    test('F) علي فليح — correct candidate', () {
      final batch = matcher.matchDoctors(
        query: 'علي فليح',
        doctors: const [
          (id: 'a', name: 'علي ناصر السعيدي'),
          (id: 'b', name: 'علي فليح جودة'),
        ],
      );
      expect(batch.isAmbiguous, isFalse);
      expect(batch.best?.doctorId, 'b');
      expect(batch.best!.score, greaterThanOrEqualTo(90));
    });

    test('G) الدكتورة أساور زين العابدين المصور', () {
      final m = matcher.score(
        doctorName: 'أساور زين العابدين المصور',
        query: 'الدكتورة أساور زين العابدين المصور',
      );
      expect(m.score, greaterThanOrEqualTo(90));
    });

    test('H) unrelated name — no confident match', () {
      final batch = matcher.matchDoctors(
        query: 'دكتور سمير الخيالي',
        doctors: const [
          (id: '1', name: 'ناجي عبد الله الركابي'),
          (id: '2', name: 'علي فليح جودة'),
        ],
      );
      expect(batch.matches, isEmpty);
    });

    test('I) unordered lower than ordered full name', () {
      const stored = 'ناجي عبد الله الركابي';
      final ordered = matcher.score(
        doctorName: stored,
        query: 'ناجي عبدالله الركابي',
      );
      final unordered = matcher.score(
        doctorName: stored,
        query: 'الركابي ناجي عبدالله',
      );
      expect(ordered.score, greaterThan(unordered.score));
      expect(unordered.matchType, DoctorNameMatchType.unordered);
    });

    test('J) title only — not a doctor name', () {
      expect(matcher.isTitleOnlyQuery('دكتور'), isTrue);
      expect(matcher.isTitleOnlyQuery('الدكتورة'), isTrue);
      final batch = matcher.matchDoctors(
        query: 'دكتور',
        doctors: const [
          (id: '1', name: 'ناجي عبد الله الركابي'),
        ],
      );
      expect(batch.matches, isEmpty);
    });

    test('spoken noise: اريد الدكتور ناجي الركابي', () {
      final m = matcher.score(
        doctorName: 'ناجي عبد الله الركابي',
        query: 'اريد الدكتور ناجي الركابي',
      );
      expect(m.score, greaterThanOrEqualTo(90));
    });

    test('عبدالرحمن spaced/joined', () {
      expect(
        matcher
            .score(
              doctorName: 'محمد عبد الرحمن العلي',
              query: 'محمد عبدالرحمن العلي',
            )
            .score,
        greaterThanOrEqualTo(90),
      );
    });
  });
}
