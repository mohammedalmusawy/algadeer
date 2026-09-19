import '../../clinical_care_direction_request.dart';
import '../../clinical_knowledge_models.dart';
import 'chronic_care_destination_policy.dart';
import 'chronic_care_due_policy.dart';
import 'chronic_care_interpreter.dart';
import 'chronic_care_models.dart';
import 'chronic_care_query_adapter.dart';
import 'chronic_care_question_planner.dart';
import 'chronic_care_response_builder.dart';
import 'chronic_care_safety_adapter.dart';
import 'diabetes_care_policy.dart';
import 'diabetes_rule_catalog.dart';
import 'hypertension_care_policy.dart';
import 'hypertension_rule_catalog.dart';

/// منسّق معرفة سريرية سكري/ضغط — PC-1.20 فوق سلطة PC-1.5.
class ChronicClinicalCoordinator {
  ChronicClinicalCoordinator({
    ChronicCareInterpreter? interpreter,
    ChronicCareQuestionPlanner? questions,
    ChronicCareSafetyAdapter? safety,
    DiabetesRuleCatalog? diabetesRules,
    HypertensionRuleCatalog? hypertensionRules,
    ChronicCareDuePolicy? duePolicy,
    ChronicCarePlanAssembler? assembler,
    ChronicCareDestinationPolicy? destinations,
    ChronicCareResponseBuilder? responses,
    DiabetesCarePolicy? diabetesPolicy,
    HypertensionCarePolicy? hypertensionPolicy,
    ChronicCareQueryAdapter? queryAdapter,
  })  : _interpreter = interpreter ?? const ChronicCareInterpreter(),
        _questions = questions ?? const ChronicCareQuestionPlanner(),
        _safety = safety ?? const ChronicCareSafetyAdapter(),
        _diabetesRules = diabetesRules ?? DiabetesRuleCatalog(),
        _htnRules = hypertensionRules ?? HypertensionRuleCatalog(),
        _due = duePolicy ?? ChronicCareDuePolicy(),
        _assembler = assembler ?? const ChronicCarePlanAssembler(),
        _destinations = destinations ?? const ChronicCareDestinationPolicy(),
        _responses = responses ?? const ChronicCareResponseBuilder(),
        _dmPolicy = diabetesPolicy ?? DiabetesCarePolicy(),
        _htnPolicy = hypertensionPolicy ?? HypertensionCarePolicy(),
        _query = queryAdapter ?? ChronicCareQueryAdapter();

  final ChronicCareInterpreter _interpreter;
  final ChronicCareQuestionPlanner _questions;
  final ChronicCareSafetyAdapter _safety;
  final DiabetesRuleCatalog _diabetesRules;
  final HypertensionRuleCatalog _htnRules;
  final ChronicCareDuePolicy _due;
  final ChronicCarePlanAssembler _assembler;
  final ChronicCareDestinationPolicy _destinations;
  final ChronicCareResponseBuilder _responses;
  final DiabetesCarePolicy _dmPolicy;
  final HypertensionCarePolicy _htnPolicy;
  final ChronicCareQueryAdapter _query;

  ChronicCareInterpreter get interpreter => _interpreter;
  DiabetesRuleCatalog get diabetesRules => _diabetesRules;
  HypertensionRuleCatalog get hypertensionRules => _htnRules;
  ChronicCareDuePolicy get duePolicy => _due;
  DiabetesCarePolicy get diabetesPolicy => _dmPolicy;
  HypertensionCarePolicy get hypertensionPolicy => _htnPolicy;
  ChronicCareSafetyAdapter get safety => _safety;
  ChronicCareQueryAdapter get queryAdapter => _query;
  /// توافق اختبارات سابقة
  ChronicCareQueryAdapter get pc15Adapter => _query;
  ChronicCarePlanAssembler get assembler => _assembler;
  ChronicCareDestinationPolicy get destinations => _destinations;

  bool mayHandle({
    required String query,
    required ChronicClinicalSession session,
  }) {
    final interp = _interpreter.interpret(query);
    if (interp.explicitFollowUp) return false;

    // لا تسرق شكاوى المجال أو أوامر غير مزمنة
    if (_looksLikeForeignDomain(query)) return false;

    if (session.active) {
      if (interp.asksServiceWhere ||
          interp.asksBooking ||
          interp.asksWhatsLeft ||
          interp.asksFullChecklist ||
          interp.asksEducation ||
          interp.asksBpTechnique ||
          interp.asksWhyCareItem ||
          ClinicalCareDirectionRequest.matches(query)) {
        return true;
      }
      if (_isCareReasoningIntent(interp)) return true;
      if (session.lastQuestionKey != null && query.trim().isNotEmpty) {
        return true;
      }
      // قياسات خام أثناء جلسة نشطة: اترك PC-1.5 إن أمكن — لا نخطف التسجيل
      if (interp.glucoseValue != null || interp.systolic != null) {
        return false;
      }
      return false;
    }

    return _isCareReasoningIntent(interp);
  }

  bool _isCareReasoningIntent(ChronicClinicalInterpretation interp) {
    if (!interp.isChronicClinicalTurn) return false;
    if (interp.asksEducation ||
        interp.asksWhatsLeft ||
        interp.asksFullChecklist ||
        interp.asksBpTechnique ||
        interp.asksWhyCareItem ||
        interp.asksServiceWhere ||
        interp.asksBooking) {
      return true;
    }
    if (interp.diabetesStatus == ChronicConditionStatus.established ||
        interp.hypertensionStatus == ChronicConditionStatus.established) {
      return true;
    }
    if (interp.diabetesStatus == ChronicConditionStatus.suspected ||
        interp.hypertensionStatus == ChronicConditionStatus.suspected) {
      return true;
    }
    if (interp.diabetesStatus == ChronicConditionStatus.familyHistoryOnly ||
        interp.hypertensionStatus == ChronicConditionStatus.familyHistoryOnly) {
      return true;
    }
    if (interp.cufflessDevice) return true;
    if (interp.diabetesType == DiabetesTypeContext.gestational) return true;
    if (interp.footWoundHint) return true;
    // قراءة واحدة: توجيه سريري فقط إن لم تكن مجرد إدخال قياس لـ PC-1.5
    // نسمح بها هنا لأن PC-1.5 يعمل أولاً في المخطّط؛ إن تركها نكمّل.
    if (interp.glucoseValue != null || interp.systolic != null) {
      return true;
    }
    return false;
  }

  bool _looksLikeForeignDomain(String raw) {
    final n = raw.toLowerCase();
    // سعال/ظهر/رقبة/ركبة — حزم المجال
    return RegExp(
      r'(?:سعال|كحه|ضيق\s*نفس|ظهري|رقبتي|ركبتي|كتفي|فخذ)',
    ).hasMatch(n);
  }

  Future<ChronicClinicalTurnResult> handle({
    required String text,
    required ChronicClinicalSession session,
  }) async {
    try {
      return await _handle(text: text, session: session);
    } catch (_) {
      return ChronicClinicalTurnResult(
        handled: false,
        message: '',
        session: session,
        success: false,
      );
    }
  }

  Future<ChronicClinicalTurnResult> _handle({
    required String text,
    required ChronicClinicalSession session,
  }) async {
    if (_safety.deferToMentalSafety(text)) {
      return ChronicClinicalTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToMentalSafety: true,
      );
    }

    final interp = _interpreter.interpret(text);

    if (interp.explicitFollowUp) {
      return ChronicClinicalTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToFollowUp: true,
      );
    }

    if (_safety.deferToMedicalSafety(interp)) {
      return ChronicClinicalTurnResult(
        handled: false,
        message: '',
        session: session.copyWith(active: true, redFlagCandidate: true),
        deferToMedicalSafety: true,
      );
    }

    if (interp.isAboutOtherPerson || interp.correctionSubject) {
      return ChronicClinicalTurnResult(
        handled: true,
        message: _responses.otherPerson(),
        session: session.copyWith(
          active: true,
          isOtherPerson: true,
          // لا نثبت تشخيص/قياس على المالك
          diabetesStatus: ChronicConditionStatus.unknown,
          hypertensionStatus: ChronicConditionStatus.unknown,
          clearBp: true,
          clearGlucose: true,
        ),
      );
    }

    if (interp.pregnancyContextHint ||
        interp.diabetesType == DiabetesTypeContext.gestational) {
      return ChronicClinicalTurnResult(
        handled: true,
        message: _responses.pregnancy(),
        session: session.copyWith(active: true, pregnancyContext: true),
      );
    }

    if (interp.selfSuspectsDiabetes || interp.selfSuspectsHypertension) {
      return ChronicClinicalTurnResult(
        handled: true,
        message: _responses.refuseSelfDx(),
        session: session.copyWith(active: true),
      );
    }

    var merged = _merge(session, interp);

    final snap = await _query.loadSnapshot();
    if (!snap.loadFailed) {
      if (snap.establishedDiabetes) {
        merged = merged.copyWith(
          diabetesStatus: ChronicConditionStatus.established,
        );
      }
      if (snap.establishedHypertension) {
        merged = merged.copyWith(
          hypertensionStatus: ChronicConditionStatus.established,
        );
      }
    }
    // عند فشل المستودع: لا ندّعي اكتمالاً/تأخراً من تاريخ غير معروف
    if (snap.loadFailed) {
      merged = merged.copyWith(
        completedCareItems: const [],
        dueCareItems: const [],
        unknownCareItems: const [],
      );
    }
    merged = merged.copyWith(conditionKind: _kindOf(merged));

    if (interp.asksBooking) {
      return ChronicClinicalTurnResult(
        handled: true,
        message: _responses.noFakeBooking(),
        session: merged,
        deferToServiceNavigation: true,
        preserveDestinationContext: true,
      );
    }

    if (interp.asksBpTechnique || interp.cufflessDevice) {
      final tech = _htnRules.findById('htn_home_measurement_technique');
      var msg =
          '${_responses.acknowledge(merged)}\n${tech?.arabicGuidance ?? ''}';
      if (interp.cufflessDevice) {
        msg = '$msg\n${_responses.cuffless()}';
      }
      return ChronicClinicalTurnResult(
        handled: true,
        message: msg.trim(),
        session: merged.copyWith(
          active: true,
          matchedRuleIds: [if (tech != null) tech.ruleId],
          cufflessWarned: interp.cufflessDevice,
        ),
      );
    }

    if (interp.asksWhyCareItem ||
        (interp.asksEducation && interp.careItemHint != null)) {
      final msg = interp.careItemHint == DiabetesCareItem.kidneyAssessment.name
          ? _responses.whyKidney()
          : _responses.education(text);
      return ChronicClinicalTurnResult(
        handled: true,
        message: msg,
        session:
            merged.copyWith(active: true, topic: ChronicClinicalTopic.education),
      );
    }

    if (interp.asksEducation) {
      return ChronicClinicalTurnResult(
        handled: true,
        message: _responses.education(text),
        session: merged.copyWith(
          active: true,
          topic: ChronicClinicalTopic.education,
          clearBp: true,
          clearGlucose: true,
          clearHba1c: true,
        ),
      );
    }

    // «وين توجهني» داخل جلسة نشطة = نفس معنى «وين اروح» القائم.
    if (interp.asksServiceWhere ||
        (session.active && ClinicalCareDirectionRequest.matches(text))) {
      return ChronicClinicalTurnResult(
        handled: true,
        message: _responses.labHandoffHonest(availableKnown: false),
        session: merged,
        deferToServiceNavigation: true,
        preserveDestinationContext: true,
      );
    }

    final qKey = _questions.nextQuestion(merged, interp);
    if (qKey != null &&
        (interp.glucoseValue != null || interp.systolic != null) &&
        !merged.hasEstablishedDiabetes &&
        !merged.hasEstablishedHypertension) {
      final prompt = _questions.promptFor(qKey);
      final body = interp.glucoseValue != null
          ? _responses.singleGlucose(
              establishedDiabetes: false,
              timingKnown: false,
            )
          : _responses.singleBp(
              establishedHtn: false,
              elevated: _due.bpReadingElevated(
                interp.systolic?.round(),
                interp.diastolic?.round(),
              ),
            );
      return ChronicClinicalTurnResult(
        handled: true,
        message: '$body\n$prompt',
        session: merged.copyWith(
          active: true,
          questionCount: merged.questionCount + 1,
          lastQuestionKey: qKey,
          askedQuestionKeys: [
            ...merged.askedQuestionKeys,
            if (!merged.askedQuestionKeys.contains(qKey)) qKey,
          ],
        ),
      );
    }

    if (interp.glucoseValue != null) {
      final msg = _responses.singleGlucose(
        establishedDiabetes: merged.hasEstablishedDiabetes,
        timingKnown: !merged.measurementContextUnknown,
      );
      final trendBan = snap.hasMultipleDiabetesMeasurements
          ? ''
          : ''; // بلا لغة اتجاه بدون قياسات متعددة من PC-1.5
      return ChronicClinicalTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)}\n$msg$trendBan',
        session: merged.copyWith(active: true),
      );
    }

    if (interp.systolic != null) {
      final elevated = _due.bpReadingElevated(
        interp.systolic?.round(),
        interp.diastolic?.round(),
      );
      final recheck = _htnRules.findById('htn_single_high_recheck');
      final msg = _responses.singleBp(
        establishedHtn: merged.hasEstablishedHypertension,
        elevated: elevated,
      );
      final extra =
          elevated && recheck != null ? '\n${recheck.arabicGuidance}' : '';
      return ChronicClinicalTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)}\n$msg$extra',
        session: merged.copyWith(
          active: true,
          matchedRuleIds: [if (recheck != null) recheck.ruleId],
        ),
      );
    }

    if (interp.asksWhatsLeft ||
        interp.asksFullChecklist ||
        merged.hasEstablishedDiabetes ||
        merged.hasEstablishedHypertension) {
      // بدون تاريخ مستودع: كل غير المكتمل يبقى unknown
      if (snap.loadFailed) {
        merged = merged.copyWith(
          unknownCareItems: [
            if (merged.hasEstablishedDiabetes) ...[
              DiabetesCareItem.glycemicAssessment.name,
              DiabetesCareItem.kidneyAssessment.name,
              DiabetesCareItem.eyeAssessment.name,
            ],
          ],
        );
      }

      final priorities = _assembler.assemble(
        session: merged,
        diabetesRules: _diabetesRules,
        htnRules: _htnRules,
        fullChecklist: interp.asksFullChecklist ||
            interp.topic == ChronicClinicalTopic.careChecklist,
        footWound: interp.footWoundHint,
      );
      final sanitized = priorities.map((p) {
        if (p.status == CareItemStatus.overdue) {
          return AssembledCarePriority(
            id: p.id,
            status: CareItemStatus.unknown,
            arabicLabel: p.arabicLabel,
            reasonCode: 'unknownNotOverdue',
            matchedRuleId: p.matchedRuleId,
          );
        }
        return p;
      }).toList();

      var msg =
          '${_responses.acknowledge(merged)}\n${_responses.buildPriorities(sanitized)}';
      if (merged.hasEstablishedDiabetes || merged.hasEstablishedHypertension) {
        msg = '$msg\n${_responses.noChestXray()}';
      }
      if (snap.loadFailed) {
        msg =
            '$msg\nما عندي سجل متابعة موثوق حالياً — ما أدّعي فحوص مكتملة أو متأخرة.';
      }
      msg =
          '$msg\nهذا توجيه رعاية عام — مو تشخيص جديد ولا تغيير دواء. ناقش التفاصيل مع طبيبك.';

      if (_responses.containsForbidden(msg)) {
        msg = '${_responses.acknowledge(merged)}\nتوجيه حذر — راجع طبيبك.';
      }

      final dest = sanitized.isEmpty
          ? ClinicalCareDestination.generalPractitioner
          : _destinations.forCareItem(sanitized.first.id);

      return ChronicClinicalTurnResult(
        handled: true,
        message: msg,
        session: merged.copyWith(
          active: true,
          assembledPriorities: sanitized,
          matchedRuleIds: sanitized
              .map((e) => e.matchedRuleId)
              .whereType<String>()
              .toList(),
          destinationType: dest,
          dueCareItems: sanitized
              .where((e) => e.status == CareItemStatus.due)
              .map((e) => e.id)
              .toList(),
          clearLastQuestion: true,
        ),
      );
    }

    if (!interp.isChronicClinicalTurn && !session.active) {
      return ChronicClinicalTurnResult.notHandled(session);
    }

    return ChronicClinicalTurnResult(
      handled: true,
      message:
          '${_responses.acknowledge(merged)}\n'
          'أكدر أساعد بمتابعة رعاية مبنية على الأدلة عند توفر سياق مشخص.',
      session: merged.copyWith(active: true),
    );
  }

  ChronicConditionKind _kindOf(ChronicClinicalSession s) {
    if (s.hasEstablishedDiabetes && s.hasEstablishedHypertension) {
      return ChronicConditionKind.both;
    }
    if (s.hasEstablishedDiabetes ||
        s.diabetesStatus != ChronicConditionStatus.unknown) {
      return ChronicConditionKind.diabetes;
    }
    if (s.hasEstablishedHypertension ||
        s.hypertensionStatus != ChronicConditionStatus.unknown) {
      return ChronicConditionKind.hypertension;
    }
    return ChronicConditionKind.none;
  }

  ChronicConditionStatus _prefer(
    ChronicConditionStatus cur,
    ChronicConditionStatus next,
  ) {
    if (next == ChronicConditionStatus.unknown) return cur;
    if (cur == ChronicConditionStatus.established) return cur;
    return next;
  }

  ChronicClinicalSession _merge(
    ChronicClinicalSession session,
    ChronicClinicalInterpretation interp,
  ) {
    final dm = _prefer(session.diabetesStatus, interp.diabetesStatus);
    final htn =
        _prefer(session.hypertensionStatus, interp.hypertensionStatus);

    var dmType = session.diabetesType;
    if (interp.correctionDiabetesType ||
        interp.diabetesType != DiabetesTypeContext.unknown) {
      dmType = interp.diabetesType;
    }

    final completed = <String>{
      ...session.completedCareItems,
      if (interp.careCompletedHint != null) interp.careCompletedHint!,
    }.toList();

    final unknown = <String>{
      ...session.unknownCareItems,
      if (interp.asksWhatsLeft &&
          !completed.contains(DiabetesCareItem.kidneyAssessment.name) &&
          interp.careCompletedHint != DiabetesCareItem.kidneyAssessment.name)
        DiabetesCareItem.kidneyAssessment.name,
    }.toList();

    return session.copyWith(
      active: true,
      topic: interp.topic != ChronicClinicalTopic.unknown
          ? interp.topic
          : session.topic,
      diabetesStatus: dm,
      hypertensionStatus: htn,
      diabetesType: dmType,
      lastSystolic: interp.systolic ?? session.lastSystolic,
      lastDiastolic: interp.diastolic ?? session.lastDiastolic,
      lastGlucose: interp.glucoseValue ?? session.lastGlucose,
      lastHba1c: interp.hba1cValue ?? session.lastHba1c,
      measurementContextUnknown: (!interp.isFasting && !interp.isPostMeal)
          ? session.measurementContextUnknown
          : false,
      isFasting: interp.isFasting || session.isFasting,
      isPostMeal: interp.isPostMeal || session.isPostMeal,
      unitLabel:
          interp.unitLabel.isNotEmpty ? interp.unitLabel : session.unitLabel,
      completedCareItems: completed,
      unknownCareItems: unknown,
      pregnancyContext: interp.pregnancyContextHint || session.pregnancyContext,
      redFlagCandidate: interp.redFlagCandidate || session.redFlagCandidate,
    );
  }
}
