import 'package:flutter/material.dart';

import 'doctor_availability_service.dart';
import '../widgets/clinic_app_bar.dart';

/// إدارة إجازات طبيب واحد — تقويم من/إلى + مزامنة حالة الإجازة للبطاقة.
class DoctorAbsencesAdminPage extends StatefulWidget {
  const DoctorAbsencesAdminPage({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  final String doctorId;
  final String doctorName;

  @override
  State<DoctorAbsencesAdminPage> createState() =>
      _DoctorAbsencesAdminPageState();
}

class _DoctorAbsencesAdminPageState extends State<DoctorAbsencesAdminPage> {
  final _service = DoctorAvailabilityService();
  List<DoctorAbsence> _items = [];
  bool _loading = true;
  String? _error;
  bool _tableMissing = false;
  DateTime? _mirrorFrom;
  DateTime? _mirrorTo;

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
      final hasTable = await _service.hasAbsencesTable();
      final mirror = await _service.fetchDoctorLeaveMirror(widget.doctorId);

      if (!hasTable) {
        if (!mounted) return;
        setState(() {
          _tableMissing = true;
          _mirrorFrom = mirror.from;
          _mirrorTo = mirror.to;
          _items = [];
          _loading = false;
        });
        return;
      }

      final items = await _service.fetchAbsencesForDoctor(widget.doctorId);
      if (!mounted) return;
      setState(() {
        _tableMissing = false;
        _items = items;
        _mirrorFrom = mirror.from;
        _mirrorTo = mirror.to;
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

  Future<void> _openEditor({DoctorAbsence? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _AbsenceEditorSheet(
        service: _service,
        doctorId: widget.doctorId,
        existing: existing,
        simpleMode: _tableMissing,
        initialFrom: _tableMissing ? _mirrorFrom : existing?.startDate,
        initialTo: _tableMissing ? _mirrorTo : existing?.endDate,
      ),
    );
    if (saved == true && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ الإجازة — ستظهر في مربع التواجد إذا كانت الفترة سارية.',
          ),
        ),
      );
    }
  }

  Future<void> _clearSimpleLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الإجازة؟'),
          content: const Text('سيتم مسح فترة الإجازة الحالية لهذا الطبيب.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إلغاء الإجازة'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _service.setDoctorLeaveDirect(doctorId: widget.doctorId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الإجازة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الإلغاء: $e')),
      );
    }
  }

  Future<void> _toggle(DoctorAbsence item, bool value) async {
    try {
      await _service.setAbsenceActive(
        id: item.id,
        doctorId: widget.doctorId,
        isActive: value,
      );
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((e) => e.id == item.id);
        if (i >= 0) _items[i] = item.copyWith(isActive: value);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'تم التفعيل' : 'تم التعطيل')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر التحديث: $e')));
    }
  }

  Future<void> _confirmDelete(DoctorAbsence item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الإجازة؟'),
          content: const Text('سيتم حذف سجل الإجازة نهائيًا.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteAbsence(id: item.id, doctorId: widget.doctorId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر الحذف: $e')));
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBFC),
        appBar: ClinicAppBar(
          title: Text('إجازات ${widget.doctorName}'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.event_available_rounded),
          label: Text(_tableMissing ? 'تحديد إجازة' : 'إضافة إجازة'),
        ),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('إعادة')),
            ],
          ),
        ),
      );
    }

    if (_tableMissing) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8D9A8)),
            ),
            child: const Text(
              'يمكنك تحديد الإجازة الآن عبر التقويم (من → إلى).\n'
              'لسجل إجازات متعدد لاحقًا نفّذ supabase/doctor_absences_schema.sql',
              style: TextStyle(
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B5A20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_mirrorFrom != null && _mirrorTo != null)
            _simpleLeaveCard()
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'لا توجد إجازة محددة — اضغط «تحديد إجازة» واختر التواريخ من التقويم',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF708084), height: 1.4),
                ),
              ),
            ),
        ],
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد إجازات مسجّلة لهذا الطبيب\nاضغط «إضافة إجازة» واختر من/إلى من التقويم',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF708084), height: 1.45),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final today = DoctorLeaveDisplay.dateOnly(DateTime.now());
          final coversToday =
              item.isActive &&
              !today.isBefore(item.startDate) &&
              !today.isAfter(item.endDate);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: coversToday
                        ? const Color(0xFFFFE0A3)
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
                            item.startDate == item.endDate
                                ? 'يوم ${_fmt(item.startDate)}'
                                : 'من ${_fmt(item.startDate)} إلى ${_fmt(item.endDate)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                              color: Color(0xFF123B42),
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: item.isActive,
                          activeThumbColor: const Color(0xFF0FAFA3),
                          onChanged: (v) => _toggle(item, v),
                        ),
                      ],
                    ),
                    if (item.reason.trim().isNotEmpty)
                      Text(
                        item.reason,
                        style: const TextStyle(
                          color: Color(0xFF5B6C70),
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _chip(item.isActive ? 'مفعّلة' : 'معطّلة'),
                        if (coversToday) _chip('سارية اليوم'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openEditor(existing: item),
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
                            onPressed: () => _confirmDelete(item),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFC94A4A),
                              size: 18,
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
            ),
          );
        },
      ),
    );
  }

  Widget _simpleLeaveCard() {
    final from = _mirrorFrom!;
    final to = _mirrorTo!;
    final today = DoctorLeaveDisplay.dateOnly(DateTime.now());
    final coversToday = !today.isBefore(from) && !today.isAfter(to);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: coversToday
                ? const Color(0xFFFFE0A3)
                : const Color(0xFFE4EEEE),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              from == to ? 'يوم ${_fmt(from)}' : 'من ${_fmt(from)} إلى ${_fmt(to)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15.5,
                color: Color(0xFF123B42),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _chip('مفعّلة'),
                if (coversToday) _chip('سارية اليوم'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditor(),
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
                    onPressed: _clearSimpleLeave,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFC94A4A),
                      size: 18,
                    ),
                    label: const Text(
                      'إلغاء',
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

  Widget _chip(String label) {
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

class _AbsenceEditorSheet extends StatefulWidget {
  const _AbsenceEditorSheet({
    required this.service,
    required this.doctorId,
    this.existing,
    this.simpleMode = false,
    this.initialFrom,
    this.initialTo,
  });

  final DoctorAvailabilityService service;
  final String doctorId;
  final DoctorAbsence? existing;
  final bool simpleMode;
  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<_AbsenceEditorSheet> createState() => _AbsenceEditorSheetState();
}

class _AbsenceEditorSheetState extends State<_AbsenceEditorSheet> {
  late DateTime _start;
  late DateTime _end;
  late final TextEditingController _reason;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final today = DoctorLeaveDisplay.dateOnly(DateTime.now());
    _start = e?.startDate ?? widget.initialFrom ?? today;
    _end = e?.endDate ?? widget.initialTo ?? today;
    _reason = TextEditingController(text: e?.reason ?? '');
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'اختر بداية الإجازة',
      cancelText: 'إلغاء',
      confirmText: 'تم',
      fieldLabelText: 'من تاريخ',
    );
    if (picked == null) return;
    setState(() {
      _start = DoctorLeaveDisplay.dateOnly(picked);
      if (_end.isBefore(_start)) _end = _start;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: DateTime(2100),
      helpText: 'اختر نهاية الإجازة',
      cancelText: 'إلغاء',
      confirmText: 'تم',
      fieldLabelText: 'إلى تاريخ',
    );
    if (picked == null) return;
    setState(() => _end = DoctorLeaveDisplay.dateOnly(picked));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (widget.simpleMode) {
        await widget.service.setDoctorLeaveDirect(
          doctorId: widget.doctorId,
          from: _start,
          to: _end,
        );
      } else {
        final absence = DoctorAbsence(
          id: widget.existing?.id ?? '',
          doctorId: widget.doctorId,
          startDate: _start,
          endDate: _end,
          reason: _reason.text.trim(),
          isActive: _isActive,
        );
        await widget.service.upsertAbsence(
          absence,
          existingId: widget.existing?.id,
        );
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

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
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
                widget.existing == null ? 'تحديد إجازة' : 'تعديل الإجازة',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF123B42),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'اضغط لاختيار التاريخ من التقويم',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7C80),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickStart,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text('من: ${_fmt(_start)}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: const Color(0xFF0FAFA3),
                  side: const BorderSide(color: Color(0xFF0FAFA3)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickEnd,
                icon: const Icon(Icons.event_available_rounded),
                label: Text('إلى: ${_fmt(_end)}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: const Color(0xFF0FAFA3),
                  side: const BorderSide(color: Color(0xFF0FAFA3)),
                ),
              ),
              if (!widget.simpleMode) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _reason,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'السبب (اختياري)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مفعّلة'),
                  subtitle: const Text(
                    'إن كانت الفترة تغطي اليوم تظهر رسالة الإجازة في بطاقة الطبيب',
                  ),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'عند الحفظ: إن كانت الفترة تشمل اليوم، يظهر الطبيب بحالة إجازة والرسالة في مربع التواجد.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7C80),
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الإجازة'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0FAFA3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
