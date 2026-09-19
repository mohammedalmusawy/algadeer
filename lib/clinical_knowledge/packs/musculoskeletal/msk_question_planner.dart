import '../../clinical_knowledge_models.dart';
import 'msk_models.dart';

/// أسئلة دنيا — سؤال واحد؛ حد أقصى 3 قبل التوجيه المفيد.
class MskQuestionPlanner {
  const MskQuestionPlanner({this.maxQuestions = 3});

  final int maxQuestions;

  String? nextQuestion(MskSession session, MskInterpretation interp) {
    if (session.questionCount >= maxQuestions) return null;
    if (interp.asksEducation ||
        interp.asksServiceWhere ||
        interp.asksBooking ||
        interp.asksImagingWhere) {
      return null;
    }

    final asked = session.lastQuestionKey;

    if (session.duration == MskDurationClass.unknown && asked != 'duration') {
      return 'duration';
    }
    if (session.trauma == MskTraumaMechanism.noneReported &&
        asked != 'trauma' &&
        session.duration != MskDurationClass.unknown &&
        (session.topic == MskTopic.kneePain ||
            session.topic == MskTopic.lowBackPain ||
            session.topic == MskTopic.neckPain ||
            session.topic == MskTopic.shoulderPain ||
            session.topic == MskTopic.hipPain ||
            session.topic == MskTopic.thighMuscleInjury)) {
      return 'trauma';
    }
    if ((session.region == MskBodyRegion.knee ||
            session.topic == MskTopic.kneePain) &&
        !session.symptoms.contains(MskSymptomType.difficultyWeightBearing) &&
        asked != 'weightBearing' &&
        session.trauma != MskTraumaMechanism.noneReported) {
      return 'weightBearing';
    }
    if ((session.topic == MskTopic.lowBackPain ||
            session.topic == MskTopic.radiatingLimbPain) &&
        !session.symptoms.contains(MskSymptomType.radiatingPain) &&
        asked != 'radiation') {
      return 'radiation';
    }
    if (session.functionalImpact == ClinicalFunctionalImpact.unknown &&
        asked != 'function' &&
        session.duration != MskDurationClass.unknown) {
      return 'function';
    }
    return null;
  }

  String promptFor(String key) {
    switch (key) {
      case 'duration':
        return 'منو صاير هذا الألم تقريباً؟';
      case 'trauma':
        return 'صار بعد طيحة أو التواء أو ضربة، لو بدون إصابة واضحة؟';
      case 'weightBearing':
        return 'تگدر تحط وزنك وتمشي عليها؟';
      case 'radiation':
        return 'الألم ينزل للرجل أو الذراع، لو بس موضعي؟';
      case 'function':
        return 'يشگد يأثر على حركتك أو نومك أو شغلك؟';
      default:
        return 'ممكن توضّح أكثر شوية؟';
    }
  }
}
