/// Phase 2B — استمرارية سريرية متعددة الأدوار على ConversationContext فقط.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('محوّل العمر السياقي', () {
    const ages = AgeAuthorityResolver();

    test('8 سنوات تُفهم و8 العارية لا', () {
      expect(ages.parseSessionSubjectAgeYears('8 سنوات'), 8);
      expect(ages.parseSessionSubjectAgeYears('عمره 8'), 8);
      expect(ages.parseSessionSubjectAgeYears('8'), isNull);
      expect(ages.parseSessionSubjectAgeYears('2'), isNull);
      expect(ages.parseSessionSubjectAgeYears('عمري 8'), isNull);
    });
  });

  group('A — السلسلة الثلاثية', () {
    test('سعال الطفل ثم 8 سنوات ثم حرارة وضيق نفس تُحفظ كلها', () async {
      final fake = FakeNluClient(
        response: const NluParse(
          intent: NluIntent.clinicalContinuation,
          continuation: true,
          subject: NluSubject.inherit,
          fever: RespiratoryTriState.present,
          breathlessness: RespiratoryTriState.present,
          overallConfidence: 0.92,
          slotConfidence: {'fever': 0.91, 'breathlessness': 0.9},
        ),
      );
      final h = _Harness(nluClient: fake);
      await h.turn('ابني عنده سعال من يومين');
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
      expect(
        h.context.respiratorySession.durationBucket,
        RespiratoryDurationBucket.days,
      );

      await h.turn('8 سنوات');
      expect(h.context.healthSubject.ageYears, 8);
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
      expect(
        h.context.respiratorySession.durationBucket,
        RespiratoryDurationBucket.days,
      );
      expect(h.context.respiratorySession.symptomKeys, contains('childAgeKnown'));

      final third = await h.turn('عنده حرارة ويا السعال وما ياخذ هوا');
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.healthSubject.ageYears, 8);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
      expect(
        h.context.respiratorySession.durationBucket,
        RespiratoryDurationBucket.days,
      );
      expect(h.context.respiratorySession.fever, RespiratoryTriState.present);
      expect(
        h.context.respiratorySession.breathlessness,
        RespiratoryTriState.present,
        reason: third.message,
      );
      expect(h.context.healthSubject.reservedSexHint, isNull);
      expect(fake.callCount, greaterThan(0));
      expect(
        h.planner.lastNluTraceForTest?.acceptedSlots ?? const [],
        isNotEmpty,
      );
    });
  });

  group('B — جواب عمر معلّق', () {
    test('سؤال عمر ثم 8 سنوات → ageYears=8', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      expect(h.context.respiratorySession.lastQuestionKey, 'childAge');
      await h.turn('8 سنوات');
      expect(h.context.healthSubject.ageYears, 8);
      expect(h.context.healthSubject.type, HealthSubjectType.child);
    });
  });

  group('C — رقم بلا سياق عمر', () {
    test('8 العارية لا تصبح عمراً', () async {
      final h = _Harness();
      await h.turn('8');
      expect(h.context.healthSubject.ageYears, isNull);
    });
  });

  group('D — رقم مع نتائج بحث', () {
    test('2 مع طبيبين لا يُستهلك كعمر سريري', () async {
      final h = _Harness();
      h.context.rememberResults([
        _doc('d1', 'علي ناصر'),
        _doc('d2', 'سارة'),
      ]);
      await h.turn('2');
      expect(h.context.healthSubject.ageYears, isNull);
      expect(h.context.healthSubject.type, isNot(HealthSubjectType.child));
    });
  });

  group('E — unknown لا يمسح known', () {
    test('حمى حاضرة تبقى بعد دور بلا حمى', () async {
      final coordinator = RespiratoryGuidanceCoordinator();
      var session = const RespiratorySession(
        active: true,
        topic: RespiratoryTopic.acuteCough,
        population: RespiratoryPopulation.child,
        durationBucket: RespiratoryDurationBucket.days,
        fever: RespiratoryTriState.present,
        symptomKeys: ['cough'],
      );
      final turn = await coordinator.handle(
        text: 'والسعال مستمر',
        session: session,
      );
      expect(turn.session.fever, RespiratoryTriState.present);
      expect(turn.session.durationBucket, RespiratoryDurationBucket.days);
      expect(turn.session.hasCoughContext, isTrue);
    });
  });

  group('F — تبديل الموضوع', () {
    test('شكوى المالك لا ترث عمر الطفل وأعراضه', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      await h.turn('8 سنوات');
      expect(h.context.healthSubject.ageYears, 8);
      await h.turn('اني عندي ألم بالظهر');
      expect(h.context.healthSubject.type, isNot(HealthSubjectType.child));
      expect(h.context.healthSubject.ageYears, isNull);
      expect(h.context.respiratorySession.active, isFalse);
      expect(h.context.respiratorySession.fever, isNot(RespiratoryTriState.present));
    });
  });

  group('G — موضوع سريري جديد', () {
    test('شكوى ظهر صريحة لا تطبّق سعال الطفل', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      await h.turn('8 سنوات');
      final plan = await h.turn('اني عندي ألم بالظهر');
      expect(h.context.respiratorySession.active, isFalse);
      expect(
        h.context.mskSession.active ||
            plan.message.contains('ظهر') ||
            plan.message.contains('عظام'),
        isTrue,
        reason: plan.message,
      );
      expect(h.context.healthSubject.ageYears, isNull);
    });
  });

  group('H — توافق العمر الحتمي القائم', () {
    test('عمره 8 سنوات تبقى استمرارية تنفسية', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      await h.turn('عمره 8 سنوات');
      expect(h.context.respiratorySession.active, isTrue);
      expect(h.context.respiratorySession.population, RespiratoryPopulation.child);
      expect(h.context.healthSubject.ageYears, 8);
    });
  });

  group('I — توافق overlay مرحلة 1', () {
    test('overlay يملأ ضيق النفس دون مسح المدة', () async {
      final fake = FakeNluClient(
        response: const NluParse(
          intent: NluIntent.clinicalContinuation,
          continuation: true,
          subject: NluSubject.inherit,
          fever: RespiratoryTriState.present,
          breathlessness: RespiratoryTriState.present,
          overallConfidence: 0.92,
          slotConfidence: {'fever': 0.91, 'breathlessness': 0.9},
        ),
      );
      final h = _Harness(nluClient: fake);
      await h.turn('ابني عنده سعال من يومين');
      await h.turn('8 سنوات');
      await h.turn('عنده حرارة ويا السعال وما ياخذ هوا');
      expect(h.planner.lastNluTraceForTest?.called, isTrue);
      expect(
        h.context.respiratorySession.durationBucket,
        RespiratoryDurationBucket.days,
      );
      expect(
        h.context.respiratorySession.breathlessness,
        RespiratoryTriState.present,
      );
    });
  });
}

SmartSearchResult _doc(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: 'طب الأطفال',
      doctorId: id,
      specialty: 'طب الأطفال',
      phone: '0700$id',
      score: 90,
    );

class _Harness {
  _Harness({NluClient? nluClient}) {
    context = ConversationContext();
    planner = SmartBrainPlanner(
      nluClient: nluClient ?? NluClient.disabled,
      doctorLookup: (q) async {
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('اطفال') || n.contains('علي')) {
          return [_doc('d1', 'علي ناصر'), _doc('d2', 'سارة')];
        }
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

  Future<AssistantActionPlan> turn(String query) =>
      planner.plan(query: query, context: context);
}
