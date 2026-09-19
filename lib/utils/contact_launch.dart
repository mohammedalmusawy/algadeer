import 'package:url_launcher/url_launcher.dart';

Future<void> launchClinicCall(String phone) async {
  if (phone.trim().isEmpty) return;
  await launchUrl(Uri.parse('tel:${phone.trim()}'));
}

/// يفتح الروابط الخارجية http/https فقط — بدون تغيير سلوك الروابط الصحيحة.
Future<bool> launchExternalHttpUrl(String raw) async {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> launchClinicWhatsApp(
  String whatsapp, {
  String message = '',
}) async {
  String number = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
  if (number.startsWith('0')) {
    number = '964${number.substring(1)}';
  }
  if (number.isEmpty) return;

  final text = message.trim();
  final uri = text.isEmpty
      ? Uri.parse('https://wa.me/$number')
      : Uri.parse(
          'https://wa.me/$number?text=${Uri.encodeComponent(text)}',
        );

  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
