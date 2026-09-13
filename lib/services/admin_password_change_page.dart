import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/clinic_app_bar.dart';

/// بريد حساب الإدارة (نفس المستخدم في دخول اللوحة).
const kAdminEmail = 'almusawyalmusawy90@gmail.com';

/// يفتح شاشة تغيير كلمة مرور الإدارة.
Future<void> openAdminPasswordChange(
  BuildContext context, {
  bool recoveryMode = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AdminPasswordChangePage(recoveryMode: recoveryMode),
    ),
  );
}

/// رابط الرجوع بعد فتح إيميل الاستعادة (يجب إضافته في Redirect URLs بـ Supabase).
String? adminPasswordResetRedirectTo() {
  if (kIsWeb) {
    // مثال محلي: http://127.0.0.1:7357/
    return Uri.base.origin.endsWith('/')
        ? Uri.base.origin
        : '${Uri.base.origin}/';
  }
  return null;
}

class AdminPasswordChangePage extends StatefulWidget {
  const AdminPasswordChangePage({super.key, this.recoveryMode = false});

  /// بعد رابط الإيميل: لا نطلب كلمة المرور الحالية.
  final bool recoveryMode;

  @override
  State<AdminPasswordChangePage> createState() =>
      _AdminPasswordChangePageState();
}

class _AdminPasswordChangePageState extends State<AdminPasswordChangePage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text.trim();
    final next = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    setState(() {
      _error = null;
      _success = null;
    });

    if ((!widget.recoveryMode && current.isEmpty) ||
        next.isEmpty ||
        confirm.isEmpty) {
      setState(() => _error = 'أكمل كل الحقول');
      return;
    }
    if (next.length < 6) {
      setState(() => _error = 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'تأكيد كلمة المرور غير متطابق');
      return;
    }
    if (!widget.recoveryMode && next == current) {
      setState(() => _error = 'اختر كلمة مرور مختلفة عن الحالية');
      return;
    }

    setState(() => _loading = true);
    try {
      if (!widget.recoveryMode) {
        await _supabase.auth.signInWithPassword(
          email: kAdminEmail,
          password: current,
        );
      }
      await _supabase.auth.updateUser(UserAttributes(password: next));

      if (!mounted) return;
      setState(() {
        _success = 'تم تغيير كلمة المرور بنجاح';
        _currentController.clear();
        _newController.clear();
        _confirmController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور')),
      );
      if (widget.recoveryMode) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      setState(() {
        _error = msg.contains('invalid') || msg.contains('credentials')
            ? 'كلمة المرور الحالية غير صحيحة'
            : 'تعذر التغيير: ${e.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'حدث خطأ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration({
    required String label,
    required bool hidden,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      prefixIcon: const Icon(Icons.lock_rounded),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0FAFA3);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: Text(
            widget.recoveryMode ? 'تعيين كلمة مرور جديدة' : 'تغيير كلمة المرور',
          ),
          backgroundColor: teal,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.password_rounded, size: 56, color: teal),
                  const SizedBox(height: 12),
                  Text(
                    widget.recoveryMode
                        ? 'اختر كلمة مرور جديدة للإدارة'
                        : 'تحديث كلمة مرور الإدارة',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.recoveryMode
                        ? 'تم التحقق من رابط الإيميل. أدخل كلمة المرور الجديدة مرتين.'
                        : 'أدخل كلمة المرور الحالية ثم الجديدة مرتين للتأكيد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  if (!widget.recoveryMode) ...[
                    TextField(
                      controller: _currentController,
                      obscureText: _hideCurrent,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        label: 'كلمة المرور الحالية',
                        hidden: _hideCurrent,
                        onToggle: () =>
                            setState(() => _hideCurrent = !_hideCurrent),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _newController,
                    obscureText: _hideNew,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      label: 'كلمة المرور الجديدة',
                      hidden: _hideNew,
                      onToggle: () => setState(() => _hideNew = !_hideNew),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmController,
                    obscureText: _hideConfirm,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: _decoration(
                      label: 'تأكيد كلمة المرور الجديدة',
                      hidden: _hideConfirm,
                      onToggle: () =>
                          setState(() => _hideConfirm = !_hideConfirm),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _success!,
                      style: const TextStyle(
                        color: Color(0xFF0FAFA3),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(backgroundColor: teal),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('حفظ كلمة المرور'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
