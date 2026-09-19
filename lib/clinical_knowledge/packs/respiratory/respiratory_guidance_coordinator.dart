import '../../../nlu/nlu_models.dart';
import '../../../nlu/respiratory_nlu_overlay.dart';
import '../../clinical_care_direction_request.dart';
import '../../clinical_knowledge_models.dart';
import 'respiratory_imaging_policy.dart';
import 'respiratory_interpreter.dart';
import 'respiratory_models.dart';
import 'respiratory_question_planner.dart';
import 'respiratory_response_builder.dart';
import 'respiratory_rule_catalog.dart';
import 'respiratory_safety_adapter.dart';

/// منسّق حزمة الجهاز التنفسي — PC-1.19.
class RespiratoryGuidanceCoordinator {
  RespiratoryGuidanceCoordinator({
    RespiratoryInterpreter? interpreter,
    RespiratoryQuestionPlanner? questions,
    RespiratorySafetyAdapter? safety,
    RespiratoryRuleCatalog? catalog,
    RespiratoryImagingPolicy? imaging,
    RespiratoryResponseBuilder? responses,
  })  : _interpreter = interpreter ?? const RespiratoryInterpreter(),
        _questions = questions ?? const RespiratoryQuestionPlanner(),
        _safety = safety ?? const RespiratorySafetyAdapter(),
        _catalog = catalog ?? RespiratoryRuleCatalog(),
        _imaging = imaging ?? const RespiratoryImagingPolicy(),
        _responses = responses ?? const RespiratoryResponseBuilder();

  final RespiratoryInterpreter _interpreter;
  final RespiratoryQuestionPlanner _questions;
  final RespiratorySafetyAdapter _safety;
  final RespiratoryRuleCatalog _catalog;
  final RespiratoryImagingPolicy _imaging;
  final RespiratoryResponseBuilder _responses;

  RespiratoryInterpreter get interpreter => _interpreter;
  RespiratoryRuleCatalog get catalog => _catalog;
  RespiratoryImagingPolicy get imagingPolicy => _imaging;
  RespiratorySafetyAdapter get safety => _safety;
  RespiratoryQuestionPlanner get questions => _questions;

  bool mayHandle({
    required String query,
    required RespiratorySession session,
  }) {
    final interp = _interpreter.interpret(query);
    if (interp.explicitFollowUp) return false;
    if (session.active) {
      if (interp.asksServiceWhere ||
          interp.asksBooking ||
          interp.asksImagingWhere ||
          interp.asksDirectChestXray ||
          ClinicalCareDirectionRequest.matches(query)) {
        return true;
      }
      if (interp.isRespiratoryTurn) return true;
      if (session.lastQuestionKey != null && query.trim().isNotEmpty) {
        return true;
      }
      // عمر قصير يكمّل جلسة طفل/سعال نشطة قبل أي حزمة أخرى.
      if (_interpreter.looksLikeAgeReply(query)) return true;
      // إجابات/تصحيحات جلسة بدون إعادة ذكر السعال
      if (interp.durationBucket != RespiratoryDurationBucket.unknown ||
          interp.correctionDuration ||
          interp.correctionCoughType ||
          interp.sputum != RespiratoryTriState.unknown ||
          interp.breathlessness != RespiratoryTriState.unknown ||
          interp.hemoptysis != RespiratoryTriState.unknown ||
          interp.fever != RespiratoryTriState.unknown ||
          _interpreter.shortAnswerPolarity(query) != null) {
        return true;
      }
      return false;
    }
    return interp.isRespiratoryTurn;
  }

  Future<RespiratoryTurnResult> handle({
    required String text,
    required RespiratorySession session,
    NluParse? nluParse,
  }) async {
    try {
      return _handle(text: text, session: session, nluParse: nluParse);
    } catch (_) {
      return RespiratoryTurnResult(
        handled: false,
        message: '',
        session: session,
        success: false,
      );
    }
  }

  RespiratoryTurnResult _handle({
    required String text,
    required RespiratorySession session,
    NluParse? nluParse,
  }) {
    if (_safety.deferToMentalSafety(text)) {
      return RespiratoryTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToMentalSafety: true,
      );
    }

    var interp = _interpreter.interpret(text);

    if (interp.explicitFollowUp) {
      return RespiratoryTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToFollowUp: true,
      );
    }

    // إجابات قصيرة على سؤال معلق
    interp = _applyPendingAnswer(session, interp, text);

    // Overlay لغوي اختياري — يملأ الخانات المجهولة فقط.
    if (nluParse != null) {
      interp = const RespiratoryNluOverlay()
          .apply(interp: interp, session: session, parse: nluParse)
          .interp;
    }

    if (_safety.deferToMedicalSafety(interp)) {
      return RespiratoryTurnResult(
        handled: false,
        message: '',
        session: session.copyWith(
          active: true,
          redFlagCandidate: true,
          hemoptysis: interp.hemoptysis != RespiratoryTriState.unknown
              ? interp.hemoptysis
              : session.hemoptysis,
        ),
        deferToMedicalSafety: true,
      );
    }

    // دمج الأعراض أولاً — حتى مسار الطفل يحتفظ بالسعال/المدة.
    var mergedEarly = _merge(session, interp);
    if (_interpreter.looksLikeAgeReply(text) ||
        interp.population == RespiratoryPopulation.child ||
        session.population == RespiratoryPopulation.child) {
      mergedEarly = mergedEarly.copyWith(
        active: true,
        population: RespiratoryPopulation.child,
        symptomKeys: [
          ...mergedEarly.symptomKeys,
          if (_interpreter.looksLikeAgeReply(text) &&
              !mergedEarly.symptomKeys.contains('childAgeKnown'))
            'childAgeKnown',
        ],
      );
    }

    if (interp.population == RespiratoryPopulation.child ||
        session.population == RespiratoryPopulation.child ||
        mergedEarly.population == RespiratoryPopulation.child) {
      return _handleChildCompanion(text: text, session: mergedEarly, interp: interp);
    }

    if (interp.isAboutOtherPerson) {
      return RespiratoryTurnResult(
        handled: true,
        message: _responses.otherPersonSafe(),
        session: mergedEarly.copyWith(active: true),
      );
    }

    if (interp.pregnancyContextHint) {
      return RespiratoryTurnResult(
        handled: true,
        message: _responses.pregnancyConservative(),
        session: mergedEarly.copyWith(active: true, pregnancyContext: true),
      );
    }

    if (interp.selfSuspectsInfection) {
      return RespiratoryTurnResult(
        handled: true,
        message: _responses.refuseSelfDiagnosis(),
        session: session.copyWith(active: true),
      );
    }

    if (interp.asksEducation) {
      return RespiratoryTurnResult(
        handled: true,
        message: _responses.education(text),
        session: session.copyWith(
          active: true,
          topic: RespiratoryTopic.educationQuery,
          // لا نحوّل التعليم إلى أعراض
        ),
      );
    }

    var merged = _merge(session, interp);

    if (interp.asksBooking) {
      return RespiratoryTurnResult(
        handled: true,
        message: _responses.noFakeBooking(),
        session: merged,
        deferToServiceNavigation: true,
        preserveDestinationContext: true,
      );
    }

    // «وين توجهني» داخل جلسة نشطة = نفس معنى «وين اروح» القائم.
    final asksCareDirection = interp.asksServiceWhere ||
        (session.active && ClinicalCareDirectionRequest.matches(text));

    if (asksCareDirection || interp.asksImagingWhere) {
      final eligible = _imagingEligible(merged);
      if (interp.asksImagingWhere && !eligible) {
        return RespiratoryTurnResult(
          handled: true,
          message:
              'ما ثبت بعد إن صورة الصدر مناسبة لهذا السياق. '
              'خلينا نكمّل التوضيح السريري أولاً.',
          session: merged,
        );
      }
      return RespiratoryTurnResult(
        handled: true,
        message: interp.asksImagingWhere
            ? 'بما إن التصوير قد يكون مناسباً حسب السياق، '
                'أكدر أدليك على خدمة أشعة الصدر المتوفرة بالغدير.'
            : 'حسب الوجهة المناسبة: ${merged.destinationType?.arabicLabel ?? 'تقييم سريري عام'}. '
                'أكدر أحولك لمسار اكتشاف الخدمة الحقيقي بالغدير.',
        session: merged,
        deferToServiceNavigation: true,
        preserveDestinationContext: true,
      );
    }

    if (interp.asksDirectChestXray) {
      final rule = _imaging.selectRule(
        session: merged,
        activeRules: _catalog.active,
      );
      final eligible = rule?.imaging?.allowsServiceHandoff == true &&
          (rule!.imaging!.appropriateness ==
                  ClinicalImagingAppropriateness.usuallyAppropriate ||
              rule.imaging!.appropriateness ==
                  ClinicalImagingAppropriateness.mayBeAppropriate);
      if (!eligible) {
        final q = _questions.promptFor('clarifyImaging');
        return RespiratoryTurnResult(
          handled: true,
          message:
              '${_responses.directXrayHonest(merged, eligible: false)}\n$q',
          session: merged.copyWith(
            active: true,
            questionCount: merged.questionCount + 1,
            lastQuestionKey: 'clarifyImaging',
            askedQuestionKeys: [
              ...merged.askedQuestionKeys,
              if (!merged.askedQuestionKeys.contains('clarifyImaging'))
                'clarifyImaging',
            ],
          ),
        );
      }
    }

    if (!interp.isRespiratoryTurn &&
        !session.active &&
        session.lastQuestionKey == null) {
      return RespiratoryTurnResult.notHandled(session);
    }

    final rule = _imaging.selectRule(
      session: merged,
      activeRules: _catalog.active,
    );

    final qKey = _questions.nextQuestion(merged, interp);
    final enoughForGuidance = merged.durationBucket !=
            RespiratoryDurationBucket.unknown ||
        merged.knownCondition != RespiratoryKnownCondition.none ||
        merged.recurrentInfection ||
        merged.questionCount >= 1 ||
        merged.hemoptysis == RespiratoryTriState.present;

    if (qKey != null && !enoughForGuidance) {
      final prompt = _questions.promptFor(qKey);
      final msg = '${_responses.acknowledge(merged)}\n$prompt';
      final asked = [
        ...merged.askedQuestionKeys,
        if (!merged.askedQuestionKeys.contains(qKey)) qKey,
      ];
      return RespiratoryTurnResult(
        handled: true,
        message: msg,
        session: merged.copyWith(
          active: true,
          questionCount: merged.questionCount + 1,
          lastQuestionKey: qKey,
          askedQuestionKeys: asked,
          lastGuidance: msg,
        ),
      );
    }

    // بعد مدة معروفة — سؤال مرافق عالي القيمة مرة واحدة قبل التوجيه الكامل عند الإمكان
    if (qKey != null &&
        qKey == 'associatedRed' &&
        merged.durationBucket != RespiratoryDurationBucket.unknown &&
        merged.questionCount < 3 &&
        !merged.askedQuestionKeys.contains('associatedRed')) {
      final prompt = _questions.promptFor(qKey);
      final msg =
          '${_responses.acknowledge(merged)}\n$prompt';
      return RespiratoryTurnResult(
        handled: true,
        message: msg,
        session: merged.copyWith(
          active: true,
          questionCount: merged.questionCount + 1,
          lastQuestionKey: qKey,
          askedQuestionKeys: [...merged.askedQuestionKeys, qKey],
          lastGuidance: msg,
        ),
      );
    }

    if (rule == null) {
      return RespiratoryTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)}\n'
            'ما عندي قاعدة تنفسية مراجَعة جاهزة لهذا التفصيل حالياً — '
            'ما أخترع توجيهاً. الأنسب مراجعة سريرية إن استمر السعال أو تدهور.',
        session: merged.copyWith(active: true),
      );
    }

    var msg = _responses.buildGuidance(rule: rule, session: merged);
    if (_responses.containsForbidden(msg)) {
      msg =
          '${_responses.acknowledge(merged)}\nتوجيه عام حذر — راجع مختص إن لزم.';
    }

    final imaging = rule.imaging;
    return RespiratoryTurnResult(
      handled: true,
      message: msg,
      session: merged.copyWith(
        active: true,
        lastRuleId: rule.ruleId,
        imagingAppropriateness: imaging?.appropriateness,
        imagingModality: imaging?.modality,
        imagingReasonCode: imaging?.reasonCode,
        investigationType: rule.investigationType,
        destinationType: rule.destinations.isEmpty
            ? null
            : rule.destinations.first.destination,
        pendingDestination: rule.destinations.isEmpty
            ? null
            : rule.destinations.first.destination,
        lastGuidance: msg,
        clearLastQuestion: true,
      ),
      preserveDestinationContext: true,
    );
  }

  bool _imagingEligible(RespiratorySession s) =>
      s.imagingAppropriateness ==
          ClinicalImagingAppropriateness.usuallyAppropriate ||
      s.imagingAppropriateness ==
          ClinicalImagingAppropriateness.mayBeAppropriate;

  /// مسار طفل طبيعي: دمج الشكوى + سؤال واحد مفيد — بلا لغة حزم داخلية.
  RespiratoryTurnResult _handleChildCompanion({
    required String text,
    required RespiratorySession session,
    required RespiratoryInterpretation interp,
  }) {
    var merged = session;
    if (_interpreter.looksLikeAgeReply(text) &&
        !merged.symptomKeys.contains('childAgeKnown')) {
      merged = merged.copyWith(
        symptomKeys: [...merged.symptomKeys, 'childAgeKnown'],
        askedQuestionKeys: [
          ...merged.askedQuestionKeys,
          if (!merged.askedQuestionKeys.contains('childAge')) 'childAge',
        ],
        clearLastQuestion: merged.lastQuestionKey == 'childAge',
      );
    }

    // نفي/إثبات قصير على سؤال مرافق الأطفال.
    if (merged.lastQuestionKey == 'childAssociated') {
      final polarity = _interpreter.shortAnswerPolarity(text);
      if (polarity != null) {
        merged = merged.copyWith(
          fever: polarity == RespiratoryTriState.absent
              ? (merged.fever == RespiratoryTriState.unknown
                  ? RespiratoryTriState.absent
                  : merged.fever)
              : merged.fever,
          breathlessness: polarity,
          clearLastQuestion: true,
        );
      }
      if (interp.fever != RespiratoryTriState.unknown) {
        merged = merged.copyWith(fever: interp.fever);
      }
      if (interp.breathlessness != RespiratoryTriState.unknown) {
        merged = merged.copyWith(breathlessness: interp.breathlessness);
      }
    }

    final qKey = _questions.nextQuestion(merged, interp);
    if (qKey != null) {
      final prompt = _questions.promptFor(qKey);
      final msg = _responses.childCompanionAck(
        session: merged,
        question: prompt,
      );
      return RespiratoryTurnResult(
        handled: true,
        message: msg,
        session: merged.copyWith(
          active: true,
          population: RespiratoryPopulation.child,
          questionCount: merged.questionCount + 1,
          lastQuestionKey: qKey,
          askedQuestionKeys: [
            ...merged.askedQuestionKeys,
            if (!merged.askedQuestionKeys.contains(qKey)) qKey,
          ],
          lastGuidance: msg,
        ),
      );
    }

    final wrap = _responses.childCompanionAck(
      session: merged,
      question:
          'إذا استمر السعال أو ظهرت حرارة عالية أو ضيق نفس، الأفضل مراجعة سريرية مناسبة للعمر. '
          'هذا توجيه عام — مو تشخيص.',
    );
    return RespiratoryTurnResult(
      handled: true,
      message: wrap,
      session: merged.copyWith(
        active: true,
        population: RespiratoryPopulation.child,
        lastGuidance: wrap,
        clearLastQuestion: true,
      ),
    );
  }

  RespiratoryInterpretation _applyPendingAnswer(
    RespiratorySession session,
    RespiratoryInterpretation interp,
    String text,
  ) {
    final key = session.lastQuestionKey;
    if (key == null) return interp;

    final polarity = _interpreter.shortAnswerPolarity(text);
    if (key == 'associatedRed' || key == 'hemoptysis') {
      if (polarity == RespiratoryTriState.absent) {
        return RespiratoryInterpretation(
          isRespiratoryTurn: true,
          topic: interp.topic != RespiratoryTopic.unknownRespiratory
              ? interp.topic
              : session.topic,
          durationBucket: interp.durationBucket,
          coughType: interp.coughType,
          sputum: interp.sputum != RespiratoryTriState.unknown
              ? interp.sputum
              : session.sputum,
          breathlessness: key == 'associatedRed'
              ? RespiratoryTriState.absent
              : interp.breathlessness,
          wheeze: interp.wheeze,
          chestPain: interp.chestPain,
          fever: interp.fever,
          hemoptysis: RespiratoryTriState.absent,
          weightLoss: interp.weightLoss,
          functionalImpact: interp.functionalImpact,
          knownCondition: interp.knownCondition,
          smoking: interp.smoking,
          recurrentInfection: interp.recurrentInfection,
          recentRespiratoryIllness: interp.recentRespiratoryIllness,
          symptomKeys: interp.symptomKeys,
        );
      }
    }
    if (key == 'duration' &&
        interp.durationBucket == RespiratoryDurationBucket.unknown) {
      // احتفظ بالمدة من النص إن وُجدت؛ وإلا أبقِ الجلسة
    }
    return interp;
  }

  RespiratorySession _merge(
    RespiratorySession session,
    RespiratoryInterpretation interp,
  ) {
    final keys = {
      ...session.symptomKeys,
      ...interp.symptomKeys,
    }.toList();

    var coughType = session.coughType;
    if (interp.correctionCoughType ||
        interp.coughType != RespiratoryCoughType.unknown) {
      coughType = interp.coughType;
    }
    if (interp.sputum == RespiratoryTriState.present &&
        coughType == RespiratoryCoughType.unknown) {
      coughType = RespiratoryCoughType.productive;
    }
    if (interp.sputum == RespiratoryTriState.absent &&
        coughType == RespiratoryCoughType.productive &&
        interp.correctionCoughType) {
      coughType = RespiratoryCoughType.dry;
    }
    if (interp.coughType == RespiratoryCoughType.dry) {
      coughType = RespiratoryCoughType.dry;
    }

    var durationBucket = session.durationBucket;
    if (interp.durationBucket != RespiratoryDurationBucket.unknown) {
      durationBucket = interp.durationBucket;
    }

    RespiratoryTriState mergeTri(
      RespiratoryTriState cur,
      RespiratoryTriState next,
    ) {
      if (next != RespiratoryTriState.unknown) return next;
      return cur;
    }

    var topic = session.topic;
    if (interp.topic != RespiratoryTopic.unknownRespiratory &&
        interp.topic != RespiratoryTopic.serviceNavigation &&
        interp.topic != RespiratoryTopic.educationQuery) {
      topic = interp.topic;
    }
    // ترقية الموضوع حسب المدة من الكتالوج
    final durationClass = _catalog.classifyDuration(durationBucket);
    if (keys.contains('cough') || session.hasCoughContext) {
      if (durationClass == ClinicalCoughDurationClass.chronic) {
        topic = RespiratoryTopic.chronicCough;
      } else if (durationClass == ClinicalCoughDurationClass.subacute &&
          topic != RespiratoryTopic.chronicCough) {
        topic = RespiratoryTopic.persistentCough;
      } else if (durationClass == ClinicalCoughDurationClass.acute &&
          topic == RespiratoryTopic.unknownRespiratory) {
        topic = RespiratoryTopic.acuteCough;
      }
    }

    return session.copyWith(
      active: true,
      topic: topic,
      durationBucket: durationBucket,
      durationClass: durationClass,
      coughType: coughType,
      sputum: mergeTri(session.sputum, interp.sputum),
      breathlessness: mergeTri(session.breathlessness, interp.breathlessness),
      wheeze: mergeTri(session.wheeze, interp.wheeze),
      chestPain: mergeTri(session.chestPain, interp.chestPain),
      fever: mergeTri(session.fever, interp.fever),
      hemoptysis: mergeTri(session.hemoptysis, interp.hemoptysis),
      weightLoss: mergeTri(session.weightLoss, interp.weightLoss),
      functionalImpact:
          interp.functionalImpact != RespiratoryFunctionalImpact.unknown
              ? interp.functionalImpact
              : session.functionalImpact,
      knownCondition: interp.knownCondition != RespiratoryKnownCondition.none
          ? interp.knownCondition
          : session.knownCondition,
      smoking: interp.smoking != RespiratorySmokingState.unknown
          ? interp.smoking
          : session.smoking,
      recurrentInfection:
          interp.recurrentInfection || session.recurrentInfection,
      recentRespiratoryIllness:
          interp.recentRespiratoryIllness || session.recentRespiratoryIllness,
      redFlagCandidate: interp.redFlagCandidate || session.redFlagCandidate,
      population: interp.population != RespiratoryPopulation.unknown
          ? interp.population
          : session.population,
      pregnancyContext: interp.pregnancyContextHint || session.pregnancyContext,
      symptomKeys: keys,
    );
  }
}
