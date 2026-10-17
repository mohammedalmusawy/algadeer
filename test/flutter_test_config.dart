import 'dart:async';

import 'package:ghadeer_clinic/utils/contact_launch.dart';
import 'package:ghadeer_clinic/widgets/ghadeer_net_image.dart';

/// إعداد عام لكل الاختبارات:
/// - الصور بدون حفظ على القرص (مكتبة الحفظ تحتاج ملفات النظام).
/// - فحص النت قبل واتساب يعتبر النت موجود، إلا إذا الاختبار بدّله.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GhadeerNetImage.diskCache = false;
  whatsappInternetCheck = () async => true;
  await testMain();
}
