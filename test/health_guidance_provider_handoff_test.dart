import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/specialty_catalog.dart';
import 'package:ghadeer_clinic/health/guidance/guidance_provider_discovery_service.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_coordinator.dart';
import 'package:ghadeer_clinic/health/guidance/health_guidance_models.dart';
import 'package:ghadeer_clinic/health/guidance/local_health_guidance_rules.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/conversation_reference_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/result_context.dart';

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late List<SmartSearchResult> entDoctors;
  late int doctorLookupCalls;
  late int labLookupCalls;

  SmartSearchResult doc({
    required String id,
    required String title,
    String specialty = 'الأنف والأذن والحنجرة',
    String? phone,
    String? whatsapp,
    String? clinicLocation,
    int score = 80,
  }) {
    return SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: specialty,
      doctorId: id,
      specialty: specialty,
      phone: phone,
      whatsapp: whatsapp,
      clinicLocation: clinicLocation,
      score: score,
    );
  }

  setUp(() {
    ctx = ConversationContext();
    doctorLookupCalls = 0;
    labLookupCalls = 0;
    entDoctors = [
      doc(
        id: 'ent1',
        title: 'دكتور أذن أول',
        phone: '0700111001',
        whatsapp: '0700111001',
        clinicLocation: 'الكرادة',
        score: 95,
      ),
      doc(
        id: 'ent2',
        title: 'دكتور أذن ثاني',
        phone: '0700222002',
        whatsapp: '0700222002',
        clinicLocation: 'المنصور',
        score: 90,
      ),
      doc(
        id: 'ent3',
        title: 'دكتور أذن ثالث',
        phone: '0700333003',
        whatsapp: '0700333003',
        clinicLocation: 'الجادرية',
        score: 85,
      ),
    ];

    planner = SmartBrainPlanner(
      doctorLookup: (q) async {
        doctorLookupCalls++;
        return List<SmartSearchResult>.from(entDoctors);
      },
      labLookup: (q) async {
        labLookupCalls++;
        return [
          const SmartSearchResult(
            type: SmartSearchResultType.lab,
            title: 'مختبر الحياة',
            subtitle: 'مختبر',
            labId: 'hayat',
            score: 90,
          ),
        ];
      },
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

  group('10F Provider handoff', () {
    test('A — ENT guidance creates awaitingAcceptance handoff', () async {
      final plan = await say('ما اسمع زين وعندي صفير باذني');
      expect(plan.kind, AssistantActionKind.healthGuidance);
      expect(plan.healthDecision?.destination?.specialtyCatalogId, 'ent');
      expect(
        ctx.healthGuidanceSession.handoff.status,
        HealthGuidanceHandoffStatus.awaitingAcceptance,
      );
      expect(plan.message.contains('تريد أعرض لك الأطباء'), isTrue);
    });

    test('B — no provider query before user accepts', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      expect(doctorLookupCalls, 0);
    });

    test('C — إي accepts using 10A normalizer', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final plan = await say('إي');
      expect(
        ctx.healthGuidanceSession.handoff.status,
        anyOf(
          HealthGuidanceHandoffStatus.providersDisplayed,
          HealthGuidanceHandoffStatus.completed,
        ),
      );
      expect(doctorLookupCalls, greaterThan(0));
      expect(plan.candidates, isNotEmpty);
    });

    test('D — لا declines without provider search', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final before = doctorLookupCalls;
      final plan = await say('لا');
      expect(doctorLookupCalls, before);
      expect(
        ctx.healthGuidanceSession.handoff.status,
        HealthGuidanceHandoffStatus.declined,
      );
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
    });

    test('E — accepted ENT delegates to existing doctor architecture', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      expect(ctx.currentResultContext?.entityType, ConversationEntityType.doctor);
      final ent = SpecialtyCatalog.all.firstWhere((s) => s.id == 'ent');
      expect(
        ctx.sessionSpecialtyLabel,
        anyOf(ent.nameAr, contains('أنف')),
      );
    });

    test('F — no hardcoded doctor name in health rules/handoff', () {
      final blob = LocalHealthGuidanceRuleSource()
          .enabledRulesSync()
          .map((r) => '${r.id} ${r.rationaleCode} ${r.destination.displayNameAr}')
          .join(' ');
      expect(blob.contains('دكتور أذن أول'), isFalse);
      expect(blob.contains('ناصر'), isFalse);
      expect(File('lib/health/guidance/health_guidance_handoff.dart')
          .readAsStringSync()
          .contains('دكتور أذن'), isFalse);
    });

    test('G — zero real providers → truthful empty', () async {
      planner = SmartBrainPlanner(
        doctorLookup: (q) async {
          doctorLookupCalls++;
          return const [];
        },
      );
      ctx = ConversationContext();
      await planner.plan(
        query: 'ما اسمع زين وعندي صفير باذني',
        context: ctx,
      );
      final plan = await planner.plan(query: 'إي', context: ctx);
      expect(plan.message.contains('ما ظهر عندي طبيب'), isTrue);
      expect(plan.candidates, isEmpty);
      expect(
        ctx.healthGuidanceSession.handoff.status,
        HealthGuidanceHandoffStatus.empty,
      );
    });

    test('H — one provider → real result, no auto-contact', () async {
      planner = SmartBrainPlanner(
        doctorLookup: (_) async => [entDoctors.first],
      );
      ctx = ConversationContext();
      await planner.plan(
        query: 'ما اسمع زين وعندي صفير باذني',
        context: ctx,
      );
      final plan = await planner.plan(query: 'إي', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.kind, isNot(AssistantActionKind.prepareWhatsApp));
      expect(ctx.selectedDoctor?.doctorId, 'ent1');
      expect(plan.message.toLowerCase().contains('أفضل'), isFalse);
    });

    test('I — multiple providers → typed doctor ResultContext', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      expect(ctx.currentResultContext?.entityType, ConversationEntityType.doctor);
      expect(ctx.currentResultContext!.length, greaterThanOrEqualTo(2));
    });

    test('J — الثاني after handoff selects second doctor', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      final plan = await say('الثاني');
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedDoctor?.doctorId, 'ent2');
      expect(ctx.activeEntityType, ConversationEntityType.doctor);
    });

    test('K — وين عيادته؟ uses selected doctor', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      await say('الثاني');
      final plan = await say('وين عيادته؟');
      expect(
        plan.kind == AssistantActionKind.showLocation ||
            (plan.message.contains('المنصور')),
        isTrue,
      );
      expect(ctx.selectedDoctor?.clinicLocation, 'المنصور');
    });

    test('L — اتصل بيه uses existing contact path', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      await say('الثاني');
      final plan = await say('اتصل بيه');
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'ent2');
    });

    test('M — دزله واتساب uses existing WhatsApp path', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      await say('الثاني');
      final plan = await say('دزله واتساب');
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.whatsapp, '0700222002');
    });

    test('N — no centralized Ghadeer WhatsApp sender introduced', () {
      final discovery = File(
        'lib/health/guidance/guidance_provider_discovery_service.dart',
      ).readAsStringSync();
      expect(discovery.contains('WhatsApp Business'), isFalse);
      expect(discovery.contains('waba'), isFalse);
      expect(discovery.contains('sendWhatsApp'), isFalse);
    });

    test('O — no appointment slot invented', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final plan = await say('إي');
      expect(plan.message.contains('موعد متاح الساعة'), isFalse);
      expect(plan.message.contains('الساعة'), isFalse);
    });

    test('P — no best-doctor-for-condition text', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final plan = await say('إي');
      expect(plan.message.contains('أفضل طبيب'), isFalse);
      expect(plan.message.contains('أنصحك بالدكتور'), isFalse);
      expect(plan.message.contains('ضمن الاختصاص في بيانات الغدير'), isTrue);
    });

    test('Q — urgent safety blocks ordinary provider handoff', () async {
      final plan = await say('صدري يوجعني كلش ونفسي ضايج كلش');
      expect(plan.kind, AssistantActionKind.healthGuidance);
      expect(
        plan.healthDecision?.type,
        anyOf(
          HealthGuidanceDecisionType.urgentEvaluation,
          HealthGuidanceDecisionType.emergencyEvaluation,
          HealthGuidanceDecisionType.needMoreInformation,
        ),
      );
      if (plan.healthDecision?.type ==
              HealthGuidanceDecisionType.urgentEvaluation ||
          plan.healthDecision?.type ==
              HealthGuidanceDecisionType.emergencyEvaluation) {
        expect(
          ctx.healthGuidanceSession.handoff.status,
          HealthGuidanceHandoffStatus.inactive,
        );
        expect(plan.message.contains('تريد أعرض لك الأطباء'), isFalse);
        expect(doctorLookupCalls, 0);
      }
    });

    test('R — emergency result blocks commercial provider handoff', () async {
      final coord = HealthGuidanceCoordinator();
      final result = coord.startFromUserText(
        query: 'صدري يوجعني كلش ونفسي ضايج كلش',
        current: HealthGuidanceSession.inactive,
        turnId: 1,
      );
      if (result.decision?.type ==
              HealthGuidanceDecisionType.emergencyEvaluation ||
          result.decision?.type ==
              HealthGuidanceDecisionType.urgentEvaluation) {
        expect(result.runProviderDiscovery, isFalse);
        expect(
          result.session.handoff.status,
          HealthGuidanceHandoffStatus.inactive,
        );
      }
    });

    test('S — urgent blocks package/offer suggestions', () async {
      await say('صدري يوجعني كلش ونفسي ضايج كلش');
      final dec = ctx.healthGuidanceSession.currentDecision;
      if (dec?.type == HealthGuidanceDecisionType.urgentEvaluation ||
          dec?.type == HealthGuidanceDecisionType.emergencyEvaluation) {
        final plan = await say('شنو الباقات؟');
        expect(plan.kind, isNot(AssistantActionKind.showOffers));
        expect(plan.kind, isNot(AssistantActionKind.runPackageSearch));
        expect(plan.message.contains('باقة مناسبة'), isFalse);
      }
    });

    test('T — conduct phrase + إي still preserves acceptance', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final plan = await say('إي يا غبي');
      expect(doctorLookupCalls, greaterThan(0));
      expect(
        ctx.healthGuidanceSession.handoff.status,
        anyOf(
          HealthGuidanceHandoffStatus.providersDisplayed,
          HealthGuidanceHandoffStatus.completed,
        ),
      );
      expect(plan.candidates.isNotEmpty || ctx.selectedDoctor != null, isTrue);
    });

    test('U — topic switch to laboratory during confirmation', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final before = doctorLookupCalls;
      final plan = await say('لا، أريد مختبر الحياة');
      expect(doctorLookupCalls, before);
      expect(
        plan.kind == AssistantActionKind.runLabSearch ||
            plan.kind == AssistantActionKind.selectEntity ||
            plan.candidates.any((c) => c.type == SmartSearchResultType.lab) ||
            ctx.selectedLaboratory != null ||
            ctx.currentResultContext?.entityType ==
                ConversationEntityType.laboratory,
        isTrue,
      );
    });

    test('V — topic switch to analysis reaches Step 7', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final plan = await say('لا، أريد تحليل CBC');
      expect(
        plan.intentResult.intent == AssistantIntent.findAnalysis ||
            plan.kind == AssistantActionKind.runAnalysisSearch ||
            plan.kind == AssistantActionKind.showPackagesContainingAnalysis ||
            plan.kind == AssistantActionKind.selectEntity ||
            ctx.activeEntityType == ConversationEntityType.analysis ||
            ctx.currentResultContext?.entityType ==
                ConversationEntityType.analysis,
        isTrue,
      );
    });

    test('W — explicit package request reaches Step 8 where safe', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      await say('الثاني');
      // بعد اكتمال التسليم — طلب باقات صريح مسموح (ليس من الأعراض).
      final plan = await say('شنو الباقات؟');
      expect(plan.message.contains('مصاب'), isFalse);
      expect(
        plan.kind == AssistantActionKind.showOffers ||
            plan.kind == AssistantActionKind.runPackageSearch ||
            plan.kind == AssistantActionKind.showMessage ||
            plan.kind == AssistantActionKind.showLabPackages,
        isTrue,
      );
    });

    test('X — health guidance never automatically recommends package', () async {
      final plan = await say('ما اسمع زين وعندي صفير باذني');
      expect(plan.message.contains('باقة'), isFalse);
      expect(plan.healthDecision?.type,
          isNot(HealthGuidanceDecisionType.unableToDetermine));
    });

    test('Y — health guidance never automatically recommends analysis', () async {
      final plan = await say('ما اسمع زين وعندي صفير باذني');
      expect(plan.message.toLowerCase().contains('cbc'), isFalse);
      expect(plan.message.contains('تحليل'), isFalse);
    });

    test('Z — health guidance never automatically recommends imaging', () async {
      final plan = await say('ما اسمع زين وعندي صفير باذني');
      expect(plan.message.contains('أشعة'), isFalse);
      expect(plan.message.contains('رنين'), isFalse);
      expect(plan.message.contains('مفراس'), isFalse);
    });

    test('AA — provider results use existing entity models', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      expect(ctx.currentResultContext!.items.first, isA<SmartSearchResult>());
      expect(
        ctx.currentResultContext!.items.first.type,
        SmartSearchResultType.doctor,
      );
    });

    test('AB — provider results populate Step 9 ResultContext', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      expect(ctx.currentResultContext, isNotNull);
      expect(ctx.currentResultContext!.entityType, ConversationEntityType.doctor);
    });

    test('AC — ConversationReferenceResolver remains authoritative', () {
      expect(const ConversationReferenceResolver(), isNotNull);
      expect(
        File('lib/voice/intent/smart_brain_planner.dart')
            .readAsStringSync()
            .contains('ConversationReferenceResolver'),
        isTrue,
      );
    });

    test('AD — EntityActionCompatibility remains authoritative', () {
      expect(
        EntityActionCompatibility.supportsCall(ConversationEntityType.doctor),
        isTrue,
      );
      expect(
        EntityActionCompatibility.supportsWhatsApp(
          ConversationEntityType.doctor,
        ),
        isTrue,
      );
    });

    test('AE — handoff does not destroy previous entity selections', () async {
      await planner.plan(query: 'أريد مختبر الحياة', context: ctx);
      final labId = ctx.selectedLaboratory?.labId ??
          ctx.currentResultContext?.items.first.labId;
      expect(labId, isNotNull);
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      // اختيار المختبر السابق لا يُمسَح بلا داعٍ عند نتائج أطباء فقط.
      expect(
        ctx.selectedLaboratory?.labId == labId ||
            ctx.lastLabSnapshot.any((l) => l.labId == labId),
        isTrue,
      );
    });

    test('AF — selecting new doctor makes doctor active', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      await say('الثاني');
      expect(ctx.activeEntityType, ConversationEntityType.doctor);
      expect(ctx.selectedDoctor?.doctorId, 'ent2');
    });

    test('AG — health follow-up stops after provider handoff completion', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي');
      await say('الثاني');
      expect(
        ctx.healthGuidanceSession.status,
        HealthGuidanceSessionStatus.completed,
      );
      expect(
        ctx.healthGuidanceSession.handoff.status,
        HealthGuidanceHandoffStatus.completed,
      );
      expect(ctx.healthGuidanceSession.status,
          isNot(HealthGuidanceSessionStatus.waitingForAnswer));
    });

    test('AH — no raw symptom in provider analytics path', () {
      final plannerSrc =
          File('lib/voice/intent/smart_brain_planner.dart').readAsStringSync();
      expect(
        plannerSrc.contains('_runAcceptedProviderDiscovery'),
        isTrue,
      );
      // لا نمرّر نص الأعراض إلى rememberResults من مسار التسليم.
      expect(
        RegExp(r'rememberResults\([\s\S]{0,120}symptom').hasMatch(plannerSrc),
        isFalse,
      );
    });

    test('AI — no raw health answer persisted', () {
      final snap = ctx.healthGuidanceSession.debugSnapshot();
      expect(snap.containsKey('rawAnswer'), isFalse);
      expect(snap.values.any((v) => '$v'.contains('صفير')), isFalse);
    });

    test('AJ — debug snapshot contains no raw health text', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final snap = ctx.debugSnapshot();
      expect(snap['handoffStatus'], isNotNull);
      expect('$snap'.contains('صفير'), isFalse);
      expect('$snap'.contains('ما اسمع'), isFalse);
    });

    test('AK — laboratory destination architecture delegates to lab resolver',
        () async {
      final discovery = GuidanceProviderDiscoveryService(
        labLookup: (q) async {
          labLookupCalls++;
          return [
            const SmartSearchResult(
              type: SmartSearchResultType.lab,
              title: 'مختبر الحياة',
              subtitle: 'مختبر',
              labId: 'hayat',
              score: 90,
            ),
          ];
        },
      );
      final dest = const GuidanceDestination(
        type: GuidanceDestinationType.laboratory,
        key: 'laboratory',
        displayNameAr: 'مختبر',
      );
      final result = await discovery.discoverLaboratories(destination: dest);
      expect(result.entityType, ConversationEntityType.laboratory);
      expect(result.items.first, isA<SmartSearchResult>());
      expect(labLookupCalls, 1);
    });

    test('AL — unsupported diagnostic destination returns unsupported', () async {
      final discovery = GuidanceProviderDiscoveryService(
        doctorLookup: (_) async => entDoctors,
      );
      final dest = const GuidanceDestination(
        type: GuidanceDestinationType.diagnosticService,
        key: 'diagnostic_service',
        displayNameAr: 'خدمة تشخيصية',
      );
      final result = await discovery.discover(dest);
      expect(result.status, ProviderDiscoveryStatus.unsupported);
      expect(result.items, isEmpty);
    });

    test('AM — radiology/CT/MRI types representable without symptom recommendations',
        () {
      expect(GuidanceDestinationType.radiologyReserved, isNotNull);
      expect(GuidanceDestinationType.ctReserved, isNotNull);
      expect(GuidanceDestinationType.mriReserved, isNotNull);
      expect(GuidanceDestinationType.ultrasoundReserved, isNotNull);
      expect(GuidanceDestinationType.diagnosticService, isNotNull);
    });

    test('AN — doctor status semantics not converted to fake availability',
        () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final plan = await say('إي');
      expect(plan.message.contains('متاح الآن'), isFalse);
      expect(plan.message.contains('available now'), isFalse);
    });

    test('AO — voice/text parity (same planner entry)', () async {
      final t1 = await say('ما اسمع زين وعندي صفير باذني');
      final ctx2 = ConversationContext();
      final t2 = await planner.plan(
        query: 'ما اسمع زين وعندي صفير باذني',
        context: ctx2,
      );
      expect(t1.kind, t2.kind);
      expect(
        t1.healthDecision?.destination?.specialtyCatalogId,
        t2.healthDecision?.destination?.specialtyCatalogId,
      );
    });
  });

  group('10F Scripts', () {
    test('SCRIPT 1 — complete handoff', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      expect(
        ctx.healthGuidanceSession.handoff.status,
        HealthGuidanceHandoffStatus.awaitingAcceptance,
      );
      await say('إي');
      expect(ctx.currentResultContext?.entityType, ConversationEntityType.doctor);
      await say('الثاني');
      expect(ctx.selectedDoctor?.doctorId, 'ent2');
      final loc = await say('وين عيادته؟');
      expect(
        loc.kind == AssistantActionKind.showLocation ||
            loc.message.contains('المنصور'),
        isTrue,
      );
      final call = await say('اتصل بيه');
      expect(call.kind, AssistantActionKind.prepareCall);
    });

    test('SCRIPT 2 — decline', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final before = doctorLookupCalls;
      await say('لا');
      expect(doctorLookupCalls, before);
      expect(
        ctx.healthGuidanceSession.handoff.status,
        HealthGuidanceHandoffStatus.declined,
      );
      final later = await say('أريد مختبر الحياة');
      expect(later.kind, isNot(AssistantActionKind.none));
    });

    test('SCRIPT 3 — topic change to CBC', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      final plan = await say('لا، أريد تحليل CBC');
      expect(doctorLookupCalls, 0);
      expect(
        plan.intentResult.intent == AssistantIntent.findAnalysis ||
            ctx.activeEntityType == ConversationEntityType.analysis ||
            ctx.currentResultContext?.entityType ==
                ConversationEntityType.analysis ||
            plan.kind == AssistantActionKind.runAnalysisSearch ||
            plan.kind == AssistantActionKind.showPackagesContainingAnalysis ||
            plan.kind == AssistantActionKind.selectEntity,
        isTrue,
      );
    });

    test('SCRIPT 4 — ethics + acceptance', () async {
      await say('ما اسمع زين وعندي صفير باذني');
      await say('إي يا غبي');
      expect(doctorLookupCalls, greaterThan(0));
    });

    test('SCRIPT 5 — urgent firewall', () async {
      final plan = await say('صدري يوجعني كلش ونفسي ضايج كلش');
      if (plan.healthDecision?.allowCommercialOffers == false) {
        expect(plan.message.contains('عرض'), isFalse);
        expect(plan.message.contains('باقة'), isFalse);
        expect(
          ctx.healthGuidanceSession.handoff.isAwaitingAcceptance,
          isFalse,
        );
      }
    });

    test('SCRIPT 6 — zero results', () async {
      planner = SmartBrainPlanner(
        doctorLookup: (_) async => const [],
      );
      ctx = ConversationContext();
      await planner.plan(
        query: 'ما اسمع زين وعندي صفير باذني',
        context: ctx,
      );
      final plan = await planner.plan(query: 'إي', context: ctx);
      expect(plan.message.contains('ما ظهر عندي طبيب'), isTrue);
      expect(plan.candidates, isEmpty);
    });
  });
}
