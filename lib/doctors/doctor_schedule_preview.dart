import 'package:flutter/material.dart';

import '../theme/ghadeer_tokens.dart';
import 'doctor_week_schedule.dart';

/// معاينة الدوام بمحرّر الإدارة وبطاقة الطبيب (Phase 5C): نفس الكلام اللي
/// راح يطلع بصفحة الطبيب («يومياً مساءً» + الملاحظات)، قبل لا ينحفظ.
/// تقرأ النص بنفس القارئ اللي تستخدمه صفحة الطبيب وعقل الغدير.
class DoctorSchedulePreview extends StatelessWidget {
  const DoctorSchedulePreview({
    super.key,
    required this.workingHours,
    this.workingDays = '',
  });

  final String workingHours;
  final String workingDays;

  @override
  Widget build(BuildContext context) {
    final week = parseDoctorWeekSchedule(
      workingDays: workingDays,
      workingHours: workingHours,
    );
    final summary = summarizeDoctorWeek(week);
    final empty = week.isEmpty;

    return Container(
      key: const Key('doctor_schedule_preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: empty ? GhadeerTokens.warnWash : GhadeerTokens.tealWash,
        borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                empty ? Icons.info_outline_rounded : Icons.visibility_outlined,
                size: 18,
                color: empty ? GhadeerTokens.warn : GhadeerTokens.tealDeep,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'شلون راح يطلع الدوام بصفحة الطبيب',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: GhadeerTokens.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            empty ? 'ما يطلع دوام — اختر فترة لكل يوم' : summary.headline,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: empty ? GhadeerTokens.warn : GhadeerTokens.ink,
            ),
          ),
          if (summary.notes.isNotEmpty || summary.offDays.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in summary.notes)
                  _chip(n, GhadeerTokens.tealDeep, GhadeerTokens.surface),
                if (summary.offDays.isNotEmpty)
                  _chip(
                    'عطلة: ${summary.offDays.join('، ')}',
                    GhadeerTokens.warn,
                    GhadeerTokens.surface,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(50),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}
