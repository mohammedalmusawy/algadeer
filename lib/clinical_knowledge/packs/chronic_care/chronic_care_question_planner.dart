import 'chronic_care_models.dart';

class ChronicCareQuestionPlanner {
  const ChronicCareQuestionPlanner({this.maxQuestions = 3});

  final int maxQuestions;

  String? nextQuestion(
    ChronicClinicalSession session,
    ChronicClinicalInterpretation interp,
  ) {
    if (session.questionCount >= maxQuestions) return null;
    if (interp.asksEducation ||
        interp.asksWhatsLeft ||
        interp.asksFullChecklist ||
        interp.asksBpTechnique ||
        interp.asksServiceWhere ||
        interp.asksBooking) {
      return null;
    }

    final asked = session.askedQuestionKeys.toSet();

    if (interp.glucoseValue != null &&
        session.diabetesStatus != ChronicConditionStatus.established &&
        !asked.contains('dmEstablished')) {
      return 'dmEstablished';
    }
    if (interp.systolic != null &&
        session.hypertensionStatus != ChronicConditionStatus.established &&
        !asked.contains('htnEstablished')) {
      return 'htnEstablished';
    }
    if (interp.glucoseValue != null &&
        session.measurementContextUnknown &&
        !asked.contains('glucoseTiming')) {
      return 'glucoseTiming';
    }
    if (session.hasEstablishedDiabetes &&
        !session.completedCareItems.contains(DiabetesCareItem.kidneyAssessment.name) &&
        !asked.contains('kidneyLast') &&
        session.topic == ChronicClinicalTopic.whatsLeft) {
      return 'kidneyLast';
    }
    return null;
  }

  String promptFor(String key) {
    switch (key) {
      case 'dmEstablished':
        return 'السكري مشخص من طبيب لو هذه أول قراءة عالية؟';
      case 'htnEstablished':
        return 'عندك ضغط مشخص، لو هاي أول مرة يطلع عالي؟';
      case 'glucoseTiming':
        return 'هذه القراءة وإنت صايم لو بعد الأكل؟';
      case 'kidneyLast':
        return 'تتذكر تقريباً آخر مرة سويت فحص الكلى؟';
      default:
        return 'ممكن توضّح أكثر شوية؟';
    }
  }
}
