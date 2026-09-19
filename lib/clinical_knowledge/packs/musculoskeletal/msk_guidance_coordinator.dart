import '../../clinical_care_direction_request.dart';
import '../../clinical_knowledge_models.dart';
import '../../../search/arabic_text_utils.dart';
import 'msk_imaging_policy.dart';
import 'msk_interpreter.dart';
import 'msk_models.dart';
import 'msk_question_planner.dart';
import 'msk_response_builder.dart';
import 'msk_rule_catalog.dart';
import 'msk_safety_adapter.dart';

/// منسّق حزمة MSK — PC-1.18.
class MskGuidanceCoordinator {
  MskGuidanceCoordinator({
    MskInterpreter? interpreter,
    MskQuestionPlanner? questions,
    MskSafetyAdapter? safety,
    MskRuleCatalog? catalog,
    MskImagingPolicy? imaging,
    MskResponseBuilder? responses,
  })  : _interpreter = interpreter ?? const MskInterpreter(),
        _questions = questions ?? const MskQuestionPlanner(),
        _safety = safety ?? const MskSafetyAdapter(),
        _catalog = catalog ?? MskRuleCatalog(),
        _imaging = imaging ?? const MskImagingPolicy(),
        _responses = responses ?? const MskResponseBuilder();

  final MskInterpreter _interpreter;
  final MskQuestionPlanner _questions;
  final MskSafetyAdapter _safety;
  final MskRuleCatalog _catalog;
  final MskImagingPolicy _imaging;
  final MskResponseBuilder _responses;

  MskInterpreter get interpreter => _interpreter;
  MskRuleCatalog get catalog => _catalog;
  MskImagingPolicy get imagingPolicy => _imaging;
  MskSafetyAdapter get safety => _safety;

  bool mayHandle({required String query, required MskSession session}) {
    final interp = _interpreter.interpret(query);
    if (interp.explicitFollowUp) return false;
    // جلسة نشطة: أكمل فقط إن كان الجواب/التنقل/MSK — لا تسرق إلغاء/مختبر/إساءة.
    if (session.active) {
      if (interp.asksServiceWhere ||
          interp.asksBooking ||
          interp.asksImagingWhere ||
          ClinicalCareDirectionRequest.matches(query)) {
        return true;
      }
      // جلسة MSK نشطة + ذكر أشعة/تصوير → لا تفقد للبحث العام الفارغ.
      final nImg = ArabicTextUtils.normalize(query.trim());
      if (RegExp(r'(?:اشعه|أشعة|تصوير)').hasMatch(nImg)) {
        return true;
      }
      if (interp.isMskTurn) return true;
      // إجابات شدة/نفي شائعة أثناء جلسة MSK نشطة بلا إعادة ذكر المنطقة
      if (interp.severity != ClinicalSeverityClass.unknown) return true;
      final n = ArabicTextUtils.normalize(query.trim());
      if (n.isNotEmpty &&
          RegExp(
            r'(?:ما\s*عندي\s*نزف|ماكو\s*نزف|بدون\s*نزف|الألم\s*متوسط|الالم\s*متوسط|خفيف|شديد)',
          ).hasMatch(n)) {
        return true;
      }
      // تصحيح أسبوع حمل / عمر رقمي ليس جواب MSK
      if (RegExp(r'(?:مو|لا|اسف|آسف)\s*\d{1,2}').hasMatch(n) &&
          !interp.isMskTurn) {
        return false;
      }
      if (session.lastQuestionKey != null && query.trim().isNotEmpty) {
        return true;
      }
      return false;
    }
    return interp.isMskTurn;
  }

  Future<MskTurnResult> handle({
    required String text,
    required MskSession session,
  }) async {
    try {
      return _handle(text: text, session: session);
    } catch (_) {
      return MskTurnResult(
        handled: false,
        message: '',
        session: session,
        success: false,
      );
    }
  }

  MskTurnResult _handle({
    required String text,
    required MskSession session,
  }) {
    if (_safety.deferToMentalSafety(text)) {
      return MskTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToMentalSafety: true,
      );
    }

    final interp = _interpreter.interpret(text);

    if (interp.explicitFollowUp) {
      return MskTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToFollowUp: true,
      );
    }

    if (_safety.deferToMedicalSafety(interp)) {
      return MskTurnResult(
        handled: false,
        message: '',
        session: session.copyWith(
          active: true,
          redFlagCandidate: true,
        ),
        deferToMedicalSafety: true,
      );
    }

    if (interp.isAboutOtherPerson) {
      return MskTurnResult(
        handled: true,
        message: _responses.otherPersonSafe(),
        session: session.copyWith(active: true),
      );
    }

    if (interp.pregnancyContextHint) {
      return MskTurnResult(
        handled: true,
        message: _responses.pregnancyConservative(),
        session: session.copyWith(active: true),
      );
    }

    if (interp.selfSuspectsOa) {
      return MskTurnResult(
        handled: true,
        message: _responses.refuseSelfDiagnosis(),
        session: session.copyWith(active: true),
      );
    }

    if (interp.asksEducation) {
      return MskTurnResult(
        handled: true,
        message: _responses.education(text),
        session: session.copyWith(active: true, topic: MskTopic.educationQuery),
      );
    }

    // دمج الجلسة
    var merged = _merge(session, interp);

    if (interp.asksBooking) {
      return MskTurnResult(
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
      final eligibleImaging = merged.imagingAppropriateness ==
              ClinicalImagingAppropriateness.usuallyAppropriate ||
          merged.imagingAppropriateness ==
              ClinicalImagingAppropriateness.mayBeAppropriate;
      if (interp.asksImagingWhere && !eligibleImaging) {
        return MskTurnResult(
          handled: true,
          message:
              'ما ثبت بعد إن التصوير مناسب لهذا السياق. '
              'خلينا نكمّل التوضيح السريري أولاً، وبعدها أكدر أدلّك على الخدمة إن صارت مؤهلة.',
          session: merged,
        );
      }
      return MskTurnResult(
        handled: true,
        message: interp.asksImagingWhere
            ? 'بما إن التصوير قد يكون مناسباً حسب السياق، أكدر أدليك على خدمة الأشعة المتوفرة بالغدير.'
            : 'حسب الوجهة المناسبة: ${merged.destinationType?.arabicLabel ?? 'تقييم سريري عام'}. '
                'أكدر أحولك لمسار اكتشاف الخدمة الحقيقي بالغدير.',
        session: merged,
        deferToServiceNavigation: true,
        preserveDestinationContext: true,
      );
    }

    if (!interp.isMskTurn && !session.active) {
      return MskTurnResult.notHandled(session);
    }

    final rule = _imaging.selectRule(
      session: merged,
      activeRules: _catalog.active,
    );

    // سؤال ناقص عالي القيمة قبل توجيه كامل (إلا إذا اكتمل الحد أو لدينا رضّ واضح)
    final qKey = _questions.nextQuestion(merged, interp);
    final enoughForGuidance = merged.duration != MskDurationClass.unknown ||
        merged.hasTraumaLike ||
        merged.knownDiagnosis != MskKnownDiagnosisKind.none ||
        merged.questionCount >= 1;

    if (qKey != null && !enoughForGuidance) {
      final prompt = _questions.promptFor(qKey);
      final msg =
          '${_responses.acknowledge(merged)}\n$prompt';
      return MskTurnResult(
        handled: true,
        message: msg,
        session: merged.copyWith(
          active: true,
          questionCount: merged.questionCount + 1,
          lastQuestionKey: qKey,
          lastGuidance: msg,
        ),
      );
    }

    if (rule == null) {
      return MskTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)}\n'
            'ما عندي قاعدة MSK مراجَعة جاهزة لهذا التفصيل حالياً — '
            'ما أخترع توجيهاً. الأنسب مراجعة سريرية إن استمر الألم.',
        session: merged.copyWith(active: true),
      );
    }

    String? followQ;
    if (qKey != null && merged.questionCount < 3 && enoughForGuidance) {
      // سؤال واحد إضافي اختياري بعد توجيه مختصر؟ نكتفي بالتوجيه لتقليل الاستجواب
      followQ = null;
    }

    var msg = _responses.buildGuidance(
      rule: rule,
      session: merged,
      question: followQ,
    );
    if (_responses.containsForbidden(msg)) {
      msg =
          '${_responses.acknowledge(merged)}\nتوجيه عام حذر — راجعي/راجع مختص إن لزم.';
    }

    final imaging = rule.imaging;
    return MskTurnResult(
      handled: true,
      message: msg,
      session: merged.copyWith(
        active: true,
        lastRuleId: rule.ruleId,
        imagingAppropriateness: imaging?.appropriateness,
        imagingModality: imaging?.modality,
        imagingReasonCode: imaging?.reasonCode,
        destinationType: rule.destinations.isEmpty
            ? null
            : rule.destinations.first.destination,
        pendingDestination: rule.destinations.isEmpty
            ? null
            : rule.destinations.first.destination,
        lastGuidance: msg,
        clearLastQuestion: true,
      ),
    );
  }

  MskSession _merge(MskSession session, MskInterpretation interp) {
    final symptoms = {
      ...session.symptoms,
      ...interp.symptoms,
    }.toList();
    return session.copyWith(
      active: true,
      topic: interp.topic != MskTopic.unknown ? interp.topic : session.topic,
      region:
          interp.region != MskBodyRegion.unknown ? interp.region : session.region,
      symptoms: symptoms,
      severity: interp.severity != ClinicalSeverityClass.unknown
          ? interp.severity
          : session.severity,
      functionalImpact:
          interp.functionalImpact != ClinicalFunctionalImpact.unknown
              ? interp.functionalImpact
              : session.functionalImpact,
      duration: interp.duration != MskDurationClass.unknown
          ? interp.duration
          : session.duration,
      trauma: interp.trauma != MskTraumaMechanism.noneReported
          ? interp.trauma
          : session.trauma,
      knownDiagnosis: interp.knownDiagnosis != MskKnownDiagnosisKind.none
          ? interp.knownDiagnosis
          : session.knownDiagnosis,
      redFlagCandidate: interp.redFlagCandidate || session.redFlagCandidate,
    );
  }
}

extension on MskSession {
  bool get hasTraumaLike => trauma != MskTraumaMechanism.noneReported;
}
