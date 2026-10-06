import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/clinic_app_bar.dart';
import 'attachment_view.dart';
import 'follow_up_card_page.dart';
import 'patient_health_models.dart';
import 'patient_health_repository.dart';
import 'patient_health_validation.dart';

class PatientHealthPage extends StatefulWidget {
  const PatientHealthPage({
    super.key,
    required this.repository,
    required this.onSignOut,
    required this.onDeleteAccount,
    this.now,
  });

  final PatientHealthRepository repository;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;
  final DateTime Function()? now;

  @override
  State<PatientHealthPage> createState() => _PatientHealthPageState();
}

class _PatientHealthPageState extends State<PatientHealthPage> {
  PatientHealthSnapshot? _snapshot;
  bool _loading = true;
  String? _error;
  bool _consent = false;
  final _name = TextEditingController();
  final _attachments = AttachmentByteStore();

  DateTime get _now => widget.now?.call() ?? DateTime.now();
  String get _userId => widget.repository.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      _name.text = snapshot.profile?.displayName ?? _name.text;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = patientHealthErrorMessage(error);
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(patientHealthErrorMessage(error))),
      );
    }
  }

  Future<void> _saveConsent() async {
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الموافقة مطلوبة قبل حفظ أي بيانات صحية.')),
      );
      return;
    }
    await _run(() {
      return widget.repository.saveConsent(displayName: _name.text, at: _now);
    });
  }

  Future<void> _addCondition() async {
    final draft = await showModalBottomSheet<_ConditionDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ConditionSheet(),
    );
    if (draft == null) return;
    final now = _now;
    await _run(() async {
      await widget.repository.saveCondition(
        PatientCondition(
          id: newHealthId(),
          userId: _userId,
          kind: draft.kind,
          label: draft.label,
          thalassemiaType: draft.thalassemiaType,
          prescribedTreatment: draft.treatment,
          reviewsNote: draft.reviews,
          notes: draft.notes,
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }

  Future<void> _editCondition(PatientCondition condition) async {
    final draft = await showModalBottomSheet<_ConditionDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ConditionSheet(initial: condition),
    );
    if (draft == null) return;
    await _run(() async {
      await widget.repository.saveCondition(
        condition.copyWith(
          label: draft.label,
          thalassemiaType: draft.thalassemiaType,
          prescribedTreatment: draft.treatment,
          reviewsNote: draft.reviews,
          notes: draft.notes,
          updatedAt: _now,
        ),
      );
    });
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _onMenu(
    String value,
    NavigatorState navigator,
    ScaffoldMessengerState messenger,
  ) async {
    if (value == 'out') {
      await widget.onSignOut();
      navigator.pop();
      return;
    }
    if (value == 'file') {
      final ok = await _confirm(
        'حذف الملف الصحي؟',
        'تنحذف السجلات والمرفقات من حسابك. حساب الدخول يبقى.',
      );
      if (!ok) return;
      await _run(widget.repository.deleteOwnFile);
      return;
    }
    if (value != 'account') return;
    final ok = await _confirm(
      'حذف الحساب؟',
      'تنحذف السجلات والمرفقات وحساب الدخول والجلسة. ما نكدر نرجّعها.',
    );
    if (!ok) return;
    try {
      await widget.onDeleteAccount();
      navigator.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(patientHealthErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('ملفي الصحي'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                _onMenu(value, navigator, messenger);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'out', child: Text('تسجيل الخروج')),
                PopupMenuItem(value: 'file', child: Text('حذف الملف الصحي')),
                PopupMenuItem(value: 'account', child: Text('حذف الحساب')),
              ],
            ),
          ],
        ),
        floatingActionButton: _snapshot?.profile == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _addCondition,
                icon: const Icon(Icons.add),
                label: const Text('إضافة مرض'),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _message(_error!)
                : _snapshot?.profile == null
                    ? _consentForm()
                    : _file(_snapshot!),
      ),
    );
  }

  Widget _message(String text) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(text, style: const TextStyle(height: 1.4)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
      ],
    );
  }

  Widget _consentForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(patientEnteredBanner, style: TextStyle(height: 1.45)),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'الاسم على البطاقة (اختياري)',
            border: OutlineInputBorder(),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          onChanged: (value) => setState(() => _consent = value ?? false),
          title: const Text('أوافق على حفظ بياناتي الصحية في حسابي فقط'),
          subtitle: const Text(
            'ما تنشارك مع إدارة الغدير أو الصيدليات أو المختبرات أو الأطباء تلقائياً.',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saveConsent,
          child: const Text('حفظ الموافقة'),
        ),
      ],
    );
  }

  Widget _file(PatientHealthSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        const Text(patientEnteredBanner, style: TextStyle(height: 1.45)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: snapshot.conditions.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowUpCardPage(
                        userId: _userId,
                        snapshot: snapshot,
                        repository: widget.repository,
                        store: _attachments,
                        now: widget.now,
                      ),
                    ),
                  );
                },
          child: const Text('عرض بطاقة المتابعة'),
        ),
        const SizedBox(height: 12),
        if (snapshot.conditions.isEmpty)
          const Text('ما عندك مرض مسجّل بعد. اضغط «إضافة مرض».')
        else
          for (final condition in snapshot.conditions)
            _conditionCard(snapshot, condition),
      ],
    );
  }

  Widget _conditionCard(PatientHealthSnapshot snapshot, PatientCondition condition) {
    final timeline = _timeline(snapshot, condition);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              condition.title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              '${conditionKindLabel(condition.kind)} · أدخلها المريض',
              style: const TextStyle(color: Color(0xFF0C7F76)),
            ),
            if (condition.kind == ConditionKind.thalassemia)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'سجّل المواعيد ونقل الدم ونتائج التحاليل حسب خطة طبيبك. '
                  'التطبيق ما يستنتج جدول علاج.',
                  style: TextStyle(height: 1.35),
                ),
              ),
            if (condition.prescribedTreatment.trim().isNotEmpty)
              Text('العلاج الموصوف: ${condition.prescribedTreatment}'),
            if (condition.reviewsNote.trim().isNotEmpty)
              Text('المراجعات: ${condition.reviewsNote}'),
            if (condition.notes.trim().isNotEmpty)
              Text('ملاحظات: ${condition.notes}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (condition.kind == ConditionKind.hypertension)
                  OutlinedButton(
                    onPressed: () => _editBp(condition),
                    child: const Text('قراءة ضغط'),
                  ),
                if (condition.kind == ConditionKind.diabetes)
                  OutlinedButton(
                    onPressed: () => _editGlucose(condition),
                    child: const Text('قراءة سكر'),
                  ),
                if (condition.kind == ConditionKind.thalassemia)
                  OutlinedButton(
                    onPressed: () => _editEvent(condition),
                    child: const Text('سجل موعد أو تحليل'),
                  ),
                OutlinedButton(
                  onPressed: () => _editCondition(condition),
                  child: const Text('تعديل البيانات'),
                ),
                OutlinedButton(
                  onPressed: () => _attach(condition),
                  child: const Text('إرفاق صورة'),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await _confirm(
                      'حذف المرض؟',
                      'تنحذف قراءاته ومرفقاته من حسابك.',
                    );
                    if (!ok) return;
                    await _run(() => widget.repository.deleteCondition(condition.id));
                  },
                  child: const Text('حذف المرض'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('السجل', style: TextStyle(fontWeight: FontWeight.w900)),
            if (timeline.isEmpty)
              const Text('ماكو قراءات بعد.')
            else
              for (final item in timeline) item,
            for (final file in snapshot.attachments)
              if (file.conditionId == condition.id)
                PatientAttachmentTile(
                  attachment: file,
                  repository: widget.repository,
                  store: _attachments,
                  onDelete: () => _run(() async {
                    _attachments.remove(file.id);
                    await widget.repository.deleteAttachment(file.id);
                  }),
                ),
          ],
        ),
      ),
    );
  }

  List<Widget> _timeline(PatientHealthSnapshot snapshot, PatientCondition condition) {
    final items = <({DateTime at, Widget child})>[];
    for (final row in snapshot.bpReadings) {
      if (row.conditionId != condition.id) continue;
      items.add((
        at: row.measuredAt,
        child: _row(
          title: '${row.systolic}/${row.diastolic} ملم زئبق'
              '${row.pulse == null ? '' : ' · نبض ${row.pulse}'}',
          stamp: row.measuredAt,
          onEdit: () => _editBp(condition, existing: row),
          onDelete: () => _run(() => widget.repository.deleteBp(row.id)),
        ),
      ));
    }
    for (final row in snapshot.glucoseReadings) {
      if (row.conditionId != condition.id) continue;
      items.add((
        at: row.measuredAt,
        child: _row(
          title:
              '${row.value} ${glucoseUnitLabel(row.unit)} · ${glucoseTimingLabel(row.timing)}',
          stamp: row.measuredAt,
          onEdit: () => _editGlucose(condition, existing: row),
          onDelete: () => _run(() => widget.repository.deleteGlucose(row.id)),
        ),
      ));
    }
    for (final row in snapshot.events) {
      if (row.conditionId != condition.id) continue;
      items.add((
        at: row.occurredAt,
        child: _row(
          title: '${thalassemiaEventLabel(row.kind)} · ${row.title}',
          stamp: row.occurredAt,
          detail: row.details,
          onEdit: () => _editEvent(condition, existing: row),
          onDelete: () => _run(() => widget.repository.deleteEvent(row.id)),
        ),
      ));
    }
    items.sort((a, b) => b.at.compareTo(a.at));
    return [for (final item in items) item.child];
  }

  Widget _row({
    required String title,
    required DateTime stamp,
    String detail = '',
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        detail.trim().isEmpty
            ? formatHealthStamp(stamp)
            : '${formatHealthStamp(stamp)}\n$detail',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(tooltip: 'تعديل', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            tooltip: 'حذف',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Future<void> _editBp(PatientCondition condition, {BpReading? existing}) async {
    final result = await showDialog<_BpDraft>(
      context: context,
      builder: (context) => _BpDialog(existing: existing, now: _now),
    );
    if (result == null) return;
    final error = validateBloodPressure(
      systolic: result.systolic,
      diastolic: result.diastolic,
      pulse: result.pulse,
      measuredAt: result.measuredAt,
      now: _now,
    );
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _run(() async {
      await widget.repository.saveBp(
        BpReading(
          id: existing?.id ?? newHealthId(),
          userId: _userId,
          conditionId: condition.id,
          systolic: parseHealthInt(result.systolic)!,
          diastolic: parseHealthInt(result.diastolic)!,
          pulse: result.pulse.trim().isEmpty ? null : parseHealthInt(result.pulse),
          measuredAt: result.measuredAt,
        ),
      );
    });
  }

  Future<void> _editGlucose(
    PatientCondition condition, {
    GlucoseReading? existing,
  }) async {
    final result = await showDialog<_GlucoseDraft>(
      context: context,
      builder: (context) => _GlucoseDialog(existing: existing, now: _now),
    );
    if (result == null) return;
    final error = validateGlucose(
      value: result.value,
      unit: result.unit,
      measuredAt: result.measuredAt,
      now: _now,
    );
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _run(() async {
      await widget.repository.saveGlucose(
        GlucoseReading(
          id: existing?.id ?? newHealthId(),
          userId: _userId,
          conditionId: condition.id,
          value: parseHealthDouble(result.value)!,
          unit: result.unit,
          timing: result.timing,
          measuredAt: result.measuredAt,
        ),
      );
    });
  }

  Future<void> _editEvent(
    PatientCondition condition, {
    ThalassemiaEvent? existing,
  }) async {
    final result = await showDialog<_EventDraft>(
      context: context,
      builder: (context) => _EventDialog(existing: existing, now: _now),
    );
    if (result == null) return;
    final error = validateEventTitle(result.title) ??
        validateMeasuredAt(result.occurredAt, _now);
    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _run(() async {
      await widget.repository.saveEvent(
        ThalassemiaEvent(
          id: existing?.id ?? newHealthId(),
          userId: _userId,
          conditionId: condition.id,
          kind: result.kind,
          title: result.title.trim(),
          details: result.details.trim(),
          occurredAt: result.occurredAt,
        ),
      );
    });
  }

  Future<void> _attach(PatientCondition condition) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _run(() async {
      final saved = await widget.repository.addAttachment(
        conditionId: condition.id,
        fileName: picked.name,
        bytes: bytes,
        contentType: picked.mimeType ?? 'image/jpeg',
      );
      _attachments.put(saved.id, bytes);
    });
  }
}

class _ConditionDraft {
  const _ConditionDraft({
    required this.kind,
    required this.label,
    required this.thalassemiaType,
    required this.treatment,
    required this.reviews,
    required this.notes,
  });

  final ConditionKind kind;
  final String label;
  final String thalassemiaType;
  final String treatment;
  final String reviews;
  final String notes;
}

class _ConditionSheet extends StatefulWidget {
  const _ConditionSheet({this.initial});

  final PatientCondition? initial;

  @override
  State<_ConditionSheet> createState() => _ConditionSheetState();
}

class _ConditionSheetState extends State<_ConditionSheet> {
  late ConditionKind _kind;
  late final TextEditingController _label;
  late final TextEditingController _type;
  late final TextEditingController _treatment;
  late final TextEditingController _reviews;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _kind = initial?.kind ?? ConditionKind.hypertension;
    _label = TextEditingController(text: initial?.label ?? '');
    _type = TextEditingController(text: initial?.thalassemiaType ?? '');
    _treatment = TextEditingController(text: initial?.prescribedTreatment ?? '');
    _reviews = TextEditingController(text: initial?.reviewsNote ?? '');
    _notes = TextEditingController(text: initial?.notes ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _type.dispose();
    _treatment.dispose();
    _reviews.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'مرض مشخص من طبيبك، وتسجّله أنت.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (widget.initial == null)
              Wrap(
                spacing: 8,
                children: [
                  for (final kind in ConditionKind.values)
                    ChoiceChip(
                      label: Text(conditionKindLabel(kind)),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: _kind == ConditionKind.other
                    ? 'اسم المرض'
                    : 'اسم يظهر لك (اختياري)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_kind == ConditionKind.thalassemia) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _type,
                decoration: const InputDecoration(
                  labelText: 'نوع الحالة إن كان معروفاً',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _treatment,
              decoration: const InputDecoration(
                labelText: 'العلاج الموصوف (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviews,
              decoration: const InputDecoration(
                labelText: 'المراجعات (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final error = validateConditionLabel(_kind, _label.text);
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  _ConditionDraft(
                    kind: _kind,
                    label: _label.text.trim(),
                    thalassemiaType: _type.text.trim(),
                    treatment: _treatment.text.trim(),
                    reviews: _reviews.text.trim(),
                    notes: _notes.text.trim(),
                  ),
                );
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BpDraft {
  const _BpDraft({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.measuredAt,
  });

  final String systolic;
  final String diastolic;
  final String pulse;
  final DateTime measuredAt;
}

class _BpDialog extends StatefulWidget {
  const _BpDialog({this.existing, required this.now});

  final BpReading? existing;
  final DateTime now;

  @override
  State<_BpDialog> createState() => _BpDialogState();
}

class _BpDialogState extends State<_BpDialog> {
  late final TextEditingController _sys;
  late final TextEditingController _dia;
  late final TextEditingController _pulse;
  late final TextEditingController _when;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _sys = TextEditingController(text: existing == null ? '' : '${existing.systolic}');
    _dia = TextEditingController(text: existing == null ? '' : '${existing.diastolic}');
    _pulse = TextEditingController(text: existing?.pulse?.toString() ?? '');
    _when = TextEditingController(
      text: formatHealthStamp(existing?.measuredAt ?? widget.now).replaceAll('/', '-'),
    );
  }

  @override
  void dispose() {
    _sys.dispose();
    _dia.dispose();
    _pulse.dispose();
    _when.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('قراءة الضغط'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _sys,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الانقباضي'),
              ),
              TextField(
                controller: _dia,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الانبساطي'),
              ),
              TextField(
                controller: _pulse,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'النبض (اختياري)'),
              ),
              TextField(
                controller: _when,
                decoration: const InputDecoration(
                  labelText: 'التاريخ والوقت',
                  hintText: '2026-10-04 18:30',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final when = parseHealthStamp(_when.text);
              if (when == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('صيغة التاريخ: 2026-10-04 18:30')),
                );
                return;
              }
              Navigator.pop(
                context,
                _BpDraft(
                  systolic: _sys.text,
                  diastolic: _dia.text,
                  pulse: _pulse.text,
                  measuredAt: when,
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _GlucoseDraft {
  const _GlucoseDraft({
    required this.value,
    required this.unit,
    required this.timing,
    required this.measuredAt,
  });

  final String value;
  final GlucoseUnit unit;
  final GlucoseTiming timing;
  final DateTime measuredAt;
}

class _GlucoseDialog extends StatefulWidget {
  const _GlucoseDialog({this.existing, required this.now});

  final GlucoseReading? existing;
  final DateTime now;

  @override
  State<_GlucoseDialog> createState() => _GlucoseDialogState();
}

class _GlucoseDialogState extends State<_GlucoseDialog> {
  late final TextEditingController _value;
  late final TextEditingController _when;
  late GlucoseUnit _unit;
  late GlucoseTiming _timing;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _value = TextEditingController(text: existing == null ? '' : '${existing.value}');
    _unit = existing?.unit ?? GlucoseUnit.mgDl;
    _timing = existing?.timing ?? GlucoseTiming.fasting;
    _when = TextEditingController(
      text: formatHealthStamp(existing?.measuredAt ?? widget.now).replaceAll('/', '-'),
    );
  }

  @override
  void dispose() {
    _value.dispose();
    _when.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('قراءة السكر'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'القيمة'),
              ),
              DropdownButtonFormField<GlucoseUnit>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'الوحدة'),
                items: [
                  for (final unit in GlucoseUnit.values)
                    DropdownMenuItem(
                      value: unit,
                      child: Text(glucoseUnitLabel(unit)),
                    ),
                ],
                onChanged: (value) => setState(() => _unit = value ?? _unit),
              ),
              DropdownButtonFormField<GlucoseTiming>(
                initialValue: _timing,
                decoration: const InputDecoration(labelText: 'وقت القياس'),
                items: [
                  for (final timing in GlucoseTiming.values)
                    DropdownMenuItem(
                      value: timing,
                      child: Text(glucoseTimingLabel(timing)),
                    ),
                ],
                onChanged: (value) => setState(() => _timing = value ?? _timing),
              ),
              TextField(
                controller: _when,
                decoration: const InputDecoration(labelText: 'التاريخ والوقت'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final when = parseHealthStamp(_when.text);
              if (when == null) return;
              Navigator.pop(
                context,
                _GlucoseDraft(
                  value: _value.text,
                  unit: _unit,
                  timing: _timing,
                  measuredAt: when,
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _EventDraft {
  const _EventDraft({
    required this.kind,
    required this.title,
    required this.details,
    required this.occurredAt,
  });

  final ThalassemiaEventKind kind;
  final String title;
  final String details;
  final DateTime occurredAt;
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({this.existing, required this.now});

  final ThalassemiaEvent? existing;
  final DateTime now;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late ThalassemiaEventKind _kind;
  late final TextEditingController _title;
  late final TextEditingController _details;
  late final TextEditingController _when;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? ThalassemiaEventKind.appointment;
    _title = TextEditingController(text: existing?.title ?? '');
    _details = TextEditingController(text: existing?.details ?? '');
    _when = TextEditingController(
      text: formatHealthStamp(existing?.occurredAt ?? widget.now).replaceAll('/', '-'),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _when.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('سجل الثلاسيميا'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ThalassemiaEventKind>(
                initialValue: _kind,
                items: [
                  for (final kind in ThalassemiaEventKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(thalassemiaEventLabel(kind)),
                    ),
                ],
                onChanged: (value) => setState(() => _kind = value ?? _kind),
              ),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              TextField(
                controller: _details,
                decoration: const InputDecoration(labelText: 'التفاصيل التي أدخلتها'),
              ),
              TextField(
                controller: _when,
                decoration: const InputDecoration(labelText: 'التاريخ والوقت'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final when = parseHealthStamp(_when.text);
              if (when == null) return;
              Navigator.pop(
                context,
                _EventDraft(
                  kind: _kind,
                  title: _title.text,
                  details: _details.text,
                  occurredAt: when,
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
