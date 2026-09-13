import 'package:flutter/material.dart';

import '../../models/radiology_models.dart';
import '../../widgets/clinic_app_bar.dart';
import '../radiology_default_images.dart';
import '../radiology_service.dart';
import '../widgets/radiology_network_or_asset_image.dart';
import 'radiology_form_page.dart';

class RadiologyAdminPage extends StatefulWidget {
  const RadiologyAdminPage({super.key});

  @override
  State<RadiologyAdminPage> createState() => _RadiologyAdminPageState();
}

class _RadiologyAdminPageState extends State<RadiologyAdminPage> {
  final _service = RadiologyService();
  List<RadiologyCenter> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.fetchAllCenters();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التحميل: $e')),
      );
    }
  }

  Future<void> _openForm({RadiologyCenter? center}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RadiologyFormPage(center: center)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(RadiologyCenter center) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف مركز الأشعة؟'),
          content: Text('سيتم حذف «${center.name}».'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _service.tryDeleteStorageUrl(center.imageUrl);
      await _service.deleteCenter(center.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحذف: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('إعدادات الأشعة'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('إضافة مركز'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'لا توجد مراكز أشعة بعد.\nأضف مركزًا أو نفّذ supabase/radiology_centers_schema.sql',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final imageUrl = RadiologyDefaultImages.displayUrl(
                          imageUrl: item.imageUrl,
                          centerId: item.id,
                        );
                        final provider = radiologyImageProvider(imageUrl);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFEAF4F3),
                              backgroundImage: provider,
                              child: provider == null
                                  ? const Icon(Icons.radar_outlined)
                                  : null,
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              [
                                item.isActive ? 'مفعّل' : 'مخفي',
                                'ترتيب: ${item.displayOrder}',
                                if (item.address.isNotEmpty) item.address,
                              ].join(' • '),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _openForm(center: item);
                                if (value == 'delete') _delete(item);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('تعديل'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف'),
                                ),
                              ],
                            ),
                            onTap: () => _openForm(center: item),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
