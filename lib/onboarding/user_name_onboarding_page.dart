import 'package:flutter/material.dart';

import '../companion/personal_companion_profile.dart';
import '../companion/personal_profile_foundation.dart';
import '../services/user_profile_service.dart';

/// Phase 3A — شاشة تأسيس الملف الشخصي القصيرة عند أول تشغيل.
///
/// تعيد استخدام [UserProfileService] / [PersonalCompanionProfile] —
/// بلا نظام ملف موازٍ وبلا رفع سحابي.
class UserNameOnboardingPage extends StatefulWidget {
  const UserNameOnboardingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<UserNameOnboardingPage> createState() => _UserNameOnboardingPageState();
}

class _UserNameOnboardingPageState extends State<UserNameOnboardingPage> {
  final _nameController = TextEditingController();
  final _birthController = TextEditingController();
  final _profile = UserProfileService();
  ProfileSexSelection? _sex;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _error = null;
      _saving = true;
    });

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'الاسم الثلاثي مطلوب.';
        _saving = false;
      });
      return;
    }
    if (_sex == null) {
      setState(() {
        _error = 'اختر الجنس: ذكر أو أنثى.';
        _saving = false;
      });
      return;
    }

    final parsed = PersonalProfileFoundation.parseBirthOrAgeInput(
      _birthController.text,
    );
    if (parsed == null) {
      setState(() {
        _error =
            'أدخل عمراً (مثل 35) أو سنة ميلاد (مثل 1990) أو تاريخاً (1990-06-15).';
        _saving = false;
      });
      return;
    }

    try {
      await _profile.foundation.saveBasicProfile(
        fullName: name,
        birthDate: parsed.birthDate,
        birthYear: parsed.birthYear,
        ageYears: parsed.ageYears,
        sex: _sex!,
      );
      await _profile.markFirstLaunchFinished();
      if (!mounted) return;
      widget.onFinished();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر الحفظ. راجع العمر/تاريخ الميلاد وحاول مجدداً.';
        _saving = false;
      });
    }
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Icon(
                  Icons.waving_hand_rounded,
                  size: 56,
                  color: teal,
                ),
                const SizedBox(height: 16),
                const Text(
                  'مرحباً بك في تطبيق الغدير',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: navy,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ملف شخصي قصير — تكدر تعدّله لاحقاً من الإعدادات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF5B6C70),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'الاسم الثلاثي',
                    hintText: 'مثال: محمد علي حسن',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _birthController,
                  keyboardType: TextInputType.datetime,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: 'تاريخ الميلاد / العمر',
                    hintText: 'مثال: 35 أو 1990 أو 1990-06-15',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'الجنس',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: navy,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SexChip(
                        label: 'ذكر',
                        selected: _sex == ProfileSexSelection.male,
                        onTap: () => setState(
                          () => _sex = ProfileSexSelection.male,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SexChip(
                        label: 'أنثى',
                        selected: _sex == ProfileSexSelection.female,
                        onTap: () => setState(
                          () => _sex = ProfileSexSelection.female,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
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
                    child: Text(_saving ? '...' : 'حفظ ومتابعة'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          await _profile.skipOnboarding();
                          if (!mounted) return;
                          widget.onFinished();
                        },
                  child: const Text('تخطي الآن'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SexChip extends StatelessWidget {
  const _SexChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0FAFA3);
    return Material(
      color: selected ? teal : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? teal : const Color(0xFFD0DADF),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : const Color(0xFF123B42),
            ),
          ),
        ),
      ),
    );
  }
}
