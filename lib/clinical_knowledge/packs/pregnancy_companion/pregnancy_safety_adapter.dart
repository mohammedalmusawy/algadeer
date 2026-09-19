import '../../../health/emotional_support/mental_health_safety_gate.dart';
import 'pregnancy_models.dart';

/// تأجيل لـ 10E / MentalHealthSafetyGate — بلا محرك طوارئ حمل ثانٍ.
class PregnancySafetyAdapter {
  const PregnancySafetyAdapter({
    MentalHealthSafetyGate? mentalSafety,
  }) : _mental = mentalSafety ?? const MentalHealthSafetyGate();

  final MentalHealthSafetyGate _mental;

  bool deferToMedicalSafety(PregnancyInterpretation interp) =>
      interp.redFlagCandidate ||
      interp.symptomClass == PregnancySymptomClass.deferTo10E ||
      interp.bleedingHint;

  bool deferToMentalSafety(String raw) => _mental.triggersCrisis(raw);

  bool createsPregnancyEmergencyEngine() => false;
  bool createsPreeclampsiaEmergencyEngine() => false;
  bool createsBleedingEmergencyEngine() => false;
  bool createsLaborEmergencyEngine() => false;
}
