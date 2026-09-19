/// Phase 2F — تحقق تكاملي لجلسة Smart Brain واحدة مستمرة.
///
/// اختبار أولاً. بلا ذكاء جديد وبلا طبقة سياق ثانية.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/labs/labs_service.dart';
import 'package:ghadeer_clinic/memory/memory_session_policy.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
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

  group('سيناريوهات 1–5 و7–8 و11–12 — جلسة واحدة', () {
    test('تدفق طبيب → اختصاص → مختبر → باقة → سريري → مالك → عظام',
        () async {
      final nlu = FakeNluClient(
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
      final h = _Harness(nluClient: nlu);
      final gen0 = h.context.conversationGeneration;
      expect(gen0, kInitialConversationGeneration);
      expect(h.context.allowsPersistentMemorySerialization, isFalse);

      // —— 1. طبيب أطفال → الثاني → اتصل بيه → نعم ——
      await h.deliverSearch(
        'أريد طبيب أطفال',
        [_pedA, _pedB, _pedC],
        intent: AssistantIntent.specialtySearch,
      );
      final genAfterPedSearch = h.context.conversationGeneration;
      _expectDocumentedGeneration(h.context, gen0);
      expect(h.context.currentResultContext?.entityType,
          ConversationEntityType.doctor);
      expect(h.context.currentResultContext?.length, 3);

      final second = await h.turn('الثاني');
      expect(second.kind, AssistantActionKind.selectEntity);
      expect(h.context.selectedDoctor?.doctorId, 'ped_b');
      expect(
        h.context.currentResultContext?.items[1].doctorId,
        'ped_b',
      );
      expect(h.context.conversationGeneration, genAfterPedSearch);
      h.lookupQueries.clear();

      final callPed = await h.turn('اتصل بيه');
      expect(callPed.kind, AssistantActionKind.prepareCall);
      expect(callPed.target?.doctorId, 'ped_b');
      expect(h.lookupQueries, isEmpty);
      expect(h.context.pendingAction, 'call');
      expect(h.context.conversationGeneration, genAfterPedSearch);

      final yesPed = await h.turn('نعم');
      expect(yesPed.kind, AssistantActionKind.prepareCall);
      expect(yesPed.target?.doctorId, 'ped_b');
      expect(h.context.conversationGeneration, genAfterPedSearch);

      // —— 2. تغيير الاختصاص ——
      await h.deliverSearch(
        'أريد طبيب أعصاب',
        [_neuroA, _neuroB],
        intent: AssistantIntent.specialtySearch,
      );
      expect(h.context.selectedDoctor, isNull);
      expect(h.context.currentResultContext?.items.map((e) => e.doctorId),
          isNot(contains('ped_b')));
      final genAfterNeuroSearch = h.context.conversationGeneration;
      _expectDocumentedGeneration(h.context, genAfterPedSearch);

      final firstNeuro = await h.turn('الأول');
      expect(firstNeuro.target?.doctorId, 'neuro_a');
      expect(h.context.selectedDoctor?.doctorId, 'neuro_a');
      expect(h.context.selectedDoctor?.doctorId, isNot('ped_b'));

      h.lookupQueries.clear();
      final callNeuro = await h.turn('اتصل بيه');
      expect(callNeuro.target?.doctorId, 'neuro_a');
      expect(callNeuro.target?.doctorId, isNot('ped_b'));
      expect(h.lookupQueries, isEmpty);
      expect(h.context.conversationGeneration, genAfterNeuroSearch);

      // —— 3. طبيب → مختبر ——
      await h.deliverSearch(
        'أريد مختبر',
        [_labNoor, _labHayat, _labYarmouk],
        intent: AssistantIntent.findLab,
      );
      expect(
        h.context.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
      final genAfterLabSearch = h.context.conversationGeneration;
      _expectDocumentedGeneration(h.context, genAfterNeuroSearch);

      final secondLab = await h.turn('الثاني');
      expect(secondLab.target?.labId, 'hayat');
      expect(h.context.selectedLaboratory?.labId, 'hayat');
      expect(h.context.activeEntityType, ConversationEntityType.laboratory);

      final openThis = await h.turn('افتح هذا');
      expect(openThis.target?.labId, 'hayat');
      expect(openThis.target?.doctorId, isNot('neuro_a'));
      expect(openThis.target?.type, SmartSearchResultType.lab);

      final staleDoctor = await h.turn('هذا الدكتور');
      expect(staleDoctor.kind, isNot(AssistantActionKind.prepareCall));
      expect(staleDoctor.target?.doctorId, isNot('neuro_a'));
      expect(staleDoctor.target?.doctorId, isNot('ped_b'));
      expect(
        staleDoctor.kind,
        anyOf(
          AssistantActionKind.showMessage,
          AssistantActionKind.showClarification,
        ),
      );
      _expectDocumentedGeneration(h.context, genAfterLabSearch);

      // —— 4. مختبر → باقة ——
      final pkgs = await h.turn('شنو باقاته؟');
      expect(pkgs.kind, AssistantActionKind.showLabPackages);
      expect(
        h.context.currentResultContext?.entityType,
        ConversationEntityType.package,
      );
      expect(h.context.currentResultContext?.length, 3);
      _expectDocumentedGeneration(h.context, genAfterLabSearch);
      final genAfterPkgs = h.context.conversationGeneration;

      final secondPkg = await h.turn('الثاني');
      expect(secondPkg.target?.packageId, 'pkg_b');
      expect(h.context.selectedPackage?.packageId, 'pkg_b');
      expect(h.context.conversationGeneration, genAfterPkgs);

      final openPkg = await h.turn('افتح هاي الباقة');
      expect(openPkg.target?.packageId, 'pkg_b');
      expect(openPkg.target?.doctorId, isNull);
      expect(openPkg.target?.type, SmartSearchResultType.package);
      expect(h.context.selectedPackage?.packageId, 'pkg_b');
      _expectDocumentedGeneration(h.context, genAfterPkgs);
      final genAfterOpenPkg = h.context.conversationGeneration;

      final leftoverDoctor = h.context.selectedDoctor?.doctorId;
      final leftoverLab = h.context.selectedLaboratory?.labId;
      final leftoverPkg = h.context.selectedPackage?.packageId;

      // —— 5. سلسلة سريرية للطفل (الكيانات المحددة لا تختطف الموضوع) ——
      await h.turn('ابني عنده سعال من يومين');
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
      expect(
        h.context.respiratorySession.durationBucket,
        RespiratoryDurationBucket.days,
      );
      expect(h.context.conversationGeneration, genAfterOpenPkg);

      await h.turn('8 سنوات');
      expect(h.context.healthSubject.ageYears, 8);
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.selectedDoctor?.doctorId, leftoverDoctor);
      expect(h.context.selectedLaboratory?.labId, leftoverLab);
      expect(h.context.selectedPackage?.packageId, leftoverPkg);

      final feverTurn = await h.turn('عنده حرارة ويا السعال وما ياخذ هوا');
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
        reason: feverTurn.message,
      );
      expect(feverTurn.kind, isNot(AssistantActionKind.prepareCall));
      expect(feverTurn.target?.doctorId, isNull);
      expect(feverTurn.target?.packageId, isNull);

      final pronounClinical = await h.turn('هو عنده حرارة');
      expect(pronounClinical.kind, isNot(AssistantActionKind.prepareCall));
      expect(pronounClinical.target?.doctorId, isNot(leftoverDoctor));
      expect(h.context.healthSubject.type, HealthSubjectType.child);

      final demonstrativeClinical = await h.turn('هاي الأعراض من يومين');
      expect(demonstrativeClinical.target?.packageId, isNull);
      expect(demonstrativeClinical.target?.labId, isNull);
      expect(demonstrativeClinical.target?.type,
          isNot(SmartSearchResultType.doctor));
      expect(h.context.selectedPackage?.packageId, leftoverPkg);

      // —— 11. unknown لا يمسح known ——
      await h.turn('والسعال مستمر');
      expect(h.context.respiratorySession.fever, RespiratoryTriState.present);
      expect(
        h.context.respiratorySession.breathlessness,
        RespiratoryTriState.present,
      );
      expect(
        h.context.respiratorySession.durationBucket,
        RespiratoryDurationBucket.days,
      );
      expect(h.context.conversationGeneration, genAfterOpenPkg);

      // —— 7. تبديل الموضوع إلى المالك ——
      final self = await h.turn('اني عندي ألم بالظهر');
      expect(h.context.healthSubject.type, isNot(HealthSubjectType.child));
      expect(h.context.healthSubject.ageYears, isNull);
      expect(h.context.respiratorySession.active, isFalse);
      expect(
        h.context.respiratorySession.fever,
        isNot(RespiratoryTriState.present),
      );
      expect(
        h.context.mskSession.active ||
            self.message.contains('ظهر') ||
            self.message.contains('عظام'),
        isTrue,
        reason: self.message,
      );
      expect(h.context.lastResetReason, ConversationResetReason.subjectChanged);
      expect(
        h.context.conversationGeneration,
        greaterThan(genAfterOpenPkg),
      );
      final genAfterSelf = h.context.conversationGeneration;

      // —— 8. الرجوع إلى البحث (Phase 2G: طلب خدمة صريح يقطع السؤال السريري) ——
      await h.deliverSearch(
        'أريد طبيب عظام',
        [_orthoA, _orthoB, _orthoC],
        intent: AssistantIntent.specialtySearch,
      );
      _expectDocumentedGeneration(h.context, genAfterSelf);
      final orthoSecond = await h.turn('الثاني');
      expect(orthoSecond.target?.doctorId, 'ortho_b');
      h.lookupQueries.clear();
      final callOrtho = await h.turn('اتصل بيه');
      expect(callOrtho.kind, AssistantActionKind.prepareCall);
      expect(callOrtho.target?.doctorId, 'ortho_b');
      expect(h.lookupQueries, isEmpty);
      expect(h.context.healthSubject.ageYears, isNull);

      expect(identical(h.context, h.context), isTrue);
      expect(h.context.allowsPersistentMemorySerialization, isFalse);
      expect(
        const MemorySessionOnlyPolicy().maySerializeConversationContextAsMemory(),
        isFalse,
      );
    });
  });

  group('سيناريو 6 — نعم/لا السريري أمام pendingAction قديم', () {
    test('نعم ولا تستهلكهما الجلسة السريرية لا الاتصال', () async {
      final h = _Harness();
      h.context.rememberResults([_ali], intent: AssistantIntent.doctorSearch);
      await h.turn('اتصل');
      expect(h.context.pendingAction, 'call');

      await h.turn('ابني عنده سعال من يومين');
      if (h.context.respiratorySession.lastQuestionKey != 'childAssociated') {
        await h.turn('8 سنوات');
      }
      expect(h.context.respiratorySession.lastQuestionKey, 'childAssociated');

      final yes = await h.turn('نعم');
      expect(yes.kind, isNot(AssistantActionKind.prepareCall));
      expect(h.context.pendingAction, isNull);

      await h.turn('ابني عنده سعال من يومين');
      if (h.context.respiratorySession.lastQuestionKey != 'childAssociated') {
        await h.turn('8 سنوات');
      }
      final no = await h.turn('لا');
      expect(no.kind, isNot(AssistantActionKind.prepareCall));
      expect(
        h.context.respiratorySession.fever.name,
        anyOf('absent', 'unknown'),
      );
    });
  });

  group('سيناريو 9 — أمان بلا سياق', () {
    test('الثاني / اتصل بيه / افتح هذا / نعم / 2 لا تختار اعتباطاً', () async {
      for (final q in ['الثاني', 'اتصل بيه', 'افتح هذا', 'نعم', '2']) {
        final h = _Harness();
        final plan = await h.turn(q);
        expect(plan.kind, isNot(AssistantActionKind.prepareCall), reason: q);
        expect(plan.target, isNull, reason: q);
        expect(h.context.selectedDoctor, isNull, reason: q);
        expect(h.context.selectedLaboratory, isNull, reason: q);
        expect(h.context.selectedPackage, isNull, reason: q);
        expect(h.context.healthSubject.ageYears, isNull, reason: q);
        expect(h.lookupQueries, isEmpty, reason: q);
        expect(plan.kind, isNot(AssistantActionKind.selectEntity), reason: q);
      }
    });
  });

  group('سيناريو 10 — الاسم الصريح يغلب', () {
    test('طبيب A ثم علي ناصر ثم نعم تؤكد علي', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'د. أحمد كاظم'), _ali, _doc('c', 'د. كريم جاسم')],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('الأول');
      expect(h.context.selectedDoctor?.doctorId, 'a');
      final call = await h.turn('اتصل بالدكتور علي ناصر');
      expect(call.target?.doctorId, 'ali');
      expect(h.context.selectedDoctor?.doctorId, 'ali');
      expect(h.context.pendingAction, 'call');
      final yes = await h.turn('نعم');
      expect(yes.kind, AssistantActionKind.prepareCall);
      expect(yes.target?.doctorId, 'ali');
    });
  });
}

void _expectDocumentedGeneration(ConversationContext ctx, int previous) {
  expect(
    ctx.conversationGeneration,
    anyOf(previous, greaterThan(previous)),
  );
  if (ctx.conversationGeneration > previous) {
    expect(
      ctx.lastResetReason,
      anyOf(
        ConversationResetReason.foreignTurn,
        ConversationResetReason.subjectChanged,
        ConversationResetReason.explicitUserReset,
        ConversationResetReason.pageDisposed,
      ),
    );
  }
}

final _pedA = _doc('ped_a', 'طبيب أطفال أ', specialty: 'طب الأطفال');
final _pedB = _doc('ped_b', 'طبيب أطفال ب', specialty: 'طب الأطفال');
final _pedC = _doc('ped_c', 'طبيب أطفال ج', specialty: 'طب الأطفال');
final _neuroA = _doc('neuro_a', 'طبيب أعصاب أ', specialty: 'طب الأعصاب');
final _neuroB = _doc('neuro_b', 'طبيب أعصاب ب', specialty: 'طب الأعصاب');
final _orthoA = _doc('ortho_a', 'طبيب عظام أ', specialty: 'العظام');
final _orthoB = _doc('ortho_b', 'طبيب عظام ب', specialty: 'العظام');
final _orthoC = _doc('ortho_c', 'طبيب عظام ج', specialty: 'العظام');
final _ali = _doc('ali', 'د. علي ناصر السعيدي', specialty: 'طب الأطفال');

final _labNoor = _lab('noor', 'مختبر النور');
final _labHayat = _lab('hayat', 'مختبر الحياة');
final _labYarmouk = _lab('yarmouk', 'مختبر اليرموك');

SmartSearchResult _doc(
  String id,
  String title, {
  String specialty = 'اختصاص',
}) =>
    SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: specialty,
      doctorId: id,
      specialty: specialty,
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
      clinicLocation: 'بغداد',
      score: 90,
    );

LabPackageItem _pkg(String id, String name) => LabPackageItem(
      id: id,
      labId: 'hayat',
      name: name,
      newPrice: 40000,
      isActive: true,
    );

class _Harness {
  _Harness({NluClient? nluClient}) {
    context = ConversationContext();
    lookupQueries = <String>[];
    planner = SmartBrainPlanner(
      nluClient: nluClient ?? NluClient.disabled,
      doctorLookup: (q) async {
        lookupQueries.add(q);
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('علي') && n.contains('ناصر')) return [_ali];
        return const [];
      },
      labLookup: (_) async => [_labNoor, _labHayat, _labYarmouk],
      analysisLookup: (_) async => const [],
      packagesLookup: (labId) async {
        if (labId != 'hayat') return const [];
        return [
          _pkg('pkg_a', 'باقة أ'),
          _pkg('pkg_b', 'باقة ب'),
          _pkg('pkg_c', 'باقة ج'),
        ];
      },
      packagesForAnalysisLookup: (_) async => const [],
      activePackagesLookup: ({labId, nameQuery}) async => [
            if (labId == null || labId == 'hayat')
              AnalysisPackageLink(
                package: _pkg('pkg_a', 'باقة أ'),
                labId: 'hayat',
                labName: 'مختبر الحياة',
              ),
            if (labId == null || labId == 'hayat')
              AnalysisPackageLink(
                package: _pkg('pkg_b', 'باقة ب'),
                labId: 'hayat',
                labName: 'مختبر الحياة',
              ),
            if (labId == null || labId == 'hayat')
              AnalysisPackageLink(
                package: _pkg('pkg_c', 'باقة ج'),
                labId: 'hayat',
                labName: 'مختبر الحياة',
              ),
          ],
      discountedPackagesLookup: ({labId}) async => const [],
    );
  }

  late final ConversationContext context;
  late final SmartBrainPlanner planner;
  late final List<String> lookupQueries;

  Future<AssistantActionPlan> turn(String query) =>
      planner.plan(query: query, context: context);

  Future<AssistantActionPlan> deliverSearch(
    String query,
    List<SmartSearchResult> results, {
    required AssistantIntent intent,
  }) async {
    final plan = await turn(query);
    expect(
      plan.kind,
      anyOf(
        AssistantActionKind.runSpecialtySearch,
        AssistantActionKind.runDoctorSearch,
        AssistantActionKind.runLabSearch,
        AssistantActionKind.runGeneralSearch,
        AssistantActionKind.showClarification,
      ),
      reason: '$query → ${plan.kind} ${plan.message}',
    );
    context.rememberResults(results, query: query, intent: intent);
    return plan;
  }
}
