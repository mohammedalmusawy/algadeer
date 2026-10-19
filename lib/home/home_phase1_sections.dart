import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../theme/ghadeer_tokens.dart';
import '../widgets/app_slot_icon.dart';
import 'ghadeer_home_colors.dart';

/// رأس الرئيسية — «الغدير»: شريط ماي فاتح حافته موجة هادئة،
/// والبحث يطفو على الموجة. هذا العنصر المميز الوحيد بالرئيسية،
/// وكل الباقي هادي وبسيط.
class HomePhase1Header extends StatelessWidget {
  const HomePhase1Header({
    super.key,
    required this.onNotifications,
    required this.onLogoTap,
    this.search,
  });

  final VoidCallback onNotifications;
  final VoidCallback onLogoTap;

  /// شريط البحث يطفو على حافة الموجة (اختياري).
  final Widget? search;

  static const double _waveHeight = 26;

  @override
  Widget build(BuildContext context) {
    final top = Container(
      color: GhadeerTokens.tealWash,
      padding: const EdgeInsets.fromLTRB(
        GhadeerTokens.gutter,
        10,
        GhadeerTokens.gutter,
        0,
      ),
      child: Row(
        children: [
          // الشعار + الاسم (ضغطات الشعار = دخول الإدارة، مثل قبل).
          Expanded(
            child: GestureDetector(
              onTap: onLogoTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: GhadeerTokens.surface,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const GhadeerBrandMark(
                      size: 40,
                      backgroundColor: null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'الغدير',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: GhadeerTokens.ink,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: GhadeerTokens.tealDeep,
                            ),
                            SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'دليلك الصحي في الشطرة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: GhadeerTokens.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'التنبيهات',
            child: Material(
              color: GhadeerTokens.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onNotifications,
                child: const SizedBox(
                  width: GhadeerTokens.touch,
                  height: GhadeerTokens.touch,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: GhadeerTokens.ink,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final searchWidget = search;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        top,
        // الموجة: البحث (إن وُجد) يطفو فوقها نصّه على الماي ونصّه على الضباب.
        if (searchWidget == null)
          const SizedBox(
            height: _waveHeight,
            width: double.infinity,
            child: CustomPaint(painter: _BrookWavePainter()),
          )
        else
          Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _waveHeight + 30,
                child: CustomPaint(painter: _BrookWavePainter()),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: searchWidget,
              ),
            ],
          ),
      ],
    );
  }
}

/// حافة الغدير: ماي فاتح ينزل بموجة ناعمة وحدة على الضباب.
class _BrookWavePainter extends CustomPainter {
  const _BrookWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.55)
      ..cubicTo(w * 0.72, h * 1.05, w * 0.52, h * 0.15, w * 0.30, h * 0.55)
      ..cubicTo(w * 0.17, h * 0.80, w * 0.07, h * 0.70, 0, h * 0.50)
      ..close();
    canvas.drawPath(path, Paint()..color = GhadeerTokens.tealWash);
  }

  @override
  bool shouldRepaint(covariant _BrookWavePainter oldDelegate) => false;
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GhadeerTokens.gutter,
        0,
        GhadeerTokens.gutter,
        GhadeerTokens.gap,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: GhadeerTokens.surface,
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
          border: Border.all(color: GhadeerTokens.line),
          boxShadow: [
            BoxShadow(
              color: GhadeerTokens.deepWater.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onSearchTap,
                  borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
                  child: const SizedBox(
                    height: GhadeerTokens.touch,
                    child: Row(
                      children: [
                        SizedBox(width: 10),
                        Icon(
                          Icons.search_rounded,
                          color: GhadeerTokens.inkFaint,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ابحث عن طبيب أو اختصاص أو خدمة ...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: GhadeerTokens.inkFaint,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: 'ابحث بالصوت',
              child: Material(
                color: GhadeerTokens.teal,
                borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
                child: InkWell(
                  borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
                  onTap: onMicTap,
                  child: const SizedBox(
                    width: GhadeerTokens.touch,
                    height: GhadeerTokens.touch,
                    child: Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
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

/// «اسأل الغدير» — البطاقة الدافئة الوحيدة بالرئيسية (رمل).
class HomePhase1AskBanner extends StatelessWidget {
  const HomePhase1AskBanner({super.key, required this.onTalk});

  final VoidCallback onTalk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GhadeerTokens.gutter,
        4,
        GhadeerTokens.gutter,
        GhadeerTokens.gap,
      ),
      child: Material(
        color: GhadeerTokens.sand,
        borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
        child: InkWell(
          onTap: onTalk,
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'اسأل الغدير',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: GhadeerTokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'كول شتحتاج، ويدورلك الطبيب أو المختبر أو الصيدلية.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: GhadeerTokens.sandInk,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: GhadeerTokens.ink,
                          borderRadius: BorderRadius.circular(
                            GhadeerTokens.radiusSm,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mic_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'اضغط وتحدث الآن',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFE3CF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    size: 32,
                    color: GhadeerTokens.sandInk,
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

/// عنوان قسم بالرئيسية.
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GhadeerTokens.gutter,
        12,
        GhadeerTokens.gutter,
        10,
      ),
      child: Text(text, style: GhadeerTokens.title),
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
  const HomePhase1ServicesGrid({super.key, required this.onOpen});

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
      id: 'optics',
      title: 'العوينات وفحص البصر',
      subtitle: 'مراكز البصريات',
      icon: Icons.visibility_outlined,
      background: GhadeerHomeColors.opticsBg,
      accent: GhadeerHomeColors.opticsAccent,
    ),
    HomeServiceCardData(
      id: 'beauty',
      title: 'مراكز التجميل',
      subtitle: 'مراكز العناية',
      icon: Icons.spa_outlined,
      background: GhadeerHomeColors.beautyBg,
      accent: GhadeerHomeColors.beautyAccent,
    ),
    HomeServiceCardData(
      id: 'pharmacy',
      title: 'الصيدليات',
      subtitle: 'استفسار • اتصال • مراسلة',
      icon: Icons.medication_liquid_outlined,
      background: GhadeerHomeColors.pharmacyBg,
      accent: GhadeerHomeColors.pharmacyAccent,
    ),
    HomeServiceCardData(
      id: 'nursing',
      title: 'التمريض المنزلي',
      subtitle: 'ممرض أو ممرضة يزورك بالبيت',
      icon: Icons.volunteer_activism_outlined,
      background: GhadeerHomeColors.nursingBg,
      accent: GhadeerHomeColors.nursingAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GhadeerTokens.gutter,
        0,
        GhadeerTokens.gutter,
        8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // ٣ أعمدة بالموبايل، ٤ بالشاشات الأعرض. مربعات بنفس الارتفاع.
          // الارتفاع على قد النص (سطرين، أو ثلاثة بالشاشات الضيقة) ويكبر
          // ويا حجم الخط من إعدادات الهاتف — بلا فراغ ميت تحت الاسم.
          const gap = 10.0;
          final cols = constraints.maxWidth >= 560 ? 4 : 3;
          final tileW = (constraints.maxWidth - gap * (cols - 1)) / cols;
          final lines = tileW < 100 ? 3 : 2;
          final textH =
              MediaQuery.textScalerOf(context).scale(13) * 1.3 * lines;
          final tileH = 12 + 52 + 8 + textH + 12;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: tileW,
                  height: tileH,
                  child: _ServiceCard(
                    data: item,
                    maxLines: lines,
                    onTap: () => onOpen(item.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  const _ServiceCard({
    required this.data,
    required this.onTap,
    this.maxLines = 3,
  });

  final HomeServiceCardData data;
  final VoidCallback onTap;

  /// نفس عدد الأسطر اللي انحسب عليه ارتفاع المربع — الزايد يطلع «…».
  final int maxLines;

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      child: Semantics(
        button: true,
        label: d.title,
        excludeSemantics: true,
        child: Material(
          color: GhadeerTokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
            side: const BorderSide(color: GhadeerTokens.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
              // من فوق (مو بالنص) حتى الأيقونات تبقى على خط واحد بكل صف.
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: d.background,
                      borderRadius: BorderRadius.circular(
                        GhadeerTokens.radiusMd,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: AppSlotIcon(
                      slotId: 'home.${d.id}',
                      fallback: d.icon,
                      size: 28,
                      color: d.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      d.title,
                      maxLines: widget.maxLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GhadeerTokens.ink,
                        height: 1.3,
                      ),
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

/// رسالة اليوم — هادئة بدون سهم (مو زر).
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

    Widget bar(double w, double h, Color c) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GhadeerTokens.gutter,
        8,
        GhadeerTokens.gutter,
        4,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: GhadeerTokens.card(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: GhadeerTokens.tealWash,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: GhadeerTokens.tealDeep,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: loading
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(140, 14, const Color(0xFFE6EEEF)),
                        const SizedBox(height: 8),
                        bar(200, 12, const Color(0xFFEEF3F4)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tipTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GhadeerTokens.heading,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tipBody,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GhadeerTokens.body.copyWith(
                            fontSize: 13.5,
                            color: GhadeerTokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
