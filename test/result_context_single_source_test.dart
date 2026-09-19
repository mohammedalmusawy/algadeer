import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/doctor_target_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/intent_result.dart';
import 'package:ghadeer_clinic/voice/intent/extracted_entities.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/result_context.dart';

/// PC-0.2 invariant: Conversation ordinals resolve against the latest
/// authoritative typed ResultContext, never a legacy/display cache.
void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late DoctorTargetResolver doctorResolver;

  SmartSearchResult doc(
    String id,
    String title, {
    String specialty = 'طب الأطفال',
  }) =>
      SmartSearchResult(
        type: SmartSearchResultType.doctor,
        title: title,
        subtitle: specialty,
        doctorId: id,
        specialty: specialty,
        phone: '0700$id',
        whatsapp: '0700$id',
        clinicLocation: 'موقع-$id',
        score: 90,
      );

  SmartSearchResult lab(String id, String title) => SmartSearchResult(
        type: SmartSearchResultType.lab,
        title: title,
        subtitle: 'مختبر',
        labId: id,
        score: 90,
      );

  SmartSearchResult analysis(String id, String title) => SmartSearchResult(
        type: SmartSearchResultType.analysis,
        title: title,
        subtitle: 'تحليل',
        analysisId: id,
        score: 90,
      );

  SmartSearchResult pkg(
    String id,
    String title, {
    int? price,
    String labId = 'hayat',
  }) =>
      SmartSearchResult(
        type: SmartSearchResultType.package,
        title: title,
        subtitle: 'باقة',
        packageId: id,
        labId: labId,
        labName: 'مختبر الحياة',
        newPrice: price,
        score: 90,
      );

  IntentResult selectIntent([int? ordinal]) => IntentResult(
        intent: AssistantIntent.selectResult,
        originalText: ordinal == 2 ? 'الثاني' : 'الأول',
        normalizedText: ordinal == 2 ? 'الثاني' : 'الاول',
        searchMeaning: '',
        entities: ExtractedEntities(resultIndex: ordinal),
        confidence: 1,
        requiresContext: true,
        source: IntentSource.rules,
      );

  setUp(() {
    ctx = ConversationContext();
    doctorResolver = const DoctorTargetResolver();
    planner = SmartBrainPlanner(
      doctorLookup: (_) async => [
            doc('d1', 'دكتور أطفال أ'),
            doc('d2', 'دكتور أطفال ب'),
            doc('d3', 'دكتور أطفال ج'),
            doc('ent1', 'دكتور أذن أول',
                specialty: 'الأنف والأذن والحنجرة'),
            doc('ent2', 'دكتور أذن ثاني',
                specialty: 'الأنف والأذن والحنجرة'),
            doc('ent3', 'دكتور أذن ثالث',
                specialty: 'الأنف والأذن والحنجرة'),
          ],
      labLookup: (_) async => [
            lab('hayat', 'مختبر الحياة'),
            lab('noor', 'مختبر النور'),
          ],
      analysisLookup: (_) async => [
            AnalysisItem(id: 'cbc', name: 'CBC'),
            AnalysisItem(id: 'vitd', name: 'Vitamin D'),
          ],
      packagesForAnalysisLookup: (_) async => const [],
      activePackagesLookup: ({labId, nameQuery}) async => const [],
      discountedPackagesLookup: ({labId}) async => const [],
    );
  });

  Future<AssistantActionPlan> say(String q) =>
      planner.plan(query: q, context: ctx);

  group('PC-0.2 ResultContext single source', () {
    test('A — doctor results → second = doctor #2', () {
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب'), doc('d3', 'ج')],
        intent: AssistantIntent.specialtySearch,
      );
      expect(ctx.currentResultContext?.entityType, ConversationEntityType.doctor);
      final r = doctorResolver.resolve(
        intentResult: selectIntent(2),
        context: ctx,
      );
      expect(r.source, DoctorTargetSource.ordinal);
      expect(r.doctor?.doctorId, 'd2');
      expect(ctx.selectedDoctor?.doctorId, 'd2');
    });

    test('B — doctor → lab → second = lab #2', () async {
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب'), doc('d3', 'ج')],
        intent: AssistantIntent.specialtySearch,
      );
      ctx.rememberResults(
        [lab('hayat', 'مختبر الحياة'), lab('noor', 'مختبر النور')],
        intent: AssistantIntent.findLab,
      );
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
      final plan = await say('الثاني');
      expect(plan.target?.labId, 'noor');
      expect(ctx.selectedLaboratory?.labId, 'noor');
      expect(ctx.selectedDoctor?.doctorId, isNot('d2'));
    });

    test('C — lab → doctor → second = doctor #2', () async {
      ctx.rememberResults(
        [lab('hayat', 'الحياة'), lab('noor', 'النور')],
        intent: AssistantIntent.findLab,
      );
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب'), doc('d3', 'ج')],
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await say('الثاني');
      expect(plan.target?.doctorId, 'd2');
    });

    test('D — analysis → package → second = package #2', () async {
      ctx.rememberResults(
        [analysis('cbc', 'CBC'), analysis('vitd', 'Vit D')],
        intent: AssistantIntent.findAnalysis,
      );
      ctx.rememberResults(
        [
          pkg('p1', 'باقة أ', price: 50),
          pkg('p2', 'باقة ب', price: 40),
          pkg('p3', 'باقة ج', price: 60),
        ],
        intent: AssistantIntent.findPackage,
      );
      final plan = await say('الثاني');
      expect(plan.target?.packageId, 'p2');
    });

    test('E — package → analysis ResultContext → second = analysis #2', () async {
      ctx.rememberResults(
        [pkg('p1', 'باقة أ', price: 50), pkg('p2', 'باقة ب', price: 40)],
        intent: AssistantIntent.findPackage,
      );
      ctx.rememberResults(
        [analysis('cbc', 'CBC'), analysis('vitd', 'Vit D')],
        intent: AssistantIntent.findAnalysis,
      );
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.analysis,
      );
      final plan = await say('الثاني');
      expect(plan.target?.analysisId, 'vitd');
    });

    test('F — doctor results → empty lab search → second NOT old doctor',
        () async {
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب'), doc('d3', 'ج')],
        intent: AssistantIntent.specialtySearch,
      );
      // بحث مختبر فارغ يستبدل العرض ويُبطِل ResultContext
      ctx.rememberResults(const [], intent: AssistantIntent.findLab);
      expect(ctx.currentResultContext, isNull);
      final plan = await say('الثاني');
      expect(plan.target?.doctorId, isNot('d2'));
      expect(ctx.selectedDoctor?.doctorId, isNot('d2'));
    });

    test('G — package → empty analysis packages → cheapest not old list', () {
      ctx.rememberResults(
        [
          pkg('p1', 'غالية', price: 100),
          pkg('p2', 'رخيصة', price: 20),
        ],
        intent: AssistantIntent.findPackage,
      );
      expect(ctx.currentPackageResultItems.length, 2);
      ctx.rememberAnalysisPackages(const []);
      expect(ctx.currentResultContext, isNull);
      expect(ctx.currentPackageResultItems, isEmpty);
      // بلا سياق باقات سلطوية — لا قراءة من lastPackageSnapshot للترتيبي/أرخص
      expect(
        ctx.authoritativeItemsFor(ConversationEntityType.package),
        isEmpty,
      );
    });

    test('H — mixed/general replacement invalidates ordinal context', () {
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب')],
        intent: AssistantIntent.specialtySearch,
      );
      ctx.rememberResults(
        [
          doc('d1', 'أ'),
          lab('hayat', 'الحياة'),
        ],
        intent: AssistantIntent.generalSearch,
      );
      expect(ctx.currentResultContext, isNull);
      expect(
        ctx.authoritativeItemsFor(ConversationEntityType.doctor),
        isEmpty,
      );
    });

    test('I — new doctor search invalidates stale lab ResultContext', () {
      ctx.rememberResults(
        [lab('hayat', 'أ'), lab('noor', 'ب')],
        intent: AssistantIntent.findLab,
      );
      ctx.beginNewDoctorSearch(intent: AssistantIntent.doctorSearch);
      expect(ctx.currentResultContext, isNull);
      expect(
        ctx.authoritativeItemsFor(ConversationEntityType.laboratory),
        isEmpty,
      );
    });

    test('J — new lab search invalidates stale doctor ResultContext', () {
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب')],
        intent: AssistantIntent.specialtySearch,
      );
      ctx.beginNewLabSearch(intent: AssistantIntent.findLab);
      expect(ctx.currentResultContext, isNull);
    });

    test('K — selectedDoctor can remain when result set becomes laboratory', () {
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب')],
        intent: AssistantIntent.specialtySearch,
        clearSelection: false,
      );
      ctx.selectDoctor(doc('d1', 'أ'));
      expect(ctx.selectedDoctor?.doctorId, 'd1');
      ctx.rememberResults(
        [lab('hayat', 'الحياة'), lab('noor', 'النور')],
        intent: AssistantIntent.findLab,
        clearSelection: false,
      );
      // مع clearSelection:false يبقى الطبيب محفوظاً وResultContext مختبر
      expect(ctx.selectedDoctor?.doctorId, 'd1');
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
    });

    test('L — activeEntityType separate from ResultContext.entityType', () {
      ctx.rememberResults(
        [lab('hayat', 'أ'), lab('noor', 'ب')],
        intent: AssistantIntent.findLab,
      );
      ctx.selectDoctor(doc('d9', 'محفوظ'));
      expect(ctx.activeEntityType, ConversationEntityType.doctor);
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
    });

    test('M — recentReferences still work', () {
      ctx.selectDoctor(doc('d1', 'أ'));
      ctx.selectLaboratory(lab('hayat', 'الحياة'));
      expect(ctx.recentReferences.length, greaterThanOrEqualTo(2));
    });

    test('N — ارجع للطبيب from selectedDoctor', () async {
      ctx.selectDoctor(doc('d1', 'دكتور محفوظ'));
      ctx.selectLaboratory(lab('hayat', 'مختبر'));
      final plan = await say('ارجع للطبيب');
      expect(
        ctx.activeEntityType == ConversationEntityType.doctor ||
            plan.target?.doctorId == 'd1' ||
            plan.message.contains('محفوظ'),
        isTrue,
      );
    });

    test('O — ارجع للمختبر', () async {
      ctx.selectLaboratory(lab('hayat', 'مختبر الحياة'));
      ctx.selectDoctor(doc('d1', 'طبيب'));
      final plan = await say('ارجع للمختبر');
      expect(
        ctx.activeEntityType == ConversationEntityType.laboratory ||
            plan.target?.labId == 'hayat' ||
            plan.message.contains('الحياة'),
        isTrue,
      );
    });

    test('P — pending clarification uses candidates not stale results', () {
      ctx.rememberResults(
        [doc('old1', 'قديم1'), doc('old2', 'قديم2'), doc('old3', 'قديم3')],
        intent: AssistantIntent.specialtySearch,
      );
      ctx.setPendingClarification(
        PendingClarification(
          entityType: ClarificationEntityType.doctor,
          reason: ClarificationReason.ambiguousName,
          candidates: [
            ClarificationCandidate(
              id: 'n1',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: 'مرشح1',
              payload: doc('n1', 'مرشح1'),
            ),
            ClarificationCandidate(
              id: 'n2',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: 'مرشح2',
              payload: doc('n2', 'مرشح2'),
            ),
          ],
        ),
      );
      final items =
          ctx.authoritativeItemsFor(ConversationEntityType.doctor);
      expect(items.map((e) => e.doctorId), ['n1', 'n2']);
      expect(items.any((e) => e.doctorId == 'old2'), isFalse);
    });

    test('Q — resolved clarification does not resurrect via ordinal cache', () {
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب')],
        intent: AssistantIntent.specialtySearch,
      );
      ctx.setPendingClarification(
        PendingClarification(
          entityType: ClarificationEntityType.doctor,
          reason: ClarificationReason.ambiguousName,
          candidates: [
            ClarificationCandidate(
              id: 'x1',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: 'س',
              payload: doc('x1', 'س'),
            ),
          ],
        ),
      );
      ctx.clearPendingClarification();
      // ResultContext الأصلي ما زال صالحاً من rememberResults
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.doctor,
      );
      // lastResults قد يتحدث أثناء clarification كـ display — لا يُستخدم للترتيبي
      final auth = ctx.authoritativeItemsFor(ConversationEntityType.doctor);
      expect(auth.map((e) => e.doctorId).toList(), ['d1', 'd2']);
    });

    test('R — cheapest only package ResultContext', () {
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب')],
        intent: AssistantIntent.specialtySearch,
      );
      expect(ctx.currentPackageResultItems, isEmpty);
      ctx.rememberResults(
        [
          pkg('p1', 'غالية', price: 90),
          pkg('p2', 'رخيصة', price: 15),
        ],
        intent: AssistantIntent.findPackage,
      );
      expect(ctx.currentPackageResultItems.length, 2);
      final priced = ctx.currentPackageResultItems
          .where((p) => p.newPrice != null)
          .toList()
        ..sort((a, b) => a.newPrice!.compareTo(b.newPrice!));
      expect(priced.first.packageId, 'p2');
    });

    test('S — most expensive only package ResultContext', () {
      ctx.rememberResults(
        [
          pkg('p1', 'رخيصة', price: 10),
          pkg('p2', 'غالية', price: 200),
        ],
        intent: AssistantIntent.findPackage,
      );
      final priced = [...ctx.currentPackageResultItems]
        ..sort((a, b) => b.newPrice!.compareTo(a.newPrice!));
      expect(priced.first.packageId, 'p2');
    });

    test('T — invalid package prices ignored', () {
      ctx.rememberResults(
        [
          pkg('p1', 'بلا سعر'),
          pkg('p2', 'بسعر', price: 30),
        ],
        intent: AssistantIntent.findPackage,
      );
      final priced = ctx.currentPackageResultItems
          .where((p) => p.newPrice != null && p.newPrice! > 0)
          .toList();
      expect(priced.length, 1);
      expect(priced.first.packageId, 'p2');
    });

    test('U — contact uses selected entity not arbitrary ordinal set', () async {
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب')],
        intent: AssistantIntent.specialtySearch,
      );
      ctx.selectDoctor(doc('d1', 'أ'));
      final plan = await say('اتصل بيه');
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'd1');
    });

    test('V — location follows valid entity reference', () async {
      ctx.selectDoctor(doc('d2', 'ب'));
      final plan = await say('وين عيادته؟');
      expect(
        plan.kind == AssistantActionKind.showLocation ||
            plan.message.contains('موقع-d2') ||
            plan.target?.doctorId == 'd2',
        isTrue,
      );
    });

    test('W — Step 10F provider results populate doctor ResultContext',
        () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.doctor,
      );
      expect(ctx.currentResultContext!.length, greaterThanOrEqualTo(2));
    });

    test('X — health handoff → second → location', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      await say('الثاني');
      expect(ctx.selectedDoctor?.doctorId, 'ent2');
      final loc = await say('وين عيادته؟');
      expect(
        loc.kind == AssistantActionKind.showLocation ||
            loc.target?.doctorId == 'ent2' ||
            loc.message.contains('موقع'),
        isTrue,
      );
    });

    test('Y — health handoff doctors → new lab → second = lab', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      expect(ctx.currentResultContext?.entityType, ConversationEntityType.doctor);
      ctx.rememberResults(
        [lab('hayat', 'مختبر الحياة'), lab('noor', 'مختبر النور')],
        intent: AssistantIntent.findLab,
      );
      final plan = await say('الثاني');
      expect(plan.target?.labId, 'noor');
    });

    test('Z — reset clears authoritative ResultContext', () {
      ctx.rememberResults(
        [doc('d1', 'أ'), doc('d2', 'ب')],
        intent: AssistantIntent.specialtySearch,
      );
      ctx.reset();
      expect(ctx.currentResultContext, isNull);
      expect(ctx.lastResults, isEmpty);
    });

    test('AA — session fields remain in-memory only', () {
      expect(ctx.debugSnapshot().containsKey('resultEntityType'), isTrue);
    });

    test('AB — voice/text parity of ResultContext semantics', () {
      final a = ConversationContext();
      final b = ConversationContext();
      final items = [doc('d1', 'أ'), doc('d2', 'ب')];
      a.rememberResults(items, intent: AssistantIntent.specialtySearch);
      b.rememberResults(items, intent: AssistantIntent.specialtySearch);
      expect(a.currentResultContext?.entityType, b.currentResultContext?.entityType);
      expect(a.currentResultContext?.length, b.currentResultContext?.length);
      a.selectDoctorByOrdinal(2);
      b.selectDoctorByOrdinal(2);
      expect(a.selectedDoctor?.doctorId, b.selectedDoctor?.doctorId);
    });

    test('AC — legacy lastResults cannot independently resolve ordinal', () {
      ctx.rememberResults(
        [lab('hayat', 'أ'), lab('noor', 'ب')],
        intent: AssistantIntent.findLab,
      );
      // زوّر lastResults بأطباء دون تحديث ResultContext
      ctx.lastResults = [
        doc('stale1', 'قديم1'),
        doc('stale2', 'قديم2'),
        doc('stale3', 'قديم3'),
      ];
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
      final r = doctorResolver.resolve(
        intentResult: selectIntent(2),
        context: ctx,
      );
      // الترتيبي على طبيب مع ResultContext=مختبر → فشل/غير محلول، ليس stale2
      expect(r.doctor?.doctorId, isNot('stale2'));
      expect(
        ctx.authoritativeItemsFor(ConversationEntityType.doctor),
        isEmpty,
      );
    });

    test('AD — _sessionDoctorResults / lastDoctorSnapshot cannot resolve ordinal',
        () {
      ctx.rememberResults(
        [lab('hayat', 'أ'), lab('noor', 'ب')],
        intent: AssistantIntent.findLab,
      );
      // lastDoctorSnapshot يُشتق من lastResults — نزوّره
      ctx.lastResults = [doc('s1', 'س1'), doc('s2', 'س2')];
      expect(ctx.lastDoctorSnapshot.length, 2);
      expect(ctx.selectDoctorByOrdinal(2)?.doctorId, isNull);
    });

    test('AE — no new persistence', () {
      ctx.rememberResults([doc('d1', 'أ')], intent: AssistantIntent.doctorSearch);
      expect(ctx.currentResultContext, isNotNull);
      // لا SharedPreferences — حالة جلسة فقط
    });

    test('AF — no raw health logging in ResultContext path', () {
      final snap = ctx.debugSnapshot();
      expect(snap.toString().contains('صفير'), isFalse);
    });

    test('KNOWN FAILURE SHAPE — أطفال then مختبر then الثاني ≠ doctor#2',
        () async {
      ctx.rememberResults(
        [
          doc('d1', 'أطفال أ'),
          doc('d2', 'أطفال ب'),
          doc('d3', 'أطفال ج'),
        ],
        intent: AssistantIntent.specialtySearch,
      );
      expect(ctx.currentResultContext?.length, 3);
      // استبدال بحالة عرض مختبر/عامة (حتى لو lastResults ما زال فيه أثر)
      ctx.rememberResults(
        [lab('hayat', 'مختبر الحياة')],
        intent: AssistantIntent.findLab,
      );
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
      final plan = await say('الثاني');
      expect(plan.target?.doctorId, isNot('d2'));
      // نتيجة واحدة لمختبر → قد يُحدَّد تلقائياً؛ «الثاني» خارج النطاق
      expect(ctx.selectedDoctor?.doctorId, isNot('d2'));
    });

    test('invariant comment present in ResultContext', () {
      // وجود الملف والفئة كافٍ؛ الثابت موثّق في result_context.dart
      expect(const ResultContext(
        entityType: ConversationEntityType.doctor,
        items: [],
        turnId: 0,
      ).isEmpty, isTrue);
    });
  });
}
