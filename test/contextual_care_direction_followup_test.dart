/// «وين توجهني؟» داخل محادثة طبية قائمة — Smart Brain V1.
///
/// العطل الحقيقي: في محادثة سريرية نشطة، سؤال المتابعة «وين توجهني» كان
/// يُقرأ نصاً حرفياً. الحزم السريرية تعرف هذا المعنى أصلاً باسم
/// `asksServiceWhere`، لكن مفرداته كانت محصورة بـ«وين اروح / منو اراجع /
/// منو الطبيب»، فيرجع `mayHandle` كذباً ويسقط الدور من تحكيم PC-1.24. بعدها
/// يقصّ مستخرِج الكيانات «وين» كبادئة موقع فتبقى «توجهني»، فتُقرأ اسم طبيب
/// (`intent = doctorSearch`, `doctorQuery = توجهني`) ويصل الدور إلى بحث
/// Supabase الحرفي وينتهي بـ«ما لقيت نتيجة مطابقة حالياً.».
///
/// الإصلاح: مصدر واحد `ClinicalCareDirectionRequest` يوسّع نفس المعنى القائم،
/// ويُستشار حصراً عندما تكون الجلسة نشطة — فأسئلة البداية العامة تبقى في
/// مسارها الوقائي (PC-1.7) ولا تُخطف.
///
/// يمر عبر `SmartBrainPlanner.plan` العام مع `ConversationContext` — نفس سلطة
/// `SmartSearchPage`. لا APIs خاصة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/clinical_care_direction_request.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نص السقوط الحرفي الذي يجب ألا يظهر لسؤال سياقي.
const _literalMiss = 'ما لقيت نتيجة مطابقة';

/// نص جدار الخصوصية القائم — نتحقق من بقائه، ولا نغيّره.
const _subjectClarification = 'حدّد عن مَن نتكلم';

/// أفعال البحث التي يجب ألا يقع فيها سؤال التوجيه السياقي.
const _searchKinds = <AssistantActionKind>[
  AssistantActionKind.runDoctorSearch,
  AssistantActionKind.runSpecialtySearch,
  AssistantActionKind.runGeneralSearch,
];

/// الصياغات العراقية الطبيعية لسؤال «وين توجهني».
const _careDirectionVariants = <String>[
  'وين توجهني',
  'وين اتوجه',
  'وين أراجع',
  'شنو تنصحني',
  'شنو تنصحني اسوي',
  'أي اختصاص أراجع',
  'أي طبيب أراجع',
];

SmartSearchResult _doc(String id, String title, String specialty) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty,
    doctorId: id,
    specialty: specialty,
    phone: '07700000000',
    whatsapp: '07700000000',
    clinicLocation: 'الكرادة',
    score: 96,
  );
}

final _saeedi = _doc('saeedi', 'الدكتور علي ناصر السعيدي', 'طب الأطفال');
final _dentist = _doc('dent', 'الدكتورة سارة أحمد', 'طب الأسنان');

class _Harness {
  _Harness() {
    context = ConversationContext();
    planner = SmartBrainPlanner(
      doctorLookup: (q) async {
        lookups.add(q);
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('اسنان')) return [_dentist];
        if (n.contains('السعيدي') || n.contains('اطفال')) return [_saeedi];
        return const [];
      },
      labLookup: (_) async => const [],
      analysisLookup: (_) async => const [],
      packagesLookup: (_) async => const [],
      packagesForAnalysisLookup: (_) async => const [],
      activePackagesLookup: ({labId, nameQuery}) async => const [],
      discountedPackagesLookup: ({labId}) async => const [],
    );
  }

  late final ConversationContext context;
  late final SmartBrainPlanner planner;
  final List<String> lookups = <String>[];

  Future<AssistantActionPlan> turn(String query) =>
      planner.plan(query: query, context: context);

  /// دور تمهيدي واحد يجعل الجلسة «قائمة» كما في التطبيق الحقيقي، فيستقر رابط
  /// الشخص. هذا نفس التمهيد الذي تحتاجه اختبارات الاستمرارية القائمة.
  Future<void> warmUpExistingSession() async {
    await turn('علي ناصر السعدي');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  /// يؤكد أن سؤال التوجيه بقي داخل المحادثة ولم يصبح بحثاً حرفياً.
  void expectContextualGuidance(_Harness h, AssistantActionPlan plan) {
    expect(
      plan.kind,
      isNot(isIn(_searchKinds)),
      reason: 'سؤال التوجيه صار بحثاً: ${plan.kind}',
    );
    // ملاحظة: طبقة النية ما زالت تصنّف «وين توجهني» كـ doctorSearch — سلطة
    // تحكيم PC-1.24 هي التي تحسم الدور قبل أي توجيه بحث، فالمقياس هو أن
    // الدور لم يُنفَّذ كبحث ولم يصل أي نص للاستعلام.
    expect(plan.message.contains(_literalMiss), isFalse);
    expect(plan.message.trim(), isNotEmpty);
    expect(
      h.lookups,
      isEmpty,
      reason: 'ممنوع أي استعلام أطباء على نص سؤال التوجيه: ${h.lookups}',
    );
  }

  group('أ — جلسة تنفسية قائمة للمالك + «وين توجهني»', () {
    test('لا يصبح بحثاً حرفياً في Supabase', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      await h.turn('اني عندي سعال من اسبوعين');
      await h.turn('اي عندي بلغم');
      expect(h.context.respiratorySession.active, isTrue,
          reason: 'الشرط المسبق: جلسة سريرية نشطة');

      h.lookups.clear();
      final plan = await h.turn('وين توجهني');

      expectContextualGuidance(h, plan);
      expect(h.context.respiratorySession.active, isTrue,
          reason: 'سؤال التوجيه لا يُنهي الجلسة');
    });

    test('«وين توجهني» يجيب من وجهة الجلسة القائمة', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      await h.turn('اني عندي سعال من اسبوعين');
      await h.turn('اي عندي بلغم');
      final plan = await h.turn('وين توجهني');

      expect(plan.message.contains('الوجهة'), isTrue,
          reason: 'يُتوقع جواب وجهة من الحزمة: ${plan.message}');
    });
  });

  group('ب — الصياغات الطبيعية تمر بنفس الآلية', () {
    for (final variant in _careDirectionVariants) {
      test('«$variant» يبقى توجيهاً سياقياً', () async {
        final h = _Harness();
        await h.warmUpExistingSession();
        await h.turn('اني عندي سعال من اسبوعين');
        await h.turn('اي عندي بلغم');

        h.lookups.clear();
        final plan = await h.turn(variant);
        expectContextualGuidance(h, plan);
      });
    }

    test('جلسة عظام نشطة + «وين توجهني» تبقى عظمية', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      await h.turn('اني عندي ألم بالظهر');
      await h.turn('صار له اسبوعين');
      expect(h.context.mskSession.active, isTrue);

      h.lookups.clear();
      final plan = await h.turn('وين توجهني');
      expectContextualGuidance(h, plan);
      expect(h.context.mskSession.active, isTrue);
    });

    test('جلسة طفل تنفسية بعد إغلاق السؤال + «وين توجهني»', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      await h.turn('ابني عنده سعال من يومين');
      await h.turn('عمره 8 سنوات');
      await h.turn('اي ما عنده حرارة');
      await h.turn('لا ما يأثر');
      expect(h.context.respiratorySession.lastQuestionKey, isNull,
          reason: 'الشرط المسبق للعطل: ما بقي سؤال معلّق يمسك الدور');

      h.lookups.clear();
      final plan = await h.turn('وين توجهني');
      expectContextualGuidance(h, plan);
    });
  });

  group('ج — الطلبات الصريحة تبقى بحثاً طبيعياً', () {
    test('«أريد طبيب أطفال» في محادثة جديدة يبحث اختصاصاً', () async {
      final h = _Harness();
      final plan = await h.turn('أريد طبيب أطفال');

      expect(plan.intentResult.intent, AssistantIntent.specialtySearch);
      expect(plan.kind, AssistantActionKind.runSpecialtySearch);
    });

    test('«أريد طبيب أسنان» بعد جلسة تنفسية ينتقل للأسنان', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      await h.turn('اني عندي سعال من اسبوعين');

      final plan = await h.turn('أريد طبيب أسنان');
      expect(
        plan.intentResult.intent == AssistantIntent.specialtySearch ||
            plan.kind == AssistantActionKind.runSpecialtySearch ||
            plan.message.contains('أسنان'),
        isTrue,
        reason: 'النية الصريحة تفوز: ${plan.kind} ${plan.message}',
      );
    });

    test('«شنو تنصحني» بلا جلسة سريرية يبقى في المسار الوقائي', () async {
      final h = _Harness();
      final plan = await h.turn('شنو تنصحني');

      expect(h.context.respiratorySession.active, isFalse,
          reason: 'سؤال بداية عام ما يفتح جلسة تنفسية');
      expect(plan.kind, isNot(isIn(_searchKinds)));
      expect(plan.message.trim(), isNotEmpty);
    });

    test('«أنا طالب شنو تنصحني؟» يبقى نصائح وقائية', () async {
      final h = _Harness();
      final plan = await h.turn('أنا طالب شنو تنصحني؟');

      expect(h.context.respiratorySession.active, isFalse);
      expect(plan.message.contains('طالب'), isTrue,
          reason: 'المسار الوقائي القائم: ${plan.message}');
    });
  });

  group('د — كاشف طلب الوجهة نفسه', () {
    test('يطابق الصياغات الطبيعية', () {
      for (final variant in _careDirectionVariants) {
        expect(ClinicalCareDirectionRequest.matches(variant), isTrue,
            reason: variant);
      }
    });

    test('لا يطابق طلب طبيب أو شكوى أو نصاً فارغاً', () {
      const others = <String>[
        '',
        'أريد طبيب أطفال',
        'دكتور علي ناصر السعيدي',
        'عندي سعال من يومين',
        'اتصل',
        'نعم',
        'وين موقع العيادة',
      ];
      for (final other in others) {
        expect(ClinicalCareDirectionRequest.matches(other), isFalse,
            reason: other);
      }
    });
  });

  group('هـ — السلوكيات المحمية تبقى كما هي', () {
    test('استمرارية سعال الطفل مع «عمره 8 سنوات»', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      await h.turn('ابني عنده سعال من يومين');

      h.lookups.clear();
      final age = await h.turn('عمره 8 سنوات');
      expect(h.context.respiratorySession.active, isTrue);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
      expect(age.kind, isNot(isIn(_searchKinds)));
      expect(h.lookups, isEmpty);
      expect(h.context.dentalSession.active, isFalse,
          reason: '«سنوات» لا تُقرأ أسناناً');
    });

    test('«نعم» الحرّة بلا حالة معلّقة لا تُبحث', () async {
      final h = _Harness();
      final plan = await h.turn('نعم');

      expect(plan.kind, isNot(isIn(_searchKinds)));
      expect(plan.message.contains(_literalMiss), isFalse);
      expect(h.lookups, isEmpty);
    });

    test('اقتراح تصحيح الاسم ثم «نعم» يحل الطبيب الحقيقي', () async {
      final h = _Harness();
      h.context.setPendingDoctorSuggestion(
        const PendingDoctorSuggestion(
          doctorId: 'saeedi',
          doctorName: 'الدكتور علي ناصر السعيدي',
        ),
      );

      final yes = await h.turn('نعم');
      expect(yes.kind, AssistantActionKind.selectEntity);
      expect(yes.target?.doctorId, 'saeedi');
    });

    test('«اني» بعد جلسة طفل تعيد الموضوع لصاحب الحساب', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      await h.turn('ابني عنده سعال من يومين');
      await h.turn('عمره 8 سنوات');

      final self = await h.turn('اني عندي ألم بالظهر');
      expect(h.context.resolvedConversationSubject.isAccountOwner, isTrue);
      expect(self.message.contains(_subjectClarification), isFalse);
    });

    test('جدار الخصوصية يبقى فعّالاً حين لا يُحدَّد الشخص', () async {
      final h = _Harness();
      // التمهيد غير السريري هو ما يزرع الشخص المؤقت، وبدونه لا يظهر الحاجب.
      await h.warmUpExistingSession();
      final plan = await h.turn('عندي ضغط وقراءتي 150 على 95');

      expect(
        plan.message.contains(_subjectClarification),
        isTrue,
        reason: 'حاجب الخصوصية القائم يجب أن يبقى: ${plan.message}',
      );
    });
  });
}
