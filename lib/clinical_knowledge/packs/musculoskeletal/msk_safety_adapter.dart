import '../../../health/emotional_support/mental_health_safety_gate.dart';
import 'msk_models.dart';

/// يحوّل مرشّحات الخطر إلى سلطة 10E — بلا محرك طوارئ ثانٍ.
class MskSafetyAdapter {
  const MskSafetyAdapter({
    MentalHealthSafetyGate? mentalSafety,
  }) : _mental = mentalSafety ?? const MentalHealthSafetyGate();

  final MentalHealthSafetyGate _mental;

  bool deferToMedicalSafety(MskInterpretation interp) =>
      interp.redFlagCandidate;

  bool deferToMentalSafety(String raw) => _mental.triggersCrisis(raw);

  /// مرشّحات نطاقية — للميتاداتا فقط؛ القرار لـ 10E.
  List<String> candidateFlagKeys(MskInterpretation interp) {
    if (!interp.redFlagCandidate) return const [];
    return const [
      'msk_red_flag_candidate',
      'defer_to_medical_safety_engine',
    ];
  }

  bool createsSecondEmergencyEngine() => false;
}
