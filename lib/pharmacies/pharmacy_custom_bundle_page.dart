import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import '../widgets/clinic_app_bar.dart';
import 'pharmacy_catalog_bundles.dart';
import 'pharmacy_models.dart';
import 'pharmacy_order_message.dart';

/// اختيار باقة مخصصة من المكملات وإرسالها للصيدلية عبر واتساب.
class PharmacyCustomBundlePage extends StatefulWidget {
  const PharmacyCustomBundlePage({super.key, required this.pharmacy});

  final PharmacyItem pharmacy;

  @override
  State<PharmacyCustomBundlePage> createState() =>
      _PharmacyCustomBundlePageState();
}

class _PharmacyCustomBundlePageState extends State<PharmacyCustomBundlePage> {
  final _selected = <String>{};
  final _custom = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _addCustom() {
    final t = _custom.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _selected.add(t);
      _custom.clear();
    });
  }

  Future<void> _send() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مكمل واحد على الأقل')),
      );
      return;
    }
    setState(() => _sending = true);
    final msg = PharmacyOrderMessage.build(
      pharmacyName: widget.pharmacy.name,
      packageName: 'اختر باقتك بنفسك',
      supplements: _selected.toList()..sort(),
      isCustom: true,
    );
    final ok = await PharmacyOrderMessage.openWhatsApp(
      whatsapp: widget.pharmacy.whatsapp.isNotEmpty
          ? widget.pharmacy.whatsapp
          : widget.pharmacy.phone,
      message: msg,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = PharmacyCatalogBundles.customPickerOptions;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBFC),
        appBar: ClinicAppBar(
          title: const Text('اختر باقتك بنفسك'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'اختر الفيتامينات والمكملات — الرسالة تُرسل لـ ${widget.pharmacy.name} من منصة الغدير.',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GhadeerHomeColors.muted,
                  height: 1.35,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _custom,
                      decoration: InputDecoration(
                        hintText: 'مكمل غير موجود بالقائمة…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addCustom(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _addCustom,
                    style: FilledButton.styleFrom(
                      backgroundColor: GhadeerHomeColors.primary,
                    ),
                    child: const Text('إضافة'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final s = options[i];
                  final on = _selected.contains(s);
                  return CheckboxListTile(
                    value: on,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(s);
                        } else {
                          _selected.remove(s);
                        }
                      });
                    },
                    title: Text(
                      s,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'المحدّد: ${_selected.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: GhadeerHomeColors.primary,
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(
                    _sending ? 'جاري الفتح…' : 'إرسال الطلب للصيدلية',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
