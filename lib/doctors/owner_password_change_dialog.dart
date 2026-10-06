import 'package:flutter/material.dart';

import 'doctor_card_access_client.dart';

/// تغيير كلمة مرور المالك منفصل عن حفظ البطاقة.
/// الإلغاء يغلق الحوار فقط ولا يمس حقول النموذج.
Future<void> showOwnerPasswordChangeDialog({
  required BuildContext context,
  required DoctorCardSession session,
  DoctorCardAccessClient? client,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => OwnerPasswordChangeDialog(
      session: session,
      client: client ?? DoctorCardAccessClient(),
    ),
  );
}

class OwnerPasswordChangeDialog extends StatefulWidget {
  const OwnerPasswordChangeDialog({
    super.key,
    required this.session,
    required this.client,
  });

  final DoctorCardSession session;
  final DoctorCardAccessClient client;

  @override
  State<OwnerPasswordChangeDialog> createState() =>
      _OwnerPasswordChangeDialogState();
}

class _OwnerPasswordChangeDialogState extends State<OwnerPasswordChangeDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_next.text.trim() != _confirm.text.trim()) {
      _toast('التأكيد غير متطابق');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.client.changePassword(
        session: widget.session,
        oldPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور')),
      );
    } on DoctorCardAccessException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _next,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'جاري الحفظ...' : 'حفظ'),
          ),
        ],
      ),
    );
  }
}
