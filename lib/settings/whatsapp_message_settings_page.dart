import 'package:flutter/material.dart';

import '../companion/personal_companion_profile_service.dart';
import '../utils/clinic_contact_message.dart';
import '../widgets/clinic_app_bar.dart';
import 'whatsapp_message_settings.dart';

/// تعديل قالب رسالة الواتساب التلقائية (محلي على الجهاز).
class WhatsAppMessageSettingsPage extends StatefulWidget {
  const WhatsAppMessageSettingsPage({super.key, this.service});

  final WhatsAppMessageSettingsService? service;

  @override
  State<WhatsAppMessageSettingsPage> createState() =>
      _WhatsAppMessageSettingsPageState();
}

class _WhatsAppMessageSettingsPageState
    extends State<WhatsAppMessageSettingsPage> {
  static const _teal = Color(0xFF0FAFA3);
  static const _sampleDoctor = 'د. فلان';

  late final WhatsAppMessageSettingsService _service;
  final _controller = TextEditingController();
  String? _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? WhatsAppMessageSettingsService();
    _controller.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final template = await _service.loadTemplate();
    String? name;
    try {
      name = await PersonalCompanionProfileService()
          .preferredNameForPersonalization();
    } catch (_) {
      name = null;
    }
    if (!mounted) return;
    _controller.text = template;
    setState(() {
      _name = name;
      _loading = false;
    });
  }

  void _insertVariable(String variable) {
    final value = _controller.value;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    final text = value.text.replaceRange(start, end, variable);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + variable.length),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    final ok = await _service.saveTemplate(_controller.text);
    if (!mounted) return;
    if (!ok) {
      _snack(
        'النص طويل جدًا (الحد الأقصى ${WhatsAppMessageSettingsService.maxLength} حرف).',
      );
      return;
    }
    final blank = _controller.text.trim().isEmpty;
    if (blank) {
      _controller.text = ClinicContactMessage.defaultTemplate;
      _snack('النص فارغ — رجعت الرسالة الافتراضية.');
      return;
    }
    _snack('تم حفظ رسالة الواتساب.');
  }

  Future<void> _reset() async {
    await _service.resetTemplate();
    if (!mounted) return;
    _controller.text = ClinicContactMessage.defaultTemplate;
    _snack('تم الإرجاع للرسالة الافتراضية.');
  }

  String get _preview => ClinicContactMessage.render(
        template: _controller.text,
        patientFullName: _name,
        providerTitle: _sampleDoctor,
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('رسالة الواتساب'),
          backgroundColor: _teal,
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'هذه الرسالة تُجهَّز تلقائيًا عند فتح واتساب لطبيب أو '
                      'مختبر أو مركز أشعة. تُحفظ على هذا الجهاز فقط.',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('whatsapp_template_field'),
                      controller: _controller,
                      minLines: 5,
                      maxLines: 10,
                      maxLength: WhatsAppMessageSettingsService.maxLength,
                      keyboardType: TextInputType.multiline,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'نص الرسالة',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'اضغط لإدراج متغيّر عند المؤشر:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          key: const ValueKey('insert_name_variable'),
                          label: const Text(ClinicContactMessage.nameVariable),
                          onPressed: () => _insertVariable(
                            ClinicContactMessage.nameVariable,
                          ),
                        ),
                        ActionChip(
                          key: const ValueKey('insert_provider_variable'),
                          label: const Text(
                            ClinicContactMessage.providerVariable,
                          ),
                          onPressed: () => _insertVariable(
                            ClinicContactMessage.providerVariable,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '{اسم} = اسمك (إن لم يوجد يُحذف من الرسالة). '
                      '{طبيب} = اسم الطبيب أو المختبر أو المركز.',
                      style: TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'معاينة',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      key: const ValueKey('whatsapp_template_preview'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F8F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_preview, style: const TextStyle(height: 1.6)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('whatsapp_template_save'),
                      onPressed: _save,
                      style: FilledButton.styleFrom(backgroundColor: _teal),
                      child: const Text('حفظ'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const ValueKey('whatsapp_template_reset'),
                      onPressed: _reset,
                      child: const Text('إرجاع للافتراضي'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
