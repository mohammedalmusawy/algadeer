import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../doctors/doctor_card_password_admin_section.dart';
import '../home/ghadeer_home_colors.dart';
import '../services/content_conflict.dart';
import '../widgets/clinic_app_bar.dart';
import '../widgets/entity_optional_logo.dart';
import 'service_center_kind.dart';
import 'service_center_models.dart';
import 'service_centers_store.dart';
import '../theme/ghadeer_tokens.dart';

/// إدارة قسم واحد. الحفظ يكتب في الجدول المشترك، ويفشل بوضوح إن تعذر.
class ServiceCentersAdminPage extends StatefulWidget {
  const ServiceCentersAdminPage({super.key, required this.kind});

  final ServiceCenterKind kind;

  @override
  State<ServiceCentersAdminPage> createState() => _ServiceCentersAdminPageState();
}

class _ServiceCentersAdminPageState extends State<ServiceCentersAdminPage> {
  final _store = ServiceCentersStore.instance;
  bool _loading = true;
  List<ServiceCenter> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await _store.reload();
    if (!mounted) return;
    setState(() {
      _items = serviceCentersForAdmin(
        shared: _store.sharedItems,
        kind: widget.kind,
      );
      _loading = false;
    });
  }

  Future<void> _edit(ServiceCenter? existing) async {
    final result = await Navigator.push<ServiceCenter>(
      context,
      MaterialPageRoute(
        builder: (_) => _ServiceCenterFormPage(
          kind: widget.kind,
          initial: existing,
          nextOrder: _items.isEmpty ? 0 : _items.last.displayOrder + 1,
        ),
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
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لم يُحفظ المركز للزوار. تأكد من جدول service_centers ودخول الإدارة.\n$e',
          ),
        ),
      );
      return;
    }
    await _reload();
  }

  Future<void> _toggle(ServiceCenter center) async {
    try {
      await _store.setActive(center, !center.isActive);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث الظهور.\n$e')),
      );
      return;
    }
    await _reload();
  }

  Future<void> _delete(ServiceCenter center) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المركز'),
          content: Text('هل تريد حذف ${center.name} من الدليل المشترك؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _store.delete(center);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحذف.\n$e')),
      );
      return;
    }
    await _reload();
  }

  Future<void> _move(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    final next = List<ServiceCenter>.of(_items);
    final moved = next.removeAt(index);
    next.insert(target, moved);
    try {
      for (var i = 0; i < next.length; i++) {
        if (next[i].displayOrder != i) {
          await _store.upsert(next[i].copyWith(displayOrder: i));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تغيير الترتيب.\n$e')),
      );
      return;
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _store.sharedReady;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: ClinicAppBar(
          title: Text('إدارة ${widget.kind.sectionTitle}'),
          backgroundColor: GhadeerTokens.mist,
          foregroundColor: GhadeerTokens.ink,
          surfaceTintColor: Colors.transparent,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(null),
          backgroundColor: GhadeerHomeColors.primary,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة مركز'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: _items.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Text(
                      ready
                          ? 'الحفظ يظهر لكل الزوار. الإخفاء هنا يخفي المركز عن الدليل، ولا يغني عن صلاحية الإدارة.'
                          : widget.kind.unavailableMessage,
                      style: TextStyle(
                        color: ready
                            ? GhadeerHomeColors.muted
                            : const Color(0xFFB45309),
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    );
                  }
                  final center = _items[index - 1];
                  return Material(
                    color: const Color(0xFFF7FBFC),
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      title: Text(
                        center.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${center.isActive ? 'ظاهر' : 'مخفي'} · ترتيب ${center.displayOrder}',
                      ),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: 'تقديم',
                            onPressed: index == 1 ? null : () => _move(index - 1, -1),
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                          IconButton(
                            tooltip: 'تأخير',
                            onPressed: index == _items.length
                                ? null
                                : () => _move(index - 1, 1),
                            icon: const Icon(Icons.arrow_downward_rounded),
                          ),
                          IconButton(
                            tooltip: center.isActive ? 'إخفاء' : 'إظهار',
                            onPressed: () => _toggle(center),
                            icon: Icon(
                              center.isActive
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          IconButton(
                            tooltip: 'تعديل',
                            onPressed: () => _edit(center),
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () => _delete(center),
                            icon: const Icon(Icons.delete_outline_rounded),
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

class _ServiceCenterFormPage extends StatefulWidget {
  const _ServiceCenterFormPage({
    required this.kind,
    required this.nextOrder,
    this.initial,
  });

  final ServiceCenterKind kind;
  final ServiceCenter? initial;
  final int nextOrder;

  @override
  State<_ServiceCenterFormPage> createState() => _ServiceCenterFormPageState();
}

class _ServiceCenterFormPageState extends State<_ServiceCenterFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _services;
  late final TextEditingController _hours;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _map;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _order;
  late bool _active;
  late final String _id;
  String _imageUrl = '';
  String _logoUrl = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _bio = TextEditingController(text: initial?.bio ?? '');
    _services = TextEditingController(
      text: initial?.actualServices.join('\n') ?? '',
    );
    _hours = TextEditingController(text: initial?.hours ?? '');
    _address = TextEditingController(text: initial?.address ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _whatsapp = TextEditingController(text: initial?.whatsapp ?? '');
    _map = TextEditingController(text: initial?.mapUrl ?? '');
    _lat = TextEditingController(
      text: initial?.latitude?.toString() ?? '',
    );
    _lng = TextEditingController(
      text: initial?.longitude?.toString() ?? '',
    );
    _order = TextEditingController(
      text: '${initial?.displayOrder ?? widget.nextOrder}',
    );
    _active = initial?.isActive ?? true;
    _id = initial?.id ??
        'sc_${widget.kind.dbValue}_${DateTime.now().microsecondsSinceEpoch}';
    _imageUrl = initial?.imageUrl ?? '';
    _logoUrl = initial?.logoUrl ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _bio,
      _services,
      _hours,
      _address,
      _phone,
      _whatsapp,
      _map,
      _lat,
      _lng,
      _order,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(bool logo) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // صورة الكاميرا الكاملة (٤٠٠٠px) تبطّئ التحميل عند الكل.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    try {
      final url = await ServiceCentersStore.instance.uploadImage(
        centerId: _id,
        bytes: bytes,
        png: picked.name.toLowerCase().endsWith('.png'),
      );
      if (!mounted) return;
      setState(() {
        if (logo) {
          _logoUrl = url;
        } else {
          _imageUrl = url;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفع الصورة.\n$e')),
      );
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم المركز قبل الحفظ.')),
      );
      return;
    }
    setState(() => _saving = true);
    final center = ServiceCenter(
      id: _id,
      kind: widget.kind,
      name: name,
      isActive: _active,
      displayOrder: int.tryParse(_order.text.trim()) ?? widget.nextOrder,
      contentRevision: widget.initial?.contentRevision ?? 0,
      bio: _bio.text.trim(),
      services: parseServiceLines(_services.text),
      hours: _hours.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      whatsapp: _whatsapp.text.trim(),
      imageUrl: _imageUrl.trim(),
      logoUrl: _logoUrl.trim(),
      mapUrl: _map.text.trim(),
      latitude: double.tryParse(_lat.text.trim()),
      longitude: double.tryParse(_lng.text.trim()),
    );
    Navigator.pop(context, center);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: Text(widget.initial == null ? 'مركز جديد' : 'تعديل المركز'),
          backgroundColor: GhadeerTokens.mist,
          foregroundColor: GhadeerTokens.ink,
          surfaceTintColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _field(
              _name,
              widget.kind.nameFieldLabel,
              hint: widget.kind.nameFieldHint,
            ),
            _field(_bio, 'نبذة', lines: 3),
            _field(_services, 'الخدمات، سطر لكل خدمة', lines: 4),
            _field(_hours, 'الدوام', lines: 2),
            _field(_address, 'العنوان'),
            _field(_map, 'رابط الموقع إن وُجد'),
            _field(_phone, 'الهاتف', type: TextInputType.phone),
            _field(_whatsapp, 'واتساب', type: TextInputType.phone),
            Row(
              children: [
                Expanded(child: _field(_lat, 'خط العرض')),
                const SizedBox(width: 8),
                Expanded(child: _field(_lng, 'خط الطول')),
              ],
            ),
            _field(_order, 'ترتيب الظهور', type: TextInputType.number),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ظاهر للزوار'),
              subtitle: const Text('الإخفاء لا يغني عن صلاحية الإدارة'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            if (widget.initial != null && widget.initial!.id.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              EntityOwnerAdminPanel(
                entityType: widget.kind.dbValue,
                entityId: widget.initial!.id,
              ),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pick(false),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_imageUrl.isEmpty ? 'صورة' : 'تغيير الصورة'),
                ),
                EntityLogoAdminField(
                  logoUrl: _logoUrl,
                  folder: 'service-centers',
                  entityId: _id,
                  onChanged: (value) => setState(() => _logoUrl = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('حفظ في الدليل المشترك'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    TextInputType? type,
    String hint = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: type,
        minLines: lines,
        maxLines: lines,
        inputFormatters: type == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint.isEmpty ? null : hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
