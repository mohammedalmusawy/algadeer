import 'package:flutter/material.dart';

import '../theme/ghadeer_tokens.dart';

/// ألوان الأقسام — مربوطة بهوية الغدير («الماي الصافي») في [GhadeerTokens].
///
/// كل قسم عنده صبغة خلفية فاتحة ولون أيقونة أغمق بنفس العائلة الهادئة،
/// حتى تتميّز الأقسام بدون ما يصير التطبيق ملوّن وصاخب.
class GhadeerHomeColors {
  GhadeerHomeColors._();

  static const primary = GhadeerTokens.teal;
  static const secondary = GhadeerTokens.ink;

  /// خلفية الصفحة — ضباب هادي.
  static const pageBg = GhadeerTokens.mist;
  static const skyBg = GhadeerTokens.tealWash;
  static const surface = GhadeerTokens.surface;
  static const muted = GhadeerTokens.inkMuted;

  static const doctorsBg = Color(0xFFE3F5F3);
  static const doctorsAccent = Color(0xFF0A7C74);

  static const radiologyBg = Color(0xFFE6EEF8);
  static const radiologyAccent = Color(0xFF2F5D9B);

  static const labsBg = Color(0xFFFBEAEE);
  static const labsAccent = Color(0xFFB4475F);

  static const physioBg = Color(0xFFE7F3EA);
  static const physioAccent = Color(0xFF2F7A47);

  static const suppliesBg = Color(0xFFFBF0E2);
  static const suppliesAccent = Color(0xFF9A5B12);

  static const pharmacyBg = Color(0xFFE2F4F5);

  /// تركواز شعار الغدير بدرجة أعمق شوية للتباين.
  static const pharmacyAccent = Color(0xFF0B7F88);
  static const opticsBg = Color(0xFFE9EEFA);
  static const opticsAccent = Color(0xFF3D5A9E);
  static const beautyBg = Color(0xFFF8EAF2);
  static const beautyAccent = Color(0xFFA2487A);

  /// التمريض المنزلي: نفس عائلة الأطباء (هوية طبية) بدرجة أهدأ.
  static const nursingBg = Color(0xFFE4F2F4);
  static const nursingAccent = Color(0xFF0E6F7A);

  /// عناوين الصيدليات.
  static const pharmacyTitle = GhadeerTokens.ink;
}
