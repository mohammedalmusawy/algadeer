import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import '../models/doctor_item.dart';
import '../utils/responsive.dart';
import 'clinic_doctor_list_card.dart';

/// قائمة أطباء اختصاص واحد — تُفتح من بطاقة الأطباء → الاختصاصات.
class SpecialtyDoctorsPage extends StatefulWidget {
  const SpecialtyDoctorsPage({
    super.key,
    required this.specialty,
    required this.doctors,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.onOpenProfile,
  });

  final String specialty;
  final List<DoctorItem> doctors;
  final Set<String> favoriteIds;
  final void Function(String doctorId) onToggleFavorite;
  final void Function(DoctorItem doctor) onOpenProfile;

  @override
  State<SpecialtyDoctorsPage> createState() => _SpecialtyDoctorsPageState();
}

class _SpecialtyDoctorsPageState extends State<SpecialtyDoctorsPage> {
  late Set<String> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = Set<String>.from(widget.favoriteIds);
  }

  @override
  void didUpdateWidget(covariant SpecialtyDoctorsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favoriteIds != widget.favoriteIds) {
      _favorites = Set<String>.from(widget.favoriteIds);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
    widget.onToggleFavorite(id);
  }

  @override
  Widget build(BuildContext context) {
    final pad = AppResponsive.pagePadding(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: GhadeerHomeColors.pageBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: GhadeerHomeColors.secondary,
          elevation: 0,
          title: Text(
            widget.specialty,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: GhadeerHomeColors.secondary,
            ),
          ),
        ),
        body: widget.doctors.isEmpty
            ? const Center(
                child: Text(
                  'لا يوجد أطباء في هذا الاختصاص حالياً',
                  style: TextStyle(
                    color: GhadeerHomeColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
                itemCount: widget.doctors.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doctor = widget.doctors[index];
                  return ClinicDoctorListCard(
                    doctor: doctor,
                    isFavorite: _favorites.contains(doctor.id),
                    onToggleFavorite: () => _toggle(doctor.id),
                    onOpenProfile: () => widget.onOpenProfile(doctor),
                  );
                },
              ),
      ),
    );
  }
}
