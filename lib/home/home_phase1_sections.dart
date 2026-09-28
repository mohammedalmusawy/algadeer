import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../widgets/app_slot_icon.dart';
import 'ghadeer_home_colors.dart';

/// أقسام الرئيسية — مواضع بصرية مطابقة للموكاب (يسار/يمين الشاشة).
/// نستخدم LTR للصفوف التي تعتمد على موضع الشاشة، والنص العربي يبقى RTL.
class HomePhase1Header extends StatelessWidget {
  const HomePhase1Header({
    super.key,
    required this.onNotifications,
    required this.onLogoTap,
  });

  final VoidCallback onNotifications;
  final VoidCallback onLogoTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      // الموكاب: تنبيهات يسار · شعار+نص وسط · موقع يمين
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // يسار الشاشة
            InkWell(
              onTap: onNotifications,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: GhadeerHomeColors.secondary,
                      size: 24,
                    ),
                    SizedBox(height: 1),
                    Text(
                      'التنبيهات',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: GhadeerHomeColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // الوسط: شعار ثم «الغدير» يمين الشعار (مثل الصورة)
            Expanded(
              child: GestureDetector(
                onTap: onLogoTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // بدون ColorFiltered — كان يضيف صبغة تركواز حول الشعار.
                    const GhadeerBrandMark(
                      size: 52,
                      backgroundColor: null,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الغدير',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: GhadeerHomeColors.secondary,
                              height: 1.05,
                            ),
                          ),
                          Text(
                            'دليلك الصحي في الشطرة',
                            textDirection: TextDirection.rtl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: GhadeerHomeColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // يمين الشاشة: الموقع (أيقونة يمين النص)
            const SizedBox(
              width: 120,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: GhadeerHomeColors.primary,
                    ),
                    SizedBox(width: 3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الشطرة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: GhadeerHomeColors.secondary,
                            ),
                          ),
                          Text(
                            'شارع الأطباء',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: GhadeerHomeColors.secondary,
                            ),
                          ),
                          Text(
                            'قرب صيدلية رحاب',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: GhadeerHomeColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePhase1SearchRow extends StatelessWidget {
  const HomePhase1SearchRow({
    super.key,
    required this.onSearchTap,
    required this.onMicTap,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    // الموكاب: شريط البحث يسار · المايك يمين الشاشة
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: onSearchTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE4EEEE)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    // أيقونة البحث يسار الحقل (مثل الصورة)
                    child: const Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: Color(0xFF8A9A9E),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ابحث عن طبيب أو اختصاص أو خدمة ...',
                            textDirection: TextDirection.rtl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF8A9A9E),
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: GhadeerHomeColors.primary,
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: GhadeerHomeColors.primary.withValues(alpha: 0.35),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onMicTap,
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePhase1AskBanner extends StatelessWidget {
  const HomePhase1AskBanner({super.key, required this.onTalk});

  final VoidCallback onTalk;

  @override
  Widget build(BuildContext context) {
    // الموكاب: عنوان+زر يسار · نقاط صح يمين · زخرفة يمين (تحت المايك)
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: const Color(0xFFE8F6FB),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTalk,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'اسأل الغدير',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: GhadeerHomeColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'مساعدك الذكي دائماً معك',
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: GhadeerHomeColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: GhadeerHomeColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.mic_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'اضغط وتحدث الآن',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _AskCheckLine('أطباء موثوقون'),
                      _AskCheckLine('معلومات دقيقة'),
                      _AskCheckLine('خدمة أسرع'),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.monitor_heart_outlined,
                    size: 40,
                    color: GhadeerHomeColors.primary.withValues(alpha: 0.28),
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

class _AskCheckLine extends StatelessWidget {
  const _AskCheckLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    // صح ثم النص من اليمين لليسار بصرياً بجانب الزخرفة
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: GhadeerHomeColors.secondary,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: Color(0xFF2ECC71),
          ),
        ],
      ),
    );
  }
}

class HomeServiceCardData {
  const HomeServiceCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.accent,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color accent;
}

class HomePhase1ServicesGrid extends StatelessWidget {
  const HomePhase1ServicesGrid({
    super.key,
    required this.onOpen,
  });

  final void Function(String id) onOpen;

  /// ترتيب الموكاب يسار→يمين، فوق→تحت (مع Directionality.ltr للشبكة).
  static const items = <HomeServiceCardData>[
    HomeServiceCardData(
      id: 'doctors',
      title: 'الأطباء',
      subtitle: 'جميع الاختصاصات',
      icon: Icons.medical_services_outlined,
      background: GhadeerHomeColors.doctorsBg,
      accent: GhadeerHomeColors.doctorsAccent,
    ),
    HomeServiceCardData(
      id: 'radiology',
      title: 'الأشعة',
      subtitle: 'سونار • رنين • X-Ray',
      icon: Icons.radar_outlined,
      background: GhadeerHomeColors.radiologyBg,
      accent: GhadeerHomeColors.radiologyAccent,
    ),
    HomeServiceCardData(
      id: 'labs',
      title: 'المختبرات',
      subtitle: 'تحاليل دقيقة وموثوقة',
      icon: Icons.biotech_outlined,
      background: GhadeerHomeColors.labsBg,
      accent: GhadeerHomeColors.labsAccent,
    ),
    HomeServiceCardData(
      id: 'physio',
      title: 'العلاج الطبيعي والتأهيل الطبي',
      subtitle: 'حركة أفضل لحياة أفضل',
      icon: Icons.accessibility_new_rounded,
      background: GhadeerHomeColors.physioBg,
      accent: GhadeerHomeColors.physioAccent,
    ),
    HomeServiceCardData(
      id: 'supplies',
      title: 'المستلزمات والتجهيزات الطبية',
      subtitle: 'مستلزمات طبية معتمدة',
      icon: Icons.wheelchair_pickup_rounded,
      background: GhadeerHomeColors.suppliesBg,
      accent: GhadeerHomeColors.suppliesAccent,
    ),
    HomeServiceCardData(
      id: 'pharmacy',
      title: 'الصيدليات',
      subtitle: 'استفسار • اتصال • مراسلة',
      icon: Icons.medication_liquid_outlined,
      background: GhadeerHomeColors.pharmacyBg,
      accent: GhadeerHomeColors.pharmacyAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final cardW = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final item in items)
                  SizedBox(
                    width: cardW,
                    child: _ServiceCard(
                      data: item,
                      onTap: () => onOpen(item.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  const _ServiceCard({required this.data, required this.onTap});

  final HomeServiceCardData data;
  final VoidCallback onTap;

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: d.background,
        borderRadius: BorderRadius.circular(20),
        elevation: _pressed ? 1 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(20),
          // المحتوى العربي داخل البطاقة يبقى RTL للقراءة،
          // بينما صف الأيقونة/السهم LTR ليطابق الموكاب: أيقونة يسار · سهم يمين.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: AppSlotIcon(
                        slotId: 'home.${d.id}',
                        fallback: d.icon,
                        size: 28,
                        color: d.accent,
                      ),
                      ),
                      const Spacer(),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: d.accent.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: d.accent,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: GhadeerHomeColors.secondary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: GhadeerHomeColors.muted.withValues(alpha: 0.95),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePhase1HealthTip extends StatelessWidget {
  const HomePhase1HealthTip({
    super.key,
    this.title,
    this.body,
    this.loading = false,
  });

  final String? title;
  final String? body;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tipTitle = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : 'معاً من أجل صحتك';
    final tipBody = (body != null && body!.trim().isNotEmpty)
        ? body!.trim()
        : 'معلومات .. توجيه .. رعاية أفضل';

    // الموكاب: صورة/أيقونة يسار · النص يمين · سهم يمين
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: GhadeerHomeColors.skyBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD6EAF5)),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: GhadeerHomeColors.primary,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: loading
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            height: 14,
                            width: 140,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD6EAF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F2F8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            tipTitle,
                            textDirection: TextDirection.rtl,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: GhadeerHomeColors.secondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tipBody,
                            textDirection: TextDirection.rtl,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: GhadeerHomeColors.muted,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: GhadeerHomeColors.primary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
