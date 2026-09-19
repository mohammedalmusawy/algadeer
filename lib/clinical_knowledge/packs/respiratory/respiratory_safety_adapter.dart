import '../../../health/emotional_support/mental_health_safety_gate.dart';
import 'respiratory_models.dart';

/// يحوّل مرشّحات الخطر إلى سلطة 10E — بلا محرك طوارئ ثانٍ.
class RespiratorySafetyAdapter {
  const RespiratorySafetyAdapter({
    MentalHealthSafetyGate? mentalSafety,
  }) : _mental = mentalSafety ?? const MentalHealthSafetyGate();

  final MentalHealthSafetyGate _mental;

  bool deferToMedicalSafety(RespiratoryInterpretation interp) =>
      interp.redFlagCandidate ||
      interp.severeDistress ||
      interp.chestPainSafetyFirst ||
      interp.hemoptysis == RespiratoryTriState.present;

  bool deferToMentalSafety(String raw) => _mental.triggersCrisis(raw);

  bool createsSecondEmergencyEngine() => false;
}
