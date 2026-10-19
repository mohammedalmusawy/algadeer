import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../models/lab_models.dart';
import '../utils/contact_launch.dart';
import '../services/app_stats_service.dart';
import '../voice/lab_packages_speech.dart';
import '../voice/voice_response_controller.dart';
import '../doctors/doctor_card_gate.dart';
import '../doctors/doctor_card_tap.dart';
import '../widgets/entity_contact_actions.dart';
import '../theme/ghadeer_tokens.dart';
import '../widgets/entity_optional_logo.dart';
import '../widgets/ghadeer_identity_card.dart';
import 'lab_owner_editor_page.dart';
import 'lab_card_links.dart';
import 'lab_default_images.dart';
import 'lab_package_detail_page.dart';
import 'lab_packages_page.dart';
import 'lab_pick_analyses_sheet.dart';
import 'labs_service.dart';
import 'widgets/lab_network_or_asset_image.dart';
import 'widgets/lab_package_strip.dart';
import '../widgets/owner_access_link.dart';
import '../services/favorites_cloud.dart';
import '../settings/whatsapp_templates.dart';
import '../settings/whatsapp_contact_flow.dart';

/// بطاقة المختبر الرقمية — قالب Premium واحد لكل المختبرات من Supabase.
class LabProfilePage extends StatefulWidget {
  const LabProfilePage({super.key, required this.lab});

  final LabItem lab;

  @override
  State<LabProfilePage> createState() => _LabProfilePageState();
}

class _LabProfilePageState extends State<LabProfilePage> {
  final _service = LabsService();
  final _stats = AppStatsService();
  final _analysisSearch = TextEditingController();
  final _voice = VoiceResponseController();

  late LabItem _lab;
  List<LabPackageItem> _packages = [];
  List<AnalysisItem> _labAnalyses = [];
  List<AnalysisItem> _filteredAnalyses = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  bool _favorite = false;
  bool _viewRecorded = false;
  bool _packagesSpeechBusy = false;

  static const _navy = GhadeerTokens.ink;
  static const _ink = GhadeerTokens.ink;
  static const _teal = GhadeerTokens.teal;
  static const _actionBlue = GhadeerTokens.tealDeep;
  static const _muted = GhadeerTokens.inkMuted;
  static const _line = GhadeerTokens.line;
  static const _pageBg = GhadeerTokens.mist;
  static const _favKey = 'favoriteLabIds';

  @override
  void initState() {
    super.initState();
    _lab = widget.lab;
    _loadFavorite();
    _load();
    _recordProfileView();
  }

  Future<void> _recordProfileView() async {
    if (_viewRecorded || _lab.id.isEmpty) return;
    _viewRecorded = true;
    await _stats.recordLabProfileView(_lab.id);
  }

  @override
  void dispose() {
    unawaited(_voice.stop());
    _voice.dispose();
    _analysisSearch.dispose();
    super.dispose();
  }

  Future<void> _stopSpeechAndPop() async {
    await _voice.stop();
    if (!mounted) return;
    Navigator.pop(context);
  }

  String _packagesSpeechFor(
    List<LabPackageItem> packages, {
    bool offersOnly = false,
  }) {
    return LabPackagesSpeech.build(
      labName: _lab.name,
      packages: packages,
      offersOnly: offersOnly,
    );
  }

  Future<void> _togglePackagesSpeech({
    required List<LabPackageItem> packages,
    bool offersOnly = false,
  }) async {
    if (_voice.isSpeaking || _packagesSpeechBusy) {
      await _voice.stop();
      _packagesSpeechBusy = false;
      return;
    }
    final text = _packagesSpeechFor(packages, offersOnly: offersOnly);
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            offersOnly
                ? 'لا توجد عروض للقراءة حالياً.'
                : 'لا توجد باقات للقراءة حالياً.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _packagesSpeechBusy = true;
    try {
      await _voice.speak(text);
    } finally {
      _packagesSpeechBusy = false;
    }
  }

  Widget _packagesSpeakButton({
    required List<LabPackageItem> packages,
    bool offersOnly = false,
  }) {
    return AnimatedBuilder(
      animation: _voice,
      builder: (context, _) {
        final speaking = _voice.isSpeaking;
        final canSpeak = packages.isNotEmpty;
        return Material(
          color: speaking ? const Color(0xFFE6F8F6) : Colors.white,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: canSpeak
                ? () => unawaited(
                    _togglePackagesSpeech(
                      packages: packages,
                      offersOnly: offersOnly,
                    ),
                  )
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: ShapeDecoration(
                shape: StadiumBorder(
                  side: BorderSide(
                    color: canSpeak
                        ? _actionBlue.withValues(alpha: 0.35)
                        : const Color(0xFFE8EEF2),
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: 18,
                    color: canSpeak ? _actionBlue : _muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    speaking
                        ? 'إيقاف'
                        : (offersOnly ? 'اسمع العروض' : 'اسمع الباقات'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: canSpeak ? _navy : _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_favKey) ?? const [];
    if (!mounted) return;
    setState(() => _favorite = ids.contains(_lab.id));
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = [...(prefs.getStringList(_favKey) ?? const <String>[])];
    if (_favorite) {
      ids.remove(_lab.id);
    } else if (!ids.contains(_lab.id)) {
      ids.add(_lab.id);
    }
    await prefs.setStringList(_favKey, ids);
    await FavoritesCloud.instance.push(_favKey, ids);
    if (!mounted) return;
    setState(() => _favorite = !_favorite);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var lab = _lab;
      try {
        final fresh = await _service.fetchLabById(_lab.id);
        if (fresh != null) lab = fresh;
      } catch (_) {}

      final packages = await _service.fetchPublicPackages(lab.id);
      final analyses = _collectAnalysesFromPackages(packages);

      if (!mounted) return;
      setState(() {
        _lab = lab;
        _packages = packages;
        _labAnalyses = analyses;
        _filteredAnalyses = analyses;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل هوية المختبر';
      });
    }
  }

  List<AnalysisItem> _collectAnalysesFromPackages(
    List<LabPackageItem> packages,
  ) {
    final map = <String, AnalysisItem>{};
    for (final pkg in packages) {
      for (final a in pkg.analyses) {
        final key = a.id.isNotEmpty ? a.id : a.name.toLowerCase();
        map.putIfAbsent(key, () => a);
      }
      for (final name in pkg.testNames) {
        final key = name.toLowerCase();
        map.putIfAbsent(key, () => AnalysisItem.fromName(name));
      }
    }
    final list = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// باقات الصفحة الرئيسية: كل ما عليه show_on_home أو is_featured،
  /// وإن ماكو تعيين نعرض كل الباقات مرتّبة (قدر المكان).
  List<LabPackageItem> get _homePackages {
    if (_packages.isEmpty) return const [];
    final flagged =
        _packages.where((p) => p.isFeatured || p.showOnHome).toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    if (flagged.isNotEmpty) return flagged;
    final ordered = [..._packages]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return ordered;
  }

  List<LabPackageItem> get _offerPackages =>
      _packages.where((p) => p.discountPercent != null).toList();

  void _filterAnalyses(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _filteredAnalyses = _labAnalyses);
      return;
    }
    setState(() {
      _filteredAnalyses = rankAnalysisMatches(_labAnalyses, q, limit: 40);
    });
  }

  void _openPackage(LabPackageItem pkg) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabPackageDetailPage(
          packageId: pkg.id,
          labName: _lab.name,
          labWhatsapp: _lab.whatsapp,
          labPhone: _lab.phone,
        ),
      ),
    );
  }

  void _openAllPackages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabPackagesPage(lab: _lab)),
    );
  }

  Future<void> _openLocation() async {
    final map = _lab.mapUrl.trim();
    final address = _lab.address.trim();
    if (map.isNotEmpty) {
      await LabCardLinks.openMapUrl(map);
      return;
    }
    if (address.isNotEmpty) {
      await LabCardLinks.openMapUrl(address);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لا يوجد عنوان أو رابط خرائط لهذا المختبر')),
    );
  }

  void _share() {
    LabCardLinks.shareLabCard(labId: _lab.id, labName: _lab.name);
  }

  void _openPickAnalyses() {
    openLabPickAnalysesSheet(
      context: context,
      labId: _lab.id,
      labName: _lab.name,
      labWhatsApp: _lab.whatsapp,
    );
  }

  void _showQr() {
    LabCardLinks.showDigitalLabCard(
      context,
      labId: _lab.id,
      labName: _lab.name,
      slogan: _lab.slogan,
      imageUrl: LabDefaultImages.displayUrl(
        imageUrl: _lab.imageUrl,
        labId: _lab.id,
      ),
      verified: _lab.isFeatured,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        unawaited(_voice.stop());
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _pageBg,
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _teal),
                      )
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
                                child: const Text('إعادة المحاولة'),
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
                            SliverToBoxAdapter(child: _buildAddressSection()),
                            SliverToBoxAdapter(child: _buildTabs()),
                            SliverToBoxAdapter(child: _buildTabBody()),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 20),
                            ),
                          ],
                        ),
                      ),
              ),
              if (!_loading && _error == null) _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  String get _heroImageUrl =>
      LabDefaultImages.displayUrl(imageUrl: _lab.imageUrl, labId: _lab.id);

  /// سطر نوع المختبر تحت الاسم — شعار أو افتراضي.
  String get _heroSpecialty {
    final slogan = _lab.slogan.trim();
    if (slogan.isNotEmpty) return slogan;
    return 'مختبر تحاليل طبية';
  }

  /// مقتطف قصير من بداية النبذة للهيرو فقط.
  String get _heroBioSnippet {
    final raw = _lab.description.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.isEmpty) return '';
    final words = raw.split(' ');
    const maxWords = 14;
    if (words.length <= maxWords) return raw;
    return '${words.take(maxWords).join(' ')}…';
  }

  /// الهوية الموحّدة (نفس هوية الطبيب): صورة بإطار يمين، والكتابة يسار،
  /// و«اختر تحليلك بنفسك» بعرض البطاقة تحتهم.
  Widget _buildHero() {
    final hasImage = _heroImageUrl.trim().isNotEmpty;
    return GhadeerIdentityCard(
      photo: _LabHeroImage(imageUrl: _heroImageUrl),
      onPhotoTap: hasImage
          ? () => showGhadeerPhotoViewer(
              context,
              LabNetworkOrAssetImage(
                _heroImageUrl,
                fit: BoxFit.contain,
                cacheWidth: 1400,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            )
          : null,
      name: _lab.name.trim().isEmpty ? 'مختبر' : _lab.name.trim(),
      subtitle: _heroSpecialty,
      snippet: _heroBioSnippet,
      logo: _lab.logoUrl.trim().isNotEmpty
          ? EntityOptionalLogo(url: _lab.logoUrl)
          : null,
      // ٥ ضغطات على الاسم = دخول صاحب المختبر (مثل قبل).
      wrapName: (name) => DoctorCardTripleTap(
        tapCount: 5,
        onTripleTap: _openLabPackagesManage,
        child: name,
      ),
      favorite: _favorite,
      onToggleFavorite: _toggleFavorite,
      onShare: _share,
      onBack: () => unawaited(_stopSpeechAndPop()),
      ownerAccess: OwnerAccess.faint(
        onTap: () => unawaited(_openLabPackagesManage()),
      ),
      below: _LabPickAnalysesCta(onTap: _openPickAnalyses),
    );
  }

  Widget _buildIdentity() {
    final bio = _lab.description.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: GhadeerTokens.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('نبذة عن المختبر', style: GhadeerTokens.heading),
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
                    'لم تتم إضافة نبذة عن المختبر حتى الآن.',
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
    // مباشرة تحت النبذة — اتصال · واتساب · مواقع · الموقع.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: EntityContactActionsRow(
        phone: _lab.phone,
        whatsapp: _lab.whatsapp,
        social: _lab.social,
        socialTitle: 'مواقع تواصل ${_lab.name}',
        onCall: () {
          _stats.recordLabCallTap(_lab.id);
          launchClinicCall(_lab.phone);
        },
        onWhatsapp: () async {
          _stats.recordLabWhatsAppTap(_lab.id);
          await WhatsAppContactFlow.open(
            context,
            whatsapp: _lab.whatsapp,
            section: WhatsAppSection.labs,
            providerTitle: _lab.name,
          );
        },
        onLocation: _openLocation,
        showLocation:
            _lab.address.trim().isNotEmpty || _lab.mapUrl.trim().isNotEmpty,
      ),
    );
  }

  Widget _buildAddressSection() {
    final location = _lab.address.trim();
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
                      const Text('عنوان المختبر', style: GhadeerTokens.caption),
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

  Future<void> _openLabPackagesManage() async {
    final session = await showEntityOwnerSession(
      context,
      entityType: 'lab',
      entityId: _lab.id,
      title: _lab.name,
    );
    if (session == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LabOwnerEditorPage(lab: _lab, session: session),
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = <({String label, int id})>[
      (label: 'نبذة المختبر', id: 0),
      if (_packages.isNotEmpty) (label: 'الباقات', id: 1),
      if (_offerPackages.isNotEmpty) (label: 'العروض', id: 2),
      if (_labAnalyses.isNotEmpty) (label: 'أهم التحاليل', id: 3),
    ];

    // Normalize tab if current is hidden.
    if (!tabs.any((t) => t.id == _tab) && tabs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tab = tabs.first.id);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in tabs)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: InkWell(
                      onTap: () => setState(() => _tab = t.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Text(
                          t.label,
                          style: TextStyle(
                            color: _tab == t.id
                                ? _actionBlue
                                : const Color(0xFF7A8B90),
                            fontWeight: _tab == t.id
                                ? FontWeight.w900
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Stack(
            children: [
              Container(height: 2, color: _line),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final t in tabs)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: t.label.length * 8.5 + 16,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: _tab == t.id
                              ? _actionBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_tab) {
      case 1:
        return _packagesList(_packages);
      case 2:
        return _packagesList(_offerPackages, offersOnly: true);
      case 3:
        return _analysesTab();
      default:
        return _aboutTab();
    }
  }

  Widget _aboutTab() {
    final homePkgs = _homePackages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (homePkgs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'الباقات',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                ),
                if (homePkgs.length > 1)
                  _packagesSpeakButton(packages: homePkgs),
              ],
            ),
          ),
          // شريط أفقي مثل الصيدلية — كل الباقات + سحب.
          LabPackagesStrip(packages: homePkgs, onOpen: _openPackage),
          if (homePkgs.length > 4)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _tab = 1),
                child: const Text(
                  'عرض كل الباقات',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
        if (_lab.description.trim().isNotEmpty && homePkgs.isEmpty)
          _sectionCard(
            title: 'نبذة عن المختبر',
            icon: Icons.biotech_outlined,
            child: Text(
              _lab.description,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.75,
                color: Color(0xFF33454F),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _hoursAndLocationRow(),
      ],
    );
  }

  Widget _packagesList(
    List<LabPackageItem> packages, {
    bool offersOnly = false,
  }) {
    if (packages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          offersOnly ? 'لا توجد عروض حاليًا' : 'لا توجد باقات حاليًا',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _packagesSpeakButton(
              packages: packages,
              offersOnly: offersOnly,
            ),
          ),
        ),
        LabPackagesStrip(packages: packages, onOpen: _openPackage),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _analysesTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _analysisSearch,
            onChanged: _filterAnalyses,
            decoration: InputDecoration(
              hintText: 'ابحث عن تحليل...',
              prefixIcon: const Icon(Icons.search_rounded, color: _teal),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _line),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_filteredAnalyses.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'لا توجد تحاليل مطابقة',
                style: TextStyle(color: _muted),
              ),
            )
          else
            ..._filteredAnalyses
                .take(40)
                .map(
                  (a) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.arabicDisplayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _navy,
                          ),
                        ),
                        if (a.englishDisplayName.isNotEmpty &&
                            a.englishDisplayName != a.arabicDisplayName) ...[
                          const SizedBox(height: 3),
                          Text(
                            a.englishDisplayName,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _hoursAndLocationRow() {
    final hours = _lab.workingHours.trim();
    final address = _lab.address.trim();
    if (hours.isEmpty && address.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 360;
          final cards = <Widget>[
            if (hours.isNotEmpty)
              _infoMiniCard(
                icon: Icons.access_time_rounded,
                title: 'أوقات العمل',
                body: hours,
              ),
            if (address.isNotEmpty)
              _infoMiniCard(
                icon: Icons.location_on_rounded,
                title: 'موقع المختبر',
                body: address,
                trailing: InkWell(
                  onTap: _openLocation,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF4F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _line),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_rounded,
                          color: Color(0xFFE25555),
                          size: 20,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'الخريطة',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                footer: TextButton(
                  onPressed: _openLocation,
                  style: TextButton.styleFrom(
                    foregroundColor: _actionBlue,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'عرض على الخريطة',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
          ];

          if (!wide || cards.length == 1) {
            return Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  cards[i],
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cards[i]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _infoMiniCard({
    required IconData icon,
    required String title,
    required String body,
    Widget? trailing,
    Widget? footer,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _actionBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _navy,
                    fontSize: 14,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: _muted,
              height: 1.45,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 4), footer],
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _actionBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: _ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasMany = _packages.length > 1;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            if (hasMany)
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _openAllPackages,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E8F9A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text(
                      'عرض جميع الباقات',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _showQr,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0E8F9A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text(
                      'بطاقة المختبر الرقمية',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            SizedBox(
              height: 50,
              width: 50,
              child: OutlinedButton(
                onPressed: hasMany ? _showQr : _share,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _actionBlue,
                  side: const BorderSide(color: Color(0xFFB7DCE2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(
                  hasMany ? Icons.qr_code_2_rounded : Icons.share_outlined,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// زر اختيار التحاليل في أسفل عمود هوية المختبر.
class _LabPickAnalysesCta extends StatelessWidget {
  const _LabPickAnalysesCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: GhadeerTokens.teal,
        borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
        child: InkWell(
          key: const Key('lab_pick_analyses_cta'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.science_outlined, color: Colors.white, size: 22),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'اختر تحليلك بنفسك',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.25,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabHeroImage extends StatelessWidget {
  const _LabHeroImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final photo = imageUrl.trim().isNotEmpty
        ? LabNetworkOrAssetImage(
            imageUrl,
            fit: BoxFit.cover,
            alignment: const Alignment(0.1, -0.15),
            cacheWidth: 1200,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const _LabPortraitFallback(),
          )
        : const _LabPortraitFallback();

    return photo;
  }
}

class _LabPortraitFallback extends StatelessWidget {
  const _LabPortraitFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAF4F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.biotech_rounded,
        size: 72,
        color: Color(0xFF9BB8B6),
      ),
    );
  }
}
