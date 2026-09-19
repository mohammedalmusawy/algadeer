/// Phase 2C — استمرارية مراجع البحث وحل الكيان عبر currentResultContext فقط.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/context_resolver.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('مفردات الترتيب', () {
    test('العربية ورقم 1/2/3 تُستخرج — و2 العارية لا', () {
      expect(ContextResolver.extractOrdinal('الأول'), 1);
      expect(ContextResolver.extractOrdinal('الاول'), 1);
      expect(ContextResolver.extractOrdinal('أول واحد'), 1);
      expect(ContextResolver.extractOrdinal('اول واحد'), 1);
      expect(ContextResolver.extractOrdinal('الثاني'), 2);
      expect(ContextResolver.extractOrdinal('ثاني واحد'), 2);
      expect(ContextResolver.extractOrdinal('الثالث'), 3);
      expect(ContextResolver.extractOrdinal('ثالث واحد'), 3);
      expect(ContextResolver.extractOrdinal('رقم 1'), 1);
      expect(ContextResolver.extractOrdinal('رقم 2'), 2);
      expect(ContextResolver.extractOrdinal('رقم 3'), 3);
      expect(ContextResolver.extractOrdinal('2'), isNull);
      final resolver = RuleBasedIntentResolver();
      expect(resolver.resolve('2').intent, isNot(AssistantIntent.selectResult));
      expect(resolver.resolve('رقم 2').intent, AssistantIntent.selectResult);
    });
  });

  group('A — ترتيب طبيب', () {
    test('نتائج A/B/C ثم الثاني يختار B', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'Doctor A'), _doc('b', 'Doctor B'), _doc('c', 'Doctor C')],
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await h.turn('الثاني');
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.doctorId, 'b');
      expect(h.context.selectedDoctor?.doctorId, 'b');
      expect(h.context.activeEntityType, ConversationEntityType.doctor);
    });
  });

  group('B — بلا نتائج سابقة', () {
    test('الثاني بلا currentResultContext لا يختار شيئاً', () async {
      final h = _Harness();
      expect(h.context.currentResultContext, isNull);
      final plan = await h.turn('الثاني');
      expect(plan.target, isNull);
      expect(h.context.selectedDoctor, isNull);
      expect(h.context.selectedLaboratory, isNull);
      expect(h.context.selectedPackage, isNull);
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.showMessage,
          AssistantActionKind.showClarification,
        ),
      );
      expect(plan.message, contains('نتائج سابقة'));
    });
  });

  group('C — حماية نتائج طبيب قديمة', () {
    test('بعد بحث مختبر الثاني يختار المختبر لا الطبيب', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'أطفال أ'), _doc('b', 'أطفال ب'), _doc('c', 'أطفال ج')],
        intent: AssistantIntent.specialtySearch,
      );
      h.context.rememberResults(
        [_lab('l1', 'مختبر الحياة'), _lab('l2', 'مختبر النور'), _lab('l3', 'مختبر اليرموك')],
        intent: AssistantIntent.findLab,
      );
      expect(
        h.context.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
      final plan = await h.turn('الثاني');
      expect(plan.target?.labId, 'l2');
      expect(plan.target?.type, SmartSearchResultType.lab);
      expect(h.context.selectedLaboratory?.labId, 'l2');
      expect(h.context.selectedDoctor?.doctorId, isNot('b'));
      expect(h.context.activeEntityType, ConversationEntityType.laboratory);
    });
  });

  group('D — ترتيب باقة', () {
    test('نتائج باقات ثم الثاني يختار الثانية', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_pkg('p1', 'باقة أ'), _pkg('p2', 'باقة ب'), _pkg('p3', 'باقة ج')],
        intent: AssistantIntent.findPackage,
      );
      final plan = await h.turn('الثاني');
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.packageId, 'p2');
      expect(h.context.selectedPackage?.packageId, 'p2');
      expect(h.context.activeEntityType, ConversationEntityType.package);
    });
  });

  group('E — ترتيب خارج النطاق', () {
    test('نتيجتان ثم الثالث لا يختار اعتباطاً', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'Doctor A'), _doc('b', 'Doctor B')],
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await h.turn('الثالث');
      expect(plan.target, isNull);
      expect(h.context.selectedDoctor, isNull);
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.showMessage,
          AssistantActionKind.showClarification,
        ),
      );
    });
  });

  group('F — اسم جزئي فريد', () {
    test('اتصل بعلي ناصر يحل الطبيب الحالي الفريد', () async {
      final h = _Harness();
      h.context.rememberResults(
        [
          _doc('sara', 'د. سارة محمد'),
          _doc('ali_saeedi', 'د. علي ناصر السعيدي'),
          _doc('kareem', 'د. كريم جاسم'),
        ],
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await h.turn('اتصل بعلي ناصر');
      expect(h.lookupQueries, isEmpty, reason: 'لا بحث عالمي عند تطابق سياقي فريد');
      expect(plan.target?.doctorId, 'ali_saeedi');
      expect(h.context.selectedDoctor?.doctorId, 'ali_saeedi');
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.prepareCall,
          AssistantActionKind.selectEntity,
        ),
      );
    });
  });

  group('G — اسم جزئي غامض', () {
    test('طبيبان متشابهان يطلبان توضيحاً بلا اختيار أول اعتباطي', () async {
      final h = _Harness();
      h.context.rememberResults(
        [
          _doc('ali_saeedi', 'د. علي ناصر السعيدي'),
          _doc('ali_kadhim', 'د. علي ناصر الكاظمي'),
          _doc('sara', 'د. سارة محمد'),
        ],
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await h.turn('اتصل بعلي ناصر');
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(h.context.selectedDoctor, isNull);
      expect(plan.target?.doctorId, isNull);
      expect(plan.candidates.length, greaterThanOrEqualTo(2));
      expect(
        plan.candidates.map((c) => c.doctorId),
        containsAll(['ali_saeedi', 'ali_kadhim']),
      );
    });
  });

  group('H — الاسم الكامل', () {
    test('الاسم الكامل يُحل حتمياً من النتائج الحالية', () async {
      final h = _Harness();
      h.context.rememberResults(
        [
          _doc('ali_saeedi', 'د. علي ناصر السعيدي'),
          _doc('ali_kadhim', 'د. علي ناصر الكاظمي'),
        ],
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await h.turn('اتصل بالدكتور علي ناصر السعيدي');
      expect(plan.target?.doctorId, 'ali_saeedi');
      expect(h.context.selectedDoctor?.doctorId, 'ali_saeedi');
      expect(plan.kind, isNot(AssistantActionKind.showClarification));
    });
  });

  group('I — بحث جديد يُبطل الترتيب القديم', () {
    test('بعد بدء بحث مختبر الثاني لا يستخدم أطباء قدماء', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'A'), _doc('b', 'B'), _doc('c', 'C')],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('أريد مختبر');
      expect(h.context.currentResultContext, isNull);
      final plan = await h.turn('الثاني');
      expect(plan.target?.doctorId, isNull);
      expect(h.context.selectedDoctor, isNull);
    });
  });

  group('J — حماية الرقم السريري', () {
    test('8 سنوات أثناء سؤال عمر الطفل تبقى عمراً', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      expect(h.context.respiratorySession.lastQuestionKey, 'childAge');
      final before = h.context.currentResultContext;
      await h.turn('8 سنوات');
      expect(h.context.healthSubject.ageYears, 8);
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.selectedDoctor, isNull);
      expect(h.context.currentResultContext, before);
    });
  });

  group('K — الرقم العاري', () {
    test('2 بلا سياق نتائج صالح لا تختار كياناً', () async {
      final h = _Harness();
      expect(h.context.currentResultContext, isNull);
      final plan = await h.turn('2');
      expect(plan.target, isNull);
      expect(h.context.selectedDoctor, isNull);
      expect(h.context.selectedLaboratory, isNull);
      expect(h.context.selectedPackage, isNull);
      expect(h.context.healthSubject.ageYears, isNull);
    });
  });

  group('L — عزل نوع الكيان', () {
    test('selectedDoctor لا يُستخدم كمختبر أو باقة', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'A'), _doc('b', 'B'), _doc('c', 'C')],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('الثاني');
      expect(h.context.selectedDoctor?.type, SmartSearchResultType.doctor);
      expect(h.context.selectedDoctor?.labId, isNull);
      expect(h.context.selectedPackage, isNull);
      expect(h.context.activeEntityType, ConversationEntityType.doctor);

      h.context.rememberResults(
        [_lab('l1', 'مختبر أ'), _lab('l2', 'مختبر ب')],
        intent: AssistantIntent.findLab,
      );
      await h.turn('الثاني');
      expect(h.context.selectedLaboratory?.type, SmartSearchResultType.lab);
      expect(h.context.selectedLaboratory?.doctorId, isNull);
      expect(h.context.selectedLaboratory?.packageId, isNull);
      expect(h.context.activeEntityType, ConversationEntityType.laboratory);
      expect(
        h.context.selectedLaboratory?.labId,
        isNot(h.context.selectedDoctor?.doctorId),
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

SmartSearchResult _lab(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: 'مختبر',
      labId: id,
      labName: title,
      phone: '0770$id',
      score: 90,
    );

SmartSearchResult _pkg(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.package,
      title: title,
      subtitle: 'مختبر الحياة',
      packageId: id,
      labId: 'hayat',
      labName: 'مختبر الحياة',
      score: 90,
    );

class _Harness {
  _Harness() {
    context = ConversationContext();
    lookupQueries = <String>[];
    planner = SmartBrainPlanner(
      nluClient: NluClient.disabled,
      doctorLookup: (q) async {
        lookupQueries.add(q);
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('علي') && n.contains('ناصر')) {
          return [
            _doc('ali_saeedi', 'د. علي ناصر السعيدي'),
            _doc('ali_kadhim', 'د. علي ناصر الكاظمي'),
          ];
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
  late final List<String> lookupQueries;

  Future<AssistantActionPlan> turn(String query) =>
      planner.plan(query: query, context: context);
}
