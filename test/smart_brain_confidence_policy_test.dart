import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/voice/intent/confidence_policy.dart';

void main() {
  group('SmartBrainConfidencePolicy', () {
    test('عتبات نية: high / medium / low', () {
      expect(
        SmartBrainConfidencePolicy.fromIntentScore(90),
        SmartBrainConfidenceBand.high,
      );
      expect(
        SmartBrainConfidencePolicy.fromIntentScore(80),
        SmartBrainConfidenceBand.high,
      );
      expect(
        SmartBrainConfidencePolicy.fromIntentScore(70),
        SmartBrainConfidenceBand.medium,
      );
      expect(
        SmartBrainConfidencePolicy.fromIntentScore(55),
        SmartBrainConfidenceBand.medium,
      );
      expect(
        SmartBrainConfidencePolicy.fromIntentScore(40),
        SmartBrainConfidenceBand.low,
      );
    });

    test('عتبات مطابقة اسم', () {
      expect(
        SmartBrainConfidencePolicy.fromMatchScore(95),
        SmartBrainConfidenceBand.high,
      );
      expect(
        SmartBrainConfidencePolicy.fromMatchScore(75),
        SmartBrainConfidenceBand.medium,
      );
      expect(
        SmartBrainConfidencePolicy.fromMatchScore(50),
        SmartBrainConfidenceBand.low,
      );
    });

    test('combine يأخذ الأضعف', () {
      expect(
        SmartBrainConfidencePolicy.combine(intentScore: 95, matchScore: 60),
        SmartBrainConfidenceBand.low,
      );
      expect(
        SmartBrainConfidencePolicy.combine(intentScore: 95, matchScore: 75),
        SmartBrainConfidenceBand.medium,
      );
      expect(
        SmartBrainConfidencePolicy.combine(intentScore: 95, matchScore: 92),
        SmartBrainConfidenceBand.high,
      );
      expect(
        SmartBrainConfidencePolicy.combine(intentScore: 70),
        SmartBrainConfidenceBand.medium,
      );
    });

    test('forNameResolution: المطابقة تقود إن النية ليست LOW', () {
      expect(
        SmartBrainConfidencePolicy.forNameResolution(
          intentScore: 75,
          matchScore: 96,
        ),
        SmartBrainConfidenceBand.high,
      );
      expect(
        SmartBrainConfidencePolicy.forNameResolution(
          intentScore: 75,
          matchScore: 80,
        ),
        SmartBrainConfidenceBand.medium,
      );
      expect(
        SmartBrainConfidencePolicy.forNameResolution(
          intentScore: 40,
          matchScore: 100,
        ),
        SmartBrainConfidenceBand.low,
      );
    });

    test('forUniqueNameResolution: وحيد+لقب → HIGH؛ وحيد بلا لقب → MEDIUM', () {
      expect(
        SmartBrainConfidencePolicy.forUniqueNameResolution(
          intentScore: 90,
          matchScore: 85,
          isUniqueNonAmbiguous: true,
          hasExplicitTypeHint: true,
        ),
        SmartBrainConfidenceBand.high,
      );
      expect(
        SmartBrainConfidencePolicy.forUniqueNameResolution(
          intentScore: 90,
          matchScore: 85,
          isUniqueNonAmbiguous: true,
          hasExplicitTypeHint: false,
        ),
        SmartBrainConfidenceBand.medium,
      );
      expect(
        SmartBrainConfidencePolicy.forUniqueNameResolution(
          intentScore: 90,
          matchScore: 85,
          isUniqueNonAmbiguous: false,
          hasExplicitTypeHint: true,
        ),
        SmartBrainConfidenceBand.medium,
      );
    });

    test('shouldExecute / Confirm / Clarify', () {
      expect(
        SmartBrainConfidencePolicy.shouldExecuteDirectly(
          SmartBrainConfidenceBand.high,
        ),
        isTrue,
      );
      expect(
        SmartBrainConfidencePolicy.shouldConfirm(
          SmartBrainConfidenceBand.medium,
        ),
        isTrue,
      );
      expect(
        SmartBrainConfidencePolicy.shouldClarify(
          SmartBrainConfidenceBand.low,
        ),
        isTrue,
      );
    });
  });
}
