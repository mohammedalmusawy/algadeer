import '../../../health/emotional_support/mental_health_safety_gate.dart';
import 'chronic_care_models.dart';

/// تأجيل لـ 10E — بلا محرك طوارئ سكري/ضغط ثانٍ.
class ChronicCareSafetyAdapter {
  const ChronicCareSafetyAdapter({
    MentalHealthSafetyGate? mentalSafety,
  }) : _mental = mentalSafety ?? const MentalHealthSafetyGate();

  final MentalHealthSafetyGate _mental;

  bool deferToMedicalSafety(ChronicClinicalInterpretation interp) =>
      interp.redFlagCandidate ||
      interp.metabolicDangerHint ||
      interp.bpConcerningSymptoms;

  bool deferToMentalSafety(String raw) => _mental.triggersCrisis(raw);

  bool createsDiabetesEmergencyEngine() => false;
  bool createsHypertensionEmergencyEngine() => false;
}
