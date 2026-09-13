import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../branding/ghadeer_brand_mark.dart';
import '../../models/radiology_models.dart';
import '../../widgets/clinic_app_bar.dart';
import '../radiology_default_images.dart';
import '../radiology_service.dart';
import '../widgets/radiology_network_or_asset_image.dart';

class RadiologyFormPage extends StatefulWidget {
  const RadiologyFormPage({super.key, this.center});

  final RadiologyCenter? center;

  @override
  State<RadiologyFormPage> createState() => _RadiologyFormPageState();
}

class _RadiologyFormPageState extends State<RadiologyFormPage> {
  final _service = RadiologyService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _slogan;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _workingHours;
  late final TextEditingController _mapUrl;
  late final TextEditingController _order;
  late final TextEditingController _imageUrl;

  bool _isActive = true;
  bool _isFeatured = false;
  bool _saving = false;
  XFile? _pickedImage;
  Uint8List? _pickedBytes;
  String? _selectedDefaultId;

  bool get _isEditing => widget.center != null;

  @override
  void initState() {
    super.initState();
    final c = widget.center;
    _name = TextEditingController(text: c?.name ?? '');
    _description = TextEditingController(text: c?.description ?? '');
    _slogan = TextEditingController(text: c?.slogan ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _whatsapp = TextEditingController(text: c?.whatsapp ?? '');
    _workingHours = TextEditingController(text: c?.workingHours ?? '');
    _mapUrl = TextEditingController(text: c?.mapUrl ?? '');
    _order = TextEditingController(text: '${c?.displayOrder ?? 0}');
    _imageUrl = TextEditingController(
      text: GhadeerBranding.normalizeEntityImageUrl(c?.imageUrl ?? ''),
    );
    _isActive = c?.isActive ?? true;
    _isFeatured = c?.isFeatured ?? false;
    _selectedDefaultId = RadiologyDefaultImages.matchIdForUrl(
      GhadeerBranding.normalizeEntityImageUrl(c?.imageUrl ?? ''),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _slogan.dispose();
    _address.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _workingHours.dispose();
    _mapUrl.dispose();
    _order.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _pickedImage = image;
      _pickedBytes = bytes;
      _selectedDefaultId = null;
      _imageUrl.text = '';
    });
  }

  void _selectDefault(({String id, String label, String url}) item) {
    setState(() {
      _pickedBytes = null;
      _pickedImage = null;
      _selectedDefaultId = item.id;
      _imageUrl.text = item.url;
    });
  }

  Widget _previewImage() {
    if (_pickedBytes != null) {
      return Image.memory(_pickedBytes!, fit: BoxFit.cover);
    }
    final url = _imageUrl.text.trim();
    if (url.isEmpty) {
      return const Icon(Icons.radar_outlined, size: 48);
    }
    return RadiologyNetworkOrAssetImage(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.radar_outlined, size: 48),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      var imageUrl = _imageUrl.text.trim();
      final oldUrl = widget.center?.imageUrl;

      if (_pickedBytes != null) {
        imageUrl = await _service.uploadCenterImage(
          bytes: _pickedBytes!,
          originalName: _pickedImage?.name ?? 'radiology.jpg',
        );
      }
      if (imageUrl.isEmpty) {
        imageUrl = RadiologyDefaultImages.all
            .firstWhere(
              (e) => e.id != 'rad_ghadeer_logo',
              orElse: () => RadiologyDefaultImages.all.first,
            )
            .url;
      }
      imageUrl = GhadeerBranding.normalizeEntityImageUrl(imageUrl);

      final center = RadiologyCenter(
        id: widget.center?.id ?? '',
        name: _name.text.trim(),
        description: _description.text.trim(),
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        whatsapp: _whatsapp.text.trim(),
        imageUrl: imageUrl,
        isActive: _isActive,
        isFeatured: _isFeatured,
        displayOrder: int.tryParse(_order.text.trim()) ?? 0,
        mapUrl: _mapUrl.text.trim(),
        workingHours: _workingHours.text.trim(),
        slogan: _slogan.text.trim(),
      );

      await _service.upsertCenter(center, existingId: widget.center?.id);

      if (_pickedBytes != null &&
          oldUrl != null &&
          oldUrl.isNotEmpty &&
          oldUrl != imageUrl &&
          RadiologyDefaultImages.matchIdForUrl(oldUrl) == null) {
        await _service.tryDeleteStorageUrl(oldUrl);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: Text(_isEditing ? 'تعديل مركز أشعة' : 'إضافة مركز أشعة'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'صورة المركز',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 120,
                    height: 120,
                    color: const Color(0xFFEAF4F3),
                    child: _previewImage(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('رفع صورة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _pickedBytes = null;
                          _pickedImage = null;
                          _selectedDefaultId = null;
                          _imageUrl.text = '';
                        });
                      },
                      icon: const Icon(Icons.hide_image_outlined),
                      label: const Text('مسح'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('صور افتراضية', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in RadiologyDefaultImages.all)
                    InkWell(
                      onTap: () => _selectDefault(item),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 140,
                        height: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedDefaultId == item.id
                                ? const Color(0xFF0FAFA3)
                                : const Color(0xFFE4EEEE),
                            width: _selectedDefaultId == item.id ? 2.5 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: RadiologyNetworkOrAssetImage(
                          item.url,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _imageUrl,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  GhadeerBranding.applyOfficialLogoToField(
                    _imageUrl,
                    onApplied: () {
                      if (!mounted) return;
                      setState(() {
                        _selectedDefaultId = 'rad_ghadeer_logo';
                        _pickedBytes = null;
                        _pickedImage = null;
                      });
                    },
                  );
                  setState(() {});
                },
                decoration: const InputDecoration(
                  labelText: 'رابط الصورة أو اكتب: لوغو الغدير',
                  hintText: 'لوغو الغدير',
                  helperText:
                      'إذا كتبت «لوغو الغدير» يُستبدل تلقائيًا بالشعار المعتمد',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم المركز'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: _slogan,
                decoration: const InputDecoration(
                  labelText: 'شعار قصير',
                  hintText: 'مثل: مركز أشعة تشخيصية',
                ),
              ),
              TextFormField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'النبذة'),
              ),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'الهاتف'),
              ),
              TextFormField(
                controller: _whatsapp,
                decoration: const InputDecoration(labelText: 'واتساب'),
              ),
              TextFormField(
                controller: _workingHours,
                decoration: const InputDecoration(labelText: 'ساعات العمل'),
              ),
              TextFormField(
                controller: _mapUrl,
                decoration: const InputDecoration(labelText: 'رابط الخريطة'),
              ),
              TextFormField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الترتيب'),
              ),
              SwitchListTile(
                title: const Text('مفعّل'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              SwitchListTile(
                title: const Text('مميز'),
                value: _isFeatured,
                onChanged: (v) => setState(() => _isFeatured = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0FAFA3),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('حفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
