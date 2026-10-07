import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
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
    final readings = [
      for (final row in snapshot.bpReadings)
        if (row.userId == userId &&
            row.conditionId == condition.id &&
            healthStampInPeriod(row.measuredAt, selection))
          row,
    ]..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    for (final row in readings) {
      final pulse = row.pulse == null ? '' : ' · نبض ${row.pulse}';
      lines.add(
        FollowUpLine(
          title: formatHealthStamp(row.measuredAt),
          detail: '${row.systolic}/${row.diastolic} ملم زئبق$pulse',
        ),
      );
    }
  }

  if (selection.includeMeasurements && condition.kind == ConditionKind.diabetes) {
    final readings = [
      for (final row in snapshot.glucoseReadings)
        if (row.userId == userId &&
            row.conditionId == condition.id &&
            healthStampInPeriod(row.measuredAt, selection))
          row,
    ]..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    for (final row in readings) {
      final value = row.value == row.value.roundToDouble()
          ? row.value.toStringAsFixed(0)
          : row.value.toString();
      lines.add(
        FollowUpLine(
          title: formatHealthStamp(row.measuredAt),
          detail:
              '$value ${glucoseUnitLabel(row.unit)} · ${glucoseTimingLabel(row.timing)}',
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
          title: '${thalassemiaEventLabel(row.kind)} · ${formatHealthStamp(row.occurredAt)}',
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
    issuedAt: selection.issuedAt,
    emptyNote: lines.isEmpty ? 'لا سجلات ضمن الخيارات والفترة المحددة.' : '',
  );
}

class FollowUpCardView extends StatelessWidget {
  const FollowUpCardView({super.key, required this.content});

  final FollowUpCardContent content;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'عيادة الغدير',
                style: TextStyle(
                  color: GhadeerHomeColors.pharmacyAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'بطاقة متابعة',
                style: TextStyle(
                  color: GhadeerHomeColors.secondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                content.conditionTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.3,
                ),
              ),
              if (content.patientName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'الاسم: ${content.patientName}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                patientDataAttribution,
                style: TextStyle(
                  color: Color(0xFF0C7F76),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              if (content.emptyNote.isNotEmpty)
                Text(
                  content.emptyNote,
                  style: const TextStyle(height: 1.4),
                ),
              for (final line in content.lines) ...[
                Text(
                  line.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(line.detail, style: const TextStyle(height: 1.45)),
                const SizedBox(height: 8),
              ],
              const Divider(height: 16),
              Text(
                'تاريخ الإصدار: ${formatHealthStamp(content.issuedAt)}',
                style: const TextStyle(
                  color: GhadeerHomeColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'المعلومات أعلاه أدخلها صاحب الحساب لمشاركتها مع من يختاره. '
                'ليست تقريراً طبياً من عيادة الغدير.',
                style: TextStyle(
                  color: GhadeerHomeColors.muted,
                  height: 1.4,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
