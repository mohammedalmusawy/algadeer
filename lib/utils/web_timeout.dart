import 'package:flutter/foundation.dart' show kIsWeb;

/// الويب: طلب الشبكة ما ينتظر للأبد على نت ضعيف (يرمي TimeoutException
/// وصاحب الطلب يرجع للمحفوظ). على الموبايل يرجع الطلب نفسه بدون تغيير.
Future<T> webTimed<T>(
  Future<T> request, {
  bool isWeb = kIsWeb,
  Duration limit = const Duration(seconds: 8),
}) => isWeb ? request.timeout(limit) : request;
