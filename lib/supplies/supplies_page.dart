import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../home/ghadeer_home_colors.dart';
import '../widgets/entity_contact_actions.dart';
import 'supplies_store.dart';
import 'supply_models.dart';
import 'supply_profile_page.dart';

/// قائمة محلات المستلزمات والتجهيزات الطبية.
class SuppliesPage extends StatefulWidget {
  const SuppliesPage({super.key});

  @override
  State<SuppliesPage> createState() => _SuppliesPageState();
}

class _SuppliesPageState extends State<SuppliesPage> {
  final _search = TextEditingController();
  String _chip = 'all'; // all | near | open
  String _query = '';
  List<SupplyVendor> _all = const [];
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
    await SuppliesStore.instance.load();
    if (!mounted) return;
    setState(() {
      _all = [
        for (final p in SuppliesStore.instance.items) _withCatalogCoords(p),
      ];
      _loading = false;
    });
  }

  SupplyVendor _withCatalogCoords(SupplyVendor p) {
    if (p.latitude != null && p.longitude != null) return p;
    for (final c in SuppliesCatalog.items) {
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

  List<SupplyVendor> get _filtered {
    var list = _all.toList();
    switch (_chip) {
      case 'open':
        list = list.where((p) => p.isOpenNow).toList();
        break;
      case 'near':
        final lat = _userLat ?? SupplyDistance.shatraLat;
        final lng = _userLng ?? SupplyDistance.shatraLng;
        list = SupplyDistance.sortByDistance(
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
                p.categories.any((t) => t.contains(q)),
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
        _applyFallback('فعّل الموقع لترتيب أدق — يُعرض حسب الشطرة مؤقتاً');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _applyFallback('لم يُمنح إذن الموقع — الترتيب حسب الشطرة');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _usedFallbackOrigin = false;
        _locating = false;
      });
    } catch (_) {
      _applyFallback('تعذر قراءة الموقع — الترتيب حسب الشطرة');
    }
  }

  void _applyFallback(String msg) {
    if (!mounted) return;
    setState(() {
      _userLat = null;
      _userLng = null;
      _usedFallbackOrigin = true;
      _locating = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String wa) async {
    final digits = wa.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openProfile(SupplyVendor p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplyProfilePage(vendor: p)),
    ).then((_) => _bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF7),
        body: SafeArea(
          child: Column(
            children: [
              _header(context),
              _searchRow(),
              _chips(),
              if (_chip == 'near')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _locating
                          ? 'جاري تحديد موقعك…'
                          : _usedFallbackOrigin
                              ? 'مرتب حسب القرب (مركز الشطرة)'
                              : 'مرتب حسب قربك',
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
                              'لا توجد نتائج مطابقة',
                              style: TextStyle(
                                color: GhadeerHomeColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final p = items[i];
                              return _SupplyCard(
                                vendor: p,
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
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GhadeerBackButton(
              onPressed: () => Navigator.pop(context),
              color: GhadeerHomeColors.suppliesAccent,
            ),
            const Expanded(
              child: Column(
                children: [
                  Text(
                    'المستلزمات والتجهيزات',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: GhadeerHomeColors.secondary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'مستلزمات طبية معتمدة',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GhadeerHomeColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const GhadeerBrandMark(size: 44, backgroundColor: null),
          ],
        ),
      ),
    );
  }

  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8DDD0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Color(0xFF8A9A9E)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'ابحث بالاسم أو نوع المستلزم…',
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
    );
  }

  Widget _chips() {
    Widget chip(String id, String label) {
      final on = _chip == id;
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : GhadeerHomeColors.secondary,
            ),
          ),
          selected: on,
          selectedColor: GhadeerHomeColors.suppliesAccent,
          onSelected: (_) => _onChipSelected(id),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          chip('all', 'الكل'),
          chip('near', 'قريب مني'),
          chip('open', 'مفتوح الآن'),
        ],
      ),
    );
  }
}

class _SupplyCard extends StatelessWidget {
  const _SupplyCard({
    required this.vendor,
    required this.onDetails,
    required this.onCall,
    required this.onWhatsapp,
  });

  final SupplyVendor vendor;
  final VoidCallback onDetails;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: vendor.imageUrl.isEmpty
                          ? const ColoredBox(
                              color: Color(0xFFFFF3E6),
                              child: Icon(
                                Icons.wheelchair_pickup_rounded,
                                color: GhadeerHomeColors.suppliesAccent,
                              ),
                            )
                          : Image.network(
                              vendor.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFFFFF3E6),
                                child: Icon(
                                  Icons.wheelchair_pickup_rounded,
                                  color: GhadeerHomeColors.suppliesAccent,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                            color: GhadeerHomeColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vendor.address,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: GhadeerHomeColors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          vendor.isOpenNow ? 'مفتوح الآن' : 'مغلق الآن',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: vendor.isOpenNow
                                ? const Color(0xFF2ECC71)
                                : const Color(0xFFE74C3C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (vendor.categories.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in vendor.categories.take(4))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          c,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: GhadeerHomeColors.suppliesAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              EntityListContactRow(
                onCall: onCall,
                onWhatsapp: onWhatsapp,
                onDetails: onDetails,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
