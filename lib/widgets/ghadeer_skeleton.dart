import 'package:flutter/material.dart';

import '../theme/ghadeer_tokens.dart';

/// هياكل التحميل (Phase 5C): بطاقات رمادية خفيفة بشكل البطاقات الحقيقية
/// تنبض بهدوء لحد ما توصل البيانات — بدل الدائرة اللي تدور.
class GhadeerSkeletonList extends StatefulWidget {
  const GhadeerSkeletonList({
    super.key,
    this.count = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  State<GhadeerSkeletonList> createState() => _GhadeerSkeletonListState();
}

class _GhadeerSkeletonListState extends State<GhadeerSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // احترام «تقليل الحركة» بإعدادات الجهاز.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جاري التحميل',
      liveRegion: true,
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 0.55,
          end: 1,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: ListView.separated(
          key: const Key('ghadeer_skeleton_list'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: widget.padding,
          itemCount: widget.count,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _SkeletonCard(seed: i),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    // أطوال مختلفة شوية حتى يبين طبيعي مو مكرر.
    final widths = [0.62, 0.48, 0.55, 0.7, 0.5];
    final w = widths[seed % widths.length];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: GhadeerTokens.card(radius: GhadeerTokens.radiusLg),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _bone,
              borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(c.maxWidth * w, 14),
                  const SizedBox(height: 10),
                  _bar(c.maxWidth * (w - 0.15), 11),
                  const SizedBox(height: 10),
                  _bar(c.maxWidth * 0.32, 18, radius: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _bone = Color(0xFFE8EFF0);

  Widget _bar(double width, double height, {double radius = 6}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: _bone,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
