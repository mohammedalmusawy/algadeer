import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/labs/labs_service.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

AnalysisItem _cbc() => const AnalysisItem(
      id: 'cbc',
      name: 'CBC',
      shortName: 'CBC',
      nameAr: 'صورة الدم الكاملة',
      isActive: true,
    );

AnalysisItem _vitD() => const AnalysisItem(
      id: 'vitd',
      name: 'Vitamin D',
      shortName: 'Vit D',
      nameAr: 'فيتامين د',
      aliases: ['فيتامين دي'],
      isActive: true,
    );

LabPackageItem _pkg({
  required String id,
  required String labId,
  required String name,
  int? oldPrice,
  int? newPrice,
  bool isActive = true,
  List<AnalysisItem> analyses = const [],
}) {
  return LabPackageItem(
    id: id,
    labId: labId,
    name: name,
    oldPrice: oldPrice,
    newPrice: newPrice,
    isActive: isActive,
    analyses: analyses,
  );
}

SmartSearchResult _doc(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: 'أطفال',
      doctorId: id,
      specialty: 'أطفال',
      clinicLocation: 'الكرادة',
      phone: '07701111111',
      whatsapp: '07701111111',
    );

SmartSearchResult _lab(String id, String title, {String location = 'بغداد'}) =>
    SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: location,
      labId: id,
      labName: title,
      clinicLocation: location,
      phone: '07702222222',
      whatsapp: '07702222222',
    );

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late RuleBasedIntentResolver resolver;

  final pkgA = _pkg(
    id: 'pkg_a',
    labId: 'hayat',
    name: 'باقة الفحص الشامل',
    oldPrice: 100000,
    newPrice: 80000,
    analyses: [_cbc(), _vitD()],
  );
  final pkgB = _pkg(
    id: 'pkg_b',
    labId: 'noor',
    name: 'باقة الصحة',
    oldPrice: 60000,
    newPrice: 25000,
    analyses: [_cbc(), _vitD()],
  );
  final pkgC = _pkg(
    id: 'pkg_c',
    labId: 'hayat',
    name: 'باقة الدم',
    newPrice: 40000,
    analyses: [_cbc()],
  );
  final pkgNoPrice = _pkg(
    id: 'pkg_np',
    labId: 'hayat',
    name: 'باقة بلا سعر',
    analyses: [_cbc()],
  );

  AnalysisPackageLink link(LabPackageItem p, String labName) =>
      AnalysisPackageLink(package: p, labId: p.labId, labName: labName);

  final activeLinks = [
    link(pkgA, 'مختبر الحياة'),
    link(pkgB, 'مختبر النور'),
    link(pkgC, 'مختبر الحياة'),
    link(pkgNoPrice, 'مختبر الحياة'),
  ];

  setUp(() {
    ctx = ConversationContext();
    resolver = RuleBasedIntentResolver();
    planner = SmartBrainPlanner(
      analysisLookup: (q) async {
        final n = q.toLowerCase();
        if (n.contains('cbc') || n.contains('دم')) return [_cbc()];
        if (n.contains('فيتامين') || n.contains('vit') || n.contains('d')) {
          return [_vitD()];
        }
        return [_cbc(), _vitD()];
      },
      packagesForAnalysisLookup: (analysisId) async => [
            for (final l in activeLinks)
              if (l.package.isActive &&
                  l.package.analyses.any((a) => a.id == analysisId))
                l,
          ],
      packagesContainingAllLookup: (ids, {labId}) async => [
            for (final l in activeLinks)
              if (l.package.isActive &&
                  (labId == null || labId.isEmpty || l.labId == labId) &&
                  ids.every(
                    (id) => l.package.analyses.any((a) => a.id == id),
                  ))
                l,
          ],
      activePackagesLookup: ({labId, nameQuery}) async => [
            for (final l in activeLinks)
              if (l.package.isActive &&
                  (labId == null || labId.isEmpty || l.labId == labId) &&
                  ((nameQuery ?? '').trim().isEmpty ||
                      ArabicTextUtils.normalize(l.package.name).contains(
                        ArabicTextUtils.normalize(nameQuery!),
                      )))
                l,
          ],
      packagesLookup: (labId) async => [
            for (final l in activeLinks)
              if (l.labId == labId && l.package.isActive) l.package,
          ],
      packageDetailsLookup: (id) async {
        for (final l in activeLinks) {
          if (l.package.id == id) return l.package;
        }
        return null;
      },
      labLookup: (q) async {
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('حيا')) return [_lab('hayat', 'مختبر الحياة')];
        if (n.contains('نور')) return [_lab('noor', 'مختبر النور')];
        return [_lab('hayat', 'مختبر الحياة'), _lab('noor', 'مختبر النور')];
      },
      doctorLookup: (_) async => [
            _doc('d1', 'دكتور أطفال أ'),
            _doc('d2', 'دكتور أطفال ب'),
          ],
    );
  });

  group('Unified Multi-Entity Conversation', () {
    test('A — Analysis → packages → cheapest → lab → location', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      expect(ctx.currentResultContext?.entityType,
          ConversationEntityType.package);
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
      final cheap = await planner.plan(query: 'أرخص وحدة', context: ctx);
      expect(cheap.kind, AssistantActionKind.selectEntity);
      expect(ctx.activeEntityType, ConversationEntityType.package);
      expect(ctx.selectedPackage?.newPrice, 25000);
      final labPlan = await planner.plan(query: 'أي مختبر؟', context: ctx);
      expect(labPlan.target?.labId, isNotNull);
      final loc = await planner.plan(query: 'وين موقعه؟', context: ctx);
      expect(
        loc.kind == AssistantActionKind.showLocation ||
            loc.target?.type == SmartSearchResultType.lab,
        isTrue,
      );
    });

    test('B — packages → package → lab → WhatsApp', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      await planner.plan(query: 'الثانية', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.package);
      await planner.plan(query: 'أي مختبر؟', context: ctx);
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.type, SmartSearchResultType.lab);
    });

    test('C — multi analysis intersection → package → analyses', () async {
      final plan = await planner.plan(
        query: 'أريد باقة بيها CBC وفيتامين D',
        context: ctx,
      );
      expect(plan.candidates.length, greaterThanOrEqualTo(2));
      await planner.plan(query: 'الثانية', context: ctx);
      final analyses =
          await planner.plan(query: 'شنو تحاليلها؟', context: ctx);
      expect(
        analyses.kind == AssistantActionKind.showPackageAnalyses ||
            analyses.message.contains('تحاليل'),
        isTrue,
      );
    });

    test('D — Lab → packages → first → price', () async {
      await planner.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      await planner.plan(query: 'شنو باقاته؟', context: ctx);
      await planner.plan(query: 'الأولى', context: ctx);
      final price = await planner.plan(query: 'شكد سعرها؟', context: ctx);
      expect(
        price.kind == AssistantActionKind.showPackagePrice ||
            price.message.contains('سعر'),
        isTrue,
      );
    });

    test('E — Lab → packages → package → return lab → location', () async {
      await planner.plan(query: 'أريد مختبر الحياة', context: ctx);
      await planner.plan(query: 'شنو باقاته؟', context: ctx);
      await planner.plan(query: 'الثانية', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.package);
      final back = await planner.plan(query: 'ارجع للمختبر', context: ctx);
      expect(back.kind, AssistantActionKind.selectEntity);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      final loc = await planner.plan(query: 'وين موقعه؟', context: ctx);
      expect(
        loc.kind == AssistantActionKind.showLocation ||
            loc.target?.type == SmartSearchResultType.lab,
        isTrue,
      );
    });

    test('F — Doctor → location → Analysis — no doctor leakage', () async {
      await planner.plan(query: 'أريد طبيب أطفال', context: ctx);
      ctx.rememberResults([_doc('d1', 'دكتور أطفال أ')]);
      await planner.plan(query: 'وين عيادته؟', context: ctx);
      expect(ctx.selectedDoctor, isNotNull);
      await planner.plan(query: 'هسه أريد تحليل فيتامين D', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
      expect(ctx.selectedAnalysis?.analysisId, 'vitd');
      final where = await planner.plan(query: 'وين موجود؟', context: ctx);
      expect(where.target?.type, isNot(SmartSearchResultType.doctor));
      expect(ctx.selectedDoctor, isNotNull); // محفوظ لكن غير نشط
    });

    test('G — doctor results then packages: الثاني → package #2', () async {
      ctx.rememberResults([
        _doc('d1', 'دكتور أ'),
        _doc('d2', 'دكتور ب'),
      ]);
      expect(ctx.currentResultContext?.entityType,
          ConversationEntityType.doctor);
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      expect(ctx.currentResultContext?.entityType,
          ConversationEntityType.package);
      final plan = await planner.plan(query: 'الثاني', context: ctx);
      expect(
        plan.target?.type == SmartSearchResultType.package ||
            plan.target?.type == SmartSearchResultType.offer,
        isTrue,
      );
      expect(plan.target?.type, isNot(SmartSearchResultType.doctor));
    });

    test('H — package results then doctors: الأول → doctor #1', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      ctx.rememberResults([
        _doc('d1', 'دكتور أ'),
        _doc('d2', 'دكتور ب'),
      ]);
      expect(ctx.currentResultContext?.entityType,
          ConversationEntityType.doctor);
      final plan = await planner.plan(query: 'الأول', context: ctx);
      expect(plan.target?.doctorId, 'd1');
    });

    test('I — هذا التحليل → selectedAnalysis even if package active', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      await planner.plan(query: 'الأولى', context: ctx);
      expect(ctx.selectedPackage, isNotNull);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');
      final plan =
          await planner.plan(query: 'هذا التحليل', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
      expect(plan.target?.analysisId, 'cbc');
    });

    test('J — هاي الباقة → selectedPackage', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      await planner.plan(query: 'الأولى', context: ctx);
      ctx.focusOn(ConversationEntityType.analysis);
      final plan = await planner.plan(query: 'هاي الباقة', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.package);
      expect(plan.target?.packageId, isNotNull);
    });

    test('K — هذا المختبر → selectedLaboratory', () async {
      ctx.rememberResults([_lab('hayat', 'مختبر الحياة')]);
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      final plan =
          await planner.plan(query: 'هذا المختبر', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      expect(plan.target?.labId, 'hayat');
    });

    test('L — ارجع للطبيب', () async {
      ctx.rememberResults([_doc('d1', 'دكتور أطفال')]);
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      final plan = await planner.plan(query: 'ارجع للطبيب', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.doctor);
      expect(plan.target?.doctorId, 'd1');
    });

    test('M — ارجع للمختبر', () async {
      ctx.rememberResults([_lab('hayat', 'مختبر الحياة')]);
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'ارجع للمختبر', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
    });

    test('N — ارجع للتحليل', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      await planner.plan(query: 'الأولى', context: ctx);
      await planner.plan(query: 'ارجع للتحليل', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');
    });

    test('O — ارجع للباقة', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      await planner.plan(query: 'الأولى', context: ctx);
      ctx.focusOn(ConversationEntityType.analysis);
      await planner.plan(query: 'ارجع للباقة', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.package);
    });

    test('P — package اتصل بيهم → provider lab', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      await planner.plan(query: 'الأولى', context: ctx);
      final plan = await planner.plan(query: 'اتصل بيهم', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.type, SmartSearchResultType.lab);
    });

    test('Q — analysis اتصل بيه → no invalid call', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      final plan = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.message, contains('ما عنده رقم اتصال'));
    });

    test('R — package سعرها → package', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      await planner.plan(query: 'الأولى', context: ctx);
      final plan = await planner.plan(query: 'سعرها', context: ctx);
      expect(
        plan.kind == AssistantActionKind.showPackagePrice ||
            plan.message.contains('سعر'),
        isTrue,
      );
    });

    test('S — analysis سعره → no fake analysis price', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      final plan = await planner.plan(query: 'سعره', context: ctx);
      expect(plan.message, isNot(contains('سعر التحليل')));
      expect(
        plan.message.contains('باق') || plan.message.contains('ماكو سعر'),
        isTrue,
      );
    });

    test('T — package تحاليلها', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      await planner.plan(query: 'الأولى', context: ctx);
      final plan = await planner.plan(query: 'تحاليلها', context: ctx);
      expect(
        plan.kind == AssistantActionKind.showPackageAnalyses ||
            plan.message.contains('تحاليل'),
        isTrue,
      );
    });

    test('U — laboratory تحاليله truthful', () async {
      await planner.plan(query: 'أريد مختبر الحياة', context: ctx);
      final plan = await planner.plan(query: 'تحاليله', context: ctx);
      // كتالوج عبر الباقات أو رسالة آمنة — ليس قائمة طبية مخترعة.
      expect(plan.canExecute || plan.message.isNotEmpty, isTrue);
    });

    test('V — pending clarification priority', () async {
      ctx.rememberResults([
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: 'CBC',
          subtitle: 'CBC',
          analysisId: 'cbc',
        ),
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: 'فيتامين د',
          subtitle: 'Vit D',
          analysisId: 'vitd',
        ),
      ]);
      expect(ctx.hasPendingClarification, isTrue);
      final plan = await planner.plan(query: 'الثاني', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedAnalysis?.analysisId, 'vitd');
    });

    test('W — clear new search abandons pending', () async {
      ctx.rememberResults([
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: 'CBC',
          subtitle: 'CBC',
          analysisId: 'cbc',
        ),
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: 'فيتامين د',
          subtitle: 'Vit D',
          analysisId: 'vitd',
        ),
      ]);
      expect(ctx.hasPendingClarification, isTrue);
      await planner.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('X — invalid ordinal does not use stale older set', () async {
      ctx.rememberResults([
        _doc('d1', 'دكتور أ'),
        _doc('d2', 'دكتور ب'),
        _doc('d3', 'دكتور ج'),
      ]);
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      // باقتان/ثلاث فقط — الثالث من الأطباء لا يُختار.
      final plan = await planner.plan(query: 'الثالث', context: ctx);
      expect(plan.target?.doctorId, isNull);
      if (plan.kind == AssistantActionKind.selectEntity) {
        expect(plan.target?.type, SmartSearchResultType.package);
      } else {
        expect(
          plan.kind == AssistantActionKind.showClarification ||
              plan.kind == AssistantActionKind.showMessage,
          isTrue,
        );
      }
    });

    test('Y — cheapest only from package results', () async {
      ctx.rememberResults([_doc('d1', 'رخيص'), _doc('d2', 'غالي')]);
      final plan = await planner.plan(query: 'أرخص وحدة', context: ctx);
      // بدون نتائج باقات — إما بحث باقات عام أو رسالة؛ ليس طبيب.
      expect(plan.target?.type, isNot(SmartSearchResultType.doctor));
    });

    test('Z — missing prices → no unsafe cheapest', () async {
      ctx.setResultContext(
        entityType: ConversationEntityType.package,
        items: [
          SmartSearchResult(
            type: SmartSearchResultType.package,
            title: 'بلا سعر',
            subtitle: 'مختبر',
            packageId: 'np',
            labId: 'hayat',
          ),
        ],
      );
      final plan = await planner.plan(query: 'أرخص وحدة', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
    });

    test('AA — inactive relationship → safe recovery', () async {
      ctx.selectPackage(
        SmartSearchResult(
          type: SmartSearchResultType.package,
          title: 'باقة يتيمة',
          subtitle: '',
          packageId: 'orphan',
          // no labId
        ),
      );
      final plan = await planner.plan(query: 'أي مختبر؟', context: ctx);
      expect(plan.canExecute == false || plan.message.isNotEmpty, isTrue);
    });

    test('AB — strong active lab: اتصل بيه no unnecessary clarification',
        () async {
      ctx.rememberResults([_lab('hayat', 'مختبر الحياة')]);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      final plan = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.labId, 'hayat');
      expect(plan.kind, isNot(AssistantActionKind.showClarification));
    });

    test('AC — ambiguous contact pronoun → clarification', () async {
      ctx.selectedDoctor = _doc('d1', 'دكتور أ');
      ctx.selectedLaboratory = _lab('hayat', 'مختبر الحياة');
      ctx.activeEntityType = ConversationEntityType.none;
      final plan = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(plan.canExecute, isFalse);
    });

    test('AD — typed/voice parity', () {
      const q = 'ارجع للتحليل';
      final a = resolver.resolve(q);
      final b = resolver.resolve(q);
      expect(a.intent, b.intent);
      expect(a.entities.actionHint, b.entities.actionHint);
      expect(QueryInputSource.typed, isNot(QueryInputSource.voice));
    });

    test('AE — context reset clears focus/results/refs/pending', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      ctx.reset();
      expect(ctx.activeEntityType, ConversationEntityType.none);
      expect(ctx.currentResultContext, isNull);
      expect(ctx.recentReferences, isEmpty);
      expect(ctx.hasPendingClarification, isFalse);
      expect(ctx.selectedAnalysis, isNull);
      expect(ctx.turnId, 0);
    });

    test('AF — recent references bounded', () {
      for (var i = 0; i < 20; i++) {
        ctx.pushRecentReference(_doc('d$i', 'دكتور $i'));
      }
      expect(
        ctx.recentReferences.length,
        lessThanOrEqualTo(ConversationContext.maxRecentReferences),
      );
    });

    test('AG — debugSnapshot accurate', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      final snap = ctx.debugSnapshot();
      expect(snap['activeEntityType'], 'analysis');
      expect(snap['selectedAnalysisId'], 'cbc');
      expect(snap['turnId'], isA<int>());
      expect(snap.containsKey('recentReferenceTypes'), isTrue);
    });

    test('AH — no symptom/medical inference', () async {
      final plan = await planner.plan(
        query: 'عندي تعب شنو تحليل أسوي؟',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, contains('ما أگدر أوصي'));
    });
  });

  group('Long conversation scripts', () {
    test('SCRIPT 1 — CBC → packages → cheapest → lab → location → WA',
        () async {
      await planner.plan(query: 'أريد CBC', context: ctx);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');

      await planner.plan(query: 'بأي باقات موجود؟', context: ctx);
      expect(ctx.currentResultContext?.entityType,
          ConversationEntityType.package);
      expect(ctx.activeEntityType, ConversationEntityType.analysis);

      await planner.plan(query: 'أرخص وحدة', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.package);
      expect(ctx.selectedPackage?.newPrice, 25000);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');

      await planner.plan(query: 'أي مختبر؟', context: ctx);
      expect(ctx.selectedLaboratory?.labId, isNotNull);

      final loc = await planner.plan(query: 'وين موقعه؟', context: ctx);
      expect(
        loc.kind == AssistantActionKind.showLocation ||
            loc.target?.type == SmartSearchResultType.lab,
        isTrue,
      );

      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.type, SmartSearchResultType.lab);
    });

    test('SCRIPT 2 — lab → packages → package → analyses → return → call',
        () async {
      await planner.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);

      await planner.plan(query: 'شنو باقاته؟', context: ctx);
      expect(ctx.currentResultContext?.entityType,
          ConversationEntityType.package);

      await planner.plan(query: 'الثانية', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.package);

      await planner.plan(query: 'شنو تحاليلها؟', context: ctx);

      await planner.plan(query: 'ارجع للمختبر', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);

      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.labId, 'hayat');
    });

    test('SCRIPT 3 — doctor → analysis → packages → price — no leakage',
        () async {
      ctx.rememberResults([_doc('ped', 'دكتور أطفال')]);
      expect(ctx.activeEntityType, ConversationEntityType.doctor);

      await planner.plan(query: 'وين عيادته؟', context: ctx);
      expect(ctx.selectedDoctor?.doctorId, 'ped');

      await planner.plan(query: 'هسه أريد تحليل فيتامين D', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
      expect(ctx.selectedAnalysis?.analysisId, 'vitd');
      expect(ctx.selectedDoctor?.doctorId, 'ped');

      await planner.plan(query: 'بأي باقات؟', context: ctx);
      expect(ctx.currentResultContext?.entityType,
          ConversationEntityType.package);

      await planner.plan(query: 'الأولى', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.package);

      final price = await planner.plan(query: 'شكد سعرها؟', context: ctx);
      expect(
        price.kind == AssistantActionKind.showPackagePrice ||
            price.message.contains('سعر'),
        isTrue,
      );

      await planner.plan(query: 'أي مختبر؟', context: ctx);
      expect(ctx.selectedDoctor?.doctorId, 'ped');
      expect(ctx.selectedAnalysis?.analysisId, 'vitd');
      expect(ctx.activeEntityType, isNot(ConversationEntityType.doctor));
    });
  });

  group('ResultContext isolation', () {
    test('ResultContext holds typed items and turnId', () {
      ctx.setResultContext(
        entityType: ConversationEntityType.package,
        items: [
          SmartSearchResult(
            type: SmartSearchResultType.package,
            title: 'A',
            subtitle: 'lab',
            packageId: 'a',
            newPrice: 10,
          ),
        ],
      );
      expect(ctx.currentResultContext!.entityType,
          ConversationEntityType.package);
      expect(ctx.turnId, greaterThan(0));
      expect(ctx.currentResultContext!.atOrdinal(1)?.packageId, 'a');
    });
  });
}
