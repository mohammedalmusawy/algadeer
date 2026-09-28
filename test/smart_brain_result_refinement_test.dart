import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/result_set_refiner.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

SmartSearchResult _doc({
  required String id,
  required String title,
  String? phone,
  String? whatsapp,
  String? gender,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: 'طب الأطفال',
    doctorId: id,
    score: 90,
    specialty: 'طب الأطفال',
    phone: phone,
    whatsapp: whatsapp,
    gender: gender,
    clinicLocation: 'الكرادة',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('ResultSetRefiner.parse', () {
    test('يفهم عبارات واتساب العراقية', () {
      for (final q in [
        'اللي عنده واتساب',
        'اللي بيه واتساب',
        'عنده واتساب',
        'اللي عدها واتساب',
      ]) {
        final c = ResultSetRefiner.parse(q);
        expect(c, isNotNull, reason: q);
        expect(c!.requiresWhatsApp, isTrue, reason: q);
      }
    });

    test('لا يخطف دزله واتساب أو بحث جديد', () {
      expect(ResultSetRefiner.parse('دزله واتساب'), isNull);
      expect(ResultSetRefiner.parse('ارسل واتساب'), isNull);
      expect(ResultSetRefiner.parse('اريد طبيب اطفال عنده واتساب'), isNull);
      expect(ResultSetRefiner.parse('دكتورة ميعاد'), isNull);
    });

    test('جنس قصير فقط', () {
      expect(ResultSetRefiner.parse('طبيبة')?.gender, 'female');
      expect(ResultSetRefiner.parse('دكتورة فقط')?.gender, 'female');
      expect(ResultSetRefiner.parse('طبيب فقط')?.gender, 'male');
      expect(ResultSetRefiner.parse('دكتور'), isNull);
    });
  });

  group('M3 — تصفية ResultContext', () {
    late SmartBrainPlanner planner;
    late ConversationContext ctx;

    final withWa = _doc(
      id: 'a',
      title: 'د. أحمد',
      phone: '07701',
      whatsapp: '07701',
      gender: 'male',
    );
    final noWa = _doc(
      id: 'b',
      title: 'د. سارة',
      phone: '07702',
      whatsapp: null,
      gender: 'female',
    );
    final femaleWa = _doc(
      id: 'c',
      title: 'د. نور',
      phone: '07703',
      whatsapp: '07703',
      gender: 'female',
    );

    setUp(() {
      ctx = ConversationContext();
      planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (q) async {
          if (q.trim().isEmpty) return [withWa, noWa, femaleWa];
          return const [];
        },
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
      );
      ctx.rememberResults(
        [withWa, noWa, femaleWa],
        query: 'اطباء اطفال',
        intent: AssistantIntent.specialtySearch,
      );
    });

    test('اللي عنده واتساب → يصفّي القائمة الحالية', () async {
      final plan = await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      expect(plan.message, contains('واتساب'));
      expect(plan.candidates.length, 2);
      expect(
        plan.candidates.map((e) => e.doctorId),
        containsAll(['a', 'c']),
      );
      expect(plan.candidates.any((e) => e.doctorId == 'b'), isFalse);
      expect(plan.kind, isNot(AssistantActionKind.prepareWhatsApp));
      expect(ctx.currentResultContext?.length, 2);
    });

    test('بعد التصفية: الثاني ثم اتصل بيه', () async {
      await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      final select = await planner.plan(query: 'الثاني', context: ctx);
      expect(select.kind, AssistantActionKind.selectEntity);
      expect(select.target?.doctorId, 'c');

      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'c');
      expect(call.canExecute, isTrue);
    });

    test('طبيبة → جنس أنثى فقط', () async {
      final plan = await planner.plan(query: 'طبيبة', context: ctx);
      expect(plan.candidates.every((e) => e.gender == 'female'), isTrue);
      expect(plan.candidates.map((e) => e.doctorId), containsAll(['b', 'c']));
    });

    test('تصفية بلا نتائج حالية → طلب بحث أول', () async {
      final empty = ConversationContext();
      final plan =
          await planner.plan(query: 'اللي عنده واتساب', context: empty);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, contains('بحث أول'));
      expect(plan.canExecute, isFalse);
    });

    test('صفر بعد التصفية → لا يمسح القائمة الأصلية كاختيار أعمى', () async {
      ctx.rememberResults(
        [noWa], // واحد بلا واتساب — path length==1 answers about entity
        query: 'x',
        intent: AssistantIntent.specialtySearch,
      );
      // أعد قائمة كلها بلا واتساب
      final none = _doc(id: 'x', title: 'د. بلا', phone: null, whatsapp: null);
      final none2 = _doc(id: 'y', title: 'د. بلا2', phone: null, whatsapp: null);
      ctx.rememberResults(
        [none, none2],
        query: 'x',
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      expect(plan.message, contains('ما لكيت'));
      expect(plan.candidates.length, 2); // القائمة الأصلية معروضة في الرد
      expect(ctx.currentResultContext?.length, 2); // لم تُستبدل بفارغ
    });
  });
}
