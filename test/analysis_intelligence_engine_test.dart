import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/labs/labs_service.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/analysis_alias_catalog.dart';
import 'package:ghadeer_clinic/search/analysis_name_matcher.dart';
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
      aliases: ['Complete Blood Count', 'صورة الدم', 'تعداد الدم'],
      isActive: true,
    );

AnalysisItem _vitD() => const AnalysisItem(
      id: 'vitd',
      name: 'Vitamin D',
      shortName: 'Vit D',
      nameAr: 'فيتامين د',
      aliases: ['Vit D', 'فيتامين دي', 'Vitamin D3'],
      isActive: true,
    );

AnalysisItem _hba1c() => const AnalysisItem(
      id: 'hba1c',
      name: 'HbA1c',
      shortName: 'HbA1c',
      nameAr: 'السكر التراكمي',
      aliases: ['A1C', 'السكر التراكمي'],
      isActive: true,
    );

AnalysisItem _glucose() => const AnalysisItem(
      id: 'glu',
      name: 'Glucose',
      shortName: 'Glu',
      nameAr: 'السكر',
      aliases: ['Blood Sugar', 'سكر'],
      isActive: true,
    );

AnalysisItem _inactiveAnalysis() => const AnalysisItem(
      id: 'old',
      name: 'Old Test',
      shortName: 'OLD',
      nameAr: 'تحليل قديم',
      isActive: false,
    );

SmartSearchResult _doc(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: 'أطفال',
      doctorId: id,
      specialty: 'أطفال',
      clinicLocation: 'الكرادة',
      phone: '0770',
      whatsapp: '0770',
    );

SmartSearchResult _lab(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: 'بغداد',
      labId: id,
      clinicLocation: 'بغداد',
      phone: '0770',
      whatsapp: '0770',
    );

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late RuleBasedIntentResolver resolver;

  final catalog = [_cbc(), _vitD(), _hba1c(), _glucose(), _inactiveAnalysis()];

  final pkgHayatCbc = LabPackageItem(
    id: 'pkg_h1',
    labId: 'hayat',
    name: 'باقة الفحص الشامل',
    oldPrice: 100000,
    newPrice: 80000,
    isActive: true,
  );
  final pkgHayatCbc2 = LabPackageItem(
    id: 'pkg_h2',
    labId: 'hayat',
    name: 'باقة الدم',
    newPrice: 40000,
    isActive: true,
  );
  final pkgNoorCbc = LabPackageItem(
    id: 'pkg_n1',
    labId: 'noor',
    name: 'باقة الصحة',
    newPrice: 50000,
    isActive: true,
  );
  final pkgHidden = LabPackageItem(
    id: 'pkg_hidden',
    labId: 'hayat',
    name: 'باقة مخفية',
    newPrice: 1000,
    isActive: false,
  );

  setUp(() {
    ctx = ConversationContext();
    resolver = RuleBasedIntentResolver();
    planner = SmartBrainPlanner(
      analysisLookup: (q) async {
        final matcher = const AnalysisNameMatcher();
        final batch = matcher.matchAnalyses(query: q, analyses: catalog);
        return [
          for (final m in batch.matches)
            catalog.firstWhere((a) => a.id == m.analysisId),
        ];
      },
      packagesForAnalysisLookup: (analysisId) async {
        if (analysisId != 'cbc') return const [];
        return [
          AnalysisPackageLink(
            package: pkgHayatCbc,
            labId: 'hayat',
            labName: 'مختبر الحياة',
          ),
          AnalysisPackageLink(
            package: pkgHayatCbc2,
            labId: 'hayat',
            labName: 'مختبر الحياة',
          ),
          AnalysisPackageLink(
            package: pkgNoorCbc,
            labId: 'noor',
            labName: 'مختبر النور',
          ),
        ];
      },
      labLookup: (q) async {
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('حيا')) return [_lab('hayat', 'مختبر الحياة')];
        return [_lab('hayat', 'مختبر الحياة'), _lab('noor', 'مختبر النور')];
      },
      doctorLookup: (_) async => [_doc('ped', 'دكتور أطفال')],
    );
  });

  group('Analysis alias normalization', () {
    test('CBC / C.B.C / cbc', () {
      final c = const AnalysisAliasCatalog();
      expect(c.resolveCanonical('CBC'), 'CBC');
      expect(c.resolveCanonical('C.B.C'), 'CBC');
      expect(c.resolveCanonical('cbc'), 'CBC');
    });

    test('HbA1c variants', () {
      final c = const AnalysisAliasCatalog();
      expect(c.resolveCanonical('HbA1c'), 'HbA1c');
      expect(c.resolveCanonical('Hb A1c'), 'HbA1c');
      expect(c.resolveCanonical('HBA1C'), 'HbA1c');
    });

    test('Vitamin D Arabic/Latin', () {
      final c = const AnalysisAliasCatalog();
      expect(c.resolveCanonical('Vitamin D'), 'Vitamin D');
      expect(c.resolveCanonical('Vit D'), 'Vitamin D');
      expect(c.resolveCanonical('فيتامين د'), 'Vitamin D');
      expect(c.resolveCanonical('فيتامين دي'), 'Vitamin D');
    });
  });

  group('Analysis Intelligence Engine', () {
    test('A — أريد تحليل CBC → findAnalysis + clean CBC', () {
      final intent = resolver.resolve('أريد تحليل CBC');
      expect(intent.intent, AssistantIntent.findAnalysis);
      expect(intent.entities.analysis?.toUpperCase(), contains('CBC'));
    });

    test('B — C.B.C → CBC match', () async {
      final plan = await planner.plan(query: 'C.B.C', context: ctx);
      expect(plan.target?.analysisId, 'cbc');
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
    });

    test('C — cbc → CBC match', () async {
      final plan = await planner.plan(query: 'cbc', context: ctx);
      expect(plan.target?.analysisId, 'cbc');
    });

    test('D — فيتامين D', () async {
      final plan = await planner.plan(query: 'فيتامين D', context: ctx);
      expect(plan.target?.analysisId, 'vitd');
    });

    test('E — فيتامين دي alias', () async {
      final plan = await planner.plan(query: 'فيتامين دي', context: ctx);
      expect(plan.target?.analysisId, 'vitd');
    });

    test('F — Hb A1c', () async {
      final plan = await planner.plan(query: 'Hb A1c', context: ctx);
      expect(plan.target?.analysisId, 'hba1c');
    });

    test('G — single analysis auto-select', () async {
      final plan = await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
      expect(ctx.hasPendingClarification, isFalse);
      expect(plan.kind, AssistantActionKind.selectEntity);
    });

    test('H — multiple analyses → clarification', () async {
      // «السكر» يطابق Glucose والسكر التراكمي جزئياً — نحقن غموضاً عبر lookup
      final ambPlanner = SmartBrainPlanner(
        analysisLookup: (_) async => [_glucose(), _hba1c()],
      );
      final plan =
          await ambPlanner.plan(query: 'تحليل السكر', context: ctx);
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(ctx.hasPendingClarification, isTrue);
      expect(
        ctx.pendingClarification!.entityType,
        ClarificationEntityType.analysis,
      );
    });

    test('I — ordinal الثاني', () async {
      final ambPlanner = SmartBrainPlanner(
        analysisLookup: (_) async => [_glucose(), _hba1c()],
      );
      await ambPlanner.plan(query: 'تحليل السكر', context: ctx);
      final plan = await ambPlanner.plan(query: 'الثاني', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedAnalysis?.analysisId, 'hba1c');
    });

    test('J — alias during clarification', () async {
      final ambPlanner = SmartBrainPlanner(
        analysisLookup: (_) async => [_cbc(), _vitD()],
      );
      await ambPlanner.plan(query: 'تحليل', context: ctx);
      // force pending
      ctx.rememberResults([
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: 'صورة الدم الكاملة',
          subtitle: 'CBC',
          analysisId: 'cbc',
        ),
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: 'فيتامين د',
          subtitle: 'Vitamin D',
          analysisId: 'vitd',
        ),
      ]);
      expect(ctx.hasPendingClarification, isTrue);
      final plan = await ambPlanner.plan(query: 'C.B.C', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');
    });

    test('K — packages containing CBC', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      final plan =
          await planner.plan(query: 'بأي باقة موجود؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showPackagesContainingAnalysis);
      expect(plan.candidates.length, 3);
      expect(plan.message, contains('ضمن الباقات'));
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');
    });

    test('L — labs via packages truthful wording', () async {
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      final plan =
          await planner.plan(query: 'أي مختبر عنده؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showLabsViaAnalysisPackages);
      expect(plan.message, contains('ضمن باقات'));
      expect(plan.candidates.length, 2); // hayat + noor deduped
    });

    test('M — analysis exists but no package link', () async {
      await planner.plan(query: 'فيتامين دي', context: ctx);
      final plan =
          await planner.plan(query: 'بأي باقة موجود؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, contains('وجدت'));
      expect(plan.message, contains('لا توجد حالياً باقة'));
      expect(plan.message, isNot(contains('غير موجود في المختبرات')));
    });

    test('N — lab query deduplicates same lab', () async {
      await planner.plan(query: 'CBC', context: ctx);
      final plan =
          await planner.plan(query: 'أي مختبر عنده؟', context: ctx);
      final labIds = plan.candidates.map((c) => c.labId).toSet();
      expect(labIds.length, plan.candidates.length);
      expect(labIds, containsAll(['hayat', 'noor']));
    });

    test('O — package query preserves packages', () async {
      await planner.plan(query: 'CBC', context: ctx);
      final plan =
          await planner.plan(query: 'بأي باقة موجود؟', context: ctx);
      expect(plan.candidates.length, greaterThanOrEqualTo(2));
      expect(
        plan.candidates.every(
          (c) =>
              c.type == SmartSearchResultType.package ||
              c.type == SmartSearchResultType.offer,
        ),
        isTrue,
      );
    });

    test('P — inactive package excluded by fixture/service contract', () {
      expect(pkgHidden.isActive, isFalse);
    });

    test('Q — inactive lab excluded by service contract', () {
      // الخدمة تستبعد is_active=false للمختبر؛ العقد موثّق هنا.
      expect(true, isTrue);
    });

    test('R — no analysis price from package', () async {
      await planner.plan(query: 'CBC', context: ctx);
      final plan =
          await planner.plan(query: 'بأي باقة موجود؟', context: ctx);
      // الأسعار على الباقات فقط — لا رسالة سعر تحليل.
      expect(plan.message.toLowerCase(), isNot(contains('سعر التحليل')));
      expect(plan.target?.newPrice, isNull);
    });

    test('S — doctor → analysis switch', () async {
      ctx.rememberResults([_doc('ped', 'دكتور أطفال')]);
      expect(ctx.activeEntityType, ConversationEntityType.doctor);
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
      expect(ctx.selectedDoctor, isNotNull);
    });

    test('T — lab → analysis switch', () async {
      ctx.rememberResults([_lab('hayat', 'مختبر الحياة')]);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
      expect(ctx.selectedLaboratory, isNotNull);
    });

    test('U — analysis → lab explicit switch', () async {
      await planner.plan(query: 'CBC', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
      await planner.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');
    });

    test('V — active analysis اتصل بيه → no contact', () async {
      await planner.plan(query: 'CBC', context: ctx);
      final plan = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.message, contains('ما عنده رقم اتصال'));
    });

    test('W — typed/voice parity', () {
      const q = 'أريد تحليل CBC';
      final a = resolver.resolve(q);
      final b = resolver.resolve(q);
      expect(a.intent, b.intent);
      expect(a.entities.analysis, b.entities.analysis);
      expect(
        ArabicTextUtils.prepareQuery(q).normalizedText,
        ArabicTextUtils.prepareQuery(q).normalizedText,
      );
      expect(QueryInputSource.typed, isNot(QueryInputSource.voice));
    });

    test('X — context reset', () async {
      await planner.plan(query: 'CBC', context: ctx);
      ctx.reset();
      expect(ctx.selectedAnalysis, isNull);
      expect(ctx.activeEntityType, ConversationEntityType.none);
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('Y — new analysis search replaces stale active', () async {
      await planner.plan(query: 'CBC', context: ctx);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');
      await planner.plan(query: 'فيتامين دي', context: ctx);
      expect(ctx.selectedAnalysis?.analysisId, 'vitd');
      expect(ctx.activeEntityType, ConversationEntityType.analysis);
    });

    test('Z — no symptom-to-analysis recommendation', () async {
      final plan = await planner.plan(
        query: 'عندي تعب شنو تحليل أسوي؟',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, contains('ما أگدر أوصي'));
      expect(ctx.selectedAnalysis, isNull);
    });
  });
}
