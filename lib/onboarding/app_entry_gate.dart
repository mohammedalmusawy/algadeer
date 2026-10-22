import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'user_name_onboarding_page.dart';
import '../services/user_profile_service.dart';
import '../utils/ghadeer_card_link.dart';
import '../utils/web_launch.dart';

/// بوابة الدخول: أول تشغيل → تأسيس الملف الشخصي القصير (Phase 3A)، بعدها الرئيسية.
class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key, required this.home});

  final Widget home;

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  final _profile = UserProfileService();
  bool _loading = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // الويب: اللي يجي من رابط بطاقة يشوف الطبيب مباشرة بدون سؤال الاسم
    // (الترحيب يطلع بزيارته العادية الجاية).
    final launch = webLaunchUri;
    final fromCardLink =
        kIsWeb && launch != null && GhadeerCardLink.parse(launch) != null;
    final done = await _profile.isOnboardingDone();
    if (!mounted) return;
    setState(() {
      _showOnboarding = !done && !fromCardLink;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0FAFA3)),
        ),
      );
    }
    if (_showOnboarding) {
      return UserNameOnboardingPage(
        onFinished: () => setState(() => _showOnboarding = false),
      );
    }
    return widget.home;
  }
}
