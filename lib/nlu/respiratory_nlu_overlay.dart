import '../clinical_knowledge/packs/respiratory/respiratory_models.dart';
import 'nlu_models.dart';

/// دمج آمن: AI يملأ الخانات المجهولة فقط. الجلسة والتفسير الحتمي يفوزان.
class RespiratoryNluOverlay {
  const RespiratoryNluOverlay();

  NluOverlayApplication apply({
    required RespiratoryInterpretation interp,
    required RespiratorySession session,
    required NluParse parse,
  }) {
    if (!parse.meetsOverallConfidence) {
      return NluOverlayApplication(
        interp: interp,
        overlay: const NluSlotOverlay(),
        rejectedSlots: const ['overall'],
        fallbackReason: NluSkipReason.lowConfidence,
      );
    }

    final accepted = <String>[];
    final rejected = <String>[];

    RespiratoryTriState pick({
      required String name,
      required RespiratoryTriState sessionValue,
      required RespiratoryTriState interpValue,
      required RespiratoryTriState aiValue,
    }) {
      if (aiValue == RespiratoryTriState.unknown) {
        return RespiratoryTriState.unknown;
      }
      if (sessionValue != RespiratoryTriState.unknown) {
        rejected.add(name);
        return RespiratoryTriState.unknown;
      }
      if (interpValue != RespiratoryTriState.unknown) {
        rejected.add(name);
        return RespiratoryTriState.unknown;
      }
      if (parse.confidenceFor(name) < kNluMinSlotConfidence) {
        rejected.add(name);
        return RespiratoryTriState.unknown;
      }
      accepted.add(name);
      return aiValue;
    }

    final overlay = NluSlotOverlay(
      cough: pick(
        name: 'cough',
        sessionValue: session.coughType != RespiratoryCoughType.unknown ||
                session.hasCoughContext
            ? RespiratoryTriState.present
            : RespiratoryTriState.unknown,
        interpValue: interp.symptomKeys.contains('cough')
            ? RespiratoryTriState.present
            : RespiratoryTriState.unknown,
        aiValue: parse.cough,
      ),
      fever: pick(
        name: 'fever',
        sessionValue: session.fever,
        interpValue: interp.fever,
        aiValue: parse.fever,
      ),
      breathlessness: pick(
        name: 'breathlessness',
        sessionValue: session.breathlessness,
        interpValue: interp.breathlessness,
        aiValue: parse.breathlessness,
      ),
      sputum: pick(
        name: 'sputum',
        sessionValue: session.sputum,
        interpValue: interp.sputum,
        aiValue: parse.sputum,
      ),
      hemoptysis: pick(
        name: 'hemoptysis',
        sessionValue: session.hemoptysis,
        interpValue: interp.hemoptysis,
        aiValue: parse.hemoptysis,
      ),
    );

    if (!overlay.hasAnyKnown) {
      return NluOverlayApplication(
        interp: interp,
        overlay: overlay,
        acceptedSlots: accepted,
        rejectedSlots: rejected,
        fallbackReason: accepted.isEmpty ? NluSkipReason.overlayEmpty : null,
      );
    }

    final keys = {...interp.symptomKeys};
    if (overlay.cough == RespiratoryTriState.present) keys.add('cough');
    if (overlay.fever == RespiratoryTriState.present) keys.add('fever');
    if (overlay.breathlessness == RespiratoryTriState.present) {
      keys.add('breathlessness');
    }
    if (overlay.sputum == RespiratoryTriState.present) keys.add('sputum');
    if (overlay.hemoptysis == RespiratoryTriState.present) {
      keys.add('hemoptysis');
    }

    final merged = RespiratoryInterpretation(
      isRespiratoryTurn: true,
      topic: interp.topic,
      durationBucket: interp.durationBucket,
      coughType: interp.coughType,
      sputum: overlay.sputum != RespiratoryTriState.unknown
          ? overlay.sputum
          : interp.sputum,
      breathlessness: overlay.breathlessness != RespiratoryTriState.unknown
          ? overlay.breathlessness
          : interp.breathlessness,
      wheeze: interp.wheeze,
      chestPain: interp.chestPain,
      fever: overlay.fever != RespiratoryTriState.unknown
          ? overlay.fever
          : interp.fever,
      hemoptysis: overlay.hemoptysis != RespiratoryTriState.unknown
          ? overlay.hemoptysis
          : interp.hemoptysis,
      weightLoss: interp.weightLoss,
      functionalImpact: interp.functionalImpact,
      knownCondition: interp.knownCondition,
      smoking: interp.smoking,
      recurrentInfection: interp.recurrentInfection,
      recentRespiratoryIllness: interp.recentRespiratoryIllness,
      redFlagCandidate: interp.redFlagCandidate,
      chestPainSafetyFirst: interp.chestPainSafetyFirst,
      severeDistress: interp.severeDistress,
      asksEducation: interp.asksEducation,
      asksServiceWhere: interp.asksServiceWhere,
      asksBooking: interp.asksBooking,
      asksImagingWhere: interp.asksImagingWhere,
      asksDirectChestXray: interp.asksDirectChestXray,
      selfSuspectsInfection: interp.selfSuspectsInfection,
      isAboutOtherPerson: interp.isAboutOtherPerson,
      pregnancyContextHint: interp.pregnancyContextHint,
      population: interp.population,
      explicitFollowUp: interp.explicitFollowUp,
      correctionDuration: interp.correctionDuration,
      correctionCoughType: interp.correctionCoughType,
      symptomKeys: keys.toList(growable: false),
    );

    return NluOverlayApplication(
      interp: merged,
      overlay: overlay,
      acceptedSlots: accepted,
      rejectedSlots: rejected,
    );
  }
}

class NluOverlayApplication {
  const NluOverlayApplication({
    required this.interp,
    required this.overlay,
    this.acceptedSlots = const [],
    this.rejectedSlots = const [],
    this.fallbackReason,
  });

  final RespiratoryInterpretation interp;
  final NluSlotOverlay overlay;
  final List<String> acceptedSlots;
  final List<String> rejectedSlots;
  final NluSkipReason? fallbackReason;
}
