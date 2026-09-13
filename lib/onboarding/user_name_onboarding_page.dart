import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';

/// أول تشغيل: طلب الاسم اختياريًا مع زر تخطي.
class UserNameOnboardingPage extends StatefulWidget {
  const UserNameOnboardingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<UserNameOnboardingPage> createState() => _UserNameOnboardingPageState();
}

class _UserNameOnboardingPageState extends State<UserNameOnboardingPage> {
  final _controller = TextEditingController();
  final _profile = UserProfileService();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _profile.saveDisplayName(_controller.text);
    if (!mounted) return;
    widget.onFinished();
  }

  Future<void> _skip() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _profile.skipOnboarding();
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0FAFA3);
    const navy = Color(0xFF123B42);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBFC),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                const Icon(
                  Icons.waving_hand_rounded,
                  size: 56,
                  color: teal,
                ),
                const SizedBox(height: 16),
                const Text(
                  'من فضلك، ممكن اسمك؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: navy,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'إذا تسمح، الاسم اللي تحب نناديك به.\nاختياري — تقدر تتخطى أو تعدّل من الإعدادات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: Color(0xFF5B6C70),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: 'اسمك',
                    hintText: 'مثال: محمد',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(_saving ? '...' : 'حفظ والمتابعة'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : _skip,
                  child: const Text('تخطي'),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
