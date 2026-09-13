import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../branding/ghadeer_brand_mark.dart';
import '../../widgets/clinic_app_bar.dart';
import '../ad_campaign.dart';
import '../ads_notify.dart';
import '../ads_service.dart';

class AdCampaignFormPage extends StatefulWidget {
  const AdCampaignFormPage({super.key, this.campaign});

  final AdCampaign? campaign;

  @override
  State<AdCampaignFormPage> createState() => _AdCampaignFormPageState();
}

class _AdCampaignFormPageState extends State<AdCampaignFormPage> {
  final _service = AdsService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _imageUrl;
  late final TextEditingController _videoUrl;
  late final TextEditingController _clickUrl;
  late final TextEditingController _displaySeconds;
  late final TextEditingController _maxTotal;
  late final TextEditingController _maxPerUser;
  late final TextEditingController _maxPerDay;
  late final TextEditingController _priority;

  String _placement = 'home';
  String _mediaType = 'image';
  bool _isActive = false;
  bool _notifyOnActivate = true;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;
  Uint8List? _pickedBytes;
  String? _pickedName;

  bool get _editing => widget.campaign != null;

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    _title = TextEditingController(text: c?.title ?? '');
    _body = TextEditingController(text: c?.body ?? '');
    _imageUrl = TextEditingController(text: c?.imageUrl ?? '');
    _videoUrl = TextEditingController(text: c?.videoUrl ?? '');
    _clickUrl = TextEditingController(text: c?.clickUrl ?? '');
    _displaySeconds =
        TextEditingController(text: '${c?.displaySeconds ?? 0}');
    _maxTotal = TextEditingController(
      text: c?.maxTotalImpressions == null ? '' : '${c!.maxTotalImpressions}',
    );
    _maxPerUser = TextEditingController(text: '${c?.maxPerUser ?? 3}');
    _maxPerDay = TextEditingController(text: '${c?.maxPerUserPerDay ?? 1}');
    _priority = TextEditingController(text: '${c?.priority ?? 0}');
    _placement = c?.placement ?? 'home';
    _mediaType = c?.mediaType ?? 'image';
    _isActive = c?.isActive ?? false;
    _startsAt = c?.startsAt;
    _endsAt = c?.endsAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _imageUrl.dispose();
    _videoUrl.dispose();
    _clickUrl.dispose();
    _displaySeconds.dispose();
    _maxTotal.dispose();
    _maxPerUser.dispose();
    _maxPerDay.dispose();
    _priority.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _pickedName = image.name;
    });
  }

  void _clearPickedImage() {
    setState(() {
      _pickedBytes = null;
      _pickedName = null;
      _imageUrl.text = '';
    });
  }

  Widget _previewImage() {
    if (_pickedBytes != null) {
      return Image.memory(_pickedBytes!, fit: BoxFit.cover);
    }
    final url = _imageUrl.text.trim();
    if (url.isEmpty) {
      return const Center(
        child: Text(
          'اختر صورة الإعلان من الجهاز',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF708084),
          ),
        ),
      );
    }
    return GhadeerResolvedImage(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Color(0xFF9BB8B6)),
      ),
    );
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = (start ? _startsAt : _endsAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDate: initial,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _startsAt = value;
      } else {
        _endsAt = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final wasActive = widget.campaign?.isActive == true;
    final isVideo = _mediaType == 'video';
    if (!isVideo && _pickedBytes == null && _imageUrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر صورة الإعلان من الجهاز')),
      );
      return;
    }
    if (isVideo && _videoUrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رابط الفيديو')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var imageUrl = _imageUrl.text.trim();
      if (_pickedBytes != null) {
        imageUrl = await _service.uploadAdImage(
          bytes: _pickedBytes!,
          originalName: _pickedName ?? 'ad.jpg',
        );
      }

      final maxTotalRaw = _maxTotal.text.trim();
      final draft = AdCampaign(
        id: widget.campaign?.id ?? '',
        title: _title.text.trim(),
        body: _body.text.trim(),
        mediaType: _mediaType,
        imageUrl: imageUrl,
        videoUrl: _videoUrl.text.trim(),
        clickUrl: _clickUrl.text.trim(),
        placement: _placement,
        isActive: _isActive,
        startsAt: _startsAt,
        endsAt: _endsAt,
        displaySeconds: int.tryParse(_displaySeconds.text.trim()) ?? 0,
        maxTotalImpressions:
            maxTotalRaw.isEmpty ? null : int.tryParse(maxTotalRaw),
        maxPerUser: int.tryParse(_maxPerUser.text.trim()) ?? 3,
        maxPerUserPerDay: int.tryParse(_maxPerDay.text.trim()) ?? 1,
        priority: int.tryParse(_priority.text.trim()) ?? 0,
      );
      final saved = await _service.upsert(
        draft,
        existingId: widget.campaign?.id,
      );

      final becameActive = _isActive && !wasActive;
      if (becameActive && _notifyOnActivate) {
        await AdsNotify.notifyCampaignActivated(saved);
      }

      if (!mounted) return;
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
    const teal = Color(0xFF0FAFA3);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: Text(_editing ? 'تعديل حملة' : 'حملة جديدة'),
          backgroundColor: teal,
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تفعيل الحملة'),
                subtitle: const Text('إن كانت متوقفة لن تظهر للمستخدم'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إشعار عند التفعيل'),
                subtitle: const Text(
                  'يظهر في صندوق الإشعارات: «إعلان في منصة الغدير»',
                ),
                value: _notifyOnActivate,
                onChanged: (v) => setState(() => _notifyOnActivate = v),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'عنوان الإعلان',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _body,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'نص قصير (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _placement,
                decoration: const InputDecoration(
                  labelText: 'موضع الظهور',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'home', child: Text('الرئيسية')),
                  DropdownMenuItem(value: 'doctors', child: Text('الأطباء')),
                  DropdownMenuItem(value: 'labs', child: Text('المختبرات')),
                  DropdownMenuItem(value: 'radiology', child: Text('الأشعة')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _placement = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _mediaType,
                decoration: const InputDecoration(
                  labelText: 'نوع الوسائط',
                  border: OutlineInputBorder(),
                  helperText:
                      'الفيديو الأفضل برابط (يوتيوب/رابط مباشر) — أخف على التطبيق',
                ),
                items: const [
                  DropdownMenuItem(value: 'image', child: Text('صورة')),
                  DropdownMenuItem(value: 'video', child: Text('فيديو برابط')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _mediaType = v);
                },
              ),
              const SizedBox(height: 14),
              Text(
                _mediaType == 'video'
                    ? 'صورة مصغّرة (اختياري)'
                    : 'صورة الإعلان',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                _mediaType == 'video'
                    ? 'اختياري: صورة غلاف تظهر قبل فتح رابط الفيديو'
                    : 'المصمّم يجهّز الصورة وتعطى لكم — اختاروها من الجهاز',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF708084),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFFEAF4F3),
                  child: _previewImage(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _pickedBytes != null || _imageUrl.text.trim().isNotEmpty
                            ? 'تغيير الصورة'
                            : 'اختيار صورة',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearPickedImage,
                      icon: const Icon(Icons.hide_image_outlined),
                      label: const Text('مسح'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _videoUrl,
                decoration: InputDecoration(
                  labelText: _mediaType == 'video'
                      ? 'رابط الفيديو (مطلوب)'
                      : 'رابط الفيديو (اختياري)',
                  hintText: 'https://youtube.com/... أو رابط مباشر',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clickUrl,
                decoration: const InputDecoration(
                  labelText: 'رابط عند الضغط (اختياري)',
                  hintText: 'https://... أو واتساب',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'الوقت والحدود',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(start: true),
                      child: Text(
                        _startsAt == null
                            ? 'بداية الإعلان'
                            : 'بداية: ${_startsAt!.toLocal()}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(start: false),
                      child: Text(
                        _endsAt == null
                            ? 'نهاية الإعلان'
                            : 'نهاية: ${_endsAt!.toLocal()}',
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() {
                  _startsAt = null;
                  _endsAt = null;
                }),
                child: const Text('مسح التواريخ (بلا حد زمني)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _displaySeconds,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'مدة الظهور بالثواني (0 = حتى يغلقها المستخدم)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxPerUser,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'كم مرة كحد أقصى لكل مستخدم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxPerDay,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'كم مرة باليوم لكل مستخدم',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxTotal,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'حد إجمالي الظهور (فارغ = بلا حد)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priority,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'الأولوية (الأعلى يظهر أولًا)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: teal,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
