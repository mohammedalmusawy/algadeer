import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../doctors/doctor_card_access_client.dart';
import '../doctors/owner_password_change_dialog.dart';
import '../models/lab_models.dart';
import '../widgets/clinic_app_bar.dart';
import 'admin/packages_admin_page.dart';

/// حقول المختبر التي سمح بها المدير. الحفظ يمر عبر Edge Function.
class LabOwnerEditorPage extends StatefulWidget {
  const LabOwnerEditorPage({
    super.key,
    required this.lab,
    required this.session,
  });

  final LabItem lab;
  final DoctorCardSession session;

  @override
  State<LabOwnerEditorPage> createState() => _LabOwnerEditorPageState();
}

class _LabOwnerEditorPageState extends State<LabOwnerEditorPage> {
  final _client = DoctorCardAccessClient();
  late final TextEditingController _description;
  late final TextEditingController _slogan;
  late final TextEditingController _hours;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  Uint8List? _imageBytes;
  bool _saving = false;

  bool get _admin => widget.session.isAdmin;

  @override
  void initState() {
    super.initState();
    final lab = widget.lab;
    _description = TextEditingController(text: lab.description);
    _slogan = TextEditingController(text: lab.slogan);
    _hours = TextEditingController(text: lab.workingHours);
    _phone = TextEditingController(text: lab.phone);
    _whatsapp = TextEditingController(text: lab.whatsapp);
  }

  @override
  void dispose() {
    _description.dispose();
    _slogan.dispose();
    _hours.dispose();
    _phone.dispose();
    _whatsapp.dispose();
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
    setState(() => _saving = true);
    try {
      var revision = widget.lab.contentRevision;
      if (_imageBytes != null && (_admin || widget.session.allows('image'))) {
        await _client.uploadPhoto(
          session: widget.session,
          bytes: _imageBytes!,
          baseRevision: revision,
        );
        revision += 1;
      }
      final fields = <String, dynamic>{};
      if (_admin || widget.session.allows('bio')) {
        fields['description'] = _description.text.trim();
        fields['slogan'] = _slogan.text.trim();
      }
      if (_admin || widget.session.allows('hours')) {
        fields['working_hours'] = _hours.text.trim();
      }
      if (_admin || widget.session.allows('contacts')) {
        fields['phone'] = _phone.text.trim();
        fields['whatsapp'] = _whatsapp.text.trim();
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
        const SnackBar(content: Text('تم حفظ التعديلات')),
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
    final allowPackages = _admin || widget.session.allows('packages');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(title: Text(widget.lab.name)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'صلاحياتك تخص هذا المختبر فقط',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (_admin || widget.session.allows('image'))
              TextButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_outlined),
                label: Text(_imageBytes == null ? 'تغيير الصورة' : 'تم اختيار صورة'),
              ),
            if (_admin || widget.session.allows('bio')) ...[
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'النبذة',
                  border: OutlineInputBorder(),
                ),
              ),
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
                controller: _hours,
                decoration: const InputDecoration(
                  labelText: 'ساعات العمل',
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
            if (allowPackages) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PackagesAdminPage(
                        lockedLabId: widget.lab.id,
                        lockedLabName: widget.lab.name,
                        ownerSession: widget.session,
                      ),
                    ),
                  );
                },
                child: const Text('الباقات والفحوصات والأسعار'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
