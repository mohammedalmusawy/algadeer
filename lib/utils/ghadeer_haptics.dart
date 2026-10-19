import 'dart:async';

import 'package:flutter/services.dart';

/// اهتزازة خفيفة تأكّد للمستخدم إن ضغطته وصلت (Phase 5D):
/// الاتصال، الواتساب، المفضلة. ما تكسر شي إذا الجهاز ما يدعمها
/// أو بالاختبارات (بدون binding).
void ghadeerTapFeedback() {
  try {
    unawaited(HapticFeedback.lightImpact().catchError((_) {}));
  } catch (_) {
    // ماكو binding أو منصة ما تدعمها — نكمل بصمت.
  }
}

/// تأكيد أنعم لتبديل حالة (مثل المفضلة).
void ghadeerToggleFeedback() {
  try {
    unawaited(HapticFeedback.selectionClick().catchError((_) {}));
  } catch (_) {}
}
