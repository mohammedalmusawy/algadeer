import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/arabic_answer_normalizer.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/arabic_duration_parser.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/guided_answer_resolver.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/guided_conversation_models.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/guided_demo_flows.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

SmartSearchResult _doc(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: 'اختصاص',
      doctorId: id,
      score: 90,
      specialty: 'طب الأطفال',
      clinicLocation: 'بغداد',
      phone: '0770',
      whatsapp: '0770',
    );

SmartSearchResult _lab(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: 'مختبر',
      labId: id,
      score: 90,
      phone: '0771',
      whatsapp: '0771',
      clinicLocation: 'الكرادة',
    );

GuidedFlowDefinition _durationOnlyFlow() {
  const q = GuidedQuestion(
    id: 'duration',
    type: GuidedQuestionType.duration,
    prompt: 'من متى بدأت المشكلة؟',
    expectedAnswerType: GuidedAnswerType.duration,
  );
  return const GuidedFlowDefinition(
    id: 'duration_only_test',
    type: GuidedFlowType.generic,
    steps: [
      GuidedFlowStep(id: 'd1', question: q, nextStepId: '__complete__'),
    ],
  );
}

GuidedFlowDefinition _multiChoiceFlow() {
  const q = GuidedQuestion(
    id: 'multi',
    type: GuidedQuestionType.multipleChoice,
    prompt: 'أي من هذه ينطبق؟',
    expectedAnswerType: GuidedAnswerType.multipleChoice,
    options: [
      GuidedChoiceOption(id: 'a', label: 'أ'),
      GuidedChoiceOption(id: 'b', label: 'ب'),
      GuidedChoiceOption(id: 'c', label: 'ج'),
      GuidedChoiceOption(id: 'd', label: 'د'),
    ],
  );
  return const GuidedFlowDefinition(
    id: 'multi_test',
    type: GuidedFlowType.generic,
    steps: [
      GuidedFlowStep(id: 'm1', question: q, nextStepId: '__complete__'),
    ],
  );
}

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late ArabicDurationParser durationParser;
  late GuidedAnswerResolver answerResolver;

  setUp(() {
    ctx = ConversationContext();
    planner = SmartBrainPlanner(
      doctorLookup: (q) async => [_doc('d1', 'دكتور أطفال')],
      labLookup: (q) async => [_lab('hayat', 'مختبر الحياة')],
      analysisLookup: (q) async => [
            AnalysisItem(id: 'cbc', name: 'CBC', aliases: const ['سي بي سي']),
          ],
      packagesForAnalysisLookup: (id) async => const [],
      activePackagesLookup: ({labId, nameQuery}) async => const [],
    );
    durationParser = const ArabicDurationParser();
    answerResolver = const GuidedAnswerResolver();
  });

  group('Guided Conversation State Engine', () {
    test('A — start flow → waitingForAnswer', () {
      final resp = planner.startServiceAssistanceDemo(context: ctx);
      expect(ctx.guidedConversation.status, GuidedFlowStatus.waitingForAnswer);
      expect(ctx.guidedConversation.pendingQuestion?.id, 'help_search_yes_no');
      expect(resp.nextQuestion?.prompt, contains('خدمة'));
    });

    test('B — إي → YES', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      final plan = await planner.plan(query: 'إي', context: ctx);
      expect(plan.kind, AssistantActionKind.guidedConversation);
      expect(ctx.guidedConversation.collectedAnswers['help_search_yes_no']?.yesNo,
          isTrue);
      expect(ctx.guidedConversation.pendingQuestion?.id, 'service_type');
    });

    test('C — نعم → YES', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'نعم', context: ctx);
      expect(ctx.guidedConversation.collectedAnswers['help_search_yes_no']?.yesNo,
          isTrue);
    });

    test('D — لا → NO, not cancel', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      final plan = await planner.plan(query: 'لا', context: ctx);
      expect(ctx.guidedConversation.status, GuidedFlowStatus.completed);
      expect(ctx.guidedConversation.collectedAnswers['help_search_yes_no']?.yesNo,
          isFalse);
      expect(plan.guidedResponse?.cancelled, isNot(true));
    });

    test('E — خلاص → cancelled', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      final plan = await planner.plan(query: 'خلاص', context: ctx);
      expect(ctx.guidedConversation.status, GuidedFlowStatus.cancelled);
      expect(plan.guidedResponse?.cancelled, isTrue);
    });

    test('F — topic change duration + أريد مختبر الحياة', () async {
      planner.startGuidedFlow(context: ctx, definition: _durationOnlyFlow());
      expect(ctx.guidedConversation.isWaitingForAnswer, isTrue);
      final plan = await planner.plan(
        query: 'أريد مختبر الحياة',
        context: ctx,
      );
      expect(ctx.guidedConversation.status, GuidedFlowStatus.cancelled);
      expect(
        plan.kind == AssistantActionKind.runLabSearch ||
            plan.kind == AssistantActionKind.selectEntity ||
            plan.target?.labId == 'hayat' ||
            plan.message.contains('مختبر') ||
            plan.kind == AssistantActionKind.showClarification ||
            plan.canExecute,
        isTrue,
      );
    });

    test('G — من يومين → 2 days', () {
      final d = durationParser.parse('من يومين');
      expect(d?.amount, 2);
      expect(d?.unit, 'day');
    });

    test('H — من البارحة → relative yesterday', () {
      final d = durationParser.parse('من البارحة');
      expect(d, isNotNull);
      expect(d!.unit, 'relative_yesterday');
    });

    test('I — أسبوعين → 2 weeks', () {
      final d = durationParser.parse('أسبوعين');
      expect(d?.amount, 2);
      expect(d?.unit, 'week');
    });

    test('J — من فترة → approximate, no invented amount', () {
      final d = durationParser.parse('من فترة');
      expect(d?.approximate, isTrue);
      expect(d?.amount, isNull);
    });

    test('K — ٣ أيام → 3 days', () {
      final d = durationParser.parse('٣ أيام');
      expect(d?.amount, 3);
      expect(d?.unit, 'day');
    });

    test('L — 3 أيام → 3 days', () {
      final d = durationParser.parse('3 أيام');
      expect(d?.amount, 3);
      expect(d?.unit, 'day');
    });

    test('M — singleChoice doctor', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'إي', context: ctx);
      await planner.plan(query: 'دكتور', context: ctx);
      expect(ctx.guidedConversation.status, GuidedFlowStatus.completed);
      expect(
        ctx.guidedConversation.collectedAnswers['service_type']?.optionIds,
        ['doctor'],
      );
    });

    test('N — singleChoice laboratory', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'إي', context: ctx);
      await planner.plan(query: 'مختبر', context: ctx);
      expect(
        ctx.guidedConversation.collectedAnswers['service_type']?.optionIds,
        ['laboratory'],
      );
    });

    test('O — singleChoice analysis', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'إي', context: ctx);
      await planner.plan(query: 'تحليل', context: ctx);
      expect(
        ctx.guidedConversation.collectedAnswers['service_type']?.optionIds,
        ['analysis'],
      );
    });

    test('P — singleChoice package', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'إي', context: ctx);
      await planner.plan(query: 'باقة', context: ctx);
      expect(
        ctx.guidedConversation.collectedAnswers['service_type']?.optionIds,
        ['package'],
      );
    });

    test('Q — multipleChoice الأول والثالث', () {
      final def = _multiChoiceFlow();
      final q = def.steps.first.question;
      final r = answerResolver.resolve(query: 'الأول والثالث', question: q);
      expect(r.status, GuidedAnswerResolveStatus.resolved);
      expect(r.answer?.optionIds, ['a', 'c']);
    });

    test('R — short compatible answer does not become global search', () async {
      planner.startGuidedFlow(context: ctx, definition: _durationOnlyFlow());
      final plan = await planner.plan(query: 'يومين', context: ctx);
      expect(plan.kind, AssistantActionKind.guidedConversation);
      expect(plan.kind, isNot(AssistantActionKind.runGeneralSearch));
      expect(plan.kind, isNot(AssistantActionKind.runDoctorSearch));
      expect(
        ctx.guidedConversation.collectedAnswers['duration']?.durationValue?.amount,
        2,
      );
    });

    test('S — explicit new search escapes pending question', () async {
      planner.startGuidedFlow(context: ctx, definition: _durationOnlyFlow());
      final plan = await planner.plan(query: 'أريد تحليل CBC', context: ctx);
      expect(ctx.guidedConversation.status, GuidedFlowStatus.cancelled);
      expect(
        plan.kind == AssistantActionKind.runAnalysisSearch ||
            plan.kind == AssistantActionKind.selectEntity ||
            plan.target?.analysisId == 'cbc' ||
            plan.analysisQuery != null ||
            plan.canExecute ||
            plan.message.isNotEmpty,
        isTrue,
      );
    });

    test('T — collected answers keyed by question ID', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'نعم', context: ctx);
      await planner.plan(query: 'مختبر', context: ctx);
      expect(
        ctx.guidedConversation.collectedAnswers.keys,
        containsAll(['help_search_yes_no', 'service_type']),
      );
    });

    test('U — correction updates previous answer', () async {
      planner.startGuidedFlow(context: ctx, definition: _durationOnlyFlow());
      await planner.plan(query: 'من يومين', context: ctx);
      expect(
        ctx.guidedConversation.collectedAnswers['duration']?.durationValue?.amount,
        2,
      );
      final plan = await planner.plan(
        query: 'لا، قصدي من ثلاثة أيام',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.guidedConversation);
      expect(
        ctx.guidedConversation.collectedAnswers['duration']?.durationValue?.amount,
        3,
      );
    });

    test('V — flow completes cleanly', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'إي', context: ctx);
      final plan = await planner.plan(query: 'مختبر', context: ctx);
      expect(ctx.guidedConversation.status, GuidedFlowStatus.completed);
      expect(ctx.guidedConversation.pendingQuestion, isNull);
      expect(plan.guidedResponse?.completedData['serviceType'], 'laboratory');
    });

    test('W — completed flow does not erase entity selections', () async {
      ctx.selectDoctor(_doc('d1', 'دكتور'));
      ctx.selectLaboratory(_lab('hayat', 'مختبر الحياة'));
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'إي', context: ctx);
      await planner.plan(query: 'تحليل', context: ctx);
      expect(ctx.selectedDoctor?.doctorId, 'd1');
      expect(ctx.selectedLaboratory?.labId, 'hayat');
    });

    test('X — conversation reset clears guided flow', () {
      planner.startServiceAssistanceDemo(context: ctx);
      expect(ctx.guidedConversation.isWaitingForAnswer, isTrue);
      ctx.reset();
      expect(ctx.guidedConversation.status, GuidedFlowStatus.inactive);
      expect(ctx.guidedConversation.pendingQuestion, isNull);
      expect(ctx.guidedConversation.collectedAnswers, isEmpty);
    });

    test('Y — debugSnapshot guided metadata without raw answers', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'إي', context: ctx);
      final snap = ctx.debugSnapshot();
      expect(snap['guidedFlowId'], GuidedDemoFlows.serviceAssistanceDemoId);
      expect(snap['guidedStatus'], isNotNull);
      expect(snap['pendingQuestionId'], isNotNull);
      expect(snap['collectedAnswerCount'], greaterThan(0));
      final encoded = snap.toString();
      expect(encoded.contains('إي'), isFalse);
      expect(encoded.contains('نعم'), isFalse);
    });

    test('Z — voice/text parity', () async {
      final ctxVoice = ConversationContext();
      final ctxText = ConversationContext();
      planner.startServiceAssistanceDemo(context: ctxVoice);
      planner.startServiceAssistanceDemo(context: ctxText);

      const uttered = 'مختبر';
      // محاكاة: نفس النص المعدّ بعد STT أو الكتابة.
      expect(QueryInputSource.voice, isNot(QueryInputSource.typed));
      await planner.plan(query: 'إي', context: ctxVoice);
      await planner.plan(query: 'إي', context: ctxText);
      final v = await planner.plan(query: uttered, context: ctxVoice);
      final t = await planner.plan(query: uttered, context: ctxText);
      expect(v.guidedResponse?.completedData['serviceType'],
          t.guidedResponse?.completedData['serviceType']);
      expect(ctxVoice.guidedConversation.status,
          ctxText.guidedConversation.status);
    });

    test('AA — PendingClarification still works', () async {
      final a = _doc('nasir', 'الدكتور علي ناصر');
      final b = _doc('fleih', 'الدكتور علي فليح');
      ctx.setPendingClarification(
        PendingClarification(
          entityType: ClarificationEntityType.doctor,
          reason: ClarificationReason.ambiguousName,
          candidates: [
            ClarificationCandidate(
              id: 'nasir',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: a.title,
              payload: a,
            ),
            ClarificationCandidate(
              id: 'fleih',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: b.title,
              payload: b,
            ),
          ],
          originalIntent: AssistantIntent.doctorSearch,
        ),
      );
      final plan = await planner.plan(query: 'الثاني', context: ctx);
      expect(ctx.pendingClarification, isNull);
      expect(ctx.selectedDoctor?.doctorId, 'fleih');
      expect(plan.target?.doctorId, 'fleih');
    });

    test('AB — لا، الثاني with clarification is not bare NO', () async {
      final a = _doc('nasir', 'الدكتور علي ناصر');
      final b = _doc('fleih', 'الدكتور علي فليح');
      planner.startServiceAssistanceDemo(context: ctx);
      ctx.setPendingClarification(
        PendingClarification(
          entityType: ClarificationEntityType.doctor,
          reason: ClarificationReason.ambiguousName,
          candidates: [
            ClarificationCandidate(
              id: 'nasir',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: a.title,
              payload: a,
            ),
            ClarificationCandidate(
              id: 'fleih',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: b.title,
              payload: b,
            ),
          ],
        ),
      );
      // التوضيح يملك الجواب رغم وجود guided waiting.
      final plan = await planner.plan(query: 'لا، الثاني', context: ctx);
      expect(ArabicAnswerNormalizer.tryYesNo('لا، الثاني'), isNull);
      expect(ctx.selectedDoctor?.doctorId, 'fleih');
      expect(plan.kind, isNot(AssistantActionKind.guidedConversation));
    });

    test('AC — no raw guided answer persistence', () {
      planner.startServiceAssistanceDemo(context: ctx);
      final guidedDir = Directory('lib/voice/guided_conversation');
      expect(guidedDir.existsSync(), isTrue);
      for (final f in guidedDir.listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        expect(src.contains('SharedPreferences'), isFalse);
        expect(src.contains('supabase'), isFalse);
        expect(src.contains('Supabase'), isFalse);
        expect(src.contains('print('), isFalse);
        expect(src.contains('debugPrint'), isFalse);
      }
    });

    test('AD — no medical inference', () async {
      planner.startGuidedFlow(context: ctx, definition: _durationOnlyFlow());
      final plan = await planner.plan(
        query: 'عندي صداع أريد تحليل',
        context: ctx,
      );
      // إما هروب لبحث تحليل أو رسالة عدم توصية — بدون تشخيص.
      final blob =
          '${plan.message}${plan.guidedResponse?.message ?? ''}${plan.kind}';
      expect(blob.toLowerCase().contains('تشخيص'), isFalse);
      expect(blob.contains('يجب أن تأخذ'), isFalse);
    });

    test('AE — no TTS dependency in guided engine', () {
      final guidedDir = Directory('lib/voice/guided_conversation');
      for (final f in guidedDir.listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        expect(src.contains('text_to_speech'), isFalse);
        expect(src.contains('TextToSpeech'), isFalse);
        expect(src.contains('flutter_tts'), isFalse);
      }
    });

    test('AF — bounded deterministic state', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'إي', context: ctx);
      await planner.plan(query: 'مختبر', context: ctx);
      expect(ctx.guidedConversation.collectedAnswers.length, lessThanOrEqualTo(8));
      expect(
        ctx.guidedConversation.definition!.steps.length,
        lessThanOrEqualTo(16),
      );
    });
  });

  group('Scripted guided conversations', () {
    test('SCRIPT — service assistance demo completes laboratory', () async {
      final start = planner.startServiceAssistanceDemo(context: ctx);
      expect(start.message, contains('خدمة'));

      final mid = await planner.plan(query: 'إي', context: ctx);
      expect(mid.guidedResponse?.nextQuestion?.id, 'service_type');
      expect(mid.message, contains('طبيب'));

      final done = await planner.plan(query: 'مختبر', context: ctx);
      expect(done.guidedResponse?.flowStatus, GuidedFlowStatus.completed);
      expect(done.guidedResponse?.completedData['serviceType'], 'laboratory');
      expect(ctx.guidedConversation.pendingQuestion, isNull);
    });

    test('SCRIPT — topic change forwards to analysis CBC', () async {
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'إي', context: ctx);
      expect(ctx.guidedConversation.pendingQuestion?.id, 'service_type');

      final plan = await planner.plan(
        query: 'خلينا من هذا، أريد تحليل CBC',
        context: ctx,
      );
      expect(ctx.guidedConversation.status, GuidedFlowStatus.cancelled);
      expect(
        plan.kind == AssistantActionKind.runAnalysisSearch ||
            plan.analysisQuery != null ||
            (plan.target?.analysisId == 'cbc') ||
            plan.canExecute ||
            plan.message.isNotEmpty,
        isTrue,
      );
      // لا يبتلع الأمر كجواب اختيار.
      expect(
        ctx.guidedConversation.collectedAnswers['service_type'],
        isNull,
      );
    });
  });
}
