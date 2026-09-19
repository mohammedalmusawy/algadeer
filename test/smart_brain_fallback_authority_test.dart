import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_models.dart';
import 'package:ghadeer_clinic/health/understanding/health_understanding_engine.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/extracted_entities.dart';
import 'package:ghadeer_clinic/voice/intent/intent_result.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_fallback_policy.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late SmartBrainFallbackPolicy policy;
  late HealthUnderstandingEngine understanding;
  late List<String> orchestratorQueriesSeen;
  late List<String> medicalNavQueriesSeen;

  IntentResult intentOf(AssistantIntent i) => IntentResult(
        intent: i,
        originalText: '',
        normalizedText: '',
        searchMeaning: '',
        entities: const ExtractedEntities(),
        confidence: 1,
        requiresContext: false,
        source: IntentSource.rules,
      );

  AssistantActionPlan planOf(
    AssistantActionKind kind, {
    AssistantIntent intent = AssistantIntent.unknown,
    String message = '',
    HealthGuidanceDecision? health,
  }) {
    return AssistantActionPlan(
      kind: kind,
      intentResult: intentOf(intent),
      message: message,
      healthDecision: health,
    );
  }

  SmartSearchResult doc(String id, String title) => SmartSearchResult(
        type: SmartSearchResultType.doctor,
        title: title,
        subtitle: 'أطفال',
        doctorId: id,
        specialty: 'طب الأطفال',
        phone: '0700111001',
        whatsapp: '0700111001',
        clinicLocation: 'الكرادة',
        score: 90,
      );

  setUp(() {
    ctx = ConversationContext();
    understanding = HealthUnderstandingEngine();
    policy = SmartBrainFallbackPolicy(understanding: understanding);
    orchestratorQueriesSeen = [];
    medicalNavQueriesSeen = [];
    planner = SmartBrainPlanner(
      doctorLookup: (_) async => [
            doc('d1', 'دكتور أطفال أ'),
            doc('d2', 'دكتور أطفال ب'),
            doc('d3', 'دكتور أطفال ج'),
          ],
      labLookup: (_) async => [
            const SmartSearchResult(
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
      packagesForAnalysisLookup: (_) async => const [],
      activePackagesLookup: ({labId, nameQuery}) async => const [],
      discountedPackagesLookup: ({labId}) async => const [],
    );
  });

  Future<AssistantActionPlan> say(String q) =>
      planner.plan(query: q, context: ctx);

  SmartBrainFallbackDecision decideFor(String q, AssistantActionPlan plan) {
    // محاكاة: إن سمحت السياسة بـ orchestrator نُسجّل الاستعلام (يجب ألا يحدث).
    final d = policy.decide(query: q, plan: plan, context: ctx);
    if (d.allowLegacyOrchestrator) {
      orchestratorQueriesSeen.add(q);
    }
    if (!d.blockLegacyMedicalNavigation) {
      medicalNavQueriesSeen.add(q);
    }
    return d;
  }

  group('PC-0.1 Smart Brain fallback authority', () {
    test('A — health complaint never allows legacy orchestrator', () async {
      final plan = await say('ما اسمع زين وعندي صفير باذني');
      final d = decideFor('ما اسمع زين وعندي صفير باذني', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.blockLegacyMedicalNavigation, isTrue);
      expect(orchestratorQueriesSeen, isEmpty);
    });

    test('B — raw health text never reaches legacy AI fallback', () {
      final pageSrc =
          File('lib/search/smart_search_page.dart').readAsStringSync();
      expect(pageSrc.contains('processQuery('), isFalse);
      expect(pageSrc.contains('_runAuthoritativeSafeFallback'), isTrue);
      expect(
        pageSrc.contains('allowLegacyOrchestrator'),
        isTrue,
      );
    });

    test('C — medical safety query never opens MedicalNavigation fallback',
        () async {
      final plan = await say('صدري يوجعني كلش ونفسي ضايج كلش');
      final d = decideFor('صدري يوجعني كلش ونفسي ضايج كلش', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.blockLegacyMedicalNavigation, isTrue);
      expect(medicalNavQueriesSeen, isEmpty);
      expect(
        plan.kind == AssistantActionKind.healthGuidance ||
            plan.healthDecision != null,
        isTrue,
      );
    });

    test('D — health follow-up answer never escapes', () async {
      await say('بطني يوجعني');
      expect(ctx.guidedConversation.isWaitingForAnswer ||
          ctx.healthGuidanceSession.status ==
              HealthGuidanceSessionStatus.waitingForAnswer, isTrue);
      final plan = await say('البارحة');
      final d = decideFor('البارحة', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.blockLegacyMedicalNavigation, isTrue);
    });

    test('E — health correction never escapes', () async {
      await say('بطني يوجعني');
      final plan = await say('أقصد من أسبوع');
      final d = decideFor('أقصد من أسبوع', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
    });

    test('F — pending safety question never escapes', () async {
      // ألم صدر بدون شدة كافية → سؤال سلامة محتمل
      final p1 = await say('صدري يوجعني');
      if (ctx.healthGuidanceSession.status ==
          HealthGuidanceSessionStatus.waitingForAnswer) {
        final d = decideFor('صدري يوجعني', p1);
        expect(d.allowLegacyOrchestrator, isFalse);
        expect(d.brainOwned || d.blockLegacyMedicalNavigation, isTrue);
      } else {
        // حتى لو اتّخذ قراراً فورياً — لا orchestrator
        expect(decideFor('صدري يوجعني', p1).allowLegacyOrchestrator, isFalse);
      }
    });

    test('G — pending provider acceptance never escapes', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      expect(
        ctx.healthGuidanceSession.handoff.isAwaitingAcceptance,
        isTrue,
      );
      final pending = planOf(
        AssistantActionKind.none,
        intent: AssistantIntent.unknown,
      );
      final d = decideFor('ممم', pending);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.reasonCode, 'health_pending_authoritative');
    });

    test('H — doctor search uses authoritative pipeline', () async {
      final plan = await say('أريد طبيب أطفال');
      final d = decideFor('أريد طبيب أطفال', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(
        plan.kind == AssistantActionKind.runSpecialtySearch ||
            plan.kind == AssistantActionKind.runDoctorSearch ||
            plan.kind == AssistantActionKind.showClarification ||
            plan.candidates.isNotEmpty,
        isTrue,
      );
    });

    test('I — doctor ordinal uses authoritative pipeline', () async {
      await say('أريد طبيب أطفال');
      // محاكاة نتائج في السياق
      ctx.rememberResults(
        [
          doc('d1', 'دكتور أطفال أ'),
          doc('d2', 'دكتور أطفال ب'),
          doc('d3', 'دكتور أطفال ج'),
        ],
        intent: AssistantIntent.specialtySearch,
      );
      final plan = await say('الثاني');
      final d = decideFor('الثاني', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedDoctor?.doctorId, 'd2');
    });

    test('J — doctor call uses authoritative pipeline', () async {
      ctx.rememberResults(
        [doc('d1', 'دكتور أطفال أ'), doc('d2', 'دكتور أطفال ب')],
        intent: AssistantIntent.specialtySearch,
      );
      await say('الثاني');
      final plan = await say('اتصل بيه');
      final d = decideFor('اتصل بيه', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(plan.kind, AssistantActionKind.prepareCall);
    });

    test('K — doctor WhatsApp uses authoritative pipeline', () async {
      ctx.rememberResults(
        [doc('d1', 'دكتور أطفال أ'), doc('d2', 'دكتور أطفال ب')],
        intent: AssistantIntent.specialtySearch,
      );
      await say('الثاني');
      final plan = await say('دزله واتساب');
      final d = decideFor('دزله واتساب', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
    });

    test('L — laboratory query authoritative', () async {
      final plan = await say('أريد مختبر الحياة');
      final d = decideFor('أريد مختبر الحياة', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.blockLegacyMedicalNavigation, isTrue);
    });

    test('M — analysis query authoritative', () async {
      final plan = await say('أريد تحليل CBC');
      final d = decideFor('أريد تحليل CBC', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
    });

    test('N — package query authoritative', () async {
      final plan = await say('شنو الباقات؟');
      final d = decideFor('شنو الباقات؟', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
    });

    test('O — offer query authoritative', () async {
      final plan = await say('شنو العروض؟');
      final d = decideFor('شنو العروض؟', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
    });

    test('P — entity location does not use legacy navigation', () async {
      ctx.selectDoctor(doc('d2', 'دكتور أطفال ب'));
      final plan = await say('وين عيادته؟');
      final d = decideFor('وين عيادته؟', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.blockLegacyMedicalNavigation, isTrue);
      expect(
        plan.kind == AssistantActionKind.showLocation ||
            plan.message.contains('الكرادة') ||
            plan.target != null,
        isTrue,
      );
    });

    test('Q — pending clarification remains authoritative', () {
      ctx.setPendingClarification(
        PendingClarification(
          reason: ClarificationReason.multipleMatches,
          entityType: ClarificationEntityType.doctor,
          candidates: [
            ClarificationCandidate(
              id: 'd1',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: 'أ',
              payload: doc('d1', 'أ'),
            ),
            ClarificationCandidate(
              id: 'd2',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: 'ب',
              payload: doc('d2', 'ب'),
            ),
          ],
        ),
      );
      final d = decideFor(
        'ممم',
        planOf(AssistantActionKind.none),
      );
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.reasonCode, 'clarification_authoritative');
    });

    test('R — topic switch health → lab uses Smart Brain', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final plan = await say('لا، أريد مختبر الحياة');
      final d = decideFor('لا، أريد مختبر الحياة', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(
        plan.kind != AssistantActionKind.healthGuidance ||
            ctx.selectedLaboratory != null ||
            ctx.currentResultContext?.entityType ==
                ConversationEntityType.laboratory,
        isTrue,
      );
    });

    test('S — topic switch health → analysis uses Smart Brain', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final plan = await say('لا، أريد تحليل CBC');
      final d = decideFor('لا، أريد تحليل CBC', plan);
      expect(d.allowLegacyOrchestrator, isFalse);
    });

    test('T — unknown health → controlled safe result', () {
      const q = 'عندي شي غريب بجسمي وما أعرف أوصفه';
      // حتى لو المخطِّط أعاد none/general — السياسة تمنع legacy وتُرجع ردّاً مسيطراً.
      final synthetic = planOf(AssistantActionKind.runGeneralSearch);
      final d = decideFor(q, synthetic);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.blockLegacyMedicalNavigation, isTrue);
      if (understanding.looksLikeHealthLanguage(q)) {
        expect(d.controlledMessage, isNotNull);
        expect(d.allowGeneralSearch, isFalse);
        expect(
          d.controlledMessage!.contains('مصاب') ||
              d.controlledMessage!.contains('تشخيص'),
          isFalse,
        );
      }
    });

    test('U — no disease diagnosis introduced', () async {
      final plan = await say('عندي شي غريب بجسمي وما أعرف أوصفه');
      expect(plan.message.contains('سكري'), isFalse);
      expect(plan.message.contains('مصاب ب'), isFalse);
      final d = decideFor('عندي شي غريب بجسمي وما أعرف أوصفه', plan);
      expect((d.controlledMessage ?? '').contains('تشخيص'), isFalse);
    });

    test('V — no specialty invented by fallback', () {
      final d = decideFor(
        'عندي شي غريب بجسمي وما أعرف أوصفه',
        planOf(AssistantActionKind.none),
      );
      expect(d.allowLegacyOrchestrator, isFalse);
      final msg = d.controlledMessage ?? '';
      expect(msg.contains('أنف وأذن'), isFalse);
      expect(msg.contains('قلب'), isFalse);
    });

    test('W — general non-medical search remains functional', () {
      final d = decideFor(
        'شنو الخدمات الموجودة بالتطبيق؟',
        planOf(
          AssistantActionKind.runGeneralSearch,
          intent: AssistantIntent.generalSearch,
        ),
      );
      expect(d.allowGeneralSearch, isTrue);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.brainOwned, isFalse);
    });

    test('X — SmartSearchService data search remains allowed', () {
      final d = decideFor(
        'دكتور علي',
        planOf(
          AssistantActionKind.runDoctorSearch,
          intent: AssistantIntent.doctorSearch,
        ),
      );
      expect(d.allowGeneralSearch, isTrue);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.reasonCode, anyOf('entity_search_data_only', 'planner_search_data_only'));
    });

    test('Y — orchestrator cannot remain as health/entity authority', () {
      // السياسة الافتراضية لا تسمح أبداً بـ allowLegacyOrchestrator=true.
      for (final kind in AssistantActionKind.values) {
        final d = policy.decide(
          query: 'اختبار',
          plan: planOf(kind),
          context: ConversationContext(),
        );
        expect(d.allowLegacyOrchestrator, isFalse, reason: kind.name);
      }
    });

    test('Z — AssistantIntegrationPage isolated from SmartSearchPage', () {
      final page = File('lib/search/smart_search_page.dart').readAsStringSync();
      final integration =
          File('lib/voice/assistant_integration_page.dart').readAsStringSync();
      expect(page.contains('processQuery('), isFalse);
      expect(integration.contains('processQuery'), isTrue);
      expect(integration.contains('SmartBrainPlanner'), isFalse);
    });

    test('AA — Step 10E safety remains authoritative', () async {
      final plan = await say('صدري يوجعني كلش ونفسي ضايج كلش');
      expect(
        plan.healthDecision?.type ==
                HealthGuidanceDecisionType.urgentEvaluation ||
            plan.healthDecision?.type ==
                HealthGuidanceDecisionType.emergencyEvaluation ||
            plan.healthDecision?.type ==
                HealthGuidanceDecisionType.needMoreInformation ||
            plan.kind == AssistantActionKind.healthGuidance,
        isTrue,
      );
      expect(decideFor('صدري يوجعني كلش ونفسي ضايج كلش', plan).allowLegacyOrchestrator,
          isFalse);
    });

    test('AB — Step 10E.1 ethics remains authoritative', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final plan = await say('إي يا غبي');
      expect(decideFor('إي يا غبي', plan).allowLegacyOrchestrator, isFalse);
      expect(
        ctx.healthGuidanceSession.handoff.status,
        anyOf(
          HealthGuidanceHandoffStatus.providersDisplayed,
          HealthGuidanceHandoffStatus.completed,
          HealthGuidanceHandoffStatus.empty,
          HealthGuidanceHandoffStatus.accepted,
        ),
      );
    });

    test('AC — Step 10F provider handoff remains authoritative', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      expect(
        ctx.healthGuidanceSession.handoff.status,
        HealthGuidanceHandoffStatus.awaitingAcceptance,
      );
      final plan = await say('إي');
      expect(decideFor('إي', plan).allowLegacyOrchestrator, isFalse);
    });

    test('AD — voice/text parity after transcript (same policy)', () {
      final plan = planOf(
        AssistantActionKind.runDoctorSearch,
        intent: AssistantIntent.doctorSearch,
      );
      final typed = policy.decide(
        query: 'دكتور أحمد',
        plan: plan,
        context: ConversationContext(),
      );
      final voice = policy.decide(
        query: 'دكتور أحمد',
        plan: plan,
        context: ConversationContext(),
      );
      expect(typed.allowLegacyOrchestrator, voice.allowLegacyOrchestrator);
      expect(typed.allowGeneralSearch, voice.allowGeneralSearch);
      expect(typed.reasonCode, voice.reasonCode);
    });

    test('AE — no paid dependency added', () {
      final src = File('lib/voice/intent/smart_brain_fallback_policy.dart')
          .readAsStringSync();
      expect(src.toLowerCase().contains('openai'), isFalse);
      expect(src.toLowerCase().contains('embedding'), isFalse);
    });

    test('AF — no persistent raw query logging added', () {
      final page = File('lib/search/smart_search_page.dart').readAsStringSync();
      final policySrc =
          File('lib/voice/intent/smart_brain_fallback_policy.dart')
              .readAsStringSync();
      expect(policySrc.contains('SharedPreferences'), isFalse);
      expect(page.contains('_runAuthoritativeSafeFallback'), isTrue);
      // لا نمرّر الاستعلام لـ processQuery بعد الآن.
      expect(page.contains('processQuery('), isFalse);
    });
  });

  group('PC-0.1 Scripts', () {
    test('SCRIPT 1 — health unknown controlled', () async {
      const q = 'عندي شي غريب بجسمي وما أعرف أوصفه';
      expect(understanding.looksLikeHealthLanguage(q), isTrue);
      final plan = await say(q);
      final d = decideFor(q, plan);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(d.blockLegacyMedicalNavigation, isTrue);
      final msg = [
        plan.message,
        d.controlledMessage ?? '',
      ].join(' ');
      expect(msg.trim().isNotEmpty, isTrue);
      expect(msg.contains('MedicalNavigation'), isFalse);
      expect(msg.contains('مصاب ب'), isFalse);
    });

    test('SCRIPT 2 — health follow-up bar7a', () async {
      await say('بطني يوجعني');
      final plan = await say('البارحة');
      expect(decideFor('البارحة', plan).allowLegacyOrchestrator, isFalse);
      expect(plan.kind, isNot(AssistantActionKind.runGeneralSearch));
    });

    test('SCRIPT 3 — entity pipeline', () async {
      await say('أريد طبيب أطفال');
      ctx.rememberResults(
        [
          doc('d1', 'دكتور أطفال أ'),
          doc('d2', 'دكتور أطفال ب'),
        ],
        intent: AssistantIntent.specialtySearch,
      );
      await say('الثاني');
      expect(ctx.selectedDoctor?.doctorId, 'd2');
      final call = await say('اتصل بيه');
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(decideFor('اتصل بيه', call).allowLegacyOrchestrator, isFalse);
    });

    test('SCRIPT 4 — general non-medical', () {
      final d = decideFor(
        'شنو الخدمات الموجودة بالتطبيق؟',
        planOf(
          AssistantActionKind.runGeneralSearch,
          intent: AssistantIntent.generalSearch,
        ),
      );
      expect(d.allowGeneralSearch, isTrue);
      expect(d.allowLegacyOrchestrator, isFalse);
      expect(understanding.looksLikeHealthLanguage('شنو الخدمات الموجودة بالتطبيق؟'),
          isFalse);
    });
  });
}
