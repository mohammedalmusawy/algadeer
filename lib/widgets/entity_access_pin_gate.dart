import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home/ghadeer_home_colors.dart';
import '../services/entity_access_pin_service.dart';

/// بوابة الرقم السري — دخول برقم الكيان، أو رقم الإدارة بصمت.
/// «نسيت الرقم السري» يفتح واتساب الإدارة (بدون كشف خيار الدخول برقم الإدارة).
Future<bool> openEntityAccessPinGate(
  BuildContext context, {
  required String entityKey,
  required String entityTitle,
}) async {
  final pins = EntityAccessPinService.instance;
  if (pins.hasValidSession(entityKey)) {
    return true;
  }
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _EntityAccessPinSheet(
      entityKey: entityKey,
      entityTitle: entityTitle,
    ),
  );
  if (ok == true) {
    pins.grantSession(entityKey);
    return true;
  }
  return false;
}

/// ثلاث ضغطات سريعة على عنصر مخفي لفتح بوابة إدارة الباقات.
class StaffTripleTap extends StatefulWidget {
  const StaffTripleTap({
    super.key,
    required this.onTripleTap,
    required this.child,
  });

  final VoidCallback onTripleTap;
  final Widget child;

  @override
  State<StaffTripleTap> createState() => _StaffTripleTapState();
}

class _StaffTripleTapState extends State<StaffTripleTap> {
  int _count = 0;
  DateTime? _last;

  void _handleTap() {
    final now = DateTime.now();
    if (_last == null ||
        now.difference(_last!) > const Duration(milliseconds: 700)) {
      _count = 1;
    } else {
      _count += 1;
    }
    _last = now;
    if (_count >= 3) {
      _count = 0;
      _last = null;
      widget.onTripleTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: widget.child,
    );
  }
}

class _EntityAccessPinSheet extends StatefulWidget {
  const _EntityAccessPinSheet({
    required this.entityKey,
    required this.entityTitle,
  });

  final String entityKey;
  final String entityTitle;

  @override
  State<_EntityAccessPinSheet> createState() => _EntityAccessPinSheetState();
}

class _EntityAccessPinSheetState extends State<_EntityAccessPinSheet> {
  final _pins = EntityAccessPinService.instance;
  final _pin = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _hasEntityPin = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _pins.load();
    if (!mounted) return;
    setState(() => _loading = false);
    final hasE = await _pins.hasEntityPin(widget.entityKey);
    if (!mounted) return;
    setState(() => _hasEntityPin = hasE);
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final input = _pin.text;
      if (input.trim().isEmpty) {
        setState(() {
          _error = 'أدخل الرقم السري';
          _busy = false;
        });
        return;
      }
      // يقبل رقم الكيان أو رقم الإدارة بصمت — بدون إخبار المستخدم.
      final ok = await _pins.verifyEntityOrAdmin(widget.entityKey, input);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = _hasEntityPin
              ? 'الرقم السري غير صحيح'
              : 'لم يُعيَّن رقم سري بعد. تواصل مع الإدارة عبر «نسيت الرقم السري».';
          _busy = false;
        });
        return;
      }
      Navigator.pop(context, true);
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPinWhatsApp() async {
    final message = EntityAccessPinService.forgotPinWhatsAppMessage(
      entityTitle: widget.entityTitle,
      entityKey: widget.entityKey,
    );
    final uri = Uri.parse(
      'https://wa.me/${EntityAccessPinService.adminSupportWhatsAppDigits}'
      '?text=${Uri.encodeComponent(message)}',
    );
    final launched = await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) {
      setState(() {
        _error =
            'تعذر فتح واتساب. راسل الإدارة على ${EntityAccessPinService.adminSupportWhatsApp}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
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
                    'إدارة باقات ${widget.entityTitle}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: GhadeerHomeColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'أدخل الرقم السري للدخول',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: GhadeerHomeColors.muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pin,
                    obscureText: _obscure,
                    maxLength: EntityAccessPinService.maxPinLength,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'الرقم السري',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _busy ? null : _forgotPinWhatsApp,
                    child: const Text(
                      'نسيت الرقم السري',
                      style: TextStyle(fontWeight: FontWeight.w800),
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
                        : const Text('دخول'),
                  ),
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

/// حوار تعيين/تغيير الرقم السري من لوحة الإدارة.
Future<void> showSetEntityPinDialog(
  BuildContext context, {
  required String entityKey,
  required String title,
}) async {
  final pin = TextEditingController();
  final confirm = TextEditingController();
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'أي طول من ${EntityAccessPinService.minPinLength} '
                    'إلى ${EntityAccessPinService.maxPinLength} خانة — '
                    'أرقام أو رموز. يُحفظ على هذا الجهاز.',
                    style: const TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pin,
                    obscureText: true,
                    maxLength: EntityAccessPinService.maxPinLength,
                    decoration: const InputDecoration(
                      labelText: 'الرقم السري',
                      counterText: '',
                    ),
                  ),
                  TextField(
                    controller: confirm,
                    obscureText: true,
                    maxLength: EntityAccessPinService.maxPinLength,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد',
                      counterText: '',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xFFE74C3C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () async {
                    final format =
                        EntityAccessPinService.validatePinFormat(pin.text);
                    if (format != null) {
                      setLocal(() => error = format);
                      return;
                    }
                    if (pin.text.trim() != confirm.text.trim()) {
                      setLocal(() => error = 'التأكيد غير متطابق');
                      return;
                    }
                    await EntityAccessPinService.instance
                        .setEntityPin(entityKey, pin.text);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        ),
      );
    },
  );
  pin.dispose();
  confirm.dispose();
}

/// تعيين رقم الإدارة — للدخول الصامت عند الحاجة (لا يُعرض لصاحب الصيدلية/المختبر).
Future<void> showSetAdminAccessPinDialog(BuildContext context) async {
  await showSetEntityPinDialog(
    context,
    entityKey: EntityAccessPinService.adminKey,
    title: 'رقم إدارة الدخول الصامت',
  );
}
