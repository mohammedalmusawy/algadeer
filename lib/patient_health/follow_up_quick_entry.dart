import 'package:flutter/material.dart';

import 'follow_up_insights.dart';
import 'follow_up_reminders.dart';
import 'follow_up_target_store.dart';
import 'patient_health_models.dart';
import 'patient_health_repository.dart';
import 'patient_health_validation.dart';

/// إدخال سريع لقراءة جديدة من صفحة البطاقة (الوقت = الآن).
/// يرجع القراءة الجاهزة بعد التحقق، أو null عند الإلغاء.
Future<Object?> showQuickReadingDialog({
  required BuildContext context,
  required PatientCondition condition,
  required String userId,
  required DateTime now,
}) {
  return showDialog<Object>(
    context: context,
    builder: (_) =>
        _QuickReadingDialog(condition: condition, userId: userId, now: now),
  );
}

class _QuickReadingDialog extends StatefulWidget {
  const _QuickReadingDialog({
    required this.condition,
    required this.userId,
    required this.now,
  });

  final PatientCondition condition;
  final String userId;
  final DateTime now;

  @override
  State<_QuickReadingDialog> createState() => _QuickReadingDialogState();
}

class _QuickReadingDialogState extends State<_QuickReadingDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _pulse = TextEditingController();
  GlucoseUnit _unit = GlucoseUnit.mgDl;
  GlucoseTiming _timing = GlucoseTiming.fasting;
  String? _error;

  bool get _isBp => widget.condition.kind == ConditionKind.hypertension;

  @override
  void initState() {
    super.initState();
    // اقتراح وقت القياس حسب الساعة: الصبح = صائم.
    _timing = isMorningReading(widget.now)
        ? GlucoseTiming.fasting
        : GlucoseTiming.random;
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _save() {
    final c = widget.condition;
    if (_isBp) {
      final err = validateBloodPressure(
        systolic: _a.text,
        diastolic: _b.text,
        pulse: _pulse.text,
        measuredAt: widget.now,
        now: widget.now,
      );
      if (err != null) {
        setState(() => _error = err);
        return;
      }
      Navigator.pop(
        context,
        BpReading(
          id: newHealthId(),
          userId: widget.userId,
          conditionId: c.id,
          systolic: parseHealthInt(_a.text)!,
          diastolic: parseHealthInt(_b.text)!,
          pulse: _pulse.text.trim().isEmpty
              ? null
              : parseHealthInt(_pulse.text),
          measuredAt: widget.now,
        ),
      );
      return;
    }
    final err = validateGlucose(
      value: _a.text,
      unit: _unit,
      measuredAt: widget.now,
      now: widget.now,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(
      context,
      GlucoseReading(
        id: newHealthId(),
        userId: widget.userId,
        conditionId: c.id,
        value: parseHealthDouble(_a.text)!,
        unit: _unit,
        timing: _timing,
        measuredAt: widget.now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(_isBp ? 'قراءة ضغط جديدة' : 'قراءة سكر جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'الوقت: ${formatHealthStamp(widget.now)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (_isBp) ...[
                TextField(
                  key: const Key('quick-bp-systolic'),
                  controller: _a,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الانقباضي (الفوك)',
                  ),
                ),
                TextField(
                  key: const Key('quick-bp-diastolic'),
                  controller: _b,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الانبساطي (الجوه)',
                  ),
                ),
                TextField(
                  key: const Key('quick-bp-pulse'),
                  controller: _pulse,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'النبض (اختياري)',
                  ),
                ),
              ] else ...[
                TextField(
                  key: const Key('quick-glucose-value'),
                  controller: _a,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'القيمة'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final t in GlucoseTiming.values)
                      ChoiceChip(
                        label: Text(glucoseTimingLabel(t)),
                        selected: _timing == t,
                        onSelected: (_) => setState(() => _timing = t),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final u in GlucoseUnit.values)
                      ChoiceChip(
                        label: Text(glucoseUnitLabel(u)),
                        selected: _unit == u,
                        onSelected: (_) => setState(() => _unit = u),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('quick-reading-save'),
            onPressed: _save,
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

/// نافذة المدى الذي كتبه الطبيب للمريض. يرجع المدى أو null عند الإلغاء.
Future<FollowUpTarget?> showFollowUpTargetDialog({
  required BuildContext context,
  required ConditionKind kind,
  required FollowUpTarget current,
}) {
  return showDialog<FollowUpTarget>(
    context: context,
    builder: (_) => _TargetDialog(kind: kind, current: current),
  );
}

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.kind, required this.current});

  final ConditionKind kind;
  final FollowUpTarget current;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final _low = TextEditingController(text: _fmt(widget.current.low));
  late final _high = TextEditingController(text: _fmt(widget.current.high));
  late final _low2 = TextEditingController(
    text: _fmt(widget.current.secondLow),
  );
  late final _high2 = TextEditingController(
    text: _fmt(widget.current.secondHigh),
  );
  late GlucoseUnit _unit = widget.current.unit ?? GlucoseUnit.mgDl;
  String? _error;

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
  }

  bool get _isBp => widget.kind == ConditionKind.hypertension;

  @override
  void dispose() {
    _low.dispose();
    _high.dispose();
    _low2.dispose();
    _high2.dispose();
    super.dispose();
  }

  double? _p(TextEditingController c) =>
      c.text.trim().isEmpty ? null : parseHealthDouble(c.text);

  bool _invalid(TextEditingController c) =>
      c.text.trim().isNotEmpty && parseHealthDouble(c.text) == null;

  void _save() {
    if ([_low, _high, _low2, _high2].any(_invalid)) {
      setState(() => _error = 'اكتب الأرقام فقط.');
      return;
    }
    final target = FollowUpTarget(
      low: _p(_low),
      high: _p(_high),
      secondLow: _isBp ? _p(_low2) : null,
      secondHigh: _isBp ? _p(_high2) : null,
      unit: _isBp ? null : _unit,
    );
    final err = validateFollowUpTarget(target);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, target);
  }

  Widget _pair(
    String title,
    TextEditingController lo,
    TextEditingController hi,
    String keyPrefix,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: Key('$keyPrefix-low'),
                controller: lo,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'من'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: Key('$keyPrefix-high'),
                controller: hi,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'إلى'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('المدى اللي حدده طبيبك'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اكتبه مثل ما كاله طبيبك بالضبط. الغدير ما يحدد أرقام، '
                'بس يعلّم القراءات اللي تطلع برا مداك. ينحفظ على جهازك فقط.',
                style: TextStyle(height: 1.4, fontSize: 13.5),
              ),
              if (_isBp) ...[
                _pair('الانقباضي (الفوك)', _low, _high, 'target-sys'),
                _pair('الانبساطي (الجوه)', _low2, _high2, 'target-dia'),
              ] else ...[
                _pair('السكر', _low, _high, 'target-glucose'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final u in GlucoseUnit.values)
                      ChoiceChip(
                        label: Text(glucoseUnitLabel(u)),
                        selected: _unit == u,
                        onSelected: (_) => setState(() => _unit = u),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, const FollowUpTarget()),
            child: const Text('مسح المدى'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('target-save'),
            onPressed: _save,
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

/// نافذة أوقات تذكير القياس اليومي (لحد 3 أوقات). ترجع القائمة أو null.
Future<List<ReminderTime>?> showReminderTimesDialog({
  required BuildContext context,
  required List<ReminderTime> current,
}) {
  return showDialog<List<ReminderTime>>(
    context: context,
    builder: (_) => _ReminderDialog(current: current),
  );
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({required this.current});

  final List<ReminderTime> current;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late final List<ReminderTime> _times = [...widget.current]..sort();

  Future<void> _add() async {
    final suggested = _times.isEmpty
        ? const TimeOfDay(hour: 8, minute: 0)
        : const TimeOfDay(hour: 20, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: suggested,
      helpText: 'وقت التذكير',
    );
    if (picked == null || !mounted) return;
    final t = ReminderTime(picked.hour, picked.minute);
    if (_times.contains(t)) return;
    setState(
      () => _times
        ..add(t)
        ..sort(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تذكير القياس اليومي'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'يوصلك إشعار كل يوم بهالأوقات حتى تسجّل قراءتك. '
                'الإشعار ما يذكر اسم المرض، ويشتغل حتى بدون نت.',
                style: TextStyle(height: 1.4, fontSize: 13.5),
              ),
              const SizedBox(height: 10),
              if (_times.isEmpty)
                const Text(
                  'ماكو تذكير بعد.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              for (final t in _times)
                ListTile(
                  key: Key('reminder-${t.storage}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alarm_rounded),
                  title: Text(t.label),
                  trailing: IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _times.remove(t)),
                  ),
                ),
              if (_times.length < maxRemindersPerCondition)
                TextButton.icon(
                  key: const Key('reminder-add'),
                  onPressed: _add,
                  icon: const Icon(Icons.add_alarm_rounded),
                  label: const Text('إضافة وقت'),
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
            key: const Key('reminder-save'),
            onPressed: () => Navigator.pop(context, List.of(_times)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
