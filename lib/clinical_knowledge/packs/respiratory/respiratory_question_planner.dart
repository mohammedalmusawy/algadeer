import '../../clinical_knowledge_models.dart';
import 'respiratory_models.dart';

/// أسئلة دنيا — سؤال واحد؛ حد أقصى 3؛ لا إعادة سؤال مُجاب.
class RespiratoryQuestionPlanner {
  const RespiratoryQuestionPlanner({this.maxQuestions = 3});

  final int maxQuestions;

  String? nextQuestion(
    RespiratorySession session,
    RespiratoryInterpretation interp,
  ) {
    if (session.questionCount >= maxQuestions) return null;
    if (interp.asksEducation ||
        interp.asksServiceWhere ||
        interp.asksBooking ||
        interp.asksImagingWhere ||
        interp.asksDirectChestXray) {
      return null;
    }

    final asked = session.askedQuestionKeys.toSet();

    if (session.durationBucket == RespiratoryDurationBucket.unknown &&
        !asked.contains('duration') &&
        session.hasCoughContext) {
      return 'duration';
    }

    if (session.population == RespiratoryPopulation.child &&
        !asked.contains('childAge') &&
        !session.symptomKeys.contains('childAgeKnown')) {
      return 'childAge';
    }

    if (session.population == RespiratoryPopulation.child &&
        session.hasCoughContext &&
        session.fever == RespiratoryTriState.unknown &&
        session.breathlessness == RespiratoryTriState.unknown &&
        !asked.contains('childAssociated')) {
      return 'childAssociated';
    }

    if (session.hasCoughContext &&
        session.durationBucket != RespiratoryDurationBucket.unknown &&
        session.durationBucket != RespiratoryDurationBucket.hours &&
        session.durationBucket != RespiratoryDurationBucket.days &&
        session.breathlessness == RespiratoryTriState.unknown &&
        session.hemoptysis == RespiratoryTriState.unknown &&
        !asked.contains('associatedRed')) {
      return 'associatedRed';
    }

    if (session.hasCoughContext &&
        session.hemoptysis == RespiratoryTriState.unknown &&
        !asked.contains('hemoptysis') &&
        !asked.contains('associatedRed') &&
        session.durationClass == ClinicalCoughDurationClass.chronic) {
      return 'hemoptysis';
    }

    if (session.chestPain == RespiratoryTriState.unknown &&
        !asked.contains('chestPain') &&
        session.topic == RespiratoryTopic.respiratoryChestPain) {
      return 'chestPain';
    }

    if (session.functionalImpact == RespiratoryFunctionalImpact.unknown &&
        !asked.contains('function') &&
        session.breathlessness == RespiratoryTriState.present) {
      return 'function';
    }

    return null;
  }

  String promptFor(String key) {
    switch (key) {
      case 'duration':
        return 'منو صاير السعال تقريباً؟ أيام، أسابيع، لو أشهر؟';
      case 'childAge':
        return 'شكد عمره تقريباً؟';
      case 'childAssociated':
        return 'هل عنده حرارة أو ضيق بالتنفس ويا السعال؟';
      case 'associatedRed':
        return 'وياه ضيق نفس أو دم بالبلغم؟';
      case 'hemoptysis':
        return 'صار ويا السعال دم أو بلغم مدمّى؟';
      case 'chestPain':
        return 'في ألم بالصدر ويا الأعراض؟';
      case 'function':
        return 'الضيق يأثر على كلامك أو نومك أو نشاطك اليومي؟';
      case 'clarifyImaging':
        return 'حتى أوضّح إن صورة الصدر مناسبة لهذا السياق: '
            'السعال صارله تقريباً كم؟ وفي ضيق نفس أو دم بالبلغم؟';
      default:
        return 'ممكن توضّح أكثر شوية؟';
    }
  }
}
