import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import 'service_center_kind.dart';

/// ألوان وأيقونة كل قسم — مكان واحد بدل شروط optics/beauty المتفرقة.
extension ServiceCenterKindStyle on ServiceCenterKind {
  Color get accent => switch (this) {
    ServiceCenterKind.optics => GhadeerHomeColors.opticsAccent,
    ServiceCenterKind.beauty => GhadeerHomeColors.beautyAccent,
    ServiceCenterKind.nursing => GhadeerHomeColors.nursingAccent,
  };

  Color get background => switch (this) {
    ServiceCenterKind.optics => GhadeerHomeColors.opticsBg,
    ServiceCenterKind.beauty => GhadeerHomeColors.beautyBg,
    ServiceCenterKind.nursing => GhadeerHomeColors.nursingBg,
  };

  IconData get icon => switch (this) {
    ServiceCenterKind.optics => Icons.visibility_outlined,
    ServiceCenterKind.beauty => Icons.spa_outlined,
    ServiceCenterKind.nursing => Icons.medical_services_outlined,
  };
}
