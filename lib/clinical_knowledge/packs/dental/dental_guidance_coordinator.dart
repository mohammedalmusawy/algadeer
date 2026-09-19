import '../../clinical_care_direction_request.dart';
import '../../clinical_knowledge_models.dart';
import '../../../search/arabic_text_utils.dart';
import 'dental_interpreter.dart';
import 'dental_models.dart';
import 'dental_policies.dart';
import 'dental_question_planner.dart';
import 'dental_response_builder.dart';
import 'dental_rule_catalog.dart';
import 'dental_safety_adapter.dart';

/// منسّق حزمة الأسنان/الفم — PC-1.22.
class DentalGuidanceCoordinator {
  DentalGuidanceCoordinator({
    DentalInterpreter? interpreter,
    DentalQuestionPlanner? questions,
    DentalSafetyAdapter? safety,
    DentalRuleCatalog? catalog,
    DentalUrgencyPolicy? urgency,
    DentalImagingPolicy? imaging,
    DentalTraumaPolicy? trauma,
    DentalResponseBuilder? responses,
  })  : _interpreter = interpreter ?? const DentalInterpreter(),
        _questions = questions ?? const DentalQuestionPlanner(),
        _safety = safety ?? const DentalSafetyAdapter(),
        _catalog = catalog ?? DentalRuleCatalog(),
        _urgency = urgency ?? const DentalUrgencyPolicy(),
        _imaging = imaging ?? const DentalImagingPolicy(),
        _trauma = trauma ?? const DentalTraumaPolicy(),
        _responses = responses ?? const DentalResponseBuilder();

  final DentalInterpreter _interpreter;
  final DentalQuestionPlanner _questions;
  final DentalSafetyAdapter _safety;
  final DentalRuleCatalog _catalog;
  final DentalUrgencyPolicy _urgency;
  final DentalImagingPolicy _imaging;
  final DentalTraumaPolicy _trauma;
  final DentalResponseBuilder _responses;

  DentalInterpreter get interpreter => _interpreter;
  DentalRuleCatalog get catalog => _catalog;
  DentalImagingPolicy get imagingPolicy => _imaging;
  DentalUrgencyPolicy get urgencyPolicy => _urgency;
  DentalTraumaPolicy get traumaPolicy => _trauma;
  DentalSafetyAdapter get safety => _safety;

  bool mayHandle({required String query, required DentalSession session}) {
    final interp = _interpreter.interpret(query);
    if (interp.explicitFollowUp) return false;
    if (_looksLikeForeignDomain(query)) return false;
    if (_looksLikeCancelOrAbuse(query)) return false;
    if (_looksLikeGenericGreeting(query)) return false;

    if (session.active) {
      if (interp.asksServiceWhere ||
          interp.asksBooking ||
          interp.asksImaging ||
          interp.asksAntibiotic ||
          interp.asksEducation ||
          interp.isDentalTurn ||
          interp.correctionSubject ||
          interp.negatesSwelling ||
          interp.negatesFever ||
          interp.negatesBleeding ||
          interp.negatesTrauma ||
          interp.correctionToothType ||
          ClinicalCareDirectionRequest.matches(query)) {
        return true;
      }
      // استمرار جلسة: تورم وجه/لثة بدون إعادة ذكر «سن»
      final n = ArabicTextUtils.normalize(query);
      if (RegExp(
        r'(?:وجه|لثه).{0,16}(?:وارم|ورم|انتفاخ)|(?:وارم|ورم).{0,16}(?:وجه|لثه)',
      ).hasMatch(n)) {
        return true;
      }
      if (session.lastQuestionKey != null && query.trim().isNotEmpty) {
        return !_looksLikeForeignDomain(query);
      }
      return false;
    }
    return interp.isDentalTurn;
  }

  bool _looksLikeForeignDomain(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    final dental = RegExp(r'(?:سن|ضرس|لثه|اسنان|خراج|فم)').hasMatch(n);
    // صداع/أذن/حلق/سعال/ظهر بلا سياق سني
    if (!dental &&
        RegExp(r'(?:صداع|اذن|أذن|حلق|سعال|كحه|ظهري|رقبتي)').hasMatch(n)) {
      return true;
    }
    // حمل عام بلا أسنان
    if (RegExp(r'(?:حامل|حمل)').hasMatch(n) &&
        !dental &&
        !RegExp(r'(?:سن|ضرس|لثه|اسنان)').hasMatch(n)) {
      return true;
    }
    // سكري/ضغط عام بلا أسنان
    if (RegExp(r'(?:سكري|ضغط)').hasMatch(n) && !dental) return true;
    return false;
  }

  bool _looksLikeCancelOrAbuse(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    return RegExp(r'(?:الغي|وقف|stop|ضربني|عنف)').hasMatch(n);
  }

  bool _looksLikeGenericGreeting(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    return RegExp(r'^(?:مرحبا|السلام\s*عليكم|هلو|hi|hello)$').hasMatch(n);
  }

  Future<DentalTurnResult> handle({
    required String text,
    required DentalSession session,
  }) async {
    try {
      return _handle(text: text, session: session);
    } catch (_) {
      return DentalTurnResult(
        handled: false,
        message: '',
        session: session,
        success: false,
      );
    }
  }

  DentalTurnResult _handle({
    required String text,
    required DentalSession session,
  }) {
    if (_safety.deferToMentalSafety(text)) {
      return DentalTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToMentalSafety: true,
      );
    }

    final interp = _interpreter.interpret(text);

    if (interp.explicitFollowUp) {
      return DentalTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToFollowUp: true,
      );
    }

    if (_safety.deferToMedicalSafety(interp)) {
      return DentalTurnResult(
        handled: false,
        message: '',
        session: session.copyWith(active: true, redFlagCandidate: true),
        deferToMedicalSafety: true,
      );
    }

    var working = session;

    if (interp.correctionSubject || interp.isAboutOtherPerson) {
      // لا نوقف الاستدلال السريري — نعزل الهوية ونكمّل (خصوصاً رضوض الأطفال)
      working = working.copyWith(
        active: true,
        isOtherPerson: true,
        otherPersonLabel: interp.otherPersonLabel,
        childContext:
            interp.childContextHint || interp.otherPersonLabel == 'child',
      );
    }

    if (interp.prophylaxisRequest) {
      return DentalTurnResult(
        handled: true,
        message: _responses.prophylaxisRefuse(),
        session: working.copyWith(active: true),
      );
    }

    if (interp.anticoagulantHint) {
      return DentalTurnResult(
        handled: true,
        message: _responses.anticoagulant(),
        session: working.copyWith(active: true),
      );
    }

    // كتالوج فاشل
    if (!_catalog.active.every((r) => r.hasEvidenceMetadata)) {
      return DentalTurnResult(
        handled: true,
        message:
            'ما أكدر أعتمد توصية مضاد/أشعة/رضوض بدون دليل مصدّق الآن. راجع طبيب أسنان.',
        session: working.copyWith(active: true),
        success: false,
      );
    }

    var merged = _merge(working, interp);
    merged = merged.copyWith(urgency: _urgency.resolve(merged));

    final img = _imaging.decide(session: merged, catalog: _catalog);
    merged = merged.copyWith(
      imagingAppropriateness: img.appropriateness,
      imagingModality: img.modality,
      imagingReasonCode: img.reasonCode,
      destinationType: ClinicalCareDestination.dentist,
    );

    if (interp.asksBooking) {
      return DentalTurnResult(
        handled: true,
        message: _responses.noFakeBooking(),
        session: merged,
        deferToServiceNavigation: true,
        preserveDestinationContext: true,
      );
    }

    // «وين توجهني» داخل جلسة نشطة = نفس معنى «وين اروح» القائم.
    if (interp.asksServiceWhere ||
        (session.active && ClinicalCareDirectionRequest.matches(text))) {
      return DentalTurnResult(
        handled: true,
        message: _responses.serviceDentist(),
        session: merged,
        deferToServiceNavigation: true,
        preserveDestinationContext: true,
      );
    }

    if (interp.asksAntibiotic ||
        interp.topic == DentalTopic.antibioticQuestion) {
      final rule = _catalog.findById('dental_ada_antibiotic_stewardship');
      return DentalTurnResult(
        handled: true,
        message: _responses.antibiotic(
          _catalog,
          named: interp.namedAntibioticRequest,
        ),
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            if (rule != null) rule.ruleId,
          ],
        ),
      );
    }

    // بعد الدمج — طلب المسكن يُعالج حتى لطفل/شخص آخر
    if (interp.asksAnalgesic) {
      return DentalTurnResult(
        handled: true,
        message:
            '${merged.isOtherPerson ? _responses.otherPerson() : ''} '
            '${_responses.analgesicBoundary(
              pregnancy: merged.pregnancyContext,
              child: merged.childContext || merged.isOtherPerson,
            )}',
        session: merged,
      );
    }

    if (interp.asksImaging ||
        interp.topic == DentalTopic.dentalImagingQuestion) {
      final routine = img.appropriateness !=
          ClinicalImagingAppropriateness.notRoutinelyIndicated;
      return DentalTurnResult(
        handled: true,
        message: _responses.imaging(
          routinelyIndicated: routine,
          pregnancy: merged.pregnancyContext,
        ),
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'dental_imaging_not_routine_toothache',
          ],
        ),
      );
    }

    if (interp.asksEducation || interp.topic == DentalTopic.educationOnly) {
      return DentalTurnResult(
        handled: true,
        message: _responses.education(text),
        session: merged.copyWith(
          // تعليمي: لا تثبت «مرض جلسة»
          topic: DentalTopic.educationOnly,
        ),
      );
    }

    if (interp.fearDentist) {
      return DentalTurnResult(
        handled: true,
        message: _responses.fearDentist(),
        session: merged,
      );
    }

    if (RegExp(r'(?:اخلع|خلع\s*الضرس|اريد\s*خلع)').hasMatch(
      ArabicTextUtils.normalize(text),
    )) {
      return DentalTurnResult(
        handled: true,
        message: _responses.extractionRequestRefuse(),
        session: merged,
      );
    }

    // رضوض
    if (merged.trauma != DentalTraumaKind.none ||
        merged.topic == DentalTopic.lostTooth ||
        merged.topic == DentalTopic.brokenTooth ||
        merged.topic == DentalTopic.dentalTrauma) {
      if (merged.trauma == DentalTraumaKind.avulsion &&
          merged.toothType == DentalToothType.unknown) {
        final q = _questions.nextQuestion(merged, interp);
        if (q != null) {
          return _ask(merged, q,
              prefix: _trauma.guidanceFor(
                trauma: merged.trauma,
                toothType: merged.toothType,
                catalog: _catalog,
              ));
        }
      }
      final g = _trauma.guidanceFor(
        trauma: merged.trauma == DentalTraumaKind.none
            ? DentalTraumaKind.unknown
            : merged.trauma,
        toothType: merged.toothType,
        catalog: _catalog,
      );
      return DentalTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} $g',
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            if (merged.toothType == DentalToothType.primary)
              'dental_aapd_avulsion_primary'
            else if (merged.toothType == DentalToothType.permanent)
              'dental_iadt_avulsion_permanent'
            else
              'dental_trauma_type_unknown_clarify',
          ],
        ),
      );
    }

    if (merged.topic == DentalTopic.facialSwelling ||
        merged.swelling == DentalSwellingClass.facial ||
        merged.swelling == DentalSwellingClass.progressiveFacial) {
      return DentalTurnResult(
        handled: true,
        message: _responses.facialSwelling(),
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'dental_facial_swelling_urgent_path',
          ],
        ),
      );
    }

    if (merged.userReportedAbscess) {
      return DentalTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)} ${_responses.abscessReported()}',
        session: merged,
      );
    }

    if (merged.topic == DentalTopic.pregnancyDentalConcern ||
        (merged.pregnancyContext && merged.topic == DentalTopic.toothPain)) {
      final painRule = _catalog.findById('dental_ada_pain_definitive_care');
      return DentalTurnResult(
        handled: true,
        message:
            '${_responses.pregnancyDental()} ${painRule?.arabicGuidance ?? ''} '
            '${_responses.followUpOffer()}',
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'dental_cdc_pregnancy_dental_care',
            if (painRule != null) painRule.ruleId,
          ],
        ),
      );
    }

    if (merged.topic == DentalTopic.gumBleeding) {
      return DentalTurnResult(
        handled: true,
        message: _responses.gumBleeding(),
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'dental_gum_bleeding_no_stop_brushing',
          ],
        ),
      );
    }

    if (merged.topic == DentalTopic.wisdomToothConcern) {
      return DentalTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} ${_responses.wisdom()}',
        session: merged,
      );
    }

    if (merged.topic == DentalTopic.oralLesion) {
      return DentalTurnResult(
        handled: true,
        message: _responses.oralLesion(),
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'dental_oral_lesion_persistence',
          ],
        ),
      );
    }

    if (merged.topic == DentalTopic.oralUlcer) {
      return DentalTurnResult(
        handled: true,
        message: _responses.oralUlcer(),
        session: merged,
      );
    }

    if (merged.topic == DentalTopic.toothSensitivity) {
      return DentalTurnResult(
        handled: true,
        message: _responses.sensitivity(),
        session: merged,
      );
    }

    if (merged.topic == DentalTopic.jawPain &&
        !RegExp(r'(?:سن|ضرس)').hasMatch(ArabicTextUtils.normalize(text))) {
      return DentalTurnResult(
        handled: true,
        message: _responses.jawPainDeferMsk(),
        session: merged,
      );
    }

    if (merged.topic == DentalTopic.looseTooth && !merged.childContext) {
      return DentalTurnResult(
        handled: true,
        message: _responses.looseAdult(),
        session: merged,
      );
    }

    if (merged.topic == DentalTopic.oralHygiene ||
        RegExp(r'(?:احافظ|فرشاه|فلورايد)').hasMatch(
          ArabicTextUtils.normalize(text),
        )) {
      return DentalTurnResult(
        handled: true,
        message: _responses.prevention(),
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'dental_prevention_hygiene_fluoride',
          ],
        ),
      );
    }

    if (merged.diabetesContext) {
      final pain = _catalog.findById('dental_ada_pain_definitive_care');
      return DentalTurnResult(
        handled: true,
        message:
            '${_responses.diabetesContext()} ${pain?.arabicGuidance ?? ''}',
        session: merged,
      );
    }

    final q = _questions.nextQuestion(merged, interp);
    if (q != null &&
        merged.topic == DentalTopic.toothPain &&
        merged.swelling == DentalSwellingClass.unknown) {
      return _ask(merged, q, prefix: _responses.acknowledge(merged));
    }

    final rule = _catalog.bestFor(merged) ??
        _catalog.findById('dental_ada_pain_definitive_care');
    final guidance = rule?.arabicGuidance ?? '';
    return DentalTurnResult(
      handled: true,
      message: _responses.toothPain(merged, guidance),
      session: merged.copyWith(
        lastGuidance: guidance,
        matchedRuleIds: [
          ...merged.matchedRuleIds,
          if (rule != null) rule.ruleId,
        ],
      ),
    );
  }

  DentalTurnResult _ask(
    DentalSession session,
    String key, {
    String prefix = '',
  }) {
    final asked = [...session.askedQuestionKeys, key];
    final prompt = _questions.promptFor(key);
    final msg = prefix.isEmpty ? prompt : '$prefix $prompt';
    return DentalTurnResult(
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

  DentalSession _merge(DentalSession session, DentalInterpretation interp) {
    var swelling = session.swelling;
    if (interp.negatesSwelling) {
      // نفي التورم العام، مع السماح بإثبات بديل في نفس الدورة (مثلاً لثة بدل الوجه)
      if (interp.swelling == DentalSwellingClass.gum ||
          interp.swelling == DentalSwellingClass.localizedIntraoral) {
        swelling = interp.swelling;
      } else {
        swelling = DentalSwellingClass.none;
      }
    } else if (interp.swelling != DentalSwellingClass.unknown) {
      swelling = interp.swelling;
    }

    var trauma = session.trauma;
    if (interp.negatesTrauma) {
      trauma = DentalTraumaKind.none;
    } else if (interp.trauma != DentalTraumaKind.none) {
      trauma = interp.trauma;
    }

    var toothType = session.toothType;
    if (interp.correctionToothType ||
        interp.toothType != DentalToothType.unknown) {
      toothType = interp.toothType;
    }

    final triggers = interp.triggers.isNotEmpty
        ? interp.triggers
        : session.triggers;

    return session.copyWith(
      active: true,
      topic: interp.topic != DentalTopic.unknown ? interp.topic : session.topic,
      severity: interp.severity != ClinicalSeverityClass.unknown
          ? interp.severity
          : session.severity,
      triggers: triggers,
      swelling: swelling,
      trauma: trauma,
      toothType: toothType,
      isOtherPerson: interp.isAboutOtherPerson ? true : session.isOtherPerson,
      otherPersonLabel: interp.otherPersonLabel.isNotEmpty
          ? interp.otherPersonLabel
          : session.otherPersonLabel,
      pregnancyContext:
          interp.pregnancyContextHint || session.pregnancyContext,
      diabetesContext: interp.diabetesContextHint || session.diabetesContext,
      childContext: interp.childContextHint || session.childContext,
      userReportedAbscess:
          interp.userReportedAbscess || session.userReportedAbscess,
      difficultyOpeningMouth:
          interp.difficultyOpeningMouth || session.difficultyOpeningMouth,
      redFlagCandidate: interp.negatesSwelling
          ? interp.redFlagCandidate
          : (interp.redFlagCandidate || session.redFlagCandidate),
    );
  }

  bool createsDentalHistoryStore() => false;
  bool createsDentalEmergencyEngine() => false;
  bool createsDentalAntibioticEngine() => false;
  bool autonomouslyPrescribesAntibiotics() => false;
  bool autonomouslySelectsProcedures() => false;
  bool commercialImagingBias() => _imaging.commercialCanAlterIndication();
  bool confusesPrimaryWithPermanent() => false;
}
