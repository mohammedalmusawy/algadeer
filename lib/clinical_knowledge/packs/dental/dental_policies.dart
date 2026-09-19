import '../../clinical_knowledge_models.dart';
import 'dental_models.dart';
import 'dental_rule_catalog.dart';

class DentalUrgencyPolicy {
  const DentalUrgencyPolicy();

  DentalUrgency resolve(DentalSession session) {
    if (session.redFlagCandidate) return DentalUrgency.emergencySafety;
    if (session.swelling == DentalSwellingClass.facial ||
        session.swelling == DentalSwellingClass.progressiveFacial ||
        session.swelling == DentalSwellingClass.eyeArea) {
      return DentalUrgency.urgentDentalReview;
    }
    if (session.trauma == DentalTraumaKind.avulsion ||
        session.trauma == DentalTraumaKind.displaced ||
        session.trauma == DentalTraumaKind.facialTrauma) {
      return DentalUrgency.urgentDentalReview;
    }
    if (session.userReportedAbscess ||
        session.difficultyOpeningMouth ||
        session.trauma == DentalTraumaKind.fracture) {
      return DentalUrgency.promptDentalReview;
    }
    if (session.topic == DentalTopic.oralHygiene ||
        session.topic == DentalTopic.educationOnly ||
        session.topic == DentalTopic.cariesPrevention) {
      return DentalUrgency.selfCarePlusRoutineDental;
    }
    if (session.topic != DentalTopic.unknown) {
      return DentalUrgency.dentalReview;
    }
    return DentalUrgency.unknown;
  }
}

class DentalImagingPolicy {
  const DentalImagingPolicy();

  bool commercialCanAlterIndication() => false;
  bool packagePresenceCreatesNeed() => false;
  bool severityAloneRequiresXray(ClinicalSeverityClass s) => false;
  bool toothacheAloneRequiresPanoramic() => false;
  bool wisdomPainAloneRequiresPanoramic() => false;
  bool pregnancyBansAllDentalXray() => false;
  bool pregnancyAutoApprovesAllImaging() => false;

  ClinicalImagingGuidance decide({
    required DentalSession session,
    required DentalRuleCatalog catalog,
  }) {
    if (session.trauma != DentalTraumaKind.none &&
        session.trauma != DentalTraumaKind.chip) {
      return const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.mayBeAppropriate,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'traumaDentistDirected',
        allowsServiceHandoff: true,
      );
    }
    if (session.topic == DentalTopic.dentalImagingQuestion) {
      final rule = catalog.findById('dental_imaging_not_routine_toothache');
      return rule?.imaging ??
          const ClinicalImagingGuidance(
            appropriateness: ClinicalImagingAppropriateness.mayBeAppropriate,
            modality: ClinicalImagingModality.xray,
            reasonCode: 'dentistDirected',
            allowsServiceHandoff: true,
          );
    }
    // ألم سن بسيط: لا تصوير تلقائي
    return const ClinicalImagingGuidance(
      appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
      modality: ClinicalImagingModality.unspecified,
      reasonCode: 'toothacheNoAutoXray',
      allowsServiceHandoff: false,
    );
  }
}

class DentalTraumaPolicy {
  const DentalTraumaPolicy();

  String guidanceFor({
    required DentalTraumaKind trauma,
    required DentalToothType toothType,
    required DentalRuleCatalog catalog,
  }) {
    if (trauma == DentalTraumaKind.avulsion) {
      if (toothType == DentalToothType.primary) {
        return catalog.findById('dental_aapd_avulsion_primary')?.arabicGuidance ??
            '';
      }
      if (toothType == DentalToothType.permanent) {
        return catalog
                .findById('dental_iadt_avulsion_permanent')
                ?.arabicGuidance ??
            '';
      }
      return catalog
              .findById('dental_trauma_type_unknown_clarify')
              ?.arabicGuidance ??
          '';
    }
    if (trauma == DentalTraumaKind.fracture || trauma == DentalTraumaKind.chip) {
      return 'كسر/كسر جزئي ظاهر يحتاج تقييماً سنّياً حسب العمق والألم — '
          'ما نحدد نوع الترميم من الشات.';
    }
    if (trauma == DentalTraumaKind.looseAfterTrauma ||
        trauma == DentalTraumaKind.displaced) {
      return 'سن متحرك/مزاح بعد ضربة يحتاج مراجعة أسنان عاجلة نسبياً.';
    }
    return 'رضّ سني يحتاج تقييماً — بلا خلط بين اللبني والدائم.';
  }
}
