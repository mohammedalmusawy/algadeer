import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'dynamic_message_service.dart';
import '../widgets/clinic_app_bar.dart';
import '../widgets/dynamic_highlight_card.dart';

/// إدارة كاملة للعبارات الديناميكية (CRUD + تفعيل + أولوية).
class DynamicMessageAdminPage extends StatefulWidget {
  const DynamicMessageAdminPage({super.key});

  @override
  State<DynamicMessageAdminPage> createState() =>
      _DynamicMessageAdminPageState();
}

class _DynamicMessageAdminPageState extends State<DynamicMessageAdminPage> {
  final _service = DynamicMessageService();
  List<DynamicMessage> _items = [];
  bool _loading = true;
  String? _error;
  bool _tableMissing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _tableMissing = false;
    });
    try {
      final hasTable = await _service.hasTable();
      if (!hasTable) {
        if (!mounted) return;
        setState(() {
          _tableMissing = true;
          _items = [];
          _loading = false;
        });
        return;
      }
      final items = await _service.fetchAllForAdmin();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openEditor({DynamicMessage? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) =>
          _MessageEditorSheet(service: _service, existing: existing),
    );
    if (saved == true && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ الإعلان')));
    }
  }

  Future<void> _toggleActive(DynamicMessage item, bool value) async {
    try {
      await _service.setActive(id: item.id, isActive: value);
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((e) => e.id == item.id);
        if (i >= 0) _items[i] = item.copyWith(isActive: value);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'تم التفعيل' : 'تم التعطيل')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر التحديث: $e')));
    }
  }

  Future<void> _confirmDelete(DynamicMessage item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف العبارة؟'),
          content: Text('سيتم حذف «${item.title}» نهائيًا.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC94A4A),
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteMessage(item.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.id == item.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم الحذف')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8F8),
        appBar: ClinicAppBar(
          title: const Text('المكان الإعلاني'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: _tableMissing
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openEditor(),
                backgroundColor: const Color(0xFF0FAFA3),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('إعلان جديد'),
              ),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          3,
          (i) => Container(
            height: 110,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4EEEE)),
            ),
          ),
        ),
      );
    }

    if (_tableMissing) {
      return const _AdminInfoCard(
        title: 'الجدول غير موجود',
        body: 'نفّذ dynamic_messages_schema.sql ثم dynamic_messages_highlight_schema.sql في Supabase SQL Editor ثم اضغط تحديث.',
      );
    }

    if (_error != null) {
      return _AdminInfoCard(
        title: 'تعذر التحميل',
        body: _error!,
        actionLabel: 'إعادة المحاولة',
        onAction: _load,
      );
    }

    if (_items.isEmpty) {
      return const _AdminInfoCard(
        title: 'لا توجد عبارات بعد',
        body: 'أضف أول عبارة لتظهر في الصفحة الرئيسية فورًا بعد الحفظ.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AdminMessageCard(
              message: item,
              onEdit: () => _openEditor(existing: item),
              onDelete: () => _confirmDelete(item),
              onToggle: (v) => _toggleActive(item, v),
            ),
          );
        },
      ),
    );
  }
}

class _AdminInfoCard extends StatelessWidget {
  const _AdminInfoCard({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EEEE)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF123B42),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  height: 1.5,
                  color: Color(0xFF5B6C70),
                  fontSize: 14,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0FAFA3),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminMessageCard extends StatelessWidget {
  const _AdminMessageCard({
    required this.message,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final DynamicMessage message;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: message.isActive
                ? const Color(0xFFBFEDE8)
                : const Color(0xFFE4EEEE),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF123B42),
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: message.isActive,
                  activeThumbColor: const Color(0xFF0FAFA3),
                  onChanged: onToggle,
                ),
              ],
            ),
            Text(
              message.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                height: 1.45,
                color: Color(0xFF5B6C70),
                fontSize: 14,
              ),
            ),
            if (message.address.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: Color(0xFF1197A8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      message.address.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF445A5E),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (message.badge.trim().isNotEmpty)
                  _Chip(label: message.badge.trim()),
                _Chip(
                  label: DynamicMessagePlacement.labelAr(message.placement),
                ),
                _Chip(
                  label: DynamicMessageDestination.labelAr(
                    message.destinationKind,
                  ),
                ),
                if (message.hasLocation) const _Chip(label: 'موقع'),
                _Chip(label: 'أولوية ${message.priority}'),
                _Chip(label: message.isActive ? 'مفعّلة' : 'معطّلة'),
                if (message.hasImage) const _Chip(label: 'صورة'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('تعديل'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0FAFA3),
                      side: const BorderSide(color: Color(0xFF0FAFA3)),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Color(0xFFC94A4A),
                    ),
                    label: const Text(
                      'حذف',
                      style: TextStyle(color: Color(0xFFC94A4A)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC94A4A)),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0C7F76),
        ),
      ),
    );
  }
}

class _MessageEditorSheet extends StatefulWidget {
  const _MessageEditorSheet({required this.service, this.existing});

  final DynamicMessageService service;
  final DynamicMessage? existing;

  @override
  State<_MessageEditorSheet> createState() => _MessageEditorSheetState();
}

class _MessageEditorSheetState extends State<_MessageEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _priority;
  late final TextEditingController _hint;
  late final TextEditingController _badge;
  late final TextEditingController _linkUrl;
  late final TextEditingController _imageUrl;
  late final TextEditingController _address;
  late final TextEditingController _mapUrl;
  late String _placement;
  late bool _isActive;
  late String _destinationKind;
  String? _destinationId;
  bool _saving = false;
  Uint8List? _pickedBytes;
  String? _pickedName;

  List<Map<String, String>> _doctorOptions = [];
  List<Map<String, String>> _labOptions = [];
  List<Map<String, String>> _radiologyOptions = [];
  bool _loadingOptions = true;

  static const _maxBody = 600;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? 'معاً لصحة أفضل');
    _body = TextEditingController(text: e?.body ?? '');
    _priority = TextEditingController(text: '${e?.priority ?? 10}');
    _hint = TextEditingController(text: e?.contextHint ?? '');
    _badge = TextEditingController(
      text: e?.badge.trim().isNotEmpty == true ? e!.badge : 'عيادة الغدير',
    );
    _linkUrl = TextEditingController(text: e?.linkUrl ?? '');
    _imageUrl = TextEditingController(text: e?.imageUrl ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _mapUrl = TextEditingController(text: e?.mapUrl ?? '');
    _placement = e?.placement ?? DynamicMessagePlacement.home;
    _isActive = e?.isActive ?? true;
    _destinationKind =
        e?.destinationKind.trim().isNotEmpty == true
            ? e!.destinationKind
            : DynamicMessageDestination.none;
    _destinationId =
        e?.destinationId.trim().isNotEmpty == true ? e!.destinationId : null;
    _body.addListener(() => setState(() {}));
    _title.addListener(() => setState(() {}));
    _badge.addListener(() => setState(() {}));
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() => _loadingOptions = true);
    final doctors = await widget.service.fetchDestinationOptions(
      DynamicMessageDestination.doctor,
    );
    final labs = await widget.service.fetchDestinationOptions(
      DynamicMessageDestination.lab,
    );
    final radiology = await widget.service.fetchDestinationOptions(
      DynamicMessageDestination.radiology,
    );
    if (!mounted) return;
    setState(() {
      _doctorOptions = doctors;
      _labOptions = labs;
      _radiologyOptions = radiology;
      _loadingOptions = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _priority.dispose();
    _hint.dispose();
    _badge.dispose();
    _linkUrl.dispose();
    _imageUrl.dispose();
    _address.dispose();
    _mapUrl.dispose();
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

  List<Map<String, String>> get _currentOptions {
    switch (_destinationKind) {
      case DynamicMessageDestination.doctor:
        return _doctorOptions;
      case DynamicMessageDestination.lab:
        return _labOptions;
      case DynamicMessageDestination.radiology:
        return _radiologyOptions;
      default:
        return const [];
    }
  }

  Future<void> _save() async {
    final body = _body.text.trim();
    final title = _title.text.trim();
    if (title.isEmpty &&
        body.isEmpty &&
        _pickedBytes == null &&
        _imageUrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل عنوانًا أو نبذة أو صورة')),
      );
      return;
    }
    if (_destinationKind == DynamicMessageDestination.url &&
        _linkUrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل الرابط الخارجي أو اختر وجهة أخرى')),
      );
      return;
    }
    if (_address.text.trim().isNotEmpty && _mapUrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يفضّل إضافة رابط Google Maps مع العنوان المكتوب لفتح الموقع بدقة',
          ),
        ),
      );
    }
    if ((_destinationKind == DynamicMessageDestination.doctor ||
            _destinationKind == DynamicMessageDestination.lab ||
            _destinationKind == DynamicMessageDestination.radiology) &&
        (_destinationId == null || _destinationId!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'اختر ${DynamicMessageDestination.labelAr(_destinationKind)}',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      var imageUrl = _imageUrl.text.trim();
      if (_pickedBytes != null) {
        imageUrl = await widget.service.uploadHighlightImage(
          bytes: _pickedBytes!,
          originalName: _pickedName ?? 'highlight.jpg',
        );
      }
      final message = DynamicMessage(
        id: widget.existing?.id ?? '',
        title: title.isEmpty ? 'عيادة الغدير' : title,
        body: body,
        placement: _placement,
        priority: int.tryParse(_priority.text.trim()) ?? 0,
        isActive: _isActive,
        contextHint: _hint.text.trim(),
        imageUrl: imageUrl,
        badge: _badge.text.trim(),
        linkUrl: _linkUrl.text.trim(),
        destinationKind: _destinationKind,
        destinationId: _destinationId ?? '',
        address: _address.text.trim(),
        mapUrl: _mapUrl.text.trim(),
      );
      await widget.service.upsertMessage(
        message,
        existingId: widget.existing?.id,
      );
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
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final preview = DynamicMessage(
      id: 'preview',
      title: _title.text.trim().isEmpty ? 'عيادة الغدير' : _title.text.trim(),
      body: _body.text.trim().isEmpty
          ? 'ستظهر النبذة هنا...'
          : _body.text.trim(),
      badge: _badge.text.trim().isEmpty ? 'عيادة الغدير' : _badge.text.trim(),
      imageUrl: _imageUrl.text.trim(),
      destinationKind: _destinationKind,
      destinationId: _destinationId ?? '',
      linkUrl: _linkUrl.text.trim(),
      address: _address.text.trim(),
      mapUrl: _mapUrl.text.trim(),
    );
    final options = _currentOptions;
    final destValue = options.any((e) => e['id'] == _destinationId)
        ? _destinationId
        : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + inset),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E4E4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.existing == null ? 'إعلان جديد' : 'تعديل الإعلان',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF123B42),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تخطيط مثل هوية الطبيب — الصورة كاملة، والجانب مساحة إعلانية',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 14),
              IgnorePointer(
                child: DynamicHighlightCard(
                  message: preview,
                  previewImageBytes: _pickedBytes,
                  openDetailsOnTap: false,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'شارة الإعلان',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in DynamicMessageBadges.suggestions)
                    ChoiceChip(
                      label: Text(b),
                      selected: _badge.text.trim() == b,
                      onSelected: (_) {
                        setState(() => _badge.text = b);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _badge,
                decoration: _dec('أو اكتب شارة إعلانية'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _title,
                decoration: _dec('التحية / العنوان الإعلاني'),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                minLines: 4,
                maxLines: 8,
                maxLength: _maxBody,
                decoration: _dec('الكلمات الإعلانية'),
              ),
              const SizedBox(height: 10),
                  TextField(
                controller: _address,
                decoration: _dec(
                  'العنوان كتابة (مثال: الشطرة – شارع الأطباء – قرب صيدلية الحدباء)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mapUrl,
                decoration: _dec('رابط الموقع من Google Maps (مهم لفتح 📍 بدقة)'),
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                'بعد الحفظ: إن ظهر تنبيه عن العنوان، نفّذ dynamic_messages_highlight_schema.sql ثم أعد الحفظ.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.grey.shade600,
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
                            ? 'تغيير صورة الإعلان'
                            : 'صورة الإعلان (تظهر كاملة)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _pickedBytes = null;
                        _pickedName = null;
                        _imageUrl.text = '';
                      }),
                      icon: const Icon(Icons.hide_image_outlined),
                      label: const Text('مسح'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'وجهة الإعلان (اختياري)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in DynamicMessageDestination.all)
                    ChoiceChip(
                      label: Text(DynamicMessageDestination.labelAr(kind)),
                      selected: _destinationKind == kind,
                      onSelected: (_) {
                        setState(() {
                          _destinationKind = kind;
                          if (kind == DynamicMessageDestination.none ||
                              kind == DynamicMessageDestination.url) {
                            _destinationId = null;
                          }
                        });
                      },
                    ),
                ],
              ),
              if (_destinationKind == DynamicMessageDestination.url) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _linkUrl,
                  decoration: _dec('الرابط الخارجي'),
                ),
              ],
              if (_destinationKind == DynamicMessageDestination.doctor ||
                  _destinationKind == DynamicMessageDestination.lab ||
                  _destinationKind == DynamicMessageDestination.radiology) ...[
                const SizedBox(height: 10),
                if (_loadingOptions)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (options.isEmpty)
                  Text(
                    'لا توجد عناصر متاحة لهذا النوع حاليًا',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('dest-$_destinationKind'),
                    initialValue: destValue,
                    decoration: _dec(
                      'اختر ${DynamicMessageDestination.labelAr(_destinationKind)}',
                    ),
                    items: options
                        .map(
                          (o) => DropdownMenuItem(
                            value: o['id'],
                            child: Text(
                              o['subtitle'] == null || o['subtitle']!.isEmpty
                                  ? o['name']!
                                  : '${o['name']} — ${o['subtitle']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _destinationId = v),
                  ),
              ],
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _placement,
                decoration: _dec('مكان ظهور الشريط'),
                items: DynamicMessagePlacement.all
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(DynamicMessagePlacement.labelAr(p)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _placement = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _priority,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('الأولوية (الأعلى يظهر أولًا)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _hint,
                decoration: _dec('تلميح سياقي للمستقبل / AI (اختياري)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'مفعّلة',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                value: _isActive,
                activeThumbColor: const Color(0xFF0FAFA3),
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0FAFA3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'حفظ الإعلان',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD7E4E4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0FAFA3), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
