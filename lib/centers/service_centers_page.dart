import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/ghadeer_state_message.dart';
import '../theme/ghadeer_tokens.dart';
import '../widgets/ghadeer_skeleton.dart';
import '../home/ghadeer_home_colors.dart';
import '../pharmacies/pharmacy_distance.dart';
import '../widgets/clinic_app_bar.dart';
import 'service_center_kind.dart';
import 'service_center_style.dart';
import 'service_center_models.dart';
import 'service_center_profile_page.dart';
import 'service_centers_store.dart';
import '../widgets/ghadeer_net_image.dart';

class ServiceCenterSnapshot {
  const ServiceCenterSnapshot({
    required this.centers,
    required this.sharedReady,
  });

  final List<ServiceCenter> centers;
  final bool sharedReady;
}

/// قائمة قسم واحد. الترتيب الافتراضي كالصيدليات: ترتيب الإدارة ثم الاسم.
class ServiceCentersPage extends StatefulWidget {
  const ServiceCentersPage({super.key, required this.kind, this.loadCenters});

  final ServiceCenterKind kind;
  final Future<ServiceCenterSnapshot> Function()? loadCenters;

  @override
  State<ServiceCentersPage> createState() => _ServiceCentersPageState();
}

class _ServiceCentersPageState extends State<ServiceCentersPage> {
  final _search = TextEditingController();
  String _chip = 'all';
  String _query = '';
  List<ServiceCenter> _all = const [];
  bool _loading = true;
  bool _sharedReady = false;
  bool _locating = false;
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final snapshot = await (widget.loadCenters ?? _loadShared)();
    if (!mounted) return;
    setState(() {
      _all = snapshot.centers;
      _sharedReady = snapshot.sharedReady;
      _loading = false;
    });
  }

  Future<ServiceCenterSnapshot> _loadShared() async {
    final store = ServiceCentersStore.instance;
    await store.load();
    return ServiceCenterSnapshot(
      centers: serviceCentersForVisitors(
        shared: store.sharedItems,
        sharedReady: store.sharedReady,
        kind: widget.kind,
      ),
      sharedReady: store.sharedReady,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ServiceCenter> get _filtered {
    var list = List<ServiceCenter>.of(_all);
    if (_chip == 'near') {
      final lat = _userLat ?? PharmacyDistance.shatraLat;
      final lng = _userLng ?? PharmacyDistance.shatraLng;
      list = _sortByDistance(list, lat, lng);
    }
    final q = _query.trim();
    if (q.isNotEmpty) {
      list = [
        for (final center in list)
          if (center.name.contains(q) ||
              center.address.contains(q) ||
              center.actualServices.any((s) => s.contains(q)))
            center,
      ];
    }
    return list;
  }

  List<ServiceCenter> _sortByDistance(
    List<ServiceCenter> items,
    double lat,
    double lng,
  ) {
    final indexed = <({ServiceCenter center, double? km, int index})>[
      for (var i = 0; i < items.length; i++)
        (
          center: items[i],
          km: items[i].latitude == null || items[i].longitude == null
              ? null
              : PharmacyDistance.kmBetween(
                  lat,
                  lng,
                  items[i].latitude!,
                  items[i].longitude!,
                ),
          index: i,
        ),
    ];
    indexed.sort((a, b) {
      if (a.km == null && b.km == null) return a.index.compareTo(b.index);
      if (a.km == null) return 1;
      if (b.km == null) return -1;
      final byKm = a.km!.compareTo(b.km!);
      if (byKm != 0) return byKm;
      return a.index.compareTo(b.index);
    });
    return [for (final row in indexed) row.center];
  }

  Future<void> _onChip(String id) async {
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
        _fallback(
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
        _fallback('لم يُسمح بالموقع — الترتيب حسب مركز الشطرة');
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
      });
    } catch (_) {
      _fallback('تعذر تحديد موقعك — الترتيب حسب مركز الشطرة');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _fallback(String message) {
    if (!mounted) return;
    setState(() {
      _userLat = null;
      _userLng = null;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String get _emptyMessage {
    if (_query.trim().isNotEmpty) return 'لا توجد نتائج مطابقة.';
    if (!_sharedReady) return widget.kind.unavailableMessage;
    return widget.kind.emptyVisitorsMessage;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: GhadeerHomeColors.pageBg,
        appBar: ClinicAppBar(
          title: Text(widget.kind.sectionTitle),
          // رأس هادي موحّد (Phase 5C).
          backgroundColor: GhadeerTokens.mist,
          foregroundColor: GhadeerTokens.ink,
          surfaceTintColor: Colors.transparent,
        ),
        body: _loading
            ? const GhadeerSkeletonList()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      key: const Key('service_centers_search'),
                      controller: _search,
                      textDirection: TextDirection.rtl,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو العنوان أو الخدمة',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF7FBFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _chipButton('all', 'الكل'),
                        const SizedBox(width: 8),
                        _chipButton(
                          'near',
                          _locating ? 'جارٍ تحديد الموقع' : 'الأقرب',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? GhadeerStateMessage(
                            icon: _query.trim().isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.storefront_outlined,
                            title: _emptyMessage,
                            titleKey: const Key('service_centers_empty'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final center = list[index];
                              return _CenterTile(
                                center: center,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ServiceCenterProfilePage(
                                        center: center,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chipButton(String id, String label) {
    final selected = _chip == id;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _onChip(id),
    );
  }
}

class _CenterTile extends StatelessWidget {
  const _CenterTile({required this.center, required this.onTap});

  final ServiceCenter center;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = center.displayImage;
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: image.startsWith('http')
                      ? GhadeerNetImage(image, cacheWidth: 192)
                      : ColoredBox(
                          color: const Color(0xFFE8F4FC),
                          child: Icon(
                            center.kind.icon,
                            color: GhadeerHomeColors.secondary,
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
                      center.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF123B42),
                      ),
                    ),
                    if (center.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        center.address.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GhadeerHomeColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
