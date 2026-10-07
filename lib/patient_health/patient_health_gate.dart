import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/admin_launch_session.dart';
import 'patient_auth.dart';
import 'patient_auth_page.dart';
import 'patient_health_page.dart';
import 'patient_health_repository.dart';

class PatientHealthGate extends StatefulWidget {
  const PatientHealthGate({super.key, this.auth, this.client});

  final PatientAuthApi? auth;
  final SupabaseClient? client;

  @override
  State<PatientHealthGate> createState() => _PatientHealthGateState();
}

class _PatientHealthGateState extends State<PatientHealthGate> {
  SupabaseClient get _client => widget.client ?? Supabase.instance.client;

  PatientAuthApi get _auth => widget.auth ?? SupabasePatientAuthApi(_client);

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final adminSession = isClinicAdminEmail(user?.email);
    if (user == null || adminSession) {
      return PatientAuthPage(
        auth: _auth,
        adminSessionActive: adminSession,
        onSignedIn: () {
          AdminLaunchSession.clear();
          setState(() {});
        },
        onAdminSignedOut: () {
          AdminLaunchSession.clear();
          setState(() {});
        },
      );
    }
    return _file(user.id);
  }

  Widget _file(String userId) {
    return PatientHealthPage(
      repository: SupabasePatientHealthRepository(_client, userId),
      onSignOut: () => _auth.signOut(),
      onDeleteAccount: () => _auth.deleteAccount(),
    );
  }
}
