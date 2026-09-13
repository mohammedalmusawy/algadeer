import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/medical/medical_navigation_service.dart';

void main() {
  final medical = MedicalNavigationService();

  test('red flags trigger urgent care', () {
    final decision = medical.decideForQuery('عندي ألم صدر شديد وضيق تنفس');
    expect(decision.action, MedicalNavigationAction.urgentCare);
  });

  test('blocked diagnosis request', () {
    final decision = medical.decideForQuery('شخص لي حالتي');
    expect(decision.action, MedicalNavigationAction.blocked);
  });

  test('detects abdominal specialty', () {
    final specs = medical.detectSpecialtiesFromDescription(
      'عندي ألم بالبطن وغثيان وين أراجع؟',
    );
    expect(specs, isNotEmpty);
    expect(specs.first.specialty, contains('باطنية'));
  });
}
