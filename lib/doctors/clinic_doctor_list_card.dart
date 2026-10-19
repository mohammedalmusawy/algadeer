import 'package:flutter/material.dart';

import 'dart:async';

import '../branding/ghadeer_brand_mark.dart';
import '../models/doctor_item.dart';
import '../theme/ghadeer_tokens.dart';
import '../utils/ghadeer_haptics.dart';
import 'doctor_card_gate.dart';
import 'doctor_card_tap.dart';
import 'doctor_today_status.dart';

/// بطاقة قائمة الأطباء — Design Target (Compact Discovery Card).
/// بدون أزرار اتصال/واتساب — الإجراءات داخل Doctor Digital Profile.
class ClinicDoctorListCard extends StatelessWidget {
  const ClinicDoctorListCard({
    super.key,
    required this.doctor,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpenProfile,
    this.onTripleTap,
  });

  final DoctorItem doctor;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenProfile;

  /// إن تُرك فارغًا تُفتح نافذة كلمة مرور البطاقة.
  final VoidCallback? onTripleTap;

  /// حالة اليوم من الدوام المسجّل + الحجز (عطلة اليوم / متوفر اليوم · مساءً).
  ({String text, Color color, Color bg}) _status() => doctorTodayStatus(doctor);

  @override
  Widget build(BuildContext context) {
    final status = _status();
    final radius = BorderRadius.circular(GhadeerTokens.radiusLg);

    // بطاقة قائمة هادئة — العرض يُحدَّد من الأب (قائمة أو شبكة متجاوبة).
    return Semantics(
      button: true,
      label: 'فتح ملف ${doctor.name}',
      child: Material(
        color: GhadeerTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: GhadeerTokens.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: DoctorCardOpenSurface(
          onOpen: onOpenProfile,
          onTripleTap:
              onTripleTap ??
              () {
                unawaited(openDoctorCardAccess(context, doctor));
              },
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
                  child: SizedBox(
                    width: 76,
                    height: 84,
                    child: doctor.imageUrl.trim().isNotEmpty
                        ? GhadeerResolvedImage(
                            doctor.imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            cacheWidth: 240,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) =>
                                const _ListPortraitFallback(),
                          )
                        : const _ListPortraitFallback(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              doctor.name.isEmpty ? 'طبيب' : doctor.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: GhadeerTokens.ink,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (doctor.ghadeerBadge)
                            const Padding(
                              padding: EdgeInsetsDirectional.only(start: 4),
                              child: Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF1A73E8),
                                size: 17,
                              ),
                            ),
                        ],
                      ),
                      if (doctor.specialty.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          doctor.specialty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: GhadeerTokens.tealDeep,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // سطر الحالة منفصل حتى النص الطويل (إجازة) لا يكسر الارتفاع.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: status.bg,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          status.text,
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
                      if (doctor.location.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: GhadeerTokens.inkMuted,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                doctor.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GhadeerTokens.caption,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: isFavorite
                      ? 'إزالة ${doctor.name} من المفضلة'
                      : 'إضافة ${doctor.name} للمفضلة',
                  child: InkResponse(
                    onTap: () {
                      ghadeerToggleFeedback();
                      onToggleFavorite();
                    },
                    radius: 22,
                    child: SizedBox(
                      width: GhadeerTokens.touch,
                      height: GhadeerTokens.touch,
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 22,
                        color: isFavorite
                            ? const Color(0xFFD93A4A)
                            : GhadeerTokens.inkFaint,
                      ),
                    ),
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

class _ListPortraitFallback extends StatelessWidget {
  const _ListPortraitFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GhadeerTokens.tealWash,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 38,
        color: Color(0xFF8DBDB8),
      ),
    );
  }
}
