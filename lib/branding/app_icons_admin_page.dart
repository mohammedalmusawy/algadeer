import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../branding/app_icon_slots.dart';
import '../services/app_icons_service.dart';
import '../widgets/app_slot_icon.dart';
import '../widgets/clinic_app_bar.dart';

/// إدارة أيقونات الواجهة — الشعار الرسمي ثابت وغير قابل للتغيير هنا.
class AppIconsAdminPage extends StatefulWidget {
  const AppIconsAdminPage({super.key});

  @override
  State<AppIconsAdminPage> createState() => _AppIconsAdminPageState();
}

class _AppIconsAdminPageState extends State<AppIconsAdminPage> {
  final _service = AppIconsService.instance;
  bool _loading = true;
  String? _busySlot;
  String _filter = 'all'; // all | home | specialty | nav

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await _service.load();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  List<AppIconSlot> get _slots {
    final all = AppIconSlots.all;
    switch (_filter) {
      case 'home':
        return all.where((s) => s.group == AppIconSlots.groupHome).toList();
      case 'specialty':
        return all
            .where((s) => s.group == AppIconSlots.groupSpecialty)
            .toList();
      case 'nav':
        return all.where((s) => s.group == AppIconSlots.groupNav).toList();
      default:
        return all;
    }
  }

  Future<void> _pickAndUpload(AppIconSlot slot) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 92,
    );
    if (picked == null) return;

    setState(() => _busySlot = slot.id);
    try {
      final bytes = await picked.readAsBytes();
      final url = await _service.uploadIconImage(
        bytes: bytes,
        originalName: picked.name,
        slotId: slot.id,
      );
      await _service.setUrl(slot.id, url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث أيقونة «${slot.titleAr}»')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر الحفظ. تأكد من جدول app_ui_icons ومخزن clinic-media.\n$e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  Future<void> _reset(AppIconSlot slot) async {
    setState(() => _busySlot = slot.id);
    try {
      await _service.clearUrl(slot.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('أُعيدت «${slot.titleAr}» للرمز الافتراضي')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الإعادة: $e')),
      );
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: ClinicAppBar(
          title: const Text('إدارة الأيقونات'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'شعار الغدير ثابت ولا يُغيَّر من هنا. '
                          'غيّر صور الأيقونات فقط — وإن حُذفت الصورة يعود الرمز الافتراضي.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Color(0xFF5B6C70),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _service.tableAvailable
                              ? 'المزامنة مع قاعدة البيانات متاحة.'
                              : 'الجدول غير موجود بعد — يُحفظ محلياً على هذا الجهاز إلى أن تُنفَّذ app_ui_icons_schema.sql.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _service.tableAvailable
                                ? const Color(0xFF0C7F76)
                                : const Color(0xFFB45309),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip('all', 'الكل'),
                            _chip('home', 'الرئيسية'),
                            _chip('specialty', 'الاختصاصات'),
                            _chip('nav', 'شريط الأسفل'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _slots.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final slot = _slots[index];
                        final busy = _busySlot == slot.id;
                        final hasCustom =
                            (_service.urlFor(slot.id) ?? '').isNotEmpty;
                        return Material(
                          color: const Color(0xFFF7FBFC),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE4EEEE),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : AppSlotIcon(
                                          slotId: slot.id,
                                          fallback: slot.fallbackIcon,
                                          size: 28,
                                          color: const Color(0xFF0FAFA3),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.titleAr,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                          color: Color(0xFF123B42),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        hasCustom
                                            ? 'صورة مخصّصة'
                                            : 'الرمز الافتراضي',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: hasCustom
                                              ? const Color(0xFF0C7F76)
                                              : const Color(0xFF6B7C80),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed:
                                      busy ? null : () => _pickAndUpload(slot),
                                  child: const Text('تغيير'),
                                ),
                                if (hasCustom)
                                  TextButton(
                                    onPressed:
                                        busy ? null : () => _reset(slot),
                                    child: const Text('افتراضي'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chip(String id, String label) {
    final active = _filter == id;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _filter = id),
      selectedColor: const Color(0xFF0FAFA3),
      labelStyle: TextStyle(
        color: active ? Colors.white : const Color(0xFF123B42),
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: Colors.white,
    );
  }
}
