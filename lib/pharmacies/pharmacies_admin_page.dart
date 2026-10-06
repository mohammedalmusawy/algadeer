import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import '../services/content_conflict.dart';
import '../models/entity_social_links.dart';
import '../doctors/doctor_card_password_admin_section.dart';
import '../widgets/clinic_app_bar.dart';
import '../widgets/entity_access_pin_gate.dart';
import '../widgets/entity_social_sheet.dart';
import 'pharmacies_store.dart';
import 'pharmacy_bundles_manage_page.dart';
import 'pharmacy_fit_image.dart';
import 'pharmacy_models.dart';

/// إدارة الصيدليات — محلي حالياً (SharedPreferences) بدون كسر باقي النظام.
class PharmaciesAdminPage extends StatefulWidget {
  const PharmaciesAdminPage({super.key});

  @override
  State<PharmaciesAdminPage> createState() => _PharmaciesAdminPageState();
}

class _PharmaciesAdminPageState extends State<PharmaciesAdminPage> {
  final _store = PharmaciesStore.instance;
  bool _loading = true;
  List<PharmacyItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await _store.load();
    if (!mounted) return;
    setState(() {
      _items = _store.allForAdmin;
      _loading = false;
    });
  }

  Future<void> _edit(PharmacyItem? existing) async {
    final result = await Navigator.push<PharmacyItem>(
      context,
      MaterialPageRoute(
        builder: (_) => _PharmacyEditPage(initial: existing),
      ),
    );
    if (result == null) return;
    try {
      await _store.upsert(result);
    } on ContentConflictException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(contentConflictMessage)),
      );
      await _edit(result);
      return;
    }
    if (!mounted) return;
    final share = _store.lastShareError;
    if (share != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حُفظت على هذا الجهاز. النشر للزوار لم يكتمل؛ راجع جدول الصيدليات ثم أعد النشر.',
          ),
        ),
      );
    }
    await _reload();
  }

  Future<void> _publishShared() async {
    final error = await _store.publishDeviceCopy();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'نُشرت النسخة المحفوظة على هذا الجهاز لكل الزوار.'
              : 'تعذر نشر بعض الصيدليات. النسخة المحلية ما زالت محفوظة.',
        ),
      ),
    );
    await _reload();
  }

  Future<void> _toggleActive(PharmacyItem p) async {
    await _store.setActive(p.id, !p.isActive);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: ClinicAppBar(
          title: const Text('إدارة الصيدليات'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(null),
          backgroundColor: GhadeerHomeColors.primary,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة صيدلية'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: _items.length + 2,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          PharmaciesStore.instance.sharedCatalogReady &&
                                  !PharmaciesStore.instance.hasSharedCatalog
                              ? 'جدول الصيدليات المنشور فارغ أو بلا صيدليات نشطة، '
                                  'لذلك صفحة الزوار فارغة. انشر النسخة المحفوظة أدناه '
                                  'دون حذف البيانات المحلية.'
                              : 'النسخة المنشورة يراها الزوار على كل الأجهزة. '
                                  'ما يُحفظ هنا يبقى على الجهاز إن تعذر النشر.',
                          style: TextStyle(
                            color: PharmaciesStore.instance.sharedCatalogReady &&
                                    !PharmaciesStore.instance.hasSharedCatalog
                                ? const Color(0xFFB45309)
                                : GhadeerHomeColors.muted,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _publishShared,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('نشر النسخة المحفوظة على هذا الجهاز'),
                        ),
                      ],
                    );
                  }
                  if (i == 1) {
                    return OutlinedButton.icon(
                      onPressed: () => showSetAdminAccessPinDialog(context),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('رقم إدارة إعادة تعيين السرّي'),
                    );
                  }
                  final p = _items[i - 2];
                  return Material(
                    color: const Color(0xFFF7FBFC),
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${p.address}\n${p.isActive ? 'ظاهرة' : 'مخفية'} · '
                        '${p.bundles.length} باقة · '
                        '${p.isOpenNow ? 'مفتوحة' : 'مغلقة'}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: p.isActive
                                ? 'إخفاء الصيدلية كاملة'
                                : 'إظهار الصيدلية',
                            onPressed: () => _toggleActive(p),
                            icon: Icon(
                              p.isActive
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          IconButton(
                            tooltip: 'تعديل',
                            onPressed: () => _edit(p),
                            icon: const Icon(Icons.edit_rounded),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PharmacyEditPage extends StatefulWidget {
  const _PharmacyEditPage({this.initial});
  final PharmacyItem? initial;

  @override
  State<_PharmacyEditPage> createState() => _PharmacyEditPageState();
}

class _PharmacyEditPageState extends State<_PharmacyEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _slogan;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final TextEditingController _image;
  late final TextEditingController _offerPercent;
  late final TextEditingController _offerImage;
  late final TextEditingController _offerIcon;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _instagram;
  late final TextEditingController _facebook;
  late final TextEditingController _tiktok;
  late final TextEditingController _telegram;
  late final TextEditingController _website;
  late bool _open;
  late bool _supplements;
  late bool _active;
  bool _picking = false;
  int _bundleCount = 0;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _slogan = TextEditingController(text: p?.slogan ?? 'صحتك تهمنا دائماً');
    _address = TextEditingController(text: p?.address ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _whatsapp = TextEditingController(text: p?.whatsapp ?? '');
    _from = TextEditingController(text: p?.openFrom ?? '8:00 صباحاً');
    _to = TextEditingController(text: p?.openTo ?? '11:00 مساءً');
    _image = TextEditingController(text: p?.imageUrl ?? '');
    _offerPercent = TextEditingController(
      text: '${p?.offerPercent ?? 20}',
    );
    _offerImage = TextEditingController(text: p?.offerImageUrl ?? '');
    _offerIcon = TextEditingController(text: p?.offerIconUrl ?? '');
    _lat = TextEditingController(
      text: p?.latitude == null ? '' : '${p!.latitude}',
    );
    _lng = TextEditingController(
      text: p?.longitude == null ? '' : '${p!.longitude}',
    );
    _instagram = TextEditingController(text: p?.social.instagram ?? '');
    _facebook = TextEditingController(text: p?.social.facebook ?? '');
    _tiktok = TextEditingController(text: p?.social.tiktok ?? '');
    _telegram = TextEditingController(text: p?.social.telegram ?? '');
    _website = TextEditingController(text: p?.social.website ?? '');
    _open = p?.isOpenNow ?? true;
    _supplements = p?.hasSupplements ?? true;
    _active = p?.isActive ?? true;
    _bundleCount = _resolvedBundles().length;
  }

  @override
  void dispose() {
    _name.dispose();
    _slogan.dispose();
    _address.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _from.dispose();
    _to.dispose();
    _image.dispose();
    _offerPercent.dispose();
    _offerImage.dispose();
    _offerIcon.dispose();
    _lat.dispose();
    _lng.dispose();
    _instagram.dispose();
    _facebook.dispose();
    _tiktok.dispose();
    _telegram.dispose();
    _website.dispose();
    super.dispose();
  }

  List<PharmacyBundle> _resolvedBundles() {
    final id = widget.initial?.id;
    if (id != null && id.isNotEmpty) {
      final fromStore = PharmaciesStore.instance.byId(id);
      if (fromStore != null) return fromStore.bundles;
      return widget.initial!.bundles;
    }
    return const [];
  }

  Future<void> _openPackageWorkflow() async {
    final id = widget.initial?.id.trim() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'احفظ الصيدلية أولاً، ثم افتح الباقات.',
          ),
        ),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PharmacyBundlesManagePage(pharmacyId: id),
      ),
    );
    if (!mounted) return;
    setState(() => _bundleCount = _resolvedBundles().length);
  }

  Future<void> _pickInto(TextEditingController target) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final dataUrl = await PharmacyImageHelper.pickFromDevice();
      if (dataUrl == null || !mounted) return;
      setState(() => target.text = dataUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم ضبط الصورة على قد الموبايل')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر اختيار الصورة: $e')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم الصيدلية مطلوب')),
      );
      return;
    }
    final id = widget.initial?.id ??
        'p_${DateTime.now().millisecondsSinceEpoch}';
    final pct = int.tryParse(_offerPercent.text.trim()) ?? 20;
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final item = PharmacyItem(
      id: id,
      name: name,
      slogan: _slogan.text.trim().isEmpty
          ? 'صحتك تهمنا دائماً'
          : _slogan.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      whatsapp: _whatsapp.text.trim().isEmpty
          ? _phone.text.trim()
          : _whatsapp.text.trim(),
      tags: widget.initial?.tags ??
          const ['أدوية عامة', 'مكملات غذائية'],
      openFrom: _from.text.trim(),
      openTo: _to.text.trim(),
      isOpenNow: _open,
      hasSupplements: _supplements,
      imageUrl: _image.text.trim(),
      logoUrl: widget.initial?.logoUrl ?? '',
      offerPercent: pct.clamp(0, 90),
      offerImageUrl: _offerImage.text.trim(),
      offerIconUrl: _offerIcon.text.trim(),
      // الباقات تُدار عبر المسار التدريجي المنفصل؛ لا تُستبدل من هذا النموذج.
      bundles: _resolvedBundles(),
      latitude: lat ?? widget.initial?.latitude,
      longitude: lng ?? widget.initial?.longitude,
      isActive: _active,
      contentRevision: widget.initial?.contentRevision ?? 1,
      social: EntitySocialLinks(
        website: _website.text.trim(),
        instagram: _instagram.text.trim(),
        facebook: _facebook.text.trim(),
        tiktok: _tiktok.text.trim(),
        telegram: _telegram.text.trim(),
      ),
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: ClinicAppBar(
          title: Text(widget.initial == null ? 'إضافة صيدلية' : 'تعديل صيدلية'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _field(_name, 'اسم الصيدلية'),
                _field(_slogan, 'الشعار الفرعي'),
                _field(_address, 'العنوان'),
                _field(_phone, 'الهاتف'),
                _field(_whatsapp, 'واتساب (مع رمز الدولة إن أمكن)'),
                _field(_from, 'من الساعة'),
                _field(_to, 'إلى الساعة'),
                _imagePickerBlock(
                  label: 'صورة واجهة الصيدلية',
                  controller: _image,
                ),
                const SizedBox(height: 8),
                const Text(
                  'العروض',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: GhadeerHomeColors.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                _field(_offerPercent, 'نسبة الخصم ٪'),
                _imagePickerBlock(
                  label: 'صورة بانر العروض',
                  controller: _offerImage,
                  previewSize: 108,
                ),
                _imagePickerBlock(
                  label: 'أيقونة العروض',
                  controller: _offerIcon,
                  previewSize: 56,
                  circular: true,
                ),
                _field(_lat, 'خط العرض (اختياري — لقريب مني)'),
                _field(_lng, 'خط الطول (اختياري — لقريب مني)'),
                const SizedBox(height: 8),
                EntitySocialAdminFields(
                  website: _website,
                  instagram: _instagram,
                  facebook: _facebook,
                  tiktok: _tiktok,
                  telegram: _telegram,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _openPackageWorkflow,
                  icon: const Icon(Icons.medication_outlined),
                  label: Text(
                    widget.initial == null
                        ? 'الباقات (بعد الحفظ)'
                        : 'الباقات${_bundleCount > 0 ? ' ($_bundleCount)' : ''}',
                  ),
                ),
                SwitchListTile(
                  title: const Text('مفتوحة الآن'),
                  value: _open,
                  onChanged: (v) => setState(() => _open = v),
                ),
                SwitchListTile(
                  title: const Text('تقدم مكملات غذائية'),
                  value: _supplements,
                  onChanged: (v) => setState(() => _supplements = v),
                ),
                SwitchListTile(
                  title: const Text('ظاهرة في التطبيق'),
                  subtitle: const Text(
                    'أطفئها لإخفاء الصيدلية كاملة عن الزبائن',
                  ),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                if (widget.initial != null &&
                    widget.initial!.id.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  EntityOwnerAdminPanel(
                    entityType: 'pharmacy',
                    entityId: widget.initial!.id,
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: GhadeerHomeColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('حفظ'),
                ),
                const SizedBox(height: 24),
              ],
            ),
            if (_picking)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _imagePickerBlock({
    required String label,
    required TextEditingController controller,
    double previewSize = 88,
    bool circular = false,
  }) {
    final has = controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFF7FBFC),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(circular ? 999 : 12),
                    child: SizedBox(
                      width: previewSize,
                      height: previewSize,
                      child: has
                          ? PharmacyFitImage(
                              source: controller.text,
                              borderRadius: circular ? 999 : 12,
                              width: previewSize,
                              height: previewSize,
                            )
                          : ColoredBox(
                              color: const Color(0xFFE8F6FB),
                              child: Icon(
                                circular
                                    ? Icons.eco_rounded
                                    : Icons.add_photo_alternate_outlined,
                                color: GhadeerHomeColors.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _pickInto(controller),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(has ? 'تغيير من الجهاز' : 'رفع من الجهاز'),
                          style: FilledButton.styleFrom(
                            backgroundColor: GhadeerHomeColors.primary,
                          ),
                        ),
                        if (has)
                          TextButton(
                            onPressed: () =>
                                setState(() => controller.clear()),
                            child: const Text('إزالة الصورة'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
