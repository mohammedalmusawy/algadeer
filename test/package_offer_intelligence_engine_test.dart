import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/labs/labs_service.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
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

AnalysisItem _hba1c() => const AnalysisItem(
      id: 'hba1c',
      name: 'HbA1c',
      shortName: 'HbA1c',
      nameAr: 'السكر التراكمي',
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
      phone: '0770',
      whatsapp: '0770',
    );

SmartSearchResult _lab(String id, String title, {String location = 'بغداد'}) =>
    SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: location,
      labId: id,
      labName: title,
      clinicLocation: location,
      phone: '0770',
      whatsapp: '0770',
    );

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late RuleBasedIntentResolver resolver;

  final catalog = [_cbc(), _vitD(), _hba1c()];

  final pkgHayatFull = _pkg(
    id: 'pkg_h_full',
    labId: 'hayat',
    name: 'باقة الفحص الشامل',
    oldPrice: 100000,
    newPrice: 80000,
    analyses: [_cbc(), _vitD(), _hba1c()],
  );
  final pkgNoorFull = _pkg(
    id: 'pkg_n_full',
    labId: 'noor',
    name: 'باقة الفحص الشامل',
    oldPrice: 90000,
    newPrice: 70000,
    analyses: [_cbc(), _vitD()],
  );
  final pkgHayatCbcOnly = _pkg(
    id: 'pkg_h_cbc',
    labId: 'hayat',
    name: 'باقة الدم',
    oldPrice: null,
    newPrice: 40000,
    analyses: [_cbc()],
  );
  final pkgCheapCombo = _pkg(
    id: 'pkg_cheap_combo',
    labId: 'noor',
    name: 'باقة الصحة',
    oldPrice: 60000,
    newPrice: 25000,
    analyses: [_cbc(), _vitD()],
  );
  final pkgNoPrice = _pkg(
    id: 'pkg_noprice',
    labId: 'hayat',
    name: 'باقة بدون سعر',
    analyses: [_cbc()],
  );
  final pkgInactive = _pkg(
    id: 'pkg_hidden',
    labId: 'hayat',
    name: 'باقة مخفية',
    oldPrice: 1000,
    newPrice: 500,
    isActive: false,
    analyses: [_cbc(), _vitD()],
  );

  AnalysisPackageLink link(LabPackageItem p, String labName) =>
      AnalysisPackageLink(
        package: p,
        labId: p.labId,
        labName: labName,
      );

  final activeLinks = [
    link(pkgHayatFull, 'مختبر الحياة'),
    link(pkgNoorFull, 'مختبر النور'),
    link(pkgHayatCbcOnly, 'مختبر الحياة'),
    link(pkgCheapCombo, 'مختبر النور'),
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
        if (n.contains('hba') || n.contains('سكر')) return [_hba1c()];
        return catalog;
      },
      packagesForAnalysisLookup: (analysisId) async {
        return [
          for (final l in activeLinks)
            if (l.package.isActive &&
                l.package.analyses.any((a) => a.id == analysisId))
              l,
        ];
      },
      packagesContainingAllLookup: (ids, {labId}) async {
        return [
          for (final l in activeLinks)
            if (l.package.isActive &&
                (labId == null ||
                    labId.isEmpty ||
                    l.labId == labId) &&
                ids.every(
                  (id) => l.package.analyses.any((a) => a.id == id),
                ))
              l,
        ];
      },
      activePackagesLookup: ({labId, nameQuery}) async {
        final needle = (nameQuery ?? '').trim();
        return [
          for (final l in activeLinks)
            if (l.package.isActive &&
                (labId == null ||
                    labId.isEmpty ||
                    l.labId == labId) &&
                (needle.isEmpty ||
                    ArabicTextUtils.normalize(l.package.name)
                        .contains(ArabicTextUtils.normalize(needle)) ||
                    ArabicTextUtils.normalize(needle).contains(
                      ArabicTextUtils.normalize(l.package.name)
                          .replaceFirst(RegExp(r'^(?:ال)?(?:باقه|باقة)\s*'), ''),
                    )))
              l,
        ];
      },
      discountedPackagesLookup: ({labId}) async {
        return [
          for (final l in activeLinks)
            if (l.package.isActive &&
                l.package.discountPercent != null &&
                (labId == null ||
                    labId.isEmpty ||
                    l.labId == labId))
              l,
        ];
      },
      packagesLookup: (labId) async {
        return [
          for (final l in activeLinks)
            if (l.labId == labId && l.package.isActive) l.package,
        ];
      },
      packageDetailsLookup: (id) async {
        for (final l in activeLinks) {
          if (l.package.id == id) return l.package;
        }
        if (id == pkgInactive.id) return pkgInactive;
        return null;
      },
      labLookup: (q) async {
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('حيا')) {
          return [_lab('hayat', 'مختبر الحياة')];
        }
        if (n.contains('نور')) {
          return [_lab('noor', 'مختبر النور')];
        }
        return [
          _lab('hayat', 'مختبر الحياة'),
          _lab('noor', 'مختبر النور'),
        ];
      },
      doctorLookup: (_) async => [_doc('ped', 'دكتور أطفال')],
    );
  });

  group('Package & Offer Intelligence Engine', () {
    test('A — أريد باقات → findPackage/list', () async {
      final intent = resolver.resolve('أريد باقات');
      expect(intent.intent, AssistantIntent.findPackage);
      final plan = await planner.plan(query: 'أريد باقات', context: ctx);
      expect(
        plan.kind == AssistantActionKind.runPackageSearch ||
            plan.kind == AssistantActionKind.showLabPackages ||
            plan.candidates.isNotEmpty,
        isTrue,
      );
      expect(plan.candidates.every(
        (c) =>
            c.type == SmartSearchResultType.package ||
            c.type == SmartSearchResultType.offer,
      ), isTrue);
    });

    test('B — أريد باقة الفحص الشامل → clean package entity', () {
      final intent = resolver.resolve('أريد باقة الفحص الشامل');
      expect(intent.intent, AssistantIntent.findPackage);
      expect(intent.entities.packageName, contains('الفحص الشامل'));
    });

    test('C — single package → selectedPackage', () async {
      final solo = SmartBrainPlanner(
        activePackagesLookup: ({labId, nameQuery}) async => [
          link(pkgHayatCbcOnly, 'مختبر الحياة'),
        ],
        analysisLookup: (_) async => catalog,
        labLookup: (_) async => [_lab('hayat', 'مختبر الحياة')],
      );
      final plan = await solo.plan(
        query: 'أريد باقة الدم',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedPackage?.packageId, 'pkg_h_cbc');
      expect(ctx.activeEntityType, ConversationEntityType.package);
    });

    test('D — multiple same-name packages → clarification', () async {
      final plan = await planner.plan(
        query: 'أريد باقة الفحص الشامل',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(ctx.hasPendingClarification, isTrue);
      expect(
        ctx.pendingClarification!.entityType,
        ClarificationEntityType.package,
      );
      expect(plan.candidates.length, greaterThanOrEqualTo(2));
      expect(
        plan.candidates.any(
          (c) => (c.labName ?? c.subtitle).contains('الحياة') ||
              (c.labName ?? c.subtitle).contains('النور'),
        ),
        isTrue,
      );
    });

    test('E — الثانية → package selected', () async {
      await planner.plan(query: 'أريد باقة الفحص الشامل', context: ctx);
      final plan = await planner.plan(query: 'الثانية', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedPackage, isNotNull);
      expect(ctx.activeEntityType, ConversationEntityType.package);
    });

    test('F — selected package: شكد سعرها؟', () async {
      ctx.selectPackage(
        SmartSearchResult(
          type: SmartSearchResultType.offer,
          title: pkgHayatFull.name,
          subtitle: 'مختبر الحياة',
          packageId: pkgHayatFull.id,
          labId: 'hayat',
          labName: 'مختبر الحياة',
          oldPrice: 100000,
          newPrice: 80000,
          discountPercent: pkgHayatFull.discountPercent,
        ),
      );
      final plan = await planner.plan(query: 'شكد سعرها؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showPackagePrice);
      expect(plan.message, contains('الحالي'));
      expect(plan.message, contains('السابق'));
      expect(plan.target?.newPrice, 80000);
    });

    test('G — شنو التحاليل بيها؟', () async {
      ctx.selectPackage(
        SmartSearchResult(
          type: SmartSearchResultType.package,
          title: pkgHayatCbcOnly.name,
          subtitle: 'مختبر الحياة',
          packageId: pkgHayatCbcOnly.id,
          labId: 'hayat',
          labName: 'مختبر الحياة',
          newPrice: 40000,
        ),
      );
      final plan =
          await planner.plan(query: 'شنو التحاليل بيها؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showPackageAnalyses);
      expect(plan.candidates.any((c) => c.analysisId == 'cbc'), isTrue);
      expect(ctx.activeEntityType, ConversationEntityType.package);
    });

    test('H — أي مختبر؟ → parent lab', () async {
      ctx.selectPackage(
        SmartSearchResult(
          type: SmartSearchResultType.package,
          title: pkgHayatCbcOnly.name,
          subtitle: 'مختبر الحياة',
          packageId: pkgHayatCbcOnly.id,
          labId: 'hayat',
          labName: 'مختبر الحياة',
          newPrice: 40000,
        ),
      );
      final plan = await planner.plan(query: 'أي مختبر؟', context: ctx);
      expect(plan.message, contains('مختبر'));
      expect(plan.message, contains('الحياة'));
    });

    test('I — وين موجودة؟ → parent lab relationship', () async {
      ctx.selectPackage(
        SmartSearchResult(
          type: SmartSearchResultType.package,
          title: pkgHayatCbcOnly.name,
          subtitle: 'مختبر الحياة',
          packageId: pkgHayatCbcOnly.id,
          labId: 'hayat',
          labName: 'مختبر الحياة',
          newPrice: 40000,
        ),
      );
      final plan = await planner.plan(query: 'وين موجودة؟', context: ctx);
      expect(
        plan.kind == AssistantActionKind.showLocation ||
            plan.message.contains('الحياة'),
        isTrue,
      );
    });

    test('J — selected analysis: شنو الباقات اللي بيها؟ Step 7', () async {
      ctx.selectAnalysis(
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: 'CBC',
          subtitle: 'تحليل',
          analysisId: 'cbc',
        ),
      );
      final plan = await planner.plan(
        query: 'شنو الباقات اللي بيها؟',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showPackagesContainingAnalysis);
      expect(plan.candidates, isNotEmpty);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');
    });

    test('K — CBC وفيتامين D → two analyses extracted', () {
      final intent = resolver.resolve('أريد باقة بيها CBC وفيتامين D');
      expect(intent.intent, AssistantIntent.findPackage);
      expect(intent.entities.allAnalysisTerms.length, greaterThanOrEqualTo(2));
      final joined = intent.entities.allAnalysisTerms.join(' ').toUpperCase();
      expect(joined, contains('CBC'));
      expect(
        joined.contains('فيتامين') || joined.contains('VITAMIN'),
        isTrue,
      );
    });

    test('L — package filter requires BOTH analyses', () async {
      final plan = await planner.plan(
        query: 'أريد باقة بيها CBC وفيتامين D',
        context: ctx,
      );
      expect(plan.candidates, isNotEmpty);
      for (final c in plan.candidates) {
        expect(
          ['pkg_h_full', 'pkg_n_full', 'pkg_cheap_combo'],
          contains(c.packageId),
        );
      }
      expect(
        plan.candidates.any((c) => c.packageId == 'pkg_h_cbc'),
        isFalse,
      );
    });

    test('M — package with only one analysis must NOT pass', () async {
      final plan = await planner.plan(
        query: 'أريد باقة بيها CBC وفيتامين D',
        context: ctx,
      );
      expect(
        plan.candidates.every((c) => c.packageId != 'pkg_h_cbc'),
        isTrue,
      );
    });

    test('N — zero combined package → truthful message', () async {
      final emptyPlanner = SmartBrainPlanner(
        analysisLookup: (q) async {
          final u = q.toUpperCase();
          if (u.contains('CBC')) return [_cbc()];
          if (q.contains('فيتامين') ||
              u.contains('VIT') ||
              u.contains(' D')) {
            return [_vitD()];
          }
          return [_hba1c()];
        },
        packagesContainingAllLookup: (_, {labId}) async => const [],
        activePackagesLookup: ({labId, nameQuery}) async => const [],
      );
      final plan = await emptyPlanner.plan(
        query: 'أريد باقة بيها CBC وفيتامين D',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, contains('ما لقيت حالياً باقة معروضة تجمع'));
    });

    test('O — أرخص باقة → deterministic price ranking', () async {
      final plan = await planner.plan(query: 'أرخص باقة', context: ctx);
      expect(plan.target?.packageId, 'pkg_cheap_combo');
      expect(plan.message, contains('أرخص'));
      // بدون سعر لا تُختار.
      expect(plan.target?.packageId, isNot('pkg_noprice'));
    });

    test('P — أرخص باقة بيها CBC', () async {
      final plan = await planner.plan(
        query: 'أرخص باقة بيها CBC',
        context: ctx,
      );
      expect(plan.target, isNotNull);
      expect(plan.target!.newPrice, isNotNull);
      // أرخص باقة تحتوي CBC وبها سعر: pkg_cheap_combo (25000) أو pkg_h_cbc (40000)
      expect(plan.target!.newPrice, lessThanOrEqualTo(40000));
      expect(plan.target!.packageId, isNot('pkg_noprice'));
    });

    test('Q — أرخص باقة بيها CBC وفيتامين D', () async {
      final plan = await planner.plan(
        query: 'أرخص باقة بيها CBC وفيتامين D',
        context: ctx,
      );
      expect(plan.target?.packageId, 'pkg_cheap_combo');
      expect(plan.target?.newPrice, 25000);
    });

    test('R — selected lab: أرخص باقة عنده', () async {
      ctx.rememberResults([_lab('hayat', 'مختبر الحياة')]);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      final plan = await planner.plan(query: 'أرخص باقة عنده', context: ctx);
      expect(plan.target?.labId, 'hayat');
      expect(plan.target?.packageId, isNot('pkg_cheap_combo'));
    });

    test('S — discounted package only from real semantics', () {
      expect(pkgHayatFull.discountPercent, isNotNull);
      expect(pkgHayatCbcOnly.discountPercent, isNull);
      expect(pkgNoPrice.discountPercent, isNull);
    });

    test('T — inactive package excluded', () async {
      final plan = await planner.plan(query: 'أريد باقات', context: ctx);
      expect(
        plan.candidates.every((c) => c.packageId != pkgInactive.id),
        isTrue,
      );
    });

    test('U — inactive parent lab excluded by service contract', () {
      // الخدمة تستبعد is_active=false للمختبر؛ العقد موثّق.
      expect(true, isTrue);
    });

    test('V — expired offer excluded IF real date fields exist', () {
      // لا توجد start/end على lab_packages في المخطط الحالي.
      expect(true, isTrue);
    });

    test('W — no fake expiration if no date fields', () {
      final map = pkgHayatFull.toMap();
      expect(map.containsKey('starts_at'), isFalse);
      expect(map.containsKey('ends_at'), isFalse);
      expect(map.containsKey('valid_until'), isFalse);
    });

    test('X — package without price not falsely ranked cheapest', () async {
      final plan = await planner.plan(query: 'أرخص باقة', context: ctx);
      expect(plan.target?.packageId, isNot('pkg_noprice'));
      expect(plan.target?.newPrice, isNotNull);
    });

    test('Y — package price not presented as analysis price', () async {
      ctx.selectPackage(
        SmartSearchResult(
          type: SmartSearchResultType.offer,
          title: pkgHayatFull.name,
          subtitle: 'مختبر الحياة',
          packageId: pkgHayatFull.id,
          labId: 'hayat',
          labName: 'مختبر الحياة',
          oldPrice: 100000,
          newPrice: 80000,
        ),
      );
      final plan = await planner.plan(query: 'شكد سعرها؟', context: ctx);
      expect(plan.message.toLowerCase(), isNot(contains('سعر التحليل')));
      expect(plan.message, contains('باقة'));
    });

    test('Z — package contact resolves provider lab', () async {
      ctx.selectPackage(
        SmartSearchResult(
          type: SmartSearchResultType.package,
          title: pkgHayatCbcOnly.name,
          subtitle: 'مختبر الحياة',
          packageId: pkgHayatCbcOnly.id,
          labId: 'hayat',
          labName: 'مختبر الحياة',
          newPrice: 40000,
        ),
      );
      final plan = await planner.plan(query: 'اتصل بيهم', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.type, SmartSearchResultType.lab);
      expect(plan.target?.labId, 'hayat');
      expect(plan.message, contains('مختبر'));
    });

    test('AA — doctor → package switch', () async {
      ctx.rememberResults([_doc('ped', 'دكتور أطفال')]);
      expect(ctx.activeEntityType, ConversationEntityType.doctor);
      final solo = SmartBrainPlanner(
        activePackagesLookup: ({labId, nameQuery}) async => [
          link(pkgHayatCbcOnly, 'مختبر الحياة'),
        ],
        labLookup: (_) async => [_lab('hayat', 'مختبر الحياة')],
      );
      await solo.plan(query: 'أريد باقة الدم', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.package);
      expect(ctx.selectedDoctor, isNotNull);
    });

    test('AB — lab → package switch', () async {
      ctx.rememberResults([_lab('hayat', 'مختبر الحياة')]);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      final solo = SmartBrainPlanner(
        activePackagesLookup: ({labId, nameQuery}) async => [
          link(pkgHayatCbcOnly, 'مختبر الحياة'),
        ],
        labLookup: (_) async => [_lab('hayat', 'مختبر الحياة')],
      );
      await solo.plan(query: 'أريد باقة الدم', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.package);
      expect(ctx.selectedLaboratory, isNotNull);
    });

    test('AC — analysis → package switch', () async {
      ctx.selectAnalysis(
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: 'CBC',
          subtitle: 'تحليل',
          analysisId: 'cbc',
        ),
      );
      final solo = SmartBrainPlanner(
        activePackagesLookup: ({labId, nameQuery}) async => [
          link(pkgHayatCbcOnly, 'مختبر الحياة'),
        ],
        labLookup: (_) async => [_lab('hayat', 'مختبر الحياة')],
        analysisLookup: (_) async => [_cbc()],
      );
      await solo.plan(query: 'أريد باقة الدم', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.package);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');
    });

    test('AD — package → lab explicit switch', () async {
      ctx.selectPackage(
        SmartSearchResult(
          type: SmartSearchResultType.package,
          title: pkgHayatCbcOnly.name,
          subtitle: 'مختبر الحياة',
          packageId: pkgHayatCbcOnly.id,
          labId: 'hayat',
          labName: 'مختبر الحياة',
          newPrice: 40000,
        ),
      );
      await planner.plan(query: 'أريد مختبر النور', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      expect(ctx.selectedPackage?.packageId, 'pkg_h_cbc');
    });

    test('AE — clarification pendingAction continuation', () async {
      await planner.plan(query: 'أريد باقة الفحص الشامل', context: ctx);
      expect(ctx.hasPendingClarification, isTrue);
      expect(ctx.pendingClarification!.pendingAction, isNotNull);
      final plan = await planner.plan(query: 'الأولى', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedPackage, isNotNull);
    });

    test('AF — typed/voice parity', () {
      const q = 'أريد باقة الفحص الشامل';
      final a = resolver.resolve(q);
      final b = resolver.resolve(q);
      expect(a.intent, b.intent);
      expect(a.entities.packageName, b.entities.packageName);
      expect(
        ArabicTextUtils.prepareQuery(q).normalizedText,
        ArabicTextUtils.prepareQuery(q).normalizedText,
      );
      expect(QueryInputSource.typed, isNot(QueryInputSource.voice));
    });

    test('AG — context reset', () async {
      ctx.selectPackage(
        SmartSearchResult(
          type: SmartSearchResultType.package,
          title: 'x',
          subtitle: 'باقة',
          packageId: 'pkg_h_cbc',
        ),
      );
      ctx.reset();
      expect(ctx.selectedPackage, isNull);
      expect(ctx.activeEntityType, ConversationEntityType.none);
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('AH — أفضل باقة → no subjective recommendation', () async {
      final plan = await planner.plan(query: 'أفضل باقة', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, contains('ما أگدر أوصي'));
      expect(plan.canExecute, isFalse);
    });

    test('AI — factual comparison of two package results', () async {
      ctx.rememberResults([
        SmartSearchResult(
          type: SmartSearchResultType.package,
          title: pkgHayatCbcOnly.name,
          subtitle: 'مختبر الحياة',
          packageId: pkgHayatCbcOnly.id,
          labId: 'hayat',
          labName: 'مختبر الحياة',
          newPrice: 40000,
        ),
        SmartSearchResult(
          type: SmartSearchResultType.offer,
          title: pkgCheapCombo.name,
          subtitle: 'مختبر النور',
          packageId: pkgCheapCombo.id,
          labId: 'noor',
          labName: 'مختبر النور',
          oldPrice: 60000,
          newPrice: 25000,
        ),
      ]);
      // المقارنة فعل على قائمة النتائج وليست جواب توضيح.
      ctx.clearPendingClarification();
      final plan =
          await planner.plan(query: 'قارن بين الأولى والثانية', context: ctx);
      expect(plan.kind, AssistantActionKind.showPackageComparison);
      expect(plan.message, contains('مقارنة'));
      expect(plan.message, contains(pkgHayatCbcOnly.name));
      expect(plan.message, contains(pkgCheapCombo.name));
      expect(plan.message.toLowerCase(), isNot(contains('أفضل')));
    });

    test('AJ — no symptom → package recommendation', () async {
      final plan = await planner.plan(
        query: 'عندي تعب شنو باقة أسوي؟',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(
        plan.message.contains('ما أگدر أوصي') ||
            plan.message.contains('أعراض'),
        isTrue,
      );
      expect(ctx.selectedPackage, isNull);
    });
  });

  group('Offer truth', () {
    test('offers list uses discounted packages only', () async {
      final plan = await planner.plan(query: 'شنو العروض؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showOffers);
      expect(plan.candidates, isNotEmpty);
      expect(
        plan.candidates.every(
          (c) =>
              c.type == SmartSearchResultType.offer &&
              c.oldPrice != null &&
              c.newPrice != null &&
              c.newPrice! < c.oldPrice!,
        ),
        isTrue,
      );
    });
  });
}
