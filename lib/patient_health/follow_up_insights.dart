import 'patient_health_models.dart';
import 'patient_health_validation.dart';

/// خلاصة أرقام بطاقة المتابعة: عدّ ومعدّل وأعلى وأقل وآخر قراءة، مقسّمة حسب
/// وقت القياس. أرقام المريض كما أدخلها — بلا تفسير ولا تشخيص.

/// صف ملخّص واحد (مثلاً «الكل» أو «صباحاً» أو «صائم»).
class FollowUpSummaryRow {
  const FollowUpSummaryRow({
    required this.label,
    required this.count,
    required this.average,
    required this.lowest,
    required this.highest,
    required this.latest,
  });

  final String label;
  final int count;
  final String average;
  final String lowest;
  final String highest;
  final String latest;
}

/// مجموعة ملخّص بوحدة واحدة (لا نخلط mg/dL مع mmol/L).
class FollowUpSummaryGroup {
  const FollowUpSummaryGroup({
    required this.title,
    required this.unit,
    required this.rows,
  });

  final String title;
  final String unit;
  final List<FollowUpSummaryRow> rows;
}

/// نقطة رسم: الوقت والقيمة (والقيمة الثانية للضغط الانبساطي).
class FollowUpChartPoint {
  const FollowUpChartPoint({
    required this.at,
    required this.value,
    this.second,
    this.outOfTarget = false,
  });

  final DateTime at;
  final double value;
  final double? second;
  final bool outOfTarget;
}

class FollowUpChart {
  const FollowUpChart({
    required this.title,
    required this.unit,
    required this.points,
    this.primaryLabel = '',
    this.secondaryLabel = '',
    this.targetLow,
    this.targetHigh,
  });

  final String title;
  final String unit;
  final List<FollowUpChartPoint> points;
  final String primaryLabel;
  final String secondaryLabel;
  final double? targetLow;
  final double? targetHigh;

  bool get hasSecondary => points.any((p) => p.second != null);
}

/// المدى الذي **كتبه المريض من طبيبه** (لا يحدده التطبيق أبداً).
class FollowUpTarget {
  const FollowUpTarget({
    this.low,
    this.high,
    this.secondLow,
    this.secondHigh,
    this.unit,
  });

  /// للسكر: الحد الأدنى/الأعلى. للضغط: الانقباضي.
  final double? low;
  final double? high;

  /// للضغط: الانبساطي.
  final double? secondLow;
  final double? secondHigh;

  /// للسكر: وحدة المدى. قراءات بوحدة ثانية ما تنقارن بيه.
  final GlucoseUnit? unit;

  bool get isEmpty =>
      low == null && high == null && secondLow == null && secondHigh == null;

  bool outside(double value, {double? second}) {
    if (low != null && value < low!) return true;
    if (high != null && value > high!) return true;
    if (second != null) {
      if (secondLow != null && second < secondLow!) return true;
      if (secondHigh != null && second > secondHigh!) return true;
    }
    return false;
  }
}

/// سطر حقيقة للثلاسيميا (آخر نقل دم، المعدّل بين النقلات، الموعد القادم).
class FollowUpFact {
  const FollowUpFact({required this.label, required this.value});

  final String label;
  final String value;
}

class FollowUpInsights {
  const FollowUpInsights({
    this.summaries = const [],
    this.charts = const [],
    this.facts = const [],
    this.outOfTargetCount = 0,
  });

  final List<FollowUpSummaryGroup> summaries;
  final List<FollowUpChart> charts;
  final List<FollowUpFact> facts;

  /// عدد القراءات خارج المدى الذي أدخله المريض (0 إن لم يُدخل مدى).
  final int outOfTargetCount;

  bool get isEmpty => summaries.isEmpty && charts.isEmpty && facts.isEmpty;
}

/// صباحاً = 4:00–11:59 بتوقيت الجهاز، وما عداه مساءً.
bool isMorningReading(DateTime at) {
  final h = at.toLocal().hour;
  return h >= 4 && h < 12;
}

String _num(double v) {
  final r = (v * 10).roundToDouble() / 10;
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
}

String _bp(double s, double d) => '${_num(s)}/${_num(d)}';

FollowUpSummaryRow? _bpRow(String label, List<BpReading> rows) {
  if (rows.isEmpty) return null;
  final sorted = [...rows]
    ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  final avgS =
      rows.map((r) => r.systolic).reduce((a, b) => a + b) / rows.length;
  final avgD =
      rows.map((r) => r.diastolic).reduce((a, b) => a + b) / rows.length;
  // الأعلى/الأقل حسب الانقباضي (مع انبساطي نفس القراءة).
  final hi = rows.reduce((a, b) => b.systolic > a.systolic ? b : a);
  final lo = rows.reduce((a, b) => b.systolic < a.systolic ? b : a);
  final last = sorted.last;
  return FollowUpSummaryRow(
    label: label,
    count: rows.length,
    average: _bp(avgS, avgD),
    lowest: '${lo.systolic}/${lo.diastolic}',
    highest: '${hi.systolic}/${hi.diastolic}',
    latest: '${last.systolic}/${last.diastolic}',
  );
}

FollowUpSummaryRow? _glucoseRow(String label, List<GlucoseReading> rows) {
  if (rows.isEmpty) return null;
  final sorted = [...rows]
    ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  final values = rows.map((r) => r.value).toList();
  final avg = values.reduce((a, b) => a + b) / values.length;
  return FollowUpSummaryRow(
    label: label,
    count: rows.length,
    average: _num(avg),
    lowest: _num(values.reduce((a, b) => a < b ? a : b)),
    highest: _num(values.reduce((a, b) => a > b ? a : b)),
    latest: _num(sorted.last.value),
  );
}

/// يبني الملخص والرسم وحقائق الثلاسيميا لمرض واحد ضمن الفترة المختارة.
FollowUpInsights buildFollowUpInsights({
  required String userId,
  required PatientHealthSnapshot snapshot,
  required FollowUpSelection selection,
  FollowUpTarget target = const FollowUpTarget(),
}) {
  PatientCondition? condition;
  for (final c in snapshot.conditions) {
    if (c.id == selection.conditionId && c.userId == userId) condition = c;
  }
  if (condition == null) return const FollowUpInsights();

  final summaries = <FollowUpSummaryGroup>[];
  final charts = <FollowUpChart>[];
  final facts = <FollowUpFact>[];
  var outside = 0;

  if (selection.includeMeasurements &&
      condition.kind == ConditionKind.hypertension) {
    final rows = [
      for (final r in snapshot.bpReadings)
        if (r.userId == userId &&
            r.conditionId == condition.id &&
            healthStampInPeriod(r.measuredAt, selection))
          r,
    ]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    if (rows.isNotEmpty) {
      final morning = [
        for (final r in rows)
          if (isMorningReading(r.measuredAt)) r,
      ];
      final evening = [
        for (final r in rows)
          if (!isMorningReading(r.measuredAt)) r,
      ];
      summaries.add(
        FollowUpSummaryGroup(
          title: 'ملخص الضغط',
          unit: 'ملم زئبق',
          rows: [
            ?_bpRow('الكل', rows),
            if (morning.isNotEmpty && evening.isNotEmpty) ...[
              ?_bpRow('صباحاً', morning),
              ?_bpRow('مساءً', evening),
            ],
          ],
        ),
      );
      final pulses = [
        for (final r in rows)
          if (r.pulse != null) r.pulse!,
      ];
      if (pulses.isNotEmpty) {
        facts.add(
          FollowUpFact(
            label: 'معدّل النبض',
            value:
                '${_num(pulses.reduce((a, b) => a + b) / pulses.length)} نبضة/دقيقة',
          ),
        );
      }
      final points = [
        for (final r in rows)
          FollowUpChartPoint(
            at: r.measuredAt,
            value: r.systolic.toDouble(),
            second: r.diastolic.toDouble(),
            outOfTarget:
                !target.isEmpty &&
                target.outside(
                  r.systolic.toDouble(),
                  second: r.diastolic.toDouble(),
                ),
          ),
      ];
      outside += points.where((p) => p.outOfTarget).length;
      if (points.length >= 2) {
        charts.add(
          FollowUpChart(
            title: 'الضغط عبر الأيام',
            unit: 'ملم زئبق',
            points: points,
            primaryLabel: 'الانقباضي',
            secondaryLabel: 'الانبساطي',
            targetLow: target.low,
            targetHigh: target.high,
          ),
        );
      }
    }
  }

  if (selection.includeMeasurements &&
      condition.kind == ConditionKind.diabetes) {
    final all = [
      for (final r in snapshot.glucoseReadings)
        if (r.userId == userId &&
            r.conditionId == condition.id &&
            healthStampInPeriod(r.measuredAt, selection))
          r,
    ]..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    for (final unit in GlucoseUnit.values) {
      final rows = [
        for (final r in all)
          if (r.unit == unit) r,
      ];
      if (rows.isEmpty) continue;
      final unitTarget = target.unit == null || target.unit == unit
          ? target
          : const FollowUpTarget();
      summaries.add(
        FollowUpSummaryGroup(
          title: 'ملخص السكر',
          unit: glucoseUnitLabel(unit),
          rows: [
            ?_glucoseRow('الكل', rows),
            for (final timing in GlucoseTiming.values)
              ?_glucoseRow(glucoseTimingLabel(timing), [
                for (final r in rows)
                  if (r.timing == timing) r,
              ]),
          ],
        ),
      );
      final points = [
        for (final r in rows)
          FollowUpChartPoint(
            at: r.measuredAt,
            value: r.value,
            outOfTarget: !unitTarget.isEmpty && unitTarget.outside(r.value),
          ),
      ];
      outside += points.where((p) => p.outOfTarget).length;
      if (points.length >= 2) {
        charts.add(
          FollowUpChart(
            title: 'السكر عبر الأيام',
            unit: glucoseUnitLabel(unit),
            points: points,
            targetLow: unitTarget.low,
            targetHigh: unitTarget.high,
          ),
        );
      }
    }
  }

  if (selection.includeEvents && condition.kind == ConditionKind.thalassemia) {
    final mine = [
      for (final e in snapshot.events)
        if (e.userId == userId && e.conditionId == condition.id) e,
    ];
    final transfusions = [
      for (final e in mine)
        if (e.kind == ThalassemiaEventKind.transfusion &&
            !e.occurredAt.isAfter(selection.issuedAt))
          e,
    ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    if (transfusions.isNotEmpty) {
      final last = transfusions.last.occurredAt;
      final days = selection.issuedAt.difference(last).inDays;
      facts.add(
        FollowUpFact(
          label: 'آخر نقل دم',
          value: days <= 0
              ? 'اليوم'
              : 'قبل $days يوم (${formatHealthStamp(last).split(' ').first})',
        ),
      );
      final inPeriod = [
        for (final t in transfusions)
          if (healthStampInPeriod(t.occurredAt, selection)) t,
      ];
      if (inPeriod.isNotEmpty) {
        facts.add(
          FollowUpFact(
            label: 'عدد نقل الدم بالفترة',
            value: '${inPeriod.length}',
          ),
        );
      }
      if (transfusions.length >= 2) {
        var totalDays = 0;
        for (var i = 1; i < transfusions.length; i++) {
          totalDays += transfusions[i].occurredAt
              .difference(transfusions[i - 1].occurredAt)
              .inDays;
        }
        facts.add(
          FollowUpFact(
            label: 'المعدّل بين كل نقل والثاني',
            value: '${(totalDays / (transfusions.length - 1)).round()} يوم',
          ),
        );
      }
    }
    final upcoming = [
      for (final e in mine)
        if (e.kind == ThalassemiaEventKind.appointment &&
            e.occurredAt.isAfter(selection.issuedAt))
          e,
    ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    if (upcoming.isNotEmpty) {
      final next = upcoming.first;
      facts.add(
        FollowUpFact(
          label: 'الموعد القادم',
          value: '${formatHealthStamp(next.occurredAt)} · ${next.title}',
        ),
      );
    }
  }

  return FollowUpInsights(
    summaries: summaries,
    charts: charts,
    facts: facts,
    outOfTargetCount: outside,
  );
}
