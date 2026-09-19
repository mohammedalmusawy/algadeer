import '../../voice/guided_conversation/guided_conversation_models.dart';
import 'health_follow_up_models.dart';
import 'health_guidance_models.dart';

/// كتالوج أسئلة متابعة مركزية — قصيرة وواضحة بلا تشخيص.
class HealthFollowUpQuestionCatalog {
  HealthFollowUpQuestionCatalog._();

  static GuidedQuestion withMeta(
    GuidedQuestion base,
    HealthQuestionMeta meta,
  ) {
    return GuidedQuestion(
      id: base.id,
      type: base.type,
      prompt: base.prompt,
      expectedAnswerType: base.expectedAnswerType,
      options: base.options,
      required: base.required,
      metadata: {
        ...base.metadata,
        ...meta.toMap(),
      },
    );
  }

  static GuidedQuestion abdominalLocation({String? symptomConceptId}) {
    return withMeta(
      const GuidedQuestion(
        id: 'health_abdominal_location',
        type: GuidedQuestionType.singleChoice,
        prompt: 'وين مكان الألم تقريباً؟',
        expectedAnswerType: GuidedAnswerType.singleChoice,
        options: [
          GuidedChoiceOption(
            id: 'upper',
            label: 'أعلى',
            aliases: ['فوك', 'فوق', 'اعلى', 'أعلى'],
          ),
          GuidedChoiceOption(
            id: 'lower',
            label: 'أسفل',
            aliases: ['جوه', 'تحت', 'اسفل', 'أسفل'],
          ),
          GuidedChoiceOption(
            id: 'right',
            label: 'يمين',
            aliases: ['اليمين', 'اليمنى', 'باليمين', 'بالجهة اليمنى'],
          ),
          GuidedChoiceOption(
            id: 'left',
            label: 'يسار',
            aliases: ['اليسار', 'اليسرى', 'باليسار', 'بالجهة اليسرى'],
          ),
          GuidedChoiceOption(
            id: 'center',
            label: 'بالنص',
            aliases: ['وسط', 'منتصف', 'النص'],
          ),
        ],
      ),
      HealthQuestionMeta(
        factKey: HealthFactKey.abdominalLocation,
        purpose: HealthQuestionPurpose.location,
        missingFact: HealthMissingFact.abdominalLocationDetail,
        symptomConceptId: symptomConceptId ?? 'abdominal_pain',
        clarificationPrompt:
            'أقصد بأي جهة أو منطقة تحس بالألم، مثل يمين أو يسار أو أعلى أو أسفل.',
        whyExplanation:
            'حتى أفهم وصف الأعراض بشكل أدق وأحدد نوع التوجيه المناسب.',
      ),
    );
  }

  static GuidedQuestion duration({String? symptomConceptId}) {
    final id = symptomConceptId == null
        ? 'health_duration'
        : 'health_duration_$symptomConceptId';
    return withMeta(
      GuidedQuestion(
        id: id,
        type: GuidedQuestionType.duration,
        prompt: symptomConceptId == 'headache'
            ? 'من متى الصداع؟'
            : 'من متى بدأت الأعراض؟',
        expectedAnswerType: GuidedAnswerType.duration,
      ),
      HealthQuestionMeta(
        factKey: HealthFactKey.duration,
        purpose: HealthQuestionPurpose.duration,
        missingFact: HealthMissingFact.duration,
        symptomConceptId: symptomConceptId,
        clarificationPrompt:
            'أقصد منذ متى بدأت المشكلة، مثل من البارحة أو من يومين أو أسبوع.',
        whyExplanation:
            'حتى أفهم وصف الأعراض بشكل أدق وأحدد نوع التوجيه المناسب.',
      ),
    );
  }

  static GuidedQuestion severity({String? symptomConceptId}) {
    return withMeta(
      const GuidedQuestion(
        id: 'health_severity',
        type: GuidedQuestionType.singleChoice,
        prompt: 'الألم خفيف، متوسط، لو شديد؟',
        expectedAnswerType: GuidedAnswerType.singleChoice,
        options: [
          GuidedChoiceOption(
            id: 'mild',
            label: 'خفيف',
            aliases: ['بسيط', 'خفيف'],
          ),
          GuidedChoiceOption(
            id: 'moderate',
            label: 'متوسط',
            aliases: ['وسط'],
          ),
          GuidedChoiceOption(
            id: 'severe',
            label: 'شديد',
            aliases: ['قوي', 'كلش قوي', 'ما اتحمله'],
          ),
        ],
      ),
      HealthQuestionMeta(
        factKey: HealthFactKey.severity,
        purpose: HealthQuestionPurpose.severity,
        missingFact: HealthMissingFact.severity,
        symptomConceptId: symptomConceptId,
        clarificationPrompt: 'أقصد شدة الألم: خفيف أو متوسط أو شديد.',
        whyExplanation:
            'حتى أفهم وصف الأعراض بشكل أدق وأحدد نوع التوجيه المناسب.',
      ),
    );
  }

  static GuidedQuestion onset({String? symptomConceptId}) {
    return withMeta(
      const GuidedQuestion(
        id: 'health_onset',
        type: GuidedQuestionType.singleChoice,
        prompt: 'بدأ فجأة لو بالتدريج؟',
        expectedAnswerType: GuidedAnswerType.singleChoice,
        options: [
          GuidedChoiceOption(
            id: 'sudden',
            label: 'فجأة',
            aliases: ['مره وحدة', 'مرة وحدة', 'بشكل مفاجئ'],
          ),
          GuidedChoiceOption(
            id: 'gradual',
            label: 'بالتدريج',
            aliases: ['شوي شوي', 'شوية شوية'],
          ),
        ],
      ),
      HealthQuestionMeta(
        factKey: HealthFactKey.onset,
        purpose: HealthQuestionPurpose.onset,
        missingFact: HealthMissingFact.onset,
        symptomConceptId: symptomConceptId,
        clarificationPrompt:
            'أقصد هل بدأت الأعراض دفعة واحدة فجأة، أو زادت شوي شوي.',
        whyExplanation:
            'حتى أفهم وصف الأعراض بشكل أدق وأحدد نوع التوجيه المناسب.',
      ),
    );
  }

  static GuidedQuestion pattern({String? symptomConceptId}) {
    return withMeta(
      const GuidedQuestion(
        id: 'health_pattern',
        type: GuidedQuestionType.singleChoice,
        prompt: 'الأعراض مستمرة لو تروح وتجي؟',
        expectedAnswerType: GuidedAnswerType.singleChoice,
        options: [
          GuidedChoiceOption(
            id: 'continuous',
            label: 'مستمر',
            aliases: ['باستمرار'],
          ),
          GuidedChoiceOption(
            id: 'intermittent',
            label: 'يروح ويجي',
            aliases: ['مرات', 'متقطع', 'يجي ويروح'],
          ),
        ],
      ),
      HealthQuestionMeta(
        factKey: HealthFactKey.pattern,
        purpose: HealthQuestionPurpose.pattern,
        symptomConceptId: symptomConceptId,
        clarificationPrompt:
            'أقصد هل الألم أو الأعراض ثابتة، أو تظهر وتختفي.',
        whyExplanation:
            'حتى أفهم وصف الأعراض بشكل أدق وأحدد نوع التوجيه المناسب.',
      ),
    );
  }

  static GuidedQuestion feverPresence() {
    return withMeta(
      const GuidedQuestion(
        id: 'health_associated_fever',
        type: GuidedQuestionType.yesNo,
        prompt: 'عندك حرارة؟',
        expectedAnswerType: GuidedAnswerType.yesNo,
      ),
      const HealthQuestionMeta(
        factKey: HealthFactKey.symptomPresence,
        purpose: HealthQuestionPurpose.symptomPresence,
        missingFact: HealthMissingFact.associatedFever,
        symptomConceptId: 'fever',
        clarificationPrompt: 'أقصد هل تحس بحرارة أو حمى حالياً: نعم أو لا.',
        whyExplanation:
            'حتى أفهم وصف الأعراض بشكل أدق وأحدد نوع التوجيه المناسب.',
      ),
    );
  }

  static GuidedQuestion patientIsChild() {
    return withMeta(
      const GuidedQuestion(
        id: 'health_patient_is_child',
        type: GuidedQuestionType.yesNo,
        prompt: 'هل الاستشارة تخص طفلاً؟',
        expectedAnswerType: GuidedAnswerType.yesNo,
      ),
      const HealthQuestionMeta(
        factKey: HealthFactKey.patientIsChild,
        purpose: HealthQuestionPurpose.patientContext,
        missingFact: HealthMissingFact.patientIsChild,
        clarificationPrompt: 'أقصد هل الأعراض لطفل أم لشخص بالغ.',
        whyExplanation:
            'حتى أفهم وصف الأعراض بشكل أدق وأحدد نوع التوجيه المناسب.',
      ),
    );
  }

  static GuidedQuestion? forMissingFact(
    HealthMissingFact fact, {
    String? symptomConceptId,
  }) {
    switch (fact) {
      case HealthMissingFact.abdominalLocationDetail:
        return abdominalLocation(symptomConceptId: symptomConceptId);
      case HealthMissingFact.duration:
        return duration(symptomConceptId: symptomConceptId);
      case HealthMissingFact.severity:
        return severity(symptomConceptId: symptomConceptId);
      case HealthMissingFact.onset:
        return onset(symptomConceptId: symptomConceptId);
      case HealthMissingFact.associatedFever:
        return feverPresence();
      case HealthMissingFact.patientIsChild:
        return patientIsChild();
      case HealthMissingFact.bodyRegion:
        return abdominalLocation(symptomConceptId: symptomConceptId);
      case HealthMissingFact.laterality:
        return abdominalLocation(symptomConceptId: symptomConceptId);
    }
  }
}
