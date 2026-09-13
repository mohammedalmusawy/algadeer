import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../branding/ghadeer_brand_mark.dart';

/// مشاركة وQR لهوية المختبر — قالب واحد لكل المختبرات.
class LabCardLinks {
  static const String publicWebBase = 'https://ghadeer-clinic.web.app';

  static String forLab(String labId) {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      return '$origin/#/lab/$labId';
    }
    return '$publicWebBase/#/lab/$labId';
  }

  static Future<void> shareLabCard({
    required String labId,
    required String labName,
  }) async {
    final url = forLab(labId);
    await SharePlus.instance.share(
      ShareParams(
        text: 'بطاقة $labName — عيادة الغدير\n$url',
        subject: 'بطاقة $labName',
      ),
    );
  }

  static Future<void> showQrDialog(
    BuildContext context, {
    required String labId,
    required String labName,
    String slogan = '',
    String imageUrl = '',
    bool verified = false,
  }) {
    return showDigitalLabCard(
      context,
      labId: labId,
      labName: labName,
      slogan: slogan,
      imageUrl: imageUrl,
      verified: verified,
    );
  }

  /// بطاقة المختبر الرقمية القابلة للمشاركة.
  static Future<void> showDigitalLabCard(
    BuildContext context, {
    required String labId,
    required String labName,
    String slogan = '',
    String imageUrl = '',
    bool verified = false,
  }) async {
    final url = forLab(labId);
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
                          Icon(
                            Icons.local_hospital_rounded,
                            color: Color(0xFF0FAFA3),
                            size: 18,
                          ),
                          SizedBox(width: 6),
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
                        'البطاقة الرقمية للمختبر',
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
                          height: 112,
                          child: imageUrl.trim().isNotEmpty
                              ? GhadeerResolvedImage(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFFEAF4F3),
                                    child: Icon(
                                      Icons.biotech_rounded,
                                      size: 48,
                                      color: Color(0xFF9BB8B6),
                                    ),
                                  ),
                                )
                              : const ColoredBox(
                                  color: Color(0xFFEAF4F3),
                                  child: Icon(
                                    Icons.biotech_rounded,
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
                              labName,
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
                      if (slogan.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          slogan,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1197A8),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
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
                                shareLabCard(labId: labId, labName: labName);
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

  static Future<void> openMapUrl(String mapUrlOrAddress) async {
    final raw = mapUrlOrAddress.trim();
    if (raw.isEmpty) return;
    Uri uri;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      uri = Uri.parse(raw);
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(raw)}',
      );
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
