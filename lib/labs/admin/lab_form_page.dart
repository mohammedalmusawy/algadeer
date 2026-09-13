import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../branding/ghadeer_brand_mark.dart';
import '../../models/lab_models.dart';
import '../lab_default_images.dart';
import '../labs_service.dart';
import '../widgets/lab_network_or_asset_image.dart';
import '../../widgets/clinic_app_bar.dart';

class LabFormPage extends StatefulWidget {
  const LabFormPage({super.key, this.lab});

  final LabItem? lab;

  @override
  State<LabFormPage> createState() => _LabFormPageState();
}

class _LabFormPageState extends State<LabFormPage> {
  final _service = LabsService();
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

  bool get _isEditing => widget.lab != null;

  @override
  void initState() {
    super.initState();
    final lab = widget.lab;
    _name = TextEditingController(text: lab?.name ?? '');
    _description = TextEditingController(text: lab?.description ?? '');
    _slogan = TextEditingController(text: lab?.slogan ?? '');
    _address = TextEditingController(text: lab?.address ?? '');
    _phone = TextEditingController(text: lab?.phone ?? '');
    _whatsapp = TextEditingController(text: lab?.whatsapp ?? '');
    _workingHours = TextEditingController(text: lab?.workingHours ?? '');
    _mapUrl = TextEditingController(text: lab?.mapUrl ?? '');
    _order = TextEditingController(text: '${lab?.displayOrder ?? 0}');
    _imageUrl = TextEditingController(
      text: GhadeerBranding.normalizeEntityImageUrl(lab?.imageUrl ?? ''),
    );
    _isActive = lab?.isActive ?? true;
    _isFeatured = lab?.isFeatured ?? false;
    _selectedDefaultId = LabDefaultImages.matchIdForUrl(
      GhadeerBranding.normalizeEntityImageUrl(lab?.imageUrl ?? ''),
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

  void _clearImage() {
    setState(() {
      _pickedBytes = null;
      _pickedImage = null;
      _selectedDefaultId = null;
      _imageUrl.text = '';
    });
  }

  Widget _previewImage() {
    if (_pickedBytes != null) {
      return Image.memory(_pickedBytes!, fit: BoxFit.cover);
    }
    final url = _imageUrl.text.trim();
    if (url.isEmpty) {
      return const Icon(Icons.biotech_rounded, size: 48);
    }
    return LabNetworkOrAssetImage(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.biotech_rounded, size: 48),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      var imageUrl = _imageUrl.text.trim();
      final oldUrl = widget.lab?.imageUrl;

      if (_pickedBytes != null) {
        imageUrl = await _service.uploadLabImage(
          bytes: _pickedBytes!,
          originalName: _pickedImage?.name ?? 'lab.jpg',
        );
      }

      // إن لم تُختر صورة: نحفظ أول افتراضي حتى تظهر في القائمة/الملف.
      if (imageUrl.isEmpty) {
        imageUrl = LabDefaultImages.all.first.url;
      }
      imageUrl = GhadeerBranding.normalizeEntityImageUrl(imageUrl);

      final lab = LabItem(
        id: widget.lab?.id ?? '',
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

      await _service.upsertLab(lab, existingId: widget.lab?.id);

      if (_pickedBytes != null &&
          oldUrl != null &&
          oldUrl.isNotEmpty &&
          oldUrl != imageUrl &&
          LabDefaultImages.matchIdForUrl(oldUrl) == null) {
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
          title: Text(_isEditing ? 'تعديل مختبر' : 'إضافة مختبر'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'صورة المختبر',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF123B42),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ارفع صورة من جهازك أو اختر صورة افتراضية من الأسفل.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF5B6C70)),
              ),
              const SizedBox(height: 12),
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
                      onPressed: _clearImage,
                      icon: const Icon(Icons.hide_image_outlined),
                      label: const Text('مسح'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'صور افتراضية',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: LabDefaultImages.all.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (context, index) {
                  final item = LabDefaultImages.all[index];
                  final selected = _selectedDefaultId == item.id &&
                      _pickedBytes == null;
                  return InkWell(
                    onTap: () => _selectDefault(item),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF0FAFA3)
                              : const Color(0xFFE4EEEE),
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          LabNetworkOrAssetImage(
                            item.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFEAF4F3),
                              alignment: Alignment.center,
                              child: const Icon(Icons.biotech_rounded),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              color: Colors.black54,
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (selected)
                            const Positioned(
                              top: 8,
                              left: 8,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Color(0xFF0FAFA3),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _imageUrl,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  GhadeerBranding.applyOfficialLogoToField(
                    _imageUrl,
                    onApplied: () {
                      if (!mounted) return;
                      setState(() {
                        _selectedDefaultId = 'lab_ghadeer_logo';
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'اسم المختبر',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'نبذة المختبر',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slogan,
                decoration: const InputDecoration(
                  labelText: 'شعار قصير (اختياري)',
                  hintText: 'مثال: دقة في التحاليل ... ثقة في النتائج',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mapUrl,
                decoration: const InputDecoration(
                  labelText: 'رابط الخريطة (اختياري)',
                  hintText: 'رابط Google Maps إن وُجد',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _workingHours,
                decoration: const InputDecoration(
                  labelText: 'أوقات العمل (اختياري)',
                  hintText: 'مثال: السبت–الخميس 9 ص – 9 م',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'الهاتف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'واتساب',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.chat_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ترتيب الظهور',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                title: const Text('إظهار المختبر'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              SwitchListTile(
                title: const Text('مختبر معتمد / مميز'),
                subtitle: const Text('يظهر شارة الاعتماد في صفحة الهوية'),
                value: _isFeatured,
                onChanged: (v) => setState(() => _isFeatured = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
