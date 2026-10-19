import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import 'follow_up_insights.dart';
import 'follow_up_insights_view.dart';
import 'patient_health_models.dart';
import 'patient_health_validation.dart';

/// يبني خلاصة بطاقة من سجلات المالك فقط.
FollowUpCardContent buildFollowUpCard({
  required String userId,
  required PatientHealthSnapshot snapshot,
  required FollowUpSelection selection,
}) {
  final condition = snapshot.conditions.cast<PatientCondition?>().firstWhere(
    (item) => item!.id == selection.conditionId && item.userId == userId,
    orElse: () => null,
  );
  if (condition == null) throw const PatientAccessDenied();

  final lines = <FollowUpLine>[];
  final readings = <FollowUpReadingRow>[];

  if (selection.includeTreatment &&
      condition.prescribedTreatment.trim().isNotEmpty) {
    lines.add(
      FollowUpLine(
        title: 'علاج موصوف أدخله المريض',
        detail: condition.prescribedTreatment.trim(),
      ),
    );
  }
  if (selection.includeReviews && condition.reviewsNote.trim().isNotEmpty) {
    lines.add(
      FollowUpLine(title: 'مراجعات', detail: condition.reviewsNote.trim()),
    );
  }
  if (selection.includeNotes && condition.notes.trim().isNotEmpty) {
    lines.add(FollowUpLine(title: 'ملاحظات', detail: condition.notes.trim()));
  }
  if (condition.kind == ConditionKind.thalassemia &&
      condition.thalassemiaType.trim().isNotEmpty) {
    lines.add(
      FollowUpLine(
        title: 'نوع الحالة كما أدخله المريض',
        detail: condition.thalassemiaType.trim(),
      ),
    );
  }

  if (selection.includeMeasurements &&
      condition.kind == ConditionKind.hypertension) {
    final rows = [
      for (final row in snapshot.bpReadings)
        if (row.userId == userId &&
            row.conditionId == condition.id &&
            healthStampInPeriod(row.measuredAt, selection))
          row,
    ]..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    for (final row in rows) {
      final pulse = row.pulse == null ? '' : ' · نبض ${row.pulse}';
      readings.add(
        FollowUpReadingRow(
          dateTimeLabel: formatHealthStamp(row.measuredAt),
          valueLabel: '${row.systolic}/${row.diastolic}$pulse',
          unitLabel: 'ملم زئبق',
          kindLabel: 'ضغط الدم',
        ),
      );
    }
  }

  if (selection.includeMeasurements &&
      condition.kind == ConditionKind.diabetes) {
    final rows = [
      for (final row in snapshot.glucoseReadings)
        if (row.userId == userId &&
            row.conditionId == condition.id &&
            healthStampInPeriod(row.measuredAt, selection))
          row,
    ]..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    for (final row in rows) {
      final value = row.value == row.value.roundToDouble()
          ? row.value.toStringAsFixed(0)
          : row.value.toString();
      readings.add(
        FollowUpReadingRow(
          dateTimeLabel: formatHealthStamp(row.measuredAt),
          valueLabel: value,
          unitLabel: glucoseUnitLabel(row.unit),
          kindLabel: 'سكر · ${glucoseTimingLabel(row.timing)}',
        ),
      );
    }
  }

  if (selection.includeEvents && condition.kind == ConditionKind.thalassemia) {
    final events = [
      for (final row in snapshot.events)
        if (row.userId == userId &&
            row.conditionId == condition.id &&
            healthStampInPeriod(row.occurredAt, selection))
          row,
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    for (final row in events) {
      final details = row.details.trim();
      lines.add(
        FollowUpLine(
          title:
              '${thalassemiaEventLabel(row.kind)} · ${formatHealthStamp(row.occurredAt)}',
          detail: details.isEmpty ? row.title : '${row.title}\n$details',
        ),
      );
    }
  }

  final name = selection.showName
      ? (snapshot.profile?.userId == userId
            ? snapshot.profile!.displayName.trim()
            : '')
      : '';

  return FollowUpCardContent(
    conditionTitle: condition.title,
    patientName: name.isEmpty ? null : name,
    lines: lines,
    readings: readings,
    issuedAt: selection.issuedAt,
    emptyNote: lines.isEmpty && readings.isEmpty
        ? 'لا سجلات ضمن الخيارات والفترة المحددة.'
        : '',
  );
}

class FollowUpCardView extends StatelessWidget {
  const FollowUpCardView({
    super.key,
    required this.content,
    this.insights = const FollowUpInsights(),
    this.conditionKind,
  });

  final FollowUpCardContent content;

  /// الملخص والرسم (اختياري) — يظهر بالصورة وPDF لأنهما لقطة من البطاقة.
  final FollowUpInsights insights;

  /// لاختيار أيقونة رأس البطاقة فقط.
  final ConditionKind? conditionKind;

  static IconData iconFor(ConditionKind? kind) {
    switch (kind) {
      case ConditionKind.hypertension:
        return Icons.monitor_heart_outlined;
      case ConditionKind.diabetes:
        return Icons.water_drop_outlined;
      case ConditionKind.thalassemia:
        return Icons.bloodtype_outlined;
      case ConditionKind.other:
      case null:
        return Icons.favorite_border_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // رأس ملوّن بهوية الغدير.
            Container(
              key: const Key('follow-up-card-header'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [Color(0xFF0FAFA3), GhadeerHomeColors.secondary],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconFor(conditionKind),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'منصة الغدير',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          'بطاقة متابعة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    content.conditionTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      height: 1.3,
                    ),
                  ),
                  if (content.patientName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'الاسم: ${content.patientName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    patientDataAttribution,
                    style: TextStyle(
                      color: Color(0xFF0C7F76),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (content.emptyNote.isNotEmpty)
                    Text(
                      content.emptyNote,
                      style: const TextStyle(height: 1.4, fontSize: 14),
                    ),
                  FollowUpInsightsView(insights: insights),
                  if (content.readings.isNotEmpty) ...[
                    const Text(
                      'القراءات',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ReadingsTable(rows: content.readings),
                    const SizedBox(height: 12),
                  ],
                  for (final line in content.lines) ...[
                    Text(
                      line.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line.detail,
                      style: const TextStyle(height: 1.45, fontSize: 14.5),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Divider(height: 16),
                  Text(
                    'تاريخ الإصدار: ${formatHealthStamp(content.issuedAt)}',
                    style: const TextStyle(
                      color: GhadeerHomeColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'المعلومات أعلاه أدخلها صاحب الحساب لمشاركتها مع من يختاره. '
                    'ليست تقريراً طبياً من منصة الغدير.',
                    style: TextStyle(
                      color: GhadeerHomeColors.muted,
                      height: 1.4,
                      fontSize: 13,
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

class _ReadingsTable extends StatelessWidget {
  const _ReadingsTable({required this.rows});

  final List<FollowUpReadingRow> rows;

  static const _headerStyle = TextStyle(
    fontWeight: FontWeight.w900,
    fontSize: 12.5,
    height: 1.25,
  );
  static const _cellStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 13.5,
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    final showNote = rows.any((r) => r.note.trim().isNotEmpty);
    return Table(
      border: TableBorder.all(color: const Color(0xFFD5E0E3), width: 1),
      columnWidths: showNote
          ? const {
              0: FlexColumnWidth(1.35),
              1: FlexColumnWidth(1.1),
              2: FlexColumnWidth(0.9),
              3: FlexColumnWidth(1.1),
              4: FlexColumnWidth(1.2),
            }
          : const {
              0: FlexColumnWidth(1.4),
              1: FlexColumnWidth(1.15),
              2: FlexColumnWidth(0.95),
              3: FlexColumnWidth(1.2),
            },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF2F7F8)),
          children: [
            _cell('التاريخ والوقت', header: true),
            _cell('القراءة', header: true),
            _cell('الوحدة', header: true),
            _cell('نوع القياس', header: true),
            if (showNote) _cell('ملاحظة', header: true),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              _cell(row.dateTimeLabel),
              _cell(row.valueLabel),
              _cell(row.unitLabel),
              _cell(row.kindLabel),
              if (showNote) _cell(row.note.trim()),
            ],
          ),
      ],
    );
  }

  Widget _cell(String text, {bool header = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: header ? _headerStyle : _cellStyle,
      ),
    );
  }
}
