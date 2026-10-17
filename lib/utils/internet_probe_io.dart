import 'dart:io';

/// فحص سريع: نحاول نعرف عنوان واتساب. بدون نت يفشل خلال ثواني قليلة.
Future<bool> hasInternet() async {
  try {
    final result = await InternetAddress.lookup('wa.me')
        .timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
