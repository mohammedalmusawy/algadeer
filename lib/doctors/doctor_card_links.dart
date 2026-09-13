import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../branding/ghadeer_brand_mark.dart';

/// رابط البطاقة الرقمية — يعمل على الويب إن وُجد، ويفتح التطبيق إن كان منزّلًا.
class DoctorCardLinks {
  /// غيّر هذا عند نشر موقع/استضافة Flutter Web النهائية.
  static const String publicWebBase = 'https://ghadeer-clinic.web.app';

  static String forDoctor(String doctorId) {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      return '$origin/#/doctor/$doctorId';
    }
    return '$publicWebBase/#/doctor/$doctorId';
  }

  static String? parseDoctorId(Uri uri) {
    // ghadeerclinic://doctor/{id}
    if (uri.host == 'doctor' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'doctor') {
      return uri.pathSegments[1];
    }
    final frag = uri.fragment; // /doctor/uuid
    if (frag.startsWith('/doctor/')) {
      return frag.substring('/doctor/'.length).split('?').first;
    }
    if (frag.startsWith('doctor/')) {
      return frag.substring('doctor/'.length).split('?').first;
    }
    return uri.queryParameters['doctor'];
  }

  static Future<void> shareDoctorCard({
    required String doctorId,
    required String doctorName,
  }) async {
    final url = forDoctor(doctorId);
    await SharePlus.instance.share(
      ShareParams(
        text:
            'بطاقة $doctorName الرقمية — عيادة الغدير\n$url\n\nإن لم يكن التطبيق منزّلًا ستفتح البطاقة عبر الموقع مع اقتراح التحميل.',
        subject: 'بطاقة $doctorName',
      ),
    );
  }

  static Future<void> showQrDialog(
    BuildContext context, {
    required String doctorId,
    required String doctorName,
    String specialty = '',
    String imageUrl = '',
    bool verified = false,
  }) {
    return showDigitalDoctorCard(
      context,
      doctorId: doctorId,
      doctorName: doctorName,
      specialty: specialty,
      imageUrl: imageUrl,
      verified: verified,
    );
  }

  /// بطاقة الطبيب الرقمية القابلة للمشاركة — QR + هوية الغدير.
  static Future<void> showDigitalDoctorCard(
    BuildContext context, {
    required String doctorId,
    required String doctorName,
    String specialty = '',
    String imageUrl = '',
    bool verified = false,
  }) async {
    final url = forDoctor(doctorId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9E4E6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GhadeerBrandMark(size: 28, backgroundColor: null),
                          SizedBox(width: 8),
                          Text(
                            'عيادة الغدير',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: Color(0xFF123B42),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'البطاقة الرقمية للطبيب',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A8B90),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: 112,
                          height: 132,
                          child: imageUrl.trim().isNotEmpty
                              ? GhadeerResolvedImage(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFFEAF4F3),
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 48,
                                      color: Color(0xFF9BB8B6),
                                    ),
                                  ),
                                )
                              : const ColoredBox(
                                  color: Color(0xFFEAF4F3),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 48,
                                    color: Color(0xFF9BB8B6),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              doctorName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F2A3D),
                              ),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: Color(0xFF1A73E8),
                            ),
                          ],
                        ],
                      ),
                      if (specialty.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          specialty,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1197A8),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE4EEF0)),
                        ),
                        child: QrImageView(
                          data: url,
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        url,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF65747C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'امسح الرمز لفتح بطاقة الطبيب في التطبيق أو الموقع.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF65747C),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: url),
                                );
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ الرابط'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.link_rounded),
                              label: const Text('نسخ الرابط'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                shareDoctorCard(
                                  doctorId: doctorId,
                                  doctorName: doctorName,
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0E8F9A),
                              ),
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('مشاركة'),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> openInstallSuggestion(BuildContext context) async {
    // روابط المتاجر — حدّثها عند النشر
    const playStore =
        'https://play.google.com/store/apps/details?id=com.example.ghadeer_clinic';
    const appStore = 'https://apps.apple.com/app/id000000000';
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'للحجز والمتابعة بشكل أفضل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'نزّل تطبيق عيادة الغدير لفتح البطاقة داخل التطبيق وتلقي الإشعارات.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => launchUrl(
                    Uri.parse(playStore),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('تحميل لأندرويد'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => launchUrl(
                    Uri.parse(appStore),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('تحميل لـ iPhone'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
