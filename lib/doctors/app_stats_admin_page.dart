import 'package:flutter/material.dart';

import '../home/trending_entity.dart';
import '../services/app_stats_service.dart';
import '../widgets/clinic_app_bar.dart';

/// لوحة إحصائية عامة لإدارة الغدير — مع اختيار يومي/أسبوعي/شهري/سنوي.
class AppStatsAdminPage extends StatefulWidget {
  const AppStatsAdminPage({super.key});

  @override
  State<AppStatsAdminPage> createState() => _AppStatsAdminPageState();
}

class _AppStatsAdminPageState extends State<AppStatsAdminPage> {
  final _stats = AppStatsService();
  StatsPeriod _period = StatsPeriod.day;
  bool _loading = true;
  AppPeriodStats _data = const AppPeriodStats(period: StatsPeriod.day);
  List<TrendingEntity> _topDoctors = const [];
  List<TrendingEntity> _topLabs = const [];
  List<TrendingEntity> _topPackages = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _stats.fetchPeriodStats(period: _period);
    final doctors = await _stats.fetchTopDoctors(limit: 10);
    final labs = await _stats.fetchTopLabs(limit: 10);
    final packages = await _stats.fetchTopPackages(limit: 10);
    if (!mounted) return;
    setState(() {
      _data = data;
      _topDoctors = doctors;
      _topLabs = labs;
      _topPackages = packages;
      _loading = false;
    });
  }

  Future<void> _onPeriodChanged(StatsPeriod period) async {
    setState(() => _period = period);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0FAFA3);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBFC),
        appBar: ClinicAppBar(
          title: const Text('الإحصائيات'),
          backgroundColor: teal,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'إحصائية عامة للتطبيق',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF123B42),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'اختر الفترة ثم اعرض الأرقام من داخل تطبيق الغدير فقط.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7C80),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              StatsPeriodSelector(
                value: _period,
                onChanged: _onPeriodChanged,
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(color: teal)),
                )
              else ...[
                if (_data.isLifetimeFallback)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8D9A8)),
                    ),
                    child: const Text(
                      'للفترات الزمنية نفّذ ملف supabase/app_stats_periods_schema.sql — حاليًا تُعرض إجماليات عامة.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B5A20),
                      ),
                    ),
                  ),
                _statCard(
                  icon: Icons.people_alt_rounded,
                  title: 'مستخدمو التطبيق',
                  value: '${_data.users}',
                  subtitle: 'ضمن الفترة المختارة (${_period.labelAr})',
                ),
                _statCard(
                  icon: Icons.touch_app_rounded,
                  title: 'فتحات التطبيق',
                  value: '${_data.appOpens}',
                  subtitle: 'مرات فتح التطبيق خلال الفترة',
                ),
                _statCard(
                  icon: Icons.visibility_outlined,
                  title: 'زيارات ملفات الأطباء',
                  value: '${_data.profileViews}',
                  subtitle: 'من داخل تطبيق الغدير',
                ),
                _statCard(
                  icon: Icons.phone_in_talk_rounded,
                  title: 'ضغطات الاتصال',
                  value: '${_data.callTaps}',
                  subtitle: 'عبر بطاقات الأطباء في التطبيق',
                ),
                _statCard(
                  icon: Icons.chat_rounded,
                  title: 'ضغطات واتساب',
                  value: '${_data.whatsappTaps}',
                  subtitle: 'عبر بطاقات الأطباء في التطبيق',
                ),
                _statCard(
                  icon: Icons.medical_services_outlined,
                  title: 'الأطباء في المنصة',
                  value: '${_data.doctorsCount}',
                  subtitle: 'عدد الأطباء المسجّلين (كل الفترات)',
                ),
                const SizedBox(height: 16),
                const Text(
                  'إحصائيات المختبرات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF123B42),
                  ),
                ),
                const SizedBox(height: 8),
                _statCard(
                  icon: Icons.visibility_outlined,
                  title: 'زيارات ملفات المختبرات',
                  value: '${_data.labProfileViews}',
                  subtitle: 'من داخل تطبيق الغدير',
                ),
                _statCard(
                  icon: Icons.phone_in_talk_rounded,
                  title: 'ضغطات اتصال المختبرات',
                  value: '${_data.labCallTaps}',
                  subtitle: 'عبر بطاقات المختبرات في التطبيق',
                ),
                _statCard(
                  icon: Icons.chat_rounded,
                  title: 'ضغطات واتساب المختبرات',
                  value: '${_data.labWhatsappTaps}',
                  subtitle: 'عبر بطاقات المختبرات في التطبيق',
                ),
                _statCard(
                  icon: Icons.science_rounded,
                  title: 'المختبرات في المنصة',
                  value: '${_data.labsCount}',
                  subtitle: 'عدد المختبرات المسجّلة (كل الفترات)',
                ),
                const SizedBox(height: 18),
                const Text(
                  'الأطباء الأكثر طلبًا',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF123B42),
                  ),
                ),
                const SizedBox(height: 8),
                if (_topDoctors.isEmpty)
                  const Text(
                    'لا توجد بيانات طلب كافية بعد.',
                    style: TextStyle(color: Color(0xFF78888B)),
                  )
                else
                  ...[
                    for (var i = 0; i < _topDoctors.length; i++)
                      _rankRow(
                        rank: i + 1,
                        title: _topDoctors[i].title,
                        subtitle: _topDoctors[i].subtitle,
                        meta:
                            'مشاهدات ${_topDoctors[i].profileViews} · اتصال ${_topDoctors[i].callTaps} · واتساب ${_topDoctors[i].whatsappTaps}',
                      ),
                  ],
                const SizedBox(height: 16),
                const Text(
                  'المختبرات الأكثر طلبًا',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF123B42),
                  ),
                ),
                const SizedBox(height: 8),
                if (_topLabs.isEmpty)
                  const Text(
                    'لا توجد بيانات طلب كافية بعد.',
                    style: TextStyle(color: Color(0xFF78888B)),
                  )
                else
                  ...[
                    for (var i = 0; i < _topLabs.length; i++)
                      _rankRow(
                        rank: i + 1,
                        title: _topLabs[i].title,
                        subtitle: _topLabs[i].subtitle,
                        meta:
                            'مشاهدات ${_topLabs[i].profileViews} · اتصال ${_topLabs[i].callTaps} · واتساب ${_topLabs[i].whatsappTaps}',
                      ),
                  ],
                const SizedBox(height: 16),
                const Text(
                  'الباقات الأكثر طلبًا',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF123B42),
                  ),
                ),
                const SizedBox(height: 8),
                if (_topPackages.isEmpty)
                  const Text(
                    'لا توجد بيانات طلب كافية بعد. افتح باقات من التطبيق بعد تشغيل package_stats_schema.sql.',
                    style: TextStyle(color: Color(0xFF78888B)),
                  )
                else
                  ...[
                    for (var i = 0; i < _topPackages.length; i++)
                      _rankRow(
                        rank: i + 1,
                        title: _topPackages[i].title,
                        subtitle: _topPackages[i].subtitle,
                        meta: 'مشاهدات ${_topPackages[i].profileViews}',
                      ),
                  ],
                const SizedBox(height: 8),
                const Text(
                  'ملاحظة: إحصائية كل طبيب في «إدارة الأطباء»، وكل مختبر في «المختبرات» — بنفس اختيار الفترة.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF78888B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rankRow({
    required int rank,
    required String title,
    required String subtitle,
    required String meta,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EEEE)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE11D48),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF123B42),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF5B6C70),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF0FAFA3),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEEE)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE8F7F5),
            child: Icon(icon, color: const Color(0xFF0FAFA3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF123B42),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7C80),
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0FAFA3),
            ),
          ),
        ],
      ),
    );
  }
}

/// حوار إحصائية طبيب مع اختيار الفترة.
class DoctorPeriodStatsDialog extends StatefulWidget {
  const DoctorPeriodStatsDialog({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  final String doctorId;
  final String doctorName;

  @override
  State<DoctorPeriodStatsDialog> createState() =>
      _DoctorPeriodStatsDialogState();
}

class _DoctorPeriodStatsDialogState extends State<DoctorPeriodStatsDialog> {
  final _stats = AppStatsService();
  StatsPeriod _period = StatsPeriod.day;
  bool _loading = true;
  AppPeriodStats _data = const AppPeriodStats(period: StatsPeriod.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _stats.fetchPeriodStats(
      period: _period,
      doctorId: widget.doctorId,
    );
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0FAFA3)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF123B42),
              ),
            ),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('إحصائيات — ${widget.doctorName}'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ما وصله الطبيب من تطبيق الغدير حسب الفترة:',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7C80),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              StatsPeriodSelector(
                value: _period,
                onChanged: (p) async {
                  setState(() => _period = p);
                  await _load();
                },
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_data.isLifetimeFallback)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'إجماليات عامة — نفّذ app_stats_periods_schema.sql للفترات.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9A7B20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                line(
                  Icons.visibility_outlined,
                  'زيارات الملف',
                  '${_data.profileViews}',
                ),
                line(
                  Icons.phone_in_talk_rounded,
                  'ضغطات الاتصال',
                  '${_data.callTaps}',
                ),
                line(
                  Icons.chat_rounded,
                  'ضغطات واتساب',
                  '${_data.whatsappTaps}',
                ),
                line(
                  Icons.star_rate_rounded,
                  'تقييمات الجمهور',
                  '${_data.ratingsCount}',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

/// حوار إحصائية مختبر مع اختيار الفترة.
class LabPeriodStatsDialog extends StatefulWidget {
  const LabPeriodStatsDialog({
    super.key,
    required this.labId,
    required this.labName,
  });

  final String labId;
  final String labName;

  @override
  State<LabPeriodStatsDialog> createState() => _LabPeriodStatsDialogState();
}

class _LabPeriodStatsDialogState extends State<LabPeriodStatsDialog> {
  final _stats = AppStatsService();
  StatsPeriod _period = StatsPeriod.day;
  bool _loading = true;
  AppPeriodStats _data = const AppPeriodStats(period: StatsPeriod.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _stats.fetchPeriodStats(
      period: _period,
      labId: widget.labId,
    );
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0FAFA3)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF123B42),
              ),
            ),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('إحصائيات — ${widget.labName}'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ما وصله المختبر من تطبيق الغدير حسب الفترة:',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7C80),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              StatsPeriodSelector(
                value: _period,
                onChanged: (p) async {
                  setState(() => _period = p);
                  await _load();
                },
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_data.isLifetimeFallback)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'إجماليات عامة — نفّذ lab_stats_schema.sql للفترات.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9A7B20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                line(
                  Icons.visibility_outlined,
                  'زيارات الملف',
                  '${_data.labProfileViews}',
                ),
                line(
                  Icons.phone_in_talk_rounded,
                  'ضغطات الاتصال',
                  '${_data.labCallTaps}',
                ),
                line(
                  Icons.chat_rounded,
                  'ضغطات واتساب',
                  '${_data.labWhatsappTaps}',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
