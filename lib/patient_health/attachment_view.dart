import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'patient_health_models.dart';
import 'patient_health_repository.dart';

String attachmentMimeType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

bool looksLikeImageBytes(Uint8List bytes) {
  if (bytes.length < 12) return false;
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E) return true;
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  return false;
}

class AttachmentByteStore {
  final _bytes = <String, Uint8List>{};

  Uint8List? peek(String id) => _bytes[id];

  void put(String id, Uint8List bytes) {
    _bytes[id] = bytes;
  }

  void remove(String id) {
    _bytes.remove(id);
  }

  Future<Uint8List> load(
    PatientHealthRepository repository,
    String id,
  ) async {
    final cached = _bytes[id];
    if (cached != null) return cached;
    final loaded = await repository.readAttachment(id);
    _bytes[id] = loaded;
    return loaded;
  }
}

class PatientAttachmentTile extends StatefulWidget {
  const PatientAttachmentTile({
    super.key,
    required this.attachment,
    required this.repository,
    required this.store,
    required this.onDelete,
  });

  final HealthAttachment attachment;
  final PatientHealthRepository repository;
  final AttachmentByteStore store;
  final VoidCallback onDelete;

  @override
  State<PatientAttachmentTile> createState() => _PatientAttachmentTileState();
}

class _PatientAttachmentTileState extends State<PatientAttachmentTile> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

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
      final bytes = await widget.store.load(
        widget.repository,
        widget.attachment.id,
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
        _error = looksLikeImageBytes(bytes) ? null : 'هالمرفق مو صورة واضحة.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الصورة. جرّب مرة ثانية.';
      });
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientAttachmentViewer(
          title: widget.attachment.fileName,
          load: () => widget.store.load(
            widget.repository,
            widget.attachment.id,
          ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('attachment-tile-${widget.attachment.id}'),
      contentPadding: EdgeInsets.zero,
      onTap: _open,
      leading: _Thumb(
        loading: _loading,
        bytes: _bytes,
        failed: _error != null,
      ),
      title: Text(widget.attachment.fileName),
      subtitle: Text(_error ?? 'مرفق خاص بحسابك · اضغط لفتح الصورة'),
      trailing: IconButton(
        tooltip: 'حذف المرفق',
        onPressed: widget.onDelete,
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.loading,
    required this.bytes,
    required this.failed,
  });

  final bool loading;
  final Uint8List? bytes;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (loading) {
      child = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (failed || bytes == null || !looksLikeImageBytes(bytes!)) {
      child = const Icon(Icons.broken_image_outlined);
    } else {
      child = Image.memory(bytes!, fit: BoxFit.cover);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: const Color(0xFFEAF4F3),
        child: SizedBox(width: 56, height: 56, child: Center(child: child)),
      ),
    );
  }
}

class PatientAttachmentViewer extends StatefulWidget {
  const PatientAttachmentViewer({
    super.key,
    required this.title,
    required this.load,
  });

  final String title;
  final Future<Uint8List> Function() load;

  @override
  State<PatientAttachmentViewer> createState() => _PatientAttachmentViewerState();
}

class _PatientAttachmentViewerState extends State<PatientAttachmentViewer> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await widget.load();
      if (!mounted) return;
      if (!looksLikeImageBytes(bytes)) {
        setState(() {
          _loading = false;
          _error = 'تعذر عرض هالملف كصورة.';
        });
        return;
      }
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر فتح الصورة. تأكد أنك داخل حسابك وجرّب مرة ثانية.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
        ),
        body: Center(
          child: _loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'جاري فتح الصورة...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                )
              : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _open,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Image.memory(_bytes!, fit: BoxFit.contain),
                ),
        ),
      ),
    );
  }
}
