import '../../../health/emotional_support/mental_health_safety_gate.dart';
import 'dental_models.dart';

/// تأجيل لـ 10E — بلا محرك طوارئ أسنان ثانٍ.
class DentalSafetyAdapter {
  const DentalSafetyAdapter({
    MentalHealthSafetyGate? mentalSafety,
  }) : _mental = mentalSafety ?? const MentalHealthSafetyGate();

  final MentalHealthSafetyGate _mental;

  bool deferToMedicalSafety(DentalInterpretation interp) =>
      interp.redFlagCandidate ||
      interp.difficultyBreathing ||
      interp.difficultySwallowing ||
      interp.swelling == DentalSwellingClass.eyeArea ||
      interp.swelling == DentalSwellingClass.progressiveFacial;

  bool deferToMentalSafety(String raw) => _mental.triggersCrisis(raw);

  bool createsDentalEmergencyEngine() => false;
  bool createsAbscessEmergencyEngine() => false;
  bool createsFacialSwellingEmergencyEngine() => false;
}
