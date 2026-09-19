import '../../clinical_care_direction_request.dart';
import '../../clinical_knowledge_models.dart';
import '../../../search/arabic_text_utils.dart';
import 'pregnancy_evidence_catalog.dart';
import 'pregnancy_interpreter.dart';
import 'pregnancy_models.dart';
import 'pregnancy_policies.dart';
import 'pregnancy_question_planner.dart';
import 'pregnancy_response_builder.dart';
import 'pregnancy_safety_adapter.dart';

/// منسّق رفيق الحمل — PC-1.21 فوق السلطات القائمة (ليس محرك توليد).
class PregnancyCompanionCoordinator {
  PregnancyCompanionCoordinator({
    PregnancyInterpreter? interpreter,
    PregnancyQuestionPlanner? questions,
    PregnancySafetyAdapter? safety,
    PregnancyEvidenceCatalog? catalog,
    PregnancyDuePolicy? due,
    PregnancyCareAssembler? assembler,
    PregnancyUltrasoundPolicy? ultrasound,
    PregnancyResponseBuilder? responses,
  })  : _interpreter = interpreter ?? const PregnancyInterpreter(),
        _questions = questions ?? const PregnancyQuestionPlanner(),
        _safety = safety ?? const PregnancySafetyAdapter(),
        _catalog = catalog ?? PregnancyEvidenceCatalog(),
        _due = due ?? PregnancyDuePolicy(),
        _assembler = assembler ?? const PregnancyCareAssembler(),
        _ultrasound = ultrasound ?? const PregnancyUltrasoundPolicy(),
        _responses = responses ?? const PregnancyResponseBuilder();

  final PregnancyInterpreter _interpreter;
  final PregnancyQuestionPlanner _questions;
  final PregnancySafetyAdapter _safety;
  final PregnancyEvidenceCatalog _catalog;
  final PregnancyDuePolicy _due;
  final PregnancyCareAssembler _assembler;
  final PregnancyUltrasoundPolicy _ultrasound;
  final PregnancyResponseBuilder _responses;

  PregnancyInterpreter get interpreter => _interpreter;
  PregnancyEvidenceCatalog get catalog => _catalog;
  PregnancyDuePolicy get duePolicy => _due;
  PregnancyCareAssembler get assembler => _assembler;
  PregnancyUltrasoundPolicy get ultrasoundPolicy => _ultrasound;
  PregnancySafetyAdapter get safety => _safety;

  bool mayHandle({
    required String query,
    required PregnancyCompanionSession session,
  }) {
    final interp = _interpreter.interpret(query);
    if (interp.explicitFollowUp) return false;
    if (_looksLikeForeignDomain(query)) return false;
    if (_looksLikeCancelOrAbuse(query)) return false;
    if (_looksLikeGenericGreeting(query)) return false;

    if (session.active) {
      if (interp.asksWhatsLeft ||
          interp.asksFullChecklist ||
          interp.asksEducation ||
          interp.asksUltrasound ||
          interp.asksFetalSex ||
          interp.asksActivity ||
          interp.asksNutrition ||
          interp.asksServiceWhere ||
          interp.asksBooking ||
          interp.correctionSubject ||
          interp.correctionWeek ||
          interp.isPregnancyTurn ||
          ClinicalCareDirectionRequest.matches(query)) {
        return true;
      }
      if (session.lastQuestionKey != null && query.trim().isNotEmpty) {
        // جواب على سؤال الحمل فقط إن لم يكن مجالاً أجنبياً
        return !_looksLikeForeignDomain(query);
      }
      return false;
    }

    return _isPregnancyCareIntent(interp);
  }

  bool _isPregnancyCareIntent(PregnancyInterpretation interp) {
    if (interp.tryingToConceive) return true;
    if (interp.pregnancyLossHint) return true;
    if (interp.possibleOnly) return true;
    if (interp.status == PregnancyStatus.confirmed ||
        interp.status == PregnancyStatus.possible) {
      return true;
    }
    if (!interp.isPregnancyTurn) return false;
    if (interp.asksFetalSex ||
        interp.asksUltrasound ||
        interp.asksNutrition ||
        interp.asksActivity ||
        interp.asksWhatsLeft ||
        interp.asksFullChecklist ||
        interp.gdmEstablished ||
        interp.preexistingDiabetes ||
        interp.highBpHint) {
      return true;
    }
    if (interp.intent != PregnancyCompanionIntent.unknown &&
        interp.intent != PregnancyCompanionIntent.whatIsDue) {
      return true;
    }
    return interp.isPregnancyTurn;
  }

  bool _looksLikeForeignDomain(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    // سعال/ظهر/أسنان — اترك الحزم الأخرى (مع سياق حمل يُضاف هناك)
    final hasPregnancy = RegExp(r'(?:حامل|حمل)').hasMatch(n);
    final msk = RegExp(r'(?:ظهري|رقبتي|ركبتي|كتفي|فخذ)').hasMatch(n);
    final resp = RegExp(r'(?:سعال|كحه|ضيق\s*نفس)').hasMatch(n) &&
        !RegExp(r'ضيق\s*نفس\s*شديد').hasMatch(n);
    final dental = RegExp(r'(?:سن|سني|ضرس|ضرسي|لثه|اسنان|أسنان|خراج)').hasMatch(n);
    if (hasPregnancy && msk) return true;
    if (hasPregnancy && resp) return true;
    if (hasPregnancy && dental) return true; // PC-1.22 يردّ برد موحّد مع سياق حمل
    if (!hasPregnancy && (msk || resp)) return true;
    // بحث أطباء/مختبر عام بلا سؤال حمل
    if (RegExp(r'(?:دكتور\s+\w+|مختبر\s+\w+)').hasMatch(n) &&
        !RegExp(r'(?:حامل|حمل|نسائيه|توليد)').hasMatch(n)) {
      return true;
    }
    return false;
  }

  bool _looksLikeCancelOrAbuse(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    return RegExp(r'(?:الغي|وقف|stop|abuse|ضربني|عنف)').hasMatch(n);
  }

  bool _looksLikeGenericGreeting(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    return RegExp(r'^(?:مرحبا|السلام\s*عليكم|هلو|hi|hello)$').hasMatch(n);
  }

  Future<PregnancyCompanionTurnResult> handle({
    required String text,
    required PregnancyCompanionSession session,
  }) async {
    try {
      return _handle(text: text, session: session);
    } catch (_) {
      return PregnancyCompanionTurnResult(
        handled: false,
        message: '',
        session: session,
        success: false,
      );
    }
  }

  PregnancyCompanionTurnResult _handle({
    required String text,
    required PregnancyCompanionSession session,
  }) {
    if (_safety.deferToMentalSafety(text)) {
      return PregnancyCompanionTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToMentalSafety: true,
      );
    }

    final interp = _interpreter.interpret(text);

    if (interp.explicitFollowUp) {
      return PregnancyCompanionTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToFollowUp: true,
      );
    }

    if (_safety.deferToMedicalSafety(interp)) {
      return PregnancyCompanionTurnResult(
        handled: false,
        message: '',
        session: session.copyWith(active: true, redFlagCandidate: true),
        deferToMedicalSafety: true,
      );
    }

    if (interp.pregnancyLossHint ||
        interp.status == PregnancyStatus.pregnancyLossReported) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.loss(),
        session: session.copyWith(
          active: true,
          status: PregnancyStatus.pregnancyLossReported,
          clearGestation: true,
          intent: PregnancyCompanionIntent.emotionalSupport,
        ),
      );
    }

    if (RegExp(r'(?:بعد\s*الولاده|ولدت|صارلي\s*ولاده)').hasMatch(
      ArabicTextUtils.normalize(text),
    )) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.postpartumBoundary(),
        session: session.copyWith(
          active: true,
          status: PregnancyStatus.postpartum,
        ),
      );
    }

    if (interp.tryingToConceive) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.tryingToConceive(),
        session: session.copyWith(
          active: true,
          status: PregnancyStatus.tryingToConceive,
        ),
      );
    }

    if (interp.possibleOnly || interp.status == PregnancyStatus.possible) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.possibleNotConfirmed(),
        session: session.copyWith(
          active: true,
          status: PregnancyStatus.possible,
        ),
      );
    }

    if (interp.correctionSubject || interp.isAboutOtherPerson) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.otherPerson(),
        session: session.copyWith(
          active: true,
          isOtherPerson: true,
          otherPersonLabel: interp.otherPersonLabel,
          clearGestation: true,
          status: PregnancyStatus.unknown,
        ),
      );
    }

    if (RegExp(r'(?:اوقف\s*الدوا|أوقف\s*الدواء|اوقف\s*الدواء)').hasMatch(
      ArabicTextUtils.normalize(text),
    )) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.medicationBoundary(),
        session: session.copyWith(active: true),
      );
    }

    if (RegExp(r'(?:مخاض|طلق|تقلصات)').hasMatch(ArabicTextUtils.normalize(text))) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.laborBoundary(),
        session: session.copyWith(
          active: true,
          destinationType: ClinicalCareDestination.obstetricsGynecology,
        ),
      );
    }

    var merged = _merge(session, interp);

    // كتالوج فاشل → لا نخترع توقيتاً
    final catalogOk = _catalog.active.every((r) => r.hasEvidenceMetadata);
    if (!catalogOk) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message:
            'ما أكدر أعتمد جدولاً طبياً الآن بدون دليل مصدّق. '
            'راجعي طبيبة المتابعة.',
        session: merged,
        success: false,
      );
    }

    if (interp.asksBooking) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.noFakeAppointment(),
        session: merged,
        deferToServiceNavigation: true,
        preserveDestinationContext: true,
      );
    }

    // «وين توجهني» داخل جلسة نشطة = نفس معنى «وين اروح» القائم.
    if (interp.asksServiceWhere ||
        (session.active && ClinicalCareDirectionRequest.matches(text))) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.serviceObgyn(),
        session: merged.copyWith(
          destinationType: ClinicalCareDestination.obstetricsGynecology,
        ),
        deferToServiceNavigation: true,
        preserveDestinationContext: true,
      );
    }

    if (interp.asksFetalSex) {
      final myth = RegExp(
        r'(?:ضربات\s*القلب|شكل\s*البطن|اشتهيت|خرافه)',
      ).hasMatch(ArabicTextUtils.normalize(text));
      final msg = myth
          ? _responses.mythSexRefuse()
          : (merged.fetalSexFromClinician.isNotEmpty
              ? _responses.fetalSexFromClinician(merged.fetalSexFromClinician)
              : _responses.fetalSexEducational());
      return PregnancyCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} $msg',
        session: merged.copyWith(
          intent: PregnancyCompanionIntent.fetalSexQuestion,
        ),
      );
    }

    if (interp.fetalSexFromClinician.isNotEmpty) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.fetalSexFromClinician(interp.fetalSexFromClinician),
        session: merged,
      );
    }

    if (interp.asksUltrasound) {
      final recent = merged.completedCareItems
          .contains(PregnancyCareItem.ultrasoundDating.name);
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.ultrasound(
          recentlyDone: recent,
          commercialPresent: false,
        ),
        session: merged.copyWith(
          intent: PregnancyCompanionIntent.ultrasoundQuestion,
          destinationType: ClinicalCareDestination.radiology,
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'preg_ultrasound_before_24w_purpose',
          ],
        ),
      );
    }

    if (interp.asksNutrition) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)} ${_responses.nutrition()}',
        session: merged.copyWith(
          intent: PregnancyCompanionIntent.nutritionQuestion,
          matchedRuleIds: [...merged.matchedRuleIds, 'preg_nutrition_who'],
        ),
      );
    }

    if (interp.asksActivity) {
      final restriction = RegExp(r'(?:ارتاح|راحه|ممنوع\s*رياضه)').hasMatch(
            ArabicTextUtils.normalize(text),
          ) ||
          merged.clinicianPlanHint.contains('rest');
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.activity(
          restrictionKnown: restriction,
          warning: merged.redFlagCandidate,
        ),
        session: merged.copyWith(
          intent: PregnancyCompanionIntent.activityQuestion,
        ),
      );
    }

    if (interp.gdmEstablished) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.gdmEstablished(),
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'preg_gdm_screening_window_ada2026',
          ],
        ),
      );
    }

    if (interp.preexistingDiabetes) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.preexistingDiabetesPregnancy(),
        session: merged,
      );
    }

    if (RegExp(r'(?:السكر\s*\d+|قراءه\s*سكر)').hasMatch(
          ArabicTextUtils.normalize(text),
        ) &&
        merged.status == PregnancyStatus.confirmed) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.singleHighGlucose(),
        session: merged,
      );
    }

    if (interp.highBpHint) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.highBpHint(),
        session: merged.copyWith(
          destinationType: ClinicalCareDestination.obstetricsGynecology,
        ),
      );
    }

    if (interp.clinicianSaid.isNotEmpty) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)} ${_responses.clinicianPlan()}',
        session: merged.copyWith(
          intent: PregnancyCompanionIntent.clinicianPlanQuestion,
          clinicianPlanHint: 'clinician_reported',
        ),
      );
    }

    if (interp.intent == PregnancyCompanionIntent.emotionalSupport ||
        RegExp(r'(?:خايفه|خايفة|خوف)').hasMatch(ArabicTextUtils.normalize(text))) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.emotionalFear(),
        session: merged.copyWith(
          intent: PregnancyCompanionIntent.emotionalSupport,
        ),
      );
    }

    if (interp.symptomKey.isNotEmpty) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.symptom(interp.symptomKey, interp.symptomClass),
        session: merged.copyWith(intent: PregnancyCompanionIntent.currentSymptom),
      );
    }

    if (interp.datingSource == GestationalDatingSource.monthColloquial &&
        interp.gestationalWeeks == null &&
        !interp.asksWhatsLeft) {
      final q = _questions.nextQuestion(merged, interp);
      if (q != null) {
        return _ask(merged, q, prefix: _responses.monthAmbiguous());
      }
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.monthAmbiguous(),
        session: merged,
      );
    }

    if (interp.asksFullChecklist || interp.asksWhatsLeft) {
      final priorities = _assembler.assemble(
        session: merged,
        catalog: _catalog,
        due: _due,
        fullChecklist: interp.asksFullChecklist,
      );
      final withPri = merged.copyWith(
        priorities: priorities,
        intent: interp.asksFullChecklist
            ? PregnancyCompanionIntent.careChecklist
            : PregnancyCompanionIntent.whatIsDue,
        matchedRuleIds: [
          ...merged.matchedRuleIds,
          ...priorities
              .where((p) => p.matchedRuleId != null)
              .map((p) => p.matchedRuleId!),
        ],
      );
      final body = interp.asksFullChecklist
          ? _responses.fullChecklist(priorities)
          : _responses.whatsLeft(priorities);
      return PregnancyCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(withPri)} $body '
            '${_responses.followUpOffer()}',
        session: withPri,
      );
    }

    if (interp.asksEducation ||
        interp.intent == PregnancyCompanionIntent.whatToExpect) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.educationWeek(merged.gestationalWeeks),
        session: merged.copyWith(intent: PregnancyCompanionIntent.whatToExpect),
      );
    }

    if (RegExp(r'(?:استعداد\s*للولاده|تحضير\s*ولاده)').hasMatch(
      ArabicTextUtils.normalize(text),
    )) {
      return PregnancyCompanionTurnResult(
        handled: true,
        message: _responses.birthPrep(),
        session: merged.copyWith(
          intent: PregnancyCompanionIntent.birthPreparation,
        ),
      );
    }

    // سؤال متابعة إن لزم
    final qKey = _questions.nextQuestion(merged, interp);
    if (qKey != null && merged.status == PregnancyStatus.confirmed) {
      return _ask(merged, qKey, prefix: _responses.acknowledge(merged));
    }

    if (merged.status == PregnancyStatus.confirmed || interp.isPregnancyTurn) {
      final guidance = _catalog
              .findById('preg_who_anc_contacts_foundation')
              ?.arabicGuidance ??
          _responses.nextStepOb();
      return PregnancyCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} $guidance',
        session: merged.copyWith(
          lastGuidance: guidance,
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'preg_who_anc_contacts_foundation',
          ],
          destinationType: ClinicalCareDestination.obstetricsGynecology,
        ),
      );
    }

    return PregnancyCompanionTurnResult.notHandled(session);
  }

  PregnancyCompanionTurnResult _ask(
    PregnancyCompanionSession session,
    String key, {
    String prefix = '',
  }) {
    final asked = [...session.askedQuestionKeys, key];
    final prompt = _questions.promptFor(key);
    final msg = prefix.isEmpty ? prompt : '$prefix $prompt';
    return PregnancyCompanionTurnResult(
      handled: true,
      message: msg,
      session: session.copyWith(
        active: true,
        askedQuestionKeys: asked,
        lastQuestionKey: key,
        questionCount: session.questionCount + 1,
      ),
    );
  }

  PregnancyCompanionSession _merge(
    PregnancyCompanionSession session,
    PregnancyInterpretation interp,
  ) {
    var status = session.status;
    if (interp.status == PregnancyStatus.confirmed) {
      status = PregnancyStatus.confirmed;
    } else if (status == PregnancyStatus.unknown &&
        interp.status != PregnancyStatus.unknown) {
      status = interp.status;
    }

    final completed = [...session.completedCareItems];
    if (interp.careCompletedHint != null &&
        !completed.contains(interp.careCompletedHint)) {
      completed.add(interp.careCompletedHint!);
    }

    int? weeks = session.gestationalWeeks;
    int? days = session.gestationalDaysExtra;
    var dating = session.datingSource;
    var stage = session.stage;

    if (interp.correctionWeek && interp.gestationalWeeks != null) {
      weeks = interp.gestationalWeeks;
      days = interp.gestationalDaysExtra;
      dating = GestationalDatingSource.explicitWeek;
    } else if (interp.gestationalWeeks != null) {
      weeks = interp.gestationalWeeks;
      days = interp.gestationalDaysExtra ?? days;
      dating = interp.datingSource;
    } else if (interp.datingSource == GestationalDatingSource.trimesterOnly ||
        interp.datingSource == GestationalDatingSource.monthColloquial) {
      dating = interp.datingSource;
    }

    if (interp.stage != PregnancyStage.unknown) {
      stage = interp.stage;
    } else if (weeks != null) {
      if (weeks < PregnancyEvidenceCatalog.firstTrimesterEndExclusive) {
        stage = PregnancyStage.firstTrimester;
      } else if (weeks < PregnancyEvidenceCatalog.secondTrimesterEndExclusive) {
        stage = PregnancyStage.secondTrimester;
      } else if (weeks < PregnancyEvidenceCatalog.termStartWeek) {
        stage = PregnancyStage.thirdTrimester;
      } else {
        stage = PregnancyStage.termContext;
      }
    }

    return session.copyWith(
      active: true,
      status: status,
      datingSource: dating,
      gestationalWeeks: weeks,
      gestationalDaysExtra: days,
      stage: stage,
      isOtherPerson: interp.isAboutOtherPerson ? true : session.isOtherPerson,
      otherPersonLabel: interp.otherPersonLabel.isNotEmpty
          ? interp.otherPersonLabel
          : session.otherPersonLabel,
      completedCareItems: completed,
      intent: interp.intent != PregnancyCompanionIntent.unknown
          ? interp.intent
          : session.intent,
      clinicianPlanHint: interp.clinicianSaid.isNotEmpty
          ? interp.clinicianSaid
          : session.clinicianPlanHint,
      fetalSexFromClinician: interp.fetalSexFromClinician.isNotEmpty
          ? interp.fetalSexFromClinician
          : session.fetalSexFromClinician,
      redFlagCandidate: interp.redFlagCandidate || session.redFlagCandidate,
    );
  }

  /// حدود معمارية للاختبارات.
  bool createsPregnancyDatabase() => false;
  bool createsSecondEmergencyEngine() => false;
  bool replacesFollowUpAuthority() => false;
  bool replacesActivityAuthority() => false;
  bool replacesEmotionalAuthority() => false;
  bool commercialUltrasoundBias() => _ultrasound.commercialCanAlterIndication();
  bool infersSexFromMyths() => false;
  bool inventsGestationalDayFromVagueMonth() => false;
}
