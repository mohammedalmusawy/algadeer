import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../search/smart_search_models.dart';
import '../search/smart_search_service.dart';
import '../utils/contact_launch.dart';
import '../utils/web_app_only.dart';
import '../widgets/clinic_app_bar.dart';
import 'attachment_view.dart';
import 'card_export.dart';
import 'follow_up_card.dart';
import 'follow_up_insights.dart';
import 'follow_up_quick_entry.dart';
import 'follow_up_reminders.dart';
import 'follow_up_target_store.dart';
import 'patient_health_models.dart';
import 'patient_health_repository.dart';

/// طبيب من الغدير يمكن إرسال البطاقة له على واتساب.
class FollowUpDoctorContact {
  const FollowUpDoctorContact({
    required this.name,
    required this.specialty,
    required this.whatsapp,
  });

  final String name;
  final String specialty;
  final String whatsapp;
}

/// أطباء الغدير اللي عندهم رقم واتساب (أو هاتف) — مرتبين بالاسم.
List<FollowUpDoctorContact> followUpDoctorContacts(
  List<SmartSearchResult> doctors,
) {
  final out = <FollowUpDoctorContact>[];
  final seen = <String>{};
  for (final d in doctors) {
    final number = (d.whatsapp ?? '').trim().isNotEmpty
        ? d.whatsapp!.trim()
        : (d.phone ?? '').trim();
    if (clinicWhatsAppDigits(number).length < 8) continue;
    if (!seen.add('${d.title}|$number')) continue;
    out.add(
      FollowUpDoctorContact(
        name: d.title.trim(),
        specialty: (d.specialty ?? d.subtitle).trim(),
        whatsapp: number,
      ),
    );
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

/// رسالة واتساب جاهزة للطبيب — بلا أي أرقام صحية داخل الرسالة نفسها.
String followUpDoctorMessage({
  required String doctorName,
  required String conditionTitle,
}) {
  final name = doctorName.trim();
  final greet = name.isEmpty
      ? 'مرحباً دكتور'
      : (RegExp(r'^(د\.|دكتور|الدكتور|الدكتورة|دكتورة)').hasMatch(name)
            ? 'مرحباً $name'
            : 'مرحباً دكتور $name');
  return '$greet، راح أرسل لك بطاقة متابعة ($conditionTitle) '
      'من منصة الغدير كملف PDF. شكراً لوقتك.';
}

class FollowUpCardPage extends StatefulWidget {
  const FollowUpCardPage({
    super.key,
    required this.userId,
    required this.snapshot,
    required this.repository,
    required this.store,
    this.now,
    this.targetStore = const FollowUpTargetStore(),
    this.loadDoctors,
    this.openWhatsApp,
    this.reminderStore = const FollowUpReminderStore(),
    this.reminderScheduler,
  });

  final String userId;
  final PatientHealthSnapshot snapshot;
  final PatientHealthRepository repository;
  final AttachmentByteStore store;
  final DateTime Function()? now;
  final FollowUpTargetStore targetStore;

  /// للاختبار: مصدر أطباء الغدير (الافتراضي كاش البحث الذكي).
  final Future<List<SmartSearchResult>> Function()? loadDoctors;

  /// للاختبار: فتح واتساب الطبيب.
  final Future<void> Function(String whatsapp, String message)? openWhatsApp;

  final FollowUpReminderStore reminderStore;

  /// للاختبار: جدولة وهمية. الافتراضي إشعارات الجهاز المحلية.
  final ReminderScheduler? reminderScheduler;

  @override
  State<FollowUpCardPage> createState() => _FollowUpCardPageState();
}

class _FollowUpCardPageState extends State<FollowUpCardPage> {
  final _boundaryKey = GlobalKey();
  late String _conditionId;
  FollowUpPeriod _period = FollowUpPeriod.days30;
  bool _measurements = true;
  bool _treatment = false;
  bool _reviews = false;
  bool _notes = false;
  bool _events = true;
  bool _showName = false;
  bool _includeAttachments = false;
  final _selectedIds = <String>{};
  bool _busy = false;
  late PatientHealthSnapshot _snapshot;
  FollowUpTarget _target = const FollowUpTarget();
  List<ReminderTime> _reminders = const [];
  late final ReminderScheduler _scheduler =
      widget.reminderScheduler ?? LocalReminderScheduler();

  @override
  void initState() {
    super.initState();
    _snapshot = widget.snapshot;
    _conditionId = _snapshot.conditions.first.id;
    _loadTarget();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final id = _conditionId;
    final times = await widget.reminderStore.load(widget.userId, id);
    if (!mounted || id != _conditionId) return;
    setState(() => _reminders = times);
  }

  Future<void> _editReminders() async {
    if (!_scheduler.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            kIsWeb
                ? kWebAppOnlyMessage
                : 'التذكير يشتغل من تطبيق الموبايل (أندرويد أو آيفون).',
          ),
        ),
      );
      return;
    }
    final result = await showReminderTimesDialog(
      context: context,
      current: _reminders,
    );
    if (result == null || !mounted) return;
    final conditionId = _conditionId;
    try {
      if (result.isNotEmpty && !await _scheduler.requestPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'الإشعارات مقفولة. فعّلها للغدير من إعدادات الموبايل وارجع جرّب.',
            ),
          ),
        );
        return;
      }
      await applyFollowUpReminders(
        scheduler: _scheduler,
        store: widget.reminderStore,
        userId: widget.userId,
        conditionId: conditionId,
        times: result,
      );
      if (!mounted) return;
      if (conditionId == _conditionId) {
        setState(() => _reminders = result..sort());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEmpty
                ? 'انلغى تذكير القياس.'
                : 'راح نذكّرك كل يوم: ${[for (final t in result) t.label].join('، ')}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر ضبط التذكير. جرّب مرة ثانية.')),
      );
    }
  }

  PatientCondition get _condition => _snapshot.conditions.firstWhere(
    (c) => c.id == _conditionId,
    orElse: () => _snapshot.conditions.first,
  );

  bool get _hasMeasurements =>
      _condition.kind == ConditionKind.hypertension ||
      _condition.kind == ConditionKind.diabetes;

  Future<void> _loadTarget() async {
    final id = _conditionId;
    final target = await widget.targetStore.load(widget.userId, id);
    if (!mounted || id != _conditionId) return;
    setState(() => _target = target);
  }

  Future<void> _editTarget() async {
    final result = await showFollowUpTargetDialog(
      context: context,
      kind: _condition.kind,
      current: _target,
    );
    if (result == null || !mounted) return;
    setState(() => _target = result);
    try {
      await widget.targetStore.save(widget.userId, _conditionId, result);
    } catch (_) {
      // المدى يبقى للجلسة حتى لو تعذر الحفظ على الجهاز.
    }
  }

  Future<void> _quickReading() async {
    final reading = await showQuickReadingDialog(
      context: context,
      condition: _condition,
      userId: widget.userId,
      now: _now,
    );
    if (reading == null || !mounted) return;
    try {
      if (reading is BpReading) await widget.repository.saveBp(reading);
      if (reading is GlucoseReading) {
        await widget.repository.saveGlucose(reading);
      }
      final fresh = await widget.repository.load();
      if (!mounted) return;
      setState(() => _snapshot = fresh);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انحفظت القراءة وانضافت للبطاقة.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(patientHealthErrorMessage(error))));
    }
  }

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  List<HealthAttachment> get _conditionAttachments {
    return [
      for (final file in _snapshot.attachments)
        if (file.userId == widget.userId && file.conditionId == _conditionId)
          file,
    ];
  }

  List<HealthAttachment> get _selectedAttachments {
    if (!_includeAttachments) return const [];
    return [
      for (final file in _conditionAttachments)
        if (_selectedIds.contains(file.id)) file,
    ];
  }

  FollowUpSelection _selection(DateTime issuedAt) => FollowUpSelection(
    conditionId: _conditionId,
    period: _period,
    issuedAt: issuedAt,
    includeMeasurements: _measurements,
    includeTreatment: _treatment,
    includeReviews: _reviews,
    includeNotes: _notes,
    includeEvents: _events,
    showName: _showName,
  );

  Future<List<AttachmentExportReady>> _readyImages() {
    return loadAttachmentsForExport(
      selected: _selectedAttachments,
      load: (id) => widget.store.load(widget.repository, id),
    );
  }

  Future<bool> _confirmShare() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مشاركة البطاقة؟'),
        content: const Text(patientShareNotice),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    return agreed == true && mounted;
  }

  Future<void> _export({required bool pdf}) async {
    if (!await _confirmShare()) return;
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _busy = true);
    try {
      final images = await _readyImages();
      await WidgetsBinding.instance.endOfFrame;
      if (boundary.debugNeedsPaint) {
        await Future<void>.delayed(Duration.zero);
      }
      final png = await captureCardPng(boundary);
      if (pdf) {
        final bytes = await followUpExportPdf(
          cardPng: png,
          images: [for (final item in images) item.bytes],
        );
        await _deliver([
          PatientExportFile(
            bytes: bytes,
            filename: 'ghadeer-follow-up.pdf',
            mimeType: 'application/pdf',
          ),
        ]);
      } else {
        await _deliver([
          PatientExportFile(
            bytes: png,
            filename: 'ghadeer-follow-up.png',
            mimeType: 'image/png',
          ),
          for (var i = 0; i < images.length; i++)
            PatientExportFile(
              bytes: images[i].bytes,
              filename: safeExportFileName(
                images[i].attachment.fileName,
                i + 1,
              ),
              mimeType: attachmentMimeType(images[i].attachment.fileName),
            ),
        ]);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AttachmentExportFailure
                ? error.toString()
                : patientHealthErrorMessage(error),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendToDoctor() async {
    final doctor = await showModalBottomSheet<FollowUpDoctorContact>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DoctorPickerSheet(
        load:
            widget.loadDoctors ??
            () => SmartSearchService().activeDoctorsCatalog(),
      ),
    );
    if (doctor == null || !mounted) return;
    final message = followUpDoctorMessage(
      doctorName: doctor.name,
      conditionTitle: _condition.title,
    );
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إرسال البطاقة إلى ${doctor.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'خطوتين: افتح محادثة الطبيب على واتساب، بعدين ارجع وأرسل '
                  'ملف PDF واختار محادثته من المشاركة.',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const Key('send-doctor-open-chat'),
                  onPressed: () async {
                    final open =
                        widget.openWhatsApp ??
                        (String number, String text) =>
                            launchClinicWhatsApp(number, message: text);
                    try {
                      await open(doctor.whatsapp, message);
                    } catch (_) {
                      if (!sheet.mounted) return;
                      ScaffoldMessenger.of(sheet).showSnackBar(
                        const SnackBar(content: Text('تعذر فتح واتساب.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('١. افتح محادثة الطبيب'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('send-doctor-share-pdf'),
                  onPressed: () {
                    Navigator.pop(sheet);
                    _export(pdf: true);
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('٢. أرسل ملف PDF'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deliver(List<PatientExportFile> files) async {
    final delivery = await deliverPatientFiles(files);
    if (!mounted) return;
    final where = delivery.savedPath;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          delivery.shared
              ? 'انفتحت مشاركة الجهاز. المستلم يحتفظ بنسخته.'
              : 'تعذرت المشاركة، وانحفظ الملف${where == null ? '' : ': $where'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issuedAt = _now;
    final selection = _selection(issuedAt);
    final content = buildFollowUpCard(
      userId: widget.userId,
      snapshot: _snapshot,
      selection: selection,
    );
    final insights = buildFollowUpInsights(
      userId: widget.userId,
      snapshot: _snapshot,
      selection: selection,
      target: _target,
    );
    final nameAvailable =
        (_snapshot.profile?.displayName.trim().isNotEmpty ?? false);
    final attachments = _conditionAttachments;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const ClinicAppBar(
          title: Text('بطاقة المتابعة'),
          backgroundColor: Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
              'اختَر المرض والفترة وما تريد إظهاره. الباقي ما يدخل بالبطاقة.',
              style: TextStyle(height: 1.35),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _conditionId,
              decoration: const InputDecoration(
                labelText: 'المرض',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final condition in _snapshot.conditions)
                  DropdownMenuItem(
                    value: condition.id,
                    child: Text(condition.title),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _conditionId = value;
                  _selectedIds.clear();
                  _target = const FollowUpTarget();
                  _reminders = const [];
                });
                _loadTarget();
                _loadReminders();
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final period in FollowUpPeriod.values)
                  ChoiceChip(
                    label: Text(followUpPeriodLabel(period)),
                    selected: _period == period,
                    onSelected: (_) => setState(() => _period = period),
                  ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _measurements,
              onChanged: (value) =>
                  setState(() => _measurements = value ?? false),
              title: const Text('القراءات'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _events,
              onChanged: (value) => setState(() => _events = value ?? false),
              title: const Text('مواعيد الثلاسيميا ونقل الدم والنتائج'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _treatment,
              onChanged: (value) => setState(() => _treatment = value ?? false),
              title: const Text('العلاج الموصوف'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _reviews,
              onChanged: (value) => setState(() => _reviews = value ?? false),
              title: const Text('المراجعات'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _notes,
              onChanged: (value) => setState(() => _notes = value ?? false),
              title: const Text('الملاحظات'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _showName && nameAvailable,
              onChanged: nameAvailable
                  ? (value) => setState(() => _showName = value ?? false)
                  : null,
              title: const Text('إظهار الاسم'),
              subtitle: Text(
                nameAvailable
                    ? 'الاسم الذي حفظته في الملف'
                    : 'ما مكتوب اسم بالملف',
              ),
            ),
            CheckboxListTile(
              key: const Key('include-attachments'),
              contentPadding: EdgeInsets.zero,
              value: _includeAttachments,
              onChanged: (value) {
                setState(() {
                  _includeAttachments = value ?? false;
                  if (!_includeAttachments) _selectedIds.clear();
                });
              },
              title: const Text('تضمين الصور والمرفقات'),
              subtitle: const Text(
                'ما تنضاف لحالها. اختَر الصور اللي تريد مشاركتها.',
              ),
            ),
            if (_includeAttachments)
              if (attachments.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('ماكو صور على هذا المرض.'),
                )
              else
                for (final file in attachments)
                  CheckboxListTile(
                    key: Key('select-attachment-${file.id}'),
                    contentPadding: EdgeInsets.zero,
                    value: _selectedIds.contains(file.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(file.id);
                        } else {
                          _selectedIds.remove(file.id);
                        }
                      });
                    },
                    title: Text(file.fileName),
                    secondary: _ExportThumb(
                      store: widget.store,
                      repository: widget.repository,
                      attachment: file,
                    ),
                  ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_hasMeasurements)
                  ActionChip(
                    key: const Key('follow-up-quick-reading'),
                    avatar: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('قراءة جديدة'),
                    onPressed: _busy ? null : _quickReading,
                  ),
                if (_hasMeasurements)
                  ActionChip(
                    key: const Key('follow-up-target'),
                    avatar: Icon(
                      _target.isEmpty ? Icons.tune_rounded : Icons.check_circle,
                      size: 18,
                    ),
                    label: Text(
                      _target.isEmpty ? 'المدى من طبيبي' : 'المدى محفوظ',
                    ),
                    onPressed: _busy ? null : _editTarget,
                  ),
                if (_hasMeasurements)
                  ActionChip(
                    key: const Key('follow-up-reminders'),
                    avatar: Icon(
                      _reminders.isEmpty
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _reminders.isEmpty
                          ? 'تذكير القياس'
                          : 'تذكير: ${_reminders.first.label}'
                                '${_reminders.length > 1 ? ' +${_reminders.length - 1}' : ''}',
                    ),
                    onPressed: _busy ? null : _editReminders,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            RepaintBoundary(
              key: _boundaryKey,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE4EEEE)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: FollowUpCardView(
                    content: content,
                    insights: insights,
                    conditionKind: _condition.kind,
                  ),
                ),
              ),
            ),
            if (_selectedAttachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'الصور المختارة للمشاركة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final file in _selectedAttachments)
                    _ExportThumb(
                      store: widget.store,
                      repository: widget.repository,
                      attachment: file,
                      large: true,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _export(pdf: false),
                    child: const Text('صورة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _export(pdf: true),
                    child: const Text('PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('follow-up-send-doctor'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : _sendToDoctor,
              icon: const Icon(Icons.send_rounded),
              label: const Text('أرسلها لطبيبي'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportThumb extends StatefulWidget {
  const _ExportThumb({
    required this.store,
    required this.repository,
    required this.attachment,
    this.large = false,
  });

  final AttachmentByteStore store;
  final PatientHealthRepository repository;
  final HealthAttachment attachment;
  final bool large;

  @override
  State<_ExportThumb> createState() => _ExportThumbState();
}

class _ExportThumbState extends State<_ExportThumb> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.store.load(
        widget.repository,
        widget.attachment.id,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _failed = !looksLikeImageBytes(bytes);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.large ? 88.0 : 40.0;
    Widget child;
    if (_failed) {
      child = const Icon(Icons.broken_image_outlined, size: 18);
    } else if (_bytes == null) {
      child = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      child = Image.memory(_bytes!, fit: BoxFit.cover);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: const Color(0xFFEAF4F3),
        child: SizedBox(width: size, height: size, child: child),
      ),
    );
  }
}

class _DoctorPickerSheet extends StatefulWidget {
  const _DoctorPickerSheet({required this.load});

  final Future<List<SmartSearchResult>> Function() load;

  @override
  State<_DoctorPickerSheet> createState() => _DoctorPickerSheetState();
}

class _DoctorPickerSheetState extends State<_DoctorPickerSheet> {
  final _query = TextEditingController();
  List<FollowUpDoctorContact>? _all;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final rows = await widget.load();
      if (!mounted) return;
      setState(() => _all = followUpDoctorContacts(rows));
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim();
    final all = _all;
    final list = all == null
        ? const <FollowUpDoctorContact>[]
        : [
            for (final d in all)
              if (q.isEmpty || d.name.contains(q) || d.specialty.contains(q)) d,
          ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'اختار طبيبك من الغدير',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    key: const Key('doctor-picker-search'),
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'اسم الطبيب أو الاختصاص',
                    ),
                  ),
                ),
                Expanded(
                  child: _failed
                      ? const Center(
                          child: Text('تعذر تحميل الأطباء. جرّب بعدين.'),
                        )
                      : all == null
                      ? const Center(child: CircularProgressIndicator())
                      : list.isEmpty
                      ? const Center(child: Text('ما لكينا طبيب بهالاسم.'))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final d = list[i];
                            return ListTile(
                              key: Key('doctor-pick-$i'),
                              leading: const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              title: Text(d.name),
                              subtitle: d.specialty.isEmpty
                                  ? null
                                  : Text(d.specialty),
                              onTap: () => Navigator.pop(context, d),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
