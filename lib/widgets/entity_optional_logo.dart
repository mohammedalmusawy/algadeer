import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// شعار اختياري بجانب صورة المقدّم. بلا عنوان لا يأخذ مساحة ولا شعارًا افتراضيًا.
class EntityOptionalLogo extends StatelessWidget {
  const EntityOptionalLogo({
    super.key,
    required this.url,
    this.maxWidth = 72,
    this.maxHeight = 56,
  });

  final String url;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final source = url.trim();
    if (source.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        key: const Key('entity_optional_logo'),
        width: maxWidth,
        height: maxHeight,
        child: _LogoImage(source: source),
      ),
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.contain,
        errorBuilder: _logoError,
      );
    }
    if (source.startsWith('data:image')) {
      final comma = source.indexOf(',');
      if (comma < 0) return const SizedBox.shrink();
      try {
        return Image.memory(
          base64Decode(source.substring(comma + 1)),
          fit: BoxFit.contain,
          errorBuilder: _logoError,
        );
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    return Image.network(
      source,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: _logoError,
    );
  }
}

/// رفع الشعار ومعاينته واستبداله وحذفه، منفصل عن الصورة الأساسية.
class EntityLogoAdminField extends StatefulWidget {
  const EntityLogoAdminField({
    super.key,
    required this.logoUrl,
    required this.folder,
    required this.entityId,
    required this.onChanged,
    this.upload,
  });

  final String logoUrl;

  /// مجلد التخزين الجذر: doctors | labs | radiology | pharmacies |
  /// service-centers | physio | supplies
  final String folder;
  final String entityId;
  final ValueChanged<String> onChanged;

  /// إن وُجد، الرفع يمر منه (صاحب البطاقة عبر Edge Function).
  /// وإلا فالرفع المباشر للإدارة بنفس مسار التخزين الموحّد.
  final Future<String> Function(Uint8List bytes, bool png)? upload;

  @override
  State<EntityLogoAdminField> createState() => _EntityLogoAdminFieldState();
}

class _EntityLogoAdminFieldState extends State<EntityLogoAdminField> {
  Uint8List? _preview;
  bool _busy = false;

  Future<void> _pick() async {
    final id = widget.entityId.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('احفظ السجل أولًا ثم ارفع الشعار.')),
      );
      return;
    }
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final png = isEntityLogoPng(bytes);
    if (!mounted) return;
    setState(() {
      _preview = bytes;
      _busy = true;
    });
    try {
      final url = widget.upload != null
          ? await widget.upload!(bytes, png)
          : await uploadEntityLogo(
              folder: widget.folder,
              entityId: id,
              bytes: bytes,
              png: png,
            );
      if (!mounted) return;
      setState(() => _preview = null);
      widget.onChanged(url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _preview = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفع الشعار.\n$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.logoUrl.trim();
    final hasLogo = _preview != null || url.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasLogo)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 72,
              height: 56,
              child: _preview != null
                  ? Image.memory(_preview!, fit: BoxFit.contain)
                  : _LogoImage(source: url),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(hasLogo ? 'استبدال الشعار' : 'رفع الشعار'),
            ),
            if (hasLogo)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _preview = null);
                        widget.onChanged('');
                      },
                icon: const Icon(Icons.delete_outline),
                label: const Text('حذف الشعار'),
              ),
          ],
        ),
      ],
    );
  }
}

Widget _logoError(BuildContext context, Object error, StackTrace? stackTrace) {
  return const SizedBox.shrink();
}

bool isEntityLogoPng(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

/// مسار موحّد للإدارة والمالك: `{folder}/{entityId}/logos/{fileId}.{ext}`
String entityLogoObjectPath({
  required String folder,
  required String entityId,
  required bool png,
  String? fileId,
}) {
  final safeFolder = folder.replaceAll(RegExp(r'[^a-z0-9_-]'), '');
  final safeId = entityId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  if (safeFolder.isEmpty || safeId.isEmpty) {
    throw ArgumentError('folder and entityId are required for logo path');
  }
  final name = (fileId == null || fileId.isEmpty)
      ? DateTime.now().microsecondsSinceEpoch.toString()
      : fileId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  return '$safeFolder/$safeId/logos/$name.${png ? 'png' : 'jpg'}';
}

/// يرفع الشعار إلى المسار الموحّد. لا يستبدل ملف الصورة الأساسية.
Future<String> uploadEntityLogo({
  required String folder,
  required String entityId,
  required Uint8List bytes,
  required bool png,
}) async {
  final path = entityLogoObjectPath(
    folder: folder,
    entityId: entityId,
    png: png,
  );
  final client = Supabase.instance.client;
  await client.storage.from('clinic-media').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: false,
          contentType: png ? 'image/png' : 'image/jpeg',
        ),
      );
  return client.storage.from('clinic-media').getPublicUrl(path);
}
