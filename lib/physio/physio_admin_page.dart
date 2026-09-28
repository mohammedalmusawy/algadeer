import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import '../models/entity_social_links.dart';
import '../pharmacies/pharmacy_fit_image.dart';
import '../widgets/clinic_app_bar.dart';
import '../widgets/entity_social_sheet.dart';
import 'physio_models.dart';
import 'physio_store.dart';

/// إدارة مراكز العلاج الطبيعي — محلي.
class PhysioAdminPage extends StatefulWidget {
  const PhysioAdminPage({super.key});

  @override
  State<PhysioAdminPage> createState() => _PhysioAdminPageState();
}

class _PhysioAdminPageState extends State<PhysioAdminPage> {
  final _store = PhysioStore.instance;
  bool _loading = true;
  List<PhysioCenter> _items = const [];

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

  Future<void> _edit(PhysioCenter? existing) async {
    final result = await Navigator.push<PhysioCenter>(
      context,
      MaterialPageRoute(builder: (_) => _PhysioEditPage(initial: existing)),
    );
    if (result == null) return;
    await _store.upsert(result);
    await _reload();
  }

  Future<void> _toggleActive(PhysioCenter p) async {
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
          title: const Text('إدارة العلاج الطبيعي'),
          backgroundColor: GhadeerHomeColors.physioAccent,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(null),
          backgroundColor: GhadeerHomeColors.physioAccent,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة مركز'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: _items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return const Text(
                      'التعديلات تُحفظ على هذا الجهاز. '
                      'الافتراضي يظهر تلقائياً ويمكنك الإخفاء أو التعديل.',
                      style: TextStyle(
                        color: GhadeerHomeColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    );
                  }
                  final p = _items[i - 1];
                  return Material(
                    color: const Color(0xFFEEF8F2),
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
                        '${p.address}\n${p.isActive ? 'ظاهر' : 'مخفي'} · '
                        '${p.services.length} خدمة · '
                        '${p.isOpenNow ? 'مفتوح' : 'مغلق'}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: p.isActive
                                ? 'إخفاء المركز كاملاً'
                                : 'إظهار المركز',
                            onPressed: () => _toggleActive(p),
                            icon: Icon(
                              p.isActive
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          IconButton(
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

class _PhysioEditPage extends StatefulWidget {
  const _PhysioEditPage({this.initial});
  final PhysioCenter? initial;

  @override
  State<_PhysioEditPage> createState() => _PhysioEditPageState();
}

class _PhysioEditPageState extends State<_PhysioEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _slogan;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final TextEditingController _image;
  late final TextEditingController _description;
  late final TextEditingController _services;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _website;
  late final TextEditingController _instagram;
  late final TextEditingController _facebook;
  late final TextEditingController _tiktok;
  late final TextEditingController _telegram;
  late bool _open;
  late bool _active;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _slogan =
        TextEditingController(text: p?.slogan ?? 'حركة أفضل لحياة أفضل');
    _address = TextEditingController(text: p?.address ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _whatsapp = TextEditingController(text: p?.whatsapp ?? '');
    _from = TextEditingController(text: p?.openFrom ?? '9:00 صباحاً');
    _to = TextEditingController(text: p?.openTo ?? '8:00 مساءً');
    _image = TextEditingController(text: p?.imageUrl ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _services = TextEditingController(
      text: (p?.services ?? const []).join('، '),
    );
    _lat = TextEditingController(
      text: p?.latitude == null ? '' : '${p!.latitude}',
    );
    _lng = TextEditingController(
      text: p?.longitude == null ? '' : '${p!.longitude}',
    );
    _website = TextEditingController(text: p?.social.website ?? '');
    _instagram = TextEditingController(text: p?.social.instagram ?? '');
    _facebook = TextEditingController(text: p?.social.facebook ?? '');
    _tiktok = TextEditingController(text: p?.social.tiktok ?? '');
    _telegram = TextEditingController(text: p?.social.telegram ?? '');
    _open = p?.isOpenNow ?? true;
    _active = p?.isActive ?? true;
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
    _description.dispose();
    _services.dispose();
    _lat.dispose();
    _lng.dispose();
    _website.dispose();
    _instagram.dispose();
    _facebook.dispose();
    _tiktok.dispose();
    _telegram.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final dataUrl = await PharmacyImageHelper.pickFromDevice();
      if (dataUrl == null || !mounted) return;
      setState(() => _image.text = dataUrl);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اسم المركز مطلوب')),
      );
      return;
    }
    final services = _services.text
        .split(RegExp(r'[،,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final id = widget.initial?.id ??
        'ph_${DateTime.now().millisecondsSinceEpoch}';
    final item = PhysioCenter(
      id: id,
      name: name,
      slogan: _slogan.text.trim().isEmpty
          ? 'حركة أفضل لحياة أفضل'
          : _slogan.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      whatsapp: _whatsapp.text.trim().isEmpty
          ? _phone.text.trim()
          : _whatsapp.text.trim(),
      services: services.isEmpty ? const ['علاج طبيعي'] : services,
      openFrom: _from.text.trim(),
      openTo: _to.text.trim(),
      isOpenNow: _open,
      imageUrl: _image.text.trim(),
      description: _description.text.trim(),
      latitude: double.tryParse(_lat.text.trim()),
      longitude: double.tryParse(_lng.text.trim()),
      isActive: _active,
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
          title: Text(widget.initial == null ? 'إضافة مركز' : 'تعديل مركز'),
          backgroundColor: GhadeerHomeColors.physioAccent,
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _field(_name, 'اسم المركز'),
                _field(_slogan, 'الشعار الفرعي'),
                _field(_address, 'العنوان'),
                _field(_phone, 'الهاتف'),
                _field(_whatsapp, 'واتساب'),
                _field(_from, 'من الساعة'),
                _field(_to, 'إلى الساعة'),
                _field(
                  _services,
                  'الخدمات (افصل بفاصلة: تأهيل، آلام ظهر، …)',
                ),
                _field(_description, 'نبذة'),
                _field(_lat, 'خط العرض (اختياري)'),
                _field(_lng, 'خط الطول (اختياري)'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _image.text.trim().isEmpty
                            ? const ColoredBox(
                                color: Color(0xFFE8F8F0),
                                child: Icon(Icons.add_photo_alternate_outlined),
                              )
                            : PharmacyFitImage(
                                source: _image.text,
                                width: 72,
                                height: 72,
                                borderRadius: 12,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _image.text.trim().isEmpty
                              ? 'رفع صورة'
                              : 'تغيير الصورة',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                EntitySocialAdminFields(
                  website: _website,
                  instagram: _instagram,
                  facebook: _facebook,
                  tiktok: _tiktok,
                  telegram: _telegram,
                ),
                SwitchListTile(
                  title: const Text('مفتوح الآن'),
                  value: _open,
                  onChanged: (v) => setState(() => _open = v),
                ),
                SwitchListTile(
                  title: const Text('ظاهر في التطبيق'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: GhadeerHomeColors.physioAccent,
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

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: label == 'نبذة' ? 3 : 1,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
