import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../models/doctor_item.dart';
import '../theme/ghadeer_tokens.dart';
import '../doctors/doctor_availability_service.dart';
import '../doctors/doctor_today_availability.dart';
import '../doctors/doctor_today_status.dart';

/// «دوام اليوم» بالرئيسية (Phase 5D) — شريط أفقي لأطباء جدولهم يگول عدهم
/// دوام اليوم والحجز مفتوح أو حضوري.
///
/// ما نگول «موجود هسه» أبد: المصدر جدول الفترات (صباحًا/مساءً) مو الساعة.
/// إذا ماكو أحد ينطبق عليه، القسم كله ما يطلع.
class HomeTodayDoctors extends StatelessWidget {
  const HomeTodayDoctors({
    super.key,
    required this.doctors,
    required this.onOpen,
    required this.onSeeAll,
    this.nowUtc,
  });

  /// الأطباء بالترتيب المعتاد (الأكثر مشاهدة أولًا).
  final List<DoctorItem> doctors;
  final void Function(DoctorItem doctor) onOpen;
  final VoidCallback onSeeAll;
  final DateTime? nowUtc;

  static const int maxItems = 12;

  /// الأطباء اللي جدولهم يثبت دوام اليوم (حجز متاح أو حضوري فقط).
  static List<DoctorItem> pick(List<DoctorItem> all, {DateTime? nowUtc}) {
    final out = <DoctorItem>[];
    for (final d in all) {
      // نفس مصدر شارة الإجازة بالبطاقات — المجاز ما يطلع هنا أبد.
      if (DoctorLeaveDisplay.fromDoctor(d).isOnLeave) continue;
      final today = DoctorTodayAvailability.evaluate(
        workingDays: d.workingDays,
        workingHours: d.workingHours,
        bookingStatus: d.bookingStatus,
        absenceFrom: d.absenceFrom,
        absenceTo: d.absenceTo,
        nowUtc: nowUtc,
      );
      if (today.state == DoctorTodayState.presentBookable ||
          today.state == DoctorTodayState.presentWalkIn) {
        out.add(d);
        if (out.length >= maxItems) break;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final list = pick(doctors, nowUtc: nowUtc);
    if (list.isEmpty) return const SizedBox.shrink();

    final scaler = MediaQuery.textScalerOf(context);
    // صورة + اسم (لحد سطرين) + اختصاص + حالة — الارتفاع يكبر ويا الخط.
    // الشارة تنزل لأسفل البطاقة حتى تبقى على خط واحد بكل البطاقات.
    final cardH =
        8 +
        112 +
        8 +
        scaler.scale(14) * 1.3 * 2 +
        2 +
        scaler.scale(12) * 1.3 +
        6 +
        scaler.scale(11.5) * 1.15 +
        8 +
        10;

    return Column(
      key: const Key('home_today_doctors'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            GhadeerTokens.gutter,
            14,
            4,
            0,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text('دوام اليوم', style: GhadeerTokens.title),
              ),
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  foregroundColor: GhadeerTokens.tealDeep,
                  minimumSize: const Size(
                    GhadeerTokens.touch,
                    GhadeerTokens.touch,
                  ),
                ),
                child: const Text(
                  'كل الاختصاصات',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            GhadeerTokens.gutter,
            0,
            GhadeerTokens.gutter,
            10,
          ),
          child: Text(
            'حسب جدول دوام كل طبيب. اتصل وتأكد قبل لا تروح.',
            style: GhadeerTokens.caption,
          ),
        ),
        SizedBox(
          height: cardH,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: GhadeerTokens.gutter,
            ),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _TodayDoctorCard(
              doctor: list[i],
              nowUtc: nowUtc,
              onTap: () => onOpen(list[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayDoctorCard extends StatelessWidget {
  const _TodayDoctorCard({
    required this.doctor,
    required this.onTap,
    this.nowUtc,
  });

  final DoctorItem doctor;
  final VoidCallback onTap;
  final DateTime? nowUtc;

  @override
  Widget build(BuildContext context) {
    final status = doctorTodayStatus(doctor, nowUtc: nowUtc);
    // عنوان القسم يگول «دوام اليوم»، فالشارة تكفي بالفترة (مساءً) إذا معروفة.
    final period = DoctorTodayAvailability.evaluate(
      workingDays: doctor.workingDays,
      workingHours: doctor.workingHours,
      bookingStatus: doctor.bookingStatus,
      absenceFrom: doctor.absenceFrom,
      absenceTo: doctor.absenceTo,
      nowUtc: nowUtc,
    ).period;
    final chipText =
        (doctor.bookingStatus.trim() == 'available' &&
            period != null &&
            period.isNotEmpty)
        ? period
        : status.text;
    final name = doctor.name.isEmpty ? 'طبيب' : doctor.name;
    return SizedBox(
      width: 136,
      child: Semantics(
        button: true,
        label: 'فتح ملف $name، ${status.text}',
        excludeSemantics: true,
        child: Material(
          color: GhadeerTokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
            side: const BorderSide(color: GhadeerTokens.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
                    child: SizedBox(
                      width: double.infinity,
                      height: 112,
                      child: doctor.imageUrl.trim().isNotEmpty
                          ? GhadeerResolvedImage(
                              doctor.imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              cacheWidth: 300,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, _, _) => const _Fallback(),
                            )
                          : const _Fallback(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: GhadeerTokens.ink,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doctor.specialty.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GhadeerTokens.tealDeep,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status.bg,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      chipText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: status.color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
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

class _Fallback extends StatelessWidget {
  const _Fallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GhadeerTokens.tealWash,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 40,
        color: Color(0xFF8DBDB8),
      ),
    );
  }
}
