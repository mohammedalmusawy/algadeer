// نطاق Smart Brain المؤقت: «مساعد بحث وتنفيذ داخل التطبيق فقط».
// - الحوار الطبي معطّل (clinicalEnabled=false) والكود القديم سليم (الافتراضي true).
// - مُعدِّلات: متوفر/اليوم/الأكثر طلبًا.
// - سؤال تواجد طبيب من بيانات Supabase الحقيقية (دوام اليوم/إجازة/حجز).
// - نص = صوت: الرد نص واحد (plan.message) يُعرض ويُنطق كما هو.
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_today_availability.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/search_refiner.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/search_modifiers.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

const _hours = 'السبت: مساءً، الأحد: مساءً، الاثنين: مساءً، الثلاثاء: مساءً، '
    'الأربعاء: مساءً، الخميس: مساءً، الجمعة: عطلة';

/// الأحد 20 أيلول 2026 — 12:00 ظهرًا بتوقيت بغداد.
final _sunday = DateTime.utc(2026, 9, 20, 9);

SmartSearchResult _doctor(
  String id, {
  String title = 'د. ميعاد',
  String status = 'available',
  String hours = _hours,
  String from = '',
  String to = '',
  int demand = 0,
  String gender = 'female',
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: 'طب الأطفال',
    doctorId: id,
    score: 96,
    specialty: 'طب الأطفال',
    phone: '07700000000',
    whatsapp: '07700000000',
    bookingStatus: status,
    workingDays: '',
    workingHours: hours,
    absenceFrom: from,
    absenceTo: to,
    gender: gender,
    demandScore: demand,
  );
}

void main() {
  group('SearchModifiers — فهم الجمل العراقية', () {
    test('طبيب أطفال متوفر / اليوم', () {
      final a = SearchModifiers.parse('جدلي طبيب أطفال متوفر');
      expect(a.availableOnly, isTrue);
      expect(a.byDemand, isFalse);
      expect(a.cleanedQuery, 'اريد طبيب أطفال');

      final b = SearchModifiers.parse('أريد طبيب أطفال اليوم');
      expect(b.availableOnly, isTrue);
      expect(b.cleanedQuery, 'أريد طبيب أطفال');
    });

    test('الأكثر طلبًا', () {
      final a = SearchModifiers.parse('منو أكثر طبيب أطفال طلبًا؟');
      expect(a.byDemand, isTrue);
      expect(a.availableOnly, isFalse);
      expect(a.cleanedQuery, 'اريد طبيب أطفال');

      final b = SearchModifiers.parse('جدلي مختبر الأعلى طلبًا');
      expect(b.byDemand, isTrue);
      expect(b.cleanedQuery, 'اريد مختبر');
    });

    test('متوفر والأكثر طلبًا معًا', () {
      final m = SearchModifiers.parse('اريد طبيب اطفال متوفر والاكثر طلبا');
      expect(m.availableOnly, isTrue);
      expect(m.byDemand, isTrue);
      expect(m.cleanedQuery, 'اريد طبيب اطفال');
    });

    test('مختبرات: متوفر / الموجودة', () {
      expect(SearchModifiers.parse('أريد مختبر متوفر').cleanedQuery,
          'أريد مختبر');
      final list = SearchModifiers.parse('شنو المختبرات الموجودة؟');
      expect(list.availableOnly, isTrue);
      expect(list.cleanedQuery, 'اريد المختبرات');
    });

    test('لا تلمس أسئلة التحاليل/العروض/الباقات', () {
      for (final q in const [
        'أريد باقة الفحص الشامل',
        'أريد تحليل السكر الصائم',
        'شنو العروض الموجودة؟',
        'وين موجود هذا التحليل',
        'التحاليل الموجودة',
        'اتصل بدكتور علي',
        'افتح بطاقة دكتور علي',
      ]) {
        expect(SearchModifiers.parse(q).isNone, isTrue, reason: q);
      }
    });
  });

  group('DoctorPresenceQuestion', () {
    test('سؤال تواجد باسم الطبيب', () {
      expect(
        DoctorPresenceQuestion.tryParseName('هل دكتورة ميعاد متواجدة اليوم؟'),
        'ميعاد',
      );
      expect(
        DoctorPresenceQuestion.tryParseName('دكتورة ميعاد موجودة هسه؟'),
        'ميعاد',
      );
    });

    test('طلبات البحث/التنفيذ ليست أسئلة تواجد', () {
      for (final q in const [
        'هل طبيب أطفال متوفر اليوم؟',
        'جدلي طبيب أطفال متوفر',
        'أريد طبيب أطفال اليوم',
        'اتصل بدكتور علي',
        'دز واتساب للدكتور ناجي',
        'افتح بطاقة دكتور علي',
      ]) {
        expect(DoctorPresenceQuestion.tryParseName(q), isNull, reason: q);
      }
    });
  });

  group('DoctorTodayAvailability — بتوقيت بغداد', () {
    DoctorTodayAvailability at(
      DateTime nowUtc, {
      String status = 'available',
      String from = '',
      String to = '',
      String hours = _hours,
      String days = '',
    }) {
      return DoctorTodayAvailability.evaluate(
        workingDays: days,
        workingHours: hours,
        bookingStatus: status,
        absenceFrom: from,
        absenceTo: to,
        nowUtc: nowUtc,
      );
    }

    test('متواجدة ومتاح الحجز', () {
      final a = at(_sunday);
      expect(a.state, DoctorTodayState.presentBookable);
      expect(a.period, 'مساءً');
      expect(
        a.describe(doctorName: 'د. ميعاد', gender: 'female'),
        'نعم، د. ميعاد متواجدة اليوم. دوامها مساءً، وحالة الحجز متاحة.',
      );
    });

    test('متواجدة لكن الحجز مكتمل', () {
      expect(
        at(_sunday, status: 'full')
            .describe(doctorName: 'د. ميعاد', gender: 'female'),
        'د. ميعاد متواجدة اليوم لكن الحجز مكتمل.',
      );
    });

    test('في إجازة اليوم', () {
      final a = at(_sunday, from: '2026-09-19', to: '2026-09-22');
      expect(a.state, DoctorTodayState.onLeave);
      expect(
        a.describe(doctorName: 'د. ميعاد', gender: 'female'),
        'د. ميعاد اليوم في إجازة.',
      );
    });

    test('اليوم = توقيت بغداد لا UTC (منتصف الليل)', () {
      // الأحد 22:30 UTC = الاثنين 01:30 ببغداد → إجازة تنتهي الأحد لم تعد سارية.
      final monday = DateTime.utc(2026, 9, 20, 22, 30);
      expect(
        at(monday, from: '2026-09-18', to: '2026-09-20').state,
        DoctorTodayState.presentBookable,
      );
      // الخميس 22:30 UTC = الجمعة ببغداد → عطلة الجمعة.
      final friday = DateTime.utc(2026, 9, 17, 22, 30);
      expect(at(friday).state, DoctorTodayState.dayOff);
    });

    test('بلا جدول مقروء → معلومة غير مؤكدة (لا تخمين)', () {
      final a = at(_sunday, hours: '', days: '');
      expect(a.state, DoctorTodayState.unknown);
      expect(
        a.describe(doctorName: 'د. ميعاد', gender: 'female'),
        'لا توجد لدي معلومة مؤكدة عن دوام د. ميعاد اليوم.',
      );
    });

    test('أيام الدوام فقط بلا فترة: لا يُذكر وقت مخترع', () {
      final a = at(_sunday, hours: '', days: 'السبت، الأحد');
      expect(a.state, DoctorTodayState.presentBookable);
      expect(a.period, isNull);
    });
  });

  group('SearchRefiner — ترتيب حقيقي بلا إضافة/حذف', () {
    final a = _doctor('a', status: 'full', demand: 50);
    final b = _doctor('b', demand: 5);
    final c = _doctor('c', demand: 20);
    final d = _doctor('d', status: 'unavailable', demand: 999);
    final all = [a, b, c, d];

    List<String?> ids(List<SmartSearchResult> l) =>
        l.map((r) => r.doctorId).toList();

    test('متوفر أولاً', () {
      final out = SearchRefiner.apply(
        all,
        const SearchModifiers(availableOnly: true),
        nowUtc: _sunday,
      );
      expect(ids(out), ['b', 'c', 'a', 'd']);
    });

    test('الأكثر طلبًا', () {
      final out = SearchRefiner.apply(
        all,
        const SearchModifiers(byDemand: true),
        nowUtc: _sunday,
      );
      expect(ids(out), ['d', 'a', 'c', 'b']);
    });

    test('متوفر والأكثر طلبًا: المتاح أولاً ثم الطلب', () {
      final out = SearchRefiner.apply(
        all,
        const SearchModifiers(availableOnly: true, byDemand: true),
        nowUtc: _sunday,
      );
      expect(ids(out), ['c', 'b', 'a', 'd']);
      expect(
        SearchRefiner.summary(
          out,
          const SearchModifiers(availableOnly: true, byDemand: true),
          nowUtc: _sunday,
        ),
        'المتاحون منهم اليوم: 2. الترتيب حسب الأكثر طلبًا.',
      );
    });

    test('بلا مُعدِّل: النتائج كما هي', () {
      expect(identical(SearchRefiner.apply(all, SearchModifiers.none), all),
          isTrue);
      expect(SearchRefiner.summary(all, SearchModifiers.none), isNull);
    });

    test('لا بيانات طلب → لا ادعاء ترتيب', () {
      final none = [_doctor('x'), _doctor('y')];
      expect(
        SearchRefiner.summary(none, const SearchModifiers(byDemand: true)),
        'ما توجد بيانات طلب كافية للترتيب.',
      );
    });
  });

  group('SmartBrainPlanner — نطاق بحث وتنفيذ (clinicalEnabled=false)', () {
    late ConversationContext ctx;
    var doctorRow = _doctor('miaad');

    SmartBrainPlanner scoped() => SmartBrainPlanner(
          clinicalEnabled: false,
          nowUtc: () => _sunday,
          doctorLookup: (q) async {
            final n = ArabicTextUtils.normalize(q);
            if (n.contains('ميعاد')) return [doctorRow];
            return const [];
          },
        );

    setUp(() {
      ctx = ConversationContext();
      doctorRow = _doctor('miaad');
    });

    test('لغة أعراض → رسالة نطاق ثابتة، لا حوار طبي ولا تشخيص', () async {
      final plan = await scoped().plan(query: 'عندي صداع من يومين', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, SmartBrainPlanner.scopedClinicalOffMessage);
      expect(plan.kind, isNot(AssistantActionKind.guidedConversation));
      expect(plan.kind, isNot(AssistantActionKind.healthGuidance));
    });

    test('الكود القديم سليم: الافتراضي (true) لا يعرض رسالة النطاق', () async {
      final legacy = SmartBrainPlanner(doctorLookup: (q) async => const []);
      final plan = await legacy.plan(query: 'عندي صداع من يومين', context: ctx);
      expect(plan.message, isNot(SmartBrainPlanner.scopedClinicalOffMessage));
    });

    test('هل دكتورة ميعاد متواجدة اليوم؟ → من بيانات اليوم الحقيقية', () async {
      final plan = await scoped().plan(
        query: 'هل دكتورة ميعاد متواجدة اليوم؟',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.doctorId, 'miaad');
      expect(
        plan.message,
        'نعم، د. ميعاد متواجدة اليوم. دوامها مساءً، وحالة الحجز متاحة.',
      );
      // نص واحد يُعرض ويُنطق كما هو (لا مصدر ثانٍ للنطق).
      expect(plan.textFirstOnly, isFalse);
    });

    test('دكتورة ميعاد موجودة هسه؟ — دوام اليوم لا تأكيد لحظي', () async {
      final plan = await scoped().plan(
        query: 'دكتورة ميعاد موجودة هسه؟',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.message, contains('اليوم'));
      expect(plan.message, isNot(contains('الآن')));
    });

    test('إجازة / حجز مكتمل / بلا معلومة مؤكدة', () async {
      doctorRow = _doctor('miaad', from: '2026-09-19', to: '2026-09-22');
      var plan = await scoped().plan(
        query: 'هل دكتورة ميعاد متواجدة اليوم؟',
        context: ConversationContext(),
      );
      expect(plan.message, 'د. ميعاد اليوم في إجازة.');

      doctorRow = _doctor('miaad', status: 'full');
      plan = await scoped().plan(
        query: 'هل دكتورة ميعاد متواجدة اليوم؟',
        context: ConversationContext(),
      );
      expect(plan.message, 'د. ميعاد متواجدة اليوم لكن الحجز مكتمل.');

      doctorRow = _doctor('miaad', hours: '');
      plan = await scoped().plan(
        query: 'هل دكتورة ميعاد متواجدة اليوم؟',
        context: ConversationContext(),
      );
      expect(plan.message, contains('لا توجد لدي معلومة مؤكدة'));
    });

    test('طبيب أطفال اليوم → بحث اختصاص + مُعدِّل (لا سؤال تواجد)', () async {
      final plan = await scoped().plan(
        query: 'أريد طبيب أطفال اليوم',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.runSpecialtySearch);
      expect(plan.modifiers.availableOnly, isTrue);
    });

    test('أكثر طبيب أطفال طلبًا → مُعدِّل الطلب', () async {
      final plan = await scoped().plan(
        query: 'منو أكثر طبيب أطفال طلبًا؟',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.runSpecialtySearch);
      expect(plan.modifiers.byDemand, isTrue);
    });

    test('مختبر الأعلى طلبًا → مُعدِّل الطلب على بحث المختبرات', () async {
      final plan = await scoped().plan(
        query: 'جدلي مختبر الأعلى طلبًا',
        context: ctx,
      );
      expect(plan.modifiers.byDemand, isTrue);
      expect(plan.kind, isNot(AssistantActionKind.showMessage));
    });
  });
}
