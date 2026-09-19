import '../../health/emotional_support/mental_health_safety_gate.dart';
import 'adolescent_models.dart';

/// تأجيل لـ MentalHealthSafetyGate / 10E — بلا محرك أزمة مراهقين ثانٍ.
class AdolescentSafetyAdapter {
  const AdolescentSafetyAdapter({
    MentalHealthSafetyGate? mentalSafety,
  }) : _mental = mentalSafety ?? const MentalHealthSafetyGate();

  final MentalHealthSafetyGate _mental;

  bool deferToMentalSafety(String raw) => _mental.triggersCrisis(raw);

  bool deferToMedicalSafety(AdolescentInterpretation interp) =>
      interp.threatHint && interp.bullyingHint;

  bool createsTeenMentalHealthEngine() => false;
  bool createsTeenSurveillance() => false;
  bool promisesAbsoluteSecrecy() => false;
}
