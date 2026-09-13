import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../medical/medical_navigation_service.dart';
import '../search/smart_search_service.dart';
import 'assistant_orchestrator.dart';
import 'voice_response_controller.dart';
import '../widgets/clinic_app_bar.dart';

/// اختبار: Provider → Edge Function → AI → Text + Voice + Medical Navigation
class AssistantIntegrationPage extends StatefulWidget {
  const AssistantIntegrationPage({super.key});

  @override
  State<AssistantIntegrationPage> createState() =>
      _AssistantIntegrationPageState();
}

class _AssistantIntegrationPageState extends State<AssistantIntegrationPage> {
  static const _teal = Color(0xFF0FAFA3);

  final _query = TextEditingController(text: 'طبيب أسنان');
  late final AssistantOrchestrator _orchestrator;
  AssistantReply? _reply;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _orchestrator = AssistantOrchestrator(
      search: SmartSearchService(),
      medical: MedicalNavigationService(),
      voice: VoiceResponseController(),
    );
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _reply = null;
    });
    try {
      final reply = await _orchestrator.processQuery(_query.text);
      if (!mounted) return;
      setState(() {
        _reply = reply;
        _busy = false;
      });
    } catch (e, st) {
      debugPrint('Assistant integration run failed: $e\n$st');
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تشغيل المسار. حاول مرة أخرى.')),
      );
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _orchestrator.voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('اختبار AI + صوت + توجيه'),
          backgroundColor: _teal,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusChip(
              'Edge Function',
              AppConfig.isAiBackendConfigured ? 'مفعّل' : 'غير مفعّل',
              AppConfig.isAiBackendConfigured ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              decoration: const InputDecoration(
                labelText: 'استعلام تجريبي',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _run,
              style: FilledButton.styleFrom(backgroundColor: _teal),
              child: Text(_busy ? 'جاري…' : 'تشغيل المسار الكامل'),
            ),
            if (_reply != null) ...[
              const SizedBox(height: 20),
              Text('المصدر: ${_reply!.source.name}'),
              Text('نتائج محلية: ${_reply!.searchResults.length}'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_reply!.text ?? '—'),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _orchestrator.voice.isSpeaking
                        ? null
                        : () => _orchestrator.speakDemo(_reply!.text ?? ''),
                    child: const Text('نطق الرد'),
                  ),
                  OutlinedButton(
                    onPressed: _orchestrator.voice.stop,
                    child: const Text('إيقاف'),
                  ),
                  OutlinedButton(
                    onPressed: _orchestrator.voice.replay,
                    child: const Text('إعادة'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, String value, Color color) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
