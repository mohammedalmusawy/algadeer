/// تبديل الموضوع إلى صاحب الحساب بعلامة ذات صريحة — Smart Brain V1.
///
/// الانحدار الحقيقي: بعد جلسة طفل نشطة، «اني عندي ألم بالظهر» كانت تُسبَق بـ
/// «حدّد عن مَن نتكلم قبل استخدام معلومات حسّاسة.» رغم أن المستخدم حدّد نفسه.
/// السبب أن ربط الشخص (PC-1.9) يقع في `_planImpl` بعد تحكيم الحزم السريرية،
/// فأي دور تحسمه حزمة يعود قبله ويترك `resolvedConversationSubject` على قيمة
/// دور سابق، ثم يقرأها جدار الخصوصية في طبقة التخصيص.
///
/// كل سيناريو يسبقه `warmUpExistingSession()` لأن العطل لا يظهر في محادثة
/// جديدة قصيرة: لا بد أن يستقر رابط الشخص أولاً.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/musculoskeletal/msk_models.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory_models.dart';
import 'package:ghadeer_clinic/companion/people/subject_binding/subject_binding_models.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نص جدار الخصوصية القائم — نتحقق من غيابه/حضوره، ولا نغيّره.
const _subjectClarification = 'حدّد عن مَن نتكلم';

final _saeedi = SmartSearchResult(
  type: SmartSearchResultType.doctor,
  title: 'الدكتور علي ناصر السعيدي',
  subtitle: 'طب الأطفال',
  doctorId: 'saeedi',
  specialty: 'طب الأطفال',
  phone: '07700000000',
  whatsapp: '07700000000',
  score: 96,
);

class _Harness {
  _Harness() {
    context = ConversationContext();
    planner = SmartBrainPlanner(
      doctorLookup: (q) async {
        lookups.add(q);
        final n = ArabicTextUtils.normalize(q);
        return n.contains('السعيدي') ? [_saeedi] : const [];
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

  /// دور تمهيدي يجعل الجلسة «قائمة» كما في التطبيق الحقيقي فيستقر رابط الشخص.
  Future<void> warmUpExistingSession() async {
    await turn('علي ناصر السعدي');
    expect(
      context.resolvedConversationSubject.status,
      ConversationPersonResolutionStatus.resolved,
      reason: 'الشرط المسبق للانحدار: رابط الشخص مستقر قبل شكوى الطفل',
    );
  }

  /// يصل بالمحادثة إلى جلسة تنفسية نشطة عن الطفل، ويؤكد ذلك.
  Future<void> enterChildRespiratory() async {
    await warmUpExistingSession();
    await turn('ابني عد سعال صار يومين');
    await turn('8 سنوات');
    expect(context.respiratorySession.active, isTrue);
    expect(context.respiratorySession.population, RespiratoryPopulation.child);
    expect(context.resolvedConversationSubject.isAccountOwner, isFalse,
        reason: 'قبل التبديل: الموضوع ليس صاحب الحساب');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  /// يؤكد تبديلاً حقيقياً للموضوع إلى صاحب الحساب عبر مسار آلام الظهر.
  void expectSelfBackPain(_Harness h, AssistantActionPlan plan) {
    final subject = h.context.resolvedConversationSubject;
    expect(subject.subjectKind, ConversationSubjectKind.accountOwner,
        reason: 'الموضوع يجب أن ينتقل إلى صاحب الحساب');
    expect(subject.isAccountOwner, isTrue);
    expect(subject.status, ConversationPersonResolutionStatus.resolved);

    expect(plan.message.contains(_subjectClarification), isFalse,
        reason: 'ممنوع طلب تحديد الشخص بعد علامة ذات صريحة: ${plan.message}');
    expect(plan.message.contains('سعال'), isFalse,
        reason: 'ممنوع ذكر سعال الطفل في شكوى المالك: ${plan.message}');
    expect(plan.message.contains('ما لقيت نتيجة مطابقة'), isFalse);
    expect(plan.message.trim(), isNotEmpty);
    expect(h.lookups, isEmpty,
        reason: 'ممنوع بحث حرفي عن جملة الشكوى: ${h.lookups}');

    expect(h.context.mskSession.active, isTrue,
        reason: 'الشكوى تمر عبر مسار العظام القائم');
    expect(h.context.mskSession.topic, MskTopic.lowBackPain);
    expect(h.context.respiratorySession.active, isFalse,
        reason: 'جلسة الطفل التنفسية تنتهي عند تبديل الشخص');
  }

  group('أ — طفل ثم علامة ذات صريحة عراقية', () {
    test('«اني عندي ألم بالظهر» ينتقل إلى المالك ومسار الظهر', () async {
      final h = _Harness();
      await h.enterChildRespiratory();
      h.lookups.clear();

      final plan = await h.turn('اني عندي ألم بالظهر');
      expectSelfBackPain(h, plan);
    });

    test('«اني عندي ألم الظهر» — صيغة المستخدم الحرفية', () async {
      final h = _Harness();
      await h.enterChildRespiratory();
      h.lookups.clear();

      final plan = await h.turn('اني عندي ألم الظهر');
      expectSelfBackPain(h, plan);
    });
  });

  group('ب — صيغة فصحى «أنا»', () {
    test('«أنا عندي ألم بالظهر» ينتقل إلى المالك', () async {
      final h = _Harness();
      await h.enterChildRespiratory();
      h.lookups.clear();

      final plan = await h.turn('أنا عندي ألم بالظهر');
      expectSelfBackPain(h, plan);
    });
  });

  group('ج — صيغة عراقية «وجع»', () {
    test('«اني عندي وجع بالظهر» ينتقل إلى المالك', () async {
      final h = _Harness();
      await h.enterChildRespiratory();
      h.lookups.clear();

      final plan = await h.turn('اني عندي وجع بالظهر');
      expectSelfBackPain(h, plan);
    });
  });

  group('د — استمرارية الطفل التنفسية محفوظة', () {
    test('سعال الطفل ثم العمر يبقى طفلاً تنفسياً بلا جدار خصوصية', () async {
      final h = _Harness();
      await h.warmUpExistingSession();

      await h.turn('ابني عنده سعال من يومين');
      h.lookups.clear();
      final age = await h.turn('عمره 8 سنوات');

      expect(h.context.respiratorySession.active, isTrue);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
      expect(h.context.respiratorySession.durationBucket,
          RespiratoryDurationBucket.days);
      expect(h.context.respiratorySession.symptomKeys,
          contains('childAgeKnown'));
      expect(h.context.resolvedConversationSubject.isAccountOwner, isFalse,
          reason: 'لا ينقلب الموضوع إلى المالك بلا علامة ذات');
      expect(age.message.contains('ما لقيت نتيجة مطابقة'), isFalse);
      expect(h.lookups, isEmpty);
    });
  });

  group('هـ — جدار الخصوصية يبقى فعّالاً عند الغموض الحقيقي', () {
    test('شكوى بضمير غائب بلا علامة مالك تبقى تطلب تحديد الشخص', () async {
      final h = _Harness();
      await h.enterChildRespiratory();

      final vague = await h.turn('عنده ألم بالظهر');
      expect(vague.message.contains(_subjectClarification), isTrue,
          reason: 'الحماية يجب أن تبقى فعّالة عند غموض الشخص: '
              '${vague.message}');
      expect(h.context.resolvedConversationSubject.isAccountOwner, isFalse);
    });
  });

  group('و — عزل حقائق الطفل عن شكوى المالك', () {
    test('العمر والمدة والسعال لا تتسرب إلى جلسة العظام', () async {
      final h = _Harness();
      await h.enterChildRespiratory();
      final childSession = h.context.respiratorySession;
      expect(childSession.symptomKeys, contains('childAgeKnown'),
          reason: 'الحقائق كانت موجودة فعلاً قبل التبديل');

      final plan = await h.turn('اني عندي ألم بالظهر');

      expect(h.context.respiratorySession.active, isFalse);
      expect(h.context.respiratorySession.symptomKeys, isEmpty,
          reason: 'حقائق الطفل تُمسح ولا تُحمل للمالك');
      expect(h.context.respiratorySession.population,
          isNot(RespiratoryPopulation.child));
      expect(plan.message.contains('سعال'), isFalse);
      expect(plan.message.contains('عمر'), isFalse);
      expect(plan.message.contains('يومين'), isFalse);
      expect(h.context.mskSession.topic, MskTopic.lowBackPain);
    });
  });
}
