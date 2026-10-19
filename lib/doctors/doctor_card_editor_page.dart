import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../widgets/entity_optional_logo.dart';
import '../models/doctor_item.dart';
import 'doctor_card_access_client.dart';
import 'owner_password_change_dialog.dart';
import 'doctor_image_bg_remover.dart';
import 'doctor_photo_guide.dart';
import 'doctor_schedule_preview.dart';
import 'doctor_week_schedule.dart';
import 'specialty_catalog.dart';

/// تعديل البطاقة بعد جلسة موثّقة. الحقول المعروضة ليست الحماية.
class DoctorCardEditorPage extends StatefulWidget {
  const DoctorCardEditorPage({
    super.key,
    required this.doctor,
    required this.session,
  });

  final DoctorItem doctor;
  final DoctorCardSession session;

  @override
  State<DoctorCardEditorPage> createState() => _DoctorCardEditorPageState();
}

class _DoctorCardEditorPageState extends State<DoctorCardEditorPage> {
  final _client = DoctorCardAccessClient();
  late final TextEditingController _name;
  late final TextEditingController _specialty;
  late final TextEditingController _location;
  late final TextEditingController _bio;
  late final TextEditingController _services;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _order;
  late Map<String, String> _periods;
  late String? _booking;

  Uint8List? _imageBytes;
  String _imageUrl = '';
  String _logoUrl = '';
  bool _scheduleTouched = false;
  bool _active = true;
  bool _metaReady = false;
  bool _saving = false;
  bool _passwordBusy = false;

  bool get _admin => widget.session.isAdmin;

  @override
  void initState() {
    super.initState();
    final doctor = widget.doctor;
    _name = TextEditingController(text: doctor.name);
    _specialty = TextEditingController(text: doctor.specialty);
    _location = TextEditingController(text: doctor.location);
    _bio = TextEditingController(text: doctor.bio);
    _services = TextEditingController(text: doctor.services);
    _phone = TextEditingController(text: doctor.phone);
    _whatsapp = TextEditingController(text: doctor.whatsapp);
    _order = TextEditingController();
    _imageUrl = doctor.imageUrl;
    _logoUrl = doctor.logoUrl;
    _periods = doctorWeekEditorValues(
      workingDays: doctor.workingDays,
      workingHours: doctor.workingHours,
    );
    const doctorStatuses = {'available', 'walk_in_only', 'full'};
    _booking = doctorStatuses.contains(doctor.bookingStatus)
        ? doctor.bookingStatus
        : (_admin ? doctor.bookingStatus : null);
    if (_admin) {
      _loadMeta();
    }
  }

  Future<void> _loadMeta() async {
    try {
      final status = await _client.adminStatusForSession(widget.session);
      if (!mounted) return;
      setState(() {
        _active = status.isActive;
        _order.text = '${status.displayOrder}';
        _metaReady = true;
      });
    } on DoctorCardAccessException {
      if (!mounted) return;
      setState(() => _metaReady = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _specialty.dispose();
    _location.dispose();
    _bio.dispose();
    _services.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    var bytes = await picked.readAsBytes();
    try {
      final removed = await DoctorImageBgRemover.removeBackground(bytes);
      if (removed != null) bytes = removed;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _imageBytes = bytes);
  }

  Future<void> _save() async {
    if (_booking == null) {
      _toast('اختر حالة الحجز');
      return;
    }
    setState(() => _saving = true);
    try {
      var imageUrl = _imageUrl;
      var revision = widget.doctor.contentRevision;
      if (_imageBytes != null && (_admin || widget.session.allows('image'))) {
        imageUrl = await _client.uploadPhoto(
          session: widget.session,
          bytes: _imageBytes!,
          baseRevision: revision,
        );
        revision += 1;
      }
      final bio = _bio.text.trim();
      final fields = <String, dynamic>{};
      if (_admin || widget.session.allows('image')) {
        fields['logo_url'] = _logoUrl.trim();
      }
      if (_admin || widget.session.allows('bio')) {
        fields['bio'] = bio;
        fields['short_description'] = bio;
      }
      if (_admin || widget.session.allows('services')) {
        fields['services'] = _services.text.trim();
      }
      if (_admin || widget.session.allows('contacts')) {
        fields['phone'] = _phone.text.trim();
        fields['whatsapp'] = _whatsapp.text.trim();
      }
      if (_admin || widget.session.allows('booking_status')) {
        fields['booking_status'] = _booking;
      }
      if (_admin || widget.session.allows('schedule')) {
        if (_scheduleTouched) {
          final week = formatDoctorWeek(_periods);
          fields['working_days'] = week.days;
          fields['working_hours'] = week.hours;
        } else {
          fields['working_days'] = widget.doctor.workingDays;
          fields['working_hours'] = widget.doctor.workingHours;
        }
      }
      if (_admin) {
        final rawSpecialty = _specialty.text.trim();
        final specialty =
            SpecialtyCatalog.match(rawSpecialty)?.nameAr ?? rawSpecialty;
        fields['doctor_name'] = _name.text.trim();
        fields['specialty'] = specialty;
        fields['clinic_location'] = _location.text.trim();
        if (_metaReady) {
          fields['is_active'] = _active;
          fields['display_order'] = int.tryParse(_order.text.trim()) ?? 0;
        }
      }
      if (fields.isNotEmpty) {
        await _client.updateFields(
          session: widget.session,
          fields: fields,
          baseRevision: revision,
        );
      }
      if (!mounted) return;
      final week = _scheduleTouched
          ? formatDoctorWeek(_periods)
          : (
              days: widget.doctor.workingDays,
              hours: widget.doctor.workingHours,
            );
      final next = widget.doctor.copyWith(
        name: _admin ? _name.text.trim() : null,
        specialty: _admin ? fields['specialty']?.toString() : null,
        location: _admin ? _location.text.trim() : null,
        bio: bio,
        services: _services.text.trim(),
        shortDescription: bio,
        phone: _phone.text.trim(),
        whatsapp: _whatsapp.text.trim(),
        bookingStatus: _booking,
        workingDays: week.days,
        workingHours: week.hours,
        imageUrl: GhadeerBranding.normalizeEntityImageUrl(imageUrl),
        logoUrl: _logoUrl,
        available: _booking == 'available',
      );
      _toast('تم حفظ التعديلات');
      Navigator.pop(context, DoctorCardEditResult(doctor: next));
    } on DoctorCardAccessException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reissueOwnerCode() async {
    setState(() => _passwordBusy = true);
    try {
      final state = await _client.adminConfigure(
        entityType: 'doctor',
        entityId: widget.session.entityId,
        enabled: true,
        reset: true,
        cardToken: widget.session.token,
      );
      final code = state.activationCode ?? '';
      if (mounted && code.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('رمز تفعيل جديد'),
            content: SelectableText(code),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('تم'),
              ),
            ],
          ),
        );
      }
      _toast('تم إصدار رمز التفعيل. سلّمه للمالك خارج التطبيق.');
    } on DoctorCardAccessException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _passwordBusy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف البطاقة'),
          content: const Text('هل تريد حذف بطاقة هذا الطبيب؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _client.adminDelete(widget.session);
      if (!mounted) return;
      Navigator.pop(context, const DoctorCardEditResult(deleted: true));
    } on DoctorCardAccessException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bookingItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'available', child: Text('متاح')),
      const DropdownMenuItem(value: 'walk_in_only', child: Text('حضوري')),
      const DropdownMenuItem(value: 'full', child: Text('مكتمل')),
      if (_admin)
        const DropdownMenuItem(value: 'unavailable', child: Text('غير متاح')),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_admin ? 'تعديل بطاقة الطبيب' : 'تعديل بطاقتك')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              children: [
                if (!_admin)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F6F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'صلاحياتك تخص بطاقتك فقط',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                if (_admin) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _specialty,
                    decoration: const InputDecoration(
                      labelText: 'الاختصاص',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _location,
                    decoration: const InputDecoration(
                      labelText: 'عنوان العيادة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_metaReady) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('إظهار البطاقة'),
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                    ),
                    TextField(
                      controller: _order,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ترتيب الظهور',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                if (_admin || widget.session.allows('image'))
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 120,
                          height: 140,
                          child: _imageBytes != null
                              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                              : _imageUrl.trim().isNotEmpty
                                  ? GhadeerResolvedImage(
                                      _imageUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : const ColoredBox(
                                      color: Color(0xFFEAF4F3),
                                      child: Icon(Icons.person_rounded, size: 48),
                                    ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _saving ? null : _pickImage,
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('تغيير الصورة'),
                      ),
                      // إرشاد الصورة + معاينة بإطار صفحة الطبيب (Phase 5C).
                      DoctorPhotoGuide(
                        pickedBytes: _imageBytes,
                        preview: _imageBytes != null
                            ? Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              )
                            : _imageUrl.trim().isNotEmpty
                            ? GhadeerResolvedImage(
                                _imageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                              )
                            : const ColoredBox(
                                color: Color(0xFFEAF4F3),
                                child: Icon(Icons.person_rounded, size: 36),
                              ),
                      ),
                      const SizedBox(height: 8),
                      EntityLogoAdminField(
                        logoUrl: _logoUrl,
                        folder: 'doctors',
                        entityId: widget.doctor.id,
                        onChanged: (value) => setState(() => _logoUrl = value),
                        upload: (bytes, _) => _client.uploadPhoto(
                          session: widget.session,
                          bytes: bytes,
                          baseRevision: widget.doctor.contentRevision,
                          logo: true,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_admin || widget.session.allows('bio'))
                TextField(
                  controller: _bio,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'النبذة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (_admin || widget.session.allows('services'))
                TextField(
                  controller: _services,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'الخدمات الطبية',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_admin || widget.session.allows('schedule'))
                ...doctorWeekDayOrder.map((day) {
                  final period = _periods[day] ?? 'off';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('card-period-$day-$period'),
                      initialValue: period,
                      decoration: InputDecoration(
                        labelText: day,
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'morning', child: Text('صباحًا')),
                        DropdownMenuItem(value: 'evening', child: Text('مساءً')),
                        DropdownMenuItem(
                          value: 'both',
                          child: Text('صباحًا ومساءً'),
                        ),
                        DropdownMenuItem(value: 'off', child: Text('عطلة')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _periods[day] = value ?? 'off';
                          _scheduleTouched = true;
                        });
                      },
                    ),
                  );
                }),
                if (_admin || widget.session.allows('schedule')) ...[
                  DoctorSchedulePreview(
                    workingHours: formatDoctorWeek(_periods).hours,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_admin || widget.session.allows('contacts')) ...[
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الحجز',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _whatsapp,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'واتساب',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ],
                if (_admin || widget.session.allows('booking_status'))
                DropdownButtonFormField<String>(
                  key: ValueKey('booking-$_booking'),
                  initialValue: _booking,
                  decoration: const InputDecoration(
                    labelText: 'حالة الحجز',
                    border: OutlineInputBorder(),
                  ),
                  items: bookingItems,
                  onChanged: (value) => setState(() => _booking = value),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'جاري الحفظ...' : 'حفظ التعديلات'),
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
                if (_admin) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'إعادة تعيين دخول المالك',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'يُبطل كلمة المرور والجلسات ويصدر رمز تفعيل لساعتين. سلّمه للمالك خارج التطبيق.',
                    style: TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _passwordBusy ? null : _reissueOwnerCode,
                    child: const Text('إصدار رمز تفعيل جديد'),
                  ),
                ],
                if (_admin) ...[
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: _saving ? null : _delete,
                    child: const Text(
                      'حذف البطاقة',
                      style: TextStyle(color: Color(0xFFC94A4A)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
