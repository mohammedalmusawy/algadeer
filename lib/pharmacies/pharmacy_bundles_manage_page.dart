import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import '../services/entity_access_pin_service.dart';
import '../widgets/clinic_app_bar.dart';
import 'pharmacies_store.dart';
import 'pharmacy_fit_image.dart';
import 'pharmacy_models.dart';

/// إدارة باقات صيدلية واحدة — بعد اجتياز الرقم السري.
class PharmacyBundlesManagePage extends StatefulWidget {
  const PharmacyBundlesManagePage({super.key, required this.pharmacyId});

  final String pharmacyId;

  @override
  State<PharmacyBundlesManagePage> createState() =>
      _PharmacyBundlesManagePageState();
}

class _PharmacyBundlesManagePageState extends State<PharmacyBundlesManagePage> {
  final _store = PharmaciesStore.instance;
  final _pins = EntityAccessPinService.instance;
  bool _loading = true;
  bool _saving = false;
  PharmacyItem? _pharmacy;
  List<_BundleEditors> _bundles = [];

  String get _entityKey =>
      EntityAccessPinService.pharmacyKey(widget.pharmacyId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pins.clearSession(_entityKey);
    for (final b in _bundles) {
      b.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    await _store.load();
    final p = _store.byId(widget.pharmacyId);
    PharmacyItem? fromCatalog;
    for (final e in PharmaciesCatalog.items) {
      if (e.id == widget.pharmacyId) {
        fromCatalog = e;
        break;
      }
    }
    final pharmacy = p ?? fromCatalog;
    if (!mounted) return;
    if (pharmacy == null) {
      setState(() {
        _loading = false;
        _pharmacy = null;
      });
      return;
    }
    final seed = PharmaciesCatalog.mergeWithCatalog(pharmacy.bundles);
    setState(() {
      _pharmacy = pharmacy;
      _bundles = [for (final b in seed) _BundleEditors.fromBundle(b)];
      _loading = false;
    });
  }

  void _addBundle() {
    setState(() {
      _bundles.add(
        _BundleEditors(
          id: 'b_${DateTime.now().millisecondsSinceEpoch}',
          title: TextEditingController(text: 'باقة جديدة'),
          subtitle: TextEditingController(),
          price: TextEditingController(text: '0'),
          oldPrice: TextEditingController(text: '0'),
          icon: TextEditingController(text: '💊'),
          imageUrl: TextEditingController(),
          note: TextEditingController(),
          isPopular: true,
          isVisible: true,
          supplements: [],
          optionalSupplements: [],
        ),
      );
    });
  }

  void _removeBundle(int index) {
    if (index < 0 || index >= _bundles.length) return;
    setState(() {
      final removed = _bundles.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickImage(_BundleEditors e) async {
    final dataUrl = await PharmacyImageHelper.pickFromDevice();
    if (dataUrl == null || !mounted) return;
    setState(() => e.imageUrl.text = dataUrl);
  }

  Future<void> _save() async {
    final p = _pharmacy;
    if (p == null) return;
    setState(() => _saving = true);
    try {
      final bundles = [for (final e in _bundles) e.toBundle()];
      await _store.upsert(p.copyWith(bundles: bundles));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الباقات')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: ClinicAppBar(
          title: Text(
            _pharmacy == null
                ? 'إدارة الباقات'
                : 'باقات ${_pharmacy!.name}',
          ),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        floatingActionButton: _pharmacy == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _addBundle,
                backgroundColor: GhadeerHomeColors.primary,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة باقة'),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _pharmacy == null
                ? const Center(child: Text('الصيدلية غير موجودة'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      const Text(
                        'يمكنك إخفاء باقة أو تغيير صورتها أو تعديل المكملات. '
                        'الجلسة تبقى حتى تخرج من هذه الشاشة.',
                        style: TextStyle(
                          color: GhadeerHomeColors.muted,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < _bundles.length; i++) ...[
                        _card(i, _bundles[i]),
                        const SizedBox(height: 10),
                      ],
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: GhadeerHomeColors.primary,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(_saving ? 'جاري الحفظ…' : 'حفظ الباقات'),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _card(int index, _BundleEditors e) {
    final hasImage = e.imageUrl.text.trim().isNotEmpty;
    return Material(
      color: e.isVisible ? const Color(0xFFF7FBFC) : const Color(0xFFF0F0F0),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'باقة ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: e.isVisible ? 'إخفاء الباقة' : 'إظهار الباقة',
                  onPressed: () => setState(() => e.isVisible = !e.isVisible),
                  icon: Icon(
                    e.isVisible
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_outlined,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeBundle(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFE74C3C),
                  ),
                ),
              ],
            ),
            _field(e.title, 'عنوان الباقة'),
            _field(e.subtitle, 'وصف قصير'),
            _field(e.price, 'السعر'),
            _field(e.oldPrice, 'السعر القديم'),
            _field(e.icon, 'رمز صغير (إيموجي)'),
            _field(e.note, 'ملاحظة للزبون (اختياري)'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ظاهرة للزبون'),
              subtitle: const Text(
                'الافتراضي ظاهرة — أخفِ فقط إذا لا تريد عرضها',
              ),
              value: e.isVisible,
              onChanged: (v) => setState(() => e.isVisible = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الأكثر رواجاً (تظهر في الشريط)'),
              value: e.isPopular,
              onChanged: (v) => setState(() => e.isPopular = v),
            ),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: hasImage
                        ? PharmacyFitImage(
                            source: e.imageUrl.text,
                            width: 72,
                            height: 72,
                            borderRadius: 12,
                          )
                        : const ColoredBox(
                            color: Color(0xFFE8F6FB),
                            child: Icon(Icons.add_photo_alternate_outlined),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _pickImage(e),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(hasImage ? 'تغيير الصورة' : 'رفع صورة'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _supplementsEditor(
              title: 'المكملات',
              items: e.supplements,
            ),
            const SizedBox(height: 8),
            _supplementsEditor(
              title: 'مكملات اختيارية',
              items: e.optionalSupplements,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSupplement(List<String> items) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مكمل'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اسم المكمل'),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    final t = c.text.trim();
    c.dispose();
    if (ok == true && t.isNotEmpty) {
      setState(() => items.add(t));
    }
  }

  Widget _supplementsEditor({
    required String title,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addSupplement(items),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة'),
            ),
          ],
        ),
        if (items.isEmpty)
          const Text(
            'لا مكملات بعد',
            style: TextStyle(color: GhadeerHomeColors.muted),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < items.length; i++)
                InputChip(
                  label: Text(items[i]),
                  onDeleted: () => setState(() => items.removeAt(i)),
                ),
            ],
          ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _BundleEditors {
  _BundleEditors({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.oldPrice,
    required this.icon,
    required this.imageUrl,
    required this.note,
    required this.isPopular,
    required this.isVisible,
    required this.supplements,
    required this.optionalSupplements,
  });

  factory _BundleEditors.fromBundle(PharmacyBundle b) => _BundleEditors(
        id: b.id,
        title: TextEditingController(text: b.title),
        subtitle: TextEditingController(text: b.subtitle),
        price: TextEditingController(text: '${b.price}'),
        oldPrice: TextEditingController(text: '${b.oldPrice}'),
        icon: TextEditingController(text: b.icon),
        imageUrl: TextEditingController(text: b.imageUrl),
        note: TextEditingController(text: b.note),
        isPopular: b.isPopular,
        isVisible: b.isVisible,
        supplements: List.of(b.supplements),
        optionalSupplements: List.of(b.optionalSupplements),
      );

  final String id;
  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController price;
  final TextEditingController oldPrice;
  final TextEditingController icon;
  final TextEditingController imageUrl;
  final TextEditingController note;
  bool isPopular;
  bool isVisible;
  final List<String> supplements;
  final List<String> optionalSupplements;

  PharmacyBundle toBundle() {
    final titleText = title.text.trim().isEmpty ? 'باقة' : title.text.trim();
    final subs = supplements.map((e) => e.trim()).where((e) => e.isNotEmpty);
    return PharmacyBundle(
      id: id,
      title: titleText,
      subtitle: subtitle.text.trim().isNotEmpty
          ? subtitle.text.trim()
          : subs.take(4).join(' · '),
      price: int.tryParse(price.text.trim()) ?? 0,
      oldPrice: int.tryParse(oldPrice.text.trim()) ?? 0,
      icon: icon.text.trim(),
      imageUrl: imageUrl.text.trim(),
      isPopular: isPopular,
      isVisible: isVisible,
      supplements: supplements
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      optionalSupplements: optionalSupplements
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      note: note.text.trim(),
    );
  }

  void dispose() {
    title.dispose();
    subtitle.dispose();
    price.dispose();
    oldPrice.dispose();
    icon.dispose();
    imageUrl.dispose();
    note.dispose();
  }
}
