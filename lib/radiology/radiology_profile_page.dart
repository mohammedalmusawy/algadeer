import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../models/radiology_models.dart';
import '../utils/contact_launch.dart';
import 'radiology_default_images.dart';
import 'radiology_service.dart';
import 'widgets/radiology_network_or_asset_image.dart';

/// هوية مركز الأشعة — نفس هيكل هوية المختبر مع تمييز الأشعة.
class RadiologyProfilePage extends StatefulWidget {
  const RadiologyProfilePage({super.key, required this.center});

  final RadiologyCenter center;

  @override
  State<RadiologyProfilePage> createState() => _RadiologyProfilePageState();
}

class _RadiologyProfilePageState extends State<RadiologyProfilePage> {
  final _service = RadiologyService();
  late RadiologyCenter _center;
  bool _loading = true;
  String? _error;
  bool _favorite = false;

  static const _navy = Color(0xFF123B42);
  static const _teal = Color(0xFF0FAFA3);
  static const _actionBlue = Color(0xFF1197A8);
  static const _muted = Color(0xFF5B6C70);
  static const _pageBg = Color(0xFFF7FBFC);
  static const _favKey = 'favoriteRadiologyIds';

  @override
  void initState() {
    super.initState();
    _center = widget.center;
    _loadFavorite();
    _load();
  }

  Future<void> _loadFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_favKey) ?? const [];
    if (!mounted) return;
    setState(() => _favorite = ids.contains(_center.id));
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = [...(prefs.getStringList(_favKey) ?? const <String>[])];
    if (_favorite) {
      ids.remove(_center.id);
    } else if (!ids.contains(_center.id)) {
      ids.add(_center.id);
    }
    await prefs.setStringList(_favKey, ids);
    if (!mounted) return;
    setState(() => _favorite = !_favorite);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fresh = await _service.fetchCenterById(_center.id);
      if (!mounted) return;
      setState(() {
        if (fresh != null) _center = fresh;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل هوية الأشعة';
      });
    }
  }

  String get _heroImageUrl => RadiologyDefaultImages.displayUrl(
        imageUrl: _center.imageUrl,
        centerId: _center.id,
      );

  String get _heroSpecialty {
    final slogan = _center.slogan.trim();
    if (slogan.isNotEmpty) return slogan;
    return 'مركز أشعة تشخيصية';
  }

  String get _heroBioSnippet {
    final raw = _center.description.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isEmpty) return '';
    final words = raw.split(' ');
    const maxWords = 14;
    if (words.length <= maxWords) return raw;
    return '${words.take(maxWords).join(' ')}…';
  }

  Future<void> _openLocation() async {
    final map = _center.mapUrl.trim();
    final address = _center.address.trim();
    final target = map.isNotEmpty ? map : address;
    if (target.isEmpty) return;
    final uri = Uri.tryParse(target) ??
        Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(target)}',
        );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  Widget _buildHero() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardW = constraints.maxWidth;
            final narrow = cardW < 400;
            final heroH = (cardW * (narrow ? 1.02 : 0.90)).clamp(390.0, 520.0);
            final imageW = cardW * (narrow ? 0.66 : 0.60);
            final leftColW =
                (cardW * (narrow ? 0.52 : 0.48)).clamp(168.0, 220.0);

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
                      const _RadHeroDepthBackground(),
                      Positioned(
                        top: 0,
                        bottom: -12,
                        right: -6,
                        width: imageW,
                        child: _RadHeroImage(imageUrl: _heroImageUrl),
                      ),
                      Positioned(
                        top: 10,
                        left: 12,
                        bottom: 12,
                        width: leftColW,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _circleIconBtn(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: () => Navigator.pop(context),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: _RadVerifiedPill(),
                              ),
                              const SizedBox(height: 8),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: GhadeerBrandHeaderRow(),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'التشخيص قبل كل شئ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A4F58),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _center.name.trim().isEmpty
                                    ? 'مركز أشعة'
                                    : _center.name.trim(),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 19,
                                  height: 1.22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F2A3D),
                                ),
                              ),
                              const SizedBox(height: 6),
                              GhadeerTextWithLogo(
                                _heroSpecialty,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                                textDirection: TextDirection.rtl,
                                logoHeight: 20,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0D8F9E),
                                ),
                              ),
                              if (_heroBioSnippet.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                GhadeerTextWithLogo(
                                  _heroBioSnippet,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                  textDirection: TextDirection.rtl,
                                  logoHeight: 18,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF5B6C70),
                                  ),
                                ),
                              ],
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _circleIconBtn(
                          icon: Icons.ios_share_rounded,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'المشاركة ستُفعَّل بالكامل بعد ربط الموقع',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 10 + 38 + 8,
                        right: 10,
                        child: _circleIconBtn(
                          icon: _favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          iconColor: _favorite
                              ? const Color(0xFFE25555)
                              : _navy,
                          onTap: _toggleFavorite,
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

  Widget _buildIdentity() {
    final bio = _center.description.trim();
    final location = _center.address.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'نبذة عن المركز',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _navy,
            ),
          ),
          const SizedBox(height: 10),
          bio.isNotEmpty
              ? GhadeerTextWithLogo(
                  bio,
                  textAlign: TextAlign.right,
                  logoHeight: 24,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.85,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF33454F),
                  ),
                )
              : Text(
                  'لم تتم إضافة نبذة عن المركز حتى الآن.',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.85,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'عنوان المركز',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _navy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              location,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.7,
                fontWeight: FontWeight.w500,
                color: Color(0xFF33454F),
              ),
            ),
          ],
          if (_center.workingHours.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'ساعات العمل: ${_center.workingHours.trim()}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A4F58),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    final buttons = <Widget>[];
    if (_center.phone.trim().isNotEmpty) {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => launchClinicCall(_center.phone),
            style: FilledButton.styleFrom(backgroundColor: _actionBlue),
            icon: const Icon(Icons.phone_in_talk_rounded),
            label: const Text('اتصال'),
          ),
        ),
      );
    }
    if (_center.whatsapp.trim().isNotEmpty) {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => launchClinicWhatsApp(_center.whatsapp),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
            ),
            icon: const Icon(Icons.chat_rounded),
            label: const Text('واتساب'),
          ),
        ),
      );
    }
    if (_center.address.trim().isNotEmpty ||
        _center.mapUrl.trim().isNotEmpty) {
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openLocation,
            icon: const Icon(Icons.near_me_rounded),
            label: const Text('الموقع'),
          ),
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            buttons[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('إعادة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: _teal,
                    onRefresh: _load,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverToBoxAdapter(child: _buildHero()),
                        SliverToBoxAdapter(child: _buildIdentity()),
                        SliverToBoxAdapter(child: _buildActions()),
                        const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _RadVerifiedPill extends StatelessWidget {
  const _RadVerifiedPill();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 186),
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD7E6EE)),
        ),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 15, color: Color(0xFF1A73E8)),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  'أشعة في منصة الغدير',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF123B42),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadHeroDepthBackground extends StatelessWidget {
  const _RadHeroDepthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
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
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: const ColoredBox(color: Color(0x33FFFFFF)),
          ),
        ),
      ],
    );
  }
}

class _RadHeroImage extends StatelessWidget {
  const _RadHeroImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final photo = imageUrl.trim().isNotEmpty
        ? RadiologyNetworkOrAssetImage(
            imageUrl,
            fit: BoxFit.cover,
            alignment: const Alignment(0.1, -0.15),
            cacheWidth: 1200,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFFEAF4F6),
              child: Icon(Icons.radar_outlined, size: 72, color: Color(0xFF9BB8B6)),
            ),
          )
        : const ColoredBox(
            color: Color(0xFFEAF4F6),
            child: Icon(Icons.radar_outlined, size: 72, color: Color(0xFF9BB8B6)),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        photo,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xEAEAF4F6),
                Color(0x66EAF4F6),
                Color(0x22FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0.0, 0.12, 0.34, 0.58],
            ),
          ),
        ),
      ],
    );
  }
}
