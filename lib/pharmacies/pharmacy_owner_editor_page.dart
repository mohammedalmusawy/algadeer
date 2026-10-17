import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../doctors/doctor_card_access_client.dart';
import '../doctors/owner_password_change_dialog.dart';
import '../widgets/clinic_app_bar.dart';
import '../widgets/entity_optional_logo.dart';
import 'pharmacies_store.dart';
import 'pharmacy_bundles_manage_page.dart';
import 'pharmacy_models.dart';

/// حقول الصيدلية المسموحة. الخادم يوافق على اللقطة ثم تُحفظ محليًا.
class PharmacyOwnerEditorPage extends StatefulWidget {
  const PharmacyOwnerEditorPage({
    super.key,
    required this.pharmacy,
    required this.session,
  });

  final PharmacyItem pharmacy;
  final DoctorCardSession session;

  @override
  State<PharmacyOwnerEditorPage> createState() => _PharmacyOwnerEditorPageState();
}

class _PharmacyOwnerEditorPageState extends State<PharmacyOwnerEditorPage> {
  final _client = DoctorCardAccessClient();
  late final TextEditingController _slogan;
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _image;
  late final TextEditingController _logo;
  bool _saving = false;
  late int _revision;

  bool get _admin => widget.session.isAdmin;

  @override
  void initState() {
    super.initState();
    final p = widget.pharmacy;
    _slogan = TextEditingController(text: p.slogan);
    _from = TextEditingController(text: p.openFrom);
    _to = TextEditingController(text: p.openTo);
    _phone = TextEditingController(text: p.phone);
    _whatsapp = TextEditingController(text: p.whatsapp);
    _image = TextEditingController(text: p.imageUrl);
    _logo = TextEditingController(text: p.logoUrl);
    _revision = p.contentRevision;
  }

  @override
  void dispose() {
    _slogan.dispose();
    _from.dispose();
    _to.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _image.dispose();
    _logo.dispose();
    super.dispose();
  }

  Future<String> _hosted(String value, {bool entityPhoto = false}) async {
    if (!value.startsWith('data:')) return value;
    final comma = value.indexOf(',');
    if (comma < 0) {
      throw const DoctorCardAccessException('الصورة غير مقبولة.');
    }
    final url = await _client.uploadPharmacyAsset(
      session: widget.session,
      bytes: Uint8List.fromList(base64Decode(value.substring(comma + 1))),
      entityPhoto: entityPhoto,
      baseRevision: entityPhoto ? _revision : null,
    );
    if (entityPhoto) _revision += 1;
    return url;
  }

  Future<void> _pickEntityPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // صورة الكاميرا الكاملة (٤٠٠٠px) تبطّئ التحميل عند الكل.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final url = await _client.uploadPharmacyAsset(
      session: widget.session,
      bytes: bytes,
      entityPhoto: true,
      baseRevision: _revision,
    );
    _revision += 1;
    if (!mounted) return;
    setState(() => _image.text = url);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final fields = <String, dynamic>{};
      if (_admin || widget.session.allows('bio')) {
        fields['slogan'] = _slogan.text.trim();
      }
      if (_admin || widget.session.allows('hours')) {
        fields['openFrom'] = _from.text.trim();
        fields['openTo'] = _to.text.trim();
      }
      if (_admin || widget.session.allows('contacts')) {
        fields['phone'] = _phone.text.trim();
        fields['whatsapp'] = _whatsapp.text.trim();
      }
      if (_admin || widget.session.allows('image')) {
        fields['imageUrl'] = await _hosted(_image.text.trim(), entityPhoto: true);
        fields['logoUrl'] = await _hosted(_logo.text.trim());
        _image.text = fields['imageUrl']?.toString() ?? '';
        _logo.text = fields['logoUrl']?.toString() ?? '';
      }
      if (fields.isNotEmpty) {
        await _client.updateFields(
          session: widget.session,
          fields: fields,
          baseRevision: _revision,
        );
        final current = widget.pharmacy;
        await PharmaciesStore.instance.cachePublished(
          current.copyWith(
            slogan: fields['slogan']?.toString(),
            openFrom: fields['openFrom']?.toString(),
            openTo: fields['openTo']?.toString(),
            phone: fields['phone']?.toString(),
            whatsapp: fields['whatsapp']?.toString(),
            imageUrl: fields['imageUrl']?.toString(),
            logoUrl: fields['logoUrl']?.toString(),
            contentRevision: _revision + 1,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر التعديلات لكل الزوار')),
      );
      Navigator.pop(context, true);
    } on DoctorCardAccessException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(title: Text(widget.pharmacy.name)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'صلاحياتك تخص هذه الصيدلية فقط. الحفظ الناجح يظهر للزوار على كل الأجهزة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, height: 1.35),
            ),
            const SizedBox(height: 12),
            if (_admin || widget.session.allows('image')) ...[
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickEntityPhoto,
                icon: const Icon(Icons.photo_outlined),
                label: const Text('رفع صورة الصيدلية'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _image,
                decoration: const InputDecoration(
                  labelText: 'رابط الصورة',
                  border: OutlineInputBorder(),
                ),
              ),
              EntityLogoAdminField(
                logoUrl: _logo.text,
                folder: 'pharmacies',
                entityId: widget.pharmacy.id,
                onChanged: (value) => setState(() => _logo.text = value),
                upload: (bytes, _) => _client.uploadPhoto(
                  session: widget.session,
                  bytes: bytes,
                  baseRevision: _revision,
                  logo: true,
                ),
              ),
            ],
            if (_admin || widget.session.allows('bio')) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _slogan,
                decoration: const InputDecoration(
                  labelText: 'الشعار',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_admin || widget.session.allows('hours')) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _from,
                decoration: const InputDecoration(
                  labelText: 'يفتح من',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _to,
                decoration: const InputDecoration(
                  labelText: 'يغلق عند',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_admin || widget.session.allows('contacts')) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'الهاتف',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _whatsapp,
                decoration: const InputDecoration(
                  labelText: 'واتساب',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
            ),
            if (!_admin) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => showOwnerPasswordChangeDialog(
                  context: context,
                  session: widget.session,
                  client: _client,
                ),
                child: const Text('تغيير كلمة المرور'),
              ),
            ],
            if (_admin ||
                widget.session.allows('products') ||
                widget.session.allows('packages_add') ||
                widget.session.allows('packages_edit') ||
                widget.session.allows('packages_delete')) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PharmacyBundlesManagePage(
                        pharmacyId: widget.pharmacy.id,
                        ownerSession: widget.session,
                      ),
                    ),
                  );
                },
                child: const Text('الباقات'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
