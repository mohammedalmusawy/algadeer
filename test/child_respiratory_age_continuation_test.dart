/// استمرارية عمر الطفل داخل جلسة تنفسية نشطة — Smart Brain V1.
///
/// الانحدار الحقيقي: بعد أن يستقر رابط الشخص (`resolvedConversationSubject`)
/// على «شخص آخر»، كان مفتاح نطاق الموضوع يُعاد بناؤه من نية الدور، فجواب
/// المتابعة «عمره 8 سنوات» — وهو بلا كلمة عرض فنيّته `unknown` — يبدو تبديلَ
/// شخص، فتُمسح الجلسة التنفسية قبل `mayHandle` ويهرب الدور إلى البحث.
///
/// لذلك كل سيناريو هنا يسبقه دور تمهيدي واحد على الأقل: بدونه لا يستقر رابط
/// الشخص ولا يظهر العيب أصلاً (وهذا سبب مرور `smart_brain_continuity_regression_test`
/// على نفس الجملتين دون كشف العطل).
///
/// يمر عبر `SmartBrainPlanner.plan` العام مع `ConversationContext` — نفس سلطة
/// `SmartSearchPage`. لا APIs خاصة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory_models.dart';
import 'package:ghadeer_clinic/companion/people/subject_binding/subject_binding_models.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
final _naji = _doc(
  'naji',
  'الدكتور ناجي عبدالله الركابي',
  'جراحة العظام والمفاصل والكسور',
);
final _dentist = _doc('dent', 'الدكتورة سارة أحمد', 'طب الأسنان');

/// أدوات فحص مشتركة — أفعال البحث التي يجب ألا يقع فيها جواب المتابعة.
const _searchKinds = <AssistantActionKind>[
  AssistantActionKind.runDoctorSearch,
  AssistantActionKind.runSpecialtySearch,
  AssistantActionKind.runGeneralSearch,
];

class _Harness {
  _Harness() {
    context = ConversationContext();
    planner = SmartBrainPlanner(
      doctorLookup: (q) async {
        lookups.add(q);
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('اسنان')) return [_dentist];
        if (n.contains('كسور') || n.contains('عظام') || n.contains('ناجي')) {
          return [_naji];
        }
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
  /// الشخص. بدونه يبقى `status = unknown` ولا يُعاد بناء مفتاح النطاق إطلاقاً،
  /// فلا يظهر العطل. نستعمل بحث اسم غير مطابق — نفس ما فعله المستخدم يدوياً.
  Future<void> warmUpExistingSession() async {
    await turn('علي ناصر السعدي');
    expect(
      context.resolvedConversationSubject.status,
      ConversationPersonResolutionStatus.resolved,
      reason: 'الشرط المسبق للانحدار: رابط الشخص مستقر قبل الشكوى',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  /// يؤكد أن الدور بقي داخل المحادثة التنفسية ولم يهرب إلى البحث.
  void expectStayedRespiratory(_Harness h, AssistantActionPlan plan) {
    expect(h.context.respiratorySession.active, isTrue,
        reason: 'الجلسة التنفسية يجب أن تبقى نشطة');
    expect(h.context.respiratorySession.hasCoughContext, isTrue,
        reason: 'السعال يجب أن يُحفظ');
    expect(plan.kind, isNot(isIn(_searchKinds)));
    expect(plan.message.contains('ما لقيت نتيجة مطابقة'), isFalse);
    expect(plan.message.trim(), isNotEmpty);
  }

  group('أ — جواب العمر يكمل الجلسة التنفسية للطفل', () {
    test('«ابني عنده سعال من يومين» ثم «عمره 8 سنوات» يبقى تنفسياً', () async {
      final h = _Harness();
      await h.warmUpExistingSession();

      final cough = await h.turn('ابني عنده سعال من يومين');
      expect(h.context.respiratorySession.active, isTrue);
      expect(h.context.respiratorySession.lastQuestionKey, 'childAge',
          reason: 'غدير يسأل عن العمر بعد الدور الأول: ${cough.message}');

      h.lookups.clear();
      final age = await h.turn('عمره 8 سنوات');

      expectStayedRespiratory(h, age);
      final session = h.context.respiratorySession;
      expect(session.population, RespiratoryPopulation.child,
          reason: 'مالك الشكوى يبقى الطفل');
      expect(session.durationBucket, RespiratoryDurationBucket.days,
          reason: 'مدة اليومين تبقى محفوظة');
      expect(session.symptomKeys, contains('childAgeKnown'),
          reason: 'العمر اندمج في الجلسة القائمة');
      expect(h.lookups, isEmpty,
          reason: 'ممنوع أي استعلام أطباء على نص العمر: ${h.lookups}');
    });
  });

  group('ب — دمج تراكمي على ثلاث خطوات', () {
    test('سعال ثم «صار له يومين» ثم «عمره 8 سنوات» تندمج كلها', () async {
      final h = _Harness();
      await h.warmUpExistingSession();

      await h.turn('ابني عنده سعال');
      await h.turn('صار له يومين');
      h.lookups.clear();
      final age = await h.turn('عمره 8 سنوات');

      expectStayedRespiratory(h, age);
      final session = h.context.respiratorySession;
      expect(session.population, RespiratoryPopulation.child);
      expect(session.durationBucket, RespiratoryDurationBucket.days);
      expect(session.symptomKeys, contains('childAgeKnown'));
      expect(h.lookups, isEmpty);
    });
  });

  group('ج — «سنوات» لا تُقرأ أسناناً', () {
    test('جواب العمر لا يفعّل حزمة الأسنان ولا نص شكوى الفم', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      await h.turn('ابني عنده سعال من يومين');
      final age = await h.turn('عمره 8 سنوات');

      expect(h.context.dentalSession.active, isFalse);
      expect(
        h.context.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        isNot(BrainAuthorityId.dental),
      );
      expect(age.message.contains('فهمت شكوى الأسنان'), isFalse);
      expect(age.message.contains('ورم بالوجه'), isFalse);
    });

    test('«سنة» و«سنين» مثل «سنوات» لا تفتح مسار الأسنان', () async {
      for (final unit in ['عمره 8 سنة', 'عمره 8 سنين']) {
        final h = _Harness();
        await h.warmUpExistingSession();
        await h.turn('ابني عنده سعال من يومين');
        final age = await h.turn(unit);

        expect(h.context.dentalSession.active, isFalse, reason: unit);
        expect(age.message.contains('فهمت شكوى الأسنان'), isFalse,
            reason: unit);
      }
    });
  });

  group('د — تبديل صريح للموضوع/المالك', () {
    test('«اني ألم ظهر» بعد سعال الطفل يترك المسار التنفسي', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      await h.turn('ابني عنده سعال من يومين');
      await h.turn('عمره 8 سنوات');

      final switched = await h.turn('اني ألم ظهر');
      expect(h.context.respiratorySession.active, isFalse,
          reason: 'شكوى جديدة صريحة للمالك تُنهي الجلسة التنفسية');
      expect(switched.message.contains('السعال'), isFalse,
          reason: 'ممنوع إكمال سؤال السعال بعد تبديل الموضوع');
    });
  });

  group('هـ — بحث اختصاص الأسنان الصريح', () {
    test('«أريد طبيب أسنان» بعد سعال الطفل ينتقل للأسنان', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      await h.turn('ابني عنده سعال من يومين');

      final dental = await h.turn('أريد طبيب أسنان');
      expect(h.context.respiratorySession.active, isFalse);
      expect(
        dental.intentResult.intent == AssistantIntent.specialtySearch ||
            dental.kind == AssistantActionKind.runSpecialtySearch ||
            dental.message.contains('أسنان') ||
            h.context.unifiedBrainDiagnostics.selectedPrimaryAuthority ==
                BrainAuthorityId.dental,
        isTrue,
        reason: 'النية الصريحة للأسنان تفوز: ${dental.kind} ${dental.message}',
      );
    });
  });

  group('و — عمر مفرد بلا شكوى لا يخترع سياقاً', () {
    test('«عمره 8 سنوات» في محادثة جديدة لا يفتح جلسة تنفسية', () async {
      final h = _Harness();
      final r = await h.turn('عمره 8 سنوات');

      expect(h.context.respiratorySession.active, isFalse,
          reason: 'ممنوع اختراع سعال غير مذكور');
      expect(h.context.respiratorySession.hasCoughContext, isFalse);
      expect(r.message.contains('السعال'), isFalse);
      expect(
        h.context.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        isNot(BrainAuthorityId.dental),
      );
    });

    test('عمر مفرد بعد جلسة قائمة بلا شكوى لا يخترع سعالاً', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      final r = await h.turn('عمره 8 سنوات');

      expect(h.context.respiratorySession.active, isFalse);
      expect(r.message.contains('السعال'), isFalse);
    });
  });

  group('ز — الاستمرارية مستقلة عن الطبيب المحدد', () {
    test('طبيب محدد ثم سعال الطفل ثم العمر — يكمل تنفسياً', () async {
      final h = _Harness();
      await h.warmUpExistingSession();
      h.context.rememberResults(
        [_naji],
        query: 'الدكتور ناجي',
        intent: AssistantIntent.doctorSearch,
      );
      h.context.selectDoctor(_naji);

      await h.turn('ابني عنده سعال من يومين');
      h.lookups.clear();
      final age = await h.turn('عمره 8 سنوات');

      expectStayedRespiratory(h, age);
      expect(h.context.respiratorySession.symptomKeys,
          contains('childAgeKnown'));
      expect(h.lookups, isEmpty,
          reason: 'الطبيب السابق لا يتحول إلى جواب طبي');
      expect(h.context.selectedDoctor?.doctorId, 'naji',
          reason: 'دلالات اختيار الطبيب القائمة تبقى كما هي');
    });
  });

  group('ح — «نعم» الحرّة تبقى إقراراً بلا بحث', () {
    test('«نعم» بلا حالة معلّقة لا تُبحث كنص', () async {
      final h = _Harness();
      h.lookups.clear();
      final r = await h.turn('نعم');

      expect(r.kind, isNot(isIn(_searchKinds)));
      expect(r.message.contains('ما لقيت نتيجة مطابقة'), isFalse);
      expect(r.message.trim(), isNotEmpty);
      expect(h.lookups, isEmpty);
    });
  });

  group('ط — تأكيد اقتراح تصحيح الاسم', () {
    test('اقتراح معلّق ثم «نعم» يحل الطبيب الحقيقي', () async {
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
      expect(yes.message.contains('ما لقيت نتيجة مطابقة'), isFalse);
    });
  });

  group('ي — الاتصال وواتساب على طبيب محدد', () {
    test('«اتصل» و«ارسل واتساب» يبقيان كما هما', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_saeedi],
        query: 'علي ناصر السعيدي',
        intent: AssistantIntent.doctorSearch,
      );
      h.context.selectDoctor(_saeedi);

      final call = await h.turn('اتصل');
      expect(
        call.kind == AssistantActionKind.prepareCall ||
            h.context.lastIntent == AssistantIntent.callDoctor ||
            h.context.hasPendingAction,
        isTrue,
        reason: 'سلوك الاتصال القائم: ${call.kind} ${call.message}',
      );

      h.context.selectDoctor(_saeedi);
      final wa = await h.turn('ارسل واتساب');
      expect(
        wa.kind == AssistantActionKind.prepareWhatsApp ||
            h.context.lastIntent == AssistantIntent.messageDoctor ||
            h.context.hasPendingAction,
        isTrue,
        reason: 'سلوك واتساب القائم: ${wa.kind} ${wa.message}',
      );
    });
  });
}
