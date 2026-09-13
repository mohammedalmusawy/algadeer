import 'package:flutter/material.dart';

import 'voice_response_controller.dart';
import 'voice_settings.dart';
import '../widgets/clinic_app_bar.dart';

/// إعدادات المساعد الصوتي + اختبار تشغيل / إيقاف / إعادة.
class VoiceSettingsPage extends StatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  State<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends State<VoiceSettingsPage> {
  static const _sampleReply =
      'مرحباً، أنا مساعد عيادة الغدير. يمكنني مساعدتك في البحث عن الأطباء والمختبرات.';

  final VoiceSettingsService _settings = VoiceSettingsService();
  late final VoiceResponseController _voice;

  AssistantVoiceGender _gender = AssistantVoiceGender.male;
  bool _autoPlay = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _voice = VoiceResponseController(settings: _settings);
    _voice.addListener(_onVoiceChanged);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final gender = await _settings.getGender();
    final auto = await _settings.getAutoPlayResponses();
    if (!mounted) return;
    setState(() {
      _gender = gender;
      _autoPlay = auto;
      _loading = false;
    });
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setGender(AssistantVoiceGender value) async {
    await _settings.setGender(value);
    setState(() => _gender = value);
  }

  Future<void> _setAutoPlay(bool value) async {
    await _settings.setAutoPlayResponses(value);
    setState(() => _autoPlay = value);
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceChanged);
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0FAFA3);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('إعدادات المساعد الصوتي'),
          backgroundColor: teal,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: teal))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('صوت المساعد'),
                  Card(
                    child: Column(
                      children: [
                        RadioListTile<AssistantVoiceGender>(
                          title: const Text('ولد'),
                          subtitle: const Text('الصوت الافتراضي'),
                          value: AssistantVoiceGender.male,
                          groupValue: _gender,
                          activeColor: teal,
                          onChanged: (v) {
                            if (v != null) _setGender(v);
                          },
                        ),
                        const Divider(height: 1),
                        RadioListTile<AssistantVoiceGender>(
                          title: const Text('بنت'),
                          value: AssistantVoiceGender.female,
                          groupValue: _gender,
                          activeColor: teal,
                          onChanged: (v) {
                            if (v != null) _setGender(v);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('الرد الصوتي التلقائي'),
                  Card(
                    child: SwitchListTile(
                      title: const Text('تشغيل الرد تلقائياً'),
                      subtitle: Text(
                        _autoPlay
                            ? 'سيُنطق الرد بعد كل إجابة'
                            : 'افتراضي: إيقاف — تشغيل يدوي فقط',
                      ),
                      value: _autoPlay,
                      activeThumbColor: teal,
                      onChanged: _setAutoPlay,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'طبقة TTS مستقلة عن مزود AI — يمكن استبدالها لاحقاً دون تغيير منطق الذكاء.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('اختبار الرد الصوتي'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        Text(
                          _sampleReply,
                          style: const TextStyle(height: 1.5),
                        ),
                        if (_voice.lastError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _voice.lastError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _voice.isSpeaking
                                  ? null
                                  : () => _voice.speak(_sampleReply),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('تشغيل'),
                              style: FilledButton.styleFrom(
                                backgroundColor: teal,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _voice.isSpeaking ? _voice.stop : null,
                              icon: const Icon(Icons.stop_rounded),
                              label: const Text('إيقاف'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _voice.isSpeaking ? null : _voice.replay,
                              icon: const Icon(Icons.replay_rounded),
                              label: const Text('إعادة'),
                            ),
                          ],
                        ),
                        if (_voice.isSpeaking) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(
                            color: teal,
                            backgroundColor: Color(0xFFE6F8F6),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'جاري النطق…',
                            style: TextStyle(color: teal),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                  const SizedBox(height: 16),
                  _sectionTitle('البنية'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _layerRow('STT', 'التعرف على الصوت — منفصل'),
                          _layerRow('AI Logic', 'منطق الإجابة — Edge Function لاحقاً'),
                          _layerRow('TTS', 'تحويل النص إلى صوت — مستقل'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF0FAFA3),
        ),
      ),
    );
  }

  Widget _layerRow(String label, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F8F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0FAFA3),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(detail)),
        ],
      ),
    );
  }
}
