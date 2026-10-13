import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../doctors/doctor_card_access_client.dart';
import '../doctors/owner_password_change_dialog.dart';
import 'clinic_app_bar.dart';
import 'entity_optional_logo.dart';

/// بيانات بطاقة يعدّلها مالكها (الأشعة، العلاج الطبيعي، التجهيزات).
/// نفس حقول المراكز: الحفظ يمر عبر Edge Function لهذه البطاقة فقط.
class OwnerCardData {
  const OwnerCardData({
    required this.id,
    required this.name,
    required this.contentRevision,
    required this.logoFolder,
    this.bio = '',
    this.services = const [],
    this.supportsServices = true,
    this.servicesLabel = 'الخدمات، سطر لكل خدمة',
    this.hours = '',
    this.openFrom = '',
    this.openTo = '',
    this.splitHours = false,
    this.phone = '',
    this.whatsapp = '',
    this.address = '',
    this.mapUrl = '',
    this.supportsMapUrl = true,
    this.logoUrl = '',
  });

  final String id;
  final String name;
  final int contentRevision;

  /// مجلد الشعار بـ clinic-media (radiology / physio / supplies).
  final String logoFolder;
  final String bio;
  final List<String> services;
  final bool supportsServices;
  final String servicesLabel;

  /// نص الدوام الحر (الأشعة).
  final String hours;

  /// يفتح / يسد (العلاج الطبيعي والتجهيزات) — ينرسل «من - إلى».
  final String openFrom;
  final String openTo;
  final bool splitHours;
  final String phone;
  final String whatsapp;
  final String address;
  final String mapUrl;
  final bool supportsMapUrl;
  final String logoUrl;
}

/// يبني حقول الحفظ من المدخلات حسب الصلاحيات (منفصلة حتى تُختبر).
Map<String, dynamic> ownerCardFields({
  required bool Function(String) allows,
  required OwnerCardData card,
  required String logoUrl,
  required String bio,
  required String services,
  required String hours,
  required String openFrom,
  required String openTo,
  required String phone,
  required String whatsapp,
  required String address,
  required String mapUrl,
}) {
  final fields = <String, dynamic>{};
  if (allows('image')) fields['logoUrl'] = logoUrl.trim();
  if (allows('bio')) fields['bio'] = bio.trim();
  if (allows('services') && card.supportsServices) {
    fields['services'] = [
      for (final line in services.split(RegExp(r'[\n,،]')))
        if (line.trim().isNotEmpty) line.trim(),
    ];
  }
  if (allows('hours')) {
    if (card.splitHours) {
      final from = openFrom.trim();
      final to = openTo.trim();
      fields['hours'] = to.isEmpty ? from : '$from - $to';
    } else {
      fields['hours'] = hours.trim();
    }
  }
  if (allows('contacts')) {
    fields['phone'] = phone.trim();
    fields['whatsapp'] = whatsapp.trim();
  }
  if (allows('location')) {
    fields['address'] = address.trim();
    if (card.supportsMapUrl) fields['mapUrl'] = mapUrl.trim();
  }
  return fields;
}

class DirectoryOwnerEditorPage extends StatefulWidget {
  const DirectoryOwnerEditorPage({
    super.key,
    required this.card,
    required this.session,
  });

  final OwnerCardData card;
  final DoctorCardSession session;

  @override
  State<DirectoryOwnerEditorPage> createState() =>
      _DirectoryOwnerEditorPageState();
}

class _DirectoryOwnerEditorPageState extends State<DirectoryOwnerEditorPage> {
  final _client = DoctorCardAccessClient();
  late final _bio = TextEditingController(text: widget.card.bio);
  late final _services = TextEditingController(
    text: widget.card.services.join('\n'),
  );
  late final _hours = TextEditingController(text: widget.card.hours);
  late final _openFrom = TextEditingController(text: widget.card.openFrom);
  late final _openTo = TextEditingController(text: widget.card.openTo);
  late final _phone = TextEditingController(text: widget.card.phone);
  late final _whatsapp = TextEditingController(text: widget.card.whatsapp);
  late final _address = TextEditingController(text: widget.card.address);
  late final _map = TextEditingController(text: widget.card.mapUrl);
  late String _logoUrl = widget.card.logoUrl;
  Uint8List? _imageBytes;
  bool _saving = false;

  bool allows(String key) => widget.session.allows(key);

  @override
  void dispose() {
    for (final c in [
      _bio,
      _services,
      _hours,
      _openFrom,
      _openTo,
      _phone,
      _whatsapp,
      _address,
      _map,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
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
      var revision = widget.card.contentRevision;
      if (_imageBytes != null && allows('image')) {
        await _client.uploadPhoto(
          session: widget.session,
          bytes: _imageBytes!,
          baseRevision: revision,
        );
        revision += 1;
      }
      final fields = ownerCardFields(
        allows: allows,
        card: widget.card,
        logoUrl: _logoUrl,
        bio: _bio.text,
        services: _services.text,
        hours: _hours.text,
        openFrom: _openFrom.text,
        openTo: _openTo.text,
        phone: _phone.text,
        whatsapp: _whatsapp.text,
        address: _address.text,
        mapUrl: _map.text,
      );
      if (fields.isNotEmpty) {
        await _client.updateFields(
          session: widget.session,
          fields: fields,
          baseRevision: revision,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انحفظت التعديلات وتطلع للكل')),
      );
      Navigator.pop(context, true);
    } on DoctorCardAccessException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    if (widget.session.isAdmin) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: ClinicAppBar(title: Text(card.name)),
          body: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'الإدارة العامة تعدّل البطاقة من شاشة الإدارة. هذه الشاشة لصاحب البطاقة فقط.',
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
        appBar: ClinicAppBar(title: Text(card.name)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'صلاحياتك تخص هذه البطاقة فقط',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (allows('image')) ...[
              TextButton.icon(
                key: const Key('owner-pick-image'),
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_outlined),
                label: Text(
                  _imageBytes == null ? 'تغيير الصورة' : 'تم اختيار صورة',
                ),
              ),
              EntityLogoAdminField(
                logoUrl: _logoUrl,
                folder: card.logoFolder,
                entityId: card.id,
                onChanged: (value) => setState(() => _logoUrl = value),
                upload: (bytes, _) => _client.uploadPhoto(
                  session: widget.session,
                  bytes: bytes,
                  baseRevision: card.contentRevision,
                  logo: true,
                ),
              ),
            ],
            if (allows('bio')) _field(_bio, 'النبذة', 'owner-bio', lines: 3),
            if (allows('services') && card.supportsServices)
              _field(_services, card.servicesLabel, 'owner-services', lines: 4),
            if (allows('hours'))
              if (card.splitHours)
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _openFrom,
                        'يفتح الساعة',
                        'owner-open-from',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _field(_openTo, 'يسد الساعة', 'owner-open-to'),
                    ),
                  ],
                )
              else
                _field(_hours, 'الدوام', 'owner-hours', lines: 2),
            if (allows('contacts')) ...[
              _field(_phone, 'الهاتف', 'owner-phone'),
              _field(_whatsapp, 'واتساب', 'owner-whatsapp'),
            ],
            if (allows('location')) ...[
              _field(_address, 'العنوان', 'owner-address'),
              if (card.supportsMapUrl) _field(_map, 'رابط الموقع', 'owner-map'),
            ],
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('owner-save'),
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

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: Key(key),
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
