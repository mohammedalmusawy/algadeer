import '../search/smart_search_models.dart';
import '../memory/memory_candidate.dart';
import '../memory/memory_session_policy.dart';
import '../companion/companion_onboarding_models.dart';
import '../companion/companion_profile_command_models.dart';
import '../companion/people/family_profile_command_models.dart';
import '../companion/people/subject_binding/subject_binding_models.dart';
import '../health/chronic_care/chronic_care_models.dart';
import '../health/emotional_support/emotional_support_models.dart';
import '../health/preventive/preventive_guidance_models.dart';
import '../health/sensitive_profile/health_profile_command_models.dart';
import '../health/family_sensitive/family_health_command_models.dart';
import '../follow_up/follow_up_command_models.dart';
import '../companion/personal_memory/personal_memory_command_models.dart';
import '../companion/personalization/personalization_models.dart';
import '../companion/ghadeer_social_conversation.dart';
import '../daily_context/daily_context_models.dart';
import '../clinical_knowledge/clinical_knowledge_models.dart';
import '../clinical_knowledge/packs/musculoskeletal/msk_models.dart';
import '../clinical_knowledge/packs/respiratory/respiratory_models.dart';
import '../clinical_knowledge/packs/chronic_care/chronic_care_models.dart';
import '../clinical_knowledge/packs/pregnancy_companion/pregnancy_models.dart';
import '../clinical_knowledge/packs/dental/dental_models.dart';
import '../companion/adolescent/adolescent_models.dart';
import '../wellbeing_planner/wellbeing_planner_models.dart';
import '../wellness/wellness_models.dart';
import '../unified_brain/unified_brain_models.dart';
import 'clarification/ambiguity_gate.dart';
import 'clarification/clarification_models.dart';
import 'conduct/conversation_conduct_models.dart';
import 'guided_conversation/guided_conversation_models.dart';
import '../health/guidance/health_guidance_models.dart';
import '../health/subject/health_subject_models.dart';
import 'conversation_session_lifecycle.dart';
import 'intent/assistant_intent.dart';
import 'result_context.dart';

export 'conversation_session_lifecycle.dart';

/// نوع الكيان النشط في جلسة المساعد.
enum ConversationEntityType {
  none,
  doctor,
  laboratory,
  analysis,
  package,
}

/// مستهلك نعم/لا العاري داخل الجلسة — آخر كاتب حي يفوز، بلا تخمين زمني.
enum ConversationYesNoConsumer {
  none,
  clarification,
  clinicalQuestion,
  doctorSuggestion,
  pendingAction,
}

/// ذاكرة جلسة قصيرة فقط — المصدر الأساسي لسياق Smart Brain.
///
/// PC-0.4: Persistent Personal Companion must NOT serialize
/// ConversationContext wholesale. [allowsPersistentMemorySerialization] is
/// always false.
///
/// نموذج متعدد الكيانات:
/// - selectedDoctor / selectedLaboratory / selectedAnalysis / selectedPackage
/// - activeEntityType يحدد الكيان المفضَّل للإشارات السياقية
/// - currentResultContext يعزل الترتيب بين أنواع النتائج
class ConversationContext with SessionOnlyStateMarker {
  static const int maxRecentReferences = 8;

  /// حراسة معمارية — Companion لا يسلسل هذا الكائن كذاكرة دائمة.
  @override
  bool get allowsPersistentMemorySerialization => false;

  String? lastQuery;
  AssistantIntent? lastIntent;

  List<SmartSearchResult> lastResults = const [];

  SmartSearchResult? selectedDoctor;
  SmartSearchResult? selectedLaboratory;
  SmartSearchResult? selectedAnalysis;
  SmartSearchResult? selectedPackage;

  ConversationEntityType activeEntityType = ConversationEntityType.none;

  List<SmartSearchResult> clarificationCandidates = const [];
  PendingClarification? pendingClarification;

  /// اقتراح تصحيح اسم طبيب معلّق — يعيش دوراً واحداً فقط داخل الجلسة.
  ///
  /// منفصل عن [pendingClarification] و[pendingAction]: «نعم» عليه تختار
  /// الطبيب فقط ولا تنفّذ اتصالاً/واتساب.
  PendingDoctorSuggestion? pendingDoctorSuggestion;

  String? lastAssistantResponse;
  String? pendingAction;
  String? pendingDate;
  String? pendingTime;

  /// جيل توقع نعم/لا — يزداد عند كل ملاحظة مستهلك، ليس طابعاً زمنياً.
  int _yesNoExpectationGeneration = 0;
  ConversationYesNoConsumer _yesNoConsumer = ConversationYesNoConsumer.none;
  String? sessionSpecialtyLabel;

  /// آخر باقات مرتبطة بتحليل محدد (للسياق اللاحق).
  List<SmartSearchResult> lastAnalysisPackageSnapshot = const [];

  /// معرّف دورة محادثة محلي متزايد — غير مُصرَّف.
  int turnId = 0;

  /// جيل موضوع الجلسة — يزداد عند reset/دورة أجنبية/تبديل شخص، لا عند كل دور.
  int conversationGeneration = kInitialConversationGeneration;

  /// آخر سبب حرّك [conversationGeneration] — أو [ConversationResetReason.none].
  ConversationResetReason lastResetReason = ConversationResetReason.none;

  /// مالك جلسة لسياق الشخص الصحي — RAM فقط، بلا استخراج عمر/جنس في 2A.
  HealthSubjectContext healthSubject = HealthSubjectContext.unknown;

  /// آخر مجموعة نتائج قابلة للاختيار (ترتيب/أرخص) بنوع واحد.
  ResultContext? currentResultContext;

  /// مراجع كيانات حديثة محدودة (5–8).
  List<RecentEntityReference> recentReferences = const [];

  /// تدفق محادثة موجَّه (Step 10A) — منفصل دلالياً عن PendingClarification.
  GuidedConversationState guidedConversation = GuidedConversationState.inactive;

  /// جلسة توجيه صحي (Step 10C) — ذاكرة فقط، بلا نص حر في الـ snapshot.
  HealthGuidanceSession healthGuidanceSession = HealthGuidanceSession.inactive;

  /// حالة أخلاقيات الحوار (Step 10E.1) — جلسة فقط، بلا عبارات مسيئة خام.
  ConversationConductSessionState conductState =
      ConversationConductSessionState.empty;

  /// مرشّحات ذاكرة PC-0.4 — RAM فقط داخل الجلسة، بلا SharedPreferences/Supabase.
  List<MemoryCandidate> sessionMemoryCandidates = const [];

  /// PC-1.2 onboarding تدريجي — حالة جلسة (التفضيل الدائم منفصل).
  CompanionOnboardingState companionOnboarding =
      CompanionOnboardingState.inactive;

  /// «لاحقاً» لهذه الجلسة فقط — لا تُعاد الدعوة تلقائياً.
  bool onboardingLaterThisSession = false;

  /// PC-1.3 — تأكيد عمليات ملف مدمّرة (حذف كامل).
  CompanionProfilePendingOp companionProfilePending =
      CompanionProfilePendingOp.none;

  /// PC-1.4 — موافقة/حذف ملف الصحة الحسّاس (جلسة فقط).
  HealthProfilePendingOp sensitiveHealthPending = HealthProfilePendingOp.none;

  /// PC-1.5 — جلسة متابعة مزمنة.
  ChronicCareSession chronicCareSession = ChronicCareSession.inactive;

  /// PC-1.6 — دعم عاطفي جلسة فقط (لا يُصرَّف ولا يدخل SensitiveHealthProfile).
  EmotionalSupportContext emotionalSupport = EmotionalSupportContext.inactive;

  /// PC-1.7 — جلسة توجيه وقائي (RAM فقط).
  PreventiveGuidanceSession preventiveSession = PreventiveGuidanceSession.inactive;

  /// PC-1.14 — جلسة عافية/نشاط (RAM فقط، بلا دفتر دائم).
  WellnessSession wellnessSession = WellnessSession.inactive;

  /// PC-1.15 — سياق يومي قصير الأمد (RAM فقط، بلا ترقية صامتة).
  DailyLifeContext dailyLifeContext = DailyLifeContext.empty;

  /// PC-1.16 — جلسة مخطّط عافية (RAM فقط، بلا سجل خطط دائم).
  WellbeingPlannerSession wellbeingPlannerSession =
      WellbeingPlannerSession.inactive;

  /// PC-1.17 — آخر استعلام معرفة سريرية (RAM فقط، بلا سجل مريض).
  ClinicalKnowledgeSession clinicalKnowledgeSession =
      ClinicalKnowledgeSession.inactive;

  /// PC-1.18 — جلسة حزمة MSK (RAM فقط، بلا دفتر ألم دائم).
  MskSession mskSession = MskSession.inactive;
  RespiratorySession respiratorySession = RespiratorySession.inactive;
  ChronicClinicalSession chronicClinicalSession =
      ChronicClinicalSession.inactive;
  PregnancyCompanionSession pregnancyCompanionSession =
      PregnancyCompanionSession.inactive;
  DentalSession dentalSession = DentalSession.inactive;
  AdolescentCompanionSession adolescentCompanionSession =
      AdolescentCompanionSession.inactive;

  /// PC-1.24 — تشخيص تحكيم آمن (بلا نصوص حسّاسة).
  UnifiedBrainDiagnostics unifiedBrainDiagnostics =
      UnifiedBrainDiagnostics.empty;

  /// PC-1.24 — مفتاح توضيح موحّد معلق (ميزانية سؤال واحدة عبر الحزم).
  String? unifiedPendingClarificationKey;

  /// PC-1.24 — مفتاح موضوع سريري سابق لكشف تبديل الشخص.
  String? lastClinicalSubjectScopeKey;

  /// PC-1.8 — تأكيد حذف شخص عائلة.
  FamilyProfilePendingOp familyProfilePending = FamilyProfilePendingOp.none;

  /// PC-1.10 — موافقة/حذف صحة عائلة حسّاسة (جلسة فقط).
  FamilyHealthPendingOp familySensitiveHealthPending =
      FamilyHealthPendingOp.none;

  /// PC-1.11 — موافقة/إدارة التزامات المتابعة (جلسة فقط).
  FollowUpPendingOp followUpPending = FollowUpPendingOp.none;

  /// PC-1.12 — أهداف/اهتمامات/تفضيلات (جلسة فقط للمعلّق).
  PersonalMemoryPendingOp personalMemoryPending = PersonalMemoryPendingOp.none;

  /// PC-1.13 — تتبع تخصيص جلسة فقط (مفاتيح بلا قيم حسّاسة).
  PersonalizationSessionState personalizationSession =
      PersonalizationSessionState.empty;

  /// Phase 3D STEP 3 — استمرارية اجتماعية خفيفة (جلسة فقط؛ بلا ثبات).
  GhadeerSocialContext ghadeerSocial = GhadeerSocialContext.empty;

  /// PC-1.8/PC-1.9 — ربط شخص دائم نشط — مصدر واحد.
  String? linkedFamilyPersonId;

  /// PC-1.9 — توضيح شخص معلّق (جلسة فقط).
  PendingPersonClarification pendingPersonClarification =
      PendingPersonClarification.inactive;

  /// PC-1.9 — آخر حلّ شخص للمحادثة (عقد downstream).
  ResolvedConversationSubject resolvedConversationSubject =
      ResolvedConversationSubject.unknown;

  void setCompanionOnboarding(CompanionOnboardingState state) {
    companionOnboarding = state;
  }

  void setCompanionProfilePending(CompanionProfilePendingOp op) {
    companionProfilePending = op;
  }

  void setFamilyProfilePending(FamilyProfilePendingOp op) {
    familyProfilePending = op;
  }

  void setFamilySensitiveHealthPending(FamilyHealthPendingOp op) {
    familySensitiveHealthPending = op;
  }

  void setFollowUpPending(FollowUpPendingOp op) {
    followUpPending = op;
  }

  void setPersonalMemoryPending(PersonalMemoryPendingOp op) {
    personalMemoryPending = op;
  }

  void setPersonalizationSession(PersonalizationSessionState state) {
    personalizationSession = state;
  }

  void setGhadeerSocial(GhadeerSocialContext state) {
    ghadeerSocial = state;
  }

  void setLinkedFamilyPersonId(String? personId) {
    linkedFamilyPersonId = personId;
  }

  void setPendingPersonClarification(PendingPersonClarification pending) {
    pendingPersonClarification = pending;
  }

  void setResolvedConversationSubject(ResolvedConversationSubject subject) {
    resolvedConversationSubject = subject;
  }

  void setSensitiveHealthPending(HealthProfilePendingOp op) {
    sensitiveHealthPending = op;
  }

  void setChronicCareSession(ChronicCareSession session) {
    chronicCareSession = session;
  }

  void setEmotionalSupport(EmotionalSupportContext support) {
    emotionalSupport = support;
  }

  void setPreventiveSession(PreventiveGuidanceSession session) {
    preventiveSession = session;
  }

  void setWellnessSession(WellnessSession session) {
    wellnessSession = session;
  }

  void setDailyLifeContext(DailyLifeContext context) {
    dailyLifeContext = context;
  }

  void setWellbeingPlannerSession(WellbeingPlannerSession session) {
    wellbeingPlannerSession = session;
  }

  void setClinicalKnowledgeSession(ClinicalKnowledgeSession session) {
    clinicalKnowledgeSession = session;
  }

  void setMskSession(MskSession session) {
    final previous = currentClinicalYesNoQuestionKey;
    mskSession = session;
    _syncClinicalYesNoExpectation(previousKey: previous);
  }

  void setRespiratorySession(RespiratorySession session) {
    final previous = currentClinicalYesNoQuestionKey;
    respiratorySession = session;
    _syncClinicalYesNoExpectation(previousKey: previous);
  }

  void setChronicClinicalSession(ChronicClinicalSession session) {
    final previous = currentClinicalYesNoQuestionKey;
    chronicClinicalSession = session;
    _syncClinicalYesNoExpectation(previousKey: previous);
  }

  void setPregnancyCompanionSession(PregnancyCompanionSession session) {
    final previous = currentClinicalYesNoQuestionKey;
    pregnancyCompanionSession = session;
    _syncClinicalYesNoExpectation(previousKey: previous);
  }

  void setDentalSession(DentalSession session) {
    final previous = currentClinicalYesNoQuestionKey;
    dentalSession = session;
    _syncClinicalYesNoExpectation(previousKey: previous);
  }

  void setAdolescentCompanionSession(AdolescentCompanionSession session) {
    final previous = currentClinicalYesNoQuestionKey;
    adolescentCompanionSession = session;
    _syncClinicalYesNoExpectation(previousKey: previous);
  }

  void setUnifiedBrainDiagnostics(UnifiedBrainDiagnostics diagnostics) {
    unifiedBrainDiagnostics = diagnostics;
  }

  void setUnifiedPendingClarificationKey(String? key) {
    unifiedPendingClarificationKey = key;
  }

  void setHealthSubject(HealthSubjectContext subject) {
    healthSubject = subject;
    if (healthGuidanceSession.isActive) {
      healthGuidanceSession = healthGuidanceSession.copyWith(
        facts: healthGuidanceSession.facts.withSubject(subject),
      );
    }
  }

  /// هل يجوز فهم العبارة كجواب عمر لموضوع الجلسة النشط؟
  bool get isSessionAgeAnswerContext {
    if (respiratorySession.active) {
      if (respiratorySession.lastQuestionKey == 'childAge') return true;
      if (respiratorySession.population == RespiratoryPopulation.child) {
        return true;
      }
    }
    if (healthSubject.type == HealthSubjectType.child &&
        (respiratorySession.active ||
            mskSession.active ||
            dentalSession.active ||
            chronicClinicalSession.active ||
            pregnancyCompanionSession.active ||
            adolescentCompanionSession.active)) {
      return true;
    }
    return false;
  }

  void _advanceConversationGeneration(ConversationResetReason reason) {
    conversationGeneration += 1;
    lastResetReason = reason;
  }

  void _clearClinicalPackSessionFields() {
    mskSession = MskSession.inactive;
    respiratorySession = RespiratorySession.inactive;
    chronicClinicalSession = ChronicClinicalSession.inactive;
    pregnancyCompanionSession = PregnancyCompanionSession.inactive;
    dentalSession = DentalSession.inactive;
    adolescentCompanionSession = AdolescentCompanionSession.inactive;
    clinicalKnowledgeSession = ClinicalKnowledgeSession.inactive;
    unifiedPendingClarificationKey = null;
    _clearYesNoExpectationIf(ConversationYesNoConsumer.clinicalQuestion);
  }

  /// مسح جلسات الحزم السريرية عند دورة أجنبية (خدمة/تحية/إلغاء).
  void clearClinicalPackSessionsForForeignTurn() {
    _clearClinicalPackSessionFields();
    _advanceConversationGeneration(ConversationResetReason.foreignTurn);
  }

  /// عزل عند تبديل الموضوع (مالك ↔ زوجة ↔ ابن…).
  void clearClinicalPackSessionsForSubjectSwitch() {
    _clearClinicalPackSessionFields();
    healthSubject = HealthSubjectContext.unknown;
    _advanceConversationGeneration(ConversationResetReason.subjectChanged);
  }

  /// إبطال جلسات شقيقة بعد اختيار سلطة أساسية.
  void invalidateSiblingClinicalSessions({
    required BrainAuthorityId primary,
    bool keepPregnancyContextual = false,
    bool keepAdolescentContextual = false,
  }) {
    if (primary != BrainAuthorityId.msk) {
      mskSession = MskSession.inactive;
    }
    if (primary != BrainAuthorityId.respiratory) {
      respiratorySession = RespiratorySession.inactive;
    }
    if (primary != BrainAuthorityId.chronicClinical) {
      chronicClinicalSession = ChronicClinicalSession.inactive;
    }
    if (primary != BrainAuthorityId.dental) {
      dentalSession = DentalSession.inactive;
    }
    if (primary != BrainAuthorityId.pregnancy && !keepPregnancyContextual) {
      pregnancyCompanionSession = PregnancyCompanionSession.inactive;
    }
    if (primary != BrainAuthorityId.adolescent && !keepAdolescentContextual) {
      adolescentCompanionSession = AdolescentCompanionSession.inactive;
    }
    _syncClinicalYesNoExpectation(
      previousKey: currentClinicalYesNoQuestionKey,
    );
  }

  /// يتتبّع نطاق الموضوع ويمسح الجلسات عند التبديل.
  bool noteClinicalSubjectScope(String scopeKey) {
    final prev = lastClinicalSubjectScopeKey;
    lastClinicalSubjectScopeKey = scopeKey;
    if (prev != null && prev.isNotEmpty && prev != scopeKey) {
      clearClinicalPackSessionsForSubjectSwitch();
      return true;
    }
    return false;
  }

  void addSessionMemoryCandidates(List<MemoryCandidate> candidates) {
    if (candidates.isEmpty) return;
    sessionMemoryCandidates = List<MemoryCandidate>.unmodifiable([
      ...sessionMemoryCandidates,
      ...candidates,
    ]);
  }

  void clearSessionMemoryCandidates() {
    sessionMemoryCandidates = const [];
  }

  bool get hasResults => lastResults.isNotEmpty;

  bool get hasGuidedPendingQuestion =>
      guidedConversation.isWaitingForAnswer;

  bool get hasActiveHealthGuidance => healthGuidanceSession.isActive;
  bool get hasSelection => selectedEntity != null;
  bool get hasPendingAction =>
      pendingAction != null && pendingAction!.trim().isNotEmpty;
  bool get hasPendingClarification => pendingClarification != null;
  bool get hasPendingDoctorSuggestion => pendingDoctorSuggestion != null;

  /// المستهلك الحي لـ نعم/لا العاري: آخر توقع سُجّل وما زال صالحاً.
  ConversationYesNoConsumer get activeYesNoConsumer {
    if (_isLiveYesNoConsumer(_yesNoConsumer)) return _yesNoConsumer;
    if (currentClinicalYesNoQuestionKey != null) {
      return ConversationYesNoConsumer.clinicalQuestion;
    }
    if (pendingClarification?.isYesNoConfirmation == true) {
      return ConversationYesNoConsumer.clarification;
    }
    if (pendingDoctorSuggestion != null) {
      return ConversationYesNoConsumer.doctorSuggestion;
    }
    if (_hasConfirmablePendingAction) {
      return ConversationYesNoConsumer.pendingAction;
    }
    return ConversationYesNoConsumer.none;
  }

  bool get _hasConfirmablePendingAction {
    final a = (pendingAction ?? '').trim().toLowerCase();
    return a == 'call' || a == 'whatsapp';
  }

  /// مفتاح سؤال سريري يتوقع نعم/لا — ليس عمراً أو مدة.
  String? get currentClinicalYesNoQuestionKey {
    final keys = <String?>[
      respiratorySession.active ? respiratorySession.lastQuestionKey : null,
      mskSession.active ? mskSession.lastQuestionKey : null,
      dentalSession.active ? dentalSession.lastQuestionKey : null,
      chronicClinicalSession.active
          ? chronicClinicalSession.lastQuestionKey
          : null,
      pregnancyCompanionSession.active
          ? pregnancyCompanionSession.lastQuestionKey
          : null,
      adolescentCompanionSession.active
          ? adolescentCompanionSession.lastQuestionKey
          : null,
    ];
    for (final key in keys) {
      if (_isClinicalYesNoQuestionKey(key)) return key;
    }
    return null;
  }

  static bool _isClinicalYesNoQuestionKey(String? key) {
    switch (key) {
      case 'childAssociated':
      case 'associatedRed':
      case 'hemoptysis':
      case 'chestPain':
      case 'function':
      case 'trauma':
      case 'weightBearing':
      case 'swellingPresent':
      case 'confirmPregnancy':
      case 'dmEstablished':
      case 'htnEstablished':
      case 'subjectClarify':
        return true;
      default:
        return false;
    }
  }

  bool _isLiveYesNoConsumer(ConversationYesNoConsumer consumer) {
    switch (consumer) {
      case ConversationYesNoConsumer.none:
        return false;
      case ConversationYesNoConsumer.clarification:
        return pendingClarification?.isYesNoConfirmation == true;
      case ConversationYesNoConsumer.clinicalQuestion:
        return currentClinicalYesNoQuestionKey != null;
      case ConversationYesNoConsumer.doctorSuggestion:
        return pendingDoctorSuggestion != null;
      case ConversationYesNoConsumer.pendingAction:
        return _hasConfirmablePendingAction;
    }
  }

  void _noteYesNoExpectation(ConversationYesNoConsumer consumer) {
    if (consumer == ConversationYesNoConsumer.none) {
      _yesNoConsumer = ConversationYesNoConsumer.none;
      return;
    }
    _yesNoExpectationGeneration += 1;
    _yesNoConsumer = consumer;
  }

  void _clearYesNoExpectationIf(ConversationYesNoConsumer consumer) {
    if (_yesNoConsumer == consumer) {
      _yesNoConsumer = ConversationYesNoConsumer.none;
    }
  }

  void _syncClinicalYesNoExpectation({required String? previousKey}) {
    final next = currentClinicalYesNoQuestionKey;
    if (next != null && next != previousKey) {
      if (_yesNoConsumer == ConversationYesNoConsumer.pendingAction) {
        pendingAction = null;
        pendingDate = null;
        pendingTime = null;
      }
      _noteYesNoExpectation(ConversationYesNoConsumer.clinicalQuestion);
      return;
    }
    if (next == null) {
      _clearYesNoExpectationIf(ConversationYesNoConsumer.clinicalQuestion);
    }
  }

  SmartSearchResult? get selectedEntity {
    switch (activeEntityType) {
      case ConversationEntityType.doctor:
        return selectedDoctor;
      case ConversationEntityType.laboratory:
        return selectedLaboratory;
      case ConversationEntityType.analysis:
        return selectedAnalysis;
      case ConversationEntityType.package:
        return selectedPackage;
      case ConversationEntityType.none:
        return null;
    }
  }

  SmartSearchResult? selectedOf(ConversationEntityType type) {
    switch (type) {
      case ConversationEntityType.doctor:
        return selectedDoctor;
      case ConversationEntityType.laboratory:
        return selectedLaboratory;
      case ConversationEntityType.analysis:
        return selectedAnalysis;
      case ConversationEntityType.package:
        return selectedPackage;
      case ConversationEntityType.none:
        return null;
    }
  }

  /// عناصر باقات من سياق النتائج السلطوي فقط (PC-0.2).
  ///
  /// Conversation ordinals / أرخص / أغلى resolve against the latest
  /// authoritative typed ResultContext, never a legacy/display cache.
  List<SmartSearchResult> get currentPackageResultItems {
    final ctx = currentResultContext;
    if (ctx != null &&
        ctx.entityType == ConversationEntityType.package &&
        ctx.isNotEmpty) {
      return ctx.items;
    }
    return const [];
  }

  void advanceTurn() {
    turnId += 1;
  }

  void setResultContext({
    required ConversationEntityType entityType,
    required List<SmartSearchResult> items,
    AssistantIntent? intent,
  }) {
    advanceTurn();
    currentResultContext = ResultContext(
      entityType: entityType,
      items: List<SmartSearchResult>.unmodifiable(items),
      sourceIntent: intent ?? lastIntent,
      turnId: turnId,
    );
  }

  /// يُبطِل سياق النتائج السلطوي — يمنع ترتيباً على نتائج قديمة/عرضية.
  void invalidateAuthoritativeResultContext({String? reason}) {
    currentResultContext = null;
  }

  /// عناصر الترتيب السلطوية لنوع واحد — ResultContext فقط (أو clarification إن طابقت).
  List<SmartSearchResult> authoritativeItemsFor(ConversationEntityType type) {
    return _ordinalItems(type);
  }

  void pushRecentReference(
    SmartSearchResult entity, {
    AssistantIntent? intent,
    String? relationFromPrevious,
  }) {
    final type = EntityActionCompatibility.fromResultType(entity.type);
    if (type == null) return;
    final id = _entityId(entity, type);
    if (id.isEmpty) return;
    final next = [
      RecentEntityReference(
        entityType: type,
        entityId: id,
        payload: entity,
        sourceIntent: intent ?? lastIntent,
        relationFromPrevious: relationFromPrevious,
        turnId: turnId,
      ),
      ...recentReferences.where(
        (r) => !(r.entityType == type && r.entityId == id),
      ),
    ];
    recentReferences = List<RecentEntityReference>.unmodifiable(
      next.take(maxRecentReferences),
    );
  }

  /// يفعّل التركيز على كيان محفوظ دون مسح الاختيارات الأخرى.
  void focusOn(ConversationEntityType type) {
    final entity = selectedOf(type);
    if (entity == null) {
      activeEntityType = ConversationEntityType.none;
      return;
    }
    activeEntityType = type;
    pushRecentReference(entity, relationFromPrevious: 'return_focus');
  }

  String _entityId(SmartSearchResult e, ConversationEntityType type) {
    switch (type) {
      case ConversationEntityType.doctor:
        return (e.doctorId ?? '').trim();
      case ConversationEntityType.laboratory:
        return (e.labId ?? '').trim();
      case ConversationEntityType.analysis:
        return (e.analysisId ?? '').trim();
      case ConversationEntityType.package:
        return (e.packageId ?? '').trim();
      case ConversationEntityType.none:
        return '';
    }
  }

  /// لقطة مطوّر فقط — ليست للمستخدم النهائي.
  Map<String, Object?> debugSnapshot() {
    return {
      'turnId': turnId,
      'conversationGeneration': conversationGeneration,
      'lastResetReason': lastResetReason.name,
      'activeEntityType': activeEntityType.name,
      'selectedDoctorId': selectedDoctor?.doctorId,
      'selectedLaboratoryId': selectedLaboratory?.labId,
      'selectedAnalysisId': selectedAnalysis?.analysisId,
      'selectedPackageId': selectedPackage?.packageId,
      'resultEntityType': currentResultContext?.entityType.name,
      'resultCount': currentResultContext?.length ?? 0,
      'resultTurnId': currentResultContext?.turnId,
      'pendingClarificationType': pendingClarification?.entityType.name,
      'recentReferenceTypes': [
        for (final r in recentReferences) r.entityType.name,
      ],
      'recentReferenceCount': recentReferences.length,
      'lastIntent': lastIntent?.name,
      'yesNoConsumer': activeYesNoConsumer.name,
      'yesNoExpectationGeneration': _yesNoExpectationGeneration,
      'hasPendingAction': hasPendingAction,
      'sessionMemoryCandidateCount': sessionMemoryCandidates.length,
      'sessionMemoryCandidateCategories': [
        for (final c in sessionMemoryCandidates) c.category.name,
      ],
      ...companionOnboarding.debugMap(),
      'onboardingLaterThisSession': onboardingLaterThisSession,
      ...companionProfilePending.debugMap(),
      ...familyProfilePending.debugMap(),
      'hasLinkedFamilyPerson': linkedFamilyPersonId != null,
      ...familySensitiveHealthPending.debugMap(),
      ...followUpPending.debugMap(),
      ...personalMemoryPending.debugMap(),
      ...personalizationSession.debugMap(),
      ...ghadeerSocial.debugMap(),
      ...pendingPersonClarification.debugMap(),
      ...resolvedConversationSubject.debugMap(),
      ...healthSubject.debugMap(),
      ...sensitiveHealthPending.debugMap(),
      ...chronicCareSession.debugMap(),
      ...wellnessSession.debugMap(),
      ...dailyLifeContext.debugMap(),
      ...wellbeingPlannerSession.debugMap(),
      ...clinicalKnowledgeSession.debugMap(),
      ...mskSession.debugMap(),
      ...respiratorySession.debugMap(),
      ...chronicClinicalSession.debugMap(),
      ...guidedConversation.debugMap(),
      ...healthGuidanceSession.debugSnapshot(),
      ...conductState.debugMap(),
    };
  }

  void setConductState(ConversationConductSessionState state) {
    conductState = state;
  }

  void clearConductState() {
    conductState = ConversationConductSessionState.empty;
  }

  void setGuidedConversation(GuidedConversationState state) {
    guidedConversation = state;
  }

  void clearGuidedConversation() {
    guidedConversation = GuidedConversationState.inactive;
  }

  void setHealthGuidanceSession(HealthGuidanceSession session) {
    healthGuidanceSession = session;
  }

  void clearHealthGuidanceSession() {
    healthGuidanceSession = HealthGuidanceSession.inactive;
  }

  List<SmartSearchResult> get lastDoctorSnapshot => lastResults
      .where((r) => r.type == SmartSearchResultType.doctor)
      .toList(growable: false);

  List<SmartSearchResult> get lastLabSnapshot => lastResults
      .where((r) => r.type == SmartSearchResultType.lab)
      .toList(growable: false);

  List<SmartSearchResult> get lastAnalysisSnapshot => lastResults
      .where((r) => r.type == SmartSearchResultType.analysis)
      .toList(growable: false);

  List<SmartSearchResult> get lastPackageSnapshot => lastResults
      .where(
        (r) =>
            r.type == SmartSearchResultType.package ||
            r.type == SmartSearchResultType.offer,
      )
      .toList(growable: false);

  bool get hasDoctorResults => lastDoctorSnapshot.isNotEmpty;
  bool get hasLabResults => lastLabSnapshot.isNotEmpty;
  bool get hasAnalysisResults => lastAnalysisSnapshot.isNotEmpty;
  bool get hasPackageResults => lastPackageSnapshot.isNotEmpty;

  List<SmartSearchResult> get lastDoctorResults => lastDoctorSnapshot;

  void rememberQuery(String query, {AssistantIntent? intent}) {
    final q = query.trim();
    if (q.isEmpty) return;
    lastQuery = q;
    if (intent != null) lastIntent = intent;
  }

  void rememberResults(
    List<SmartSearchResult> results, {
    String? query,
    AssistantIntent? intent,
    String? specialtyLabel,
    String? assistantResponse,
    bool clearSelection = true,
    AssistantIntent? pendingActionForClarification,
    ClarificationReason clarificationReason =
        ClarificationReason.multipleMatches,
  }) {
    if (query != null && query.trim().isNotEmpty) {
      lastQuery = query.trim();
    }
    if (intent != null) lastIntent = intent;
    // lastResults = UI/display cache + compatibility mirror (PC-0.2).
    // Conversation ordinals MUST NOT read this independently.
    lastResults = List<SmartSearchResult>.unmodifiable(results);
    if (specialtyLabel != null) {
      sessionSpecialtyLabel = specialtyLabel;
    }
    if (assistantResponse != null) {
      lastAssistantResponse = assistantResponse;
    }

    final doctors = lastDoctorSnapshot;
    final labs = lastLabSnapshot;
    final analyses = lastAnalysisSnapshot;
    final packages = lastPackageSnapshot;

    final purePackages = packages.isNotEmpty &&
        doctors.isEmpty &&
        labs.isEmpty &&
        analyses.isEmpty;
    final pureAnalyses = analyses.isNotEmpty &&
        doctors.isEmpty &&
        labs.isEmpty &&
        packages.isEmpty;
    final pureDoctors = doctors.isNotEmpty &&
        labs.isEmpty &&
        analyses.isEmpty &&
        packages.isEmpty;
    final pureLabs = labs.isNotEmpty &&
        doctors.isEmpty &&
        analyses.isEmpty &&
        packages.isEmpty;

    if (clearSelection) {
      clearPending();
      if (purePackages) {
        selectedPackage = null;
        if (activeEntityType == ConversationEntityType.package) {
          activeEntityType = ConversationEntityType.none;
        }
        clearPendingClarification();
      } else if (pureAnalyses) {
        selectedAnalysis = null;
        if (activeEntityType == ConversationEntityType.analysis) {
          activeEntityType = ConversationEntityType.none;
        }
        clearPendingClarification();
      } else if (pureDoctors) {
        selectedDoctor = null;
        if (activeEntityType == ConversationEntityType.doctor) {
          activeEntityType = ConversationEntityType.none;
        }
        clearPendingClarification();
      } else if (pureLabs) {
        selectedLaboratory = null;
        if (activeEntityType == ConversationEntityType.laboratory) {
          activeEntityType = ConversationEntityType.none;
        }
        clearPendingClarification();
      } else {
        // نتائج فارغة / مختلطة / عامة مع clearSelection: لا نتيجة نقية تُعيد
        // اختيار هدف، فامسح الأهداف القديمة حتى لا يحل ضمير لاحق («اتصل بيه»)
        // إلى اختيار من نتائج أُبطلت؛ ويُبطَل ResultContext أدناه.
        selectedDoctor = null;
        selectedLaboratory = null;
        selectedAnalysis = null;
        selectedPackage = null;
        activeEntityType = ConversationEntityType.none;
        clarificationCandidates = const [];
        clearPendingClarification();
      }
    }

    if (purePackages) {
      setResultContext(
        entityType: ConversationEntityType.package,
        items: packages,
        intent: intent,
      );
      _applyPackageResults(
        packages,
        intent: intent,
        query: query,
        pendingActionForClarification: pendingActionForClarification,
        clarificationReason: clarificationReason,
      );
    } else if (pureAnalyses) {
      setResultContext(
        entityType: ConversationEntityType.analysis,
        items: analyses,
        intent: intent,
      );
      _applyAnalysisResults(
        analyses,
        intent: intent,
        query: query,
        pendingActionForClarification: pendingActionForClarification,
        clarificationReason: clarificationReason,
      );
    } else if (pureDoctors) {
      setResultContext(
        entityType: ConversationEntityType.doctor,
        items: doctors,
        intent: intent,
      );
      _applyDoctorResults(
        doctors,
        intent: intent,
        query: query,
        pendingActionForClarification: pendingActionForClarification,
        clarificationReason: clarificationReason,
      );
    } else if (pureLabs) {
      setResultContext(
        entityType: ConversationEntityType.laboratory,
        items: labs,
        intent: intent,
      );
      _applyLabResults(
        labs,
        intent: intent,
        query: query,
        pendingActionForClarification: pendingActionForClarification,
        clarificationReason: clarificationReason,
      );
    } else {
      // فارغ أو مختلط/عام: يُبطِل السياق السلطوي حتى لا يبقى ترتيبي قديم.
      invalidateAuthoritativeResultContext(reason: 'mixed_or_empty_results');
      clarificationCandidates = const [];
      clearPendingClarification();
    }
  }

  void rememberAnalysisPackages(List<SmartSearchResult> packages) {
    lastAnalysisPackageSnapshot =
        List<SmartSearchResult>.unmodifiable(packages);
    // اعرضها كنتائج باقات دون تبديل الكيان النشط تلقائياً.
    if (packages.isNotEmpty) {
      lastResults = List<SmartSearchResult>.unmodifiable(packages);
      setResultContext(
        entityType: ConversationEntityType.package,
        items: packages,
        intent: lastIntent,
      );
    } else {
      // صفر باقات مرتبطة → لا تُبقِ سياق باقات قديم لـ «أرخص».
      clearPendingClarification();
      clarificationCandidates = const [];
      invalidateAuthoritativeResultContext(reason: 'empty_analysis_packages');
    }
  }

  void _applyDoctorResults(
    List<SmartSearchResult> doctors, {
    AssistantIntent? intent,
    String? query,
    AssistantIntent? pendingActionForClarification,
    ClarificationReason clarificationReason =
        ClarificationReason.multipleMatches,
  }) {
    if (doctors.length == 1) {
      selectDoctor(doctors.first);
      clarificationCandidates = const [];
      clearPendingClarification();
    } else if (doctors.length > 1) {
      clarificationCandidates = List<SmartSearchResult>.unmodifiable(doctors);
      final gate = const AmbiguityGate().fromDoctorResults(
        doctors: doctors,
        originalIntent: intent,
        originalQuery: query ?? lastQuery,
        pendingAction: pendingActionForClarification,
        reason: clarificationReason,
      );
      if (gate != null) setPendingClarification(gate);
    } else {
      clarificationCandidates = const [];
      clearPendingClarification();
    }
  }

  void _applyLabResults(
    List<SmartSearchResult> labs, {
    AssistantIntent? intent,
    String? query,
    AssistantIntent? pendingActionForClarification,
    ClarificationReason clarificationReason =
        ClarificationReason.multipleMatches,
  }) {
    if (labs.length == 1) {
      selectLaboratory(labs.first);
      clarificationCandidates = const [];
      clearPendingClarification();
    } else if (labs.length > 1) {
      clarificationCandidates = List<SmartSearchResult>.unmodifiable(labs);
      final gate = const AmbiguityGate().fromLabResults(
        labs: labs,
        originalIntent: intent,
        originalQuery: query ?? lastQuery,
        pendingAction: pendingActionForClarification,
        reason: clarificationReason,
      );
      if (gate != null) setPendingClarification(gate);
    } else {
      clarificationCandidates = const [];
      clearPendingClarification();
    }
  }

  void _applyAnalysisResults(
    List<SmartSearchResult> analyses, {
    AssistantIntent? intent,
    String? query,
    AssistantIntent? pendingActionForClarification,
    ClarificationReason clarificationReason =
        ClarificationReason.multipleMatches,
  }) {
    if (analyses.length == 1) {
      selectAnalysis(analyses.first);
      clarificationCandidates = const [];
      clearPendingClarification();
    } else if (analyses.length > 1) {
      clarificationCandidates =
          List<SmartSearchResult>.unmodifiable(analyses);
      final gate = const AmbiguityGate().fromAnalysisResults(
        analyses: analyses,
        originalIntent: intent,
        originalQuery: query ?? lastQuery,
        pendingAction: pendingActionForClarification,
        reason: clarificationReason,
      );
      if (gate != null) setPendingClarification(gate);
    } else {
      clarificationCandidates = const [];
      clearPendingClarification();
    }
  }

  void _applyPackageResults(
    List<SmartSearchResult> packages, {
    AssistantIntent? intent,
    String? query,
    AssistantIntent? pendingActionForClarification,
    ClarificationReason clarificationReason =
        ClarificationReason.multipleMatches,
  }) {
    if (packages.length == 1) {
      selectPackage(packages.first);
      clarificationCandidates = const [];
      clearPendingClarification();
    } else if (packages.length > 1) {
      clarificationCandidates =
          List<SmartSearchResult>.unmodifiable(packages);
      final gate = const AmbiguityGate().fromPackageResults(
        packages: packages,
        originalIntent: intent,
        originalQuery: query ?? lastQuery,
        pendingAction: pendingActionForClarification,
        reason: clarificationReason,
      );
      if (gate != null) setPendingClarification(gate);
    } else {
      clarificationCandidates = const [];
      clearPendingClarification();
    }
  }

  void setPendingClarification(PendingClarification? pending) {
    pendingClarification = pending;
    if (pending != null && pending.isYesNoConfirmation) {
      _noteYesNoExpectation(ConversationYesNoConsumer.clarification);
    } else {
      _clearYesNoExpectationIf(ConversationYesNoConsumer.clarification);
    }
    if (pending == null) {
      clarificationCandidates = const [];
      return;
    }
    final doctors = pending.doctorResults;
    if (doctors.isNotEmpty) {
      clarificationCandidates = List<SmartSearchResult>.unmodifiable(doctors);
      if (lastDoctorSnapshot.isEmpty ||
          lastDoctorSnapshot.length != doctors.length) {
        lastResults = List<SmartSearchResult>.unmodifiable(doctors);
      }
      return;
    }
    final labs = pending.labResults;
    if (labs.isNotEmpty) {
      clarificationCandidates = List<SmartSearchResult>.unmodifiable(labs);
      if (lastLabSnapshot.isEmpty || lastLabSnapshot.length != labs.length) {
        lastResults = List<SmartSearchResult>.unmodifiable(labs);
      }
      return;
    }
    final analyses = pending.analysisResults;
    if (analyses.isNotEmpty) {
      clarificationCandidates =
          List<SmartSearchResult>.unmodifiable(analyses);
      if (lastAnalysisSnapshot.isEmpty ||
          lastAnalysisSnapshot.length != analyses.length) {
        lastResults = List<SmartSearchResult>.unmodifiable(analyses);
      }
      return;
    }
    final packages = pending.packageResults;
    if (packages.isNotEmpty) {
      clarificationCandidates =
          List<SmartSearchResult>.unmodifiable(packages);
      if (lastPackageSnapshot.isEmpty ||
          lastPackageSnapshot.length != packages.length) {
        lastResults = List<SmartSearchResult>.unmodifiable(packages);
      }
    }
  }

  void clearPendingClarification() {
    pendingClarification = null;
    _clearYesNoExpectationIf(ConversationYesNoConsumer.clarification);
  }

  void setPendingDoctorSuggestion(PendingDoctorSuggestion? suggestion) {
    pendingDoctorSuggestion = suggestion;
    if (suggestion != null) {
      _noteYesNoExpectation(ConversationYesNoConsumer.doctorSuggestion);
    } else {
      _clearYesNoExpectationIf(ConversationYesNoConsumer.doctorSuggestion);
    }
  }

  void clearPendingDoctorSuggestion() {
    pendingDoctorSuggestion = null;
    _clearYesNoExpectationIf(ConversationYesNoConsumer.doctorSuggestion);
  }

  /// بحث أطباء جديد — يُبطل نتائج البحث فقط، ولا يحرّك [conversationGeneration]
  /// ولا يمسح الجلسة السريرية.
  void beginNewDoctorSearch({String? query, AssistantIntent? intent}) {
    if (query != null && query.trim().isNotEmpty) lastQuery = query.trim();
    if (intent != null) lastIntent = intent;
    selectedDoctor = null;
    activeEntityType = ConversationEntityType.none;
    clarificationCandidates = const [];
    clearPendingClarification();
    clearPendingDoctorSuggestion();
    clearPending();
    // يُبطِل ترتيباً على نتائج مختبر/باقة قديمة قبل وصول نتائج الأطباء.
    invalidateAuthoritativeResultContext(reason: 'begin_new_doctor_search');
  }

  void beginNewLabSearch({String? query, AssistantIntent? intent}) {
    if (query != null && query.trim().isNotEmpty) lastQuery = query.trim();
    if (intent != null) lastIntent = intent;
    selectedLaboratory = null;
    activeEntityType = ConversationEntityType.none;
    clarificationCandidates = const [];
    clearPendingClarification();
    clearPendingDoctorSuggestion();
    clearPending();
    invalidateAuthoritativeResultContext(reason: 'begin_new_lab_search');
  }

  void beginNewAnalysisSearch({String? query, AssistantIntent? intent}) {
    if (query != null && query.trim().isNotEmpty) lastQuery = query.trim();
    if (intent != null) lastIntent = intent;
    selectedAnalysis = null;
    lastAnalysisPackageSnapshot = const [];
    activeEntityType = ConversationEntityType.none;
    clarificationCandidates = const [];
    clearPendingClarification();
    clearPendingDoctorSuggestion();
    clearPending();
    invalidateAuthoritativeResultContext(reason: 'begin_new_analysis_search');
  }

  void beginNewPackageSearch({String? query, AssistantIntent? intent}) {
    if (query != null && query.trim().isNotEmpty) lastQuery = query.trim();
    if (intent != null) lastIntent = intent;
    selectedPackage = null;
    activeEntityType = ConversationEntityType.none;
    clarificationCandidates = const [];
    clearPendingClarification();
    clearPendingDoctorSuggestion();
    clearPending();
    invalidateAuthoritativeResultContext(reason: 'begin_new_package_search');
  }

  void selectEntity(SmartSearchResult? entity) {
    if (entity == null) {
      if (activeEntityType == ConversationEntityType.doctor) {
        selectedDoctor = null;
      } else if (activeEntityType == ConversationEntityType.laboratory) {
        selectedLaboratory = null;
      } else if (activeEntityType == ConversationEntityType.analysis) {
        selectedAnalysis = null;
      } else if (activeEntityType == ConversationEntityType.package) {
        selectedPackage = null;
      }
      activeEntityType = ConversationEntityType.none;
      return;
    }
    if (entity.type == SmartSearchResultType.doctor) {
      selectDoctor(entity);
    } else if (entity.type == SmartSearchResultType.lab) {
      selectLaboratory(entity);
    } else if (entity.type == SmartSearchResultType.analysis) {
      selectAnalysis(entity);
    } else if (entity.type == SmartSearchResultType.package ||
        entity.type == SmartSearchResultType.offer) {
      selectPackage(entity);
    }
  }

  void selectDoctor(SmartSearchResult doctor) {
    selectedDoctor = doctor;
    activeEntityType = ConversationEntityType.doctor;
    clarificationCandidates = const [];
    clearPendingClarification();
    pushRecentReference(doctor);
    // Step 10F: اختيار طبيب بعد عرض نتائج التسليم يُكمل الجلسة الصحية.
    final h = healthGuidanceSession.handoff;
    if (h.status == HealthGuidanceHandoffStatus.providersDisplayed ||
        h.status == HealthGuidanceHandoffStatus.accepted) {
      healthGuidanceSession = healthGuidanceSession.copyWith(
        status: HealthGuidanceSessionStatus.completed,
        handoff: h.copyWith(status: HealthGuidanceHandoffStatus.completed),
      );
    }
  }

  void selectLaboratory(SmartSearchResult lab) {
    selectedLaboratory = lab;
    activeEntityType = ConversationEntityType.laboratory;
    clarificationCandidates = const [];
    clearPendingClarification();
    pushRecentReference(lab);
  }

  void selectAnalysis(SmartSearchResult analysis) {
    selectedAnalysis = analysis;
    activeEntityType = ConversationEntityType.analysis;
    clarificationCandidates = const [];
    clearPendingClarification();
    pushRecentReference(analysis);
  }

  /// يختار باقة ويحفظ مرجع المختبر الأب دون جعله نشطاً تلقائياً.
  void selectPackage(SmartSearchResult package) {
    selectedPackage = package;
    activeEntityType = ConversationEntityType.package;
    clarificationCandidates = const [];
    clearPendingClarification();
    pushRecentReference(package);
    final labId = (package.labId ?? '').trim();
    if (labId.isEmpty) return;
    final labName = (package.labName ?? package.subtitle).trim();
    selectedLaboratory = SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: labName.isNotEmpty ? labName : 'مختبر',
      subtitle: package.clinicLocation ?? 'مختبر',
      labId: labId,
      labName: labName.isNotEmpty ? labName : null,
      clinicLocation: package.clinicLocation,
      phone: package.phone,
      whatsapp: package.whatsapp,
    );
    pushRecentReference(
      selectedLaboratory!,
      relationFromPrevious: 'package_parent_lab',
    );
    // لا تبدّل activeEntityType إلى laboratory.
  }

  SmartSearchResult? selectDoctorByOrdinal(int oneBasedIndex) {
    final doctors = _ordinalItems(ConversationEntityType.doctor);
    final index = oneBasedIndex == -1 ? doctors.length : oneBasedIndex;
    if (index < 1 || index > doctors.length) return null;
    final chosen = doctors[index - 1];
    selectDoctor(chosen);
    return chosen;
  }

  SmartSearchResult? selectLaboratoryByOrdinal(int oneBasedIndex) {
    final labs = _ordinalItems(ConversationEntityType.laboratory);
    final index = oneBasedIndex == -1 ? labs.length : oneBasedIndex;
    if (index < 1 || index > labs.length) return null;
    final chosen = labs[index - 1];
    selectLaboratory(chosen);
    return chosen;
  }

  SmartSearchResult? selectAnalysisByOrdinal(int oneBasedIndex) {
    final list = _ordinalItems(ConversationEntityType.analysis);
    final index = oneBasedIndex == -1 ? list.length : oneBasedIndex;
    if (index < 1 || index > list.length) return null;
    final chosen = list[index - 1];
    selectAnalysis(chosen);
    return chosen;
  }

  SmartSearchResult? selectPackageByOrdinal(int oneBasedIndex) {
    final list = _ordinalItems(ConversationEntityType.package);
    final index = oneBasedIndex == -1 ? list.length : oneBasedIndex;
    if (index < 1 || index > list.length) return null;
    final chosen = list[index - 1];
    selectPackage(chosen);
    return chosen;
  }

  /// Conversation ordinals resolve against the latest authoritative typed
  /// ResultContext, never a legacy/display cache (PC-0.2).
  /// PendingClarification candidates may supply ordinals while clarification
  /// is open — they are explicit state, not lastResults.
  List<SmartSearchResult> _ordinalItems(ConversationEntityType type) {
    final pending = pendingClarification;
    if (pending != null) {
      final fromPending = switch (type) {
        ConversationEntityType.doctor => pending.doctorResults,
        ConversationEntityType.laboratory => pending.labResults,
        ConversationEntityType.analysis => pending.analysisResults,
        ConversationEntityType.package => pending.packageResults,
        ConversationEntityType.none => const <SmartSearchResult>[],
      };
      if (fromPending.isNotEmpty) return fromPending;
    }

    final ctx = currentResultContext;
    if (ctx != null && ctx.entityType == type && ctx.isNotEmpty) {
      return ctx.items;
    }
    // لا سقوط إلى lastDoctorSnapshot / lastResults — يمنع ترتيباً قديماً.
    return const [];
  }

  void setPendingAction(String? action, {String? date, String? time}) {
    pendingAction = action?.trim().isEmpty == true ? null : action?.trim();
    if (date != null) pendingDate = date;
    if (time != null) pendingTime = time;
    if (_hasConfirmablePendingAction) {
      _noteYesNoExpectation(ConversationYesNoConsumer.pendingAction);
    } else {
      _clearYesNoExpectationIf(ConversationYesNoConsumer.pendingAction);
    }
  }

  void clearPending() {
    pendingAction = null;
    pendingDate = null;
    pendingTime = null;
    _clearYesNoExpectationIf(ConversationYesNoConsumer.pendingAction);
  }

  void setAssistantResponse(String? text) {
    final t = text?.trim();
    lastAssistantResponse = (t == null || t.isEmpty) ? null : t;
  }

  void reset({
    ConversationResetReason reason = ConversationResetReason.explicitUserReset,
  }) {
    lastQuery = null;
    lastIntent = null;
    lastResults = const [];
    selectedDoctor = null;
    selectedLaboratory = null;
    selectedAnalysis = null;
    selectedPackage = null;
    activeEntityType = ConversationEntityType.none;
    clarificationCandidates = const [];
    pendingClarification = null;
    pendingDoctorSuggestion = null;
    lastAssistantResponse = null;
    pendingAction = null;
    pendingDate = null;
    pendingTime = null;
    _yesNoConsumer = ConversationYesNoConsumer.none;
    _yesNoExpectationGeneration = 0;
    sessionSpecialtyLabel = null;
    lastAnalysisPackageSnapshot = const [];
    turnId = 0;
    currentResultContext = null;
    recentReferences = const [];
    guidedConversation = GuidedConversationState.inactive;
    healthGuidanceSession = HealthGuidanceSession.inactive;
    conductState = ConversationConductSessionState.empty;
    sessionMemoryCandidates = const [];
    companionOnboarding = CompanionOnboardingState.inactive;
    onboardingLaterThisSession = false;
    companionProfilePending = CompanionProfilePendingOp.none;
    familyProfilePending = FamilyProfilePendingOp.none;
    familySensitiveHealthPending = FamilyHealthPendingOp.none;
    followUpPending = FollowUpPendingOp.none;
    personalMemoryPending = PersonalMemoryPendingOp.none;
    personalizationSession = PersonalizationSessionState.empty;
    ghadeerSocial = GhadeerSocialContext.empty;
    linkedFamilyPersonId = null;
    pendingPersonClarification = PendingPersonClarification.inactive;
    resolvedConversationSubject = ResolvedConversationSubject.unknown;
    sensitiveHealthPending = HealthProfilePendingOp.none;
    chronicCareSession = ChronicCareSession.inactive;
    emotionalSupport = EmotionalSupportContext.inactive;
    preventiveSession = PreventiveGuidanceSession.inactive;
    wellnessSession = WellnessSession.inactive;
    dailyLifeContext = DailyLifeContext.empty;
    wellbeingPlannerSession = WellbeingPlannerSession.inactive;
    clinicalKnowledgeSession = ClinicalKnowledgeSession.inactive;
    mskSession = MskSession.inactive;
    respiratorySession = RespiratorySession.inactive;
    chronicClinicalSession = ChronicClinicalSession.inactive;
    pregnancyCompanionSession = PregnancyCompanionSession.inactive;
    dentalSession = DentalSession.inactive;
    adolescentCompanionSession = AdolescentCompanionSession.inactive;
    unifiedBrainDiagnostics = UnifiedBrainDiagnostics.empty;
    unifiedPendingClarificationKey = null;
    lastClinicalSubjectScopeKey = null;
    healthSubject = HealthSubjectContext.unknown;
    _advanceConversationGeneration(reason);
  }
}
