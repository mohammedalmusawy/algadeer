import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

SmartSearchResult _lab(
  String id,
  String title, {
  String? location,
  String? phone,
  String? whatsapp,
  int score = 90,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.lab,
    title: title,
    subtitle: location ?? 'بغداد',
    labId: id,
    score: score,
    clinicLocation: location ?? 'بغداد',
    phone: phone,
    whatsapp: whatsapp,
    labName: title,
  );
}

SmartSearchResult _doc(String id, String title) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: 'أطفال',
    doctorId: id,
    score: 90,
    specialty: 'أطفال',
    clinicLocation: 'الكرادة',
    phone: '07701111111',
    whatsapp: '07701111111',
  );
}

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late RuleBasedIntentResolver resolver;

  final hayat = _lab(
    'hayat',
    'مختبر الحياة',
    location: 'المنصور',
    phone: '07701234567',
    whatsapp: '07701234567',
  );
  final noorA = _lab(
    'noor_a',
    'مختبر النور',
    location: 'الكرادة',
    phone: '07702222222',
    whatsapp: '07702222222',
  );
  final noorB = _lab(
    'noor_b',
    'مختبر النور المركزي',
    location: 'الحارثية',
    phone: '07703333333',
    whatsapp: '07703333333',
  );
  final silent = _lab(
    'silent',
    'مختبر الصمت',
    location: 'بغداد',
  );

  final packages = [
    LabPackageItem(
      id: 'pkg1',
      labId: 'hayat',
      name: 'باقة الفحص الشامل',
      description: 'فحوصات أساسية',
      oldPrice: 100000,
      newPrice: 75000,
      analyses: const [
        AnalysisItem(id: 'a1', name: 'CBC', nameAr: 'تعداد الدم'),
        AnalysisItem(id: 'a2', name: 'Glucose', nameAr: 'السكر'),
      ],
    ),
    LabPackageItem(
      id: 'pkg2',
      labId: 'hayat',
      name: 'باقة الفيتامينات',
      newPrice: 50000,
      analyses: const [
        AnalysisItem(id: 'a3', name: 'Vit D', nameAr: 'فيتامين د'),
      ],
    ),
  ];

  setUp(() {
    ctx = ConversationContext();
    resolver = RuleBasedIntentResolver();
    planner = SmartBrainPlanner(
      labLookup: (q) async {
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('حيا')) return [hayat];
        if (n.contains('نور')) return [noorA, noorB];
        if (n.contains('صمت')) return [silent];
        if (n == 'مختبر' || n.isEmpty || n.contains('مختبر')) {
          return [hayat, noorA, noorB, silent];
        }
        return const [];
      },
      packagesLookup: (labId) async {
        if (labId == 'hayat') return packages;
        return const [];
      },
      doctorLookup: (q) async {
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('اطفال') || n.contains('أطفال')) {
          return [_doc('ped', 'دكتور أطفال')];
        }
        return const [];
      },
    );
  });

  group('Laboratory Intelligence Engine', () {
    test('A — أريد مختبر → findLab', () {
      final intent = resolver.resolve('أريد مختبر');
      expect(intent.intent, AssistantIntent.findLab);
    });

    test('B — أريد مختبر الحياة → extract clean name', () {
      final intent = resolver.resolve('أريد مختبر الحياة');
      expect(intent.intent, AssistantIntent.findLab);
      // ArabicTextUtils.normalize يحوّل ة→ه بأمان
      expect(intent.entities.laboratory, 'الحياه');
    });

    test('C — single lab auto-select', () async {
      final plan = await planner.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(ctx.selectedLaboratory?.labId, 'hayat');
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      expect(ctx.hasPendingClarification, isFalse);
      expect(
        plan.kind == AssistantActionKind.selectEntity ||
            plan.target?.labId == 'hayat',
        isTrue,
      );
    });

    test('D — context location for selected lab', () async {
      ctx.rememberResults([hayat], query: 'مختبر الحياة');
      expect(ctx.selectedLaboratory?.labId, 'hayat');
      final plan = await planner.plan(query: 'وين موقعه؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showLocation);
      expect(plan.target?.labId, 'hayat');
      expect(plan.message, contains('المنصور'));
    });

    test('E — context call for selected lab', () async {
      ctx.rememberResults([hayat], query: 'مختبر الحياة');
      final plan = await planner.plan(query: 'اتصل', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.labId, 'hayat');
      expect(plan.canExecute, isTrue);
    });

    test('F — context WhatsApp for selected lab', () async {
      ctx.rememberResults([hayat], query: 'مختبر الحياة');
      final plan = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.labId, 'hayat');
    });

    test('G — explicit call → matcher gets الحياة', () async {
      final intent = resolver.resolve('اتصل بمختبر الحياة');
      expect(intent.intent, AssistantIntent.callLab);
      expect(intent.entities.laboratory, 'الحياه');
      final plan = await planner.plan(query: 'اتصل بمختبر الحياة', context: ctx);
      expect(planner.lastMatcherQueryForTest, 'الحياه');
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.labId, 'hayat');
    });

    test('H — explicit WhatsApp مختبر الحياة', () async {
      final plan =
          await planner.plan(query: 'واتساب مختبر الحياة', context: ctx);
      expect(
        plan.intentResult.intent == AssistantIntent.messageLab ||
            plan.kind == AssistantActionKind.prepareWhatsApp,
        isTrue,
      );
      expect(plan.target?.labId, 'hayat');
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
    });

    test('I — multiple labs → pendingClarification laboratory', () async {
      final plan = await planner.plan(query: 'اتصل بمختبر النور', context: ctx);
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(ctx.hasPendingClarification, isTrue);
      expect(
        ctx.pendingClarification!.entityType,
        ClarificationEntityType.laboratory,
      );
      expect(ctx.selectedLaboratory, isNull);
      expect(ctx.pendingClarification!.candidates, hasLength(2));
    });

    test('J — lab ordinal الثاني → B', () async {
      ctx.rememberResults([noorA, noorB], query: 'مختبر النور');
      expect(ctx.hasPendingClarification, isTrue);
      final plan = await planner.plan(query: 'الثاني', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedLaboratory?.labId, 'noor_b');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('K — pending action continuation callLab(B)', () async {
      await planner.plan(query: 'اتصل بمختبر النور', context: ctx);
      expect(ctx.hasPendingClarification, isTrue);
      expect(
        ctx.pendingClarification!.pendingAction,
        AssistantIntent.callLab,
      );
      final plan = await planner.plan(query: 'الثاني', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.labId, 'noor_b');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('L — packages from context', () async {
      ctx.rememberResults([hayat], query: 'مختبر الحياة');
      final plan = await planner.plan(query: 'شنو باقاته؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showLabPackages);
      expect(plan.packages, hasLength(2));
      expect(plan.target?.labId, 'hayat');
      expect(plan.message, contains('الحياة'));
    });

    test('M — analyses from context via packages', () async {
      ctx.rememberResults([hayat], query: 'مختبر الحياة');
      final plan =
          await planner.plan(query: 'شنو التحاليل الموجودة؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showLabAnalyses);
      expect(plan.analyses, isNotEmpty);
      expect(plan.message, contains('ضمن باقات'));
    });

    test('N — entity switch doctor → lab → location is lab', () async {
      ctx.rememberResults([_doc('ped', 'دكتور أطفال')], query: 'أريد طبيب أطفال');
      expect(ctx.activeEntityType, ConversationEntityType.doctor);
      expect(ctx.selectedDoctor, isNotNull);

      await planner.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      expect(ctx.selectedLaboratory?.labId, 'hayat');
      expect(ctx.selectedDoctor, isNotNull); // محفوظ

      final plan = await planner.plan(query: 'وين موقعه؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showLocation);
      expect(plan.target?.labId, 'hayat');
      expect(plan.target?.type, SmartSearchResultType.lab);
    });

    test('O — no lab contact data → safe message', () async {
      ctx.rememberResults([silent], query: 'مختبر الصمت');
      final call = await planner.plan(query: 'اتصل', context: ctx);
      expect(call.kind, AssistantActionKind.showMessage);
      expect(call.canExecute, isFalse);
      expect(call.message, contains('غير متوفر'));

      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.showMessage);
      expect(wa.message, contains('واتساب'));
    });

    test('P — new doctor search after lab changes activeEntityType', () async {
      ctx.rememberResults([hayat], query: 'مختبر الحياة');
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);

      final plan = await planner.plan(query: 'أريد طبيب أطفال', context: ctx);
      expect(plan.kind, AssistantActionKind.runSpecialtySearch);
      // beginNewDoctorSearch clears doctor slot; specialty path starts doctor search
      expect(
        ctx.activeEntityType == ConversationEntityType.none ||
            ctx.activeEntityType == ConversationEntityType.doctor,
        isTrue,
      );
      expect(ctx.selectedLaboratory?.labId, 'hayat'); // lab retained
    });

    test('Q — typed/voice parity after prepareQuery', () {
      const typed = 'أريد مختبر الحياة';
      const voice = 'أريد مختبر الحياة';
      final a = resolver.resolve(typed);
      final b = resolver.resolve(voice);
      expect(a.intent, b.intent);
      expect(a.entities.laboratory, b.entities.laboratory);
      expect(a.intent, AssistantIntent.findLab);

      final typedPrepared = ArabicTextUtils.prepareQuery(typed);
      final voicePrepared = ArabicTextUtils.prepareQuery(voice);
      expect(typedPrepared.normalizedText, voicePrepared.normalizedText);
      expect(QueryInputSource.typed != QueryInputSource.voice, isTrue);
    });

    test('R — context reset clears lab clarification/active', () {
      ctx.rememberResults([noorA, noorB], query: 'النور');
      expect(ctx.hasPendingClarification, isTrue);
      ctx.selectLaboratory(hayat);
      expect(ctx.activeEntityType, ConversationEntityType.laboratory);
      ctx.reset();
      expect(ctx.selectedLaboratory, isNull);
      expect(ctx.activeEntityType, ConversationEntityType.none);
      expect(ctx.hasPendingClarification, isFalse);
      expect(ctx.lastLabSnapshot, isEmpty);
    });

    test('S — single lab never creates unnecessary clarification', () async {
      final plan = await planner.plan(query: 'مختبر الحياة', context: ctx);
      expect(ctx.hasPendingClarification, isFalse);
      expect(ctx.selectedLaboratory?.labId, 'hayat');
      expect(plan.kind, isNot(AssistantActionKind.showClarification));
    });

    test('T — invalid lab ordinal keeps clarification active', () async {
      ctx.rememberResults([noorA, noorB], query: 'النور');
      expect(ctx.hasPendingClarification, isTrue);
      final plan = await planner.plan(query: 'الخامس', context: ctx);
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(ctx.hasPendingClarification, isTrue);
      expect(ctx.selectedLaboratory, isNull);
      expect(plan.message, contains('خياران'));
    });
  });
}
