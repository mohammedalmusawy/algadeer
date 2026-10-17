import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'doctor_card_access_client.dart';

const ownerPermissionLabels = <String, Map<String, String>>{
  'doctor': {
    'image': 'صورة البطاقة',
    'bio': 'النبذة',
    'services': 'الخدمات الطبية',
    'schedule': 'أيام وساعات العمل',
    'contacts': 'هاتف الحجز وواتساب',
    'booking_status': 'حالة الحجز',
  },
  'lab': {
    'image': 'صورة المختبر',
    'bio': 'النبذة والشعار',
    'hours': 'ساعات العمل',
    'contacts': 'أرقام التواصل',
    'packages': 'الباقات والفحوصات والأسعار والعروض',
  },
  'pharmacy': {
    'image': 'الصورة والشعار',
    'bio': 'الشعار النصي',
    'hours': 'ساعات العمل',
    'contacts': 'أرقام التواصل',
    'products': 'المنتجات والأسعار والعروض (شامل)',
    'packages_add': 'إضافة باقات',
    'packages_edit': 'تعديل باقات',
    'packages_delete': 'حذف باقات محفوظة',
  },
  'optics': {
    'image': 'الصورة والشعار',
    'bio': 'النبذة',
    'services': 'الخدمات',
    'hours': 'الدوام',
    'contacts': 'الهاتف وواتساب',
    'location': 'العنوان والموقع',
  },
  'beauty': {
    'image': 'الصورة والشعار',
    'bio': 'النبذة',
    'services': 'الخدمات',
    'hours': 'الدوام',
    'contacts': 'الهاتف وواتساب',
    'location': 'العنوان والموقع',
  },
  'radiology': {
    'image': 'الصورة والشعار',
    'bio': 'النبذة',
    'hours': 'الدوام',
    'contacts': 'الهاتف وواتساب',
    'location': 'العنوان والموقع',
  },
  'physio': {
    'image': 'الصورة والشعار',
    'bio': 'النبذة',
    'services': 'الخدمات',
    'hours': 'الدوام',
    'contacts': 'الهاتف وواتساب',
    'location': 'العنوان',
  },
  'supply': {
    'image': 'الصورة والشعار',
    'bio': 'النبذة',
    'services': 'الأقسام والمنتجات',
    'hours': 'الدوام',
    'contacts': 'الهاتف وواتساب',
    'location': 'العنوان',
  },
  'nursing': {
    'image': 'الصورة',
    'bio': 'النبذة',
    'services': 'الخدمات',
    'hours': 'أوقات الزيارات',
    'contacts': 'الهاتف وواتساب',
    'location': 'المنطقة والعنوان',
  },
};

/// السماح للمالك بالتعديل من محرر الإدارة. الرمز يظهر مرة واحدة هنا فقط.
class EntityOwnerAdminPanel extends StatefulWidget {
  const EntityOwnerAdminPanel({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  final String entityType;
  final String entityId;

  @override
  State<EntityOwnerAdminPanel> createState() => _EntityOwnerAdminPanelState();
}

class _EntityOwnerAdminPanelState extends State<EntityOwnerAdminPanel> {
  final _client = DoctorCardAccessClient();
  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  String _mode = 'disabled';
  int? _codeExpiresAt;
  String? _code;
  int _ttlMinutes = defaultOwnerCodeTtlMinutes;
  late Set<String> _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = {};
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await _client.adminStatus(
        entityType: widget.entityType,
        entityId: widget.entityId,
      );
      if (!mounted) return;
      setState(() {
        _enabled = state.mode != 'disabled';
        _mode = state.mode;
        _permissions = state.permissions.toSet();
        _codeExpiresAt = state.codeExpiresAt;
        _loading = false;
      });
    } on DoctorCardAccessException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(error.message);
    }
  }

  Future<void> _save({bool reset = false, bool reissue = false}) async {
    setState(() => _busy = true);
    try {
      final state = await _client.adminConfigure(
        entityType: widget.entityType,
        entityId: widget.entityId,
        enabled: reset ? true : _enabled,
        permissions: _permissions.toList(),
        reset: reset,
        reissue: reissue,
        codeTtlMinutes: _ttlMinutes,
      );
      if (!mounted) return;
      setState(() {
        _enabled = state.mode != 'disabled';
        _mode = state.mode;
        _permissions = state.permissions.toSet();
        _code = state.activationCode;
        _codeExpiresAt = state.codeExpiresAt;
      });
      _toast(reset ? 'تم إصدار رمز تفعيل جديد' : 'تم حفظ صلاحيات المالك');
    } on DoctorCardAccessException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _statusLabel {
    switch (_mode) {
      case 'activate':
        return 'بانتظار التفعيل';
      case 'password':
        return 'مفعّل';
      default:
        return 'متوقف';
    }
  }

  String? get _expiryLabel {
    final seconds = _codeExpiresAt;
    if (seconds == null || seconds <= 0 || _mode != 'activate') return null;
    final when = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final local = when.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return 'ينتهي الرمز الساعة $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final labels = ownerPermissionLabels[widget.entityType] ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'دخول المالك',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'التعديل متوقف حتى تسمح به. الرمز يُسلَّم للمالك يدويًا، وهو لمرة واحدة، ومدته تختارها أنت.',
          style: TextStyle(fontSize: 12.5, height: 1.35),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('السماح بتعديل المالك'),
            value: _enabled,
            onChanged: _busy
                ? null
                : (value) => setState(() {
                      _enabled = value;
                    }),
          ),
          Text('الحالة: $_statusLabel'),
          if (_expiryLabel != null) Text(_expiryLabel!),
          const SizedBox(height: 8),
          for (final entry in labels.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              value: _permissions.contains(entry.key),
              onChanged: !_enabled || _busy
                  ? null
                  : (value) => setState(() {
                        if (value == true) {
                          _permissions.add(entry.key);
                        } else {
                          _permissions.remove(entry.key);
                        }
                      }),
            ),
          if (_code != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              _code!,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _code!));
                _toast('تم نسخ رمز التفعيل');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('نسخ الرمز'),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('مدة الرمز: '),
              const SizedBox(width: 8),
              DropdownButton<int>(
                key: const Key('owner-code-ttl'),
                value: _ttlMinutes,
                items: [
                  for (final entry in ownerCodeTtlChoices.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(
                          () => _ttlMinutes = value ?? defaultOwnerCodeTtlMinutes,
                        ),
              ),
            ],
          ),
          FilledButton(
            onPressed: _busy ? null : () => _save(),
            child: Text(_busy ? 'جاري الحفظ...' : 'حفظ صلاحيات المالك'),
          ),
          if (_mode == 'activate')
            OutlinedButton(
              onPressed: _busy ? null : () => _save(reissue: true),
              child: const Text('إصدار رمز بديل'),
            ),
          OutlinedButton(
            onPressed: _busy ? null : () => _save(reset: true),
            child: const Text('إعادة تعيين دخول المالك'),
          ),
        ],
      ],
    );
  }
}

class DoctorCardPasswordAdminSection extends StatelessWidget {
  const DoctorCardPasswordAdminSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context) {
    return EntityOwnerAdminPanel(entityType: 'doctor', entityId: doctorId);
  }
}
