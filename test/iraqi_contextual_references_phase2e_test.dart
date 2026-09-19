/// Phase 2E — مراجع عراقية سياقية عبر ConversationReferenceResolver فقط.
///
/// المفردات قبل 2E (لا جدول مكرّر في الإنتاج): بيه/به/وياه/عليه/هذا/هاي/
/// بيها/بيهم/عليهم/هو/هي/نفسه/نفسها + هذا|هاي|هذ|نفس مع تحليل/باقة/مختبر/طبيب.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('A — ضمير الطبيب بعد الترتيب', () {
    test('الثاني ثم اتصل بيه يستهدف الطبيب B', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'طبيب أ'), _doc('b', 'طبيب ب'), _doc('c', 'طبيب ج')],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('الثاني');
      expect(h.context.selectedDoctor?.doctorId, 'b');
      final plan = await h.turn('اتصل بيه');
      expect(h.lookupQueries, isEmpty);
      expect(plan.target?.doctorId, 'b');
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.prepareCall,
          AssistantActionKind.selectEntity,
        ),
      );
      expect(plan.kind, isNot(AssistantActionKind.runSpecialtySearch));
      expect(plan.kind, isNot(AssistantActionKind.runGeneralSearch));
    });
  });

  group('B — استمرار Phase 2D', () {
    test('اتصل بيه ثم نعم تؤكد الطبيب B', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'طبيب أ'), _doc('b', 'طبيب ب'), _doc('c', 'طبيب ج')],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('الثاني');
      await h.turn('اتصل بيه');
      expect(h.context.pendingAction, 'call');
      expect(h.context.selectedDoctor?.doctorId, 'b');
      final plan = await h.turn('نعم');
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'b');
    });
  });

  group('C — مرجع مؤنث لطبيبة محددة', () {
    test('اتصل بيها يستهدف الطبيبة المحددة', () async {
      final h = _Harness();
      final sara = _doc('sara', 'د. سارة أحمد');
      h.context.rememberResults([sara], intent: AssistantIntent.doctorSearch);
      expect(h.context.selectedDoctor?.doctorId, 'sara');
      final plan = await h.turn('اتصل بيها');
      expect(plan.target?.doctorId, 'sara');
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.prepareCall,
          AssistantActionKind.selectEntity,
        ),
      );
      expect(h.lookupQueries, isEmpty);
    });
  });

  group('D — مرجع مختبر', () {
    test('افتح هذا المختبر يحل المختبر المحدد', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_lab('hayat', 'مختبر الحياة')],
        intent: AssistantIntent.findLab,
      );
      expect(h.context.selectedLaboratory?.labId, 'hayat');
      final plan = await h.turn('افتح هذا المختبر');
      expect(plan.target?.labId, 'hayat');
      expect(h.context.selectedLaboratory?.labId, 'hayat');
      expect(plan.target?.type, SmartSearchResultType.lab);
      expect(plan.kind, isNot(AssistantActionKind.runGeneralSearch));
    });
  });

  group('E — مرجع باقة', () {
    test('افتح هاي الباقة يحل الباقة المحددة', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_pkg('p1', 'باقة الحياة الشاملة')],
        intent: AssistantIntent.findPackage,
      );
      expect(h.context.selectedPackage?.packageId, 'p1');
      final plan = await h.turn('افتح هاي الباقة');
      expect(plan.target?.packageId, 'p1');
      expect(h.context.selectedPackage?.packageId, 'p1');
      expect(plan.target?.type, SmartSearchResultType.package);
      expect(plan.target?.doctorId, isNull);
    });
  });

  group('F — بلا antecedent', () {
    test('اتصل بيه في سياق فارغ يوضح ولا يختار طبيباً', () async {
      final h = _Harness();
      final plan = await h.turn('اتصل بيه');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.canExecute, isFalse);
      expect(plan.target, isNull);
      expect(h.lookupQueries, isEmpty);
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.showMessage,
          AssistantActionKind.showClarification,
        ),
      );
    });
  });

  group('G — نوع كيان خاطئ', () {
    test('باقة محددة ثم اتصل بيه لا تتصل', () async {
      final h = _Harness();
      h.context.selectPackage(
        _pkg('p1', 'باقة الحياة الشاملة', labId: 'hayat'),
      );
      expect(h.context.activeEntityType, ConversationEntityType.package);
      expect(h.context.selectedLaboratory?.labId, 'hayat');
      final plan = await h.turn('اتصل بيه');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.kind, isNot(AssistantActionKind.prepareWhatsApp));
      expect(plan.canExecute, isFalse);
      expect(h.lookupQueries, isEmpty);
    });
  });

  group('H — الاسم الصريح يغلب الضمير', () {
    test('طبيب A محدد ثم اتصل بالدكتور علي ناصر يفوز علي', () async {
      final h = _Harness();
      h.context.rememberResults(
        [
          _doc('a', 'د. أحمد كاظم'),
          _doc('ali_nasser', 'د. علي ناصر السعيدي'),
          _doc('c', 'د. كريم جاسم'),
        ],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('الأول');
      expect(h.context.selectedDoctor?.doctorId, 'a');
      final plan = await h.turn('اتصل بالدكتور علي ناصر');
      expect(plan.target?.doctorId, 'ali_nasser');
      expect(h.context.selectedDoctor?.doctorId, 'ali_nasser');
      expect(plan.target?.doctorId, isNot('a'));
    });
  });

  group('I — حماية الطبيب القديم', () {
    test('بعد مختبر محدد افتح هذا يحل المختبر لا الطبيب', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'طبيب أ'), _doc('b', 'طبيب ب')],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('الأول');
      expect(h.context.selectedDoctor?.doctorId, 'a');
      h.context.rememberResults(
        [_lab('l1', 'مختبر النور'), _lab('l2', 'مختبر الحياة')],
        intent: AssistantIntent.findLab,
      );
      await h.turn('الثاني');
      expect(h.context.selectedLaboratory?.labId, 'l2');
      expect(h.context.activeEntityType, ConversationEntityType.laboratory);
      final plan = await h.turn('افتح هذا');
      expect(plan.target?.labId, 'l2');
      expect(plan.target?.doctorId, isNot('a'));
      expect(plan.target?.type, SmartSearchResultType.lab);
    });
  });

  group('J — حماية نوعية من إحياء طبيب قديم', () {
    test('هذا الدكتور مع مختبر حالي لا يُحيي الطبيب القديم', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'طبيب أ'), _doc('b', 'طبيب ب')],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('الأول');
      h.context.rememberResults(
        [_lab('l2', 'مختبر الحياة')],
        intent: AssistantIntent.findLab,
      );
      expect(h.context.selectedDoctor?.doctorId, 'a');
      expect(h.context.activeEntityType, ConversationEntityType.laboratory);
      final plan = await h.turn('هذا الدكتور');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.target?.doctorId, isNot('a'));
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.showMessage,
          AssistantActionKind.showClarification,
        ),
      );
    });
  });

  group('K — عزل سريري', () {
    test('هو عنده حرارة تبقى موضوعاً سريرياً لا طبيباً محدداً', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'طبيب أ')],
        intent: AssistantIntent.doctorSearch,
      );
      expect(h.context.selectedDoctor?.doctorId, 'a');
      await h.turn('ابني عنده سعال من يومين');
      if (h.context.respiratorySession.lastQuestionKey != 'childAssociated') {
        await h.turn('8 سنوات');
      }
      final plan = await h.turn('هو عنده حرارة');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.target?.doctorId, isNot('a'));
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(
        h.context.respiratorySession.fever,
        anyOf(RespiratoryTriState.present, RespiratoryTriState.unknown),
      );
      expect(h.lookupQueries, isEmpty);
    });
  });

  group('L — عزل اسم الإشارة السريري', () {
    test('هاي الأعراض من يومين لا تختار باقة/مختبر/طبيب', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_pkg('p1', 'باقة أ'), _pkg('p2', 'باقة ب')],
        intent: AssistantIntent.findPackage,
      );
      await h.turn('الأول');
      await h.turn('ابني عنده سعال من يومين');
      if (h.context.respiratorySession.lastQuestionKey != 'childAssociated') {
        await h.turn('8 سنوات');
      }
      final beforePackage = h.context.selectedPackage?.packageId;
      final plan = await h.turn('هاي الأعراض من يومين');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.target?.packageId, isNull);
      expect(plan.target?.labId, isNull);
      expect(plan.target?.type, isNot(SmartSearchResultType.doctor));
      expect(h.context.selectedPackage?.packageId, beforePackage);
      expect(h.context.healthSubject.type, HealthSubjectType.child);
    });
  });

  group('M — لا سقوط إلى lastResults', () {
    test('lastResults قديمة بلا antecedent سلطوية → توضيح', () async {
      final h = _Harness();
      h.context.lastResults = [
        _doc('a', 'طبيب أ'),
        _doc('b', 'طبيب ب'),
      ];
      expect(h.context.currentResultContext, isNull);
      expect(h.context.selectedDoctor, isNull);
      final plan = await h.turn('اتصل بيه');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.canExecute, isFalse);
      expect(plan.target, isNull);
      expect(h.lookupQueries, isEmpty);
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.showMessage,
          AssistantActionKind.showClarification,
        ),
      );
    });
  });

  group('N — حفظ Phase 2C', () {
    test('الثاني يستخدم currentResultContext فقط', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'Doctor A'), _doc('b', 'Doctor B'), _doc('c', 'Doctor C')],
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await h.turn('الثاني');
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.doctorId, 'b');
      expect(h.context.selectedDoctor?.doctorId, 'b');
      expect(
        h.context.currentResultContext?.entityType,
        ConversationEntityType.doctor,
      );
    });
  });

  group('O — حفظ Phase 2B', () {
    test('8 سنوات تحدّث عمر الموضوع الصحي لا كياناً', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      final plan = await h.turn('8 سنوات');
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.healthSubject.ageYears, 8);
      expect(plan.target?.doctorId, isNull);
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
    });
  });

  group('P — حفظ Phase 2D', () {
    test('نعم العارية بعد اتصال معلّق تؤكد الهدف القائم', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('ali', 'د. علي ناصر السعيدي')],
        intent: AssistantIntent.doctorSearch,
      );
      await h.turn('اتصل');
      expect(h.context.pendingAction, 'call');
      final plan = await h.turn('نعم');
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'ali');
    });

    test('نعم بلا توقع لا تختار نتيجة ولا تتصل', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'أ'), _doc('b', 'ب')],
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await h.turn('نعم');
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(h.context.selectedDoctor, isNull);
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
      whatsapp: '0700$id',
      score: 90,
    );

SmartSearchResult _lab(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: 'مختبر',
      labId: id,
      labName: title,
      phone: '0770$id',
      whatsapp: '0770$id',
      score: 90,
    );

SmartSearchResult _pkg(String id, String title, {String labId = 'hayat'}) =>
    SmartSearchResult(
      type: SmartSearchResultType.package,
      title: title,
      subtitle: 'مختبر الحياة',
      packageId: id,
      labId: labId,
      labName: 'مختبر الحياة',
      phone: '0770$labId',
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
          return [_doc('ali_nasser', 'د. علي ناصر السعيدي')];
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
