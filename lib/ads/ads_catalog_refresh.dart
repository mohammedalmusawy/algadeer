import 'package:flutter/foundation.dart';

/// إشارة خفيفة لإعادة جلب الإعلان على الصفحات المفتوحة بعد تعديل الإدارة.
class AdsCatalogRefresh {
  AdsCatalogRefresh._();

  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void bump() {
    tick.value = tick.value + 1;
  }
}
