import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/patient_health/patient_auth.dart';
import 'package:ghadeer_clinic/patient_health/patient_auth_page.dart';
import 'package:ghadeer_clinic/services/admin_launch_session.dart';

class _FakeAuth implements PatientAuthApi {
  bool signedOut = false;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<PatientAuthResult> requestPasswordReset({required String email}) async {
    return const PatientAuthResult(
      PatientAuthStatus.resetRequested,
      patientResetRequestedMessage,
    );
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  Future<PatientAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    return const PatientAuthResult(PatientAuthStatus.failed, 'لا');
  }

  @override
  Future<PatientAuthResult> signUp({
    required String email,
    required String password,
  }) async {
    return const PatientAuthResult(PatientAuthStatus.failed, 'لا');
  }

  @override
  Future<PatientAuthResult> updatePassword({required String password}) async {
    return const PatientAuthResult(PatientAuthStatus.failed, 'لا');
  }
}

void main() {
  testWidgets('تسجيل الخروج من الإدارة يفصل القفل عن Auth', (tester) async {
    final auth = _FakeAuth();
    AdminLaunchSession.markUnlocked();
    var cleared = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PatientAuthPage(
          auth: auth,
          adminSessionActive: true,
          onSignedIn: () {},
          onAdminSignedOut: () => cleared++,
        ),
      ),
    );

    expect(find.byKey(const Key('patient_admin_sign_out')), findsOneWidget);
    expect(find.textContaining('قفل لوحة الإدارة وحده ما يكفي'), findsOneWidget);

    await tester.tap(find.byKey(const Key('patient_admin_sign_out')));
    await tester.pumpAndSettle();

    expect(auth.signedOut, isTrue);
    expect(AdminLaunchSession.unlocked, isFalse);
    expect(cleared, 1);
    expect(find.textContaining('تم تسجيل الخروج من الإدارة'), findsOneWidget);
  });
}
