import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home/ghadeer_home_colors.dart';
import '../services/entity_access_pin_service.dart';
import '../voice/entity_profile_speech.dart';
import '../voice/voice_response_controller.dart';
import '../widgets/entity_access_pin_gate.dart';
import '../widgets/entity_contact_actions.dart';
import '../widgets/entity_speak_button.dart';
import 'pharmacy_all_bundles_page.dart';
import 'pharmacy_bundle_detail_sheet.dart';
import 'pharmacy_bundles_manage_page.dart';
import 'pharmacy_custom_bundle_page.dart';
import 'pharmacy_fit_image.dart';
import 'pharmacy_models.dart';

/// صفحة تفاصيل صيدلية — مواضع بصرية مطابقة للموكاب (موبايل أولاً).
class PharmacyProfilePage extends StatefulWidget {
  const PharmacyProfilePage({super.key, required this.pharmacy});

  final PharmacyItem pharmacy;

  @override
  State<PharmacyProfilePage> createState() => _PharmacyProfilePageState();
}

class _PharmacyProfilePageState extends State<PharmacyProfilePage> {
  late PharmacyItem _p;
  bool _favorite = false;
  final _search = TextEditingController();
  final _voice = VoiceResponseController();
  bool _speechBusy = false;

  @override
  void initState() {
    super.initState();
    _p = widget.pharmacy;
  }

  @override
  void dispose() {
    unawaited(_voice.stop());
    _voice.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggleBundlesSpeech() async {
    if (_voice.isSpeaking || _speechBusy) {
      await _voice.stop();
      _speechBusy = false;
      return;
    }
    final text = EntityProfileSpeech.pharmacyBundles(
      pharmacyName: _p.name,
      bundles: _allBundles,
    );
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد باقات للقراءة حالياً.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _speechBusy = true;
    try {
      await _voice.speak(text);
    } finally {
      _speechBusy = false;
    }
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: _p.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final digits = _p.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _maps() async {
    final q = Uri.encodeComponent(_p.address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: '${_p.name}\n${_p.address}\nهاتف: ${_p.phone}'),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final openColor =
        _p.isOpenNow ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    final openText = _p.isOpenNow ? 'مفتوح الآن' : 'مغلق الآن';

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFC),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _profileCard(openColor, openText),
                  const SizedBox(height: 12),
                  _primaryActions(),
                  const SizedBox(height: 12),
                  _productSearch(),
                  const SizedBox(height: 16),
                  _bundlesHeader(),
                  const SizedBox(height: 10),
                  _bundlesStrip(),
                  const SizedBox(height: 12),
                  _chooseOwnButton(),
                  const SizedBox(height: 14),
                  _offersBanner(),
                  const SizedBox(height: 14),
                  _secondaryActions(),
                  const SizedBox(height: 16),
                  _mapSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    // رجوع يسار (نفس جهة هوية الطبيب) · عنوان وسط · مفضلة+مشاركة يمين
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            GhadeerBackButton(
              onPressed: () => Navigator.pop(context),
              color: GhadeerHomeColors.pharmacyTitle,
            ),
            Expanded(
              child: StaffTripleTap(
                // مخفي عن المستخدم العادي — 3 ضغطات على عنوان «الصيدلية»
                onTripleTap: _openBundlesManage,
                child: const Text(
                  'الصيدلية',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: GhadeerHomeColors.secondary,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'مفضلة',
              onPressed: () => setState(() => _favorite = !_favorite),
              icon: Icon(
                _favorite ? Icons.favorite_rounded : Icons.favorite_border,
                color: _favorite
                    ? const Color(0xFFE74C3C)
                    : GhadeerHomeColors.secondary,
              ),
            ),
            IconButton(
              tooltip: 'مشاركة',
              onPressed: _share,
              icon: const Icon(
                Icons.ios_share_rounded,
                color: GhadeerHomeColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(Color openColor, String openText) {
    // صورة يسار · اسم/شعار يمين · موقع+حالة أسفل
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: PharmacyFitImage(
                        source: _p.imageUrl,
                        fallback: Icons.local_pharmacy_rounded,
                        borderRadius: 0,
                        width: 110,
                        height: 110,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _p.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: GhadeerHomeColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _p.slogan,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: GhadeerHomeColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F6FB),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFD6EAF5),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _p.logoUrl.isNotEmpty
                                    ? PharmacyFitImage(
                                        source: _p.logoUrl,
                                        fallback: Icons.medication_outlined,
                                        borderRadius: 999,
                                        width: 48,
                                        height: 48,
                                      )
                                    : const Icon(
                                        Icons.medication_outlined,
                                        color: GhadeerHomeColors.primary,
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: GhadeerHomeColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _p.address,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: GhadeerHomeColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: openColor),
                      const SizedBox(width: 4),
                      Text(
                        openText,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: openColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'من ${_p.openFrom} إلى ${_p.openTo}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: GhadeerHomeColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryActions() {
    // نفس اتجاه المختبر وألوانه — بدون لمس هوية الطبيب.
    return EntityContactActionsRow(
      phone: _p.phone,
      whatsapp: _p.whatsapp,
      social: _p.social,
      socialTitle: 'مواقع تواصل ${_p.name}',
      onCall: _call,
      onWhatsapp: _whatsapp,
      onLocation: _maps,
    );
  }

  Widget _productSearch() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4EEEE)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Color(0xFF8A9A9E)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintTextDirection: TextDirection.rtl,
                  hintText: 'ابحث عن مكمل غذائي أو منتج ...',
                  hintStyle: TextStyle(
                    color: Color(0xFF8A9A9E),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => _snack('تصفية المنتجات قريباً'),
              icon: const Icon(
                Icons.tune_rounded,
                color: GhadeerHomeColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PharmacyBundle> get _allBundles {
    final raw = _p.bundles.isEmpty
        ? PharmaciesCatalog.items.first.bundles
        : _p.bundles;
    return PharmaciesCatalog.visibleOnly(
      PharmaciesCatalog.mergeWithCatalog(raw),
    );
  }

  Widget _bundlesHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'باقات المكملات الغذائية',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: GhadeerHomeColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _voice,
                builder: (context, _) {
                  return EntitySpeakButton(
                    speaking: _voice.isSpeaking,
                    label: 'اسمع الباقات',
                    enabled: _allBundles.isNotEmpty,
                    onTap: () => unawaited(_toggleBundlesSpeech()),
                  );
                },
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PharmacyAllBundlesPage(
                    pharmacy: _p,
                    bundles: _allBundles,
                  ),
                ),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left_rounded, size: 18),
                Text(
                  'عرض الكل',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chooseOwnButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PharmacyCustomBundlePage(pharmacy: _p),
            ),
          );
        },
        icon: const Icon(Icons.tune_rounded),
        label: const Text(
          'اختر باقتك بنفسك',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: GhadeerHomeColors.primary,
          side: const BorderSide(color: GhadeerHomeColors.primary, width: 1.4),
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _bundlesStrip() {
    final raw = _p.bundles.isEmpty
        ? PharmaciesCatalog.items.first.bundles
        : _p.bundles;
    final bundles = PharmaciesCatalog.popularForStrip(
      PharmaciesCatalog.mergeWithCatalog(raw),
    );
    return SizedBox(
      height: 248,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: bundles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final b = bundles[i];
          return Container(
            width: 158,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4EEEE)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F6FB),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          b.icon.isEmpty ? '💊' : b.icon,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: GhadeerHomeColors.secondary,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (b.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      b.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: GhadeerHomeColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  PharmacyFitImage(
                    source: b.imageUrl,
                    width: double.infinity,
                    height: 86,
                    borderRadius: 12,
                    fallback: Icons.medication_liquid_rounded,
                  ),
                  const Spacer(),
                  if (b.price > 0)
                    Text(
                      '${_fmt(b.price)} د.ع',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: GhadeerHomeColors.primary,
                      ),
                    )
                  else
                    const Text(
                      'السعر عند الطلب',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: GhadeerHomeColors.primary,
                      ),
                    ),
                  if (b.oldPrice > 0)
                    Text(
                      '${_fmt(b.oldPrice)} د.ع',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE74C3C),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showPharmacyBundleDetail(
                        context: context,
                        pharmacy: _p,
                        bundle: b,
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 15),
                      label: const Text(
                        'التفاصيل والطلب',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: GhadeerHomeColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _offersBanner() {
    final pct = _p.offerPercent <= 0 ? 30 : _p.offerPercent;
    final offerImage = PharmaciesCatalog.resolveOfferImage(_p);
    final offerIcon = PharmaciesCatalog.resolveOfferIcon(_p);

    // بانر أعرض نعناعي: صورة منتجات + شارة ٪ يسار بصرياً، نص+أيقونة+زر يمين
    return Material(
      color: const Color(0xFFE6F7EF),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 108,
                    height: 108,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: PharmacyFitImage(
                            source: offerImage,
                            fallback: Icons.local_offer_rounded,
                            borderRadius: 16,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          left: -6,
                          child: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE74C3C),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              '$pct%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: const Text(
                                  'عروض الصيدلية',
                                  style: TextStyle(
                                    color: Color(0xFF0B6B4F),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _offerIconBadge(offerIcon),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'خصومات حتى $pct٪ على باقات مختارة',
                            style: const TextStyle(
                              color: Color(0xFF3D7A66),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _snack('عروض الصيدلية قريباً'),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                          color: Color(0xFF1FAF6B),
                        ),
                        Text(
                          'عرض العروض',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: Color(0xFF1FAF6B),
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offerIconBadge(String iconUrl) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2ECC71), Color(0xFF00B4D8)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332ECC71),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: iconUrl.isNotEmpty
          ? PharmacyFitImage(
              source: iconUrl,
              fallback: Icons.eco_rounded,
              borderRadius: 999,
              width: 48,
              height: 48,
            )
          : const Icon(Icons.eco_rounded, color: Colors.white, size: 26),
    );
  }

  Future<void> _openBundlesManage() async {
    final ok = await openEntityAccessPinGate(
      context,
      entityKey: EntityAccessPinService.pharmacyKey(_p.id),
      entityTitle: _p.name,
    );
    if (!ok || !mounted) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PharmacyBundlesManagePage(pharmacyId: _p.id),
      ),
    );
  }

  Widget _secondaryActions() {
    final tiles = <Widget>[
      _secTile(
        icon: Icons.info_outline_rounded,
        label: 'معلومات',
        onTap: () => _snack(_p.slogan),
      ),
      _secTile(
        icon: Icons.schedule_rounded,
        label: 'ساعات العمل',
        onTap: () => _snack('من ${_p.openFrom} إلى ${_p.openTo}'),
      ),
      _secTile(
        icon: Icons.share_outlined,
        label: 'مشاركة',
        onTap: _share,
      ),
      _secTile(
        icon: Icons.star_border_rounded,
        label: 'المفضلة',
        onTap: () => setState(() => _favorite = !_favorite),
      ),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i != tiles.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _secTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFE8F6FB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: GhadeerHomeColors.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: GhadeerHomeColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'موقع الصيدلية',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: GhadeerHomeColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 72,
                      height: 72,
                      color: const Color(0xFFE8F6FB),
                      child: const Icon(
                        Icons.map_rounded,
                        color: GhadeerHomeColors.primary,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _p.address,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: GhadeerHomeColors.secondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: GhadeerHomeColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _maps,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'فتح الخرائط',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}
