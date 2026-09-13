import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../doctors/doctor_profile_page.dart';
import '../labs/lab_card_links.dart';
import '../labs/lab_profile_page.dart';
import '../labs/labs_service.dart';
import '../models/doctor_item.dart';
import '../radiology/radiology_profile_page.dart';
import '../radiology/radiology_service.dart';
import '../services/dynamic_message_service.dart';
import '../voice/voice_response_controller.dart';

/// يفتح صفحة المكان الإعلاني (تخطيط مشابه لهوية الطبيب — صورة كاملة واضحة).
Future<void> showDynamicHighlightDetails(
  BuildContext context,
  DynamicMessage message, {
  Uint8List? previewImageBytes,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return DynamicHighlightDetailPage(
          message: message,
          previewImageBytes: previewImageBytes,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// مكان إعلاني — صورة كاملة + عمود إعلانات جانبي.
class DynamicHighlightDetailPage extends StatefulWidget {
  const DynamicHighlightDetailPage({
    super.key,
    required this.message,
    this.previewImageBytes,
  });

  final DynamicMessage message;
  final Uint8List? previewImageBytes;

  @override
  State<DynamicHighlightDetailPage> createState() =>
      _DynamicHighlightDetailPageState();
}

class _DynamicHighlightDetailPageState
    extends State<DynamicHighlightDetailPage> {
  static const _navy = Color(0xFF123B42);
  static const _actionBlue = Color(0xFF1197A8);
  static const _muted = Color(0xFF5B6C70);
  static const _pageBg = Color(0xFFF7FBFC);

  bool _opening = false;
  bool _speaking = false;
  final _voice = VoiceResponseController();

  DynamicMessage get message => widget.message;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoiceChanged);
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    final speaking = _voice.isSpeaking;
    if (speaking != _speaking) {
      setState(() => _speaking = speaking);
    }
  }

  Future<void> _stopVoice() async {
    await _voice.stop();
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceChanged);
    // إيقاف النطق عند مغادرة الصفحة (رجوع / إغلاق).
    unawaited(_voice.stop());
    _voice.dispose();
    super.dispose();
  }

  double _profileMaxWidthFor(double screenWidth) {
    if (screenWidth >= 1100) return 720;
    if (screenWidth >= 800) return 660;
    if (screenWidth >= 600) return 600;
    return screenWidth;
  }

  Future<void> _openDestination() async {
    if (_opening) return;
    setState(() => _opening = true);
    final nav = Navigator.of(context);
    try {
      final kind = message.destinationKind.trim();
      if (kind == DynamicMessageDestination.url) {
        final uri = Uri.tryParse(message.linkUrl.trim());
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return;
      }

      if (kind == DynamicMessageDestination.doctor) {
        final row = await Supabase.instance.client
            .from('doctors')
            .select()
            .eq('id', message.destinationId)
            .maybeSingle();
        if (!mounted) return;
        if (row == null) {
          _toast('لم يُعثر على الطبيب');
          return;
        }
        final doctor = DoctorItem.fromMap(Map<String, dynamic>.from(row));
        await nav.push(
          MaterialPageRoute(
            builder: (_) => DoctorProfilePage(
              doctor: doctor,
              isFavorite: false,
              onToggleFavorite: () {},
            ),
          ),
        );
        return;
      }

      if (kind == DynamicMessageDestination.lab) {
        final lab = await LabsService().fetchLabById(message.destinationId);
        if (!mounted) return;
        if (lab == null) {
          _toast('لم يُعثر على المختبر');
          return;
        }
        await nav.push(
          MaterialPageRoute(builder: (_) => LabProfilePage(lab: lab)),
        );
        return;
      }

      if (kind == DynamicMessageDestination.radiology) {
        final center =
            await RadiologyService().fetchCenterById(message.destinationId);
        if (!mounted) return;
        if (center == null) {
          _toast('لم يُعثر على مركز الأشعة');
          return;
        }
        await nav.push(
          MaterialPageRoute(
            builder: (_) => RadiologyProfilePage(center: center),
          ),
        );
      }
    } catch (e) {
      if (mounted) _toast('تعذر الفتح: $e');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _speakAd() async {
    // ضغطة ثانية = إيقاف.
    if (_speaking || _voice.isSpeaking) {
      await _stopVoice();
      return;
    }
    final text = [
      if (message.title.trim().isNotEmpty) message.title.trim(),
      if (message.body.trim().isNotEmpty) message.body.trim(),
    ].join('. ');
    if (text.trim().isEmpty) {
      _toast('لا يوجد نص للقراءة');
      return;
    }
    setState(() => _speaking = true);
    try {
      await _voice.speak(text);
    } catch (e) {
      if (mounted) _toast('تعذر تشغيل الصوت');
    } finally {
      if (mounted) setState(() => _speaking = _voice.isSpeaking);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final maxW = _profileMaxWidthFor(screenW);
    final cta = DynamicMessageDestination.ctaLabelAr(message.destinationKind);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          // أي رجوع (زر النظام / إيماءة) يوقف الصوت.
          unawaited(_stopVoice());
        },
        child: Scaffold(
        backgroundColor: _pageBg,
        body: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildAdHero()),
                      if (message.hasActionableDestination && cta.isNotEmpty)
                        SliverToBoxAdapter(child: _buildActionRow(cta)),
                      SliverToBoxAdapter(child: _buildDetails()),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    ],
                  ),
                ),
              ),
            ),
            if (message.hasActionableDestination && cta.isNotEmpty)
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: _buildBottomBar(cta),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _circleIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8EEF2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: iconColor ?? _navy),
        ),
      ),
    );
  }

  /// Hero إعلاني: صورة كاملة يمينًا + عمود إعلانات يسارًا.
  Widget _buildAdHero() {
    final title = message.title.trim().isEmpty
        ? 'إعلان الغدير'
        : message.title.trim();
    final badge = message.badge.trim().isEmpty
        ? 'إعلان الغدير'
        : message.badge.trim();
    final phrases = message.highlightPhrases;
    final address = message.address.trim();
    final canOpenMap = message.mapLaunchTarget.isNotEmpty;
    final cta = DynamicMessageDestination.ctaLabelAr(message.destinationKind);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardW = constraints.maxWidth;
            final narrow = cardW < 400;
            final heroH = (cardW * (narrow ? 1.08 : 0.96)).clamp(420.0, 560.0);
            final imageW = cardW * (narrow ? 0.56 : 0.54);
            final leftColW =
                (cardW * (narrow ? 0.50 : 0.46)).clamp(168.0, 220.0);

            return SizedBox(
              width: cardW,
              height: heroH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const _IceHeroBackground(),
                      Positioned(
                        top: 10,
                        bottom: 10,
                        right: 8,
                        width: imageW - 8,
                        child: _FullClearAdImage(
                          networkUrl: message.imageUrl,
                          previewBytes: widget.previewImageBytes,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        bottom: 10,
                        width: leftColW,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  _circleIconBtn(
                                    icon: Icons.chevron_right_rounded,
                                    onTap: () async {
                                      await _stopVoice();
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                                  const Spacer(),
                                  _circleIconBtn(
                                    icon: _speaking
                                        ? Icons.volume_up_rounded
                                        : Icons.record_voice_over_outlined,
                                    iconColor: _actionBlue,
                                    onTap: _speakAd,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _BadgePill(label: badge),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 17,
                                  height: 1.25,
                                  fontWeight: FontWeight.w900,
                                  color: _navy,
                                ),
                              ),
                              if (phrases.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (final phrase in phrases) ...[
                                          _AdPhraseLine(text: phrase),
                                          const SizedBox(height: 6),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ] else
                                const Spacer(),
                              if (message.hasLocation) ...[
                                const SizedBox(height: 6),
                                Material(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: canOpenMap
                                        ? () => LabCardLinks.openMapUrl(
                                              message.mapLaunchTarget,
                                            )
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        8,
                                        8,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_rounded,
                                            color: _actionBlue,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              address.isNotEmpty
                                                  ? address
                                                  : 'فتح الموقع على الخرائط',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                height: 1.3,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF33454F),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (message.hasActionableDestination &&
                                  cta.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Material(
                                  color: const Color(0xFFE8F7F5),
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _opening ? null : _openDestination,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 9,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cta,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w900,
                                                color: _actionBlue,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_left_rounded,
                                            size: 18,
                                            color: _actionBlue,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionRow(String cta) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _opening ? null : _openDestination,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4EEEE)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: _actionBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cta,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'وجهة الإعلان · ${DynamicMessageDestination.labelAr(message.destinationKind)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_opening)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_left_rounded, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    final body = message.body.trim();
    final address = message.address.trim();
    final canOpenMap = message.mapLaunchTarget.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'التفاصيل الإعلانية',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _navy,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body.isNotEmpty ? body : 'لم تتم إضافة نص إعلاني حتى الآن.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.85,
              fontWeight: FontWeight.w500,
              color: body.isNotEmpty ? const Color(0xFF33454F) : _muted,
            ),
          ),
          if (message.hasLocation) ...[
            const SizedBox(height: 22),
            const Text(
              'العنوان',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _navy,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: canOpenMap
                    ? () => LabCardLinks.openMapUrl(message.mapLaunchTarget)
                    : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4EEEE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _actionBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address.isNotEmpty
                                  ? address
                                  : 'اضغط لفتح الموقع على الخرائط',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.55,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF33454F),
                              ),
                            ),
                            if (canOpenMap) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'فتح في تطبيق الخرائط',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: _actionBlue,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canOpenMap)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: _muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(String cta) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: FilledButton(
            onPressed: _opening ? null : _openDestination,
            style: FilledButton.styleFrom(
              backgroundColor: _actionBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _opening
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    cta,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AdPhraseLine extends StatelessWidget {
  const _AdPhraseLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 12,
            color: Color(0xFF1197A8),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.4,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: Color(0xFF445A5E),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E6EE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.campaign_rounded, size: 15, color: Color(0xFF1197A8)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF123B42),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IceHeroBackground extends StatelessWidget {
  const _IceHeroBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFEAF4F6),
            Color(0xFFE5F1F4),
            Color(0xFFF5FBFC),
          ],
        ),
      ),
    );
  }
}

/// صورة إعلانية كاملة وواضحة — بدون قصّ (contain).
class _FullClearAdImage extends StatelessWidget {
  const _FullClearAdImage({
    required this.networkUrl,
    this.previewBytes,
  });

  final String networkUrl;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F9FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0ECEC)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: const Color(0xFFF7FBFC),
          child: Center(child: _buildImage()),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      return Image.memory(
        previewBytes!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      );
    }
    final url = networkUrl.trim();
    if (url.isEmpty) return const _AdImageFallback();
    if (GhadeerBranding.isAssetPath(url)) {
      return Image.asset(
        url,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const _AdImageFallback(),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Color(0xFF0FAFA3),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => const _AdImageFallback(),
    );
  }
}

class _AdImageFallback extends StatelessWidget {
  const _AdImageFallback();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Image.asset(
        GhadeerBranding.officialLogoAsset,
        width: 88,
        height: 88,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.campaign_rounded,
          size: 64,
          color: Color(0xFF9BB8B6),
        ),
      ),
    );
  }
}
