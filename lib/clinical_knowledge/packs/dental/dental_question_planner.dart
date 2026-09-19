import 'dental_models.dart';

class DentalQuestionPlanner {
  const DentalQuestionPlanner({this.maxQuestions = 3});

  final int maxQuestions;

  String? nextQuestion(DentalSession session, DentalInterpretation interp) {
    if (session.questionCount >= maxQuestions) return null;
    if (interp.asksEducation ||
        interp.asksAntibiotic ||
        interp.asksImaging ||
        interp.asksServiceWhere ||
        interp.asksBooking) {
      return null;
    }
    // معلومات السلامة معروفة — لا نعيد السؤال
    if (interp.redFlagCandidate ||
        session.swelling == DentalSwellingClass.facial ||
        session.swelling == DentalSwellingClass.progressiveFacial) {
      return null;
    }

    final asked = session.askedQuestionKeys.toSet();

    if (session.isOtherPerson && !asked.contains('subjectClarify')) {
      return 'subjectClarify';
    }
    if ((session.trauma == DentalTraumaKind.avulsion ||
            session.topic == DentalTopic.lostTooth) &&
        session.toothType == DentalToothType.unknown &&
        !asked.contains('primaryVsPermanent')) {
      return 'primaryVsPermanent';
    }
    if (session.swelling == DentalSwellingClass.unknown &&
        session.topic == DentalTopic.toothPain &&
        !asked.contains('swellingPresent') &&
        !interp.negatesSwelling) {
      return 'swellingPresent';
    }
    return null;
  }

  String promptFor(String key) {
    switch (key) {
      case 'subjectClarify':
        return 'هالألم عنك أنت لو عن شخص ثاني (مثل ابنك)؟';
      case 'primaryVsPermanent':
        return 'السن لبني لو دائم، إذا تعرف؟';
      case 'swellingPresent':
        return 'عندك ورم بالوجه أو داخل الفم مع الألم؟';
      default:
        return 'ممكن توضّح أكثر شوية؟';
    }
  }
}
