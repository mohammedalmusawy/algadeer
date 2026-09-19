/// جودة بحث الأطباء والاختصاصات — تثبيت قبل البيتا.
///
/// كل الحالات تستخدم قيم بيانات حقيقية من منصة الغدير (أسماء/اختصاصات كما
/// هي مخزّنة) عبر المكوّنات القائمة: DoctorNameMatcher / SpecialtyCatalog /
/// VoiceSpecialtySearchCommand / SmartBrainPlanner — بلا حلول خاصة بطبيب.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/specialty_catalog.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/doctor_name_matcher.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/search/voice_specialty_search_command.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

/// أسماء/اختصاصات كما هي مخزّنة في جدول doctors.
const _stored = <({String id, String name})>[
  (id: 'asawer', name: 'الدكتورة اساور زين العابدين المصور'),
  (id: 'meaad', name: 'الدكتورة ميعاد جاسم محمد'),
  (id: 'haider', name: 'الدكتور حيدر حسن الشمخاوي'),
  (id: 'naji', name: 'الدكتور ناجي عبدالله الركابي'),
  (id: 'fleih', name: 'الدكتور الأستشاري علي فليح جودة'),
  (id: 'saeedi', name: 'الدكتور علي ناصر السعيدي'),
];

const _najiSpecialty =
    'م. اختصاص جراحة العظام والمفاصل والكسور والفقرات والأعصاب خبرة أكثر من '
    '25 سنة في علاج أمراض العظام والروماتزم والإصابات الرياضيه';

SmartSearchResult _doctorCard(
  String id,
  String title, {
  required String specialty,
  int score = 90,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty,
    doctorId: id,
    score: score,
    specialty: specialty,
    phone: '0770',
    whatsapp: '0770',
  );
}

SmartSearchResult _specialtyCard(String specialty, {int score = 0}) {
  return SmartSearchResult(
    type: SmartSearchResultType.specialty,
    title: specialty,
    subtitle: 'اختصاص',
    score: score,
    specialty: specialty,
  );
}

void main() {
  const matcher = DoctorNameMatcher();
  final resolver = RuleBasedIntentResolver();

  group('A — full doctor name → one strong semantic match', () {
    test('كل صيغ الاسم الكامل تعطي طبيباً قوياً واحداً', () {
      for (final q in const [
        'دكتور علي ناصر السعيدي',
        'الدكتور علي ناصر السعيدي',
        'د. علي ناصر السعيدي',
        'علي ناصر السعيدي',
      ]) {
        final batch = matcher.matchDoctors(query: q, doctors: _stored);
        expect(batch.matches, hasLength(1), reason: q);
        expect(batch.matches.first.doctorId, 'saeedi', reason: q);
        expect(batch.matches.first.isStrong, isTrue, reason: q);
        expect(batch.isAmbiguous, isFalse, reason: q);
      }
    });

    test('اختصاص الطبيب لا يُحتسب كتطابق طبيب ثانٍ', () {
      // ما يعيده البحث فعلياً: طبيب + بطاقة اختصاصه.
      final results = [
        _doctorCard('saeedi', 'الدكتور علي ناصر السعيدي',
            specialty: 'طب الأطفال', score: 100),
        _specialtyCard('طب الأطفال'),
      ];
      final counted = SmartSearchResult.semanticPrimary(results);
      expect(counted, hasLength(1));
      expect(counted.first.type, SmartSearchResultType.doctor);
      // البطاقة تبقى معروضة للتنقّل.
      expect(results, hasLength(2));
    });
  });

  group('B — «علي ناصر» بلا عدد أطباء مُضلِّل', () {
    test('طبيب واحد + بطاقة اختصاص = نتيجة دلالية واحدة', () {
      final batch =
          matcher.matchDoctors(query: 'علي ناصر', doctors: _stored);
      expect(batch.matches, hasLength(1));
      expect(batch.matches.first.doctorId, 'saeedi');

      final results = [
        _doctorCard('saeedi', 'الدكتور علي ناصر السعيدي',
            specialty: 'طب الأطفال', score: 96),
        _specialtyCard('طب الأطفال'),
      ];
      expect(SmartSearchResult.semanticPrimary(results), hasLength(1));
    });

    test('لا نتائج إطلاقاً → تبقى القائمة كما هي للعدّ', () {
      expect(SmartSearchResult.semanticPrimary(const []), isEmpty);
      // اختصاص بلا طبيب (بحث اختصاص صريح) لا يُصفّر الرسالة.
      final onlySpecialty = [_specialtyCard('طب الأطفال', score: 70)];
      expect(SmartSearchResult.semanticPrimary(onlySpecialty), hasLength(1));
    });
  });

  group('C — خطأ إملائي بسيط → اقتراح آمن', () {
    test('«علي ناصر السعدي» يقترح د. علي ناصر السعيدي', () {
      final s = matcher.suggestCorrection(
        query: 'علي ناصر السعدي',
        doctors: _stored,
      );
      expect(s, isNotNull);
      expect(s!.doctorId, 'saeedi');
      expect(s.distance, lessThanOrEqualTo(2));
      expect(
        ArabicTextUtils.stripHonorifics(s.doctorName).trim(),
        'علي ناصر السعيدي',
      );
    });

    test('اسم مطابق فعلاً → لا اقتراح (الاقتراح بديل لا-نتيجة فقط)', () {
      expect(
        matcher.suggestCorrection(
          query: 'علي ناصر السعيدي',
          doctors: _stored,
        ),
        isNull,
      );
      expect(
        matcher.suggestCorrection(query: 'علي ناصر', doctors: _stored),
        isNull,
      );
    });

    test('اسم مفرد أو بعيد → لا اقتراح ولا تخمين', () {
      // توكن واحد لا يكفي للاقتراح.
      expect(
        matcher.suggestCorrection(query: 'السعدي', doctors: _stored),
        isNull,
      );
      // اسم غير موجود إطلاقاً.
      expect(
        matcher.suggestCorrection(query: 'سمير الخيالي', doctors: _stored),
        isNull,
      );
      // فرق كبير في توكنين معاً.
      expect(
        matcher.suggestCorrection(query: 'علي نصور السعودي', doctors: _stored),
        isNull,
      );
    });

    test('تشابه مع أكثر من طبيب → لا اقتراح واحد عشوائي', () {
      const twins = <({String id, String name})>[
        (id: 'a', name: 'علي ناصر السعيدي'),
        (id: 'b', name: 'علي ناصر السعودي'),
      ];
      expect(
        matcher.suggestCorrection(query: 'علي ناصر السعدي', doctors: twins),
        isNull,
      );
    });

    test('الاقتراح من أطباء المنصة فقط — قائمة فارغة = لا اقتراح', () {
      expect(
        matcher.suggestCorrection(query: 'علي ناصر السعدي', doctors: const []),
        isNull,
      );
    });
  });

  group('D — «دكتور علي» غامض بلا اختيار عشوائي', () {
    test('مرشّحان بلا تطابق قوي', () {
      final batch =
          matcher.matchDoctors(query: 'دكتور علي', doctors: _stored);
      expect(batch.matches.length, greaterThanOrEqualTo(2));
      expect(batch.isAmbiguous, isTrue);
      expect(batch.best?.isStrong, isFalse);
      expect(
        batch.matches.map((m) => m.doctorId),
        containsAll(<String>['fleih', 'saeedi']),
      );
    });

    test('العدّ الدلالي يحفظ الطبيبين ويستثني بطاقات الاختصاص', () {
      final results = [
        _doctorCard('fleih', 'الدكتور الأستشاري علي فليح جودة',
            specialty: 'الأنف والأذن والحنجرة', score: 85),
        _doctorCard('saeedi', 'الدكتور علي ناصر السعيدي',
            specialty: 'طب الأطفال', score: 85),
        _specialtyCard('الأنف والأذن والحنجرة'),
        _specialtyCard('طب الأطفال'),
      ];
      expect(SmartSearchResult.semanticPrimary(results), hasLength(2));
    });
  });

  group('E/F/G — مفاصل / كسور / عظام عبر taxonomy الحالية', () {
    test('الصيغ الطبيعية تُصنَّف بحث اختصاص لا بحث اسم', () {
      const cases = {
        'اريد طبيب مفاصل': 'المفاصل',
        'أريد طبيب مفاصل': 'المفاصل',
        'طبيب مفاصل': 'المفاصل',
        'دكتور مفاصل': 'المفاصل',
        'اريد طبيب كسور': 'العظام والكسور والمفاصل',
        'أريد طبيب كسور': 'العظام والكسور والمفاصل',
        'دكتور كسور': 'العظام والكسور والمفاصل',
        'طبيب عظام': 'العظام والكسور والمفاصل',
        'دكتور عظام': 'العظام والكسور والمفاصل',
      };
      cases.forEach((query, expected) {
        final cmd = VoiceSpecialtySearchCommand.tryParse(query);
        expect(cmd, isNotNull, reason: query);
        expect(cmd!.resolvedSpecialtyName, expected, reason: query);

        final intent = resolver.resolve(query);
        expect(
          intent.intent,
          AssistantIntent.specialtySearch,
          reason: query,
        );
        expect(intent.entities.specialty, expected, reason: query);
      });
    });

    test('الاختصاص المُطابَق يصل فعلاً لاختصاص الطبيب المخزَّن', () {
      // الطبيب الحقيقي الوحيد للعظام/المفاصل/الكسور في البيانات الحالية.
      expect(
        SpecialtyCatalog.match(_najiSpecialty)?.nameAr,
        'العظام والكسور والمفاصل',
      );

      for (final resolved in const [
        'العظام والكسور والمفاصل',
        'المفاصل',
      ]) {
        // نفس عتبة تصفية الأطباء في مسار الاختصاص.
        expect(
          ArabicTextUtils.scoreMatch(_najiSpecialty, resolved),
          greaterThanOrEqualTo(55),
          reason: resolved,
        );
      }
    });

    test('مصطلحات الكتالوج تُطابق بكلمة كاملة فقط', () {
      expect(SpecialtyCatalog.isSpecialtyTerm('كسور'), isTrue);
      expect(SpecialtyCatalog.isSpecialtyTerm('مفاصل'), isTrue);
      expect(SpecialtyCatalog.isSpecialtyTerm('عظام'), isTrue);
      expect(SpecialtyCatalog.isSpecialtyTerm('العظام'), isTrue);
      // «سن» اختصاص أسنان، لكن «حسن» اسم شخص — لا احتواء جزئي.
      expect(SpecialtyCatalog.isSpecialtyTerm('حسن'), isFalse);
      expect(SpecialtyCatalog.isSpecialtyTerm('الشمخاوي'), isFalse);
      expect(SpecialtyCatalog.isSpecialtyTerm('ناصر'), isFalse);
    });

    test('أسماء الأطباء لا تُختطف كبحث اختصاص', () {
      for (final q in const [
        'دكتور علي ناصر السعيدي',
        'ابحثلي عن دكتور حسن',
        'ابحثلي عن دكتور حيدر حسن الشمخاوي',
        'ابحثلي عن طبيب ناجي',
      ]) {
        expect(VoiceSpecialtySearchCommand.tryParse(q), isNull, reason: q);
        expect(
          resolver.resolve(q).intent,
          AssistantIntent.doctorSearch,
          reason: q,
        );
      }
    });
  });

  group('H/I/J — سياق المحادثة والتبديل الصريح', () {
    late ConversationContext ctx;
    late SmartBrainPlanner planner;
    late List<String> lookups;

    final saeedi = _doctorCard(
      'saeedi',
      'الدكتور علي ناصر السعيدي',
      specialty: 'طب الأطفال',
      score: 96,
    );

    setUp(() {
      ctx = ConversationContext();
      lookups = <String>[];
      planner = SmartBrainPlanner(
        doctorLookup: (q) async {
          lookups.add(q);
          final n = ArabicTextUtils.normalize(q);
          if (n.contains('علي') && n.contains('ناصر')) return [saeedi];
          return const [];
        },
      );
    });

    test('H — «علي ناصر» ثم «ارسل واتساب» يبقى على نفس الطبيب', () async {
      ctx.rememberResults([saeedi], query: 'علي ناصر');
      lookups.clear();

      final plan = await planner.plan(query: 'ارسل واتساب', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'saeedi');
      expect(lookups, isEmpty);
    });

    test('I — «علي ناصر» ثم «اتصل» يبقى على نفس الطبيب', () async {
      ctx.rememberResults([saeedi], query: 'علي ناصر');
      lookups.clear();

      final plan = await planner.plan(query: 'اتصل', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'saeedi');
      expect(lookups, isEmpty);
    });

    test('J — «علي ناصر» ثم «اريد طبيب كسور» = بحث اختصاص جديد', () async {
      ctx.rememberResults([saeedi], query: 'علي ناصر');
      expect(ctx.selectedDoctor?.doctorId, 'saeedi');

      final plan = await planner.plan(
        query: 'اريد طبيب كسور',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.runSpecialtySearch);
      expect(plan.specialtyQuery, 'العظام والكسور والمفاصل');
      // لا يُعاد استخدام الطبيب السابق كهدف.
      expect(plan.target?.doctorId, isNot('saeedi'));
      expect(ctx.selectedDoctor?.doctorId, isNot('saeedi'));
    });
  });
}
