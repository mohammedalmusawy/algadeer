import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../models/lab_models.dart';
import '../utils/contact_launch.dart';
import '../services/app_stats_service.dart';
import '../voice/lab_packages_speech.dart';
import '../voice/voice_response_controller.dart';
import 'lab_card_links.dart';
import 'lab_default_images.dart';
import 'lab_package_detail_page.dart';
import 'lab_packages_page.dart';
import 'lab_pick_analyses_sheet.dart';
import 'labs_service.dart';
import 'widgets/lab_network_or_asset_image.dart';
import 'widgets/lab_package_card.dart';
import 'widgets/package_hero_image.dart';

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

  static const _navy = Color(0xFF123B42);
  static const _ink = Color(0xFF0F2A3D);
  static const _teal = Color(0xFF0FAFA3);
  static const _actionBlue = Color(0xFF1197A8);
  static const _muted = Color(0xFF5B6C70);
  static const _line = Color(0xFFE4EEF0);
  static const _pageBg = Color(0xFFF7FBFC);
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

  String _packagesSpeechFor(List<LabPackageItem> packages, {bool offersOnly = false}) {
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

  /// Featured = is_featured أو show_on_home، وإلا أعلى خصم، وإلا أول باقة.
  LabPackageItem? get _featuredPackage {
    if (_packages.isEmpty) return null;
    final featured = _packages.where((p) => p.isFeatured || p.showOnHome);
    if (featured.isNotEmpty) {
      final list = featured.toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return list.first;
    }
    final discounted = _packages.where((p) => p.discountPercent != null).toList()
      ..sort((a, b) => (b.discountPercent ?? 0).compareTo(a.discountPercent ?? 0));
    if (discounted.isNotEmpty) return discounted.first;
    final ordered = [..._packages]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return ordered.first;
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
        builder: (_) =>
            LabPackageDetailPage(packageId: pkg.id, labName: _lab.name),
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
      const SnackBar(
        content: Text('لا يوجد عنوان أو رابط خرائط لهذا المختبر'),
      ),
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
                          SliverToBoxAdapter(child: _buildIdentity()),
                          SliverToBoxAdapter(child: _buildActions()),
                          SliverToBoxAdapter(child: _buildTabs()),
                          SliverToBoxAdapter(child: _buildTabBody()),
                          const SliverToBoxAdapter(child: SizedBox(height: 20)),
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

  String get _heroImageUrl => LabDefaultImages.displayUrl(
        imageUrl: _lab.imageUrl,
        labId: _lab.id,
      );

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

  Widget _circleIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      shadowColor: Colors.transparent,
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

  /// Hero مطابق لهوية الطبيب: صورة يمينًا + هوية يسارًا + أزرار علوية.
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
                    clipBehavior: Clip.hardEdge,
                    children: [
                      const _LabHeroDepthBackground(),
                      Positioned(
                        top: 0,
                        bottom: -12,
                        right: -6,
                        width: imageW,
                        child: _LabHeroImage(imageUrl: _heroImageUrl),
                      ),
                      Positioned(
                        top: 10,
                        left: 12,
                        bottom: 12,
                        width: leftColW,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          // فوق: رجوع + مجموعة الهوية. أسفل: اختيار التحاليل.
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _circleIconBtn(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: () => unawaited(_stopSpeechAndPop()),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: _LabGhadeerVerifiedPill(),
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
                                  _LabHeroNameSpecialty(
                                    name: _lab.name.trim().isEmpty
                                        ? 'مختبر'
                                        : _lab.name.trim(),
                                    specialty: _heroSpecialty,
                                    supportLine: '',
                                  ),
                                ],
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
                              _LabPickAnalysesCta(
                                onTap: _openPickAnalyses,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _circleIconBtn(
                          icon: Icons.ios_share_rounded,
                          onTap: _share,
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
    final bio = _lab.description.trim();
    final location = _lab.address.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'نبذة عن المختبر',
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
                  'لم تتم إضافة نبذة عن المختبر حتى الآن.',
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
              'عنوان المختبر',
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
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _openLocation,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE4EEEE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _actionBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.55,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF33454F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _lab.mapUrl.trim().isNotEmpty
                                  ? 'فتح الموقع في الخرائط'
                                  : 'بحث العنوان في الخرائط',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _actionBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded, color: _muted),
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

  Widget _buildActions() {
    final buttons = <Widget>[];

    if (_lab.phone.trim().isNotEmpty) {
      buttons.add(
        _ActionBtn(
          icon: Icons.phone_in_talk_rounded,
          title: 'اتصال',
          filled: true,
          color: _actionBlue,
          onTap: () {
            _stats.recordLabCallTap(_lab.id);
            launchClinicCall(_lab.phone);
          },
        ),
      );
    }
    if (_lab.whatsapp.trim().isNotEmpty) {
      buttons.add(
        _ActionBtn(
          icon: Icons.chat_rounded,
          title: 'واتساب',
          filled: true,
          color: const Color(0xFF25D366),
          onTap: () {
            _stats.recordLabWhatsAppTap(_lab.id);
            launchClinicWhatsApp(_lab.whatsapp);
          },
        ),
      );
    }
    if (_lab.address.trim().isNotEmpty || _lab.mapUrl.trim().isNotEmpty) {
      buttons.add(
        _ActionBtn(
          icon: Icons.near_me_rounded,
          title: 'الموقع',
          filled: false,
          color: _actionBlue,
          onTap: _openLocation,
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: buttons[i]),
          ],
        ],
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
                            fontWeight:
                                _tab == t.id ? FontWeight.w900 : FontWeight.w600,
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
                          color: _tab == t.id ? _actionBlue : Colors.transparent,
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
    final featured = _featuredPackage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featured != null) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Text(
              '🔥 الباقة الأكثر طلبًا',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _FeaturedPackageCard(
              package: featured,
              onOpen: () => _openPackage(featured),
            ),
          ),
        ],
        if (_lab.description.trim().isNotEmpty && featured == null)
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

  Widget _packagesList(List<LabPackageItem> packages, {bool offersOnly = false}) {
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _packagesSpeakButton(
              packages: packages,
              offersOnly: offersOnly,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < packages.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            LabPackageCard(
              package: packages[i],
              onOpen: () => _openPackage(packages[i]),
            ),
          ],
        ],
      ),
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
            ..._filteredAnalyses.take(40).map(
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
                        Icon(Icons.map_rounded, color: Color(0xFFE25555), size: 20),
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
              if (trailing != null) trailing,
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
          if (footer != null) ...[
            const SizedBox(height: 4),
            footer,
          ],
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
        color: const Color(0xFF0FAFA3),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(
              children: [
                Icon(Icons.science_outlined, color: Colors.white, size: 18),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'اختر تحليلك بنفسك',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabGhadeerVerifiedPill extends StatelessWidget {
  const _LabGhadeerVerifiedPill();

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                  'مختبر في منصة الغدير',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
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

class _LabHeroNameSpecialty extends StatelessWidget {
  const _LabHeroNameSpecialty({
    required this.name,
    required this.specialty,
    required this.supportLine,
  });

  final String name;
  final String specialty;
  final String supportLine;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final compact = w < 168;
        final nameSize = compact ? 17.0 : 19.5;
        final specialtySize = compact ? 13.0 : 14.0;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: w.isFinite ? w : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.trim().isEmpty ? 'مختبر' : name.trim(),
                  maxLines: 3,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: nameSize,
                    height: 1.22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F2A3D),
                  ),
                ),
                if (specialty.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GhadeerTextWithLogo(
                    specialty.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.rtl,
                    logoHeight: specialtySize + 4,
                    style: TextStyle(
                      fontSize: specialtySize,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                      color: const Color(0xFF0D8F9E),
                    ),
                  ),
                ],
                if (supportLine.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  GhadeerTextWithLogo(
                    supportLine.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.rtl,
                    logoHeight: compact ? 16 : 18,
                    style: TextStyle(
                      fontSize: compact ? 11.0 : 12.0,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5B6C70),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LabHeroDepthBackground extends StatelessWidget {
  const _LabHeroDepthBackground();

  static const _ice = Color(0xFFEAF4F6);
  static const _iceSoft = Color(0xFFE5F1F4);
  static const _iceMist = Color(0xFFF5FBFC);

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
                _ice,
                _iceSoft,
                _iceMist,
              ],
              stops: [0.0, 0.32, 0.68, 1.0],
            ),
          ),
        ),
        Positioned(
          right: -48,
          top: -10,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD5EBEF).withValues(alpha: 0.85),
                  _ice.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: -70,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFCFE6EB).withValues(alpha: 0.55),
                  _iceSoft.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -30,
          top: 70,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.9),
                  _ice.withValues(alpha: 0.0),
                ],
              ),
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
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color(0xCCE5F1F4),
                Color(0x44EAF4F6),
                Color(0x00FFFFFF),
              ],
              stops: [0.0, 0.14, 0.40],
            ),
          ),
        ),
      ],
    );
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

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.title,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: filled ? color : color.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: filled ? Colors.white : color, size: 22),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: filled ? Colors.white : const Color(0xFF123B42),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedPackageCard extends StatelessWidget {
  const _FeaturedPackageCard({
    required this.package,
    required this.onOpen,
  });

  final LabPackageItem package;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final discount = package.discountPercent;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4EEF0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  PackageHeroImage(
                    packageName: package.name,
                    imageUrl: package.imageUrl,
                    isFeatured: true,
                    width: 96,
                    height: 120,
                  ),
                  Positioned(
                    top: 8,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE25555),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'الأكثر طلبًا',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF123B42),
                      ),
                    ),
                    if (package.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        package.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF5B6C70),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (package.analysesCount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            size: 15,
                            color: Color(0xFF1197A8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${package.analysesCount} تحليل',
                            style: const TextStyle(
                              color: Color(0xFF1197A8),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (discount != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8E8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'خصم $discount%',
                              style: const TextStyle(
                                color: Color(0xFFC94A4A),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (package.newPrice != null)
                          Text(
                            '${formatLabPrice(package.newPrice)} د.ع',
                            style: TextStyle(
                              color: discount != null
                                  ? const Color(0xFFC94A4A)
                                  : const Color(0xFF0FAFA3),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        if (package.hasOldPrice)
                          Text(
                            '${formatLabPrice(package.oldPrice)} د.ع',
                            style: const TextStyle(
                              color: Color(0xFF9AA6A8),
                              fontSize: 12.5,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFFB0BEC2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
