import 'pregnancy_models.dart';

class PregnancyQuestionPlanner {
  const PregnancyQuestionPlanner({this.maxQuestions = 3});

  final int maxQuestions;

  String? nextQuestion(
    PregnancyCompanionSession session,
    PregnancyInterpretation interp,
  ) {
    if (session.questionCount >= maxQuestions) return null;
    if (interp.asksWhatsLeft ||
        interp.asksFullChecklist ||
        interp.asksEducation ||
        interp.asksFetalSex ||
        interp.asksUltrasound ||
        interp.asksActivity ||
        interp.asksNutrition ||
        interp.asksServiceWhere ||
        interp.asksBooking) {
      return null;
    }

    final asked = session.askedQuestionKeys.toSet();

    if (session.status == PregnancyStatus.unknown &&
        interp.status == PregnancyStatus.unknown &&
        !asked.contains('confirmPregnancy')) {
      return 'confirmPregnancy';
    }
    if (session.isOtherPerson && !asked.contains('subjectClarify')) {
      return 'subjectClarify';
    }
    if (session.status == PregnancyStatus.confirmed &&
        session.gestationalWeeks == null &&
        session.stage == PregnancyStage.unknown &&
        interp.monthColloquial == null &&
        !asked.contains('gestationalAge')) {
      return 'gestationalAge';
    }
    if (interp.datingSource == GestationalDatingSource.monthColloquial &&
        session.gestationalWeeks == null &&
        !asked.contains('clarifyWeekFromMonth')) {
      return 'clarifyWeekFromMonth';
    }
    return null;
  }

  String promptFor(String key) {
    switch (key) {
      case 'confirmPregnancy':
        return 'هل الحمل مؤكد من طبيبة أو فحص، لو مجرد احتمال؟';
      case 'subjectClarify':
        return 'هالمعلومة عنج أنتِ لو عن شخص ثاني بالعائلة؟';
      case 'gestationalAge':
        return 'تعرفين تقريباً بأي أسبوع أنتي حسب الطبيبة أو السونار؟';
      case 'clarifyWeekFromMonth':
        return 'الشهر تقريبي. إذا عندج رقم أسبوع من الطبيبة، قوليلي إياه؟';
      default:
        return 'ممكن توضّحين أكثر شوية؟';
    }
  }
}
