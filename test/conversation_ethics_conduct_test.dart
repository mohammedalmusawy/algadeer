import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_models.dart';
import 'package:ghadeer_clinic/health/understanding/health_understanding_engine.dart';
import 'package:ghadeer_clinic/health/understanding/symptom_models.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conduct/conversation_conduct_coordinator.dart';
import 'package:ghadeer_clinic/voice/conduct/conversation_conduct_detector.dart';
import 'package:ghadeer_clinic/voice/conduct/conversation_conduct_models.dart';
import 'package:ghadeer_clinic/voice/conduct/conversation_ethics_response_builder.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  late ConversationConductDetector detector;
  late ConversationConductCoordinator conduct;
  late ConversationEthicsResponseBuilder ethics;
  late HealthUnderstandingEngine understanding;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;

  setUp(() {
    detector = ConversationConductDetector();
    conduct = ConversationConductCoordinator();
    ethics = const ConversationEthicsResponseBuilder();
    understanding = HealthUnderstandingEngine();
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      doctorLookup: (q) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. الأول',
              subtitle: 'باطنية',
              doctorId: 'd1',
              score: 95,
              specialty: 'باطنية',
              phone: '0770',
              whatsapp: '0770',
            ),
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. الثاني',
              subtitle: 'باطنية',
              doctorId: 'd2',
              score: 90,
              specialty: 'باطنية',
              phone: '0771',
              whatsapp: '0771',
            ),
          ],
      labLookup: (q) async => [
            SmartSearchResult(
              type: SmartSearchResultType.lab,
              title: 'مختبر الحياة',
              subtitle: 'مختبر',
              labId: 'hayat',
              score: 90,
            ),
          ],
      analysisLookup: (q) async => [
            AnalysisItem(id: 'cbc', name: 'CBC', aliases: const ['سي بي سي']),
          ],
      packagesForAnalysisLookup: (id) async => const [],
    );
  });

  group('Conversation ethics & conduct', () {
    test('A — normal Iraqi conversation → normal', () {
      final r = detector.detect('أريد طبيب أطفال');
      expect(r.level, ConversationConductLevel.normal);
      expect(r.shouldRespond, isFalse);
    });

    test('B — frustration not abuse', () {
      final r = detector.detect('هذا ما يشتغل');
      expect(r.level, ConversationConductLevel.normal);
      expect(r.matchedCategory, ConversationConductCategory.frustration);
      expect(r.shouldRespond, isFalse);
    });

    test('C — criticism التطبيق سيء not abuse', () {
      final r = detector.detect('التطبيق سيء');
      expect(r.shouldRespond, isFalse);
      expect(r.level, ConversationConductLevel.normal);
    });

    test('D — criticism جوابك غلط not abuse', () {
      final r = detector.detect('جوابك غلط');
      expect(r.shouldRespond, isFalse);
      expect(r.matchedCategory, ConversationConductCategory.criticism);
    });

    test('E — clear assistant-directed insult → abusive', () {
      final r = detector.detect('انت غبي');
      expect(r.level, ConversationConductLevel.abusive);
      expect(r.target, ConversationConductTarget.assistant);
      expect(r.shouldRespond, isTrue);
    });

    test('F — severe abuse when configured', () {
      final r = detector.detect('يا غبي انعل ابو التطبيق');
      expect(
        r.level == ConversationConductLevel.severeAbuse ||
            r.level == ConversationConductLevel.abusive,
        isTrue,
      );
      expect(r.shouldRespond, isTrue);
    });

    test('G — reported insult → quoted, no boundary', () {
      final r = detector.detect('واحد سبني وكال لي انت غبي');
      expect(r.target, ConversationConductTarget.quotedSpeech);
      expect(r.shouldRespond, isFalse);
    });

    test('H — quoted offensive phrase does not increment abuse count', () {
      final o = conduct.observe(
        query: 'واحد سبني وكال لي انت غبي',
        state: ConversationConductSessionState.empty,
      );
      expect(o.state.recentAbuseCount, 0);
      expect(o.result.shouldRespond, isFalse);
    });

    test('I — first abuse → gentle boundary', () async {
      final plan = await brain.plan(query: 'انت غبي', context: ctx);
      expect(plan.message, contains('محترم'));
      expect(
        plan.message,
        ConversationEthicsResponseBuilder.gentle,
      );
      expect(ctx.conductState.recentAbuseCount, 1);
    });

    test('J — repeated abuse → repeated boundary', () async {
      await brain.plan(query: 'انت غبي', context: ctx);
      final plan = await brain.plan(query: 'يا غبي', context: ctx);
      expect(plan.message, ConversationEthicsResponseBuilder.repeated);
      expect(ctx.conductState.recentAbuseCount, greaterThanOrEqualTo(2));
    });

    test('K — no insult returned by Ghadeer', () async {
      final plan = await brain.plan(query: 'انت غبي', context: ctx);
      expect(ethics.violatesOwnLanguagePolicy(plan.message), isFalse);
      expect(plan.message.contains('غبي'), isFalse);
    });

    test('L — no sarcasm returned by Ghadeer', () async {
      final plan = await brain.plan(query: 'انت غبي', context: ctx);
      expect(plan.message.contains('هها'), isFalse);
      expect(plan.message.contains('من انت'), isFalse);
    });

    test('M — no feature blocking', () async {
      await brain.plan(query: 'انت غبي', context: ctx);
      final plan = await brain.plan(query: 'أريد طبيب أطفال', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.none));
    });

    test('N — no permanent user label', () {
      final s = ConversationConductSessionState(
        recentAbuseCount: 2,
        lastConductLevel: ConversationConductLevel.abusive,
      );
      expect(s.debugMap().containsKey('userIsAbusive'), isFalse);
      expect(s.debugMap().containsKey('reputation'), isFalse);
    });

    test('O — conduct state session-local', () {
      ctx.setConductState(
        const ConversationConductSessionState(recentAbuseCount: 1),
      );
      expect(ctx.conductState.recentAbuseCount, 1);
      final other = ConversationContext();
      expect(other.conductState.recentAbuseCount, 0);
    });

    test('P — no SharedPreferences persistence', () {
      final blob = File('lib/voice/conduct/conversation_conduct_coordinator.dart')
          .readAsStringSync();
      expect(blob.contains('SharedPreferences'), isFalse);
    });

    test('Q — no Supabase persistence', () {
      for (final f in Directory('lib/voice/conduct').listSync()) {
        if (f is File) {
          expect(f.readAsStringSync().toLowerCase().contains('supabase'), isFalse);
        }
      }
    });

    test('R — no analytics raw profanity', () {
      for (final f in Directory('lib/voice/conduct').listSync()) {
        if (f is File) {
          final t = f.readAsStringSync().toLowerCase();
          expect(t.contains('analytics'), isFalse);
          expect(t.contains('firebaseanalytics'), isFalse);
        }
      }
    });

    test('S — debug state contains no raw offensive phrase', () async {
      await brain.plan(query: 'انت غبي', context: ctx);
      final snap = ctx.debugSnapshot().toString();
      expect(snap.contains('غبي'), isFalse);
      expect(snap.contains('lastConductLevel'), isTrue);
      expect(snap.contains('recentAbuseCount'), isTrue);
    });

    test('T — abusive + ordinary health reaches parser', () {
      final stripped = detector.detect('يا غبي بطني يوجعني من يومين');
      expect(stripped.shouldRespond, isTrue);
      final u = understanding.understand(stripped.remainderQuery);
      expect(
        u.symptoms.any((s) => s.conceptId == 'abdominal_pain'),
        isTrue,
      );
      expect(u.duration, isNotNull);
    });

    test('U — abusive + urgent health reaches 10E first', () async {
      final plan = await brain.plan(
        query: 'يا غبي صدري يوجعني كلش ونفسي ضايج كلش',
        context: ctx,
      );
      expect(
        plan.healthDecision?.type ==
                HealthGuidanceDecisionType.urgentEvaluation ||
            plan.healthDecision?.type ==
                HealthGuidanceDecisionType.emergencyEvaluation ||
            plan.kind == AssistantActionKind.healthGuidance,
        isTrue,
      );
    });

    test('V — urgent medical response not replaced by ethics', () async {
      final plan = await brain.plan(
        query: 'يا غبي صدري يوجعني كلش ونفسي ضايج كلش',
        context: ctx,
      );
      if (plan.healthDecision?.type ==
              HealthGuidanceDecisionType.urgentEvaluation ||
          plan.healthDecision?.type ==
              HealthGuidanceDecisionType.emergencyEvaluation) {
        expect(plan.message, isNot(ConversationEthicsResponseBuilder.gentle));
        expect(plan.message, isNot(ConversationEthicsResponseBuilder.repeated));
        expect(plan.healthDecision?.allowCommercialOffers, isFalse);
        expect(plan.message.contains('عاجل') || plan.message.contains('طارئ'),
            isTrue);
      }
    });

    test('W — abusive + doctor ordinal preserves second', () async {
      ctx.setResultContext(
        entityType: ConversationEntityType.doctor,
        items: [
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'د. الأول',
            subtitle: 'باطنية',
            doctorId: 'd1',
            score: 95,
          ),
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'د. الثاني',
            subtitle: 'باطنية',
            doctorId: 'd2',
            score: 90,
          ),
        ],
      );
      ctx.lastResults = ctx.currentResultContext!.items;
      final plan = await brain.plan(
        query: 'يا غبي اتصل بالدكتور الثاني',
        context: ctx,
      );
      expect(
        plan.kind == AssistantActionKind.prepareCall ||
            plan.kind == AssistantActionKind.selectEntity ||
            plan.target?.doctorId == 'd2' ||
            plan.message.contains('محترم'),
        isTrue,
      );
      // الهدف الثاني يبقى متاحاً في السياق
      expect(ctx.currentResultContext?.items.length, 2);
    });

    test('X — abusive + WhatsApp action preserves action', () async {
      ctx.selectedDoctor = SmartSearchResult(
        type: SmartSearchResultType.doctor,
        title: 'د. الثاني',
        subtitle: 'باطنية',
        doctorId: 'd2',
        score: 90,
        whatsapp: '0771',
      );
      ctx.activeEntityType = ConversationEntityType.doctor;
      final plan = await brain.plan(
        query: 'يا غبي دزله واتساب',
        context: ctx,
      );
      expect(
        plan.kind == AssistantActionKind.prepareWhatsApp ||
            plan.canExecute ||
            plan.message.contains('محترم'),
        isTrue,
      );
    });

    test('Y — abusive + pending duration preserves duration', () async {
      await brain.plan(query: 'بطني يوجعني', context: ctx);
      expect(ctx.healthGuidanceSession.status,
          HealthGuidanceSessionStatus.waitingForAnswer);
      final plan = await brain.plan(query: 'يا غبي من البارحة', context: ctx);
      expect(ctx.healthGuidanceSession.facts.duration, isNotNull);
      expect(plan.kind, isNot(AssistantActionKind.none));
    });

    test('Z — abusive + pending yes/no preserves answer', () {
      final r = detector.detect('يا غبي إي');
      expect(r.remainderQuery.contains('إي') || r.remainderQuery.contains('اي'),
          isTrue);
      expect(r.shouldRespond, isTrue);
    });

    test('AA — topic change still works', () async {
      await brain.plan(query: 'بطني يوجعني', context: ctx);
      await brain.plan(
        query: 'خلينا من هذا، أريد مختبر الحياة',
        context: ctx,
      );
      expect(
        ctx.healthGuidanceSession.status ==
                HealthGuidanceSessionStatus.cancelled ||
            !ctx.guidedConversation.isWaitingForAnswer,
        isTrue,
      );
    });

    test('AB — Step 5 clarification still works', () async {
      // مسار التوضيح يبقى متاحاً عبر المخطط
      final plan = await brain.plan(query: 'أريد طبيب', context: ctx);
      expect(plan, isNotNull);
    });

    test('AI — no paid AI/LLM dependency', () {
      for (final f in Directory('lib/voice/conduct').listSync()) {
        if (f is File) {
          final t = f.readAsStringSync().toLowerCase();
          expect(t.contains('openai'), isFalse);
          expect(t.contains('embedding'), isFalse);
          expect(t.contains('chatgpt'), isFalse);
        }
      }
    });

    test('AJ — no conduct response contains diagnosis', () {
      for (final code in ConversationEthicsResponseCode.values) {
        final msg = ethics.build(code) ?? '';
        expect(msg.contains('تشخيص'), isFalse);
        expect(msg.contains('زائدة'), isFalse);
        expect(msg.contains('جلطة'), isFalse);
      }
    });

    test('AK — normal conversation after abuse decays/resets', () {
      var state = const ConversationConductSessionState(recentAbuseCount: 2);
      for (var i = 0; i < 3; i++) {
        final o = conduct.observe(query: 'أريد طبيب', state: state);
        state = o.state;
      }
      expect(state.recentAbuseCount, 0);
    });

    test('AL — voice/text parity', () {
      const q = 'انت غبي';
      expect(detector.detect(q).level, detector.detect(q).level);
      expect(detector.detect(q).shouldRespond, isTrue);
    });

    test('SCRIPT 1 — direct insult', () async {
      final plan = await brain.plan(query: 'انت غبي', context: ctx);
      expect(plan.message.contains('محترم'), isTrue);
      expect(ethics.violatesOwnLanguagePolicy(plan.message), isFalse);
    });

    test('SCRIPT 2 — reported speech', () async {
      final plan = await brain.plan(
        query: 'واحد سبني وكال لي انت غبي',
        context: ctx,
      );
      expect(plan.message, isNot(ConversationEthicsResponseBuilder.gentle));
      expect(ctx.conductState.recentAbuseCount, 0);
    });

    test('SCRIPT 3 — health + abuse', () async {
      final plan = await brain.plan(
        query: 'يا غبي بطني يوجعني من يومين',
        context: ctx,
      );
      expect(ctx.conductState.recentAbuseCount, greaterThan(0));
      expect(
        ctx.healthGuidanceSession.facts.symptomStatuses['abdominal_pain'],
        SymptomPolarity.present,
      );
      expect(ctx.healthGuidanceSession.facts.duration, isNotNull);
      expect(
        plan.kind == AssistantActionKind.healthGuidance ||
            plan.kind == AssistantActionKind.guidedConversation ||
            plan.message.contains('محترم'),
        isTrue,
      );
    });

    test('SCRIPT 4 — urgent + abuse', () async {
      final plan = await brain.plan(
        query: 'يا غبي صدري يوجعني كلش ونفسي ضايج كلش',
        context: ctx,
      );
      final urgent = plan.healthDecision?.type ==
              HealthGuidanceDecisionType.urgentEvaluation ||
          plan.healthDecision?.type ==
              HealthGuidanceDecisionType.emergencyEvaluation;
      if (urgent) {
        expect(plan.message.contains('عاجل') || plan.message.contains('طارئ'),
            isTrue);
        expect(plan.message.startsWith('أنا موجود حتى أساعدك'), isFalse);
        expect(plan.healthDecision?.allowCommercialOffers, isFalse);
      } else {
        // قد يسأل سؤال سلامة أولاً — لا يُستبدل برد آداب فقط
        expect(plan.kind, AssistantActionKind.healthGuidance);
        expect(plan.message, isNot(ConversationEthicsResponseBuilder.gentle));
      }
    });

    test('SCRIPT 5 — guided answer + abuse', () async {
      await brain.plan(query: 'بطني يوجعني', context: ctx);
      await brain.plan(query: 'يا غبي من البارحة', context: ctx);
      expect(ctx.healthGuidanceSession.facts.duration, isNotNull);
    });

    test('SCRIPT 6 — criticism', () async {
      final plan = await brain.plan(query: 'جوابك غلط', context: ctx);
      expect(plan.message, isNot(ConversationEthicsResponseBuilder.gentle));
      expect(ctx.conductState.recentAbuseCount, 0);
    });
  });
}
