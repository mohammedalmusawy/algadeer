import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import '../models/doctor_item.dart';
import 'doctor_card_access_client.dart';
import 'doctor_card_editor_page.dart';

/// النقرات تفتح هذه النافذة فقط. التحقق يتم في Edge Function.
Future<DoctorCardEditResult?> openDoctorCardAccess(
  BuildContext context,
  DoctorItem doctor,
) async {
  if (doctor.id.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('هذه البطاقة غير مرتبطة بسجل.')),
    );
    return null;
  }
  final session = await showEntityOwnerSession(
    context,
    entityType: 'doctor',
    entityId: doctor.id,
    title: doctor.name,
  );
  if (session == null || !context.mounted) return null;
  return Navigator.of(context).push<DoctorCardEditResult>(
    MaterialPageRoute(
      builder: (_) => DoctorCardEditorPage(doctor: doctor, session: session),
    ),
  );
}

Future<DoctorCardSession?> showEntityOwnerSession(
  BuildContext context, {
  required String entityType,
  required String entityId,
  required String title,
}) {
  return showModalBottomSheet<DoctorCardSession>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _OwnerAccessSheet(
      entityType: entityType,
      entityId: entityId,
      title: title,
    ),
  );
}

class _OwnerAccessSheet extends StatefulWidget {
  const _OwnerAccessSheet({
    required this.entityType,
    required this.entityId,
    required this.title,
  });

  final String entityType;
  final String entityId;
  final String title;

  @override
  State<_OwnerAccessSheet> createState() => _OwnerAccessSheetState();
}

class _OwnerAccessSheetState extends State<_OwnerAccessSheet> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _client = DoctorCardAccessClient();
  bool _busy = false;
  bool _obscure = true;
  bool _loading = true;
  String _mode = 'disabled';
  String? _activationToken;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final preview = await _client.preview(
        entityType: widget.entityType,
        entityId: widget.entityId,
      );
      if (!mounted) return;
      setState(() {
        _mode = preview.mode;
        _loading = false;
        if (preview.waitSeconds > 0) _error = preview.message;
      });
    } on DoctorCardAccessException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (_mode == 'activate' && _activationToken == null) {
        final token = await _client.verifyCode(
          entityType: widget.entityType,
          entityId: widget.entityId,
          code: _code.text,
        );
        if (!mounted) return;
        setState(() {
          _activationToken = token;
          _busy = false;
        });
        return;
      }
      final DoctorCardSession session;
      if (_mode == 'activate') {
        if (_password.text.trim() != _confirm.text.trim()) {
          setState(() {
            _error = 'التأكيد غير متطابق';
            _busy = false;
          });
          return;
        }
        session = await _client.completeActivation(
          entityType: widget.entityType,
          entityId: widget.entityId,
          activationToken: _activationToken!,
          newPassword: _password.text,
        );
      } else {
        session = await _client.login(
          doctorId: widget.entityId,
          password: _password.text,
          entityType: widget.entityType,
        );
      }
      if (!mounted) return;
      _busy = false;
      Navigator.pop(context, session);
    } on DoctorCardAccessException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.title.trim().isEmpty ? 'البطاقة' : widget.title.trim();
    final activating = _mode == 'activate' && _activationToken != null;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7E4E4),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'تعديل بطاقة $title',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: GhadeerHomeColors.secondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _loading
                  ? 'جاري التحقق...'
                  : _mode == 'disabled'
                      ? 'تعديل المالك غير مفعّل لهذه البطاقة.'
                      : activating
                          ? 'اختر كلمة مرور لهذه البطاقة'
                          : _mode == 'activate'
                              ? 'أدخل رمز التفعيل الذي سلّمتك إياه الإدارة'
                              : 'أدخل كلمة المرور الخاصة بهذه البطاقة',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: GhadeerHomeColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_mode != 'disabled') ...[
              if (_mode == 'activate' && !activating)
                TextField(
                  controller: _code,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'رمز التفعيل',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _busy ? null : _submit(),
                )
              else ...[
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: activating ? 'كلمة المرور الجديدة' : 'كلمة المرور',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                if (activating) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              if (!activating)
                const Text(
                  'إذا نسيت كلمة المرور، راجع الإدارة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GhadeerHomeColors.muted,
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: GhadeerHomeColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(activating ? 'حفظ كلمة المرور' : 'متابعة'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE74C3C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
