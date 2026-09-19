import 'emotional_support_models.dart';

/// استراتيجيات رد قصيرة — خطوة عملية واحدة.
class EmotionalResponseStrategyBuilder {
  const EmotionalResponseStrategyBuilder();

  String build({
    required EmotionalSupportStrategy strategy,
    required EmotionalSignal signal,
    bool studentContext = false,
  }) {
    switch (strategy) {
      case EmotionalSupportStrategy.none:
        return '';
      case EmotionalSupportStrategy.crisisSafety:
        return ''; // يُبنى من بوابة السلامة
      case EmotionalSupportStrategy.acknowledgeCalmNextStep:
        if (signal.aboutOtherPerson) {
          return 'فهمت إن القلق يخص شخص عزيز عليك. خلينا نركز على شلون نساعد بهدوء.';
        }
        return 'طبيعي تحس بهالقلق. خلينا نمشي خطوة خطوة بهدوء.';
      case EmotionalSupportStrategy.reduceTaskSize:
        return 'واضح إن الضغط عالي. خل نرتب أول خطوة بس.';
      case EmotionalSupportStrategy.examOrganize:
        if (studentContext) {
          return 'الامتحانات تضغط هواي ناس. إذا تحب، قسّم الساعة إلى دراسة قصيرة ثم استراحة بسيطة.';
        }
        return 'ضغط الامتحان مفهوم. خطوة صغيرة منظمة أحسن من حمل كلشي مرة وحدة.';
      case EmotionalSupportStrategy.resultAnxietyNoPrediction:
        return 'طبيعي تحس بقلق وأنت تنتظر النتيجة. خلينا ما نستبق النتيجة، '
            'وإذا تحب من تطلع أساعدك تفهم شنو الخطوة المناسبة.';
      case EmotionalSupportStrategy.procedureCalmPrep:
        return 'الخوف من الإجراء مفهوم. نقدر نجهزك عملياً بهدوء بدون ما نستبق النتيجة.';
      case EmotionalSupportStrategy.acknowledgeAndSolve:
        return 'فاهم إنك منزعج. خلينا نحل المطلوب خطوة واضحة.';
      case EmotionalSupportStrategy.supportiveOptionalQuestion:
        return 'معك بهاللحظة. إذا تحب، تكلي شنو أكثر شي مضايقك الحين؟';
      case EmotionalSupportStrategy.oneThingAtATime:
        return 'كلشي يصير ثقيل أحياناً. خلينا نمسك شيء واحد بس الآن.';
    }
  }
}
