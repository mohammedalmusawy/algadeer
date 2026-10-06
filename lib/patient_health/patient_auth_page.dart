import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/clinic_app_bar.dart';
import 'patient_auth.dart';

class PatientAuthPage extends StatefulWidget {
  const PatientAuthPage({
    super.key,
    required this.auth,
    required this.onSignedIn,
    this.adminSessionActive = false,
  });

  final PatientAuthApi auth;
  final VoidCallback onSignedIn;
  final bool adminSessionActive;

  @override
  State<PatientAuthPage> createState() => _PatientAuthPageState();
}

class _PatientAuthPageState extends State<PatientAuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int _mode = 0;
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    PatientAuthResult result;
    if (_mode == 2) {
      result = await widget.auth.requestPasswordReset(email: _email.text);
    } else if (_mode == 1) {
      if (_password.text != _confirm.text) {
        setState(() {
          _busy = false;
          _notice = 'كلمتا المرور غير متطابقتين.';
        });
        return;
      }
      result = await widget.auth.signUp(
        email: _email.text,
        password: _password.text,
      );
    } else {
      result = await widget.auth.signIn(
        email: _email.text,
        password: _password.text,
      );
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = result.message;
    });
    if (result.status == PatientAuthStatus.signedIn) {
      widget.onSignedIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0FAFA3);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const ClinicAppBar(
          title: Text('ملفي الصحي'),
          backgroundColor: teal,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'تصفح الأطباء والمختبرات والأشعة والصيدليات يبقى مفتوحاً. '
              'تسجيل الدخول مطلوب فقط للملف الصحي.',
              style: TextStyle(height: 1.4),
            ),
            if (widget.adminSessionActive) ...[
              const SizedBox(height: 12),
              const Text(
                'جلسة الإدارة مفتوحة حالياً. الملف الصحي ما يستخدم حساب الإدارة. '
                'اخرج من الإدارة إذا تريد تدخل بحساب مريض.',
                style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('دخول')),
                ButtonSegment(value: 1, label: Text('حساب جديد')),
                ButtonSegment(value: 2, label: Text('استعادة')),
              ],
              selected: {_mode},
              onSelectionChanged: (value) => setState(() {
                _mode = value.first;
                _notice = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                border: OutlineInputBorder(),
              ),
            ),
            if (_mode != 2) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_mode == 1) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'إنشاء الحساب ما يحفظ بيانات صحية قبل موافقتك داخل الملف.',
                style: TextStyle(height: 1.35),
              ),
            ],
            if (_mode == 2)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'الاستعادة ترسل رابطاً عبر Supabase. إذا ما وصل البريد، '
                  'السبب يكون إعداد SMTP أو Redirect URLs، مو نجاح وهمي من التطبيق.',
                  style: TextStyle(height: 1.35),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: teal,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(_busy ? 'جاري الطلب...' : _actionLabel),
            ),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              Text(_notice!, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }

  String get _actionLabel {
    switch (_mode) {
      case 1:
        return 'إنشاء الحساب';
      case 2:
        return 'إرسال رابط الاستعادة';
      default:
        return 'دخول';
    }
  }
}

class PatientPasswordUpdatePage extends StatefulWidget {
  const PatientPasswordUpdatePage({super.key, this.auth});

  final PatientAuthApi? auth;

  @override
  State<PatientPasswordUpdatePage> createState() =>
      _PatientPasswordUpdatePageState();
}

class _PatientPasswordUpdatePageState extends State<PatientPasswordUpdatePage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _notice;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text != _confirm.text) {
      setState(() => _notice = 'كلمتا المرور غير متطابقتين.');
      return;
    }
    final auth = widget.auth ??
        SupabasePatientAuthApi(Supabase.instance.client);
    setState(() {
      _busy = true;
      _notice = null;
    });
    final result = await auth.updatePassword(password: _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = result.message;
      _done = result.status == PatientAuthStatus.signedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const ClinicAppBar(
          title: Text('كلمة مرور جديدة'),
          backgroundColor: Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'هذي الصفحة لحساب المريض بعد فتح رابط الاستعادة. '
              'ما تغيّر كلمة مرور الإدارة.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _done ? null : _save,
              child: Text(_busy ? 'جاري الحفظ...' : 'حفظ كلمة المرور'),
            ),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              Text(_notice!, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}
