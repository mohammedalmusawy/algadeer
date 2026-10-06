import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../widgets/clinic_app_bar.dart';
import 'attachment_view.dart';
import 'card_export.dart';
import 'follow_up_card.dart';
import 'patient_health_models.dart';
import 'patient_health_repository.dart';

class FollowUpCardPage extends StatefulWidget {
  const FollowUpCardPage({
    super.key,
    required this.userId,
    required this.snapshot,
    required this.repository,
    required this.store,
    this.now,
  });

  final String userId;
  final PatientHealthSnapshot snapshot;
  final PatientHealthRepository repository;
  final AttachmentByteStore store;
  final DateTime Function()? now;

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

  @override
  void initState() {
    super.initState();
    _conditionId = widget.snapshot.conditions.first.id;
  }

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  List<HealthAttachment> get _conditionAttachments {
    return [
      for (final file in widget.snapshot.attachments)
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

  FollowUpCardContent get _content {
    return buildFollowUpCard(
      userId: widget.userId,
      snapshot: widget.snapshot,
      selection: FollowUpSelection(
        conditionId: _conditionId,
        period: _period,
        issuedAt: _now,
        includeMeasurements: _measurements,
        includeTreatment: _treatment,
        includeReviews: _reviews,
        includeNotes: _notes,
        includeEvents: _events,
        showName: _showName,
      ),
    );
  }

  Future<List<AttachmentExportReady>> _readyImages() {
    return loadAttachmentsForExport(
      selected: _selectedAttachments,
      load: (id) => widget.store.load(widget.repository, id),
    );
  }

  Future<void> _export({required bool pdf}) async {
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
    if (agreed != true || !mounted) return;
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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
              filename: safeExportFileName(images[i].attachment.fileName, i + 1),
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
    final content = _content;
    final nameAvailable =
        (widget.snapshot.profile?.displayName.trim().isNotEmpty ?? false);
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
                for (final condition in widget.snapshot.conditions)
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
                });
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
              onChanged: (value) => setState(() => _measurements = value ?? false),
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
                nameAvailable ? 'الاسم الذي حفظته في الملف' : 'ما مكتوب اسم بالملف',
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
            const SizedBox(height: 8),
            RepaintBoundary(
              key: _boundaryKey,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE4EEEE)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FollowUpCardView(content: content),
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
