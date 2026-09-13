import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/radiology_models.dart';
import '../utils/responsive.dart';
import '../widgets/clinic_app_bar.dart';
import 'radiology_profile_page.dart';
import 'radiology_service.dart';
import 'widgets/radiology_card.dart';

/// واجهة الأشعة العامة — قائمة مراكز الأشعة.
class RadiologyPage extends StatefulWidget {
  const RadiologyPage({super.key});

  @override
  State<RadiologyPage> createState() => _RadiologyPageState();
}

class _RadiologyPageState extends State<RadiologyPage> {
  final _service = RadiologyService();
  List<RadiologyCenter> _centers = [];
  final Set<String> _favoriteIds = <String>{};
  bool _loading = true;
  String? _error;

  static const _favKey = 'favoriteRadiologyIds';

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

  Future<void> _toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
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
      final centers = await _service.fetchPublicCenters();
      if (!mounted) return;
      setState(() {
        _centers = centers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'تعذر تحميل الأشعة. نفّذ supabase/radiology_centers_schema.sql';
      });
    }
  }

  void _openCenter(RadiologyCenter center) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RadiologyProfilePage(center: center),
      ),
    ).then((_) => _loadFavorites());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBFC),
        appBar: ClinicAppBar(
          title: const Text('الأشعة'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
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
                : _centers.isEmpty
                    ? const Center(
                        child: Text('لا توجد مراكز أشعة مفعّلة حالياً'),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            AppResponsive.pagePadding(context),
                            12,
                            AppResponsive.pagePadding(context),
                            24,
                          ),
                          itemCount: _centers.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final center = _centers[index];
                            return ClinicRadiologyCard(
                              center: center,
                              isFavorite: _favoriteIds.contains(center.id),
                              onToggleFavorite: () =>
                                  _toggleFavorite(center.id),
                              onOpen: () => _openCenter(center),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
