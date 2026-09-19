import 'dart:async';

import '../../companion/companion_onboarding_coordinator.dart';
import '../../companion/companion_onboarding_models.dart';
import '../../companion/companion_profile_command_coordinator.dart';
import '../../companion/people/family_profile_command_coordinator.dart';
import '../../companion/people/subject_binding/subject_binding_coordinator.dart';
import '../../companion/people/subject_binding/subject_binding_models.dart';
import '../../companion/personal_companion_profile.dart';
import '../../companion/owner_profile_context_bridge.dart';
import '../../companion/ghadeer_identity.dart';
import '../../companion/ghadeer_social_conversation.dart';
import '../../companion/personal_memory/personal_memory_coordinator.dart';
import '../startup_greeting.dart';
import '../../companion/personalization/natural_recall_response_decorator.dart';
import '../../companion/personalization/personalization_coordinator.dart';
import '../../companion/personalization/personalization_models.dart';
import '../../companion/personalization/personalization_privacy_policy.dart';
import '../../daily_context/daily_context_coordinator.dart';
import '../../clinical_knowledge/clinical_knowledge_coordinator.dart';
import '../../clinical_knowledge/packs/musculoskeletal/msk_guidance_coordinator.dart';
import '../../clinical_knowledge/packs/respiratory/respiratory_guidance_coordinator.dart';
import '../../clinical_knowledge/packs/respiratory/respiratory_models.dart';
import '../../clinical_knowledge/packs/chronic_care/chronic_care_coordinator.dart';
import '../../clinical_knowledge/packs/pregnancy_companion/pregnancy_companion_coordinator.dart';
import '../../clinical_knowledge/packs/dental/dental_guidance_coordinator.dart';
import '../../companion/adolescent/adolescent_companion_coordinator.dart';
import '../../nlu/nlu.dart';
import '../../unified_brain/unified_brain.dart';
import '../../wellbeing_planner/wellbeing_planner_coordinator.dart';
import '../../health/chronic_care/chronic_care_coordinator.dart';
import '../../health/emotional_support/emotional_support_coordinator.dart';
import '../../health/emotional_support/emotional_support_models.dart';
import '../../health/preventive/preventive_guidance_coordinator.dart';
import '../../follow_up/follow_up_coordinator.dart';
import '../../follow_up/follow_up_models.dart';
import '../../follow_up/follow_up_service.dart';
import '../../wellness/wellness_coordinator.dart';
import '../../health/family_sensitive/family_health_command_coordinator.dart';
import '../../health/sensitive_profile/sensitive_health_profile_coordinator.dart';
import '../../labs/labs_service.dart';
import '../../models/lab_models.dart';
import '../../search/analysis_name_matcher.dart';
import '../../search/arabic_text_utils.dart';
import '../../search/doctor_name_matcher.dart';
import '../../search/laboratory_name_matcher.dart';
import '../../search/package_name_matcher.dart';
import '../../search/smart_search_models.dart';
import '../../search/smart_search_service.dart';
import '../../search/voice_specialty_search_command.dart';
import '../arabic_speech_numbers.dart';
import '../clarification/ambiguity_gate.dart';
import '../clarification/clarification_models.dart';
import '../clarification/clarification_resolver.dart';
import '../clarification/clarification_response_builder.dart';
import '../context_resolver.dart';
import '../conversation_context.dart';
import '../conversation_reference_resolver.dart';
import '../entity_relationship_resolver.dart';
import '../ghadeer_followup_context.dart';
import '../conduct/conversation_conduct_coordinator.dart';
import '../guided_conversation/arabic_answer_normalizer.dart';
import '../guided_conversation/guided_conversation_engine.dart';
import '../guided_conversation/guided_conversation_models.dart';
import '../guided_conversation/guided_topic_change_detector.dart';
import '../../health/guidance/guidance_provider_discovery_service.dart';
import '../../health/guidance/health_guidance_coordinator.dart';
import '../../health/guidance/health_guidance_models.dart';
import '../../health/subject/health_subject_models.dart';
import '../result_context.dart';
import 'analysis_target_resolver.dart';
import 'assistant_intent.dart';
import 'doctor_target_resolver.dart';
import 'entity_target_resolver.dart';
import 'intent_resolver.dart';
import 'intent_result.dart';
import 'laboratory_target_resolver.dart';
import 'package_target_resolver.dart';

/// نوع إجراء مخطَّط — الواجهة تنفّذ عبر الآليات الحالية فقط.
enum AssistantActionKind {
  none,
  showMessage,
  showClarification,
  selectEntity,
  showLocation,
  openProfile,
  prepareCall,
  prepareWhatsApp,
  runSpecialtySearch,
  runDoctorSearch,
  runLabSearch,
  runAnalysisSearch,
  runGeneralSearch,
  showLabPackages,
  showLabAnalyses,
  showPackagesContainingAnalysis,
  showLabsViaAnalysisPackages,
  showPackagePrice,
  showPackageAnalyses,
  showPackageComparison,
  showOffers,
  runPackageSearch,
  guidedConversation,
  healthGuidance,
}

/// خطة فعل خفيفة — لا تطلق UI بنفسها.
class AssistantActionPlan {
  const AssistantActionPlan({
    required this.kind,
    required this.intentResult,
    this.target,
    this.candidates = const [],
    this.message = '',
    this.specialtyQuery,
    this.doctorQuery,
    this.labQuery,
    this.analysisQuery,
    this.canExecute = false,
    this.contextResolution,
    this.targetResolution,
    this.labTargetResolution,
    this.analysisTargetResolution,
    this.packageTargetResolution,
    this.packages = const [],
    this.analyses = const [],
    this.guidedResponse,
    this.healthDecision,
    this.textFirstOnly = false,
  });

  final AssistantActionKind kind;
  final IntentResult intentResult;
  final SmartSearchResult? target;
  final List<SmartSearchResult> candidates;
  final String message;
  final String? specialtyQuery;
  final String? doctorQuery;
  final String? labQuery;
  final String? analysisQuery;
  final bool canExecute;
  final ContextResolution? contextResolution;
  final DoctorTargetResolution? targetResolution;
  final LaboratoryTargetResolution? labTargetResolution;
  final AnalysisTargetResolution? analysisTargetResolution;
  final PackageTargetResolution? packageTargetResolution;
  final List<LabPackageItem> packages;
  final List<AnalysisItem> analyses;
  final GuidedConversationResponse? guidedResponse;
  final HealthGuidanceDecision? healthDecision;

  /// Companion profile/onboarding: نص أولاً — بلا نطق تلقائي.
  final bool textFirstOnly;

  bool get isAmbiguous => kind == AssistantActionKind.showClarification;
  bool get isMissingContext =>
      kind == AssistantActionKind.showMessage &&
      intentResult.requiresContext &&
      target == null &&
      candidates.isEmpty;
}

typedef SmartBrainDoctorLookup = Future<List<SmartSearchResult>> Function(
  String query,
);

typedef SmartBrainLabLookup = Future<List<SmartSearchResult>> Function(
  String query,
);

typedef SmartBrainLabPackagesLookup = Future<List<LabPackageItem>> Function(
  String labId,
);

typedef SmartBrainAnalysisLookup = Future<List<AnalysisItem>> Function(
  String query,
);

typedef SmartBrainPackagesForAnalysisLookup
    = Future<List<AnalysisPackageLink>> Function(String analysisId);

typedef SmartBrainActivePackagesLookup = Future<List<AnalysisPackageLink>>
    Function({String? labId, String? nameQuery});

typedef SmartBrainPackagesContainingAllLookup
    = Future<List<AnalysisPackageLink>> Function(
  List<String> analysisIds, {
  String? labId,
});

typedef SmartBrainDiscountedPackagesLookup
    = Future<List<AnalysisPackageLink>> Function({String? labId});

typedef SmartBrainPackageDetailsLookup = Future<LabPackageItem?> Function(
  String packageId,
);

/// يخطّط الإجراء من النية + السياق + مطابقة البيانات الحقيقية.
///
/// مسار موحّد للنص والصوت بعد اكتساب الإدخال:
/// IntentResolver → [PendingClarification?] → EntityTargetResolver
/// → Doctor/LaboratoryTargetResolver → Matcher → AmbiguityGate → ActionPlan
class SmartBrainPlanner {
  SmartBrainPlanner({
    IntentResolver? intentResolver,
    ContextResolver? contextResolver,
    DoctorTargetResolver? targetResolver,
    LaboratoryTargetResolver? laboratoryTargetResolver,
    AnalysisTargetResolver? analysisTargetResolver,
    PackageTargetResolver? packageTargetResolver,
    DoctorNameMatcher? doctorNameMatcher,
    LaboratoryNameMatcher? laboratoryNameMatcher,
    AnalysisNameMatcher? analysisNameMatcher,
    PackageNameMatcher? packageNameMatcher,
    ClarificationResolver? clarificationResolver,
    ClarificationResponseBuilder? clarificationResponses,
    SmartSearchService? search,
    SmartBrainDoctorLookup? doctorLookup,
    SmartBrainLabLookup? labLookup,
    SmartBrainLabPackagesLookup? packagesLookup,
    SmartBrainAnalysisLookup? analysisLookup,
    SmartBrainPackagesForAnalysisLookup? packagesForAnalysisLookup,
    SmartBrainPackagesContainingAllLookup? packagesContainingAllLookup,
    SmartBrainActivePackagesLookup? activePackagesLookup,
    SmartBrainDiscountedPackagesLookup? discountedPackagesLookup,
    SmartBrainPackageDetailsLookup? packageDetailsLookup,
    GuidedConversationEngine? guidedConversationEngine,
    HealthGuidanceCoordinator? healthGuidanceCoordinator,
    ConversationConductCoordinator? conductCoordinator,
    CompanionOnboardingCoordinator? companionOnboardingCoordinator,
    CompanionProfileCommandCoordinator? companionProfileCommands,
    SensitiveHealthProfileCoordinator? sensitiveHealthProfile,
    ChronicCareCoordinator? chronicCare,
    EmotionalSupportCoordinator? emotionalSupport,
    PreventiveGuidanceCoordinator? preventiveGuidance,
    FamilyProfileCommandCoordinator? familyProfileCommands,
    FamilyHealthCommandCoordinator? familySensitiveHealth,
    FollowUpCoordinator? followUp,
    PersonalMemoryCoordinator? personalMemory,
    PersonalizationCoordinator? personalization,
    WellnessCoordinator? wellness,
    DailyContextCoordinator? dailyContext,
    WellbeingPlannerCoordinator? wellbeingPlanner,
    ClinicalKnowledgeCoordinator? clinicalKnowledge,
    MskGuidanceCoordinator? mskGuidance,
    RespiratoryGuidanceCoordinator? respiratoryGuidance,
    ChronicClinicalCoordinator? chronicClinical,
    PregnancyCompanionCoordinator? pregnancyCompanion,
    DentalGuidanceCoordinator? dentalGuidance,
    AdolescentCompanionCoordinator? adolescentCompanion,
    SubjectBindingCoordinator? subjectBinding,
    UnifiedBrainCoordinator? unifiedBrain,
    NluClient? nluClient,
  })  : _intentResolver = intentResolver ?? RuleBasedIntentResolver(),
        _contextResolver = contextResolver ?? const ContextResolver(),
        _targetResolver = targetResolver ?? const DoctorTargetResolver(),
        _labTargetResolver =
            laboratoryTargetResolver ?? const LaboratoryTargetResolver(),
        _analysisTargetResolver =
            analysisTargetResolver ?? const AnalysisTargetResolver(),
        _packageTargetResolver =
            packageTargetResolver ?? const PackageTargetResolver(),
        _matcher = doctorNameMatcher ?? const DoctorNameMatcher(),
        _labMatcher = laboratoryNameMatcher ?? const LaboratoryNameMatcher(),
        _analysisMatcher = analysisNameMatcher ?? const AnalysisNameMatcher(),
        _packageMatcher = packageNameMatcher ?? const PackageNameMatcher(),
        _clarificationResolver =
            clarificationResolver ?? const ClarificationResolver(),
        _clarificationResponses =
            clarificationResponses ?? const ClarificationResponseBuilder(),
        _search = search,
        _doctorLookup = doctorLookup,
        _labLookup = labLookup,
        _packagesLookup = packagesLookup,
        _analysisLookup = analysisLookup,
        _packagesForAnalysisLookup = packagesForAnalysisLookup,
        _packagesContainingAllLookup = packagesContainingAllLookup,
        _activePackagesLookup = activePackagesLookup,
        _discountedPackagesLookup = discountedPackagesLookup,
        _packageDetailsLookup = packageDetailsLookup,
        _guidedEngine = guidedConversationEngine ?? GuidedConversationEngine(),
        _healthCoordinator =
            healthGuidanceCoordinator ?? HealthGuidanceCoordinator(),
        _conductCoordinator =
            conductCoordinator ?? ConversationConductCoordinator(),
        _companionOnboarding =
            companionOnboardingCoordinator ?? CompanionOnboardingCoordinator(),
        _companionProfileCommands = companionProfileCommands ??
            CompanionProfileCommandCoordinator(
              profiles: companionOnboardingCoordinator?.profiles,
            ),
        _sensitiveHealthProfile =
            sensitiveHealthProfile ?? SensitiveHealthProfileCoordinator(),
        _followUp = followUp ?? FollowUpCoordinator(),
        _chronicCare = chronicCare ??
            ChronicCareCoordinator(
              healthProfiles: sensitiveHealthProfile?.service,
              followUps: followUp?.service ?? FollowUpService(),
            ),
        _emotionalSupport =
            emotionalSupport ?? EmotionalSupportCoordinator(),
        _preventiveGuidance = preventiveGuidance ??
            PreventiveGuidanceCoordinator(
              profiles: companionOnboardingCoordinator?.profiles,
              healthProfiles: sensitiveHealthProfile?.service,
            ),
        _familyProfileCommands = familyProfileCommands ??
            FamilyProfileCommandCoordinator(
              familyHealth: familySensitiveHealth?.service,
            ),
        _familySensitiveHealth = familySensitiveHealth ??
            FamilyHealthCommandCoordinator(
              service: familyProfileCommands?.familyHealth,
              people: familyProfileCommands?.people,
            ),
        _personalMemory = personalMemory ??
            PersonalMemoryCoordinator(
              profiles: companionOnboardingCoordinator?.profiles ??
                  companionProfileCommands?.profiles,
              followUps: followUp?.service ?? FollowUpService(),
            ),
        _personalization = personalization ??
            PersonalizationCoordinator(
              profiles: companionOnboardingCoordinator?.profiles ??
                  companionProfileCommands?.profiles,
              personalMemory: personalMemory?.service,
              followUps: followUp?.service,
              health: sensitiveHealthProfile?.service,
              familyHealth: familySensitiveHealth?.service ??
                  familyProfileCommands?.familyHealth,
            ),
        _wellness = wellness ??
            WellnessCoordinator(
              profiles: companionOnboardingCoordinator?.profiles ??
                  companionProfileCommands?.profiles,
              personalMemory: personalMemory?.service,
              health: sensitiveHealthProfile?.service,
            ),
        _dailyContext = dailyContext ?? DailyContextCoordinator(),
        _wellbeingPlanner = wellbeingPlanner ??
            WellbeingPlannerCoordinator(
              personalMemory: personalMemory?.service,
              followUps: followUp?.service,
            ),
        _clinicalKnowledge =
            clinicalKnowledge ?? ClinicalKnowledgeCoordinator(),
        _mskGuidance = mskGuidance ?? MskGuidanceCoordinator(),
        _respiratoryGuidance =
            respiratoryGuidance ?? RespiratoryGuidanceCoordinator(),
        _chronicClinical = chronicClinical ?? ChronicClinicalCoordinator(),
        _pregnancyCompanion =
            pregnancyCompanion ?? PregnancyCompanionCoordinator(),
        _dentalGuidance = dentalGuidance ?? DentalGuidanceCoordinator(),
        _adolescentCompanion =
            adolescentCompanion ?? AdolescentCompanionCoordinator(),
        _subjectBinding = subjectBinding ??
            SubjectBindingCoordinator(
              people: familyProfileCommands?.people,
            ),
        _unifiedBrain = unifiedBrain ?? UnifiedBrainCoordinator(),
        _providerDiscovery = GuidanceProviderDiscoveryService(
          search: search,
          doctorLookup: doctorLookup,
          labLookup: labLookup,
        ),
        _nluClient = nluClient ?? NluClient.fromAppConfig();

  final IntentResolver _intentResolver;
  final ContextResolver _contextResolver;
  final DoctorTargetResolver _targetResolver;
  final LaboratoryTargetResolver _labTargetResolver;
  final AnalysisTargetResolver _analysisTargetResolver;
  final PackageTargetResolver _packageTargetResolver;
  final DoctorNameMatcher _matcher;
  final LaboratoryNameMatcher _labMatcher;
  final AnalysisNameMatcher _analysisMatcher;
  final PackageNameMatcher _packageMatcher;
  final ClarificationResolver _clarificationResolver;
  final ClarificationResponseBuilder _clarificationResponses;
  final SmartSearchService? _search;
  final SmartBrainDoctorLookup? _doctorLookup;
  final SmartBrainLabLookup? _labLookup;
  final SmartBrainLabPackagesLookup? _packagesLookup;
  final SmartBrainAnalysisLookup? _analysisLookup;
  final SmartBrainPackagesForAnalysisLookup? _packagesForAnalysisLookup;
  final SmartBrainPackagesContainingAllLookup? _packagesContainingAllLookup;
  final SmartBrainActivePackagesLookup? _activePackagesLookup;
  final SmartBrainDiscountedPackagesLookup? _discountedPackagesLookup;
  final SmartBrainPackageDetailsLookup? _packageDetailsLookup;
  final GuidedConversationEngine _guidedEngine;
  final HealthGuidanceCoordinator _healthCoordinator;
  final ConversationConductCoordinator _conductCoordinator;
  final CompanionOnboardingCoordinator _companionOnboarding;
  final CompanionProfileCommandCoordinator _companionProfileCommands;
  final SensitiveHealthProfileCoordinator _sensitiveHealthProfile;
  final FollowUpCoordinator _followUp;
  final ChronicCareCoordinator _chronicCare;
  final EmotionalSupportCoordinator _emotionalSupport;
  final PreventiveGuidanceCoordinator _preventiveGuidance;
  final FamilyProfileCommandCoordinator _familyProfileCommands;
  final FamilyHealthCommandCoordinator _familySensitiveHealth;
  final PersonalMemoryCoordinator _personalMemory;
  final PersonalizationCoordinator _personalization;
  final WellnessCoordinator _wellness;
  final DailyContextCoordinator _dailyContext;
  final WellbeingPlannerCoordinator _wellbeingPlanner;
  final ClinicalKnowledgeCoordinator _clinicalKnowledge;
  final MskGuidanceCoordinator _mskGuidance;
  final RespiratoryGuidanceCoordinator _respiratoryGuidance;
  final ChronicClinicalCoordinator _chronicClinical;
  final PregnancyCompanionCoordinator _pregnancyCompanion;
  final DentalGuidanceCoordinator _dentalGuidance;
  final AdolescentCompanionCoordinator _adolescentCompanion;
  final SubjectBindingCoordinator _subjectBinding;
  final UnifiedBrainCoordinator _unifiedBrain;
  final GuidanceProviderDiscoveryService _providerDiscovery;
  final NluClient _nluClient;
  final NaturalRecallResponseDecorator _naturalRecall =
      const NaturalRecallResponseDecorator();

  final ConversationReferenceResolver _referenceResolver =
      const ConversationReferenceResolver();
  final EntityRelationshipResolver _relationshipResolver =
      const EntityRelationshipResolver();

  GuidedConversationEngine get guidedConversationEngine => _guidedEngine;
  HealthGuidanceCoordinator get healthGuidanceCoordinator =>
      _healthCoordinator;
  ConversationConductCoordinator get conductCoordinator =>
      _conductCoordinator;
  CompanionOnboardingCoordinator get companionOnboardingCoordinator =>
      _companionOnboarding;
  CompanionProfileCommandCoordinator get companionProfileCommands =>
      _companionProfileCommands;
  SensitiveHealthProfileCoordinator get sensitiveHealthProfileCoordinator =>
      _sensitiveHealthProfile;
  FollowUpCoordinator get followUpCoordinator => _followUp;
  ChronicCareCoordinator get chronicCareCoordinator => _chronicCare;
  EmotionalSupportCoordinator get emotionalSupportCoordinator =>
      _emotionalSupport;
  PreventiveGuidanceCoordinator get preventiveGuidanceCoordinator =>
      _preventiveGuidance;
  FamilyProfileCommandCoordinator get familyProfileCommands =>
      _familyProfileCommands;
  FamilyHealthCommandCoordinator get familySensitiveHealthCoordinator =>
      _familySensitiveHealth;
  PersonalMemoryCoordinator get personalMemoryCoordinator => _personalMemory;
  PersonalizationCoordinator get personalizationCoordinator => _personalization;
  WellnessCoordinator get wellnessCoordinator => _wellness;
  DailyContextCoordinator get dailyContextCoordinator => _dailyContext;
  WellbeingPlannerCoordinator get wellbeingPlannerCoordinator =>
      _wellbeingPlanner;
  ClinicalKnowledgeCoordinator get clinicalKnowledgeCoordinator =>
      _clinicalKnowledge;
  MskGuidanceCoordinator get mskGuidanceCoordinator => _mskGuidance;
  RespiratoryGuidanceCoordinator get respiratoryGuidanceCoordinator =>
      _respiratoryGuidance;
  ChronicClinicalCoordinator get chronicClinicalCoordinator => _chronicClinical;
  PregnancyCompanionCoordinator get pregnancyCompanionCoordinator =>
      _pregnancyCompanion;
  DentalGuidanceCoordinator get dentalGuidanceCoordinator => _dentalGuidance;
  AdolescentCompanionCoordinator get adolescentCompanionCoordinator =>
      _adolescentCompanion;
  SubjectBindingCoordinator get subjectBindingCoordinator => _subjectBinding;
  UnifiedBrainCoordinator get unifiedBrainCoordinator => _unifiedBrain;
  GuidanceProviderDiscoveryService get providerDiscoveryService =>
      _providerDiscovery;

  /// آخر استعلام أُرسل للمطابقات (للاختبارات).
  String? lastMatcherQueryForTest;

  /// أثر NLU للمرحلة 1 — للاختبارات والتشخيص المحلي فقط.
  NluDebugTrace? lastNluTraceForTest;

  Future<_RespiratoryNluAttempt> _maybeRespiratoryNlu({
    required String query,
    required RespiratorySession session,
    required AssistantIntent intent,
  }) async {
    final deterministic =
        _respiratoryGuidance.interpreter.interpret(query);
    final gate = const RespiratoryNluGate().evaluate(
      query: query,
      session: session,
      deterministic: deterministic,
      intent: intent,
    );
    if (!gate.shouldCall) {
      return _RespiratoryNluAttempt(
        called: false,
        skipReason: gate.skipReason,
        gateReason: gate.reason,
        deterministic: deterministic,
      );
    }
    if (!_nluClient.isEnabled) {
      return _RespiratoryNluAttempt(
        called: false,
        skipReason: NluSkipReason.notConfigured,
        gateReason: gate.reason,
        deterministic: deterministic,
      );
    }

    NluClientResult clientResult;
    try {
      clientResult = await _nluClient
          .parse(
            NluRequest(
              userMessage: query,
              session: _snapshotRespiratory(session),
            ),
          )
          .timeout(kNluTimeout);
    } on TimeoutException {
      return _RespiratoryNluAttempt(
        called: true,
        fallbackReason: NluSkipReason.timeout,
        gateReason: gate.reason,
        deterministic: deterministic,
      );
    }

    if (clientResult.failed || clientResult.parse == null) {
      return _RespiratoryNluAttempt(
        called: true,
        fallbackReason: clientResult.reason ?? NluSkipReason.httpFailure,
        gateReason: gate.reason,
        deterministic: deterministic,
      );
    }

    final applied = const RespiratoryNluOverlay().apply(
      interp: deterministic,
      session: session,
      parse: clientResult.parse!,
    );
    if (applied.fallbackReason == NluSkipReason.lowConfidence ||
        applied.fallbackReason == NluSkipReason.overlayEmpty) {
      return _RespiratoryNluAttempt(
        called: true,
        fallbackReason: applied.fallbackReason,
        gateReason: gate.reason,
        deterministic: deterministic,
        acceptedSlots: applied.acceptedSlots,
        rejectedSlots: applied.rejectedSlots,
      );
    }

    return _RespiratoryNluAttempt(
      called: true,
      parse: clientResult.parse,
      gateReason: gate.reason,
      deterministic: deterministic,
      acceptedSlots: applied.acceptedSlots,
      rejectedSlots: applied.rejectedSlots,
    );
  }

  NluSessionSnapshot _snapshotRespiratory(RespiratorySession session) {
    return NluSessionSnapshot(
      activePack: 'respiratory',
      continuationExpected: session.lastQuestionKey != null,
      population: session.population.name,
      ageKnown: session.symptomKeys.contains('childAgeKnown'),
      lastQuestionKey: session.lastQuestionKey,
      cough: session.hasCoughContext ? 'present' : 'unknown',
      fever: session.fever.name,
      breathlessness: session.breathlessness.name,
      sputum: session.sputum.name,
      hemoptysis: session.hemoptysis.name,
      durationBucket: session.durationBucket.name,
    );
  }

  Future<List<SmartSearchResult>> _lookupDoctors(String query) {
    final lookup = _doctorLookup;
    if (lookup != null) return lookup(query);
    final search = _search ?? SmartSearchService();
    return search.search(query, limit: 16);
  }

  Future<List<SmartSearchResult>> _lookupLabs(String query) async {
    final lookup = _labLookup;
    if (lookup != null) return lookup(query);
    final search = _search ?? SmartSearchService();
    final results = await search.search(
      query.trim().isEmpty ? 'مختبر' : query,
      limit: 16,
    );
    return results
        .where((r) => r.type == SmartSearchResultType.lab)
        .toList(growable: false);
  }

  Future<List<LabPackageItem>> _lookupPackages(String labId) async {
    final lookup = _packagesLookup;
    if (lookup != null) return lookup(labId);
    return LabsService().fetchPublicPackages(labId);
  }

  Future<List<AnalysisItem>> _lookupAnalyses(String query) async {
    final lookup = _analysisLookup;
    if (lookup != null) return lookup(query);
    return LabsService().fetchAnalyses(query: query, activeOnly: true);
  }

  Future<List<AnalysisPackageLink>> _lookupPackagesForAnalysis(
    String analysisId,
  ) async {
    final lookup = _packagesForAnalysisLookup;
    if (lookup != null) return lookup(analysisId);
    return LabsService().fetchPackagesContainingAnalysis(analysisId);
  }

  Future<List<AnalysisPackageLink>> _lookupActivePackages({
    String? labId,
    String? nameQuery,
  }) async {
    final lookup = _activePackagesLookup;
    if (lookup != null) {
      return lookup(labId: labId, nameQuery: nameQuery);
    }
    return LabsService().fetchActivePackages(labId: labId, nameQuery: nameQuery);
  }

  Future<List<AnalysisPackageLink>> _lookupPackagesContainingAll(
    List<String> analysisIds, {
    String? labId,
  }) async {
    final lookup = _packagesContainingAllLookup;
    if (lookup != null) {
      return lookup(analysisIds, labId: labId);
    }
    return LabsService().fetchPackagesContainingAllAnalyses(
      analysisIds,
      labId: labId,
    );
  }

  Future<List<AnalysisPackageLink>> _lookupDiscountedPackages({
    String? labId,
  }) async {
    final lookup = _discountedPackagesLookup;
    if (lookup != null) return lookup(labId: labId);
    return LabsService().fetchActiveDiscountedPackages(labId: labId);
  }

  Future<LabPackageItem?> _lookupPackageDetails(String packageId) async {
    if (packageId.trim().isEmpty) return null;
    final lookup = _packageDetailsLookup;
    if (lookup != null) return lookup(packageId);
    try {
      return await LabsService().fetchPackageDetails(packageId);
    } catch (_) {
      return null;
    }
  }

  IntentResult classify(String query) => _intentResolver.resolve(query);

  /// يبدأ تدفقاً موجَّهاً (API عام — لا يبدأ صحة تلقائياً).
  GuidedConversationResponse startGuidedFlow({
    required ConversationContext context,
    required GuidedFlowDefinition definition,
  }) {
    context.advanceTurn();
    final response = _guidedEngine.startFlow(
      definition: definition,
      readState: () => context.guidedConversation,
      writeState: context.setGuidedConversation,
      turnId: context.turnId,
    );
    if (response.message.isNotEmpty) {
      context.setAssistantResponse(response.message);
    }
    return response;
  }

  GuidedConversationResponse startServiceAssistanceDemo({
    required ConversationContext context,
  }) {
    context.advanceTurn();
    final response = _guidedEngine.startServiceAssistanceDemo(
      readState: () => context.guidedConversation,
      writeState: context.setGuidedConversation,
      turnId: context.turnId,
    );
    if (response.message.isNotEmpty) {
      context.setAssistantResponse(response.message);
    }
    return response;
  }

  bool _isCompanionEntityIntent(AssistantIntent intent, String query) {
    switch (intent) {
      case AssistantIntent.findLab:
      case AssistantIntent.findAnalysis:
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
      case AssistantIntent.specialtySearch:
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.showLocation:
      case AssistantIntent.showProfile:
      case AssistantIntent.bookAppointment:
      case AssistantIntent.selectResult:
        return true;
      case AssistantIntent.doctorSearch:
        final n = ArabicTextUtils.normalize(query);
        return RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور).{0,16}(?:طبيب|دكتور)|(?:^|\s)(?:ال)?(?:دكتور|طبيب)\s+\S{2,}',
        ).hasMatch(n);
      default:
        return false;
    }
  }

  bool _looksLikeCompanionOfferTrigger(String query) {
    final n = ArabicTextUtils.normalize(query);
    if (RegExp(r'(?:تعرف\s*علي|خلي\s*نتعرف|ابغى\s*اتعرف)').hasMatch(n)) {
      return true;
    }
    // تحية قصيرة فقط — لا بعد كل بحث
    return RegExp(r'^(?:مرحبا|مرحباً|السلام\s*عليكم|هلا|هاي)$').hasMatch(n);
  }

  /// يفهم الاستعلام ويُنتج خطة فعل — بدون إطلاق اتصال/تنقل هنا.
  /// أولوية Step 10A / 10E.1 / PC-1.6 / Phase 3D:
  /// 0) كشف السلوك (metadata) — بلا ابتلاع قبل الصحة/السلامة
  /// 0b) بوابة سلامة نفسية للأزمة الصريحة
  /// 0c) هوية غدير الحتمية (تحويلة محادثية — لا تمسح الجلسة السريرية)
  /// 0d) محادثة اجتماعية standalone فقط (بعد الهوية؛ قبل _planImpl
  ///     حتى لا تُستهلك كجواب سريري؛ الجمل المختلطة لا تطابق فتمر للمعنى)
  /// 1) إلغاء / تغيير موضوع للتدفق الموجَّه
  /// 2) PendingClarification (Step 5) إن ملك الجواب
  /// 3) GuidedQuestion
  /// 4) سلامة طبية / توجيه صحي
  /// 5) المسار العادي
  /// 6) تزيين عاطفي (لا يستبدل العاجل الطبي ولا يبتلع الهدف)
  /// 7) تزيين اختياري بحدود آداب (لا يستبدل العاجل)
  Future<AssistantActionPlan> plan({
    required String query,
    required ConversationContext context,
  }) async {
    final observed = _conductCoordinator.observe(
      query: query,
      state: context.conductState,
    );
    context.setConductState(observed.state);

    final pipelineQuery = observed.pipelineQuery.trim().isNotEmpty
        ? observed.pipelineQuery.trim()
        : query;

    // PC-1.6: خطر نفسي صريح → مسار أزمة قبل المسارات العادية
    if (_emotionalSupport.safetyGate.triggersCrisis(query)) {
      final crisis = _emotionalSupport.evaluate(
        query: query,
        intent: AssistantIntent.unknown,
      );
      context.setEmotionalSupport(crisis.context);
      context.setAssistantResponse(crisis.standaloneMessage);
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: _intentResolver.resolve(pipelineQuery),
        message: crisis.standaloneMessage,
        canExecute: false,
        textFirstOnly: true,
      );
    }

    // Phase 3D STEP 1 — هوية المساعد/التطبيق قبل السريري والبحث؛ بلا مسح جلسة.
    final identityAnswer =
        const GhadeerIdentity().tryAnswer(pipelineQuery);
    if (identityAnswer != null) {
      context.setAssistantResponse(identityAnswer);
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: _intentResolver.resolve(pipelineQuery),
        message: identityAnswer,
        canExecute: false,
        textFirstOnly: true,
      );
    }

    // Phase 3D STEP 2/3 — اجتماعي standalone فقط.
    // الجمل المختلطة (هلا اريد طبيب…) لا تطابق → _planImpl يفوز.
    // مبكرًا مثل الهوية حتى لا تُستهلك شلونك/شكرا كجواب سريري معلّق.
    // STEP 3: اسم اختياري من الملف القائم + تنويع حتمي عبر ghadeerSocial.
    String? socialFirstName;
    try {
      final profile =
          await _companionOnboarding.profiles.loadProfile();
      socialFirstName = greetingAddressName(
        profile?.preferredName ?? profile?.fullName,
      );
    } catch (_) {
      socialFirstName = null;
    }
    final socialReply = const GhadeerSocialConversation().resolve(
      pipelineQuery,
      firstName: socialFirstName,
      socialContext: context.ghadeerSocial,
    );
    if (socialReply != null) {
      context.setGhadeerSocial(socialReply.nextContext);
      context.setAssistantResponse(socialReply.message);
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: _intentResolver.resolve(pipelineQuery),
        message: socialReply.message,
        canExecute: false,
        textFirstOnly: true,
      );
    }

    final plan = await _planImpl(
      query: pipelineQuery,
      context: context,
      allowGuided: true,
    );

    var studentContext = false;
    try {
      final profile =
          await _companionOnboarding.profiles.loadProfile();
      studentContext =
          profile?.userContext == ProfileUserContext.student;
    } catch (_) {
      studentContext = false;
    }

    final support = _emotionalSupport.evaluate(
      query: query,
      intent: plan.intentResult.intent,
      studentContext: studentContext,
    );
    context.setEmotionalSupport(support.context);

    final withEmotion = _emotionalSupport.decoratePlan(
      plan: plan,
      support: support,
    );
    if (withEmotion.message.trim().isNotEmpty) {
      context.setAssistantResponse(withEmotion.message);
    }

    // —— PC-1.13: تخصيص سياقي بعد العاطفة وقبل أدب الحوار ——
    var withPersonalization = withEmotion;
    try {
      if (!support.crisis) {
        final privacy = const PersonalizationPrivacyPolicy();
        final subject = privacy.mapSubject(context.resolvedConversationSubject);
        final urgent = plan.kind == AssistantActionKind.healthGuidance &&
            RegExp(
              r'(?:ضيق\s*نفس|اختناق|فاقد\s*وعي|نزيف|الم\s*صدر|ألم\s*صدر)',
            ).hasMatch(ArabicTextUtils.normalize(query));
        final envelope = await _personalization.buildEnvelope(
          PersonalizationTurnInput(
            query: query,
            subjectKind: subject,
            persistentPersonId: context.linkedFamilyPersonId,
            planKindName: plan.kind.name,
            intentName: plan.intentResult.intent.name,
            urgentSafety: urgent,
            mentalSafety: support.crisis,
            emotionalDistress:
                support.context.signal != EmotionalSignal.neutral,
            session: context.personalizationSession,
          ),
        );
        final decorated = _naturalRecall.decorate(
          plan: withEmotion,
          envelope: envelope,
          session: context.personalizationSession,
        );
        withPersonalization = decorated.plan;
        context.setPersonalizationSession(decorated.session);
        if (withPersonalization.message.trim().isNotEmpty) {
          context.setAssistantResponse(withPersonalization.message);
        }
      }
    } catch (_) {
      // فشل التخصيص → الخطة الأصلية
      withPersonalization = withEmotion;
    }

    return _conductCoordinator.decoratePlan(
      plan: withPersonalization,
      conduct: observed.result,
      state: context.conductState,
      turnId: context.turnId,
      writeState: context.setConductState,
    );
  }

  Future<AssistantActionPlan> _planImpl({
    required String query,
    required ConversationContext context,
    required bool allowGuided,
  }) async {
    lastMatcherQueryForTest = null;
    var workingQuery = query;
    var intent = _intentResolver.resolve(workingQuery);
    context.rememberQuery(workingQuery, intent: intent.intent);
    var guidedAllowed = allowGuided;

    // —— استمرارية قصيرة: تأكيد/رفض فعل معلّق فقط إن كان هو التوقع الحي الحالي ——
    if (context.activeYesNoConsumer ==
        ConversationYesNoConsumer.pendingAction) {
      final pendingAffirm = _tryPlanPendingActionAffirmation(
        workingQuery,
        context,
        intent,
      );
      if (pendingAffirm != null) {
        return pendingAffirm;
      }
    }

    // —— PC-1.4: ذاكرة صحية حسّاسة (نص أولاً، موافقة إلزامية) ——
    // —— PC-1.3: أوامر الملف الأساسي (نص أولاً) ——
    // الأولوية الطبية العاجلة تتقدم على تعديل الملف/الذاكرة الصحية.
    final healthCandidate =
        _healthCoordinator.shouldConsiderHealthFlow(workingQuery);
    final urgentHealthHint = healthCandidate &&
        RegExp(
          r'(?:ضيق\s*نفس|اختناق|فاقد\s*وعي|نزيف|الم\s*صدر|ألم\s*صدر|شديد)',
        ).hasMatch(ArabicTextUtils.normalize(workingQuery));

    // —— PC-1.10: صحة عائلة حسّاسة (قبل صحة المالك؛ نص أولاً) ——
    final familyHealthMay = _familySensitiveHealth.mayHandle(
      query: workingQuery,
      pending: context.familySensitiveHealthPending,
    );
    if (familyHealthMay && !urgentHealthHint) {
      final mentalHint = RegExp(
        r'(?:انتحار|اذي\s*نفسي|أذي\s*نفسي|اقتل\s*نفسي)',
      ).hasMatch(ArabicTextUtils.normalize(workingQuery));
      final familyHealthTurn = await _familySensitiveHealth.handle(
        text: workingQuery,
        pending: context.familySensitiveHealthPending,
        linkedFamilyPersonId: context.linkedFamilyPersonId,
        preferUrgentSafety: false,
        preferMentalSafety: mentalHint,
      );
      if (familyHealthTurn.deferToUrgentSafety ||
          familyHealthTurn.deferToMentalSafety ||
          familyHealthTurn.deferToProvider) {
        // اترك المسار يكمل للسلامة / discovery
      } else if (familyHealthTurn.handled) {
        context.setFamilySensitiveHealthPending(familyHealthTurn.pending);
        if (familyHealthTurn.linkedPersonId != null) {
          context.setLinkedFamilyPersonId(familyHealthTurn.linkedPersonId);
        }
        context.setAssistantResponse(
          familyHealthTurn.message.isEmpty ? null : familyHealthTurn.message,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: familyHealthTurn.message,
          canExecute: false,
          textFirstOnly: true,
        );
      }
    }

    final healthMemMay = _sensitiveHealthProfile.mayHandle(
      query: workingQuery,
      pending: context.sensitiveHealthPending,
    );
    if (healthMemMay && !urgentHealthHint) {
      final healthTurn = await _sensitiveHealthProfile.handle(
        text: workingQuery,
        pending: context.sensitiveHealthPending,
      );
      if (healthTurn.handled) {
        context.setSensitiveHealthPending(healthTurn.pending);
        context.setAssistantResponse(
          healthTurn.message.isEmpty ? null : healthTurn.message,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: healthTurn.message,
          canExecute: false,
          textFirstOnly: true,
        );
      }
    }

    // —— PC-1.5: متابعة مزمنة (نص أولاً، صلاحية منفصلة) ——
    final chronicMay = _chronicCare.mayHandle(
      query: workingQuery,
      session: context.chronicCareSession,
    );
    if (chronicMay && !urgentHealthHint) {
      final chronicTurn = await _chronicCare.handle(
        text: workingQuery,
        session: context.chronicCareSession,
      );
      if (chronicTurn.deferToUrgentSafety) {
        context.setChronicCareSession(chronicTurn.session);
        // اترك المسار يكمل لـ 10E / health guidance
      } else if (chronicTurn.handled) {
        context.setChronicCareSession(chronicTurn.session);
        context.setAssistantResponse(
          chronicTurn.message.isEmpty ? null : chronicTurn.message,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: chronicTurn.message,
          canExecute: false,
          textFirstOnly: true,
        );
      }
    }

    // —— PC-1.15: راقب السياق اليومي (جلسة) قبل المتابعة/العافية ——
    var dailySuppressWellness = false;
    try {
      final observed = _dailyContext.observe(
        text: workingQuery,
        context: context.dailyLifeContext,
      );
      context.setDailyLifeContext(observed);
    } catch (_) {
      // فشل المراقبة لا يكسر Smart Brain
    }

    // —— PC-1.11: التزامات متابعة موحّدة (بعد المزمن؛ نص أولاً) ——
    // deferFollowUpSurfacing يؤثر على إبراز due المستقبلي بلا حذف — أوامر PC-1.11 الصريحة تبقى.
    final followUpMay = _followUp.mayHandle(
      query: workingQuery,
      pending: context.followUpPending,
    );
    if (followUpMay && !urgentHealthHint) {
      final mentalHint = RegExp(
        r'(?:انتحار|اذي\s*نفسي|أذي\s*نفسي|اقتل\s*نفسي)',
      ).hasMatch(ArabicTextUtils.normalize(workingQuery));
      final subject = context.linkedFamilyPersonId != null &&
              context.linkedFamilyPersonId!.isNotEmpty
          ? FollowUpSubjectRef.persistentPerson(context.linkedFamilyPersonId!)
          : FollowUpSubjectRef.accountOwner;
      final followTurn = await _followUp.handle(
        text: workingQuery,
        pending: context.followUpPending,
        currentSubject: subject,
        preferMentalSafety: mentalHint,
      );
      if (followTurn.deferToUrgentSafety ||
          followTurn.deferToMentalSafety ||
          followTurn.deferToEntityIntent) {
        // اترك المسار يكمل
      } else if (followTurn.handled) {
        context.setFollowUpPending(followTurn.pending);
        context.setAssistantResponse(
          followTurn.message.isEmpty ? null : followTurn.message,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: followTurn.message,
          canExecute: false,
          textFirstOnly: true,
        );
      }
    }

    // —— PC-1.24: تحكيم موحّد للحزم السريرية/الرفيق (سلطة واحدة أساسية؛ رد واحد) ——
    final skipClinicalBareYesNo = _otherConsumerOwnsBareYesNo(
      workingQuery,
      context,
    );
    // Phase 2G: طلب خدمة صريح قوي فقط يقطع سؤالاً سريرياً معلّقاً —
    // ليس كل specialtySearch، وليس ذكر اختصاص عرضي.
    final explicitServiceSwitch = _shouldExplicitServiceSwitchInterruptClinical(
      intent: intent,
      query: workingQuery,
      context: context,
    );
    if (explicitServiceSwitch) {
      context.clearClinicalPackSessionsForForeignTurn();
      // لا تؤكّد اتصالاً/واتساب قديماً أثناء التحويل لبحث خدمة.
      context.clearPending();
      // حدّث التشخيص: المسار يتجاوز كتلة PC-1.24، فبدون هذا تبقى
      // selectedPrimaryAuthority من الدور السابق وتبدو كـ hijack.
      context.setUnifiedBrainDiagnostics(
        const UnifiedBrainDiagnostics(
          clinicalSessionsClearedForForeignTurn: true,
          serviceHandoff: true,
          selectedPrimaryAuthority: BrainAuthorityId.none,
        ),
      );
    }
    if (!skipClinicalBareYesNo && !explicitServiceSwitch) {
    try {
      PersonalCompanionProfile? ownerProfile;
      try {
        ownerProfile =
            await _companionOnboarding.profiles.loadProfile();
      } catch (_) {
        ownerProfile = null;
      }
      final labeledAge =
          _unifiedBrain.ageResolver.parseExplicitAgeYears(workingQuery);
      // عودة صريحة للمالك قبل تقرير العمر — Phase 3C يحتاج معرفة self مبكراً.
      final normalizedSubject = ArabicTextUtils.normalize(workingQuery);
      final ownerSelfReturn = RegExp(
            r'(?:^|\s)(?:اني|انا)(?:\s|$)',
          ).hasMatch(normalizedSubject) &&
          !RegExp(
            r'(?:ابني|بنتي|زوجتي|امي|أمي|اخوي|اختي|أختي)',
          ).hasMatch(normalizedSubject);
      final aboutOtherSubject = context.healthSubject.isKnown &&
          context.healthSubject.type != HealthSubjectType.self &&
          !ownerSelfReturn;
      final sessionAge = context.isSessionAgeAnswerContext
          ? _unifiedBrain.ageResolver.parseSessionSubjectAgeYears(workingQuery)
          : null;
      final explicitAge = aboutOtherSubject
          ? sessionAge
          : (labeledAge ?? sessionAge);
      const ownerBridge = OwnerProfileContextBridge();
      final provisionalSubject = ownerSelfReturn
          ? HealthSubjectContext(
              sessionKey: 'subj_self_g${context.conversationGeneration}',
              type: HealthSubjectType.self,
              evidence: HealthSubjectEvidence.explicitSelf,
              isChild: false,
              ageGroup: 'adult',
            )
          : context.healthSubject;
      final provisionalResolved = ownerSelfReturn
          ? ResolvedConversationSubject.accountOwner
          : context.resolvedConversationSubject;
      final mayOwnerProfile = ownerBridge.mayApplyOwnerProfile(
        subject: provisionalSubject,
        resolved: provisionalResolved,
      );
      final ageRes = aboutOtherSubject
          ? _unifiedBrain.ageResolver.resolve(
              explicitAgeFromUtterance: explicitAge,
              approximateAgeYears: context.healthSubject.ageYears,
            )
          : (mayOwnerProfile
              ? ownerBridge.resolveAge(
                  profile: ownerProfile,
                  explicitAgeFromUtterance: explicitAge,
                )
              : _unifiedBrain.ageResolver.resolve(
                  explicitAgeFromUtterance: explicitAge,
                  approximateAgeYears: context.healthSubject.ageYears,
                ));
      final brainTurn = _unifiedBrain.buildTurn(
        workingQuery,
        age: ageRes,
        subjectResolved:
            context.resolvedConversationSubject.status ==
                ConversationPersonResolutionStatus.resolved,
        isAboutOtherPerson:
            !context.resolvedConversationSubject.isAccountOwner &&
                context.resolvedConversationSubject.status ==
                    ConversationPersonResolutionStatus.resolved,
      );

      var clearedForeign = false;
      if (_unifiedBrain.shouldClearClinicalSessionsForForeignTurn(brainTurn)) {
        context.clearClinicalPackSessionsForForeignTurn();
        clearedForeign = true;
      }

      // نطاق موضوع نصّي خفيف (قبل ربط PC-1.9 الكامل لاحقاً).
      // تصحيح الأرقام/الأسبوع ≠ تبديل شخص — لا تمسح الجلسات.
      final subjectCorrection = RegExp(
        r'(?:مو\s*اني|مو\s*إلي|مو\s*الي|لزوجتي|لابني|لاختي|لا\s*مو\s*اني)',
      ).hasMatch(normalizedSubject);
      // عودة صريحة للمالك («اني/انا») بعد موضوع عن شخص آخر — تمسح الجلسات اللاصقة.
      // لها أولوية على isAboutOtherPerson القادم من سياق الدور السابق (PC-1.9 late binding).
      // النطاق يتبع الشخص فقط، لا نية الدور. جواب متابعة («عمره 8 سنوات»)
      // يُصنَّف primaryIntent=unknown لأنه بلا كلمة عرض — لو دخل في المفتاح
      // لبدا تبديلَ شخص وهو نفس الطفل، فتُمسح الجلسة السريرية النشطة.
      // تبديل الموضوع له آليتاه القائمتان: الدور الأجنبي وإبطال الجلسات الشقيقة.
      if (ownerSelfReturn) {
        context.noteClinicalSubjectScope('owner');
        // «اني/انا» علامة ذات صريحة — تحسم صاحب الموضوع هنا، عند مصدر الحقيقة.
        // ربط PC-1.9 يقع بعد تحكيم الحزم السريرية، فأي دور تحسمه حزمة (تنفسي/
        // عظام/أسنان) يعود من _planImpl قبله ويترك subject الدور السابق سارياً.
        // عندها يقرأ جدار الخصوصية «شخص آخر» قديماً ويطالب بتحديد الشخص رغم أن
        // المستخدم حدّده. نفس نتيجة القاعدة 1 في ConversationPersonResolver.
        context.setLinkedFamilyPersonId(null);
        context.setResolvedConversationSubject(
          ResolvedConversationSubject.accountOwner,
        );
        context.setHealthSubject(
          HealthSubjectContext(
            sessionKey: 'subj_self_g${context.conversationGeneration}',
            type: HealthSubjectType.self,
            evidence: HealthSubjectEvidence.explicitSelf,
            isChild: false,
            ageGroup: 'adult',
          ),
        );
      } else if (brainTurn.isAboutOtherPerson || subjectCorrection) {
        context.noteClinicalSubjectScope(
          brainTurn.isAboutOtherPerson ? 'other' : 'owner',
        );
      } else if (context.lastClinicalSubjectScopeKey == null) {
        final det =
            _subjectBinding.subjectCoordinator.detector.detect(workingQuery);
        context.lastClinicalSubjectScopeKey =
            det.type == HealthSubjectType.child ||
                    det.type == HealthSubjectType.otherPerson
                ? 'other'
                : 'owner';
      }

      _syncSessionHealthSubject(context, workingQuery);
      _applyOwnerProfileContextBridge(context, ownerProfile);

      bool pregMay = false;
      bool dentalMay = false;
      bool mskMay = false;
      bool respMay = false;
      bool ccMay = false;
      bool adoMay = false;
      bool ckMay = false;

      try {
        pregMay = _pregnancyCompanion.mayHandle(
          query: workingQuery,
          session: context.pregnancyCompanionSession,
        );
      } catch (_) {}
      try {
        dentalMay = _dentalGuidance.mayHandle(
          query: workingQuery,
          session: context.dentalSession,
        );
      } catch (_) {}
      try {
        mskMay = _mskGuidance.mayHandle(
          query: workingQuery,
          session: context.mskSession,
        );
      } catch (_) {}
      try {
        respMay = _respiratoryGuidance.mayHandle(
          query: workingQuery,
          session: context.respiratorySession,
        );
      } catch (_) {}
      try {
        ccMay = _chronicClinical.mayHandle(
          query: workingQuery,
          session: context.chronicClinicalSession,
        );
      } catch (_) {}
      try {
        adoMay = _adolescentCompanion.mayHandle(
          query: workingQuery,
          session: context.adolescentCompanionSession,
        );
      } catch (_) {}
      try {
        ckMay = _clinicalKnowledge.mayHandle(
          query: workingQuery,
          session: context.clinicalKnowledgeSession,
        );
      } catch (_) {}

      String reasonFor({
        required bool may,
        required bool sessionActive,
        required bool cue,
      }) {
        if (!may) return 'notRelevant';
        if (sessionActive && !cue) return 'sessionContinuation';
        if (cue) return 'explicitIntent';
        return 'activeComplaint';
      }

      final arbitrator = _unifiedBrain.arbitrator;
      final candidates = <UnifiedBrainCandidate>[
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.pregnancy,
          turn: brainTurn,
          mayHandle: pregMay,
          mayHandleReason: reasonFor(
            may: pregMay,
            sessionActive: context.pregnancyCompanionSession.active,
            cue: brainTurn.hasPregnancyCue,
          ),
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.dental,
          turn: brainTurn,
          mayHandle: dentalMay,
          mayHandleReason: reasonFor(
            may: dentalMay,
            sessionActive: context.dentalSession.active,
            cue: brainTurn.hasDentalCue,
          ),
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.msk,
          turn: brainTurn,
          mayHandle: mskMay,
          mayHandleReason: reasonFor(
            may: mskMay,
            sessionActive: context.mskSession.active,
            cue: brainTurn.hasMskCue,
          ),
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.respiratory,
          turn: brainTurn,
          mayHandle: respMay,
          mayHandleReason: reasonFor(
            may: respMay,
            sessionActive: context.respiratorySession.active,
            cue: brainTurn.hasRespiratoryCue,
          ),
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.chronicClinical,
          turn: brainTurn,
          mayHandle: ccMay,
          mayHandleReason: reasonFor(
            may: ccMay,
            sessionActive: context.chronicClinicalSession.active,
            cue: brainTurn.hasChronicCue,
          ),
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.adolescent,
          turn: brainTurn,
          mayHandle: adoMay,
          mayHandleReason: reasonFor(
            may: adoMay,
            sessionActive: context.adolescentCompanionSession.active,
            cue: brainTurn.hasAdolescentCue,
          ),
        ),
        arbitrator.classifyCandidate(
          authority: BrainAuthorityId.clinicalKnowledge,
          turn: brainTurn,
          mayHandle: ckMay &&
              !pregMay &&
              !dentalMay &&
              !mskMay &&
              !respMay &&
              !ccMay &&
              !adoMay,
          mayHandleReason: ckMay ? 'explicitIntent' : 'notRelevant',
        ),
      ];

      // حمل كسياق مع شكوى مجال أخرى حتى لو mayHandle=false (foreign داخل الحزمة).
      if (brainTurn.hasPregnancyCue &&
          (brainTurn.hasMskCue ||
              brainTurn.hasRespiratoryCue ||
              brainTurn.hasDentalCue)) {
        final i = candidates.indexWhere(
          (c) => c.authority == BrainAuthorityId.pregnancy,
        );
        if (i >= 0) {
          candidates[i] = const UnifiedBrainCandidate(
            authority: BrainAuthorityId.pregnancy,
            role: BrainAuthorityRole.contextual,
            priority: 220,
            mayHandleReason: 'contextualModifier',
          );
        }
      }

      final primaryId = _unifiedBrain.selectPrimary(brainTurn, candidates);

      // تحديث صامت لجلسات سياقية (حمل/مراهق) دون رد ثانٍ — يحفظ الأسابيع/العمر.
      Future<void> absorbContextualSessions() async {
        for (final c in candidates) {
          if (c.role != BrainAuthorityRole.contextual) continue;
          if (c.authority == primaryId) continue;
          try {
            if (c.authority == BrainAuthorityId.pregnancy &&
                (pregMay || brainTurn.hasPregnancyCue)) {
              final t = await _pregnancyCompanion.handle(
                text: workingQuery,
                session: context.pregnancyCompanionSession,
              );
              context.setPregnancyCompanionSession(t.session);
            } else if (c.authority == BrainAuthorityId.adolescent && adoMay) {
              final t = await _adolescentCompanion.handle(
                text: workingQuery,
                session: context.adolescentCompanionSession,
                resolvedAgeYears: ageRes.ageYears,
              );
              if (!t.deferToClinicalPack) {
                context.setAdolescentCompanionSession(t.session);
              }
            }
          } catch (_) {
            // فشل سياقي لا يوقف الرد الأساسي
          }
        }
      }

      Future<AssistantActionPlan?> runSelected(BrainAuthorityId id) async {
        switch (id) {
          case BrainAuthorityId.pregnancy:
            final pregTurn = await _pregnancyCompanion.handle(
              text: workingQuery,
              session: context.pregnancyCompanionSession,
            );
            context.setPregnancyCompanionSession(pregTurn.session);
            if (pregTurn.deferToMedicalSafety ||
                pregTurn.deferToMentalSafety ||
                pregTurn.deferToFollowUp) {
              return null;
            }
            if (!pregTurn.handled) return null;
            context.invalidateSiblingClinicalSessions(
              primary: BrainAuthorityId.pregnancy,
            );
            return _finishUnifiedClinical(
              context: context,
              intent: intent,
              message: pregTurn.message,
              textFirstOnly: pregTurn.textFirstOnly,
              brainTurn: brainTurn,
              candidates: candidates,
              primary: BrainAuthorityId.pregnancy,
              clearedForeign: clearedForeign,
              questionUsed: pregTurn.session.lastQuestionKey != null,
            );
          case BrainAuthorityId.dental:
            final dentalTurn = await _dentalGuidance.handle(
              text: workingQuery,
              session: context.dentalSession,
            );
            context.setDentalSession(dentalTurn.session);
            if (dentalTurn.deferToMedicalSafety ||
                dentalTurn.deferToMentalSafety ||
                dentalTurn.deferToFollowUp) {
              return null;
            }
            if (!dentalTurn.handled) return null;
            context.invalidateSiblingClinicalSessions(
              primary: BrainAuthorityId.dental,
              keepPregnancyContextual: brainTurn.hasPregnancyCue ||
                  context.pregnancyCompanionSession.active,
              keepAdolescentContextual: brainTurn.hasAdolescentCue,
            );
            return _finishUnifiedClinical(
              context: context,
              intent: intent,
              message: dentalTurn.message,
              textFirstOnly: dentalTurn.textFirstOnly,
              brainTurn: brainTurn,
              candidates: candidates,
              primary: BrainAuthorityId.dental,
              clearedForeign: clearedForeign,
              questionUsed: dentalTurn.session.lastQuestionKey != null,
            );
          case BrainAuthorityId.msk:
            final mskTurn = await _mskGuidance.handle(
              text: workingQuery,
              session: context.mskSession,
            );
            context.setMskSession(mskTurn.session);
            if (mskTurn.deferToMedicalSafety ||
                mskTurn.deferToMentalSafety ||
                mskTurn.deferToFollowUp) {
              return null;
            }
            if (!mskTurn.handled) return null;
            context.invalidateSiblingClinicalSessions(
              primary: BrainAuthorityId.msk,
              keepPregnancyContextual: brainTurn.hasPregnancyCue ||
                  context.pregnancyCompanionSession.active,
              keepAdolescentContextual: brainTurn.hasAdolescentCue,
            );
            return _finishUnifiedClinical(
              context: context,
              intent: intent,
              message: mskTurn.message,
              textFirstOnly: mskTurn.textFirstOnly,
              brainTurn: brainTurn,
              candidates: candidates,
              primary: BrainAuthorityId.msk,
              clearedForeign: clearedForeign,
              questionUsed: mskTurn.session.lastQuestionKey != null,
            );
          case BrainAuthorityId.respiratory:
            final nlu = await _maybeRespiratoryNlu(
              query: workingQuery,
              session: context.respiratorySession,
              intent: intent.intent,
            );
            final respTurn = await _respiratoryGuidance.handle(
              text: workingQuery,
              session: context.respiratorySession,
              nluParse: nlu.parse,
            );
            context.setRespiratorySession(respTurn.session);
            lastNluTraceForTest = NluDebugTrace(
              called: nlu.called,
              skipReason: nlu.skipReason,
              fallbackReason: nlu.fallbackReason,
              gateReason: nlu.gateReason,
              deterministicFever: nlu.deterministic.fever,
              deterministicBreathlessness: nlu.deterministic.breathlessness,
              acceptedSlots: nlu.acceptedSlots,
              rejectedSlots: nlu.rejectedSlots,
              mergedFever: respTurn.session.fever,
              mergedBreathlessness: respTurn.session.breathlessness,
              finalPopulation: respTurn.session.population,
              finalHasCough: respTurn.session.hasCoughContext,
              finalDuration: respTurn.session.durationBucket,
              responseCameFromPlanner: respTurn.handled &&
                  respTurn.message.trim().isNotEmpty,
            );
            logNluDebugTrace(lastNluTraceForTest!);
            context.setRespiratorySession(respTurn.session);
            if (respTurn.deferToMedicalSafety ||
                respTurn.deferToMentalSafety ||
                respTurn.deferToFollowUp) {
              return null;
            }
            if (!respTurn.handled) return null;
            context.invalidateSiblingClinicalSessions(
              primary: BrainAuthorityId.respiratory,
              keepPregnancyContextual: brainTurn.hasPregnancyCue ||
                  context.pregnancyCompanionSession.active,
              keepAdolescentContextual: brainTurn.hasAdolescentCue,
            );
            return _finishUnifiedClinical(
              context: context,
              intent: intent,
              message: respTurn.message,
              textFirstOnly: respTurn.textFirstOnly,
              brainTurn: brainTurn,
              candidates: candidates,
              primary: BrainAuthorityId.respiratory,
              clearedForeign: clearedForeign,
              questionUsed: respTurn.session.lastQuestionKey != null,
            );
          case BrainAuthorityId.chronicClinical:
            final ccTurn = await _chronicClinical.handle(
              text: workingQuery,
              session: context.chronicClinicalSession,
            );
            context.setChronicClinicalSession(ccTurn.session);
            if (ccTurn.deferToMedicalSafety ||
                ccTurn.deferToMentalSafety ||
                ccTurn.deferToFollowUp) {
              return null;
            }
            if (!ccTurn.handled) return null;
            context.invalidateSiblingClinicalSessions(
              primary: BrainAuthorityId.chronicClinical,
              keepPregnancyContextual: brainTurn.hasPregnancyCue ||
                  context.pregnancyCompanionSession.active,
            );
            return _finishUnifiedClinical(
              context: context,
              intent: intent,
              message: ccTurn.message,
              textFirstOnly: ccTurn.textFirstOnly,
              brainTurn: brainTurn,
              candidates: candidates,
              primary: BrainAuthorityId.chronicClinical,
              clearedForeign: clearedForeign,
              questionUsed: ccTurn.session.lastQuestionKey != null,
            );
          case BrainAuthorityId.adolescent:
            final adoTurn = await _adolescentCompanion.handle(
              text: workingQuery,
              session: context.adolescentCompanionSession,
              resolvedAgeYears: ageRes.ageYears,
            );
            context.setAdolescentCompanionSession(adoTurn.session);
            if (adoTurn.deferToMedicalSafety ||
                adoTurn.deferToMentalSafety ||
                adoTurn.deferToFollowUp ||
                adoTurn.deferToClinicalPack) {
              return null;
            }
            if (!adoTurn.handled) return null;
            context.invalidateSiblingClinicalSessions(
              primary: BrainAuthorityId.adolescent,
            );
            return _finishUnifiedClinical(
              context: context,
              intent: intent,
              message: adoTurn.message,
              textFirstOnly: adoTurn.textFirstOnly,
              brainTurn: brainTurn,
              candidates: candidates,
              primary: BrainAuthorityId.adolescent,
              clearedForeign: clearedForeign,
              questionUsed: adoTurn.session.lastQuestionKey != null,
            );
          case BrainAuthorityId.clinicalKnowledge:
            final ckTurn = await _clinicalKnowledge.handle(
              text: workingQuery,
              session: context.clinicalKnowledgeSession,
              urgentMedicalHint: urgentHealthHint,
            );
            context.setClinicalKnowledgeSession(ckTurn.session);
            if (ckTurn.deferToMedicalSafety || ckTurn.deferToMentalSafety) {
              return null;
            }
            if (!ckTurn.handled) return null;
            return _finishUnifiedClinical(
              context: context,
              intent: intent,
              message: ckTurn.message,
              textFirstOnly: ckTurn.textFirstOnly,
              brainTurn: brainTurn,
              candidates: candidates,
              primary: BrainAuthorityId.clinicalKnowledge,
              clearedForeign: clearedForeign,
              questionUsed: false,
            );
          default:
            return null;
        }
      }

      if (primaryId != BrainAuthorityId.none &&
          !brainTurn.isGreeting &&
          !brainTurn.isCancel) {
        await absorbContextualSessions();
        final plan = await runSelected(primaryId);
        if (plan != null) return plan;
      } else {
        final emptyPlan = _unifiedBrain.planFromContributions(
          turn: brainTurn,
          candidates: candidates,
          serviceHandoff: brainTurn.isServiceOrNavigationIntent,
        );
        context.setUnifiedBrainDiagnostics(
          _unifiedBrain.diagnosticsFromPlan(
            turn: brainTurn,
            plan: emptyPlan,
            candidates: candidates,
            clinicalSessionsClearedForForeignTurn: clearedForeign,
          ),
        );
      }
    } catch (_) {
      // فشل التحكيم لا يكسر Smart Brain — المسار يكمل
    }
    }

    // —— PC-1.16: مخطّط عافية عملي (طلب صريح؛ قبل رد السياق اليومي العام) ——
    try {
      final planMay = _wellbeingPlanner.mayHandle(
        query: workingQuery,
        session: context.wellbeingPlannerSession,
      );
      if (planMay && !urgentHealthHint) {
        final planTurn = await _wellbeingPlanner.handle(
          text: workingQuery,
          session: context.wellbeingPlannerSession,
          dailyContext: context.dailyLifeContext,
        );
        context.setWellbeingPlannerSession(planTurn.session);
        if (planTurn.deferToUrgentSafety ||
            planTurn.deferToMentalSafety ||
            planTurn.deferToEntityIntent) {
          // اترك المسار يكمل
        } else if (planTurn.deferToFollowUp && !planTurn.handled) {
          // اترك للمتابعة
        } else if (planTurn.handled) {
          context.setAssistantResponse(
            planTurn.message.isEmpty ? null : planTurn.message,
          );
          // إن طُلبت متابعة مع الخطة — لا نمنع؛ الرسالة توضح والسلطة PC-1.11
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            message: planTurn.message,
            canExecute: false,
            textFirstOnly: planTurn.textFirstOnly,
          );
        }
      }
    } catch (_) {
      // فشل المخطّط لا يكسر Smart Brain
    }

    // —— PC-1.15: رد متماسك متعدد الإشارات (قبل العافية) ——
    try {
      final dailyMay = _dailyContext.mayHandle(
        query: workingQuery,
        context: context.dailyLifeContext,
      );
      if (dailyMay && !urgentHealthHint) {
        final dailyTurn = await _dailyContext.handle(
          text: workingQuery,
          context: context.dailyLifeContext,
        );
        context.setDailyLifeContext(dailyTurn.context);
        dailySuppressWellness = dailyTurn.suppressWellnessPressure ||
            dailyTurn.context.hasHighLoad;
        if (dailyTurn.deferToUrgentSafety ||
            dailyTurn.deferToMentalSafety ||
            dailyTurn.deferToFollowUp ||
            dailyTurn.deferToPersonalMemory ||
            dailyTurn.deferToEntityIntent) {
          // اترك المسار يكمل للسلطة المناسبة
        } else if (dailyTurn.handled) {
          context.setAssistantResponse(
            dailyTurn.message.isEmpty ? null : dailyTurn.message,
          );
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            message: dailyTurn.message,
            canExecute: false,
            textFirstOnly: dailyTurn.textFirstOnly,
          );
        }
      }
    } catch (_) {
      // فشل Daily Context لا يكسر Smart Brain
    }

    // —— PC-1.14: عافية ونشاط بدني (بعد المتابعة؛ قبل الوقائي العام) ——
    final wellnessMay = _wellness.mayHandle(
      query: workingQuery,
      session: context.wellnessSession,
    );
    if (wellnessMay && !urgentHealthHint && !dailySuppressWellness) {
      try {
        final wellnessTurn = await _wellness.handle(
          text: workingQuery,
          session: context.wellnessSession,
        );
        if (wellnessTurn.deferToUrgentSafety ||
            wellnessTurn.deferToMentalSafety ||
            wellnessTurn.deferToFollowUp) {
          context.setWellnessSession(wellnessTurn.session);
          // اترك المسار يكمل
        } else if (wellnessTurn.handled) {
          context.setWellnessSession(wellnessTurn.session);
          context.setAssistantResponse(
            wellnessTurn.message.isEmpty ? null : wellnessTurn.message,
          );
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            message: wellnessTurn.message,
            canExecute: false,
            textFirstOnly: wellnessTurn.textFirstOnly,
          );
        }
      } catch (_) {
        // فشل العافية لا يكسر Smart Brain
      }
    }

    // —— PC-1.7: توجيه وقائي (requested-first، نص أولاً) ——
    final preventiveMay = _preventiveGuidance.mayHandle(
      query: workingQuery,
      session: context.preventiveSession,
    );
    if (preventiveMay &&
        !urgentHealthHint &&
        !_preventiveGuidance.shouldEscapeToProvider(workingQuery)) {
      final preventiveTurn = await _preventiveGuidance.handle(
        text: workingQuery,
        session: context.preventiveSession,
        turnId: context.turnId,
      );
      if (preventiveTurn.deferToUrgentSafety ||
          preventiveTurn.deferToMentalSafety) {
        context.setPreventiveSession(preventiveTurn.session);
        // اترك المسار يكمل للسلامة
      } else if (preventiveTurn.handled) {
        context.setPreventiveSession(preventiveTurn.session);
        context.setAssistantResponse(
          preventiveTurn.message.isEmpty ? null : preventiveTurn.message,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: preventiveTurn.message,
          canExecute: false,
          textFirstOnly: true,
        );
      }
    }

    // —— PC-1.8: ملفات العائلة/الأشخاص (نص أولاً) ——
    final familyMayHandle = _familyProfileCommands.mayHandle(
      query: workingQuery,
      pending: context.familyProfilePending,
    );
    if (familyMayHandle && !urgentHealthHint) {
      final familyTurn = await _familyProfileCommands.handle(
        text: workingQuery,
        pending: context.familyProfilePending,
      );
      if (familyTurn.handled) {
        context.setFamilyProfilePending(familyTurn.pending);
        if (familyTurn.linkedPersonId != null) {
          context.setLinkedFamilyPersonId(familyTurn.linkedPersonId);
        }
        context.setAssistantResponse(
          familyTurn.message.isEmpty ? null : familyTurn.message,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: familyTurn.message,
          canExecute: false,
          textFirstOnly: familyTurn.textFirstOnly,
        );
      }
    }

    // —— PC-1.12: أهداف/اهتمامات/تفضيلات (قبل الملف الأساسي لـ «شنو تعرف عني؟») ——
    final personalMemMay = _personalMemory.mayHandle(
      query: workingQuery,
      pending: context.personalMemoryPending,
    );
    if (personalMemMay && !urgentHealthHint) {
      final memTurn = await _personalMemory.handle(
        text: workingQuery,
        pending: context.personalMemoryPending,
      );
      if (memTurn.handled) {
        context.setPersonalMemoryPending(memTurn.pending);
        context.setAssistantResponse(
          memTurn.message.isEmpty ? null : memTurn.message,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: memTurn.message,
          canExecute: false,
          textFirstOnly: memTurn.textFirstOnly,
        );
      }
    }

    final profileMayHandle = _companionProfileCommands.mayHandle(
      query: workingQuery,
      pending: context.companionProfilePending,
    );
    if (profileMayHandle && !urgentHealthHint) {
      final doctorActive =
          context.activeEntityType == ConversationEntityType.doctor ||
              context.selectedDoctor != null;
      final profileTurn = await _companionProfileCommands.handle(
        text: workingQuery,
        pending: context.companionProfilePending,
        doctorEntityActive: doctorActive,
        preferHealthPriority: false,
      );
      if (profileTurn.handled) {
        context.setCompanionProfilePending(profileTurn.pending);
        if (profileTurn.pauseOnboarding &&
            context.companionOnboarding.isWaiting) {
          context.setCompanionOnboarding(
            _companionOnboarding.pause(context.companionOnboarding),
          );
        }
        context.setAssistantResponse(
          profileTurn.message.isEmpty ? null : profileTurn.message,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: profileTurn.message,
          canExecute: false,
          textFirstOnly: profileTurn.textFirstOnly,
        );
      }
    }

    // —— PC-1.2: جواب onboarding معلّق (بعد النية، قبل الصحة إن لم تكن مقاطعة) ——
    final onboardingInterrupt = _companionOnboarding.shouldInterruptForQuery(
      query: workingQuery,
      looksLikeHealth: healthCandidate,
      isEntityIntent: _isCompanionEntityIntent(intent.intent, workingQuery),
    );
    if (context.companionOnboarding.isWaiting) {
      if (onboardingInterrupt) {
        context.setCompanionOnboarding(
          _companionOnboarding.pause(context.companionOnboarding),
        );
      } else {
        final turn = await _companionOnboarding.handleAnswer(
          text: workingQuery,
          state: context.companionOnboarding,
        );
        if (turn.handled) {
          context.setCompanionOnboarding(turn.state);
          if (turn.state.status == CompanionOnboardingStatus.paused) {
            context.onboardingLaterThisSession = true;
          }
          if (turn.pauseAndForward &&
              (turn.forwardQuery ?? '').trim().isNotEmpty) {
            return _planImpl(
              query: turn.forwardQuery!.trim(),
              context: context,
              allowGuided: false,
            );
          }
          context.setAssistantResponse(
            turn.message.isEmpty ? null : turn.message,
          );
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            message: turn.message,
            canExecute: false,
            textFirstOnly: true,
          );
        }
      }
    } else if (!onboardingInterrupt &&
        !context.onboardingLaterThisSession &&
        _looksLikeCompanionOfferTrigger(workingQuery)) {
      final offer = await _companionOnboarding.beginOffer(
        context.companionOnboarding,
        laterThisSession: context.onboardingLaterThisSession,
      );
      if (offer.handled) {
        context.setCompanionOnboarding(offer.state);
        context.setAssistantResponse(offer.message);
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: offer.message,
          canExecute: false,
          textFirstOnly: true,
        );
      }
    }

    // —— Step 10A: إلغاء / تغيير موضوع قبل أي تفسير جواب ——
    if (guidedAllowed && context.guidedConversation.isWaitingForAnswer) {
      final topic = _guidedEngine.topicChangeDetector.detect(
        query: workingQuery,
        intentResult: intent,
      );
      if (topic.kind == GuidedTopicChangeKind.cancelOnly) {
        final resp = _guidedEngine.cancel(
          writeState: context.setGuidedConversation,
          turnId: context.turnId,
        );
        if (context.healthGuidanceSession.isActive) {
          context.setHealthGuidanceSession(
            context.healthGuidanceSession.copyWith(
              status: HealthGuidanceSessionStatus.cancelled,
              updatedTurnId: context.turnId,
              clearDecision: true,
              clearPendingMissingFact: true,
            ),
          );
        }
        context.setAssistantResponse(resp.message);
        return AssistantActionPlan(
          kind: AssistantActionKind.guidedConversation,
          intentResult: intent,
          message: resp.message,
          guidedResponse: resp,
          canExecute: false,
        );
      }
      if (topic.kind == GuidedTopicChangeKind.topicChanged) {
        context.setGuidedConversation(
          GuidedConversationState(
            status: GuidedFlowStatus.cancelled,
            lastUpdatedTurnId: context.turnId,
            flowId: context.guidedConversation.flowId,
            flowType: context.guidedConversation.flowType,
            collectedAnswers: context.guidedConversation.collectedAnswers,
          ),
        );
        if (context.healthGuidanceSession.isActive) {
          context.setHealthGuidanceSession(
            context.healthGuidanceSession.copyWith(
              status: HealthGuidanceSessionStatus.cancelled,
              updatedTurnId: context.turnId,
              clearDecision: true,
              clearPendingMissingFact: true,
            ),
          );
        }
        final forward = (topic.forwardQuery ?? workingQuery).trim();
        if (forward.isNotEmpty && forward != workingQuery) {
          return _planImpl(
            query: forward,
            context: context,
            allowGuided: false,
          );
        }
        // نفس النص لكن نية تطبيق صريحة — تابع المسار العادي بدون جواب موجَّه.
        guidedAllowed = false;
      }
    }

    // Step 5 (أ): اقتراح تصحيح اسم طبيب معلّق («ما لقيت مطابقة دقيقة. هل تقصد
    // د. …؟»). دلالة مستقلة عن PendingClarification: مرشّح واحد بلا ترتيب وبلا
    // pendingAction — «نعم» تختار الطبيب فقط ولا تفتح اتصالاً/واتساب.
    // استهلاك-مرة-واحدة: أي دور تالٍ يُنهي الاقتراح، قبولاً أو رفضاً أو تجاوزاً
    // ببحث جديد، فلا يبقى اقتراح قديم يخطف عبارة «نعم» لاحقة.
    final doctorSuggestion = context.pendingDoctorSuggestion;
    if (doctorSuggestion != null) {
      context.clearPendingDoctorSuggestion();
      if (ArabicAnswerNormalizer.isBareYes(workingQuery)) {
        return await _resumeAfterDoctorSuggestion(
          context: context,
          suggestion: doctorSuggestion,
          intentResult: intent,
        );
      }
    }

    // Step 5: إن وُجد توضيح معلّق — حاول جواب التوضيح أولاً.
    final pending = context.pendingClarification;
    if (pending != null) {
      // جواب يحدّد مرشّحاً بعينه («طبيب الأطفال» بين خيارين) هو إجابة على
      // سؤالنا لا بحث جديد — حتى لو صُنِّف كبحث اختصاص صريح.
      final clarified = _clarificationResolver.resolve(
        query: workingQuery,
        pending: pending,
        intentResult: intent,
      );
      final answersPending =
          clarified.status == ClarificationResolveStatus.resolved;
      if (!answersPending &&
          ClarificationResolver.isClearNewSearchIntent(intent, workingQuery)) {
        context.clearPendingClarification();
      } else {
        switch (clarified.status) {
          case ClarificationResolveStatus.resolved:
            return await _resumeAfterClarification(
              context: context,
              pending: pending,
              candidate: clarified.candidate!,
              intentResult: intent,
              actionOverride: (intent.isActionIntent &&
                      intent.intent != AssistantIntent.selectResult)
                  ? intent.intent
                  : null,
            );
          case ClarificationResolveStatus.stillAmbiguous:
          case ClarificationResolveStatus.invalidOrdinal:
          case ClarificationResolveStatus.unsafeYesNo:
            final candidates = switch (pending.entityType) {
              ClarificationEntityType.laboratory => pending.labResults,
              ClarificationEntityType.analysis => pending.analysisResults,
              ClarificationEntityType.package ||
              ClarificationEntityType.offer =>
                pending.packageResults,
              _ => pending.doctorResults,
            };
            context.setAssistantResponse(clarified.message);
            return AssistantActionPlan(
              kind: AssistantActionKind.showClarification,
              intentResult: intent.copyWithClarification(true),
              candidates: candidates,
              message: clarified.message.isNotEmpty
                  ? clarified.message
                  : _clarificationResponses.build(pending),
              canExecute: false,
            );
          case ClarificationResolveStatus.notAnAnswer:
            break;
        }
      }
    }

    // —— Step 10A/10D: جواب السؤال الموجَّه قبل البحث العام ——
    final guidedState = context.guidedConversation;
    final awaitingGuided = guidedState.isWaitingForAnswer;
    final correctingCompleted = guidedAllowed &&
        guidedState.status == GuidedFlowStatus.completed &&
        guidedState.collectedAnswers.isNotEmpty &&
        ArabicAnswerNormalizer.looksLikeCorrection(workingQuery);
    final healthWaiting = context.healthGuidanceSession.status ==
        HealthGuidanceSessionStatus.waitingForAnswer;

    // Step 10D: إجابات صحية سياقية (لماذا/إعادة صياغة/حقائق قصيرة) قبل guided العام
    if (guidedAllowed && healthWaiting) {
      final pendingQ = guidedState.pendingQuestion ??
          context.healthGuidanceSession.currentDecision?.nextQuestion;
      final topic = _guidedEngine.topicChangeDetector.detect(
        query: workingQuery,
        intentResult: intent,
      );
      if (topic.kind == GuidedTopicChangeKind.cancelOnly) {
        context.setHealthGuidanceSession(
          context.healthGuidanceSession.copyWith(
            status: HealthGuidanceSessionStatus.cancelled,
            updatedTurnId: context.turnId,
            clearDecision: true,
            clearPendingMissingFact: true,
            clearPendingMeta: true,
            clearHandoff: true,
          ),
        );
        final cancelled = _guidedEngine.cancel(
          writeState: context.setGuidedConversation,
          turnId: context.turnId,
          message: 'تم إيقاف المساعدة الصحية.',
        );
        context.setAssistantResponse(cancelled.message);
        return AssistantActionPlan(
          kind: AssistantActionKind.healthGuidance,
          intentResult: intent,
          message: cancelled.message,
          guidedResponse: cancelled,
          canExecute: false,
        );
      }
      if (topic.kind == GuidedTopicChangeKind.topicChanged) {
        context.setHealthGuidanceSession(
          context.healthGuidanceSession.copyWith(
            status: HealthGuidanceSessionStatus.cancelled,
            updatedTurnId: context.turnId,
            clearDecision: true,
            clearPendingMissingFact: true,
            clearPendingMeta: true,
            clearHandoff: true,
          ),
        );
        _guidedEngine.cancel(
          writeState: context.setGuidedConversation,
          turnId: context.turnId,
          message: '',
        );
        final forward = (topic.forwardQuery ?? workingQuery).trim();
        return _planImpl(
          query: forward.isEmpty ? workingQuery : forward,
          context: context,
          allowGuided: false,
        );
      }

      if (pendingQ != null) {
        final cont = _healthCoordinator.continueAfterAnswer(
          answerText: workingQuery,
          session: context.healthGuidanceSession,
          turnId: context.turnId,
          pendingQuestion: pendingQ,
        );
        if (cont.keepPendingQuestion) {
          context.setHealthGuidanceSession(cont.session);
          context.setAssistantResponse(
            cont.message.isEmpty ? null : cont.message,
          );
          return AssistantActionPlan(
            kind: AssistantActionKind.healthGuidance,
            intentResult: intent,
            message: cont.message,
            healthDecision: cont.decision,
            canExecute: false,
          );
        }
        // أوقف تدفق guided الحالي قبل سؤال/قرار جديد
        context.setGuidedConversation(
          GuidedConversationState(
            status: GuidedFlowStatus.completed,
            lastUpdatedTurnId: context.turnId,
            collectedAnswers: guidedState.collectedAnswers,
            flowId: guidedState.flowId,
            flowType: guidedState.flowType,
          ),
        );
        return _applyHealthCoordinatorResult(
          context: context,
          intent: intent,
          result: cont,
        );
      }
    }

    if (guidedAllowed && (awaitingGuided || correctingCompleted)) {
      final guidedResp = _guidedEngine.handleUserInput(
        query: workingQuery,
        state: context.guidedConversation,
        writeState: context.setGuidedConversation,
        turnId: context.turnId,
        intentResult: intent,
      );
      if (guidedResp.topicChanged) {
        if (context.healthGuidanceSession.isActive) {
          context.setHealthGuidanceSession(
            context.healthGuidanceSession.copyWith(
              status: HealthGuidanceSessionStatus.cancelled,
              updatedTurnId: context.turnId,
              clearDecision: true,
              clearPendingMissingFact: true,
              clearPendingMeta: true,
            ),
          );
        }
        final forward = (guidedResp.forwardQuery ?? workingQuery).trim();
        return _planImpl(
          query: forward.isEmpty ? workingQuery : forward,
          context: context,
          allowGuided: false,
        );
      }
      if (guidedResp.cancelled) {
        if (context.healthGuidanceSession.isActive) {
          context.setHealthGuidanceSession(
            context.healthGuidanceSession.copyWith(
              status: HealthGuidanceSessionStatus.cancelled,
              updatedTurnId: context.turnId,
              clearDecision: true,
              clearPendingMissingFact: true,
              clearPendingMeta: true,
            ),
          );
        }
        context.setAssistantResponse(
          guidedResp.message.isEmpty ? null : guidedResp.message,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.guidedConversation,
          intentResult: intent,
          message: guidedResp.message,
          guidedResponse: guidedResp,
          canExecute: false,
        );
      }

      // متابعة سؤال صحي عبر 10C/10D بعد اكتمال جواب 10A
      final isHealthFlow = healthWaiting ||
          context.healthGuidanceSession.status ==
              HealthGuidanceSessionStatus.waitingForAnswer ||
          guidedState.flowType == GuidedFlowType.healthGuidanceReserved;
      if (isHealthFlow &&
          (guidedResp.flowStatus == GuidedFlowStatus.completed ||
              correctingCompleted)) {
        final answers = context.guidedConversation.collectedAnswers;
        GuidedAnswer? lastAnswer;
        if (answers.isNotEmpty) {
          lastAnswer = answers.values.last;
        }
        final cont = _healthCoordinator.continueAfterAnswer(
          answerText: workingQuery,
          session: context.healthGuidanceSession,
          turnId: context.turnId,
          guidedAnswer: lastAnswer,
          pendingQuestion: guidedState.pendingQuestion ??
              context.healthGuidanceSession.currentDecision?.nextQuestion,
        );
        return _applyHealthCoordinatorResult(
          context: context,
          intent: intent,
          result: cont,
        );
      }

      if (guidedResp.flowStatus == GuidedFlowStatus.waitingForAnswer ||
          guidedResp.message.isNotEmpty) {
        if (guidedResp.message.isNotEmpty ||
            guidedResp.flowStatus == GuidedFlowStatus.waitingForAnswer) {
          context.setAssistantResponse(
            guidedResp.message.isEmpty ? null : guidedResp.message,
          );
          return AssistantActionPlan(
            kind: AssistantActionKind.guidedConversation,
            intentResult: intent,
            message: guidedResp.message,
            guidedResponse: guidedResp,
            canExecute: false,
          );
        }
      }
      // unresolved → تابع المسار العادي
    }

    // —— PC-1.9: ربط الشخص الدائم بالموضوع الصحي ——
    HealthSubjectContext? enrichedSubject;
    final personBind = await _subjectBinding.processTurn(
      query: workingQuery,
      context: context,
      intent: intent,
      healthSession: context.healthGuidanceSession,
    );
    if (personBind.needsClarification) {
      _subjectBinding.applyToContext(context, personBind);
      context.setAssistantResponse(personBind.message);
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: personBind.message,
        canExecute: false,
        textFirstOnly: true,
      );
    }
    if (!personBind.deferredToEntityPipeline) {
      _subjectBinding.applyToContext(context, personBind);
      enrichedSubject = personBind.enrichedHealthSubject;
      if (personBind.continuationQuery != null &&
          personBind.continuationQuery!.trim().isNotEmpty) {
        workingQuery = personBind.continuationQuery!.trim();
        intent = _intentResolver.resolve(workingQuery);
        context.rememberQuery(workingQuery, intent: intent.intent);
      }
    }

    // Phase 3C — إعادة جسر المالك بعد ربط PC-1.9 حتى لا يُمسَح الجنس/العمر.
    try {
      final ownerProfile =
          await _companionOnboarding.profiles.loadProfile();
      _applyOwnerProfileContextBridge(context, ownerProfile);
    } catch (_) {}

    // —— Step 10C: توجيه صحي عند لغة أعراض (وليس أمر تطبيق صريح) ——
    final healthPlan = _tryHealthGuidance(
      query: workingQuery,
      context: context,
      intent: intent,
      allow: guidedAllowed,
      enrichedSubject: enrichedSubject,
    );
    if (healthPlan != null) return healthPlan;

    return _planNormalPipeline(
      query: workingQuery,
      context: context,
      intent: intent,
    );
  }

  AssistantActionPlan? _tryHealthGuidance({
    required String query,
    required ConversationContext context,
    required IntentResult intent,
    required bool allow,
    HealthSubjectContext? enrichedSubject,
  }) {
    if (!allow) return null;
    if (ClarificationResolver.isClearNewSearchIntent(intent, query)) {
      return null;
    }
    switch (intent.intent) {
      case AssistantIntent.findLab:
      case AssistantIntent.findAnalysis:
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
      case AssistantIntent.specialtySearch:
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.bookAppointment:
        return null;
      case AssistantIntent.doctorSearch:
        // بحث طبيب صريح فقط يمنع المسار الصحي — لا العبارات الصحية القصيرة.
        final n = ArabicTextUtils.normalize(query);
        if (RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور).{0,16}(?:طبيب|دكتور)|(?:^|\s)(?:ال)?(?:دكتور|طبيب)\s+\S{2,}',
        ).hasMatch(n)) {
          return null;
        }
        break;
      default:
        break;
    }

    // جلسة صحية نشطة بانتظار — تُعالَج عبر guided أعلاه
    if (context.healthGuidanceSession.status ==
        HealthGuidanceSessionStatus.waitingForAnswer) {
      return null;
    }

    // «ارجع للتوجيه» — إعادة سؤال التسليم إن بقيت الوجهة جلسةً.
    final nq = ArabicTextUtils.normalize(query);
    if (RegExp(r'ارجع\s*(?:ل)?التوجيه').hasMatch(nq)) {
      final ret = _healthCoordinator.tryReturnToGuidance(
        session: context.healthGuidanceSession,
        turnId: context.turnId,
      );
      if (ret != null) {
        return _applyHealthCoordinatorResultSync(
          context: context,
          intent: intent,
          result: ret,
        );
      }
    }

    // «نرجع لابني» وما شابه — حتى بدون لغة أعراض في الجملة.
    if (_healthCoordinator.subjectCoordinator.detector
            .detect(query)
            .returnToPrevious &&
        context.healthGuidanceSession.isActive) {
      final retSub = _healthCoordinator.startFromUserText(
        query: query,
        current: context.healthGuidanceSession,
        turnId: context.turnId,
        enrichedSubject: enrichedSubject,
      );
      if (retSub.handled) {
        return _applyHealthCoordinatorResultSync(
          context: context,
          intent: intent,
          result: retSub,
        );
      }
    }

    if (!_healthCoordinator.shouldConsiderHealthFlow(query) &&
        !context.healthGuidanceSession.isActive) {
      return null;
    }

    // إعادة تقييم جلسة مقررة عند نص صحي إضافي
    final result = _healthCoordinator.startFromUserText(
      query: query,
      current: context.healthGuidanceSession,
      turnId: context.turnId,
      enrichedSubject: enrichedSubject,
    );
    if (!result.handled) return null;
    return _applyHealthCoordinatorResultSync(
      context: context,
      intent: intent,
      result: result,
    );
  }

  /// نسخة متزامنة — الاكتشاف الحقيقي يُنفَّذ عبر المسار غير المتزامن.
  AssistantActionPlan _applyHealthCoordinatorResultSync({
    required ConversationContext context,
    required IntentResult intent,
    required HealthGuidanceCoordinatorResult result,
  }) {
    context.setHealthGuidanceSession(result.session);
    final boundSubject = result.session.facts.subject;
    if (boundSubject.linkedPersonId != null) {
      context.setLinkedFamilyPersonId(boundSubject.linkedPersonId);
    } else if (boundSubject.type == HealthSubjectType.self) {
      context.setLinkedFamilyPersonId(null);
    }

    if (result.startGuidedFlow != null) {
      context.advanceTurn();
      final guided = _guidedEngine.startFlow(
        definition: result.startGuidedFlow!,
        readState: () => context.guidedConversation,
        writeState: context.setGuidedConversation,
        turnId: context.turnId,
      );
      final message =
          result.message.isNotEmpty ? result.message : guided.message;
      context.setAssistantResponse(message);
      return AssistantActionPlan(
        kind: AssistantActionKind.healthGuidance,
        intentResult: intent,
        message: message,
        healthDecision: result.decision,
        guidedResponse: guided,
        canExecute: false,
      );
    }

    context.setAssistantResponse(
      result.message.isEmpty ? null : result.message,
    );
    return AssistantActionPlan(
      kind: AssistantActionKind.healthGuidance,
      intentResult: intent,
      message: result.message,
      healthDecision: result.decision,
      canExecute: false,
    );
  }

  Future<AssistantActionPlan> _applyHealthCoordinatorResult({
    required ConversationContext context,
    required IntentResult intent,
    required HealthGuidanceCoordinatorResult result,
  }) async {
    if (result.runProviderDiscovery) {
      return _runAcceptedProviderDiscovery(
        context: context,
        intent: intent,
        result: result,
      );
    }
    return _applyHealthCoordinatorResultSync(
      context: context,
      intent: intent,
      result: result,
    );
  }

  Future<AssistantActionPlan> _runAcceptedProviderDiscovery({
    required ConversationContext context,
    required IntentResult intent,
    required HealthGuidanceCoordinatorResult result,
  }) async {
    final dest = result.session.handoff.destination ??
        result.decision?.destination;
    if (dest == null) {
      context.setHealthGuidanceSession(result.session);
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: 'ماگدرت أحدد وجهة التوجيه حالياً.',
        canExecute: false,
      );
    }

    // جدار إضافي: لا اكتشاف من العاجل/الطوارئ
    if (dest.type == GuidanceDestinationType.urgentEvaluation ||
        result.decision?.type ==
            HealthGuidanceDecisionType.urgentEvaluation ||
        result.decision?.type ==
            HealthGuidanceDecisionType.emergencyEvaluation) {
      context.setHealthGuidanceSession(
        result.session.copyWith(clearHandoff: true),
      );
      final msg = result.decision?.userMessage ??
          result.decision?.safetyMessage ??
          '';
      context.setAssistantResponse(msg.isEmpty ? null : msg);
      return AssistantActionPlan(
        kind: AssistantActionKind.healthGuidance,
        intentResult: intent,
        message: msg,
        healthDecision: result.decision,
        canExecute: false,
      );
    }

    final discovery = await _providerDiscovery.discover(dest);

    if (discovery.status == ProviderDiscoveryStatus.unsupported) {
      final session = result.session.copyWith(
        handoff: HealthGuidanceHandoff(
          status: HealthGuidanceHandoffStatus.unsupported,
          destination: dest,
        ),
        status: HealthGuidanceSessionStatus.completed,
      );
      context.setHealthGuidanceSession(session);
      context.setAssistantResponse(discovery.message);
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: discovery.message,
        healthDecision: result.decision,
        canExecute: false,
      );
    }

    if (discovery.status == ProviderDiscoveryStatus.empty ||
        discovery.items.isEmpty) {
      final session = result.session.copyWith(
        handoff: HealthGuidanceHandoff(
          status: HealthGuidanceHandoffStatus.empty,
          destination: dest,
          providerResultCount: 0,
          providerResultEntityType: discovery.entityType,
        ),
        status: HealthGuidanceSessionStatus.completed,
      );
      context.setHealthGuidanceSession(session);
      final emptyMsg = discovery.message.trim().isEmpty
          ? 'حالياً ما ظهر عندي مزوّد مطابق ضمن بيانات الغدير. أكدر أوجهك للبحث اليدوي أو اختصاص مناسب.'
          : discovery.message;
      context.setAssistantResponse(emptyMsg);
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: emptyMsg,
        healthDecision: result.decision,
        canExecute: false,
      );
    }

    // نتائج حقيقية فقط → ResultContext عبر rememberResults (Step 9).
    // لا beginNewDoctorSearch حتى لا نمسح selectedLaboratory/Analysis بلا داعٍ.
    final specialtyLabel = dest.displayNameAr;
    context.rememberResults(
      discovery.items,
      query: specialtyLabel,
      intent: AssistantIntent.specialtySearch,
      specialtyLabel: specialtyLabel,
      clearSelection: true,
    );

    final session = result.session.copyWith(
      handoff: HealthGuidanceHandoff(
        status: HealthGuidanceHandoffStatus.providersDisplayed,
        destination: dest,
        providerResultCount: discovery.items.length,
        providerResultEntityType: discovery.entityType,
      ),
      status: HealthGuidanceSessionStatus.completed,
    );
    context.setHealthGuidanceSession(session);

    // نتيجة واحدة: عرض دون اتصال تلقائي (سياسة Step 4/9).
    if (discovery.items.length == 1) {
      final only = discovery.items.first;
      context.selectEntity(only);
      final completed = session.copyWith(
        handoff: session.handoff.copyWith(
          status: HealthGuidanceHandoffStatus.completed,
        ),
      );
      context.setHealthGuidanceSession(completed);
      final msg =
          '${discovery.message} وجدت: ${only.title}.';
      context.setAssistantResponse(msg);
      return AssistantActionPlan(
        kind: AssistantActionKind.selectEntity,
        intentResult: intent,
        target: only,
        candidates: discovery.items,
        message: msg,
        healthDecision: result.decision,
        canExecute: true,
      );
    }

    final msg =
        '${discovery.message} لقيت ${discovery.items.length}. گلي رقم أو اسم.';
    context.setAssistantResponse(msg);
    return AssistantActionPlan(
      kind: AssistantActionKind.runSpecialtySearch,
      intentResult: intent,
      candidates: discovery.items,
      specialtyQuery: specialtyLabel,
      message: msg,
      healthDecision: result.decision,
      canExecute: true,
    );
  }

  Future<AssistantActionPlan> _planNormalPipeline({
    required String query,
    required ConversationContext context,
    required IntentResult intent,
  }) async {
    // Step 9: حل مراجع المحادثة (عودة تركيز / اسم كيان / أرخص سياقي / ضمير).
    final refPlan = await _planConversationReference(query, context, intent);
    if (refPlan != null) return refPlan;

    // جدار 10E/10F: حالة عاجلة قائمة تمنع اقتراحات الباقات/العروض التجارية.
    final healthDec = context.healthGuidanceSession.currentDecision;
    final urgentLock = healthDec != null &&
        (healthDec.type == HealthGuidanceDecisionType.urgentEvaluation ||
            healthDec.type == HealthGuidanceDecisionType.emergencyEvaluation ||
            healthDec.allowCommercialOffers == false) &&
        (healthDec.type == HealthGuidanceDecisionType.urgentEvaluation ||
            healthDec.type == HealthGuidanceDecisionType.emergencyEvaluation);
    if (urgentLock) {
      final wantsOffer = intent.intent == AssistantIntent.findOffer ||
          intent.intent == AssistantIntent.findPackage ||
          EntityTargetResolver.prefersPackage(
            intent: intent,
            context: context,
          ) ||
          RegExp(r'(?:باقه|باقة|باقات|عرض|عروض)').hasMatch(
            ArabicTextUtils.normalize(query),
          );
      if (wantsOffer) {
        final msg = healthDec.userMessage.isNotEmpty
            ? healthDec.userMessage
            : (healthDec.safetyMessage ??
                'حالياً الأولوية للتقييم الطبي العاجل، مو للعروض.');
        context.setAssistantResponse(msg);
        return AssistantActionPlan(
          kind: AssistantActionKind.healthGuidance,
          intentResult: intent,
          message: msg,
          healthDecision: healthDec,
          canExecute: false,
        );
      }
    }

    // لا توصية أعراض → تحليل في Step 7.
    if (_looksLikeSymptomGuidance(query)) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message:
            'ما أگدر أوصي بتحليل من الأعراض حالياً. ابحث عن اسم تحليل محدد إن تحب.',
        canExecute: false,
      );
    }

    // إيجاب/نفي حرّ وصل إلى هنا يعني أن لا حالة معلّقة استهلكته أعلاه (فعل
    // معلّق، اقتراح تصحيح اسم، توضيح، حوار موجَّه، حزم سريرية…). يُنهى كإقرار
    // محادثة قصير قبل أي توجيه بحث — «نعم» ليست نصاً يُبحث عنه.
    final bareAnswer = _planBareAnswerAcknowledgement(query, intent);
    if (bareAnswer != null) return bareAnswer;

    // مسار الباقات (Step 8) — قبل التحاليل.
    if (EntityTargetResolver.prefersPackage(
      intent: intent,
      context: context,
    )) {
      return _planPackage(query, context, intent);
    }

    // مسار التحاليل أولاً.
    if (EntityTargetResolver.prefersAnalysis(
      intent: intent,
      context: context,
    )) {
      return _planAnalysis(query, context, intent);
    }

    // مسار المختبرات عبر EntityTargetResolver.
    if (EntityTargetResolver.prefersLaboratory(
          intent: intent,
          context: context,
        ) ||
        intent.intent == AssistantIntent.findLab ||
        intent.intent == AssistantIntent.callLab ||
        intent.intent == AssistantIntent.messageLab ||
        intent.intent == AssistantIntent.findPackage) {
      return _planLaboratory(query, context, intent);
    }

    switch (intent.intent) {
      case AssistantIntent.selectResult:
        return _planSelect(query, context, intent);

      case AssistantIntent.showLocation:
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.showProfile:
        return _planAction(query, context, intent);

      case AssistantIntent.bookAppointment:
        return _planContextualBooking(query, context, intent);

      case AssistantIntent.specialtySearch:
        context.beginNewDoctorSearch(
          query: query,
          intent: intent.intent,
        );
        final specialty = VoiceSpecialtySearchCommand.tryParse(query);
        return AssistantActionPlan(
          kind: AssistantActionKind.runSpecialtySearch,
          intentResult: intent,
          specialtyQuery:
              specialty?.resolvedSpecialtyName ?? intent.entities.specialty,
          canExecute: true,
          message: '',
        );

      case AssistantIntent.doctorSearch:
        context.beginNewDoctorSearch(
          query: query,
          intent: intent.intent,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.runDoctorSearch,
          intentResult: intent,
          doctorQuery: intent.entities.doctorName ?? query,
          canExecute: true,
        );

      case AssistantIntent.generalSearch:
        // «نعم/لا» الحرّة لا تصل هنا — يستهلكها إقرار المحادثة أعلاه.
        context.beginNewDoctorSearch(
          query: query,
          intent: intent.intent,
        );
        return AssistantActionPlan(
          kind: AssistantActionKind.runGeneralSearch,
          intentResult: intent,
          canExecute: true,
        );

      case AssistantIntent.unknown:
      default:
        if (query.trim().isNotEmpty) {
          context.beginNewDoctorSearch(
            query: query,
            intent: AssistantIntent.generalSearch,
          );
          return AssistantActionPlan(
            kind: AssistantActionKind.runGeneralSearch,
            intentResult: intent,
            canExecute: true,
          );
        }
        return AssistantActionPlan(
          kind: AssistantActionKind.none,
          intentResult: intent,
        );
    }
  }

  /// Step 9 — مراجع المحادثة قبل مسارات الكيانات.
  Future<AssistantActionPlan?> _planConversationReference(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) async {
    final hint = intent.entities.actionHint ?? '';

    if (hint.startsWith('return_')) {
      final type = switch (hint) {
        'return_doctor' => ConversationEntityType.doctor,
        'return_lab' => ConversationEntityType.laboratory,
        'return_analysis' => ConversationEntityType.analysis,
        'return_package' => ConversationEntityType.package,
        _ => ConversationEntityType.none,
      };
      final selected = context.selectedOf(type);
      if (selected == null || type == ConversationEntityType.none) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: type == ConversationEntityType.doctor
              ? 'ما عندي طبيب محفوظ بالسياق. ابحث عن طبيب أولاً.'
              : type == ConversationEntityType.laboratory
                  ? 'ما عندي مختبر محفوظ بالسياق. ابحث عن مختبر أولاً.'
                  : type == ConversationEntityType.analysis
                      ? 'ما عندي تحليل محفوظ بالسياق.'
                      : type == ConversationEntityType.package
                          ? 'ما عندي باقة محفوظة بالسياق.'
                          : 'ما عندي كيان محفوظ للعودة إليه.',
          canExecute: false,
        );
      }
      context.focusOn(type);
      return AssistantActionPlan(
        kind: AssistantActionKind.selectEntity,
        intentResult: intent,
        target: selected,
        message: 'رجعت إلى ${selected.title}.',
        canExecute: true,
      );
    }

    final ref = _referenceResolver.resolve(
      query: query,
      intent: intent,
      context: context,
    );

    if (ref.confidence == ReferenceConfidence.unresolved &&
        !ref.returnFocus &&
        !ref.cheapest &&
        !ref.mostExpensive &&
        !ref.requiresClarification) {
      return null;
    }

    if (ref.returnFocus) {
      if (ref.requiresClarification || ref.target == null) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: ref.message.isNotEmpty
              ? ref.message
              : 'ما عندي كيان محفوظ للعودة إليه.',
          canExecute: false,
        );
      }
      if (ref.focusEntityType != null) {
        context.focusOn(ref.focusEntityType!);
      }
      return AssistantActionPlan(
        kind: AssistantActionKind.selectEntity,
        intentResult: intent,
        target: ref.target,
        message: 'رجعت إلى ${ref.target!.title}.',
        canExecute: true,
      );
    }

    if ((ref.cheapest || ref.mostExpensive) && ref.hasTarget) {
      context.selectPackage(ref.target!);
      final price = ref.target!.newPrice;
      final priceText =
          price != null ? ArabicSpeechNumbers.moneyIq(price) : '';
      return AssistantActionPlan(
        kind: AssistantActionKind.selectEntity,
        intentResult: intent,
        target: ref.target,
        candidates: context.currentPackageResultItems,
        message: ref.cheapest
            ? 'أرخص وحدة من النتائج الحالية: ${ref.target!.title}${priceText.isNotEmpty ? ' بسعر $priceText' : ''}.'
            : 'أغلى وحدة من النتائج الحالية: ${ref.target!.title}${priceText.isNotEmpty ? ' بسعر $priceText' : ''}.',
        canExecute: true,
      );
    }
    if ((ref.cheapest || ref.mostExpensive) && ref.requiresClarification) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: ref.message,
        canExecute: false,
      );
    }

    if (ref.confidence == ReferenceConfidence.ambiguous &&
        ref.requiresClarification) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showClarification,
        intentResult: intent.copyWithClarification(true),
        candidates: ref.candidates,
        message: ref.message.isNotEmpty ? ref.message : 'تقصد أي واحد؟',
        canExecute: false,
      );
    }

    if (ref.confidence == ReferenceConfidence.explicit &&
        ref.focusEntityType != null &&
        ref.target != null) {
      context.focusOn(ref.focusEntityType!);
      if (!_intentContinuesAfterNounFocus(intent, query)) {
        return AssistantActionPlan(
          kind: AssistantActionKind.selectEntity,
          intentResult: intent,
          target: ref.target,
          message: 'أقصد ${ref.target!.title}.',
          canExecute: true,
        );
      }
      return null;
    }

    if (ref.focusEntityType == ConversationEntityType.analysis &&
        ref.message.contains('ما عنده رقم اتصال')) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: ref.target,
        message: ref.message,
        canExecute: false,
      );
    }

    if (ref.confidence == ReferenceConfidence.relationshipContext &&
        ref.focusEntityType == ConversationEntityType.laboratory &&
        ref.target != null &&
        (intent.intent == AssistantIntent.callDoctor ||
            intent.intent == AssistantIntent.messageDoctor ||
            intent.intent == AssistantIntent.callLab ||
            intent.intent == AssistantIntent.messageLab ||
            ArabicTextUtils.normalize(query).contains('اتصل') ||
            ArabicTextUtils.normalize(query).contains('دزله') ||
            ArabicTextUtils.normalize(query).contains('واتس') ||
            ArabicTextUtils.normalize(query).contains('بيهم'))) {
      final lab = ref.target!;
      final isWa = intent.intent == AssistantIntent.messageDoctor ||
          intent.intent == AssistantIntent.messageLab ||
          ArabicTextUtils.normalize(query).contains('واتس') ||
          ArabicTextUtils.normalize(query).contains('دزله');
      var phone = isWa
          ? (lab.whatsapp ?? lab.phone)
          : (lab.phone ?? lab.whatsapp);

      // إن نقص رقم الاتصال — أكمل عبر مسار الباقة/المختبر (lookup حقيقي).
      if ((phone ?? '').trim().isEmpty &&
          context.activeEntityType == ConversationEntityType.package) {
        return null;
      }

      if ((phone ?? '').trim().isEmpty) {
        // حاول جلب المختبر الحي.
        final looked = await _lookupLabs(lab.title);
        final match = looked.where((l) => l.labId == lab.labId).toList();
        final enriched = match.isNotEmpty
            ? match.first
            : (looked.length == 1 ? looked.first : null);
        if (enriched != null) {
          phone = isWa
              ? (enriched.whatsapp ?? enriched.phone)
              : (enriched.phone ?? enriched.whatsapp);
          if ((phone ?? '').trim().isNotEmpty) {
            context.selectLaboratory(enriched);
            return AssistantActionPlan(
              kind: isWa
                  ? AssistantActionKind.prepareWhatsApp
                  : AssistantActionKind.prepareCall,
              intentResult: intent,
              target: enriched,
              message: isWa
                  ? 'سأفتح واتساب لمختبر ${enriched.title}.'
                  : 'سأتصل بمختبر ${enriched.title}.',
              canExecute: true,
            );
          }
        }
        final rel = _relationshipResolver.packageParentLaboratory(context);
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          target: lab,
          message: rel.unavailable
              ? (rel.message.isNotEmpty
                  ? rel.message
                  : 'المختبر المرتبط غير متوفر حالياً في بيانات الغدير.')
              : 'المختبر المرتبط غير متوفر برقم اتصال حالياً في بيانات الغدير.',
          canExecute: false,
        );
      }

      context.selectLaboratory(lab);
      return AssistantActionPlan(
        kind: isWa
            ? AssistantActionKind.prepareWhatsApp
            : AssistantActionKind.prepareCall,
        intentResult: intent,
        target: lab,
        message: isWa
            ? 'سأفتح واتساب لمختبر ${lab.title}.'
            : 'سأتصل بمختبر ${lab.title}.',
        canExecute: true,
      );
    }

    if (ref.focusEntityType == ConversationEntityType.analysis &&
        ref.message.contains('ماكو سعر مباشر')) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: ref.target,
        message: ref.message,
        canExecute: false,
      );
    }

    if (ref.requiresClarification) {
      return AssistantActionPlan(
        kind: ref.candidates.isNotEmpty
            ? AssistantActionKind.showClarification
            : AssistantActionKind.showMessage,
        intentResult: ref.candidates.isNotEmpty
            ? intent.copyWithClarification(true)
            : intent,
        candidates: ref.candidates,
        target: ref.target,
        message: ref.message.isNotEmpty ? ref.message : 'حدد المقصود أولاً.',
        canExecute: false,
      );
    }

    if (ref.hasTarget && _looksLikeOpenOrSelectReference(query, intent)) {
      if (ref.focusEntityType != null) {
        context.focusOn(ref.focusEntityType!);
      }
      // «افتحه» / «افتح هذا» مع نية الملف → مسار الفتح القائم، لا مجرد اختيار.
      if (intent.intent == AssistantIntent.showProfile) {
        return AssistantActionPlan(
          kind: AssistantActionKind.openProfile,
          intentResult: intent,
          target: ref.target,
          message: 'فتح ملف ${ref.target!.title}.',
          canExecute: true,
        );
      }
      return AssistantActionPlan(
        kind: AssistantActionKind.selectEntity,
        intentResult: intent,
        target: ref.target,
        message: 'أقصد ${ref.target!.title}.',
        canExecute: true,
      );
    }

    return null;
  }

  static bool _intentContinuesAfterNounFocus(
    IntentResult intent,
    String query,
  ) {
    final hint = intent.entities.actionHint ?? '';
    if (hint == 'packages_for_analysis' ||
        hint == 'labs_for_analysis' ||
        hint == 'where_analysis' ||
        hint == 'price' ||
        hint == 'package_price' ||
        hint == 'package_analyses' ||
        hint == 'packages') {
      return true;
    }
    final n = ArabicTextUtils.normalize(query);
    // لا تُكمل على مجرد «هذا التحليل» / «هاي الباقة».
    if (intent.intent == AssistantIntent.callDoctor ||
        intent.intent == AssistantIntent.messageDoctor ||
        intent.intent == AssistantIntent.callLab ||
        intent.intent == AssistantIntent.messageLab) {
      return true;
    }
    if (RegExp(
      r'^(?:هذا|هاي|هذ|هذه|هذي|هذاك|ذاك|نفس)\s*(?:ال)?(?:تحليل|باقه|باقة|مختبر|طبيب|دكتور)\s*$',
    ).hasMatch(n.trim())) {
      return false;
    }
    return RegExp(
      r'(?:باي\s+باق)|(?:وين\s+موجود)|(?:اي\s+مختبر)|(?:سعر)|(?:تحاليل)|(?:باقات)|'
      r'(?:اتصل|راسل|دزله|واتس)',
    ).hasMatch(n);
  }

  static bool _looksLikeOpenOrSelectReference(
    String query,
    IntentResult intent,
  ) {
    if (intent.intent == AssistantIntent.callDoctor ||
        intent.intent == AssistantIntent.messageDoctor ||
        intent.intent == AssistantIntent.callLab ||
        intent.intent == AssistantIntent.messageLab) {
      return false;
    }
    final n = ArabicTextUtils.normalize(query);
    // «افتح هذا» / «اختار هاي» فقط — ليس «نبذته» أو «افتح ملفه».
    return RegExp(
      r'(?:افتحه|افتحها)|'
      r'(?:افتح|اعرض|اختار|شارك)\s+(?:هذا|هاي|هذي|هذه|هذاك|ذاك)\s*$',
    ).hasMatch(n);
  }

  Future<AssistantActionPlan> _planPackage(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) async {
    final hint = intent.entities.actionHint ?? '';

    if (hint == 'best_unsupported') {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message:
            'ما أگدر أوصي بـ«أفضل» باقة. حدّد معياراً مثل أرخص سعر، أو تحاليل معيّنة، أو مختبر.',
        canExecute: false,
      );
    }

    // باقة نشطة: «وين موجودة؟» / أسئلة مختبر التحليل السياقية → المختبر الأب.
    if (context.activeEntityType == ConversationEntityType.package &&
        context.selectedPackage != null &&
        (hint == 'where_analysis' ||
            hint == 'packages_for_analysis' ||
            hint == 'labs_for_analysis' ||
            intent.intent == AssistantIntent.findAnalysis &&
                (intent.entities.analysis ?? '').trim().isEmpty)) {
      return _planSelectedPackageAction(
        query,
        context,
        intent,
        hint: intent.intent == AssistantIntent.showLocation ||
                hint == 'where_analysis'
            ? 'contact_or_location'
            : 'package_lab',
      );
    }

    if (hint == 'offers' || intent.intent == AssistantIntent.findOffer) {
      return _planPackageOffers(query, context, intent);
    }

    if (hint == 'cheapest' || hint == 'cheapest_filter') {
      return _planCheapestPackage(query, context, intent, hint: hint);
    }

    if (hint == 'filter_analyses' ||
        intent.entities.analysisTerms.length >= 2) {
      return _planPackagesFilteredByAnalyses(query, context, intent);
    }

    if (hint == 'compare_packages') {
      return _planPackageComparison(query, context, intent);
    }

    if (hint == 'package_price' ||
        hint == 'package_analyses' ||
        hint == 'package_lab') {
      return _planSelectedPackageAction(query, context, intent, hint: hint);
    }

    // اتصال / واتساب / موقع / ملف على باقة نشطة → المختبر الأب.
    if (intent.intent == AssistantIntent.callDoctor ||
        intent.intent == AssistantIntent.messageDoctor ||
        intent.intent == AssistantIntent.callLab ||
        intent.intent == AssistantIntent.messageLab ||
        intent.intent == AssistantIntent.showLocation ||
        intent.intent == AssistantIntent.showProfile) {
      return _planSelectedPackageAction(
        query,
        context,
        intent,
        hint: hint == 'package_lab' ? 'package_lab' : 'contact_or_location',
      );
    }

    if (intent.intent == AssistantIntent.selectResult) {
      final target = _packageTargetResolver.resolve(
        intentResult: intent,
        context: context,
      );
      if (target.source == PackageTargetSource.ordinal && target.hasPackage) {
        context.setAssistantResponse('تم اختيار ${target.package!.title}');
        return AssistantActionPlan(
          kind: AssistantActionKind.selectEntity,
          intentResult: intent,
          target: target.package,
          message: 'تم اختيار ${target.package!.title}.',
          canExecute: true,
        );
      }
      if (target.requiresClarification) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showClarification,
          intentResult: intent.copyWithClarification(true),
          message: target.message,
          candidates: target.candidates,
          canExecute: false,
        );
      }
    }

    final packageName = (intent.entities.packageName ?? '').trim();
    if (packageName.isNotEmpty || hint == 'search') {
      if (packageName.isNotEmpty) {
        return _planPackageNameSearch(query, context, intent, packageName);
      }
    }

    // قائمة عامة: أريد باقات.
    return _planGlobalPackageList(query, context, intent);
  }

  Future<AssistantActionPlan> _planSelectedPackageAction(
    String query,
    ConversationContext context,
    IntentResult intent, {
    required String hint,
  }) async {
    final target = _packageTargetResolver.resolve(
      intentResult: intent,
      context: context,
    );
    if (target.source == PackageTargetSource.explicitName &&
        (target.explicitName ?? '').isNotEmpty) {
      final found = await _planPackageNameSearch(
        query,
        context,
        intent,
        target.explicitName!,
      );
      if (found.target == null && found.candidates.isEmpty) return found;
      if (found.kind == AssistantActionKind.showClarification) return found;
      final pkg = found.target ?? context.selectedPackage;
      if (pkg == null) return found;
      return _planForResolvedPackage(intent, context, pkg, hint: hint);
    }
    if (!target.hasPackage) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: target.message.isNotEmpty
            ? target.message
            : PackageTargetResolution.unresolved.message,
        candidates: target.candidates,
        canExecute: false,
      );
    }
    return _planForResolvedPackage(
      intent,
      context,
      target.package!,
      hint: hint,
    );
  }

  Future<AssistantActionPlan> _planForResolvedPackage(
    IntentResult intent,
    ConversationContext context,
    SmartSearchResult package, {
    required String hint,
  }) async {
    // أبقِ الكيان باقة ما لم يُطلب مختبر صراحةً.
    if (context.selectedPackage?.packageId != package.packageId) {
      context.selectPackage(package);
    } else {
      context.activeEntityType = ConversationEntityType.package;
    }

    if (hint == 'package_price') {
      final msg = _formatPriceMessage(package);
      return AssistantActionPlan(
        kind: AssistantActionKind.showPackagePrice,
        intentResult: intent,
        target: package,
        message: msg,
        canExecute: _currentPrice(package) != null,
      );
    }

    if (hint == 'package_analyses') {
      return _planPackageAnalyses(intent, context, package);
    }

    if (hint == 'package_lab' ||
        intent.intent == AssistantIntent.showLocation ||
        intent.intent == AssistantIntent.showProfile ||
        intent.intent == AssistantIntent.callLab ||
        intent.intent == AssistantIntent.messageLab ||
        intent.intent == AssistantIntent.callDoctor ||
        intent.intent == AssistantIntent.messageDoctor ||
        hint == 'contact_or_location') {
      return _planPackageParentLab(intent, context, package);
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.selectEntity,
      intentResult: intent,
      target: package,
      message: 'وجدت ${package.title}.',
      canExecute: true,
    );
  }

  Future<AssistantActionPlan> _planPackageAnalyses(
    IntentResult intent,
    ConversationContext context,
    SmartSearchResult package,
  ) async {
    List<AnalysisItem> analyses = const [];
    final packageId = package.packageId ?? '';
    final labId = package.labId;

    if (labId != null && labId.isNotEmpty) {
      final pkgs = await _lookupPackages(labId);
      final match = pkgs.where((p) => p.id == packageId).toList();
      if (match.isNotEmpty && match.first.analyses.isNotEmpty) {
        analyses = match.first.analyses;
      }
    }

    if (analyses.isEmpty && packageId.isNotEmpty) {
      final details = await _lookupPackageDetails(packageId);
      if (details != null && details.analyses.isNotEmpty) {
        analyses = details.analyses;
      }
    }

    if (analyses.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: package,
        message: 'ماكو تحاليل مرتبطة بهذه الباقة حالياً في بيانات الغدير.',
        canExecute: false,
      );
    }

    final asResults = [
      for (final a in analyses)
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: a.arabicDisplayName.isNotEmpty
              ? a.arabicDisplayName
              : a.displayLabel,
          subtitle: 'ضمن ${package.title}',
          analysisId: a.id,
          packageId: packageId.isNotEmpty ? packageId : null,
          labId: labId,
          labName: package.labName,
        ),
    ];
    // لا تبدّل activeEntityType إلى analysis بمجرد العرض.
    context.activeEntityType = ConversationEntityType.package;

    return AssistantActionPlan(
      kind: AssistantActionKind.showPackageAnalyses,
      intentResult: intent,
      target: package,
      candidates: asResults,
      analyses: analyses,
      message:
          'تحاليل باقة ${package.title}: ${asResults.map((r) => r.title).take(8).join('، ')}'
          '${asResults.length > 8 ? '…' : '.'}',
      canExecute: true,
    );
  }

  Future<AssistantActionPlan> _planPackageParentLab(
    IntentResult intent,
    ConversationContext context,
    SmartSearchResult package,
  ) async {
    final labName = (package.labName ?? '').trim();
    final labId = (package.labId ?? '').trim();
    if (labName.isEmpty && labId.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: package,
        message: 'ما أگدر أحدد المختبر التابع لهذه الباقة حالياً.',
        canExecute: false,
      );
    }

    final lab = await _resolveParentLab(package);
    final spokenLab = labName.isNotEmpty
        ? labName
        : (lab?.title ?? 'المختبر');

    final wantsContact = intent.intent == AssistantIntent.callDoctor ||
        intent.intent == AssistantIntent.messageDoctor ||
        intent.intent == AssistantIntent.callLab ||
        intent.intent == AssistantIntent.messageLab;
    final wantsWhatsApp = intent.intent == AssistantIntent.messageDoctor ||
        intent.intent == AssistantIntent.messageLab;
    final wantsLocation = intent.intent == AssistantIntent.showLocation;
    final wantsProfile = intent.intent == AssistantIntent.showProfile;
    final wantsLabInfo = intent.entities.actionHint == 'package_lab';

    // package_lab: أبقِ الباقة نشطة واذكر المختبر الأب.
    if (wantsLabInfo && !wantsContact && !wantsLocation && !wantsProfile) {
      context.activeEntityType = ConversationEntityType.package;
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: package,
        candidates: lab != null ? [lab] : const [],
        message: 'هذه الباقة تابعة لمختبر $spokenLab.',
        canExecute: true,
      );
    }

    if (wantsLocation) {
      context.activeEntityType = ConversationEntityType.package;
      if (lab == null) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          target: package,
          message:
              'هذه الباقة تابعة لمختبر $spokenLab، لكن موقع المختبر غير متوفر حالياً.',
          canExecute: false,
        );
      }
      final loc = (lab.clinicLocation ?? lab.subtitle).trim();
      if (loc.isEmpty || loc == 'مختبر') {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          target: package,
          candidates: [lab],
          message:
              'هذه الباقة تابعة لمختبر $spokenLab، لكن موقع المختبر غير متوفر حالياً.',
          canExecute: false,
        );
      }
      return AssistantActionPlan(
        kind: AssistantActionKind.showLocation,
        intentResult: intent,
        target: lab,
        candidates: [package],
        message: 'هذه الباقة تابعة لمختبر $spokenLab: $loc',
        canExecute: true,
      );
    }

    if (wantsProfile && lab != null) {
      return AssistantActionPlan(
        kind: AssistantActionKind.openProfile,
        intentResult: intent,
        target: lab,
        message: 'فتح ملف مختبر $spokenLab (تابع لباقة ${package.title}).',
        canExecute: true,
      );
    }

    if (wantsContact) {
      if (lab == null || (!lab.canCall && !lab.canWhatsApp)) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          target: package,
          candidates: lab != null ? [lab] : const [],
          message: lab == null
              ? 'الباقة نفسها ما عندها رقم اتصال. ما لقيت بيانات اتصال لمختبر $spokenLab.'
              : 'الباقة نفسها ما عندها رقم اتصال، ورقم مختبر $spokenLab غير متوفر حالياً.',
          canExecute: false,
        );
      }
      if (wantsWhatsApp) {
        if (!lab.canWhatsApp) {
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            target: lab,
            message: 'رقم واتساب مختبر $spokenLab غير متوفر حالياً.',
            canExecute: false,
          );
        }
        return AssistantActionPlan(
          kind: AssistantActionKind.prepareWhatsApp,
          intentResult: IntentResult(
            intent: AssistantIntent.messageLab,
            originalText: intent.originalText,
            normalizedText: intent.normalizedText,
            searchMeaning: intent.searchMeaning,
            entities: intent.entities,
            confidence: intent.confidence,
            source: intent.source,
          ),
          target: lab,
          message: 'جاهز لفتح واتساب مختبر $spokenLab (تابع لباقة ${package.title}).',
          canExecute: true,
        );
      }
      if (!lab.canCall) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          target: lab,
          message: 'رقم اتصال مختبر $spokenLab غير متوفر حالياً.',
          canExecute: false,
        );
      }
      return AssistantActionPlan(
        kind: AssistantActionKind.prepareCall,
        intentResult: IntentResult(
          intent: AssistantIntent.callLab,
          originalText: intent.originalText,
          normalizedText: intent.normalizedText,
          searchMeaning: intent.searchMeaning,
          entities: intent.entities,
          confidence: intent.confidence,
          source: intent.source,
        ),
        target: lab,
        message: 'جاهز للاتصال بمختبر $spokenLab (تابع لباقة ${package.title}).',
        canExecute: true,
      );
    }

    context.activeEntityType = ConversationEntityType.package;
    return AssistantActionPlan(
      kind: AssistantActionKind.showMessage,
      intentResult: intent,
      target: package,
      candidates: lab != null ? [lab] : const [],
      message: 'هذه الباقة تابعة لمختبر $spokenLab.',
      canExecute: true,
    );
  }

  Future<SmartSearchResult?> _resolveParentLab(
    SmartSearchResult package,
  ) async {
    final labId = (package.labId ?? '').trim();
    final labName = (package.labName ?? '').trim();
    if (labName.isNotEmpty) {
      final labs = await _lookupLabs(labName);
      if (labId.isNotEmpty) {
        final byId = labs.where((l) => l.labId == labId).toList();
        if (byId.isNotEmpty) return byId.first;
      }
      if (labs.length == 1) return labs.first;
      final byTitle = labs
          .where(
            (l) =>
                l.title == labName ||
                l.title.contains(labName) ||
                labName.contains(l.title),
          )
          .toList();
      if (byTitle.length == 1) return byTitle.first;
      if (byTitle.isNotEmpty) return byTitle.first;
    } else if (labId.isNotEmpty) {
      final labs = await _lookupLabs('مختبر');
      final byId = labs.where((l) => l.labId == labId).toList();
      if (byId.isNotEmpty) return byId.first;
    }

    if (labName.isEmpty && labId.isEmpty) return null;
    return SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: labName.isNotEmpty ? labName : 'مختبر',
      subtitle: '',
      labId: labId.isNotEmpty ? labId : null,
      labName: labName.isNotEmpty ? labName : null,
    );
  }

  Future<AssistantActionPlan> _planPackageOffers(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) async {
    final scopedLabId = context.selectedLaboratory?.labId;
    final links = await _lookupDiscountedPackages(labId: scopedLabId);
    if (links.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: 'ماكو عروض/باقات مخفّضة معروضة حالياً.',
        canExecute: false,
      );
    }
    final results = [for (final link in links) _packageToResult(link)];
    context.beginNewPackageSearch(query: query, intent: intent.intent);
    context.rememberResults(results, query: query, intent: intent.intent);
    return AssistantActionPlan(
      kind: AssistantActionKind.showOffers,
      intentResult: intent,
      candidates: results,
      packages: [for (final l in links) l.package],
      message: results.length == 1
          ? 'وجدت عرضاً: ${results.first.title}.'
          : 'وجدت ${results.length} عروض/باقات مخفّضة.',
      canExecute: true,
    );
  }

  Future<AssistantActionPlan> _planCheapestPackage(
    String query,
    ConversationContext context,
    IntentResult intent, {
    required String hint,
  }) async {
    // Step 9: إن وُجدت نتائج باقات حالية بدون فلتر تحاليل جديد — رتّب منها.
    final current = context.currentPackageResultItems;
    final hasNewAnalysisFilter = hint == 'cheapest_filter' &&
        intent.entities.allAnalysisTerms.isNotEmpty;
    if (current.isNotEmpty && !hasNewAnalysisFilter) {
      final priced = current
          .where((p) => p.newPrice != null && p.newPrice! > 0)
          .toList()
        ..sort((a, b) => a.newPrice!.compareTo(b.newPrice!));
      if (priced.isEmpty) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: 'ماكو أسعار متوفرة على الباقات المعروضة حالياً للمقارنة.',
          canExecute: false,
        );
      }
      final cheapest = priced.first;
      context.selectPackage(cheapest);
      final priceText = ArabicSpeechNumbers.moneyIq(cheapest.newPrice);
      return AssistantActionPlan(
        kind: AssistantActionKind.selectEntity,
        intentResult: intent,
        target: cheapest,
        candidates: current,
        message:
            'أرخص وحدة من النتائج الحالية: ${cheapest.title}${cheapest.labName != null && cheapest.labName!.isNotEmpty ? ' (${cheapest.labName})' : ''} بسعر $priceText.',
        canExecute: true,
      );
    }

    final scopedLabId = context.selectedLaboratory?.labId;
    List<AnalysisPackageLink> links;
    if (hint == 'cheapest_filter') {
      final ids = await _resolveUniqueAnalysisIds(
        intent.entities.allAnalysisTerms,
        intent: intent,
        context: context,
      );
      if (ids.error != null) return ids.error!;
      if (ids.ids.isEmpty) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: 'حدّد التحاليل أولاً لأجد أرخص باقة تجمعها.',
          canExecute: false,
        );
      }
      links = await _lookupPackagesContainingAll(
        ids.ids,
        labId: scopedLabId,
      );
    } else {
      links = await _lookupActivePackages(labId: scopedLabId);
    }

    final priced = links
        .where((l) => l.package.newPrice != null && l.package.newPrice! > 0)
        .toList()
      ..sort(
        (a, b) => a.package.newPrice!.compareTo(b.package.newPrice!),
      );

    if (priced.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: hint == 'cheapest_filter'
            ? 'ما لقيت حالياً باقة معروضة تجمع التحاليل المطلوبة بسعر متوفر.'
            : 'ماكو باقات بسعر متوفر حالياً للمقارنة.',
        canExecute: false,
      );
    }

    final cheapest = priced.first;
    final result = _packageToResult(cheapest);
    final priceText = ArabicSpeechNumbers.moneyIq(cheapest.package.newPrice);
    context.beginNewPackageSearch(query: query, intent: intent.intent);
    context.rememberResults(
      [for (final l in priced.take(8)) _packageToResult(l)],
      query: query,
      intent: intent.intent,
    );
    context.selectPackage(result);

    return AssistantActionPlan(
      kind: AssistantActionKind.selectEntity,
      intentResult: intent,
      target: result,
      candidates: [for (final l in priced.take(8)) _packageToResult(l)],
      message:
          'أرخص باقة حالياً: ${result.title}${result.labName != null && result.labName!.isNotEmpty ? ' (${result.labName})' : ''} بسعر $priceText.',
      canExecute: true,
    );
  }

  Future<AssistantActionPlan> _planPackagesFilteredByAnalyses(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) async {
    final terms = intent.entities.allAnalysisTerms;
    if (terms.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: 'اذكر التحاليل اللي تريدها ضمن الباقة.',
        canExecute: false,
      );
    }

    final resolved = await _resolveUniqueAnalysisIds(
      terms,
      intent: intent,
      context: context,
    );
    if (resolved.error != null) return resolved.error!;

    final scopedLabId = context.selectedLaboratory?.labId;
    final links = await _lookupPackagesContainingAll(
      resolved.ids,
      labId: scopedLabId,
    );

    if (links.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: 'ما لقيت حالياً باقة معروضة تجمع كل التحاليل اللي طلبتها.',
        canExecute: false,
      );
    }

    final results = [for (final link in links) _packageToResult(link)];
    final termsLabel = terms.take(4).join(' و');
    context.beginNewPackageSearch(query: query, intent: intent.intent);
    context.rememberResults(results, query: query, intent: intent.intent);

    if (results.length == 1) {
      return AssistantActionPlan(
        kind: AssistantActionKind.selectEntity,
        intentResult: intent,
        target: results.first,
        candidates: results,
        message: 'وجدت باقة تجمع $termsLabel: ${results.first.title}.',
        canExecute: true,
      );
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.runPackageSearch,
      intentResult: intent,
      candidates: results,
      packages: [for (final l in links) l.package],
      message: 'وجدت ${results.length} باقات تجمع $termsLabel.',
      canExecute: true,
    );
  }

  Future<({List<String> ids, AssistantActionPlan? error})>
      _resolveUniqueAnalysisIds(
    List<String> terms, {
    required IntentResult intent,
    required ConversationContext context,
  }) async {
    final ids = <String>[];
    for (final term in terms) {
      final items = await _lookupAnalyses(term);
      final batch = _analysisMatcher.matchAnalyses(
        query: term,
        analyses: items,
      );
      final plausible = batch.plausible;
      if (plausible.isEmpty) {
        return (
          ids: const <String>[],
          error: AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            message: 'لم أجد تحليلاً مطابقاً لـ «$term».',
            canExecute: false,
          ),
        );
      }
      if (plausible.length > 1 && !(batch.best?.isStrong ?? false)) {
        final list = [
          for (final m in plausible)
            AnalysisTargetResolver.toSearchResult(
              items.firstWhere(
                (a) => a.id == m.analysisId || a.displayLabel == m.analysisName,
                orElse: () => items.first,
              ),
            ),
        ];
        context.rememberResults(
          list,
          query: term,
          intent: AssistantIntent.findAnalysis,
          pendingActionForClarification: intent.intent,
          clarificationReason: ClarificationReason.ambiguousName,
        );
        final pending = context.pendingClarification;
        return (
          ids: const <String>[],
          error: AssistantActionPlan(
            kind: AssistantActionKind.showClarification,
            intentResult: intent.copyWithClarification(true),
            candidates: list,
            message: pending != null
                ? _clarificationResponses.build(pending)
                : 'أي تحليل تقصد بـ «$term»؟',
            canExecute: false,
          ),
        );
      }
      final best = batch.best!;
      ids.add(best.analysisId ?? plausible.first.analysisId ?? '');
    }
    return (
      ids: ids.where((e) => e.isNotEmpty).toList(),
      error: null,
    );
  }

  Future<AssistantActionPlan> _planPackageNameSearch(
    String query,
    ConversationContext context,
    IntentResult intent,
    String nameQuery,
  ) async {
    lastMatcherQueryForTest = nameQuery;
    context.beginNewPackageSearch(query: query, intent: intent.intent);

    final links = await _lookupActivePackages(nameQuery: nameQuery);
    var results = [for (final link in links) _packageToResult(link)];

    if (results.isEmpty) {
      final all = await _lookupActivePackages();
      final batch = _packageMatcher.matchPackages(
        query: nameQuery,
        packages: [
          for (final link in all)
            (
              id: link.package.id,
              name: link.package.name,
              labId: link.labId,
            ),
        ],
      );
      if (batch.matches.isEmpty) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: 'لم أجد باقة مطابقة لـ «$nameQuery».',
          canExecute: false,
        );
      }
      final matchedIds = <String>{
        for (final m in batch.plausible) m.packageId ?? m.packageName,
      };
      results = [
        for (final link in all)
          if (matchedIds.contains(link.package.id) ||
              matchedIds.contains(link.package.name))
            _packageToResult(link),
      ];
      if (batch.isAmbiguous ||
          (batch.plausible.length > 1 && !(batch.best?.isStrong ?? false))) {
        if (results.length > 1) {
          context.rememberResults(
            results,
            query: query,
            intent: intent.intent,
            pendingActionForClarification: intent.intent,
            clarificationReason: ClarificationReason.ambiguousName,
          );
          final pending = context.pendingClarification ??
              const AmbiguityGate().fromPackageResults(
                packages: results,
                originalIntent: intent.intent,
                originalQuery: query,
                pendingAction: intent.intent,
                reason: ClarificationReason.ambiguousName,
              );
          if (pending != null) context.setPendingClarification(pending);
          return AssistantActionPlan(
            kind: AssistantActionKind.showClarification,
            intentResult: intent.copyWithClarification(true),
            candidates: results,
            message: pending != null
                ? _clarificationResponses.build(pending)
                : 'وجدت أكثر من باقة مطابقة. أي واحدة تقصد؟',
            canExecute: false,
          );
        }
      }
    } else if (results.length > 1) {
      // نفس الاسم في مختبرات مختلفة → توضيح.
      final sameName = results.every(
        (r) =>
            r.title == results.first.title ||
            _packageMatcher.prepareQuery(r.title) ==
                _packageMatcher.prepareQuery(results.first.title),
      );
      if (sameName || results.length > 1) {
        context.rememberResults(
          results,
          query: query,
          intent: intent.intent,
          pendingActionForClarification: intent.intent,
          clarificationReason: ClarificationReason.multipleMatches,
        );
        final pending = context.pendingClarification ??
            const AmbiguityGate().fromPackageResults(
              packages: results,
              originalIntent: intent.intent,
              originalQuery: query,
              pendingAction: intent.intent,
            );
        if (pending != null) context.setPendingClarification(pending);
        return AssistantActionPlan(
          kind: AssistantActionKind.showClarification,
          intentResult: intent.copyWithClarification(true),
          candidates: results,
          message: pending != null
              ? _clarificationResponses.build(pending)
              : 'وجدت باقة «$nameQuery» في أكثر من مختبر. أي واحد تقصد؟',
          canExecute: false,
        );
      }
    }

    if (results.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: 'لم أجد باقة مطابقة لـ «$nameQuery».',
        canExecute: false,
      );
    }

    context.rememberResults(results, query: query, intent: intent.intent);
    if (results.length == 1) {
      return AssistantActionPlan(
        kind: AssistantActionKind.selectEntity,
        intentResult: intent,
        target: results.first,
        message: 'وجدت ${results.first.title}.',
        canExecute: true,
      );
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.runPackageSearch,
      intentResult: intent,
      candidates: results,
      message: 'وجدت ${results.length} باقات مطابقة لـ «$nameQuery».',
      canExecute: true,
    );
  }

  Future<AssistantActionPlan> _planGlobalPackageList(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) async {
    final scopedLabId = context.selectedLaboratory?.labId;
    final links = await _lookupActivePackages(labId: scopedLabId);
    if (links.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: 'ماكو باقات معروضة حالياً.',
        canExecute: false,
      );
    }
    final results = [for (final link in links) _packageToResult(link)];
    context.beginNewPackageSearch(query: query, intent: intent.intent);
    context.rememberResults(results, query: query, intent: intent.intent);
    return AssistantActionPlan(
      kind: AssistantActionKind.runPackageSearch,
      intentResult: intent,
      candidates: results,
      packages: [for (final l in links) l.package],
      message: scopedLabId != null && context.selectedLaboratory != null
          ? 'هذه الباقات المتوفرة حالياً في ${context.selectedLaboratory!.title}.'
          : 'هذه الباقات المعروضة حالياً.',
      canExecute: true,
    );
  }

  Future<AssistantActionPlan> _planPackageComparison(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) async {
    // PC-0.2: مقارنة الأسعار من ResultContext السلطوي فقط.
    final list = context.currentPackageResultItems;
    if (list.length < 2) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message:
            'حتى أقارن، اعرض باقتين أو أكثر أولاً (مثلاً: أريد باقات، أو ابحث عن باقة).',
        canExecute: false,
      );
    }

    final a = list[0];
    final b = list[1];
    String line(SmartSearchResult p) {
      final price = _currentPrice(p);
      final pricePart = price != null
          ? 'السعر الحالي ${ArabicSpeechNumbers.moneyIq(price)}'
          : 'السعر غير متوفر';
      final old = p.oldPrice;
      final oldPart = (old != null && old > 0)
          ? '، السابق ${ArabicSpeechNumbers.moneyIq(old)}'
          : '';
      final lab = (p.labName ?? '').trim();
      final labPart = lab.isNotEmpty ? ' — $lab' : '';
      return '${p.title}$labPart: $pricePart$oldPart';
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.showPackageComparison,
      intentResult: intent,
      candidates: [a, b],
      target: a,
      message: 'مقارنة واقعية:\n• ${line(a)}\n• ${line(b)}',
      canExecute: true,
    );
  }

  SmartSearchResult _packageToResult(AnalysisPackageLink link) {
    return PackageTargetResolver.toSearchResult(
      id: link.package.id,
      name: link.package.name,
      labId: link.labId,
      labName: link.labName,
      oldPrice: link.package.oldPrice,
      newPrice: link.package.newPrice,
      discountPercent: link.package.discountPercent,
      description: link.package.description,
      imageUrl: link.package.imageUrl,
    );
  }

  int? _currentPrice(SmartSearchResult p) {
    final n = p.newPrice;
    if (n == null || n <= 0) return null;
    return n;
  }

  String _formatPriceMessage(SmartSearchResult p) {
    final current = _currentPrice(p);
    if (current == null) {
      return 'سعر هذه الباقة غير متوفر حالياً.';
    }
    final currentText = ArabicSpeechNumbers.moneyIq(current);
    final old = p.oldPrice;
    if (old != null && old > 0 && old != current) {
      return 'السعر الحالي لباقة ${p.title}: $currentText. السعر السابق: ${ArabicSpeechNumbers.moneyIq(old)}.';
    }
    return 'السعر الحالي لباقة ${p.title}: $currentText.';
  }

  Future<AssistantActionPlan> _planAnalysis(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) async {
    final hint = intent.entities.actionHint;

    // اتصال على تحليل نشط — مرفوض.
    if (intent.intent == AssistantIntent.callDoctor ||
        intent.intent == AssistantIntent.messageDoctor ||
        intent.intent == AssistantIntent.callLab ||
        intent.intent == AssistantIntent.messageLab) {
      if (context.activeEntityType == ConversationEntityType.analysis) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          target: context.selectedAnalysis,
          message:
              'التحليل نفسه ما عنده رقم اتصال. أگدر أعرض لك المختبرات اللي ظهر ضمن باقاتها.',
          canExecute: false,
        );
      }
    }

    // باقات/مختبرات لتحليل محدد أو سياقي.
    if (hint == 'packages_for_analysis' ||
        hint == 'labs_for_analysis' ||
        hint == 'where_analysis') {
      final target = _analysisTargetResolver.resolve(
        intentResult: intent,
        context: context,
      );
      if (target.source == AnalysisTargetSource.explicitName) {
        final resolved = await _resolveExplicitAnalysis(
          query,
          context,
          intent,
          target.explicitName!,
        );
        if (resolved.kind != AssistantActionKind.selectEntity &&
            resolved.target == null) {
          return resolved;
        }
        final analysis = resolved.target ?? context.selectedAnalysis;
        if (analysis == null) return resolved;
        return _planPackagesOrLabsForAnalysis(
          intent,
          context,
          analysis,
          hint: hint!,
        );
      }
      if (!target.hasAnalysis) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: target.message.isNotEmpty
              ? target.message
              : AnalysisTargetResolution.unresolved.message,
          analysisTargetResolution: target,
        );
      }
      return _planPackagesOrLabsForAnalysis(
        intent,
        context,
        target.analysis!,
        hint: hint!,
      );
    }

    // بحث تحليل بالاسم.
    final target = _analysisTargetResolver.resolve(
      intentResult: intent,
      context: context,
    );
    switch (target.source) {
      case AnalysisTargetSource.explicitName:
        return _resolveExplicitAnalysis(
          query,
          context,
          intent,
          target.explicitName!,
        );
      case AnalysisTargetSource.ordinal:
      case AnalysisTargetSource.selectedContext:
        if (!target.hasAnalysis) {
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            message: target.message.isNotEmpty
                ? target.message
                : AnalysisTargetResolution.unresolved.message,
            analysisTargetResolution: target,
          );
        }
        return AssistantActionPlan(
          kind: AssistantActionKind.selectEntity,
          intentResult: intent,
          target: target.analysis,
          message: 'وجدت ${target.analysis!.title}.',
          canExecute: true,
          analysisTargetResolution: target,
        );
      case AnalysisTargetSource.unresolved:
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: target.message.isNotEmpty
              ? target.message
              : AnalysisTargetResolution.unresolved.message,
          candidates: target.candidates,
          analysisTargetResolution: target,
        );
    }
  }

  Future<AssistantActionPlan> _resolveExplicitAnalysis(
    String query,
    ConversationContext context,
    IntentResult intent,
    String nameQuery,
  ) async {
    lastMatcherQueryForTest = nameQuery;
    context.beginNewAnalysisSearch(query: query, intent: intent.intent);
    final items = await _lookupAnalyses(nameQuery);
    final batch = _analysisMatcher.matchAnalyses(
      query: nameQuery,
      analyses: items,
    );

    if (batch.matches.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: 'لم أجد تحليلاً مطابقاً لـ «$nameQuery».',
        canExecute: false,
        analysisQuery: nameQuery,
        analysisTargetResolution: AnalysisTargetResolution(
          source: AnalysisTargetSource.explicitName,
          explicitName: nameQuery,
          requiresSearch: true,
        ),
      );
    }

    AnalysisItem itemFor(AnalysisNameMatch m) {
      return items.firstWhere(
        (a) => a.id == m.analysisId || a.displayLabel == m.analysisName,
        orElse: () => items.first,
      );
    }

    if (batch.isAmbiguous ||
        (batch.plausible.length > 1 && !(batch.best?.isStrong ?? false))) {
      final list = [
        for (final m in batch.plausible) AnalysisTargetResolver.toSearchResult(itemFor(m)),
      ];
      // حافظ على ترتيب فريد.
      final seen = <String>{};
      final unique = <SmartSearchResult>[];
      for (final r in list) {
        final id = r.analysisId ?? r.title;
        if (seen.add(id)) unique.add(r);
      }
      if (unique.length == 1) {
        context.rememberResults(unique, query: query, intent: intent.intent);
        return AssistantActionPlan(
          kind: AssistantActionKind.selectEntity,
          intentResult: intent,
          target: unique.first,
          message: 'وجدت ${unique.first.title}.',
          canExecute: true,
        );
      }
      context.rememberResults(
        unique,
        query: query,
        intent: intent.intent,
        pendingActionForClarification: intent.intent,
        clarificationReason: ClarificationReason.ambiguousName,
      );
      final pending = context.pendingClarification ??
          const AmbiguityGate().fromAnalysisResults(
            analyses: unique,
            originalIntent: intent.intent,
            originalQuery: query,
            pendingAction: intent.intent,
            reason: ClarificationReason.ambiguousName,
          );
      if (pending != null) context.setPendingClarification(pending);
      final message = pending != null
          ? _clarificationResponses.build(pending)
          : 'وجدت أكثر من تحليل مطابق. أي واحد تقصد؟';
      return AssistantActionPlan(
        kind: AssistantActionKind.showClarification,
        intentResult: intent.copyWithClarification(true),
        candidates: unique,
        message: message,
        canExecute: false,
      );
    }

    final best = batch.best!;
    final item = itemFor(best);
    final result = AnalysisTargetResolver.toSearchResult(item);
    context.rememberResults([result], query: query, intent: intent.intent);
    return AssistantActionPlan(
      kind: AssistantActionKind.selectEntity,
      intentResult: intent,
      target: result,
      message: 'وجدت ${result.title}.',
      canExecute: true,
      analysisTargetResolution: AnalysisTargetResolution(
        source: AnalysisTargetSource.explicitName,
        analysis: result,
        analysisItem: item,
        explicitName: nameQuery,
      ),
    );
  }

  Future<AssistantActionPlan> _planPackagesOrLabsForAnalysis(
    IntentResult intent,
    ConversationContext context,
    SmartSearchResult analysis, {
    required String hint,
  }) async {
    final analysisId = analysis.analysisId ?? '';
    final title = analysis.title;
    if (analysisId.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: analysis,
        message: 'تعذر تتبع علاقات هذا التحليل.',
      );
    }

    final links = await _lookupPackagesForAnalysis(analysisId);
    if (links.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: analysis,
        message:
            'وجدت تحليل $title، لكن لا توجد حالياً باقة معروضة مرتبطة به في بيانات الغدير.',
        canExecute: false,
      );
    }

    final packageResults = <SmartSearchResult>[
      for (final link in links)
        SmartSearchResult(
          type: (link.package.discountPercent != null &&
                  link.package.discountPercent! > 0)
              ? SmartSearchResultType.offer
              : SmartSearchResultType.package,
          title: link.package.name,
          subtitle: link.labName.isNotEmpty
              ? 'تحتوي $title — ${link.labName}'
              : 'تحتوي $title',
          labId: link.labId.isNotEmpty ? link.labId : null,
          packageId: link.package.id,
          labName: link.labName.isNotEmpty ? link.labName : null,
          oldPrice: link.package.oldPrice,
          newPrice: link.package.newPrice,
          discountPercent: link.package.discountPercent,
          relatedAnalysisId: analysisId,
          relatedAnalysisTitle: title,
          imageUrl: link.package.imageUrl.isNotEmpty
              ? link.package.imageUrl
              : null,
          bioSnippet: link.package.description.isNotEmpty
              ? link.package.description
              : null,
        ),
    ];
    context.rememberAnalysisPackages(packageResults);
    // لا تمسح selectedAnalysis.
    if (context.selectedAnalysis == null) {
      context.selectAnalysis(analysis);
    } else {
      context.activeEntityType = ConversationEntityType.analysis;
    }

    if (hint == 'labs_for_analysis') {
      final seenLabs = <String>{};
      final labResults = <SmartSearchResult>[];
      for (final link in links) {
        final id = link.labId.isNotEmpty ? link.labId : link.labName;
        if (id.isEmpty || !seenLabs.add(id)) continue;
        labResults.add(
          SmartSearchResult(
            type: SmartSearchResultType.lab,
            title: link.labName.isNotEmpty ? link.labName : 'مختبر',
            subtitle: 'ضمن باقاته يظهر $title',
            labId: link.labId.isNotEmpty ? link.labId : null,
            labName: link.labName,
            relatedAnalysisId: analysisId,
            relatedAnalysisTitle: title,
          ),
        );
      }
      return AssistantActionPlan(
        kind: AssistantActionKind.showLabsViaAnalysisPackages,
        intentResult: intent,
        target: analysis,
        candidates: labResults,
        packages: [for (final l in links) l.package],
        message:
            'وجدته ضمن باقات المختبرات التالية… (عبر علاقة الباقات وليس كتالوجاً مباشراً للمختبر).',
        canExecute: true,
      );
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.showPackagesContainingAnalysis,
      intentResult: intent,
      target: analysis,
      candidates: packageResults,
      packages: [for (final l in links) l.package],
      message: 'تحليل $title موجود ضمن الباقات التالية…',
      canExecute: true,
    );
  }

  static bool _looksLikeSymptomGuidance(String query) {
    final n = ArabicTextUtils.normalize(query.trim());
    return RegExp(
      r'(?:عندي|اشعر|تعب|صداع|الم|وجع).{0,40}(?:شنو\s+تحليل|اي\s+تحليل|تحليل\s+اسوي|اسوي\s+تحليل|شنو\s+باق|اي\s+باق|باق(?:ه|ة)\s+اسوي|اسوي\s+باق)',
    ).hasMatch(n);
  }

  Future<AssistantActionPlan> _planLaboratory(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) async {
    // بحث عام عن مختبرات.
    if (intent.intent == AssistantIntent.findLab) {
      final name = (intent.entities.laboratory ?? '').trim();
      context.beginNewLabSearch(query: query, intent: intent.intent);
      if (name.isEmpty) {
        return AssistantActionPlan(
          kind: AssistantActionKind.runLabSearch,
          intentResult: intent,
          labQuery: 'مختبر',
          canExecute: true,
          message: '',
        );
      }
      return _planExplicitLabName(
        query,
        context,
        intent,
        name,
        actionAfterResolve: AssistantIntent.findLab,
      );
    }

    // باقات / تحاليل / إجراءات — حل الهدف أولاً.
    final effectiveIntent = _labEffectiveIntent(intent, context);
    final synthetic = IntentResult(
      intent: effectiveIntent,
      originalText: intent.originalText,
      normalizedText: intent.normalizedText,
      searchMeaning: intent.searchMeaning,
      entities: intent.entities,
      confidence: intent.confidence,
      requiresContext: intent.requiresContext,
      source: intent.source,
    );

    final target = _labTargetResolver.resolve(
      intentResult: synthetic,
      context: context,
    );

    switch (target.source) {
      case LaboratoryTargetSource.explicitName:
        return _planExplicitLabName(
          query,
          context,
          synthetic,
          target.explicitName!,
          actionAfterResolve: effectiveIntent,
        );

      case LaboratoryTargetSource.ordinal:
      case LaboratoryTargetSource.selectedContext:
        if (!target.hasLab) {
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: synthetic,
            message: target.message.isNotEmpty
                ? target.message
                : LaboratoryTargetResolution.unresolved.message,
            labTargetResolution: target,
          );
        }
        return _planForResolvedLab(
          synthetic,
          target.laboratory!,
          targetResolution: target,
          context: context,
        );

      case LaboratoryTargetSource.unresolved:
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: synthetic,
          message: target.message.isNotEmpty
              ? target.message
              : _missingLabContextMessage(effectiveIntent),
          candidates: target.candidates,
          canExecute: false,
          labTargetResolution: target,
        );
    }
  }

  /// يحوّل callDoctor/messageDoctor السياقي إلى callLab/messageLab عند كيان مختبر نشط.
  AssistantIntent _labEffectiveIntent(
    IntentResult intent,
    ConversationContext context,
  ) {
    switch (intent.intent) {
      case AssistantIntent.callDoctor:
        return AssistantIntent.callLab;
      case AssistantIntent.messageDoctor:
        return AssistantIntent.messageLab;
      default:
        return intent.intent;
    }
  }

  Future<AssistantActionPlan> _planExplicitLabName(
    String query,
    ConversationContext context,
    IntentResult intent,
    String nameQuery, {
    required AssistantIntent actionAfterResolve,
  }) async {
    lastMatcherQueryForTest = nameQuery;
    final results = await _lookupLabs(nameQuery);
    final labs = results
        .where((r) => r.type == SmartSearchResultType.lab)
        .toList();

    final batch = _labMatcher.matchLabs(
      query: nameQuery,
      labs: [
        for (final lab in labs) (id: lab.labId ?? lab.title, name: lab.title),
      ],
    );

    if (batch.matches.isEmpty && labs.isEmpty) {
      // بحث عام بالاسم عبر خدمة البحث إن لم يطابق المُطابِق محلياً.
      final searched = await _lookupLabs(nameQuery);
      if (searched.isEmpty) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: 'لم أجد مختبراً مطابقاً لـ «$nameQuery».',
          canExecute: false,
          labTargetResolution: LaboratoryTargetResolution(
            source: LaboratoryTargetSource.explicitName,
            explicitName: nameQuery,
            requiresSearch: true,
          ),
        );
      }
      return _finalizeLabMatches(
        query: query,
        context: context,
        intent: intent,
        nameQuery: nameQuery,
        labs: searched,
        actionAfterResolve: actionAfterResolve,
        batch: _labMatcher.matchLabs(
          query: nameQuery,
          labs: [
            for (final lab in searched)
              (id: lab.labId ?? lab.title, name: lab.title),
          ],
        ),
      );
    }

    if (batch.matches.isEmpty) {
      // نتائج بحث موجودة لكن المطابقة ضعيفة — اعرضها إن كانت قليلة.
      if (labs.length == 1) {
        context.rememberResults([labs.first], query: query, intent: intent.intent);
        return _planForResolvedLab(
          IntentResult(
            intent: actionAfterResolve,
            originalText: intent.originalText,
            normalizedText: intent.normalizedText,
            searchMeaning: intent.searchMeaning,
            entities: intent.entities,
            confidence: intent.confidence,
            source: intent.source,
          ),
          labs.first,
          targetResolution: LaboratoryTargetResolution(
            source: LaboratoryTargetSource.explicitName,
            laboratory: labs.first,
            explicitName: nameQuery,
          ),
          context: context,
        );
      }
      return _finalizeLabMatches(
        query: query,
        context: context,
        intent: intent,
        nameQuery: nameQuery,
        labs: labs,
        actionAfterResolve: actionAfterResolve,
        batch: LaboratoryNameMatchBatch(
          query: nameQuery,
          matches: const [],
          isAmbiguous: labs.length > 1,
        ),
      );
    }

    return _finalizeLabMatches(
      query: query,
      context: context,
      intent: intent,
      nameQuery: nameQuery,
      labs: labs,
      actionAfterResolve: actionAfterResolve,
      batch: batch,
    );
  }

  Future<AssistantActionPlan> _finalizeLabMatches({
    required String query,
    required ConversationContext context,
    required IntentResult intent,
    required String nameQuery,
    required List<SmartSearchResult> labs,
    required AssistantIntent actionAfterResolve,
    required LaboratoryNameMatchBatch batch,
  }) async {
    final ambiguous = batch.isAmbiguous ||
        (batch.matches.length > 1 && !(batch.best?.isStrong ?? false)) ||
        (batch.matches.isEmpty && labs.length > 1);

    if (ambiguous || labs.length > 1 && batch.matches.length != 1) {
      final matchedIds = <String>{
        for (final m in batch.plausible) m.labId ?? m.labName,
      };
      final list = matchedIds.isEmpty
          ? labs
          : labs
              .where(
                (d) =>
                    matchedIds.contains(d.labId ?? d.title) ||
                    matchedIds.contains(d.title),
              )
              .toList();
      final finalList = list.isNotEmpty ? list : labs;
      if (finalList.length == 1) {
        context.rememberResults(
          finalList,
          query: query,
          intent: intent.intent,
        );
        return _planForResolvedLab(
          IntentResult(
            intent: actionAfterResolve,
            originalText: intent.originalText,
            normalizedText: intent.normalizedText,
            searchMeaning: intent.searchMeaning,
            entities: intent.entities,
            confidence: intent.confidence,
            source: intent.source,
          ),
          finalList.first,
          targetResolution: LaboratoryTargetResolution(
            source: LaboratoryTargetSource.explicitName,
            laboratory: finalList.first,
            explicitName: nameQuery,
          ),
          context: context,
        );
      }

      context.rememberResults(
        finalList,
        query: query,
        intent: intent.intent,
        clearSelection: true,
        pendingActionForClarification: actionAfterResolve,
        clarificationReason: ClarificationReason.ambiguousName,
      );
      final pending = context.pendingClarification ??
          const AmbiguityGate().fromLabResults(
            labs: finalList,
            originalIntent: intent.intent,
            originalQuery: query,
            pendingAction: actionAfterResolve,
            reason: ClarificationReason.ambiguousName,
          );
      if (pending != null) {
        context.setPendingClarification(pending);
      }
      final message = pending != null
          ? _clarificationResponses.build(pending)
          : 'وجدت أكثر من مختبر مطابق. أي واحد تقصد؟';
      context.setAssistantResponse(message);
      return AssistantActionPlan(
        kind: AssistantActionKind.showClarification,
        intentResult: intent.copyWithClarification(true),
        candidates: finalList,
        message: message,
        canExecute: false,
        labTargetResolution: LaboratoryTargetResolution(
          source: LaboratoryTargetSource.explicitName,
          explicitName: nameQuery,
          requiresSearch: true,
          requiresClarification: true,
          candidates: finalList,
        ),
      );
    }

    final bestMatch = batch.best;
    final resolved = bestMatch == null
        ? labs.first
        : labs.firstWhere(
            (d) =>
                d.labId == bestMatch.labId || d.title == bestMatch.labName,
            orElse: () => labs.first,
          );

    context.rememberResults(
      [resolved],
      query: query,
      intent: intent.intent,
    );

    return _planForResolvedLab(
      IntentResult(
        intent: actionAfterResolve,
        originalText: intent.originalText,
        normalizedText: intent.normalizedText,
        searchMeaning: intent.searchMeaning,
        entities: intent.entities,
        confidence: intent.confidence,
        source: intent.source,
      ),
      resolved,
      targetResolution: LaboratoryTargetResolution(
        source: LaboratoryTargetSource.explicitName,
        laboratory: resolved,
        explicitName: nameQuery,
      ),
      context: context,
    );
  }

  Future<AssistantActionPlan> _planForResolvedLab(
    IntentResult intent,
    SmartSearchResult target, {
    LaboratoryTargetResolution? targetResolution,
    ConversationContext? context,
  }) async {
    switch (intent.intent) {
      case AssistantIntent.callLab:
      case AssistantIntent.callDoctor:
        if (!target.canCall) {
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            target: target,
            message: 'رقم اتصال المختبر غير متوفر حالياً.',
            labTargetResolution: targetResolution,
          );
        }
        return AssistantActionPlan(
          kind: AssistantActionKind.prepareCall,
          intentResult: intent,
          target: target,
          message: 'جاهز للاتصال بـ ${target.title}.',
          canExecute: true,
          labTargetResolution: targetResolution,
        );
      case AssistantIntent.messageLab:
      case AssistantIntent.messageDoctor:
        if (!target.canWhatsApp) {
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            target: target,
            message: 'رقم واتساب المختبر غير متوفر حالياً.',
            labTargetResolution: targetResolution,
          );
        }
        return AssistantActionPlan(
          kind: AssistantActionKind.prepareWhatsApp,
          intentResult: intent,
          target: target,
          message: 'جاهز لفتح واتساب ${target.title}.',
          canExecute: true,
          labTargetResolution: targetResolution,
        );
      case AssistantIntent.showLocation:
        final loc = (target.clinicLocation ?? target.subtitle).trim();
        if (loc.isEmpty || loc == 'مختبر') {
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            target: target,
            message: 'موقع ${target.title} غير متوفر حالياً.',
            labTargetResolution: targetResolution,
          );
        }
        return AssistantActionPlan(
          kind: AssistantActionKind.showLocation,
          intentResult: intent,
          target: target,
          message: '${target.title}: $loc',
          canExecute: true,
          labTargetResolution: targetResolution,
        );
      case AssistantIntent.showProfile:
        return AssistantActionPlan(
          kind: AssistantActionKind.openProfile,
          intentResult: intent,
          target: target,
          message: 'فتح ملف ${target.title}.',
          canExecute: true,
          labTargetResolution: targetResolution,
        );
      case AssistantIntent.findPackage:
        return _planLabPackages(
          intent,
          target,
          targetResolution,
          context: context,
        );
      case AssistantIntent.findAnalysis:
        return _planLabAnalyses(intent, target, targetResolution);
      case AssistantIntent.findLab:
        return AssistantActionPlan(
          kind: AssistantActionKind.selectEntity,
          intentResult: intent,
          target: target,
          message: 'وجدت ${target.title}.',
          canExecute: true,
          labTargetResolution: targetResolution,
        );
      default:
        return AssistantActionPlan(
          kind: AssistantActionKind.runLabSearch,
          intentResult: intent,
          target: target,
          labQuery: target.title,
          canExecute: true,
          labTargetResolution: targetResolution,
        );
    }
  }

  Future<AssistantActionPlan> _planLabPackages(
    IntentResult intent,
    SmartSearchResult lab,
    LaboratoryTargetResolution? targetResolution, {
    ConversationContext? context,
  }) async {
    final labId = lab.labId ?? '';
    if (labId.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: lab,
        message: 'تعذر تحميل باقات هذا المختبر.',
        labTargetResolution: targetResolution,
      );
    }
    final packages = await _lookupPackages(labId);
    if (packages.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: lab,
        message: 'لا توجد باقات معروضة حالياً لهذا المختبر.',
        canExecute: false,
        labTargetResolution: targetResolution,
      );
    }
    final asResults = [
      for (final p in packages)
        SmartSearchResult(
          type: (p.discountPercent != null && p.discountPercent! > 0)
              ? SmartSearchResultType.offer
              : SmartSearchResultType.package,
          title: p.name,
          subtitle: lab.title,
          labId: labId,
          packageId: p.id,
          oldPrice: p.oldPrice,
          newPrice: p.newPrice,
          imageUrl: p.imageUrl.isNotEmpty ? p.imageUrl : null,
          bioSnippet: p.description.isNotEmpty ? p.description : null,
          labName: lab.title,
          phone: lab.phone,
          whatsapp: lab.whatsapp,
          clinicLocation: lab.clinicLocation,
        ),
    ];
    // Step 9: ثبّت سياق نتائج الباقات دون مسح تركيز المختبر.
    if (context != null) {
      final keepLab = context.selectedLaboratory;
      final keepActive = context.activeEntityType;
      context.rememberResults(
        asResults,
        query: intent.originalText,
        intent: intent.intent,
        clearSelection: false,
      );
      context.setResultContext(
        entityType: ConversationEntityType.package,
        items: asResults,
        intent: intent.intent,
      );
      if (keepLab != null) context.selectedLaboratory = keepLab;
      if (keepActive == ConversationEntityType.laboratory) {
        context.activeEntityType = ConversationEntityType.laboratory;
      }
    }
    return AssistantActionPlan(
      kind: AssistantActionKind.showLabPackages,
      intentResult: intent,
      target: lab,
      candidates: asResults,
      packages: packages,
      message: 'هذه الباقات المتوفرة حالياً في ${lab.title}.',
      canExecute: true,
      labTargetResolution: targetResolution,
    );
  }

  Future<AssistantActionPlan> _planLabAnalyses(
    IntentResult intent,
    SmartSearchResult lab,
    LaboratoryTargetResolution? targetResolution,
  ) async {
    final labId = lab.labId ?? '';
    if (labId.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: lab,
        message: 'تعذر تحميل تحاليل باقات هذا المختبر.',
        labTargetResolution: targetResolution,
      );
    }
    final packages = await _lookupPackages(labId);
    final seen = <String>{};
    final analyses = <AnalysisItem>[];
    for (final p in packages) {
      for (final a in p.analyses) {
        if (a.id.isEmpty || seen.contains(a.id)) continue;
        seen.add(a.id);
        analyses.add(a);
      }
    }
    if (analyses.isEmpty) {
      // قد تكون الباقات بدون analyses مضمّنة — لا ندّعي كتالوجاً كاملاً.
      if (packages.isEmpty) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          target: lab,
          message:
              'لا توجد تحاليل معروضة ضمن باقات هذا المختبر حالياً.',
          labTargetResolution: targetResolution,
        );
      }
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: lab,
        packages: packages,
        message:
            'التحاليل المرتبطة تظهر ضمن باقات ${lab.title}. '
            'اعرض الباقات لمعرفة التحاليل المتضمنة.',
        canExecute: true,
        labTargetResolution: targetResolution,
      );
    }
    final asResults = [
      for (final a in analyses)
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: a.arabicDisplayName.isNotEmpty
              ? a.arabicDisplayName
              : a.displayLabel,
          subtitle: 'ضمن باقات ${lab.title}',
          labId: labId,
          analysisId: a.id,
          labName: lab.title,
        ),
    ];
    return AssistantActionPlan(
      kind: AssistantActionKind.showLabAnalyses,
      intentResult: intent,
      target: lab,
      candidates: asResults,
      packages: packages,
      analyses: analyses,
      message:
          'هذه التحاليل الموجودة ضمن باقات ${lab.title}.',
      canExecute: true,
      labTargetResolution: targetResolution,
    );
  }

  /// يعتمد اقتراح تصحيح الاسم بإعادة تشغيل بحث الأطباء القائم بالاسم الصحيح،
  /// تماماً كما لو كتبه المستخدم — بلا بناء بطاقة طبيب يدوية.
  ///
  /// الفعل الناتج اختيار فقط (`selectResult`)؛ لا يُشتق منه اتصال/واتساب.
  Future<AssistantActionPlan> _resumeAfterDoctorSuggestion({
    required ConversationContext context,
    required PendingDoctorSuggestion suggestion,
    required IntentResult intentResult,
  }) async {
    final doctors = await _lookupDoctors(suggestion.doctorName);
    final doctor = doctors.cast<SmartSearchResult?>().firstWhere(
          (d) =>
              d != null &&
              d.type == SmartSearchResultType.doctor &&
              (d.doctorId ?? '').trim() == suggestion.doctorId,
          orElse: () => null,
        );
    if (doctor == null) {
      // الاسم لم يعد يحل إلى نفس الطبيب — لا نخترع نتيجة، نعيد البحث الطبيعي.
      return AssistantActionPlan(
        kind: AssistantActionKind.runDoctorSearch,
        intentResult: intentResult,
        doctorQuery: suggestion.doctorName,
        canExecute: true,
      );
    }

    final message = 'تم اختيار ${doctor.title}.';
    context.rememberResults(
      [doctor],
      query: suggestion.doctorName,
      intent: AssistantIntent.doctorSearch,
      assistantResponse: message,
    );
    context.lastIntent = AssistantIntent.selectResult;

    return AssistantActionPlan(
      kind: AssistantActionKind.selectEntity,
      intentResult: intentResult,
      target: doctor,
      message: message,
      canExecute: true,
      contextResolution: ContextResolution(
        status: ContextResolutionStatus.selectResult,
        intent: AssistantIntent.selectResult,
        target: doctor,
        message: message,
      ),
    );
  }

  Future<AssistantActionPlan> _resumeAfterClarification({
    required ConversationContext context,
    required PendingClarification pending,
    required ClarificationCandidate candidate,
    required IntentResult intentResult,
    AssistantIntent? actionOverride,
  }) async {
    if (pending.entityType == ClarificationEntityType.laboratory) {
      return _resumeAfterLabClarification(
        context: context,
        pending: pending,
        candidate: candidate,
        intentResult: intentResult,
        actionOverride: actionOverride,
      );
    }
    if (pending.entityType == ClarificationEntityType.analysis) {
      return _resumeAfterAnalysisClarification(
        context: context,
        pending: pending,
        candidate: candidate,
        intentResult: intentResult,
        actionOverride: actionOverride,
      );
    }
    if (pending.entityType == ClarificationEntityType.package ||
        pending.entityType == ClarificationEntityType.offer) {
      return _resumeAfterPackageClarification(
        context: context,
        pending: pending,
        candidate: candidate,
        intentResult: intentResult,
        actionOverride: actionOverride,
      );
    }

    final doctor = candidate.asDoctorResult;
    if (doctor == null) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intentResult,
        message: 'تعذر اعتماد الخيار المحدد.',
      );
    }

    final actionIntent = actionOverride ??
        pending.pendingAction ??
        AssistantIntent.selectResult;
    context.selectDoctor(doctor);
    context.clearPendingClarification();
    context.clarificationCandidates = const [];
    context.lastIntent = actionIntent;
    context.setAssistantResponse('تم اختيار ${doctor.title}');

    if (actionIntent == AssistantIntent.callDoctor ||
        actionIntent == AssistantIntent.messageDoctor ||
        actionIntent == AssistantIntent.showLocation ||
        actionIntent == AssistantIntent.showProfile) {
      final synthetic = IntentResult(
        intent: actionIntent,
        originalText: intentResult.originalText,
        normalizedText: intentResult.normalizedText,
        searchMeaning: intentResult.searchMeaning,
        entities: intentResult.entities,
        confidence: intentResult.confidence,
        requiresContext: false,
        source: IntentSource.context,
      );
      return _planForResolvedTarget(
        context,
        synthetic,
        doctor,
        targetResolution: DoctorTargetResolution(
          source: actionOverride != null || pending.pendingAction != null
              ? DoctorTargetSource.ordinal
              : DoctorTargetSource.selectedContext,
          doctor: doctor,
          resultIndex: pending.candidates.indexOf(candidate) + 1,
        ),
      );
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.selectEntity,
      intentResult: intentResult,
      target: doctor,
      message: 'تم اختيار ${doctor.title}.',
      canExecute: true,
      contextResolution: ContextResolution(
        status: ContextResolutionStatus.selectResult,
        intent: AssistantIntent.selectResult,
        target: doctor,
        message: 'تم اختيار ${doctor.title}.',
      ),
    );
  }

  Future<AssistantActionPlan> _resumeAfterAnalysisClarification({
    required ConversationContext context,
    required PendingClarification pending,
    required ClarificationCandidate candidate,
    required IntentResult intentResult,
    AssistantIntent? actionOverride,
  }) async {
    final analysis = candidate.asAnalysisResult;
    if (analysis == null) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intentResult,
        message: 'تعذر اعتماد التحليل المحدد.',
      );
    }
    final actionIntent = actionOverride ??
        pending.pendingAction ??
        AssistantIntent.selectResult;
    context.selectAnalysis(analysis);
    context.clearPendingClarification();
    context.clarificationCandidates = const [];
    context.lastIntent = actionIntent;
    context.setAssistantResponse('تم اختيار ${analysis.title}');

    final hint = intentResult.entities.actionHint;
    if (hint == 'packages_for_analysis' ||
        hint == 'labs_for_analysis' ||
        hint == 'where_analysis' ||
        actionIntent == AssistantIntent.findPackage) {
      return _planPackagesOrLabsForAnalysis(
        intentResult,
        context,
        analysis,
        hint: hint == 'labs_for_analysis'
            ? 'labs_for_analysis'
            : 'packages_for_analysis',
      );
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.selectEntity,
      intentResult: intentResult,
      target: analysis,
      message: 'تم اختيار ${analysis.title}.',
      canExecute: true,
    );
  }

  Future<AssistantActionPlan> _resumeAfterPackageClarification({
    required ConversationContext context,
    required PendingClarification pending,
    required ClarificationCandidate candidate,
    required IntentResult intentResult,
    AssistantIntent? actionOverride,
  }) async {
    final package = candidate.asPackageResult;
    if (package == null) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intentResult,
        message: 'تعذر اعتماد الباقة المحددة.',
      );
    }

    final actionIntent = actionOverride ??
        pending.pendingAction ??
        AssistantIntent.selectResult;
    context.selectPackage(package);
    context.clearPendingClarification();
    context.clarificationCandidates = const [];
    context.lastIntent = actionIntent;
    context.setAssistantResponse('تم اختيار ${package.title}');

    final hint = intentResult.entities.actionHint;
    if (hint == 'package_price' ||
        hint == 'package_analyses' ||
        hint == 'package_lab') {
      return _planForResolvedPackage(
        intentResult,
        context,
        package,
        hint: hint!,
      );
    }

    if (actionIntent == AssistantIntent.callLab ||
        actionIntent == AssistantIntent.messageLab ||
        actionIntent == AssistantIntent.callDoctor ||
        actionIntent == AssistantIntent.messageDoctor ||
        actionIntent == AssistantIntent.showLocation ||
        actionIntent == AssistantIntent.showProfile) {
      return _planForResolvedPackage(
        IntentResult(
          intent: actionIntent,
          originalText: intentResult.originalText,
          normalizedText: intentResult.normalizedText,
          searchMeaning: intentResult.searchMeaning,
          entities: intentResult.entities,
          confidence: intentResult.confidence,
          requiresContext: false,
          source: IntentSource.context,
        ),
        context,
        package,
        hint: 'contact_or_location',
      );
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.selectEntity,
      intentResult: intentResult,
      target: package,
      message: 'تم اختيار ${package.title}.',
      canExecute: true,
    );
  }

  Future<AssistantActionPlan> _resumeAfterLabClarification({
    required ConversationContext context,
    required PendingClarification pending,
    required ClarificationCandidate candidate,
    required IntentResult intentResult,
    AssistantIntent? actionOverride,
  }) async {
    final lab = candidate.asLabResult;
    if (lab == null) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intentResult,
        message: 'تعذر اعتماد المختبر المحدد.',
      );
    }

    var actionIntent = actionOverride ??
        pending.pendingAction ??
        AssistantIntent.selectResult;
    if (actionIntent == AssistantIntent.callDoctor) {
      actionIntent = AssistantIntent.callLab;
    } else if (actionIntent == AssistantIntent.messageDoctor) {
      actionIntent = AssistantIntent.messageLab;
    }

    context.selectLaboratory(lab);
    context.clearPendingClarification();
    context.clarificationCandidates = const [];
    context.lastIntent = actionIntent;
    context.setAssistantResponse('تم اختيار ${lab.title}');

    if (actionIntent == AssistantIntent.callLab ||
        actionIntent == AssistantIntent.messageLab ||
        actionIntent == AssistantIntent.showLocation ||
        actionIntent == AssistantIntent.showProfile ||
        actionIntent == AssistantIntent.findPackage ||
        actionIntent == AssistantIntent.findAnalysis ||
        actionIntent == AssistantIntent.findLab) {
      final synthetic = IntentResult(
        intent: actionIntent,
        originalText: intentResult.originalText,
        normalizedText: intentResult.normalizedText,
        searchMeaning: intentResult.searchMeaning,
        entities: intentResult.entities,
        confidence: intentResult.confidence,
        requiresContext: false,
        source: IntentSource.context,
      );
      return _planForResolvedLab(
        synthetic,
        lab,
        targetResolution: LaboratoryTargetResolution(
          source: LaboratoryTargetSource.ordinal,
          laboratory: lab,
          resultIndex: pending.candidates.indexOf(candidate) + 1,
        ),
        context: context,
      );
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.selectEntity,
      intentResult: intentResult,
      target: lab,
      message: 'تم اختيار ${lab.title}.',
      canExecute: true,
    );
  }

  AssistantActionPlan _planSelect(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) {
    // Step 9: الترتيب يتبع currentResultContext أولاً — عزل الأنواع.
    final resultCtx = context.currentResultContext;
    if (resultCtx != null && resultCtx.isNotEmpty) {
      switch (resultCtx.entityType) {
        case ConversationEntityType.package:
          final target = _packageTargetResolver.resolve(
            intentResult: intent,
            context: context,
          );
          if (target.source == PackageTargetSource.ordinal &&
              target.hasPackage) {
            context.lastIntent = AssistantIntent.selectResult;
            context.setAssistantResponse('تم اختيار ${target.package!.title}');
            return AssistantActionPlan(
              kind: AssistantActionKind.selectEntity,
              intentResult: intent,
              target: target.package,
              message: 'تم اختيار ${target.package!.title}.',
              canExecute: true,
            );
          }
          if (target.requiresClarification) {
            return AssistantActionPlan(
              kind: AssistantActionKind.showClarification,
              intentResult: intent.copyWithClarification(true),
              message: target.message.isNotEmpty
                  ? target.message
                  : 'الرقم خارج نطاق نتائج الباقات الحالية.',
              candidates: resultCtx.items,
            );
          }
          break;
        case ConversationEntityType.analysis:
          final target = _analysisTargetResolver.resolve(
            intentResult: intent,
            context: context,
          );
          if (target.source == AnalysisTargetSource.ordinal &&
              target.hasAnalysis) {
            return AssistantActionPlan(
              kind: AssistantActionKind.selectEntity,
              intentResult: intent,
              target: target.analysis,
              message: 'تم اختيار ${target.analysis!.title}.',
              canExecute: true,
              analysisTargetResolution: target,
            );
          }
          if (target.requiresClarification) {
            return AssistantActionPlan(
              kind: AssistantActionKind.showClarification,
              intentResult: intent.copyWithClarification(true),
              message: target.message,
              candidates: resultCtx.items,
              analysisTargetResolution: target,
            );
          }
          break;
        case ConversationEntityType.laboratory:
          final target = _labTargetResolver.resolve(
            intentResult: intent,
            context: context,
          );
          if (target.source == LaboratoryTargetSource.ordinal &&
              target.hasLab) {
            return AssistantActionPlan(
              kind: AssistantActionKind.selectEntity,
              intentResult: intent,
              target: target.laboratory,
              message: 'تم اختيار ${target.laboratory!.title}.',
              canExecute: true,
              labTargetResolution: target,
            );
          }
          if (target.requiresClarification) {
            return AssistantActionPlan(
              kind: AssistantActionKind.showClarification,
              intentResult: intent.copyWithClarification(true),
              message: target.message,
              candidates: resultCtx.items,
              labTargetResolution: target,
            );
          }
          break;
        case ConversationEntityType.doctor:
          final target = _targetResolver.resolve(
            intentResult: intent,
            context: context,
          );
          if (target.source == DoctorTargetSource.ordinal &&
              target.hasDoctor) {
            _markHealthHandoffCompleted(context);
            return AssistantActionPlan(
              kind: AssistantActionKind.selectEntity,
              intentResult: intent,
              target: target.doctor,
              message: 'تم اختيار ${target.doctor!.title}.',
              canExecute: true,
              targetResolution: target,
            );
          }
          if (target.requiresClarification) {
            return AssistantActionPlan(
              kind: AssistantActionKind.showClarification,
              intentResult: intent.copyWithClarification(true),
              message: target.message,
              candidates: resultCtx.items,
              targetResolution: target,
            );
          }
          break;
        case ConversationEntityType.none:
          break;
      }

      // النوع السلطوي لم يُحل — لا سقوط إلى lastResults لنوع آخر.
      final resolved = _contextResolver.resolve(query, context);
      if (resolved.handled) {
        return _mapContextResolution(intent, resolved);
      }
      final ordinal = ContextResolver.extractOrdinal(
        ArabicTextUtils.normalize(query),
      );
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: GhadeerFollowUpContext.noSelectableResultsMessage(
          requestedOrdinal: ordinal,
        ),
        canExecute: false,
      );
    }

    // بلا ResultContext: التوضيح المعلّق صريح، وlastResults ليست سلطة.
    if (!context.hasPendingClarification) {
      final resolved = _contextResolver.resolve(query, context);
      if (resolved.handled) {
        return _mapContextResolution(intent, resolved);
      }
      final ordinal = ContextResolver.extractOrdinal(
        ArabicTextUtils.normalize(query),
      );
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: GhadeerFollowUpContext.noSelectableResultsMessage(
          requestedOrdinal: ordinal,
        ),
        canExecute: false,
      );
    }

    // باقات من نتائج البحث أو من باقات تحليل (Step 7).
    if (context.activeEntityType == ConversationEntityType.package ||
        context.hasPackageResults ||
        context.lastAnalysisPackageSnapshot.isNotEmpty) {
      final target = _packageTargetResolver.resolve(
        intentResult: intent,
        context: context,
      );
      if (target.source == PackageTargetSource.ordinal && target.hasPackage) {
        context.lastIntent = AssistantIntent.selectResult;
        context.setAssistantResponse('تم اختيار ${target.package!.title}');
        return AssistantActionPlan(
          kind: AssistantActionKind.selectEntity,
          intentResult: intent,
          target: target.package,
          message: 'تم اختيار ${target.package!.title}.',
          canExecute: true,
        );
      }
      if (target.requiresClarification &&
          (context.hasPackageResults ||
              context.activeEntityType == ConversationEntityType.package)) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showClarification,
          intentResult: intent.copyWithClarification(true),
          message: target.message,
          candidates: target.candidates,
        );
      }
    }

    if (context.activeEntityType == ConversationEntityType.analysis ||
        (context.lastAnalysisSnapshot.isNotEmpty &&
            context.lastDoctorSnapshot.isEmpty &&
            context.lastLabSnapshot.isEmpty)) {
      final target = _analysisTargetResolver.resolve(
        intentResult: intent,
        context: context,
      );
      if (target.source == AnalysisTargetSource.ordinal && target.hasAnalysis) {
        context.lastIntent = AssistantIntent.selectResult;
        context.setAssistantResponse('تم اختيار ${target.analysis!.title}');
        return AssistantActionPlan(
          kind: AssistantActionKind.selectEntity,
          intentResult: intent,
          target: target.analysis,
          message: 'تم اختيار ${target.analysis!.title}.',
          canExecute: true,
          analysisTargetResolution: target,
        );
      }
      if (target.requiresClarification) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showClarification,
          intentResult: intent.copyWithClarification(true),
          message: target.message,
          candidates: target.candidates,
          analysisTargetResolution: target,
        );
      }
    }

    if (context.activeEntityType == ConversationEntityType.laboratory ||
        (context.lastLabSnapshot.isNotEmpty &&
            context.lastDoctorSnapshot.isEmpty)) {
      final target = _labTargetResolver.resolve(
        intentResult: intent,
        context: context,
      );
      if (target.source == LaboratoryTargetSource.ordinal && target.hasLab) {
        context.lastIntent = AssistantIntent.selectResult;
        context.setAssistantResponse('تم اختيار ${target.laboratory!.title}');
        return AssistantActionPlan(
          kind: AssistantActionKind.selectEntity,
          intentResult: intent,
          target: target.laboratory,
          message: 'تم اختيار ${target.laboratory!.title}.',
          canExecute: true,
          labTargetResolution: target,
        );
      }
      if (target.requiresClarification) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showClarification,
          intentResult: intent.copyWithClarification(true),
          message: target.message,
          candidates: target.candidates,
          labTargetResolution: target,
        );
      }
    }

    final target = _targetResolver.resolve(
      intentResult: intent,
      context: context,
    );
    if (target.source == DoctorTargetSource.ordinal && target.hasDoctor) {
      context.lastIntent = AssistantIntent.selectResult;
      context.setAssistantResponse('تم اختيار ${target.doctor!.title}');
      return AssistantActionPlan(
        kind: AssistantActionKind.selectEntity,
        intentResult: intent,
        target: target.doctor,
        message: 'تم اختيار ${target.doctor!.title}.',
        canExecute: true,
        targetResolution: target,
        contextResolution: ContextResolution(
          status: ContextResolutionStatus.selectResult,
          intent: AssistantIntent.selectResult,
          target: target.doctor,
          requestedOrdinal: target.resultIndex,
          message: 'تم اختيار ${target.doctor!.title}.',
        ),
      );
    }
    if (target.requiresClarification) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: target.message,
        candidates: target.candidates,
        targetResolution: target,
      );
    }
    final resolved = _contextResolver.resolve(query, context);
    if (!resolved.handled) {
      return AssistantActionPlan(
        kind: AssistantActionKind.runGeneralSearch,
        intentResult: intent,
        canExecute: true,
      );
    }
    return _mapContextResolution(intent, resolved);
  }

  /// حجز سياقي: يحل الهدف المحدد فقط — بلا حجز تلقائي (سياسة قائمة).
  Future<AssistantActionPlan> _planContextualBooking(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) async {
    final target = _targetResolver.resolve(
      intentResult: intent,
      context: context,
    );

    if (target.source == DoctorTargetSource.explicitName &&
        target.hasDoctor) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: target.doctor,
        message: GhadeerFollowUpContext.bookingNotAutomaticMessage(
          target.doctor!,
        ),
        canExecute: false,
        targetResolution: target,
      );
    }

    if ((target.source == DoctorTargetSource.selectedContext ||
            target.source == DoctorTargetSource.ordinal) &&
        target.hasDoctor) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: target.doctor,
        message: GhadeerFollowUpContext.bookingNotAutomaticMessage(
          target.doctor!,
        ),
        canExecute: false,
        targetResolution: target,
      );
    }

    final selected = context.selectedDoctor;
    if (selected != null &&
        context.activeEntityType == ConversationEntityType.doctor) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: selected,
        message: GhadeerFollowUpContext.bookingNotAutomaticMessage(selected),
        canExecute: false,
      );
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.showClarification,
      intentResult: intent.copyWithClarification(true),
      message: target.message.isNotEmpty
          ? target.message
          : GhadeerFollowUpContext.noPronounTargetMessage(),
      canExecute: false,
      targetResolution: target,
    );
  }

  Future<AssistantActionPlan> _planAction(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) async {
    final target = _targetResolver.resolve(
      intentResult: intent,
      context: context,
    );

    switch (target.source) {
      case DoctorTargetSource.explicitName:
        if (target.requiresClarification && target.candidates.isNotEmpty) {
          context.rememberResults(
            target.candidates,
            query: query,
            intent: intent.intent,
            clearSelection: true,
            pendingActionForClarification: intent.intent,
            clarificationReason: ClarificationReason.ambiguousName,
          );
          final pending = context.pendingClarification ??
              const AmbiguityGate().fromDoctorResults(
                doctors: target.candidates,
                originalIntent: intent.intent,
                originalQuery: query,
                pendingAction: intent.intent,
                reason: ClarificationReason.ambiguousName,
              );
          if (pending != null) {
            context.setPendingClarification(pending);
          }
          final message = target.message.isNotEmpty
              ? target.message
              : pending != null
                  ? _clarificationResponses.build(pending)
                  : 'وجدت أكثر من طبيب. حدّد من القائمة أو قل: الثاني / الأول.';
          context.setAssistantResponse(message);
          return AssistantActionPlan(
            kind: AssistantActionKind.showClarification,
            intentResult: intent.copyWithClarification(true),
            candidates: target.candidates,
            message: message,
            canExecute: false,
            targetResolution: target,
          );
        }
        if (target.hasDoctor && !target.requiresSearch) {
          return _planForResolvedTarget(
            context,
            intent,
            target.doctor!,
            targetResolution: target,
          );
        }
        return _planExplicitName(query, context, intent, target.explicitName!);

      case DoctorTargetSource.ordinal:
      case DoctorTargetSource.selectedContext:
        if (!target.hasDoctor) {
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            message: target.message.isNotEmpty
                ? target.message
                : DoctorTargetResolution.unresolved.message,
            targetResolution: target,
          );
        }
        return _planForResolvedTarget(
          context,
          intent,
          target.doctor!,
          targetResolution: target,
        );

      case DoctorTargetSource.unresolved:
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          message: target.message.isNotEmpty
              ? target.message
              : _missingContextMessage(intent.intent),
          candidates: target.candidates,
          canExecute: false,
          targetResolution: target,
        );
    }
  }

  Future<AssistantActionPlan> _planExplicitName(
    String query,
    ConversationContext context,
    IntentResult intent,
    String nameQuery,
  ) async {
    lastMatcherQueryForTest = nameQuery;
    final results = await _lookupDoctors(nameQuery);
    final doctors = results
        .where((r) => r.type == SmartSearchResultType.doctor)
        .toList();

    final batch = _matcher.matchDoctors(
      query: nameQuery,
      doctors: [
        for (final d in doctors)
          (id: d.doctorId ?? d.title, name: d.title),
      ],
    );

    if (batch.matches.isEmpty) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: 'لم أجد طبيباً مطابقاً لـ «$nameQuery».',
        canExecute: false,
        targetResolution: DoctorTargetResolution(
          source: DoctorTargetSource.explicitName,
          explicitName: nameQuery,
          requiresSearch: true,
        ),
      );
    }

    if (batch.isAmbiguous ||
        (batch.matches.length > 1 && !batch.best!.isStrong)) {
      final matchedIds = <String>{
        for (final m in batch.plausible) m.doctorId ?? m.doctorName,
      };
      final list = doctors
          .where(
            (d) =>
                matchedIds.contains(d.doctorId ?? d.title) ||
                matchedIds.contains(d.title),
          )
          .toList();
      final finalList = list.isNotEmpty ? list : doctors;
      context.rememberResults(
        finalList,
        query: query,
        intent: intent.intent,
        clearSelection: true,
        pendingActionForClarification: intent.intent,
        clarificationReason: ClarificationReason.ambiguousName,
      );
      final pending = context.pendingClarification ??
          const AmbiguityGate().fromDoctorResults(
            doctors: finalList,
            originalIntent: intent.intent,
            originalQuery: query,
            pendingAction: intent.intent,
            reason: ClarificationReason.ambiguousName,
          );
      if (pending != null) {
        context.setPendingClarification(pending);
      }
      final message = pending != null
          ? _clarificationResponses.build(pending)
          : 'وجدت أكثر من طبيب. حدّد من القائمة أو قل: الثاني / الأول.';
      context.setAssistantResponse(message);
      return AssistantActionPlan(
        kind: AssistantActionKind.showClarification,
        intentResult: intent.copyWithClarification(true),
        candidates: finalList,
        message: message,
        canExecute: false,
        targetResolution: DoctorTargetResolution(
          source: DoctorTargetSource.explicitName,
          explicitName: nameQuery,
          requiresSearch: true,
          requiresClarification: true,
          candidates: finalList,
        ),
      );
    }

    final bestMatch = batch.best!;
    final resolved = doctors.firstWhere(
      (d) =>
          d.doctorId == bestMatch.doctorId || d.title == bestMatch.doctorName,
      orElse: () => doctors.first,
    );

    context.rememberResults(
      [resolved],
      query: query,
      intent: intent.intent,
    );

    return _planForResolvedTarget(
      context,
      intent,
      resolved,
      targetResolution: DoctorTargetResolution(
        source: DoctorTargetSource.explicitName,
        doctor: resolved,
        explicitName: nameQuery,
      ),
    );
  }

  /// إقرار محادثة قصير لـ«نعم/لا» حرّة بلا أي حالة معلّقة تستهلكها.
  ///
  /// مصدر واحد للجملتين. يعتمد [ArabicAnswerNormalizer] القائم بلا توسيع
  /// مفرداته، ولا يلمس الطبيب/المختبر المحدد ولا يبدأ بحثاً جديداً — لذلك
  /// تبقى دلالات السياق الحالية كما هي بعد الإقرار.
  AssistantActionPlan? _planBareAnswerAcknowledgement(
    String query,
    IntentResult intent,
  ) {
    final yes = ArabicAnswerNormalizer.isBareYes(query);
    if (!yes && !ArabicAnswerNormalizer.isBareNo(query)) return null;
    return AssistantActionPlan(
      kind: AssistantActionKind.showMessage,
      intentResult: intent,
      message: yes
          ? 'إذا تحب نكمّل، وضّح الطلب — مثلاً اسم الطبيب أو الشكوى.'
          : 'تمام. إذا تحتاج شي ثاني گلي.',
      canExecute: false,
    );
  }

  /// Phase 2G — طلب خدمة/بحث صريح قوي يقطع سؤال سريري معلّق فقط.
  ///
  /// لا يجعل كل specialtySearch يسبق السريري. يعتمد على IntentResolver القائم
  /// + فعل طلب صريح، ويتطلب lastQuestionKey سريرياً نشطاً.
  static bool _shouldExplicitServiceSwitchInterruptClinical({
    required IntentResult intent,
    required String query,
    required ConversationContext context,
  }) {
    if (!_hasActiveClinicalPendingQuestion(context)) return false;
    return _isStrongExplicitServiceRequest(intent, query);
  }

  static bool _hasActiveClinicalPendingQuestion(ConversationContext context) {
    if (context.mskSession.active &&
        (context.mskSession.lastQuestionKey ?? '').isNotEmpty) {
      return true;
    }
    if (context.respiratorySession.active &&
        (context.respiratorySession.lastQuestionKey ?? '').isNotEmpty) {
      return true;
    }
    if (context.dentalSession.active &&
        (context.dentalSession.lastQuestionKey ?? '').isNotEmpty) {
      return true;
    }
    if (context.chronicClinicalSession.active &&
        (context.chronicClinicalSession.lastQuestionKey ?? '').isNotEmpty) {
      return true;
    }
    if (context.pregnancyCompanionSession.active &&
        (context.pregnancyCompanionSession.lastQuestionKey ?? '').isNotEmpty) {
      return true;
    }
    if (context.adolescentCompanionSession.active &&
        (context.adolescentCompanionSession.lastQuestionKey ?? '').isNotEmpty) {
      return true;
    }
    return false;
  }

  /// طلب خدمة قوي فقط — ليس ذكر اختصاص عرضي ولا جواب سريري قصير.
  static bool _isStrongExplicitServiceRequest(
    IntentResult intent,
    String query,
  ) {
    final n = ArabicTextUtils.normalize(query);
    if (n.isEmpty) return false;
    // أجوبة سريرية قصيرة لا تُقطع أبداً عبر هذا المسار.
    if (ArabicAnswerNormalizer.isBareYes(query) ||
        ArabicAnswerNormalizer.isBareNo(query)) {
      return false;
    }
    if (RegExp(
      r'^(?:خفيف|شديد|متوسط|اي|من\s*يومين|صارله\s*يومين|'
      r'\d{1,2}\s*(?:سنه|سنة|سنوات|سنين)|'
      r'عمر[هة]\s*\d{1,2})\s*$',
    ).hasMatch(n.trim())) {
      return false;
    }

    switch (intent.intent) {
      case AssistantIntent.specialtySearch:
        // حتى لو IntentResolver صنّف specialtySearch (مثل ذكر «عظام» بعد «طبيب»)،
        // لا نقاطع إلا بفعل طلب صريح: أريد / ابحث / دور / وريني…
        return _hasStrongServiceRequestVerb(n);
      case AssistantIntent.findLab:
        if (_hasStrongServiceRequestVerb(n) &&
            RegExp(r'مختبر').hasMatch(n)) {
          return true;
        }
        return (intent.entities.laboratory ?? '').trim().isNotEmpty &&
            _hasStrongServiceRequestVerb(n);
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
        return RegExp(
              r'(?:أريد|اريد|ابي|ابحث|دور|وريني|ورّيني|اعرض|عرض(?:لي)?|شنو)\s*'
              r'.{0,20}باق',
            ).hasMatch(n) ||
            (_hasStrongServiceRequestVerb(n) && RegExp(r'باق').hasMatch(n));
      case AssistantIntent.doctorSearch:
        // بحث اسم بلا فعل طلب لا يقاطع الجلسة السريرية.
        return _hasStrongServiceRequestVerb(n) &&
            RegExp(r'(?:طبيب|دكتور)').hasMatch(n);
      default:
        return false;
    }
  }

  static bool _hasStrongServiceRequestVerb(String n) {
    // أريد/اريد ضمن الطلب الصريح — VoiceSpecialtySearchCommand لا يشترطها
    // للتصنيف، لكن Phase 2G يشترطها للمقاطعة.
    return RegExp(
      r'(?:أريد|اريد|ابي|ابحث(?:لي)?|دور(?:لي)?|وريني|ورّيني|اعرض|طل[عّ])',
    ).hasMatch(n);
  }

  bool _otherConsumerOwnsBareYesNo(
    String query,
    ConversationContext context,
  ) {
    if (!ArabicAnswerNormalizer.isBareYes(query) &&
        !ArabicAnswerNormalizer.isBareNo(query)) {
      return false;
    }
    final owner = context.activeYesNoConsumer;
    return owner != ConversationYesNoConsumer.none &&
        owner != ConversationYesNoConsumer.clinicalQuestion;
  }

  /// تأكيد/رفض فعل معلّق قصير — يعتمد على pendingAction أو lastIntent + كيان محدد.
  AssistantActionPlan? _tryPlanPendingActionAffirmation(
    String query,
    ConversationContext context,
    IntentResult intent,
  ) {
    final yes = ArabicAnswerNormalizer.isBareYes(query);
    final no = ArabicAnswerNormalizer.isBareNo(query) ||
        ArabicAnswerNormalizer.isCancelCommand(query) ||
        RegExp(
          r'^(?:لا\s*مو\s*هذا|لا\s*مو\s*هذاك|مو\s*هذا|مو\s*هذاك|الغي|إلغاء)$',
        ).hasMatch(ArabicTextUtils.normalize(query).trim());
    if (!yes && !no) return null;

    final pending = (context.pendingAction ?? '').trim().toLowerCase();
    final isCallPending = pending == 'call';
    final isWaPending = pending == 'whatsapp';
    // بلا فعل معلّق صريح: لا lastIntent كسلطة تأكيد — يمنع فعلاً قديماً بلا هدف.
    if (!isCallPending && !isWaPending) return null;

    final target = context.selectedEntity;
    if (target == null ||
        (target.type != SmartSearchResultType.doctor &&
            target.type != SmartSearchResultType.lab)) {
      context.clearPending();
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        message: 'ما عندي مزود محدد حالياً للتأكيد. اذكر الاسم أو اختَر من النتائج.',
        canExecute: false,
      );
    }

    if (no) {
      context.clearPending();
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: intent,
        target: target,
        message: 'تمام، ألغيت الطلب بخصوص ${target.title}. '
            'تگدر تختار غير أو تكتب الاسم.',
        canExecute: false,
      );
    }

    // نعم مع فعل معلّق: أعد تخطيط الفعل على نفس المزود (تأكيد سياقي).
    final actionIntent = isWaPending
        ? (target.type == SmartSearchResultType.lab
            ? AssistantIntent.messageLab
            : AssistantIntent.messageDoctor)
        : (target.type == SmartSearchResultType.lab
            ? AssistantIntent.callLab
            : AssistantIntent.callDoctor);
    final synthetic = IntentResult(
      intent: actionIntent,
      originalText: query,
      normalizedText: ArabicTextUtils.normalize(query),
      searchMeaning: intent.searchMeaning,
      entities: intent.entities,
      confidence: 100,
      requiresContext: false,
      source: IntentSource.context,
    );
    context.lastIntent = actionIntent;
    if (target.type == SmartSearchResultType.lab) {
      // مختبرات: حافظ على رسالة تأكيد واضحة دون مسار طبيب.
      context.setPendingAction(isWaPending ? 'whatsapp' : 'call');
      if (isWaPending && !target.canWhatsApp) {
        context.clearPending();
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: synthetic,
          target: target,
          message: 'واتساب ${target.title} غير متوفر حالياً.',
        );
      }
      if (!isWaPending && !target.canCall) {
        context.clearPending();
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: synthetic,
          target: target,
          message: 'رقم اتصال ${target.title} غير متوفر حالياً.',
        );
      }
      return AssistantActionPlan(
        kind: isWaPending
            ? AssistantActionKind.prepareWhatsApp
            : AssistantActionKind.prepareCall,
        intentResult: synthetic,
        target: target,
        message: isWaPending
            ? 'تمام، جاهز لفتح واتساب ${target.title}.'
            : 'تمام، جاهز للاتصال بـ ${target.title}.',
        canExecute: true,
      );
    }
    return _planForResolvedTarget(context, synthetic, target);
  }

  AssistantActionPlan _planForResolvedTarget(
    ConversationContext context,
    IntentResult intent,
    SmartSearchResult target, {
    DoctorTargetResolution? targetResolution,
  }) {
    switch (intent.intent) {
      case AssistantIntent.callDoctor:
        if (!target.canCall) {
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            target: target,
            message: 'رقم اتصال ${target.title} غير متوفر حالياً.',
            targetResolution: targetResolution,
          );
        }
        context.lastIntent = AssistantIntent.callDoctor;
        context.setPendingAction('call');
        return AssistantActionPlan(
          kind: AssistantActionKind.prepareCall,
          intentResult: intent,
          target: target,
          message: 'جاهز للاتصال بـ ${target.title}.',
          canExecute: true,
          targetResolution: targetResolution,
        );
      case AssistantIntent.messageDoctor:
        if (!target.canWhatsApp) {
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            target: target,
            message: 'واتساب ${target.title} غير متوفر حالياً.',
            targetResolution: targetResolution,
          );
        }
        context.lastIntent = AssistantIntent.messageDoctor;
        context.setPendingAction('whatsapp');
        return AssistantActionPlan(
          kind: AssistantActionKind.prepareWhatsApp,
          intentResult: intent,
          target: target,
          message: 'جاهز لفتح واتساب ${target.title}.',
          canExecute: true,
          targetResolution: targetResolution,
        );
      case AssistantIntent.showLocation:
        final loc = target.clinicLocation?.trim() ?? '';
        if (loc.isEmpty) {
          return AssistantActionPlan(
            kind: AssistantActionKind.showMessage,
            intentResult: intent,
            target: target,
            message:
                'موقع عيادة ${target.title} غير متوفر حالياً في البيانات.',
            targetResolution: targetResolution,
          );
        }
        return AssistantActionPlan(
          kind: AssistantActionKind.showLocation,
          intentResult: intent,
          target: target,
          message: 'عيادة ${target.title}: $loc',
          canExecute: true,
          targetResolution: targetResolution,
        );
      case AssistantIntent.showProfile:
        return AssistantActionPlan(
          kind: AssistantActionKind.openProfile,
          intentResult: intent,
          target: target,
          message: 'فتح ملف ${target.title}.',
          canExecute: true,
          targetResolution: targetResolution,
        );
      default:
        return AssistantActionPlan(
          kind: AssistantActionKind.runDoctorSearch,
          intentResult: intent,
          target: target,
          doctorQuery: target.title,
          canExecute: true,
          targetResolution: targetResolution,
        );
    }
  }

  AssistantActionPlan _mapContextResolution(
    IntentResult intent,
    ContextResolution resolved,
  ) {
    switch (resolved.status) {
      case ContextResolutionStatus.selectResult:
        return AssistantActionPlan(
          kind: AssistantActionKind.selectEntity,
          intentResult: intent,
          target: resolved.target,
          message: resolved.message,
          canExecute: true,
          contextResolution: resolved,
        );
      case ContextResolutionStatus.showLocation:
        return AssistantActionPlan(
          kind: AssistantActionKind.showLocation,
          intentResult: intent,
          target: resolved.target,
          message: resolved.message,
          canExecute: true,
          contextResolution: resolved,
        );
      case ContextResolutionStatus.callDoctor:
        return AssistantActionPlan(
          kind: AssistantActionKind.prepareCall,
          intentResult: intent,
          target: resolved.target,
          message: resolved.message,
          canExecute: resolved.target?.canCall == true,
          contextResolution: resolved,
        );
      case ContextResolutionStatus.messageDoctor:
        return AssistantActionPlan(
          kind: AssistantActionKind.prepareWhatsApp,
          intentResult: intent,
          target: resolved.target,
          message: resolved.message,
          canExecute: resolved.target?.canWhatsApp == true,
          contextResolution: resolved,
        );
      case ContextResolutionStatus.showProfile:
        return AssistantActionPlan(
          kind: AssistantActionKind.openProfile,
          intentResult: intent,
          target: resolved.target,
          message: resolved.message,
          canExecute: resolved.target != null,
          contextResolution: resolved,
        );
      case ContextResolutionStatus.selectionOutOfRange:
      case ContextResolutionStatus.noPreviousResults:
      case ContextResolutionStatus.locationUnavailable:
      case ContextResolutionStatus.contactUnavailable:
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: intent,
          target: resolved.target,
          message: resolved.message,
          contextResolution: resolved,
        );
      case ContextResolutionStatus.notContextual:
        return AssistantActionPlan(
          kind: AssistantActionKind.runGeneralSearch,
          intentResult: intent,
          canExecute: true,
        );
    }
  }

  static String _missingContextMessage(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.callDoctor:
        return 'أي طبيب تقصد؟ ابحث عن الطبيب أو اذكر اسمه أولاً.';
      case AssistantIntent.messageDoctor:
        return 'أي طبيب تقصد؟ ابحث عن الطبيب أو اذكر اسمه أولاً.';
      case AssistantIntent.showLocation:
        return 'حدد الطبيب أولاً ثم اسأل عن العيادة.';
      case AssistantIntent.showProfile:
        return 'حدد الطبيب أولاً حتى أفتح ملفه.';
      default:
        return 'حدد الطبيب أولاً من نتائج البحث.';
    }
  }

  static String _missingLabContextMessage(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
        return 'أي مختبر تقصد؟ ابحث عن المختبر أو اذكر اسمه أولاً.';
      case AssistantIntent.showLocation:
        return 'حدد المختبر أولاً ثم اسأل عن موقعه.';
      case AssistantIntent.showProfile:
        return 'حدد المختبر أولاً حتى أفتح ملفه.';
      case AssistantIntent.findPackage:
        return 'حدد المختبر أولاً ثم اسأل عن باقاته.';
      case AssistantIntent.findAnalysis:
        return 'حدد المختبر أولاً ثم اسأل عن التحاليل ضمن باقاته.';
      default:
        return 'حدد المختبر أولاً من نتائج البحث.';
    }
  }

  void _markHealthHandoffCompleted(ConversationContext context) {
    final hs = context.healthGuidanceSession;
    if (hs.handoff.status == HealthGuidanceHandoffStatus.providersDisplayed ||
        hs.handoff.status == HealthGuidanceHandoffStatus.accepted) {
      context.setHealthGuidanceSession(
        hs.copyWith(
          status: HealthGuidanceSessionStatus.completed,
          handoff: hs.handoff.copyWith(
            status: HealthGuidanceHandoffStatus.completed,
          ),
        ),
      );
    }
  }

  /// يثبت موضوع الجلسة وعمرها الصريح على ConversationContext.healthSubject.
  void _syncSessionHealthSubject(ConversationContext context, String query) {
    final previous = context.healthSubject;
    final resolution = _subjectBinding.subjectCoordinator.resolve(
      current: previous.isKnown ? previous : null,
      text: query,
    );
    var subject = resolution.subject;
    if (!subject.isKnown &&
        context.respiratorySession.population == RespiratoryPopulation.child) {
      subject = HealthSubjectContext(
        sessionKey: 'subj_child_g${context.conversationGeneration}',
        type: HealthSubjectType.child,
        evidence: HealthSubjectEvidence.explicitRelationship,
        isChild: true,
        ageGroup: 'child',
        ageYears: previous.ageYears,
      );
    }
    if (previous.isKnown &&
        subject.isKnown &&
        previous.type != subject.type) {
      context.noteClinicalSubjectScope(
        subject.type == HealthSubjectType.self ? 'owner' : 'other',
      );
    }
    final age =
        _unifiedBrain.ageResolver.parseSessionSubjectAgeYears(query);
    if (age != null && context.isSessionAgeAnswerContext) {
      subject = subject.copyWith(ageYears: age);
    } else if (previous.ageYears != null && previous.type == subject.type) {
      subject = subject.copyWith(ageYears: previous.ageYears);
    }
    context.setHealthSubject(subject);
  }

  /// Phase 3C — يenrich ذات المالك بعمر/جنس الملف كملاذ فقط؛ لا يكتب للملف.
  void _applyOwnerProfileContextBridge(
    ConversationContext context,
    PersonalCompanionProfile? ownerProfile,
  ) {
    const bridge = OwnerProfileContextBridge();
    final enriched = bridge.enrichSubjectIfAllowed(
      subject: context.healthSubject,
      resolved: context.resolvedConversationSubject,
      profile: ownerProfile,
    );
    // دائماً نضبط بعد الإثراء — equality لا يشمل reservedSexHint.
    context.setHealthSubject(enriched);
  }

  /// PC-1.24 — إنهاء رد سريري واحد مع تشخيص تحكيم آمن.
  AssistantActionPlan _finishUnifiedClinical({
    required ConversationContext context,
    required IntentResult intent,
    required String message,
    required bool textFirstOnly,
    required UnifiedBrainTurnContext brainTurn,
    required List<UnifiedBrainCandidate> candidates,
    required BrainAuthorityId primary,
    required bool clearedForeign,
    required bool questionUsed,
  }) {
    final contextual = <BrainAuthorityId>[];
    for (final c in candidates) {
      if (c.authority == primary) continue;
      if (c.role == BrainAuthorityRole.contextual ||
          c.role == BrainAuthorityRole.emotional ||
          c.role == BrainAuthorityRole.supportOnly) {
        contextual.add(c.authority);
      }
    }
    final plan = UnifiedBrainResponsePlan(
      primaryAuthority: primary,
      contextualAuthorities: contextual,
      suppressedAuthorities: candidates
          .where((c) => c.role == BrainAuthorityRole.suppressed)
          .map((c) => c.authority)
          .toList(growable: false),
      coreAnswer: message,
      questionBudgetUsed: questionUsed,
      message: message,
      serviceHandoff: brainTurn.isServiceOrNavigationIntent,
    );
    context.setUnifiedBrainDiagnostics(
      _unifiedBrain.diagnosticsFromPlan(
        turn: brainTurn,
        plan: plan,
        candidates: candidates,
        clinicalSessionsClearedForForeignTurn: clearedForeign,
      ),
    );
    if (questionUsed) {
      context.setUnifiedPendingClarificationKey('budget_used');
    }
    context.setAssistantResponse(message.isEmpty ? null : message);
    _syncSessionHealthSubject(context, intent.originalText);
    return AssistantActionPlan(
      kind: AssistantActionKind.showMessage,
      intentResult: intent,
      message: message,
      canExecute: false,
      textFirstOnly: textFirstOnly,
    );
  }
}

extension IntentResultCopy on IntentResult {
  IntentResult copyWithClarification(bool value) {
    return IntentResult(
      intent: intent,
      originalText: originalText,
      normalizedText: normalizedText,
      searchMeaning: searchMeaning,
      entities: entities,
      confidence: confidence,
      requiresContext: requiresContext,
      requiresClarification: value,
      source: source,
    );
  }
}

class _RespiratoryNluAttempt {
  const _RespiratoryNluAttempt({
    required this.called,
    required this.deterministic,
    this.parse,
    this.skipReason,
    this.fallbackReason,
    this.gateReason = '',
    this.acceptedSlots = const [],
    this.rejectedSlots = const [],
  });

  final bool called;
  final NluParse? parse;
  final NluSkipReason? skipReason;
  final NluSkipReason? fallbackReason;
  final String gateReason;
  final RespiratoryInterpretation deterministic;
  final List<String> acceptedSlots;
  final List<String> rejectedSlots;
}
