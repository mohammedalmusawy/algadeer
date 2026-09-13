import 'package:flutter/material.dart';

import 'notifications_admin_service.dart';
import '../widgets/clinic_app_bar.dart';

/// إدارة إشعارات مبسّطة: جدول + فلتر (غدير / طبيب / مختبر).
class NotificationsAdminPage extends StatefulWidget {
  const NotificationsAdminPage({super.key});

  @override
  State<NotificationsAdminPage> createState() => _NotificationsAdminPageState();
}

enum _Scope { all, ghadeer, doctor, lab }

class _NotificationsAdminPageState extends State<NotificationsAdminPage> {
  final _service = NotificationsAdminService();

  List<AdminNotificationItem> _items = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _labs = [];
  bool _loading = true;
  String? _error;

  _Scope _scope = _Scope.all;
  String? _doctorId;
  String? _labId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.fetchAll();
      final doctors = await _service.fetchDoctorsLite();
      List<Map<String, dynamic>> labs = [];
      try {
        labs = await _service.fetchLabsLite();
      } catch (e) {
        debugPrint('NotificationsAdmin: labs load failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _doctors = doctors;
        _labs = labs;
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

  String _doctorName(String? id) {
    if (id == null || id.isEmpty) return '';
    for (final d in _doctors) {
      if (d['id']?.toString() == id) {
        return d['doctor_name']?.toString() ?? '';
      }
    }
    return '';
  }

  String _labName(String? id) {
    if (id == null || id.isEmpty) return '';
    for (final l in _labs) {
      if (l['id']?.toString() == id) {
        return (l['name'] ?? l['lab_name'] ?? '').toString();
      }
    }
    return '';
  }

  String _rowSourceLabel(AdminNotificationItem item) {
    switch (item.source) {
      case 'doctor':
        final n = _doctorName(item.doctorId);
        return n.isEmpty ? 'طبيب' : n;
      case 'lab':
        final n = _labName(item.labId);
        return n.isEmpty ? 'مختبر' : n;
      default:
        return 'عيادة الغدير';
    }
  }

  List<AdminNotificationItem> get _visible {
    return _items.where((item) {
      switch (_scope) {
        case _Scope.all:
          return true;
        case _Scope.ghadeer:
          return item.source == 'ghadeer' ||
              (item.doctorId == null &&
                  item.labId == null &&
                  item.source != 'doctor' &&
                  item.source != 'lab');
        case _Scope.doctor:
          if (item.source != 'doctor' && item.doctorId == null) return false;
          if (_doctorId == null || _doctorId!.isEmpty) {
            return item.source == 'doctor' || item.doctorId != null;
          }
          return item.doctorId == _doctorId;
        case _Scope.lab:
          if (item.source != 'lab' && item.labId == null) return false;
          if (_labId == null || _labId!.isEmpty) {
            return item.source == 'lab' || item.labId != null;
          }
          return item.labId == _labId;
      }
    }).toList();
  }

  Future<void> _openCompose({AdminNotificationItem? existing}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SimpleComposeSheet(
        service: _service,
        doctors: _doctors,
        labs: _labs,
        existing: existing,
        initialScope: existing == null
            ? _scope
            : (existing.source == 'doctor'
                ? _Scope.doctor
                : existing.source == 'lab'
                    ? _Scope.lab
                    : _Scope.ghadeer),
        initialDoctorId: existing?.doctorId ?? _doctorId,
        initialLabId: existing?.labId ?? _labId,
      ),
    );
    if (ok == true) _load();
  }

  String _statusLabel(String status) => NotificationStatus.labelOf(status);

  String _when(AdminNotificationItem item) {
    if (item.repeatEnabled) return 'تلقائي';
    final t = item.scheduledAt ?? item.sentAt ?? item.createdAt;
    if (t == null) return '—';
    return '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('إدارة الإشعارات'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openCompose(),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_alert_rounded),
          label: const Text('إشعار جديد'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'تعذر التحميل',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _buildFilters(),
                      const Divider(height: 1),
                      Expanded(
                        child: _visible.isEmpty
                            ? const Center(
                                child: Text('لا توجد إشعارات لهذا الاختيار'),
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    12,
                                    90,
                                  ),
                                  children: [
                                    _tableHeader(),
                                    const SizedBox(height: 6),
                                    for (final item in _visible)
                                      _tableRow(item),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFilters() {
    return Material(
      color: const Color(0xFFF4FAFB),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _scopeChip(_Scope.all, 'الكل'),
                  _scopeChip(_Scope.ghadeer, 'عيادة الغدير'),
                  _scopeChip(_Scope.doctor, 'طبيب'),
                  _scopeChip(_Scope.lab, 'مختبر'),
                ],
              ),
            ),
            if (_scope == _Scope.doctor) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _doctorId,
                decoration: const InputDecoration(
                  labelText: 'الطبيب المعني',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('كل الأطباء'),
                  ),
                  for (final d in _doctors)
                    DropdownMenuItem(
                      value: d['id']?.toString(),
                      child: Text(d['doctor_name']?.toString() ?? ''),
                    ),
                ],
                onChanged: (v) => setState(() => _doctorId = v),
              ),
            ],
            if (_scope == _Scope.lab) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _labId,
                decoration: const InputDecoration(
                  labelText: 'المختبر المعني',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('كل المختبرات'),
                  ),
                  for (final l in _labs)
                    DropdownMenuItem(
                      value: l['id']?.toString(),
                      child: Text(l['name']?.toString() ?? ''),
                    ),
                ],
                onChanged: (v) => setState(() => _labId = v),
              ),
            ],
            if (_scope == _Scope.ghadeer)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'إعلانات ورسائل عيادة الغدير — بدون اختيار طبيب أو مختبر.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B6C70)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scopeChip(_Scope scope, String label) {
    final selected = _scope == scope;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) {
          setState(() {
            _scope = scope;
            if (scope != _Scope.doctor) _doctorId = null;
            if (scope != _Scope.lab) _labId = null;
          });
        },
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('العنوان', style: _headStyle)),
          Expanded(flex: 2, child: Text('المعني', style: _headStyle)),
          Expanded(child: Text('الحالة', style: _headStyle)),
          Expanded(child: Text('التاريخ', style: _headStyle)),
          SizedBox(width: 36),
        ],
      ),
    );
  }

  static const _headStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 12.5,
  );

  Widget _tableRow(AdminNotificationItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCompose(existing: item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      item.repeatEnabled && item.repeatDays.isNotEmpty
                          ? '🔁 ${item.repeatDays.join(' · ')} · ${item.repeatHour.toString().padLeft(2, '0')}:${item.repeatMinute.toString().padLeft(2, '0')}'
                          : item.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _rowSourceLabel(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  _statusLabel(item.status),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  _when(item),
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  try {
                    if (v == 'edit') {
                      await _openCompose(existing: item);
                    } else if (v == 'sent') {
                      await _service.setStatus(
                        item.id,
                        NotificationStatus.sent,
                      );
                      _load();
                    } else if (v == 'cancel') {
                      await _service.setStatus(
                        item.id,
                        NotificationStatus.cancelled,
                      );
                      _load();
                    } else if (v == 'delete') {
                      await _service.delete(item.id);
                      _load();
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر التنفيذ: $e')),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  if (item.status != NotificationStatus.sent)
                    const PopupMenuItem(
                      value: 'sent',
                      child: Text('نشر للصندوق'),
                    ),
                  if (item.status == NotificationStatus.draft ||
                      item.status == NotificationStatus.scheduled)
                    const PopupMenuItem(value: 'cancel', child: Text('إلغاء')),
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleComposeSheet extends StatefulWidget {
  const _SimpleComposeSheet({
    required this.service,
    required this.doctors,
    required this.labs,
    required this.initialScope,
    this.existing,
    this.initialDoctorId,
    this.initialLabId,
  });

  final NotificationsAdminService service;
  final List<Map<String, dynamic>> doctors;
  final List<Map<String, dynamic>> labs;
  final _Scope initialScope;
  final AdminNotificationItem? existing;
  final String? initialDoctorId;
  final String? initialLabId;

  @override
  State<_SimpleComposeSheet> createState() => _SimpleComposeSheetState();
}

class _SimpleComposeSheetState extends State<_SimpleComposeSheet> {
  late _Scope _scope;
  String? _doctorId;
  String? _labId;
  bool _saving = false;
  bool _repeatEnabled = false;
  final Set<String> _repeatDays = {};
  int _repeatHour = 9;
  int _repeatMinute = 0;

  late final TextEditingController _title;
  late final TextEditingController _body;

  bool get _isEdit =>
      widget.existing != null && widget.existing!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null && e.id.isNotEmpty) {
      _scope = e.source == 'doctor'
          ? _Scope.doctor
          : e.source == 'lab'
              ? _Scope.lab
              : _Scope.ghadeer;
    } else if (widget.initialScope == _Scope.all) {
      _scope = _Scope.ghadeer;
    } else {
      _scope = widget.initialScope;
    }
    _doctorId = widget.initialDoctorId ?? e?.doctorId;
    _labId = widget.initialLabId ?? e?.labId;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _repeatEnabled = e?.repeatEnabled ?? false;
    _repeatDays.addAll(e?.repeatDays ?? const []);
    _repeatHour = e?.repeatHour ?? 9;
    _repeatMinute = e?.repeatMinute ?? 0;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String get _type {
    switch (_scope) {
      case _Scope.doctor:
        return NotificationTypes.doctorManual;
      case _Scope.lab:
        return NotificationTypes.labManual;
      case _Scope.ghadeer:
      case _Scope.all:
        return NotificationTypes.ghadeerManual;
    }
  }

  String get _destinationKind {
    switch (_scope) {
      case _Scope.doctor:
        return 'doctor';
      case _Scope.lab:
        return 'lab';
      case _Scope.ghadeer:
      case _Scope.all:
        return 'home';
    }
  }

  Future<void> _save(String status) async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب عنوان الإشعار')),
      );
      return;
    }
    if (_scope == _Scope.doctor &&
        (_doctorId == null || _doctorId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الطبيب المعني')),
      );
      return;
    }
    if (_scope == _Scope.lab && (_labId == null || _labId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المختبر المعني')),
      );
      return;
    }
    if (_repeatEnabled && _repeatDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر أيام التكرار')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final doctorId = _scope == _Scope.doctor ? _doctorId : null;
      final labId = _scope == _Scope.lab ? _labId : null;
      // مع التكرار: نحفظ كقاعدة مجدولة حتى لا يُعاد الإرسال يدويًا كل مرة.
      final saveStatus = _repeatEnabled && status == NotificationStatus.sent
          ? NotificationStatus.scheduled
          : status;
      final orderedDays = [
        for (final d in AdminNotificationItem.weekDays)
          if (_repeatDays.contains(d)) d,
      ];
      await widget.service.upsert(
        id: _isEdit ? widget.existing!.id : null,
        title: _title.text.trim(),
        body: _body.text.trim(),
        type: _type,
        status: saveStatus,
        audience: 'all',
        destinationKind: _destinationKind,
        destinationId: doctorId ?? labId,
        doctorId: doctorId,
        labId: labId,
        templateKey: _type,
        origin: _repeatEnabled ? 'auto' : 'manual',
        repeatEnabled: _repeatEnabled,
        repeatDays: orderedDays,
        repeatHour: _repeatHour,
        repeatMinute: _repeatMinute,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحفظ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'تعديل إشعار' : 'إشعار جديد',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('عيادة الغدير'),
                    selected: _scope == _Scope.ghadeer,
                    onSelected: _isEdit
                        ? null
                        : (_) => setState(() {
                              _scope = _Scope.ghadeer;
                              _doctorId = null;
                              _labId = null;
                            }),
                  ),
                  ChoiceChip(
                    label: const Text('طبيب'),
                    selected: _scope == _Scope.doctor,
                    onSelected: _isEdit
                        ? null
                        : (_) => setState(() {
                              _scope = _Scope.doctor;
                              _labId = null;
                            }),
                  ),
                  ChoiceChip(
                    label: const Text('مختبر'),
                    selected: _scope == _Scope.lab,
                    onSelected: _isEdit
                        ? null
                        : (_) => setState(() {
                              _scope = _Scope.lab;
                              _doctorId = null;
                            }),
                  ),
                ],
              ),
              if (_scope == _Scope.ghadeer)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'اكتب الإعلان أو الرسالة مباشرة — بدون طبيب أو مختبر.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5B6C70)),
                  ),
                ),
              if (_scope == _Scope.doctor) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _doctorId,
                  decoration: const InputDecoration(
                    labelText: 'الطبيب المعني',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final d in widget.doctors)
                      DropdownMenuItem(
                        value: d['id']?.toString(),
                        child: Text(d['doctor_name']?.toString() ?? ''),
                      ),
                  ],
                  onChanged: (v) => setState(() => _doctorId = v),
                ),
              ],
              if (_scope == _Scope.lab) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _labId,
                  decoration: const InputDecoration(
                    labelText: 'المختبر المعني',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final l in widget.labs)
                      DropdownMenuItem(
                        value: l['id']?.toString(),
                        child: Text(l['name']?.toString() ?? ''),
                      ),
                  ],
                  onChanged: (v) => setState(() => _labId = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'النص',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تكرار تلقائي'),
                subtitle: const Text(
                  'يعيد الإشعار في الأيام المحددة (طبيب / مختبر / عيادة الغدير)',
                ),
                value: _repeatEnabled,
                onChanged: (v) => setState(() => _repeatEnabled = v),
              ),
              if (_repeatEnabled) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final day in AdminNotificationItem.weekDays)
                      FilterChip(
                        label: Text(day),
                        selected: _repeatDays.contains(day),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _repeatDays.add(day);
                            } else {
                              _repeatDays.remove(day);
                            }
                          });
                        },
                      ),
                  ],
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('وقت التكرار'),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: _repeatHour,
                          minute: _repeatMinute,
                        ),
                      );
                      if (picked == null) return;
                      setState(() {
                        _repeatHour = picked.hour;
                        _repeatMinute = picked.minute;
                      });
                    },
                    child: Text(
                      '${_repeatHour.toString().padLeft(2, '0')}:${_repeatMinute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => _save(NotificationStatus.draft),
                      child: const Text('مسودة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : () => _save(NotificationStatus.sent),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0FAFA3),
                      ),
                      child: Text(
                        _saving
                            ? '...'
                            : (_repeatEnabled ? 'حفظ التكرار' : 'نشر'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
