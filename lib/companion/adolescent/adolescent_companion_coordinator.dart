import '../../search/arabic_text_utils.dart';
import 'adolescent_evidence_catalog.dart';
import 'adolescent_interpreter.dart';
import 'adolescent_models.dart';
import 'adolescent_question_planner.dart';
import 'adolescent_response_builder.dart';
import 'adolescent_safety_adapter.dart';

/// منسّق رفيق المراهق — PC-1.23 فوق السلطات القائمة.
class AdolescentCompanionCoordinator {
  AdolescentCompanionCoordinator({
    AdolescentInterpreter? interpreter,
    AdolescentQuestionPlanner? questions,
    AdolescentSafetyAdapter? safety,
    AdolescentEvidenceCatalog? catalog,
    AdolescentResponseBuilder? responses,
  })  : _interpreter = interpreter ?? const AdolescentInterpreter(),
        _questions = questions ?? const AdolescentQuestionPlanner(),
        _safety = safety ?? const AdolescentSafetyAdapter(),
        _catalog = catalog ?? AdolescentEvidenceCatalog(),
        _responses = responses ?? const AdolescentResponseBuilder();

  final AdolescentInterpreter _interpreter;
  final AdolescentQuestionPlanner _questions;
  final AdolescentSafetyAdapter _safety;
  final AdolescentEvidenceCatalog _catalog;
  final AdolescentResponseBuilder _responses;

  AdolescentInterpreter get interpreter => _interpreter;
  AdolescentEvidenceCatalog get catalog => _catalog;
  AdolescentSafetyAdapter get safety => _safety;

  bool mayHandle({
    required String query,
    required AdolescentCompanionSession session,
  }) {
    final interp = _interpreter.interpret(query);
    if (interp.explicitFollowUp) return false;
    if (interp.medicalForeignDomain) return false;
    if (_looksLikeForeignDomain(query)) return false;
    if (_looksLikeCancelOrAbuse(query) && !interp.bullyingHint) return false;
    if (_looksLikeGenericGreeting(query)) return false;

    if (session.active) {
      if (interp.isAdolescentTurn ||
          interp.correctionSubject ||
          interp.correctionAge ||
          interp.asksPlan ||
          interp.asksEducation) {
        return true;
      }
      if (session.lastQuestionKey != null && query.trim().isNotEmpty) {
        return !_looksLikeForeignDomain(query) && !interp.medicalForeignDomain;
      }
      return false;
    }

    return interp.isAdolescentTurn;
  }

  bool _looksLikeForeignDomain(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    // عمل بالغ / بحث خدمات بلا سياق مراهق
    if (RegExp(r'(?:شغلي|دوام|مختبر|أشعة|دكتور\s+\w+)').hasMatch(n) &&
        !RegExp(r'(?:عمري|مراهق|مدرسه|امتحان)').hasMatch(n)) {
      return true;
    }
    return false;
  }

  bool _looksLikeCancelOrAbuse(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    return RegExp(r'(?:الغي|وقف|stop)').hasMatch(n);
  }

  bool _looksLikeGenericGreeting(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    return RegExp(r'^(?:مرحبا|السلام\s*عليكم|هلو|hi|hello)$').hasMatch(n);
  }

  Future<AdolescentCompanionTurnResult> handle({
    required String text,
    required AdolescentCompanionSession session,
    int? resolvedAgeYears,
  }) async {
    try {
      return _handle(
        text: text,
        session: session,
        resolvedAgeYears: resolvedAgeYears,
      );
    } catch (_) {
      return AdolescentCompanionTurnResult(
        handled: false,
        message: '',
        session: session,
        success: false,
      );
    }
  }

  AdolescentCompanionTurnResult _handle({
    required String text,
    required AdolescentCompanionSession session,
    int? resolvedAgeYears,
  }) {
    if (_safety.deferToMentalSafety(text)) {
      return AdolescentCompanionTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToMentalSafety: true,
      );
    }

    final interp = _interpreter.interpret(text);

    if (interp.explicitFollowUp) {
      return AdolescentCompanionTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToFollowUp: true,
      );
    }

    if (interp.medicalForeignDomain) {
      return AdolescentCompanionTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToClinicalPack: true,
      );
    }

    if (_safety.deferToMedicalSafety(interp)) {
      return AdolescentCompanionTurnResult(
        handled: false,
        message: '',
        session: session.copyWith(active: true),
        deferToMedicalSafety: true,
      );
    }

    if (!_catalog.active.every((r) => r.hasEvidenceMetadata)) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message:
            'ما أكدر أعتمد أرقاماً صحية للمراهقين بدون دليل مصدّق الآن. '
            'أكدر أسمعك وأقترح خطوة عامة بسيطة.',
        session: session.copyWith(active: true),
        success: false,
      );
    }

    var merged = _merge(
      session,
      interp,
      resolvedAgeYears: resolvedAgeYears,
    );

    if (interp.correctionSubject ||
        (interp.isAboutOtherPerson && !interp.parentAskingAboutTeen)) {
      merged = merged.copyWith(
        isOtherPerson: true,
        otherPersonLabel: interp.otherPersonLabel,
        clearAge: true,
        developmentState: AdolescentDevelopmentState.unknown,
      );
    }

    if (merged.developmentState == AdolescentDevelopmentState.youngerChild) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message: _responses.youngerChildBoundary(),
        session: merged,
      );
    }
    if (merged.developmentState == AdolescentDevelopmentState.adult &&
        !merged.parentAskingAboutTeen) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message: _responses.adultBoundary(),
        session: merged,
      );
    }

    if (interp.dietPillRequest ||
        interp.extremeDietHint ||
        interp.weightLossRequest) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)} ${_responses.refuseUnsafeWeightLoss()}',
        session: merged.copyWith(bodyImageContext: true),
      );
    }

    if (interp.asksPlan) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} ${_responses.planHandoff()}',
        session: merged,
        deferToPlanner: true,
      );
    }

    if (interp.asksActivity &&
        merged.topic == AdolescentTopic.physicalActivity) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} ${_responses.activity()}',
        session: merged.copyWith(
          matchedRuleIds: [...merged.matchedRuleIds, 'ado_who_activity'],
        ),
        deferToActivity: true,
      );
    }

    if (interp.asksEducation ||
        interp.topic == AdolescentTopic.educationOnly ||
        interp.topic == AdolescentTopic.generalPubertyEducation) {
      final msg = interp.pubertyEducation ||
              interp.topic == AdolescentTopic.generalPubertyEducation
          ? _responses.pubertyEducation()
          : _responses.educationWhatIsAdolescence();
      return AdolescentCompanionTurnResult(
        handled: true,
        message: msg,
        session: merged.copyWith(
          topic: AdolescentTopic.educationOnly,
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            interp.pubertyEducation
                ? 'ado_puberty_education'
                : 'ado_who_age_boundary_10_19',
          ],
        ),
      );
    }

    if (merged.parentAskingAboutTeen) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message:
            '${_responses.parentAboutTeenStudy()} ${_responses.helpSeeking()}',
        session: merged.copyWith(
          supportDestination: AdolescentSupportDestination.parentGuardianWhenSafe,
        ),
      );
    }

    if (interp.topic == AdolescentTopic.cyberbullying ||
        (interp.cyberbullyingHint && interp.bullyingHint)) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)} ${_responses.cyberbullying()}',
        session: merged.copyWith(
          bullyingContext: true,
          supportDestination: AdolescentSupportDestination.trustedAdult,
          matchedRuleIds: [...merged.matchedRuleIds, 'ado_bullying_support'],
        ),
      );
    }

    if (interp.topic == AdolescentTopic.bullying || interp.bullyingHint) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} ${_responses.bullying()} '
            '${_responses.helpSeeking()}',
        session: merged.copyWith(
          bullyingContext: true,
          supportDestination: AdolescentSupportDestination.trustedAdult,
          matchedRuleIds: [...merged.matchedRuleIds, 'ado_bullying_support'],
        ),
      );
    }

    if (interp.topic == AdolescentTopic.bodyImageConcern ||
        interp.bodyImageHint) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} ${_responses.bodyImage()}',
        session: merged.copyWith(
          bodyImageContext: true,
          matchedRuleIds: [...merged.matchedRuleIds, 'ado_body_image_safe'],
        ),
      );
    }

    if (interp.topic == AdolescentTopic.familyTension) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)} ${_responses.familyTension()}',
        session: merged,
      );
    }

    if (interp.topic == AdolescentTopic.friendship) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} ${_responses.friendship()}',
        session: merged,
      );
    }

    if (interp.topic == AdolescentTopic.peerPressure) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)} ${_responses.peerPressure()}',
        session: merged,
      );
    }

    if (interp.topic == AdolescentTopic.selfConfidence) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)} ${_responses.selfConfidence()}',
        session: merged,
      );
    }

    if (interp.topic == AdolescentTopic.sleepRoutine || interp.asksSleep) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} ${_responses.sleep()}',
        session: merged.copyWith(
          matchedRuleIds: [...merged.matchedRuleIds, 'ado_who_sleep_wellbeing'],
        ),
        deferToDailyContext: true,
      );
    }

    if (interp.topic == AdolescentTopic.examStress) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} ${_responses.examStress()} '
            '${_responses.nextStepSmall()}',
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'ado_study_stress_support',
          ],
        ),
        deferToEmotionalSupport: true,
      );
    }

    if (interp.topic == AdolescentTopic.concentrationDifficulty) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message:
            '${_responses.acknowledge(merged)} ${_responses.concentration()}',
        session: merged,
      );
    }

    if (interp.topic == AdolescentTopic.motivationDifficulty) {
      return AdolescentCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} ${_responses.motivation()}',
        session: merged,
      );
    }

    if (interp.topic == AdolescentTopic.studyDifficulty ||
        interp.topic == AdolescentTopic.timeManagement ||
        interp.asksStudyHelp) {
      final q = _questions.nextQuestion(merged, interp);
      if (q != null && !merged.isConfirmedAdolescent) {
        return _ask(merged, q, prefix: _responses.acknowledge(merged));
      }
      return AdolescentCompanionTurnResult(
        handled: true,
        message: '${_responses.acknowledge(merged)} ${_responses.studyHelp()}',
        session: merged.copyWith(
          matchedRuleIds: [
            ...merged.matchedRuleIds,
            'ado_study_stress_support',
          ],
        ),
      );
    }

    final q = _questions.nextQuestion(merged, interp);
    if (q != null) {
      return _ask(merged, q, prefix: _responses.acknowledge(merged));
    }

    return AdolescentCompanionTurnResult(
      handled: true,
      message: '${_responses.acknowledge(merged)} ${_responses.nextStepSmall()} '
          '${_responses.noAbsoluteSecrecy()}',
      session: merged.copyWith(
        matchedRuleIds: [
          ...merged.matchedRuleIds,
          'ado_who_age_boundary_10_19',
        ],
      ),
    );
  }

  AdolescentCompanionTurnResult _ask(
    AdolescentCompanionSession session,
    String key, {
    String prefix = '',
  }) {
    final asked = [...session.askedQuestionKeys, key];
    final prompt = _questions.promptFor(key);
    final msg = prefix.isEmpty ? prompt : '$prefix $prompt';
    return AdolescentCompanionTurnResult(
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

  AdolescentCompanionSession _merge(
    AdolescentCompanionSession session,
    AdolescentInterpretation interp, {
    int? resolvedAgeYears,
  }) {
    var age = session.statedAgeYears;
    var development = session.developmentState;

    // أسبقية: تصحيح/عمر صريح في الدورة > عمر موحّد من الملف > جلسة سابقة
    if (interp.correctionAge && interp.statedAgeYears != null) {
      age = interp.statedAgeYears;
    } else if (interp.statedAgeYears != null) {
      age = interp.statedAgeYears;
    } else if (resolvedAgeYears != null && age == null) {
      age = resolvedAgeYears;
    }

    if (age != null) {
      if (AdolescentEvidenceCatalog.isAdolescentAge(age)) {
        development = AdolescentDevelopmentState.confirmedAdolescent;
      } else if (AdolescentEvidenceCatalog.isYoungerChildAge(age)) {
        development = AdolescentDevelopmentState.youngerChild;
      } else if (AdolescentEvidenceCatalog.isAdultAge(age)) {
        development = AdolescentDevelopmentState.adult;
      }
    } else if (interp.developmentState != AdolescentDevelopmentState.unknown) {
      development = interp.developmentState;
    }

    return session.copyWith(
      active: true,
      statedAgeYears: age,
      developmentState: development,
      topic: interp.topic != AdolescentTopic.unknown
          ? interp.topic
          : session.topic,
      isOtherPerson: interp.isAboutOtherPerson ? true : session.isOtherPerson,
      otherPersonLabel: interp.otherPersonLabel.isNotEmpty
          ? interp.otherPersonLabel
          : session.otherPersonLabel,
      parentAskingAboutTeen:
          interp.parentAskingAboutTeen || session.parentAskingAboutTeen,
      functionalImpacts: interp.functionalImpacts.isNotEmpty
          ? interp.functionalImpacts
          : session.functionalImpacts,
      bullyingContext: interp.bullyingHint || session.bullyingContext,
      bodyImageContext: interp.bodyImageHint || session.bodyImageContext,
    );
  }

  bool createsTeenProfileStore() => false;
  bool createsTeenMentalHealthStore() => false;
  bool createsSchoolRecordStore() => false;
  bool createsSurveillance() => false;
  bool diagnosesAdhdFromConcentration() => false;
  bool diagnosesDepressionFromMotivation() => false;
  bool infersAgeFromStyle() => false;
  bool commercialTargetsTeens() => false;
  bool usesDependencyLanguage() => false;
}
