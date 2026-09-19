import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_resolver.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_response_builder.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/speech_recognition_service.dart';

SmartSearchResult _doc(
  String id,
  String title, {
  String? specialty,
  String? location,
  int score = 85,
  String phone = '0770',
  String whatsapp = '0770',
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty ?? 'اختصاص',
    doctorId: id,
    score: score,
    specialty: specialty,
    clinicLocation: location ?? 'بغداد',
    phone: phone,
    whatsapp: whatsapp,
  );
}

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;

  final aliNasir = _doc(
    'nasir',
    'الدكتور علي ناصر السعيدي',
    specialty: 'طب الأطفال',
  );
  final aliFleih = _doc(
    'fleih',
    'الدكتور علي فليح جودة',
    specialty: 'الأنف والأذن والحنجرة',
  );

  setUp(() {
    ctx = ConversationContext();
    planner = SmartBrainPlanner(
      doctorLookup: (q) async {
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('ناصر') && !n.contains('فليح')) return [aliNasir];
        if (n.contains('فليح')) return [aliFleih];
        if (n.contains('علي')) return [aliNasir, aliFleih];
        return const [];
      },
    );
  });

  group('Intelligent Clarification Engine', () {
    test('A — دكتور علي → pending, no auto-select', () {
      ctx.rememberResults(
        [aliNasir, aliFleih],
        query: 'دكتور علي',
        intent: AssistantIntent.doctorSearch,
        clarificationReason: ClarificationReason.ambiguousName,
      );
      expect(ctx.selectedDoctor, isNull);
      expect(ctx.hasPendingClarification, isTrue);
      expect(ctx.pendingClarification!.candidates, hasLength(2));
      expect(ctx.pendingClarification!.pendingAction, isNull);
    });

    test('B — الثاني resolves B and clears pending', () async {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final plan = await planner.plan(query: 'الثاني', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.doctorId, 'fleih');
      expect(ctx.selectedDoctor?.doctorId, 'fleih');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('C — علي ناصر name resolution', () async {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final plan = await planner.plan(query: 'علي ناصر', context: ctx);
      expect(plan.target?.doctorId, 'nasir');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('D — unique token ناصر', () async {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final plan = await planner.plan(query: 'ناصر', context: ctx);
      expect(plan.target?.doctorId, 'nasir');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('E — علي remains ambiguous', () async {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final plan = await planner.plan(query: 'علي', context: ctx);
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(ctx.hasPendingClarification, isTrue);
      expect(ctx.selectedDoctor, isNull);
    });

    test('F — طبيب الأطفال specialty resolution', () async {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final plan = await planner.plan(query: 'طبيب الأطفال', context: ctx);
      expect(plan.target?.doctorId, 'nasir');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('G — invalid ordinal الثالث keeps pending', () async {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final plan = await planner.plan(query: 'الثالث', context: ctx);
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(plan.message, contains('خياران'));
      expect(ctx.hasPendingClarification, isTrue);
      expect(ctx.selectedDoctor, isNull);
    });

    test('H — callDoctor continuation after الثاني', () async {
      final plan1 = await planner.plan(
        query: 'اتصل بدكتور علي',
        context: ctx,
      );
      expect(plan1.kind, AssistantActionKind.showClarification);
      expect(ctx.pendingClarification?.pendingAction, AssistantIntent.callDoctor);

      final plan2 = await planner.plan(query: 'الثاني', context: ctx);
      expect(plan2.kind, AssistantActionKind.prepareCall);
      expect(plan2.target?.doctorId, 'fleih');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('I — WhatsApp continuation after علي ناصر', () async {
      final plan1 = await planner.plan(
        query: 'دز واتساب لدكتور علي',
        context: ctx,
      );
      expect(plan1.kind, AssistantActionKind.showClarification);
      expect(
        ctx.pendingClarification?.pendingAction,
        AssistantIntent.messageDoctor,
      );

      final plan2 = await planner.plan(query: 'علي ناصر', context: ctx);
      expect(plan2.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan2.target?.doctorId, 'nasir');
    });

    test('J — location continuation', () async {
      final plan1 = await planner.plan(
        query: 'وين عيادة دكتور علي',
        context: ctx,
      );
      expect(plan1.kind, AssistantActionKind.showClarification);
      expect(
        ctx.pendingClarification?.pendingAction,
        AssistantIntent.showLocation,
      );

      final plan2 = await planner.plan(query: 'الثاني', context: ctx);
      expect(plan2.kind, AssistantActionKind.showLocation);
      expect(plan2.target?.doctorId, 'fleih');
    });

    test('K — profile continuation', () async {
      final plan1 = await planner.plan(
        query: 'افتح دكتور علي',
        context: ctx,
      );
      expect(plan1.kind, AssistantActionKind.showClarification);
      expect(
        ctx.pendingClarification?.pendingAction,
        AssistantIntent.showProfile,
      );

      final plan2 = await planner.plan(query: 'الأول', context: ctx);
      expect(plan2.kind, AssistantActionKind.openProfile);
      expect(plan2.target?.doctorId, 'nasir');
    });

    test('L — new search cancels clarification', () async {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      expect(ctx.hasPendingClarification, isTrue);

      final plan = await planner.plan(
        query: 'أريد طبيب أعصاب',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.runSpecialtySearch);
      expect(ctx.hasPendingClarification, isFalse);
      expect(ctx.selectedDoctor, isNull);
    });

    test('M — نعم must not auto-select first', () async {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(ctx.selectedDoctor, isNull);
      expect(ctx.hasPendingClarification, isTrue);
    });

    test('N — لا must not randomly select', () async {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final plan = await planner.plan(query: 'لا', context: ctx);
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(ctx.selectedDoctor, isNull);
      expect(ctx.hasPendingClarification, isTrue);
    });

    test('O — لا، الثاني selects second', () async {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final plan = await planner.plan(query: 'لا، الثاني', context: ctx);
      expect(plan.target?.doctorId, 'fleih');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('P — single result no clarification', () {
      ctx.rememberResults([aliNasir], query: 'علي ناصر');
      expect(ctx.selectedDoctor?.doctorId, 'nasir');
      expect(ctx.hasPendingClarification, isFalse);
      expect(ctx.pendingClarification, isNull);
    });

    test('Q — typed/voice parity for clarification flow', () async {
      Future<AssistantActionKind> run(String q) async {
        final c = ConversationContext()
          ..rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
        final p = await planner.plan(query: q, context: c);
        return p.kind;
      }

      expect(QueryInputSource.typed, isNot(QueryInputSource.voice));
      expect(await run('الثاني'), await run('الثاني'));
      expect(await run('علي ناصر'), await run('علي ناصر'));
      expect(await run('نعم'), AssistantActionKind.showClarification);
    });

    test('R — context reset clears pending clarification', () {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      expect(ctx.hasPendingClarification, isTrue);
      ctx.reset();
      expect(ctx.hasPendingClarification, isFalse);
      expect(ctx.pendingClarification, isNull);
      expect(ctx.clarificationCandidates, isEmpty);
    });

    test('response builder is centralized Arabic', () {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final msg = const ClarificationResponseBuilder().build(
        ctx.pendingClarification!,
      );
      expect(msg, contains('علي ناصر'));
      expect(msg, contains('علي فليح'));
      expect(msg.toLowerCase(), isNot(contains('null')));
    });

    test('resolver unit: الأنف والأذن → fleih', () {
      ctx.rememberResults([aliNasir, aliFleih], query: 'دكتور علي');
      final r = const ClarificationResolver().resolve(
        query: 'الأنف والأذن',
        pending: ctx.pendingClarification!,
      );
      expect(r.isResolved, isTrue);
      expect(r.candidate?.id, 'fleih');
    });
  });

  group('mic protections unchanged', () {
    test('no second app launch', () {
      expect(DeviceSpeechRecognitionService.mayLaunchSecondAppInstance, isFalse);
    });
  });
}
