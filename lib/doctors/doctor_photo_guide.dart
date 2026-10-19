import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/ghadeer_tokens.dart';

/// إرشاد صورة الطبيب بالمحرّر (Phase 5C): معاينة بنفس إطار صفحة الطبيب
/// (طولي ومدوّر)، ونصايح قصيرة، وتنبيه إذا الصورة المختارة عرضية
/// (غالباً بوستر أو إعلان — يتقص بالإطار وما تنقرأ كتابته).
class DoctorPhotoGuide extends StatefulWidget {
  const DoctorPhotoGuide({super.key, required this.preview, this.pickedBytes});

  /// الصورة الحالية (رابط أو مختارة) — تنرسم داخل إطار الهوية.
  final Widget preview;

  /// بايتات الصورة المختارة هسه (إن وجدت) — نقرأ أبعادها للتنبيه.
  final Uint8List? pickedBytes;

  @override
  State<DoctorPhotoGuide> createState() => _DoctorPhotoGuideState();
}

class _DoctorPhotoGuideState extends State<DoctorPhotoGuide> {
  bool? _landscape;
  Uint8List? _measured;

  @override
  void didUpdateWidget(covariant DoctorPhotoGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    _measure();
  }

  @override
  void initState() {
    super.initState();
    _measure();
  }

  void _measure() {
    final bytes = widget.pickedBytes;
    if (bytes == null) {
      if (_landscape != null) setState(() => _landscape = null);
      _measured = null;
      return;
    }
    if (identical(bytes, _measured)) return;
    _measured = bytes;
    final stream = MemoryImage(bytes).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      stream.removeListener(listener);
      if (!mounted || !identical(_measured, bytes)) return;
      final w = info.image.width;
      final h = info.image.height;
      setState(() => _landscape = w > h * 1.1);
    }, onError: (_, _) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('doctor_photo_guide'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GhadeerTokens.surface,
        borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
        border: Border.all(color: GhadeerTokens.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // نفس نسبة إطار صفحة الطبيب (طول = عرض × 1.32).
          ClipRRect(
            borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
            child: SizedBox(width: 76, height: 100, child: widget.preview),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'هيچ تطلع الصورة بصفحة الطبيب',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: GhadeerTokens.ink,
                  ),
                ),
                const SizedBox(height: 6),
                for (final tip in const [
                  'صورة شخصية واضحة للوجه',
                  'طولية، والخلفية بسيطة',
                  'مو بوستر أو إعلان بيه كتابة',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 15,
                          color: GhadeerTokens.tealDeep,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: GhadeerTokens.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_landscape == true) ...[
                  const SizedBox(height: 6),
                  Container(
                    key: const Key('doctor_photo_landscape_warning'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: GhadeerTokens.warnWash,
                      borderRadius: BorderRadius.circular(
                        GhadeerTokens.radiusSm,
                      ),
                    ),
                    child: const Text(
                      'هاي الصورة عرضية — راح يتقص جوانبها بالإطار. الأفضل صورة شخصية طولية.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: GhadeerTokens.warn,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
