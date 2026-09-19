import '../search/arabic_text_utils.dart';
import 'wellness_command_interpreter.dart';
import 'wellness_models.dart';

/// بوابة سلامة العافية — لا تنافس 10E؛ تؤجّل عند الأحمر.
class WellnessSafetyGate {
  const WellnessSafetyGate();

  WellnessSafetyDecision decide(String raw) {
    final n = ArabicTextUtils.normalize(raw);

    if (RegExp(
      r'(?:الم.{0,12}صدر|ألم.{0,12}صدر|ضيق\s*نفس\s*شديد|اختناق|'
      r'فاقد\s*وعي|فقدان\s*وعي|اغمى|أدوخ\s*وأفقد|ادوخ\s*وافقد)',
    ).hasMatch(n)) {
      return WellnessSafetyDecision.deferToMedicalSafety;
    }

    if (RegExp(r'(?:ضيق\s*نفس|دوخه|دوخة)').hasMatch(n) &&
        RegExp(r'(?:تمرن|امشي|رياض)').hasMatch(n)) {
      return WellnessSafetyDecision.deferToMedicalSafety;
    }

    if (RegExp(r'(?:ركبتي|رجلي|مفصل|تتعبني\s*من\s*امشي)').hasMatch(n)) {
      return WellnessSafetyDecision.needsClarification;
    }

    if (RegExp(r'(?:قلب|سكري|ضغط)\s*.{0,20}(?:رياض|تمرين|مشي)').hasMatch(n)) {
      return WellnessSafetyDecision.clinicianDiscussionRecommended;
    }

    return WellnessSafetyDecision.safeGeneralGuidance;
  }
}

/// مخطّط أسئلة — ≤2 افتراضياً.
class WellnessQuestionPlanner {
  const WellnessQuestionPlanner({this.maxQuestions = 2});

  final int maxQuestions;

  List<String> plan({
    required WellnessCommandInterpretation interp,
    required WellnessSafetyDecision safety,
    bool overwhelmed = false,
  }) {
    if (safety == WellnessSafetyDecision.deferToMedicalSafety) {
      return const [];
    }
    final limit = overwhelmed ? 1 : maxQuestions;
    final qs = <String>[];

    if (safety == WellnessSafetyDecision.needsClarification) {
      qs.add('الألم يجي أثناء المشي ولا بعده؟ وهل يمنعك تمشي مسافات قصيرة؟');
    }

    if (interp.intent == WellnessIntent.askGuidance &&
        interp.topic == WellnessTopic.generalMovement &&
        qs.length < limit) {
      qs.add('تحب تبدأ بمشي خفيف، لو حركة قصيرة خلال اليوم؟');
    }

    if (interp.intent == WellnessIntent.askRoutine && qs.length < limit) {
      qs.add('عندك تقريباً كم دقيقة باليوم تقدر تخصّصها للحركة؟');
    }

    return qs.take(limit).toList(growable: false);
  }
}
