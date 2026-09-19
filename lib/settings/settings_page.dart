import 'package:flutter/material.dart';

import '../companion/personal_companion_profile.dart';
import '../companion/personal_profile_foundation.dart';
import '../services/user_profile_service.dart';
import '../voice/voice_settings_page.dart';
import '../widgets/clinic_app_bar.dart';

/// إعدادات المستخدم العامة — الملف الشخصي الأساسي + المساعد الذكي.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _profile = UserProfileService();
  String? _name;
  String? _birthLabel;
  ProfileSexSelection? _sex;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _profile.getDisplayName();
    final p = await _profile.companion.loadProfile();
    String? birthLabel;
    if (p?.birthDate != null) {
      final d = p!.birthDate!;
      birthLabel =
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    } else if (p?.birthYear != null) {
      birthLabel = 'سنة ${p!.birthYear}';
    }
    if (!mounted) return;
    setState(() {
      _name = name;
      _birthLabel = birthLabel;
      _sex = p?.sexSelection;
      _loading = false;
    });
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('الاسم الثلاثي'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'مثال: محمد علي حسن',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0FAFA3),
                ),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    if (result.isEmpty) {
      await _profile.saveDisplayName(null);
    } else {
      await _profile.saveDisplayName(result);
    }
    await _load();
  }

  Future<void> _editBirth() async {
    final controller = TextEditingController(text: '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تاريخ الميلاد / العمر'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '35 أو 1990 أو 1990-06-15',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0FAFA3),
                ),
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    final parsed = PersonalProfileFoundation.parseBirthOrAgeInput(result);
    if (parsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قيمة غير صالحة للعمر/الميلاد')),
      );
      return;
    }
    try {
      if (parsed.birthDate != null) {
        await _profile.companion.setBirthDate(parsed.birthDate);
      } else if (parsed.birthYear != null) {
        await _profile.companion.setBirthYear(parsed.birthYear);
      } else if (parsed.ageYears != null) {
        final y = DateTime.now().year - parsed.ageYears!;
        await _profile.companion.setBirthYear(y);
      }
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ الميلاد/العمر')),
      );
    }
  }

  Future<void> _editSex() async {
    final result = await showDialog<ProfileSexSelection>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('الجنس'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('ذكر'),
                  onTap: () => Navigator.pop(ctx, ProfileSexSelection.male),
                ),
                ListTile(
                  title: const Text('أنثى'),
                  onTap: () => Navigator.pop(ctx, ProfileSexSelection.female),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == null) return;
    await _profile.companion.setSexSelection(result);
    await _load();
  }

  String get _sexLabel {
    switch (_sex) {
      case ProfileSexSelection.male:
        return 'ذكر';
      case ProfileSexSelection.female:
        return 'أنثى';
      case ProfileSexSelection.preferNotToSpecify:
        return 'أفضل عدم التحديد';
      case null:
        return 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0FAFA3);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('الإعدادات'),
          backgroundColor: teal,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE6F8F6),
                        child: Icon(Icons.badge_outlined, color: teal),
                      ),
                      title: const Text(
                        'الاسم الثلاثي',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        (_name == null || _name!.isEmpty)
                            ? 'غير محدد'
                            : _name!,
                      ),
                      trailing: const Icon(Icons.edit_rounded),
                      onTap: _editName,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE6F8F6),
                        child: Icon(Icons.cake_outlined, color: teal),
                      ),
                      title: const Text(
                        'تاريخ الميلاد / العمر',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(_birthLabel ?? 'غير محدد'),
                      trailing: const Icon(Icons.edit_rounded),
                      onTap: _editBirth,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE6F8F6),
                        child: Icon(Icons.wc_outlined, color: teal),
                      ),
                      title: const Text(
                        'الجنس',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(_sexLabel),
                      trailing: const Icon(Icons.edit_rounded),
                      onTap: _editSex,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE6F8F6),
                        child: Icon(
                          Icons.record_voice_over_rounded,
                          color: teal,
                        ),
                      ),
                      title: const Text(
                        'المساعد الذكي',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: const Text('نوع الصوت + الرد تلقائي/يدوي'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VoiceSettingsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
