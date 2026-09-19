import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

SmartSearchResult _doc(
  String id,
  String title, {
  int score = 90,
  String? location,
  String? phone,
  String? whatsapp,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: 'اختصاص',
    doctorId: id,
    score: score,
    clinicLocation: location,
    phone: phone,
    whatsapp: whatsapp,
  );
}

void main() {
  final resolver = RuleBasedIntentResolver();

  group('RuleBasedIntentResolver Step 4', () {
    test('TEST 1 — أريد طبيب أطفال → specialtySearch', () {
      final r = resolver.resolve('أريد طبيب أطفال');
      expect(r.intent, AssistantIntent.specialtySearch);
      expect(r.confidence, greaterThanOrEqualTo(80));
    });

    test('TEST 2 — دكتور ناجي عبدالله الركابي → doctorSearch', () {
      final r = resolver.resolve('دكتور ناجي عبدالله الركابي');
      expect(r.intent, AssistantIntent.doctorSearch);
      expect(r.entities.doctorName, isNotNull);
      expect(r.entities.doctorName, contains('ناجي'));
    });

    test('TEST 3 — اتصل بالدكتور ناجي الركابي → callDoctor not doctorSearch', () {
      final r = resolver.resolve('اتصل بالدكتور ناجي الركابي');
      expect(r.intent, AssistantIntent.callDoctor);
      expect(r.intent, isNot(AssistantIntent.doctorSearch));
      expect(r.entities.doctorName, isNotNull);
      expect(r.requiresContext, isFalse);
    });

    test('TEST 4 — اتصل بيه requires context', () {
      final r = resolver.resolve('اتصل بيه');
      expect(r.intent, AssistantIntent.callDoctor);
      expect(r.requiresContext, isTrue);
      expect(r.entities.doctorName, isNull);
    });

    test('TEST 5 — دزله واتساب → messageDoctor', () {
      final r = resolver.resolve('دزله واتساب');
      expect(r.intent, AssistantIntent.messageDoctor);
      expect(r.requiresContext, isTrue);
    });

    test('TEST 6 — وين عيادته؟ → showLocation', () {
      final r = resolver.resolve('وين عيادته؟');
      expect(r.intent, AssistantIntent.showLocation);
      expect(r.requiresContext, isTrue);
    });

    test('TEST 7 — افتح ملفه → showProfile', () {
      final r = resolver.resolve('افتح ملفه');
      expect(r.intent, AssistantIntent.showProfile);
      expect(r.requiresContext, isTrue);
      expect(r.entities.doctorName, isNull);
    });

    test('TEST 11 — الثاني → selectResult', () {
      final r = resolver.resolve('الثاني');
      expect(r.intent, AssistantIntent.selectResult);
      expect(r.requiresContext, isTrue);
    });

    test('TEST 12 — lab phrase → findLab (Step 6)', () {
      final r = resolver.resolve('مختبر اليرموك');
      expect(r.intent, AssistantIntent.findLab);
      expect(r.entities.laboratory, isNotNull);
      expect(r.isActionIntent, isFalse);
    });

    test('TEST 13 — typed/voice parity', () {
      const q = 'اتصل بالدكتور ناجي الركابي';
      final a = resolver.resolve(q);
      final b = resolver.resolve(q);
      expect(a.intent, b.intent);
      expect(a.entities.doctorName, b.entities.doctorName);
      expect(a.requiresContext, b.requiresContext);

      const specialty = 'أريد طبيب أطفال';
      expect(
        resolver.resolve(specialty).intent,
        resolver.resolve(specialty).intent,
      );
      expect(
        resolver.resolve('الثاني').intent,
        AssistantIntent.selectResult,
      );
      expect(
        resolver.resolve('وين عيادته؟').intent,
        AssistantIntent.showLocation,
      );
    });

    test('TEST 14 — وين عيادة الدكتور ناجي الركابي → showLocation explicit', () {
      final r = resolver.resolve('وين عيادة الدكتور ناجي الركابي');
      expect(r.intent, AssistantIntent.showLocation);
      expect(r.requiresContext, isFalse);
      expect(r.entities.doctorName, isNotNull);
    });

    test('TEST 15 — لا، دزله واتساب → messageDoctor contextual', () {
      final r = resolver.resolve('لا، دزله واتساب');
      expect(r.intent, AssistantIntent.messageDoctor);
      expect(r.requiresContext, isTrue);
    });
  });

  group('SmartBrainPlanner contextual actions', () {
    late ConversationContext ctx;
    late SmartBrainPlanner planner;

    setUp(() {
      ctx = ConversationContext();
      planner = SmartBrainPlanner(
        doctorLookup: (_) async => const <SmartSearchResult>[],
      );
    });

    test('TEST 4/6/7 — contextual call/location/profile with selected Naji',
        () async {
      final naji = _doc(
        'naji',
        'ناجي عبد الله الركابي',
        location: 'الحارثية',
        phone: '07701111111',
        whatsapp: '07701111111',
      );
      ctx.rememberResults([naji], query: 'ناجي الركابي');

      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'naji');
      expect(call.canExecute, isTrue);

      final loc = await planner.plan(query: 'وين عيادته؟', context: ctx);
      expect(loc.kind, AssistantActionKind.showLocation);
      expect(loc.target?.doctorId, 'naji');
      expect(loc.message, contains('الحارثية'));

      final profile = await planner.plan(query: 'افتح ملفه', context: ctx);
      expect(profile.kind, AssistantActionKind.openProfile);
      expect(profile.target?.doctorId, 'naji');
    });

    test('TEST 5 — دزله واتساب contextual', () async {
      final naji = _doc('naji', 'ناجي', whatsapp: '0770');
      ctx.rememberResults([naji]);
      final plan = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'naji');
    });

    test('TEST 8 — missing context call', () async {
      final plan = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.message, contains('أي طبيب'));
    });

    test('TEST 9 — multiple Ali → ambiguous, no call', () async {
      final aliPlanner = SmartBrainPlanner(
        doctorLookup: (_) async => [
          _doc('ali1', 'علي أحمد', phone: '1'),
          _doc('ali2', 'علي حسن', phone: '2'),
        ],
      );
      final plan = await aliPlanner.plan(
        query: 'اتصل بالدكتور علي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(plan.canExecute, isFalse);
      expect(plan.isAmbiguous, isTrue);
      expect(plan.candidates.length, greaterThanOrEqualTo(2));
    });

    test('TEST 10 — multiple Ali profile → ambiguous, no navigation', () async {
      final aliPlanner = SmartBrainPlanner(
        doctorLookup: (_) async => [
          _doc('ali1', 'علي أحمد'),
          _doc('ali2', 'علي حسن'),
        ],
      );
      final plan = await aliPlanner.plan(
        query: 'افتح الدكتور علي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(plan.canExecute, isFalse);
      expect(plan.kind, isNot(AssistantActionKind.openProfile));
    });

    test('TEST 11 — الثاني via planner → selectEntity', () async {
      ctx.rememberResults([
        _doc('a', 'A'),
        _doc('b', 'B'),
        _doc('c', 'C'),
      ]);
      final plan = await planner.plan(query: 'الثاني', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.doctorId, 'b');
    });

    test('TEST 3 explicit call resolves unique Naji', () async {
      final najiPlanner = SmartBrainPlanner(
        doctorLookup: (_) async => [
          _doc(
            'naji',
            'ناجي عبد الله الركابي',
            phone: '07701111111',
          ),
        ],
      );
      final plan = await najiPlanner.plan(
        query: 'اتصل بالدكتور ناجي الركابي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'naji');
      expect(plan.canExecute, isTrue);
    });

    test('TEST 14 explicit location resolves unique Naji', () async {
      final najiPlanner = SmartBrainPlanner(
        doctorLookup: (_) async => [
          _doc(
            'naji',
            'ناجي عبد الله الركابي',
            location: 'الحارثية',
          ),
        ],
      );
      final plan = await najiPlanner.plan(
        query: 'وين عيادة الدكتور ناجي الركابي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showLocation);
      expect(plan.target?.doctorId, 'naji');
      expect(plan.message, contains('الحارثية'));
    });

    test('TEST 15 — لا، دزله واتساب keeps doctor', () async {
      final naji = _doc(
        'naji',
        'ناجي',
        phone: '1',
        whatsapp: '2',
      );
      ctx.rememberResults([naji]);
      await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(ctx.selectedEntity?.doctorId, 'naji');
      final wa = await planner.plan(query: 'لا، دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.doctorId, 'naji');
    });

    test('TEST 12 — lab search plans safely without contact action', () async {
      final labPlanner = SmartBrainPlanner(
        labLookup: (q) async {
          final n = ArabicTextUtils.normalize(q);
          if (n.contains('يرموك')) {
            return [
              SmartSearchResult(
                type: SmartSearchResultType.lab,
                title: 'مختبر اليرموك',
                subtitle: 'بغداد',
                labId: 'yarmouk',
                clinicLocation: 'بغداد',
              ),
            ];
          }
          return const [];
        },
        doctorLookup: (_) async => const [],
      );
      final plan =
          await labPlanner.plan(query: 'مختبر اليرموك', context: ctx);
      expect(
        plan.kind == AssistantActionKind.runLabSearch ||
            plan.kind == AssistantActionKind.selectEntity ||
            plan.kind == AssistantActionKind.showMessage,
        isTrue,
      );
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.kind, isNot(AssistantActionKind.prepareWhatsApp));
    });
  });
}
