import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';
import '../voice/voice_settings_page.dart';
import '../widgets/clinic_app_bar.dart';

/// إعدادات المستخدم العامة — اسم المستخدم + المساعد الذكي.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _profile = UserProfileService();
  String? _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _profile.getDisplayName();
    if (!mounted) return;
    setState(() {
      _name = name;
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
            title: const Text('اسمك'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'مثال: محمد — اتركه فارغًا لإزالة المناداة',
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
    await _profile.saveDisplayName(result.isEmpty ? null : result);
    await _load();
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
                        'اسمك',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        (_name == null || _name!.isEmpty)
                            ? 'غير محدد — المساعد لن يناديك باسم'
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
