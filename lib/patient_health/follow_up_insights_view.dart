import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import 'follow_up_insights.dart';

/// الملخص والرسم وحقائق الثلاسيميا داخل البطاقة (فتظهر بالصورة وPDF).
class FollowUpInsightsView extends StatelessWidget {
  const FollowUpInsightsView({super.key, required this.insights});

  final FollowUpInsights insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (insights.facts.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final fact in insights.facts) _FactTile(fact: fact),
            ],
          ),
          const SizedBox(height: 12),
        ],
        for (final group in insights.summaries) ...[
          _SummaryTable(group: group),
          const SizedBox(height: 12),
        ],
        if (insights.outOfTargetCount > 0) ...[
          Container(
            key: const Key('follow-up-out-of-target'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD199)),
            ),
            child: Text(
              '${insights.outOfTargetCount} قراءة خارج المدى اللي كتبته من طبيبك '
              '(معلّمة بنقطة برتقالية بالرسم).',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF8A4B00),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final chart in insights.charts) ...[
          _ChartBlock(chart: chart),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact});

  final FollowUpFact fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fact.label,
            style: const TextStyle(
              color: Color(0xFF0C7F76),
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            fact.value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.group});

  final FollowUpSummaryGroup group;

  static const _head = TextStyle(fontWeight: FontWeight.w900, fontSize: 12);
  static const _cell = TextStyle(fontWeight: FontWeight.w700, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(
              Icons.insights_rounded,
              size: 18,
              color: GhadeerHomeColors.secondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${group.title} (${group.unit})',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Table(
          border: TableBorder.all(color: const Color(0xFFD5E0E3), width: 1),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(0.6),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
            4: FlexColumnWidth(1),
            5: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF2F7F8)),
              children: [
                for (final h in const [
                  '',
                  'العدد',
                  'المعدّل',
                  'الأقل',
                  'الأعلى',
                  'الأخيرة',
                ])
                  _c(h, _head),
              ],
            ),
            for (final row in group.rows)
              TableRow(
                children: [
                  _c(row.label, _head),
                  _c('${row.count}', _cell),
                  _c(row.average, _cell),
                  _c(row.lowest, _cell),
                  _c(row.highest, _cell),
                  _c(row.latest, _cell),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _c(String text, TextStyle style) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
    child: Text(text, textAlign: TextAlign.center, style: style),
  );
}

const _primaryLine = Color(0xFF0FAFA3);
const _secondaryLine = Color(0xFF3D6CB3);
const _outColor = Color(0xFFFF8A00);

class _ChartBlock extends StatelessWidget {
  const _ChartBlock({required this.chart});

  final FollowUpChart chart;

  @override
  Widget build(BuildContext context) {
    final points = chart.points;
    final first = points.first.at;
    final last = points.last.at;
    String d(DateTime t) => '${t.month}/${t.day}';
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1ECEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                size: 18,
                color: GhadeerHomeColors.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${chart.title} (${chart.unit})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: CustomPaint(
              key: const Key('follow-up-chart'),
              painter: FollowUpChartPainter(chart),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 4),
          // الرسم من اليسار (الأقدم) لليمين (الأحدث) مثل أي رسم بياني.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(d(first), style: _axis),
                Text(d(last), style: _axis),
              ],
            ),
          ),
          if (chart.hasSecondary) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              children: [
                _legend(_primaryLine, chart.primaryLabel),
                _legend(_secondaryLine, chart.secondaryLabel),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const _axis = TextStyle(
    color: GhadeerHomeColors.muted,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
  );

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: _axis),
    ],
  );
}

/// خط بسيط بلا مكتبات: محور زمني حقيقي (المسافة تعكس الأيام) وقيم دنيا/عليا.
class FollowUpChartPainter extends CustomPainter {
  FollowUpChartPainter(this.chart);

  final FollowUpChart chart;

  @override
  void paint(Canvas canvas, Size size) {
    final points = chart.points;
    if (points.length < 2 || size.isEmpty) return;
    final values = <double>[
      for (final p in points) p.value,
      for (final p in points)
        if (p.second != null) p.second!,
      ?chart.targetLow,
      ?chart.targetHigh,
    ];
    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);
    if (maxV - minV < 1) {
      minV -= 1;
      maxV += 1;
    }
    final pad = (maxV - minV) * 0.12;
    minV -= pad;
    maxV += pad;

    const left = 34.0;
    const right = 8.0;
    const top = 6.0;
    const bottom = 6.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final t0 = points.first.at.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.at.millisecondsSinceEpoch.toDouble();
    final span = (t1 - t0) <= 0 ? 1.0 : (t1 - t0);

    double x(int i) {
      final t = points[i].at.millisecondsSinceEpoch.toDouble();
      return left + (t1 == t0 ? i / (points.length - 1) : (t - t0) / span) * w;
    }

    double y(double v) => top + h - (v - minV) / (maxV - minV) * h;

    // شبكة خفيفة + أرقام المحور.
    final grid = Paint()
      ..color = const Color(0xFFE3ECEE)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = minV + (maxV - minV) * i / 3;
      final gy = y(v);
      canvas.drawLine(Offset(left, gy), Offset(size.width - right, gy), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: v.round().toString(),
          style: const TextStyle(
            color: GhadeerHomeColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 4, gy - tp.height / 2));
    }

    // شريط المدى اللي كتبه المريض من طبيبه.
    if (chart.targetLow != null || chart.targetHigh != null) {
      final lo = y(chart.targetLow ?? minV);
      final hi = y(chart.targetHigh ?? maxV);
      canvas.drawRect(
        Rect.fromLTRB(left, hi, size.width - right, lo),
        Paint()..color = const Color(0x1A0FAFA3),
      );
    }

    void line(double Function(FollowUpChartPoint p) pick, Color color) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final o = Offset(x(i), y(pick(points[i])));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      final dotR = points.length > 40 ? 2.0 : 3.2;
      for (var i = 0; i < points.length; i++) {
        canvas.drawCircle(
          Offset(x(i), y(pick(points[i]))),
          points[i].outOfTarget ? dotR + 1.4 : dotR,
          Paint()..color = points[i].outOfTarget ? _outColor : color,
        );
      }
    }

    if (chart.hasSecondary) {
      line((p) => p.second ?? p.value, _secondaryLine);
    }
    line((p) => p.value, _primaryLine);
  }

  @override
  bool shouldRepaint(FollowUpChartPainter oldDelegate) =>
      oldDelegate.chart != chart;
}
