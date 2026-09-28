import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../home/ghadeer_home_colors.dart';
import '../labs/labs_page.dart';
import '../widgets/entity_contact_actions.dart';
import 'pharmacies_store.dart';
import 'pharmacy_distance.dart';
import 'pharmacy_models.dart';
import 'pharmacy_profile_page.dart';

/// قائمة الصيدليات — مواضع بصرية مطابقة للموكاب (يسار/يمين الشاشة).
class PharmaciesPage extends StatefulWidget {
  const PharmaciesPage({super.key});

  @override
  State<PharmaciesPage> createState() => _PharmaciesPageState();
}

class _PharmaciesPageState extends State<PharmaciesPage> {
  final _search = TextEditingController();
  String _chip = 'all'; // all | near | open | supplements
  String _query = '';
  List<PharmacyItem> _all = const [];
  bool _loading = true;
  bool _locating = false;
  double? _userLat;
  double? _userLng;
  bool _usedFallbackOrigin = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await PharmaciesStore.instance.load();
    if (!mounted) return;
    setState(() {
      _all = [
        for (final p in PharmaciesStore.instance.items) _withCatalogCoords(p),
      ];
      _loading = false;
    });
  }

  /// يحافظ على بيانات الإدارة ويملأ الإحداثيات الناقصة من الكتالوج فقط.
  PharmacyItem _withCatalogCoords(PharmacyItem p) {
    if (p.latitude != null && p.longitude != null) return p;
    for (final c in PharmaciesCatalog.items) {
      if (c.id == p.id && c.latitude != null && c.longitude != null) {
        return p.copyWith(latitude: c.latitude, longitude: c.longitude);
      }
    }
    return p;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PharmacyItem> get _filtered {
    var list = _all.toList();
    switch (_chip) {
      case 'open':
        list = list.where((p) => p.isOpenNow).toList();
        break;
      case 'supplements':
        list = list.where((p) => p.hasSupplements).toList();
        break;
      case 'near':
        final lat = _userLat ?? PharmacyDistance.shatraLat;
        final lng = _userLng ?? PharmacyDistance.shatraLng;
        list = PharmacyDistance.sortByDistance(
          list,
          originLat: lat,
          originLng: lng,
        );
        break;
    }
    final q = _query.trim();
    if (q.isNotEmpty) {
      list = list
          .where(
            (p) =>
                p.name.contains(q) ||
                p.address.contains(q) ||
                p.tags.any((t) => t.contains(q)),
          )
          .toList();
    }
    return list;
  }

  Future<void> _onChipSelected(String id) async {
    setState(() => _chip = id);
    if (id != 'near') return;
    await _resolveUserLocation();
  }

  Future<void> _resolveUserLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _applyFallbackOrigin(
          'فعّل خدمة الموقع لترتيب أدق — يُعرض الترتيب حسب الشطرة مؤقتاً',
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _applyFallbackOrigin(
          'لم يُسمح بالموقع — الترتيب حسب مركز الشطرة',
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _usedFallbackOrigin = false;
      });
    } catch (_) {
      _applyFallbackOrigin(
        'تعذر تحديد موقعك — الترتيب حسب مركز الشطرة',
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _applyFallbackOrigin(String message) {
    if (!mounted) return;
    setState(() {
      _userLat = null;
      _userLng = null;
      _usedFallbackOrigin = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsapp(String wa) async {
    final digits = wa.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openProfile(PharmacyItem p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PharmacyProfilePage(pharmacy: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchRow(),
            _buildChips(),
            if (_chip == 'near' && (_locating || _usedFallbackOrigin))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _locating
                        ? 'جاري تحديد موقعك…'
                        : 'مرتب حسب القرب (مركز الشطرة إن تعذّر الموقع)',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: GhadeerHomeColors.muted,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد صيدليات مطابقة',
                        style: TextStyle(
                          color: GhadeerHomeColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final p = items[i];
                        return _PharmacyCard(
                          pharmacy: p,
                          onDetails: () => _openProfile(p),
                          onCall: () => _call(p.phone),
                          onWhatsapp: () => _whatsapp(p.whatsapp),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      // الموكاب: رئيسية · أطباء · صيدليات · مختبرات — بدون «المزيد»
      bottomNavigationBar: _buildSectionBottomNav(),
    );
  }

  Widget _buildSectionBottomNav() {
    const teal = GhadeerHomeColors.pharmacyAccent;
    const muted = Color(0xFF8A9A9E);

    Widget item({
      required IconData icon,
      required IconData activeIcon,
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: active
                        ? teal.withValues(alpha: 0.14)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    active ? activeIcon : icon,
                    size: 22,
                    color: active ? teal : muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? teal : muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        // LTR حتى لا ينعكس صف الأزرار: رئيسية يسار → مختبرات يمين
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              item(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'الرئيسية',
                active: false,
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
              item(
                icon: Icons.medical_services_outlined,
                activeIcon: Icons.medical_services_rounded,
                label: 'الأطباء',
                active: false,
                onTap: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
              item(
                icon: Icons.medication_outlined,
                activeIcon: Icons.medication_rounded,
                label: 'الصيدليات',
                active: true,
                onTap: () {},
              ),
              item(
                icon: Icons.science_outlined,
                activeIcon: Icons.science_rounded,
                label: 'المختبرات',
                active: false,
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LabsPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // الموكاب: رجوع + شعار صحي يسار · عنوان وسط · شعار الغدير يمين
    const identity = GhadeerHomeColors.pharmacyAccent;
    const titleColor = GhadeerHomeColors.pharmacyTitle;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE5F7F9), Color(0xFFF7FBFC)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // يسار: رجوع (نفس جهة هوية الطبيب) + «صحتك أولاً...»
            SizedBox(
              width: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GhadeerBackButton(
                    onPressed: () => Navigator.pop(context),
                    color: identity,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'صحتك أولاً',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: identity,
                    ),
                  ),
                  const Text(
                    'مع صيدليات الشطرة',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: identity,
                    ),
                  ),
                ],
              ),
            ),
            // وسط: عنوان الصيدليات + خدمات الهوية
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'الصيدليات',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: 0.2,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'استفسار • اتصال • واتساب',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: identity,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'صيدليات الشطرة في خدمتك',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: titleColor.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            // يمين: شعار الغدير (الصورة الرسمية المرسلة)
            Column(
              children: [
                ClipOval(
                  child: Image.asset(
                    GhadeerBranding.officialLogoAsset,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'الغدير',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const Text(
                  'دليلك الصحي في الشطرة',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5A7A88),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    // بحث يسار الحقل · تصفية يمين
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4EEEE)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF8A9A9E),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        textDirection: TextDirection.rtl,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintTextDirection: TextDirection.rtl,
                          hintText: 'ابحث عن صيدلية بالاسم أو المنطقة...',
                          hintStyle: TextStyle(
                            color: Color(0xFF8A9A9E),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('التصفية متاحة عبر الشرائح أسفل البحث'),
                    ),
                  );
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD6EAF5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: GhadeerHomeColors.pharmacyAccent,
                        size: 20,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'تصفية',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: GhadeerHomeColors.pharmacyAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
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
    );
  }

  Widget _buildChips() {
    final chips = <({String id, String label, IconData? icon})>[
      (id: 'all', label: 'الكل', icon: null),
      (id: 'near', label: 'قريب مني', icon: Icons.location_on_outlined),
      (id: 'open', label: 'مفتوحة الآن', icon: Icons.schedule_rounded),
      (
        id: 'supplements',
        label: 'تقدم مكملات غذائية',
        icon: Icons.eco_outlined,
      ),
    ];
    return SizedBox(
      height: 42,
      // من اليسار لليمين: الكل → قريب مني → مفتوحة الآن → مكملات
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final c = chips[i];
            final active = _chip == c.id;
            return ChoiceChip(
              selected: active,
              showCheckmark: false,
              avatar: c.icon == null
                  ? null
                  : Icon(
                      c.icon,
                      size: 15,
                      color: active
                          ? Colors.white
                          : GhadeerHomeColors.pharmacyAccent,
                    ),
              label: Text(c.label),
              selectedColor: GhadeerHomeColors.pharmacyAccent,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: active
                    ? GhadeerHomeColors.pharmacyAccent
                    : const Color(0xFFD6EAF5),
              ),
              labelStyle: TextStyle(
                color:
                    active ? Colors.white : GhadeerHomeColors.pharmacyTitle,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
              onSelected: (_) => _onChipSelected(c.id),
            );
          },
        ),
      ),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  const _PharmacyCard({
    required this.pharmacy,
    required this.onDetails,
    required this.onCall,
    required this.onWhatsapp,
  });

  final PharmacyItem pharmacy;
  final VoidCallback onDetails;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;

  /// أخضر هادئ ظاهر — مو صارخ ومو مختفي.
  static const _openSoft = Color(0xFF6BAF84);
  static const _closedSoft = Color(0xFFC17A7A);

  @override
  Widget build(BuildContext context) {
    final p = pharmacy;
    final open = p.isOpenNow;
    final statusColor = open ? _openSoft : _closedSoft;
    final statusText = open ? 'مفتوحة الآن' : 'مغلقة الآن';

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            EntityListContactRow(
              onCall: onCall,
              onWhatsapp: onWhatsapp,
              onDetails: onDetails,
            ),
            const SizedBox(height: 10),
            // عكس الموكاب الظاهر في اللقطة حتى لا ينعكس على الجهاز:
            // يمين الشاشة = الصورة · الوسط = المعلومات · يسار = الحالة
            Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // يمين الشاشة (أول عنصر في RTL)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onDetails,
                      borderRadius: BorderRadius.circular(14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: p.imageUrl.isEmpty
                              ? Container(
                                  color: const Color(0xFFE8F6FB),
                                  child: const Icon(
                                    Icons.local_pharmacy_rounded,
                                    color: GhadeerHomeColors.pharmacyAccent,
                                    size: 34,
                                  ),
                                )
                              : Image.network(
                                  p.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: const Color(0xFFE8F6FB),
                                    child: const Icon(
                                      Icons.local_pharmacy_rounded,
                                      color: GhadeerHomeColors.pharmacyAccent,
                                      size: 34,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: onDetails,
                          borderRadius: BorderRadius.circular(6),
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 18.5,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                              color: GhadeerHomeColors.pharmacyTitle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: GhadeerHomeColors.pharmacyAccent,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                p.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: GhadeerHomeColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in p.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F6FB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFD6EAF5),
                                  ),
                                ),
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: GhadeerHomeColors.pharmacyTitle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // يسار الشاشة: الحالة (آخر عنصر في RTL)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: statusColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: GhadeerHomeColors.muted,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'من ${p.openFrom}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: GhadeerHomeColors.muted,
                        ),
                      ),
                      Text(
                        'إلى ${p.openTo}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: GhadeerHomeColors.muted,
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
}
