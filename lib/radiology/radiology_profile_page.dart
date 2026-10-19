import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../models/radiology_models.dart';
import '../utils/contact_launch.dart';
import '../widgets/entity_contact_actions.dart';
import '../theme/ghadeer_tokens.dart';
import '../widgets/entity_optional_logo.dart';
import '../widgets/ghadeer_identity_card.dart';
import 'radiology_default_images.dart';
import 'radiology_service.dart';
import 'widgets/radiology_network_or_asset_image.dart';
import '../utils/ghadeer_card_link.dart';
import '../doctors/doctor_card_gate.dart';
import '../widgets/directory_owner_editor_page.dart';
import '../widgets/owner_access_link.dart';
import '../services/favorites_cloud.dart';
import '../settings/whatsapp_templates.dart';
import '../settings/whatsapp_contact_flow.dart';

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

  static const _navy = GhadeerTokens.ink;
  static const _teal = GhadeerTokens.teal;
  static const _muted = GhadeerTokens.inkMuted;
  static const _pageBg = GhadeerTokens.mist;
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
    await FavoritesCloud.instance.push(_favKey, ids);
    if (!mounted) return;
    setState(() => _favorite = !_favorite);
  }

  /// قفل صاحب المركز (3 نقرات): يعدّل حقوله فقط عبر Edge Function.
  Future<void> _openOwner() async {
    final session = await showEntityOwnerSession(
      context,
      entityType: 'radiology',
      entityId: _center.id,
      title: _center.name,
    );
    if (session == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DirectoryOwnerEditorPage(
          session: session,
          card: OwnerCardData(
            id: _center.id,
            name: _center.name,
            contentRevision: _center.contentRevision,
            logoFolder: 'radiology',
            bio: _center.description,
            supportsServices: false,
            hours: _center.workingHours,
            phone: _center.phone,
            whatsapp: _center.whatsapp,
            address: _center.address,
            mapUrl: _center.mapUrl,
            logoUrl: _center.logoUrl,
          ),
        ),
      ),
    );
    if (saved == true && mounted) await _load();
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
    await launchClinicMap(target);
  }

  void _share() => GhadeerCardLink.share(
    kind: GhadeerCardKind.radiology,
    id: _center.id,
    name: _center.name,
    subtitle: [
      'مركز أشعة',
      if (_center.address.trim().isNotEmpty) _center.address.trim(),
    ].join(' · '),
  );

  Widget _buildHero() {
    final hours = _center.workingHours.trim();
    final hasImage = _heroImageUrl.trim().isNotEmpty;
    return GhadeerIdentityCard(
      photo: _RadHeroImage(imageUrl: _heroImageUrl),
      onPhotoTap: hasImage
          ? () => showGhadeerPhotoViewer(
              context,
              RadiologyNetworkOrAssetImage(
                _heroImageUrl,
                fit: BoxFit.contain,
                cacheWidth: 1400,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            )
          : null,
      name: _center.name.trim().isEmpty ? 'مركز أشعة' : _center.name.trim(),
      subtitle: _heroSpecialty,
      subtitleWidget: GhadeerTextWithLogo(
        _heroSpecialty,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        textDirection: TextDirection.rtl,
        logoHeight: 20,
        style: const TextStyle(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: GhadeerTokens.tealDeep,
        ),
      ),
      snippet: _heroBioSnippet,
      logo: _center.logoUrl.trim().isNotEmpty
          ? EntityOptionalLogo(url: _center.logoUrl)
          : null,
      favorite: _favorite,
      onToggleFavorite: _toggleFavorite,
      onShare: _share,
      onBack: () => Navigator.pop(context),
      ownerAccess: OwnerAccess.faint(onTap: _openOwner),
      below: hours.isEmpty
          ? null
          : GhadeerIdentityInfoBox(
              icon: Icons.schedule_rounded,
              label: 'ساعات العمل',
              text: hours,
            ),
    );
  }

  Widget _buildIdentity() {
    final bio = _center.description.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: GhadeerTokens.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('نبذة عن المركز', style: GhadeerTokens.heading),
            const SizedBox(height: 10),
            bio.isNotEmpty
                ? GhadeerTextWithLogo(
                    bio,
                    textAlign: TextAlign.right,
                    logoHeight: 24,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.8,
                      fontWeight: FontWeight.w400,
                      color: _navy,
                    ),
                  )
                : const Text(
                    'لم تتم إضافة نبذة عن المركز حتى الآن.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.8,
                      color: _muted,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    // مباشرة تحت بطاقة الهوية — قبل النبذة الطويلة حتى ما تنزل لتحت.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: EntityContactActionsRow(
        phone: _center.phone,
        whatsapp: _center.whatsapp,
        social: _center.social,
        socialTitle: 'مواقع تواصل ${_center.name}',
        onCall: () => launchClinicCall(_center.phone),
        onWhatsapp: () async {
          await WhatsAppContactFlow.open(
            context,
            whatsapp: _center.whatsapp,
            section: WhatsAppSection.radiology,
            providerTitle: _center.name,
          );
        },
        onLocation: _openLocation,
        showLocation:
            _center.address.trim().isNotEmpty ||
            _center.mapUrl.trim().isNotEmpty,
      ),
    );
  }

  Widget _buildAddressAndHours() {
    final location = _center.address.trim();
    if (location.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: GhadeerTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
          side: const BorderSide(color: GhadeerTokens.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
          onTap: _openLocation,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: GhadeerTokens.tealWash,
                    borderRadius: BorderRadius.circular(GhadeerTokens.radiusSm),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: GhadeerTokens.tealDeep,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('عنوان المركز', style: GhadeerTokens.caption),
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: GhadeerTokens.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'الخريطة',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: GhadeerTokens.tealDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                    // الأزرار فوق — مباشرة تحت البطاقة، قبل النبذة الطويلة.
                    SliverToBoxAdapter(child: _buildActions()),
                    SliverToBoxAdapter(child: _buildIdentity()),
                    SliverToBoxAdapter(child: _buildAddressAndHours()),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],
                ),
              ),
      ),
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
              child: Icon(
                Icons.radar_outlined,
                size: 72,
                color: Color(0xFF9BB8B6),
              ),
            ),
          )
        : const ColoredBox(
            color: Color(0xFFEAF4F6),
            child: Icon(
              Icons.radar_outlined,
              size: 72,
              color: Color(0xFF9BB8B6),
            ),
          );

    return photo;
  }
}
