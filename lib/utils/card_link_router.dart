import 'package:flutter/material.dart';

import '../centers/service_center_profile_page.dart';
import '../centers/service_centers_store.dart';
import '../labs/lab_profile_page.dart';
import '../labs/labs_service.dart';
import '../pharmacies/pharmacies_store.dart';
import '../pharmacies/pharmacy_profile_page.dart';
import '../physio/physio_profile_page.dart';
import '../physio/physio_store.dart';
import '../radiology/radiology_profile_page.dart';
import '../radiology/radiology_service.dart';
import '../supplies/supplies_store.dart';
import '../supplies/supply_profile_page.dart';
import 'ghadeer_card_link.dart';

/// يفتح بطاقة غير الطبيب من رابط مشاركة. الطبيب يفتحه main.dart بمساره
/// الخاص (المفضلة والتقييم). يرجع false إذا البطاقة مو موجودة أو مخفية.
Future<bool> openSharedCard(BuildContext context, GhadeerCardRef ref) async {
  Widget? page;
  try {
    switch (ref.kind) {
      case GhadeerCardKind.doctor:
        return false;
      case GhadeerCardKind.lab:
        final lab = await LabsService().fetchLabById(ref.id);
        if (lab != null) page = LabProfilePage(lab: lab);
      case GhadeerCardKind.radiology:
        final center = await RadiologyService().fetchCenterById(ref.id);
        if (center != null) page = RadiologyProfilePage(center: center);
      case GhadeerCardKind.pharmacy:
        await PharmaciesStore.instance.load();
        for (final p in PharmaciesStore.instance.items) {
          if (p.id == ref.id) page = PharmacyProfilePage(pharmacy: p);
        }
      case GhadeerCardKind.physio:
        await PhysioStore.instance.load();
        for (final c in PhysioStore.instance.items) {
          if (c.id == ref.id) page = PhysioProfilePage(center: c);
        }
      case GhadeerCardKind.supply:
        await SuppliesStore.instance.load();
        for (final v in SuppliesStore.instance.items) {
          if (v.id == ref.id) page = SupplyProfilePage(vendor: v);
        }
      case GhadeerCardKind.center:
        await ServiceCentersStore.instance.load();
        for (final c in ServiceCentersStore.instance.sharedItems) {
          if (c.id == ref.id && c.isActive) {
            page = ServiceCenterProfilePage(center: c);
          }
        }
    }
  } catch (e) {
    debugPrint('openSharedCard ${ref.kind.path} failed: $e');
    page = null;
  }
  if (page == null || !context.mounted) return false;
  final target = page;
  await Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => target));
  return true;
}
