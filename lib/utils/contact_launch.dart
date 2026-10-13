import 'package:url_launcher/url_launcher.dart';

/// أرقام و+ فقط: الأرقام المحفوظة قد تحمل رموز اتجاه مخفية (U+202D/U+202C)
/// تُفسد رابط الاتصال على بعض الهواتف.
Uri clinicTelUri(String phone) =>
    Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');

/// رقم واتساب بالعراق: 07xxxxxxxx → 9647xxxxxxxx. فارغ إن لا أرقام.
String clinicWhatsAppDigits(String whatsapp) {
  var number = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
  if (number.startsWith('0')) {
    number = '964${number.substring(1)}';
  }
  return number;
}

Uri? clinicWhatsAppUri(String whatsapp, {String message = ''}) {
  final number = clinicWhatsAppDigits(whatsapp);
  if (number.isEmpty) return null;
  final text = message.trim();
  if (text.isEmpty) return Uri.parse('https://wa.me/$number');
  return Uri.parse(
    'https://wa.me/$number?text=${Uri.encodeComponent(text)}',
  );
}

/// رابط خرائط: http(s) كما هو، وإلا بحث عنوان على خرائط غوغل.
Uri clinicMapUri(String mapUrlOrAddress) {
  final raw = mapUrlOrAddress.trim();
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return Uri.parse(raw);
  }
  return Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(raw)}',
  );
}

bool isExternalHttpUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}

Future<void> launchClinicCall(String phone) async {
  if (phone.trim().isEmpty) return;
  await launchUrl(clinicTelUri(phone));
}

/// يفتح الروابط الخارجية http/https فقط — بدون تغيير سلوك الروابط الصحيحة.
Future<bool> launchExternalHttpUrl(String raw) async {
  if (!isExternalHttpUrl(raw)) return false;
  return launchUrl(
    Uri.parse(raw.trim()),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> launchClinicWhatsApp(
  String whatsapp, {
  String message = '',
}) async {
  final uri = clinicWhatsAppUri(whatsapp, message: message);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> launchClinicMap(String mapUrlOrAddress) async {
  final raw = mapUrlOrAddress.trim();
  if (raw.isEmpty) return;
  await launchUrl(clinicMapUri(raw), mode: LaunchMode.externalApplication);
}
