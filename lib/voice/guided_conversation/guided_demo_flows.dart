import 'guided_conversation_models.dart';

/// تعريف تدفق تجريبي غير طبي — للاختبار والتحقق الداخلي فقط.
class GuidedDemoFlows {
  GuidedDemoFlows._();

  static const serviceAssistanceDemoId = 'service_assistance_demo';

  static GuidedFlowDefinition serviceAssistanceDemo() {
    const q1 = GuidedQuestion(
      id: 'help_search_yes_no',
      type: GuidedQuestionType.yesNo,
      prompt: 'تريد أساعدك بالبحث عن خدمة؟',
      expectedAnswerType: GuidedAnswerType.yesNo,
    );
    const q2 = GuidedQuestion(
      id: 'service_type',
      type: GuidedQuestionType.singleChoice,
      prompt: 'تبحث عن طبيب، مختبر، تحليل، لو باقة؟',
      expectedAnswerType: GuidedAnswerType.singleChoice,
      options: [
        GuidedChoiceOption(
          id: 'doctor',
          label: 'طبيب',
          aliases: ['دكتور', 'طبيبة', 'دكتورة', 'دكتوره', 'طبيبه'],
        ),
        GuidedChoiceOption(
          id: 'laboratory',
          label: 'مختبر',
          aliases: ['مختبرات', 'لاب', 'المختبر'],
        ),
        GuidedChoiceOption(
          id: 'analysis',
          label: 'تحليل',
          aliases: ['تحاليل', 'فحص', 'فحوصات'],
        ),
        GuidedChoiceOption(
          id: 'package',
          label: 'باقة',
          aliases: ['باقات', 'عرض', 'عروض', 'باقه'],
        ),
      ],
    );

    return const GuidedFlowDefinition(
      id: serviceAssistanceDemoId,
      type: GuidedFlowType.serviceAssistanceDemo,
      initialStepId: 'step_help',
      steps: [
        GuidedFlowStep(
          id: 'step_help',
          question: q1,
          nextStepByAnswer: {
            'yes': 'step_service_type',
            'no': '__complete__',
          },
          nextStepId: 'step_service_type',
        ),
        GuidedFlowStep(
          id: 'step_service_type',
          question: q2,
          nextStepId: '__complete__',
        ),
      ],
    );
  }
}
