import 'adolescent_models.dart';

class AdolescentQuestionPlanner {
  const AdolescentQuestionPlanner({this.maxQuestions = 3});

  final int maxQuestions;

  String? nextQuestion(
    AdolescentCompanionSession session,
    AdolescentInterpretation interp,
  ) {
    if (session.questionCount >= maxQuestions) return null;
    if (interp.asksEducation ||
        interp.asksPlan ||
        interp.asksStudyHelp && session.isConfirmedAdolescent) {
      // قد نسأل فقط إن العمر ناقص ومهم
    }
    final asked = session.askedQuestionKeys.toSet();

    if (session.isOtherPerson && !asked.contains('subjectClarify')) {
      return 'subjectClarify';
    }
    if (!session.isConfirmedAdolescent &&
        session.statedAgeYears == null &&
        interp.isAdolescentTurn &&
        !asked.contains('ageIfMaterial') &&
        (interp.asksStudyHelp || interp.asksSleep || interp.bodyImageHint)) {
      return 'ageIfMaterial';
    }
    if (interp.topic == AdolescentTopic.unknown &&
        interp.isAdolescentTurn &&
        !asked.contains('whatHelp')) {
      return 'whatHelp';
    }
    return null;
  }

  String promptFor(String key) {
    switch (key) {
      case 'subjectClarify':
        return 'هالموضوع عنك أنت لو عن شخص ثاني بالعائلة؟';
      case 'ageIfMaterial':
        return 'إذا تحب، قلي تقريباً شكد عمرك حتى أكون أدق؟';
      case 'whatHelp':
        return 'نبدأ بأي جزء يضايقك أكثر هسه؟';
      case 'sleepOrStudy':
        return 'نبدأ بالنوم لو الدراسة؟';
      default:
        return 'ممكن توضّح أكثر شوية؟';
    }
  }
}
