import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../models/doctor_item.dart';
import 'doctor_availability_service.dart';

/// بطاقة قائمة الأطباء — Design Target (Compact Discovery Card).
/// بدون أزرار اتصال/واتساب — الإجراءات داخل Doctor Digital Profile.
class ClinicDoctorListCard extends StatelessWidget {
  const ClinicDoctorListCard({
    super.key,
    required this.doctor,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpenProfile,
  });

  final DoctorItem doctor;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenProfile;

  static const _navy = Color(0xFF123B42);
  static const _teal = Color(0xFF0FAFA3);
  static const _muted = Color(0xFF6B7C80);
  static const _line = Color(0xFFE6EEEE);

  ({String text, Color color, Color bg}) _status() {
    final leave = DoctorLeaveDisplay.fromDoctor(doctor);
    if (leave.isOnLeave) {
      return (
        text: leave.badgeLabel.isNotEmpty ? leave.badgeLabel : 'غير متواجد',
        color: const Color(0xFFC94A4A),
        bg: const Color(0xFFFDE8E8),
      );
    }
    switch (doctor.bookingStatus) {
      case 'available':
        return (
          text: 'متاح اليوم',
          color: const Color(0xFF138B4C),
          bg: const Color(0xFFE6F8EE),
        );
      case 'walk_in_only':
        return (
          text: 'حضوري فقط',
          color: const Color(0xFFE07A00),
          bg: const Color(0xFFFFF1DE),
        );
      case 'full':
        return (
          text: 'مكتمل',
          color: const Color(0xFFC94A4A),
          bg: const Color(0xFFFDE8E8),
        );
      default:
        return (
          text: 'غير متواجد',
          color: const Color(0xFFC94A4A),
          bg: const Color(0xFFFDE8E8),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status();

    // بطاقة قائمة — العرض يُحدَّد من الأب (قائمة أو شبكة متجاوبة).
    return Semantics(
      button: true,
      label: 'فتح ملف ${doctor.name}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        child: InkWell(
          onTap: onOpenProfile,
          borderRadius: BorderRadius.circular(20),
          child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                height: 96,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: doctor.imageUrl.trim().isNotEmpty
                            ? GhadeerResolvedImage(
                                doctor.imageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                cacheWidth: 280,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (_, _, _) =>
                                    const _ListPortraitFallback(),
                              )
                            : const _ListPortraitFallback(),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                        child: Material(
                          color: Colors.white,
                          elevation: 1,
                          shadowColor: Colors.black26,
                          shape: const CircleBorder(),
                          child: Semantics(
                            button: true,
                            label: isFavorite
                                ? 'إزالة ${doctor.name} من المفضلة'
                                : 'إضافة ${doctor.name} للمفضلة',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onToggleFavorite,
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 15,
                                  color: isFavorite
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFF8A9A9E),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doctor.name.isEmpty ? 'طبيب' : doctor.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: _navy,
                            ),
                          ),
                        ),
                        if (doctor.ghadeerBadge)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF1A73E8),
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    if (doctor.specialty.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        doctor.specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _teal,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // سطر الحالة منفصل حتى النص الطويل (إجازة) لا يكسر ارتفاع البطاقة.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (doctor.location.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: _muted,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              doctor.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFFB0BEC2),
                size: 26,
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
      color: const Color(0xFFEAF4F3),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 40,
        color: Color(0xFF9BB8B6),
      ),
    );
  }
}
