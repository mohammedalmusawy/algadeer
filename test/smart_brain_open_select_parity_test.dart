import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/nlu/nlu_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// رجوع: «افتح الثاني» يفتح كزر التفاصيل؛ «افتح التفاصيل» يستخدم المختار.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final resolver = RuleBasedIntentResolver();

  group('Intent — فتح وترتيب', () {
    test('الثاني = select فقط بلا open', () {
      final r = resolver.resolve('الثاني');
      expect(r.intent, AssistantIntent.selectResult);
      expect(r.entities.actionHint, isNot('open'));
      expect(r.entities.resultIndex, 2);
    });

    test('اختار الثاني = select فقط', () {
      final r = resolver.resolve('اختار الثاني');
      expect(r.intent, AssistantIntent.selectResult);
      expect(r.entities.actionHint, isNot('open'));
    });

    test('افتح الثاني = select + open hint', () {
      final r = resolver.resolve('افتح الثاني');
      expect(r.intent, AssistantIntent.selectResult);
      expect(r.entities.actionHint, 'open');
      expect(r.entities.resultIndex, 2);
    });

    test('افتح التفاصيل = showProfile سياقي', () {
      final r = resolver.resolve('افتح التفاصيل');
      expect(r.intent, AssistantIntent.showProfile);
      expect(r.requiresContext, isTrue);
    });

    test('افتح بطاقته / ورّيني معلوماته = showProfile', () {
      expect(
        resolver.resolve('افتح بطاقته').intent,
        AssistantIntent.showProfile,
      );
      expect(
        resolver.resolve('ورّيني معلوماته').intent,
        AssistantIntent.showProfile,
      );
    });
  });

  group('Planner — أطفال → الثاني → التفاصيل', () {
    late ConversationContext ctx;
    late SmartBrainPlanner planner;
    late List<SmartSearchResult> liveDoctors;

    setUp(() {
      liveDoctors = [
        _doc('a', 'د. أحمد أطفال تجريبي'),
        _doc('b', 'د. صباح مجيد العمري'),
      ];
      ctx = ConversationContext();
      planner = SmartBrainPlanner(
        clinicalEnabled: false,
        nluClient: NluClient.disabled,
        doctorLookup: (q) async {
          if (q.trim().isEmpty) return List.of(liveDoctors);
          final n = ArabicTextUtils.normalize(q);
          return [
            for (final d in liveDoctors)
              if (ArabicTextUtils.normalize(d.title).contains(n) ||
                  ArabicTextUtils.normalize(d.specialty ?? '').contains(n) ||
                  n.contains('اطفال') ||
                  n.contains('أطفال'))
                d,
          ];
        },
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        physioLookup: (_) async => const [],
        supplyLookup: (_) async => const [],
        packagesLookup: (_) async => const [],
        activePackagesLookup: ({labId, nameQuery}) async => const [],
        packagesForAnalysisLookup: (_) async => const [],
        discountedPackagesLookup: ({labId}) async => const [],
      );
    });

    test('افتح الثاني يفتح البطاقة مباشرة', () async {
      ctx.rememberResults(
        liveDoctors,
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      expect(ctx.currentResultContext?.length, 2);
      final classified = planner.classify('افتح الثاني');
      expect(classified.entities.actionHint, 'open');
      final plan = await planner.plan(query: 'افتح الثاني', context: ctx);
      expect(
        plan.kind,
        AssistantActionKind.openProfile,
        reason:
            'hint=${classified.entities.actionHint} planHint=${plan.intentResult.entities.actionHint} '
            'msg=${plan.message} id=${plan.target?.doctorId} '
            'nav=${plan.target?.hasNavigableEntity} type=${plan.target?.type}',
      );
      expect(plan.canExecute, isTrue);
      expect(plan.target?.doctorId, 'b');
      expect(ctx.selectedDoctor?.doctorId, 'b');
    });

    test('الثاني يختار فقط ثم افتح التفاصيل يفتح', () async {
      ctx.rememberResults(
        liveDoctors,
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      final select = await planner.plan(query: 'الثاني', context: ctx);
      expect(select.kind, AssistantActionKind.selectEntity);
      expect(select.target?.doctorId, 'b');
      expect(ctx.selectedDoctor?.doctorId, 'b');

      final open = await planner.plan(query: 'افتح التفاصيل', context: ctx);
      expect(
        open.kind,
        AssistantActionKind.openProfile,
        reason: 'msg=${open.message} id=${open.target?.doctorId} '
            'intent=${open.intentResult.intent}',
      );
      expect(open.canExecute, isTrue);
      expect(open.target?.doctorId, 'b');
      expect(open.message.toLowerCase(), isNot(contains('ما لقيت')));
    });

    test('لا، الأول يصحح الاختيار', () async {
      ctx.rememberResults(
        liveDoctors,
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      await planner.plan(query: 'الثاني', context: ctx);
      final corr = await planner.plan(query: 'لا مو الثاني الأول', context: ctx);
      expect(corr.target?.doctorId, 'a');
      expect(ctx.selectedDoctor?.doctorId, 'a');
    });

    test('إخفاء الطبيب بعد الاختيار يمنع الفتح القديم', () async {
      ctx.rememberResults(
        liveDoctors,
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      await planner.plan(query: 'الثاني', context: ctx);
      liveDoctors = [liveDoctors.first]; // أخفِ الثاني
      final open = await planner.plan(query: 'افتح التفاصيل', context: ctx);
      expect(open.canExecute, isFalse);
      expect(open.kind, isNot(AssistantActionKind.openProfile));
    });

    test('تغيير رقم الهاتف قبل الاتصال يستخدم الحي', () async {
      liveDoctors = [
        _doc('a', 'د. أحمد أطفال تجريبي', phone: '07701111111'),
        _doc('b', 'د. صباح مجيد العمري', phone: '07702222222'),
      ];
      ctx.rememberResults(
        liveDoctors,
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      await planner.plan(query: 'الثاني', context: ctx);
      liveDoctors = [
        liveDoctors.first,
        _doc('b', 'د. صباح مجيد العمري', phone: '07703333333'),
      ];
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.phone, '07703333333');
    });

    test('ورّيني رقمه يعرض ولا يتصل', () async {
      liveDoctors = [
        _doc('a', 'د. أحمد أطفال تجريبي', phone: '07701111111'),
        _doc('b', 'د. صباح مجيد العمري', phone: '07702222222'),
      ];
      ctx.rememberResults(
        liveDoctors,
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      await planner.plan(query: 'الثاني', context: ctx);
      final show = await planner.plan(query: 'وريني رقمه', context: ctx);
      expect(show.kind, AssistantActionKind.showMessage);
      expect(show.message, contains('07702222222'));
      expect(show.kind, isNot(AssistantActionKind.prepareCall));
    });

    test('دورلي طبيب أطفال وافتح الثاني يفتح الثاني', () async {
      final classified = planner.classify('دورلي طبيب أطفال وافتح الثاني');
      expect(classified.intent, AssistantIntent.specialtySearch);
      expect(classified.entities.resultIndex, 2);
      expect(classified.entities.actionHint, 'open');
      final plan = await planner.plan(
        query: 'دورلي طبيب أطفال وافتح الثاني',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.openProfile);
      expect(plan.target?.doctorId, 'b');
    });

    test('مسح السياق يزيل الاختيار السابق', () {
      ctx.rememberResults(
        liveDoctors,
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      ctx.selectDoctor(liveDoctors[1]);
      expect(ctx.selectedDoctor?.doctorId, 'b');
      ctx.reset();
      expect(ctx.selectedDoctor, isNull);
      expect(ctx.currentResultContext, isNull);
    });

    test('نتائج أطفال ثم شنو دوامه بلا مختار يطلب أي طبيب ويُبقي النتائج',
        () async {
      ctx.rememberResults(
        liveDoctors,
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await planner.plan(query: 'شنو دوامه', context: ctx);
      expect(plan.intentResult.intent, AssistantIntent.doctorAvailability);
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(plan.message.contains('تقصد أي طبيب'), isTrue);
      expect(ctx.currentResultContext?.items.length, 2);
      expect(ctx.selectedDoctor, isNull);
      expect(ctx.pendingClarification, isNotNull);

      final pick = await planner.plan(query: 'الأول', context: ctx);
      expect(pick.target?.doctorId, 'a');
      expect(
        pick.message.contains('دوام') ||
            pick.message.contains('معلومة مؤكدة'),
        isTrue,
        reason: pick.message,
      );
      expect(ctx.currentResultContext?.items.length, 2);
    });
  });
}

SmartSearchResult _doc(
  String id,
  String title, {
  String phone = '07001234567',
  String workingHours = 'السبت: مساءً',
  String workingDays = 'السبت، الأحد',
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: 'طب الأطفال',
    specialty: 'طب الأطفال',
    doctorId: id,
    phone: phone,
    whatsapp: phone,
    clinicLocation: 'الشطرة',
    workingHours: workingHours,
    workingDays: workingDays,
    score: 90,
  );
}
