import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/ghadeer_tokens.dart';
import '../utils/clinic_contact_message.dart';
import '../widgets/clinic_app_bar.dart';
import 'whatsapp_templates.dart';

/// لوحة الإدارة: نصوص رسائل الواتساب (حجز، استفسار) والنموذج الافتراضي لكل قسم.
///
/// الكتابة تمر عبر سياسة is_clinic_admin() بسوبربيس. التطبيق يضيف اسم
/// المراجع بس — النص كله بيد الإدارة.
class WhatsAppTemplatesAdminPage extends StatefulWidget {
  const WhatsAppTemplatesAdminPage({super.key});

  @override
  State<WhatsAppTemplatesAdminPage> createState() =>
      _WhatsAppTemplatesAdminPageState();
}

class _WhatsAppTemplatesAdminPageState
    extends State<WhatsAppTemplatesAdminPage> {
  bool _loading = true;
  String? _error;
  WhatsAppTemplateCatalog _catalog = WhatsAppTemplateCatalog.builtIn;
  final Map<String, TextEditingController> _bodies = {};
  final Map<WhatsAppSection, String> _defaults = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _bodies.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final t = await client
          .from(WhatsAppTemplateRepository.templatesTable)
          .select('key,title,body,sort_order,is_active');
      final d = await client
          .from(WhatsAppTemplateRepository.defaultsTable)
          .select('section,template_key');
      _catalog = WhatsAppTemplateCatalog.fromRows(
        templateRows: List<Map<String, dynamic>>.from(t),
        defaultRows: List<Map<String, dynamic>>.from(d),
      );
    } catch (e) {
      _error =
          'ما گدرنا نجيب النماذج من السيرفر. تأكد إن ملف '
          'whatsapp_message_templates_schema.sql مطبّق، وبعدها اسحب للتحديث.';
      _catalog = WhatsAppTemplateCatalog.builtIn;
    }
    for (final c in _bodies.values) {
      c.dispose();
    }
    _bodies
      ..clear()
      ..addEntries(
        _catalog.active.map(
          (t) => MapEntry(t.key, TextEditingController(text: t.body)),
        ),
      );
    _defaults
      ..clear()
      ..addAll({
        for (final s in WhatsAppSection.values) s: _catalog.templateFor(s).key,
      });
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    for (final e in _bodies.entries) {
      final body = e.value.text.trim();
      if (body.isEmpty || body.length > 600) {
        _toast('نص «${_titleOf(e.key)}» لازم يكون بين حرف و٦٠٠ حرف.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      for (final t in _catalog.active) {
        await client.from(WhatsAppTemplateRepository.templatesTable).upsert({
          'key': t.key,
          'title': t.title,
          'body': _bodies[t.key]!.text.trim(),
          'sort_order': t.sortOrder,
          'is_active': true,
        });
      }
      await client.from(WhatsAppTemplateRepository.defaultsTable).upsert([
        for (final e in _defaults.entries)
          {'section': e.key.dbValue, 'template_key': e.value},
      ]);
      WhatsAppTemplateRepository.invalidate();
      _toast('انحفظت رسائل الواتساب.');
    } catch (e) {
      _toast('ما انحفظ. تأكد إنك داخل بحساب الإدارة والنت شغّال.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _titleOf(String key) => _catalog.byKey(key)?.title ?? key;

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _preview(String key) {
    final body = _bodies[key]?.text ?? '';
    return ClinicContactMessage.render(
      template: body,
      patientFullName: 'محمد علي حسين',
      providerTitle: 'علي ناصر السعيدي',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const ClinicAppBar(title: Text('رسائل الواتساب')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: GhadeerTokens.card(
                          color: GhadeerTokens.warnWash,
                          border: GhadeerTokens.warnWash,
                        ),
                        child: Text(
                          _error!,
                          style: GhadeerTokens.caption.copyWith(
                            color: GhadeerTokens.warn,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      'المتغيّرات: {اسم} اسم المراجع الثلاثي، و{الجهة} اسم الطبيب '
                      'أو المكان. إذا المراجع ما كاتب اسمه، سطر الاسم يتعدّل لحاله.',
                      style: GhadeerTokens.caption,
                    ),
                    const SizedBox(height: 16),
                    for (final t in _catalog.active) ...[
                      Text(t.title, style: GhadeerTokens.heading),
                      const SizedBox(height: 8),
                      TextField(
                        key: Key('wa_template_${t.key}'),
                        controller: _bodies[t.key],
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 600,
                        onChanged: (_) => setState(() {}),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: GhadeerTokens.card(
                          color: const Color(0xFFE7F6EC),
                          border: const Color(0xFFCFEAD8),
                          radius: GhadeerTokens.radiusMd,
                        ),
                        child: Text(
                          _preview(t.key),
                          style: GhadeerTokens.body.copyWith(fontSize: 13.5),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text(
                      'الرسالة الافتراضية لكل قسم',
                      style: GhadeerTokens.heading,
                    ),
                    const SizedBox(height: 8),
                    for (final s in WhatsAppSection.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.arabicLabel,
                                style: GhadeerTokens.label,
                              ),
                            ),
                            SegmentedButton<String>(
                              key: Key('wa_default_${s.dbValue}'),
                              showSelectedIcon: false,
                              segments: [
                                for (final t in _catalog.active)
                                  ButtonSegment(
                                    value: t.key,
                                    label: Text(t.title),
                                  ),
                              ],
                              selected: {_defaults[s]!},
                              onSelectionChanged: (v) =>
                                  setState(() => _defaults[s] = v.first),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
        bottomNavigationBar: _loading
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  key: const Key('wa_templates_save'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
                ),
              ),
      ),
    );
  }
}
