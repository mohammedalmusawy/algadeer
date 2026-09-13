import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lab_models.dart';
import '../settings/settings_page.dart';
import '../utils/responsive.dart';
import '../widgets/clinic_app_bar.dart';
import 'lab_profile_page.dart';
import 'labs_service.dart';
import 'widgets/lab_card.dart';

/// واجهة المختبرات: رئيسية · مختبراتي · المزيد (مثل تنظيم واجهة الأطباء).
class LabsPage extends StatefulWidget {
  const LabsPage({super.key});

  @override
  State<LabsPage> createState() => _LabsPageState();
}

class _LabsPageState extends State<LabsPage> {
  final _service = LabsService();
  List<LabItem> _labs = [];
  final Set<String> _favoriteIds = <String>{};
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;

  static const _favKey = 'favoriteLabIds';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _load();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_favKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _favoriteIds
        ..clear()
        ..addAll(ids);
    });
  }

  Future<void> _toggleFavorite(String labId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteIds.contains(labId)) {
        _favoriteIds.remove(labId);
      } else {
        _favoriteIds.add(labId);
      }
    });
    await prefs.setStringList(_favKey, _favoriteIds.toList());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final labs = await _service.fetchPublicLabs();
      if (!mounted) return;
      setState(() {
        _labs = labs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل المختبرات. تأكد من تنفيذ جداول Supabase.';
      });
    }
  }

  void _openLab(LabItem lab) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabProfilePage(lab: lab)),
    ).then((_) => _loadFavorites());
  }

  Widget _labCard(LabItem lab) {
    return ClinicLabCard(
      lab: lab,
      isFavorite: _favoriteIds.contains(lab.id),
      onToggleFavorite: () => _toggleFavorite(lab.id),
      onOpenPackages: () => _openLab(lab),
    );
  }

  List<LabItem> get _favoriteLabs =>
      _labs.where((l) => _favoriteIds.contains(l.id)).toList();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FAFA),
        appBar: ClinicAppBar(
          title: Text(_tabIndex == 1 ? 'مختبراتي' : 'المختبرات'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _tabIndex.clamp(0, 1),
            children: [
              _buildHomeTab(),
              _buildFavoritesTab(),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHomeTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _load,
                  child: const Text('إعادة المحاولة'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_labs.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد مختبرات مفعّلة حالياً',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF0FAFA3),
      onRefresh: _load,
      child: _labsList(_labs),
    );
  }

  Widget _buildFavoritesTab() {
    final favorites = _favoriteLabs;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (favorites.isEmpty) {
      return const Center(
        child: Text(
          'لم تحفظ أي مختبر بعد',
          style: TextStyle(color: Color(0xFF6B7C80)),
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF0FAFA3),
      onRefresh: () async {
        await _loadFavorites();
        await _load();
      },
      child: _labsList(favorites),
    );
  }

  Widget _labsList(List<LabItem> labs) {
    final pad = AppResponsive.pagePadding(context);
    final cols = AppResponsive.labColumns(context);
    if (cols <= 1) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(pad, 10, pad, 8),
        itemCount: labs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _labCard(labs[index]),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(pad, 10, pad, 8),
      itemCount: labs.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 132,
      ),
      itemBuilder: (context, index) => _labCard(labs[index]),
    );
  }

  Widget _buildBottomNav() {
    const teal = Color(0xFF0FAFA3);
    const muted = Color(0xFF8A9A9E);

    Widget item({
      required int index,
      required IconData icon,
      required IconData activeIcon,
      required String label,
      VoidCallback? onTapOverride,
    }) {
      final active = _tabIndex == index;
      return Expanded(
        child: InkWell(
          onTap: onTapOverride ?? () => setState(() => _tabIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? activeIcon : icon,
                  color: active ? teal : muted,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
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
        child: Row(
          children: [
            item(
              index: 0,
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'الرئيسية',
              onTapOverride: () => setState(() => _tabIndex = 0),
            ),
            item(
              index: 1,
              icon: Icons.favorite_border_rounded,
              activeIcon: Icons.favorite_rounded,
              label: 'مختبراتي',
            ),
            item(
              index: 2,
              icon: Icons.more_horiz_rounded,
              activeIcon: Icons.more_horiz_rounded,
              label: 'المزيد',
              onTapOverride: _openMoreSheet,
            ),
          ],
        ),
      ),
    );
  }

  void _openMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9E4E6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('تحديث المختبرات'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _load();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.favorite_rounded),
                    title: const Text('مختبراتي المفضلة'),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _tabIndex = 1);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_rounded),
                    title: const Text('الإعدادات'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
