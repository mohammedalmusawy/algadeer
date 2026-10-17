import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../doctors/doctor_card_access_client.dart';
import '../doctors/owner_password_change_dialog.dart';
import '../widgets/clinic_app_bar.dart';
import '../widgets/entity_optional_logo.dart';
import 'service_center_models.dart';

/// حقول المركز التي سمحت بها الإدارة. الحفظ يمر عبر Edge Function لهذا المركز فقط.
class ServiceCenterOwnerEditorPage extends StatefulWidget {
  const ServiceCenterOwnerEditorPage({
    super.key,
    required this.center,
    required this.session,
  });

  final ServiceCenter center;
  final DoctorCardSession session;

  @override
  State<ServiceCenterOwnerEditorPage> createState() =>
      _ServiceCenterOwnerEditorPageState();
}

class _ServiceCenterOwnerEditorPageState
    extends State<ServiceCenterOwnerEditorPage> {
  final _client = DoctorCardAccessClient();
  late final TextEditingController _bio;
  late final TextEditingController _services;
  late final TextEditingController _hours;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _address;
  late final TextEditingController _map;
  Uint8List? _imageBytes;
  String _logoUrl = '';
  bool _saving = false;

  bool allows(String key) => widget.session.allows(key);

  @override
  void initState() {
    super.initState();
    final center = widget.center;
    _bio = TextEditingController(text: center.bio);
    _services = TextEditingController(text: center.actualServices.join('\n'));
    _hours = TextEditingController(text: center.hours);
    _phone = TextEditingController(text: center.phone);
    _whatsapp = TextEditingController(text: center.whatsapp);
    _address = TextEditingController(text: center.address);
    _map = TextEditingController(text: center.mapUrl);
    _logoUrl = center.logoUrl;
  }

  @override
  void dispose() {
    _bio.dispose();
    _services.dispose();
    _hours.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _address.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // صورة الكاميرا الكاملة (٤٠٠٠px) تبطّئ التحميل عند الكل.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
  }

  Future<void> _save() async {
    if (widget.session.isAdmin) return;
    setState(() => _saving = true);
    try {
      var revision = widget.center.contentRevision;
      if (_imageBytes != null && allows('image')) {
        await _client.uploadPhoto(
          session: widget.session,
          bytes: _imageBytes!,
          baseRevision: revision,
        );
        revision += 1;
      }
      final fields = <String, dynamic>{};
      if (allows('image')) fields['logoUrl'] = _logoUrl.trim();
      if (allows('bio')) fields['bio'] = _bio.text.trim();
      if (allows('services')) {
        fields['services'] = [
          for (final line in _services.text.split(RegExp(r'[\n,،]')))
            if (line.trim().isNotEmpty) line.trim(),
        ];
      }
      if (allows('hours')) fields['hours'] = _hours.text.trim();
      if (allows('contacts')) {
        fields['phone'] = _phone.text.trim();
        fields['whatsapp'] = _whatsapp.text.trim();
      }
      if (allows('location')) {
        fields['address'] = _address.text.trim();
        fields['mapUrl'] = _map.text.trim();
      }
      if (fields.isNotEmpty) {
        await _client.updateFields(
          session: widget.session,
          fields: fields,
          baseRevision: revision,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تعديلات هذا المركز')),
      );
      Navigator.pop(context, true);
    } on DoctorCardAccessException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.isAdmin) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: ClinicAppBar(title: Text(widget.center.name)),
          body: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'الإدارة العامة تعدّل المركز من شاشة الإدارة. هذه الشاشة لصاحب المركز فقط.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, height: 1.4),
            ),
          ),
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(title: Text(widget.center.name)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'صلاحياتك تخص هذا المركز فقط',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (allows('image')) ...[
              TextButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_outlined),
                label: Text(_imageBytes == null ? 'تغيير الصورة' : 'تم اختيار صورة'),
              ),
              EntityLogoAdminField(
                logoUrl: _logoUrl,
                folder: 'service-centers',
                entityId: widget.center.id,
                onChanged: (value) => setState(() => _logoUrl = value),
                upload: (bytes, _) => _client.uploadPhoto(
                  session: widget.session,
                  bytes: bytes,
                  baseRevision: widget.center.contentRevision,
                  logo: true,
                ),
              ),
            ],
            if (allows('bio')) _field(_bio, 'النبذة', lines: 3),
            if (allows('services'))
              _field(_services, 'الخدمات، سطر لكل خدمة', lines: 4),
            if (allows('hours')) _field(_hours, 'الدوام', lines: 2),
            if (allows('contacts')) ...[
              _field(_phone, 'الهاتف'),
              _field(_whatsapp, 'واتساب'),
            ],
            if (allows('location')) ...[
              _field(_address, 'العنوان'),
              _field(_map, 'رابط الموقع'),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('حفظ'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => showOwnerPasswordChangeDialog(
                        context: context,
                        session: widget.session,
                      ),
              child: const Text('تغيير كلمة المرور'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
