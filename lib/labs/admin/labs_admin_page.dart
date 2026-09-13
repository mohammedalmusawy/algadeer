import 'package:flutter/material.dart';

import '../../models/lab_models.dart';
import '../../doctors/app_stats_admin_page.dart';
import '../lab_default_images.dart';
import '../labs_service.dart';
import '../widgets/lab_network_or_asset_image.dart';
import 'lab_form_page.dart';
import '../../widgets/clinic_app_bar.dart';

class LabsAdminPage extends StatefulWidget {
  const LabsAdminPage({super.key});

  @override
  State<LabsAdminPage> createState() => _LabsAdminPageState();
}

class _LabsAdminPageState extends State<LabsAdminPage> {
  final _service = LabsService();
  List<LabItem> _labs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final labs = await _service.fetchAllLabs();
      if (!mounted) return;
      setState(() {
        _labs = labs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر التحميل: $e')));
    }
  }

  Future<void> _openForm({LabItem? lab}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LabFormPage(lab: lab)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(LabItem lab) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المختبر؟'),
          content: Text(
            'سيتم حذف «${lab.name}» وجميع باقاته المرتبطة. التحاليل العامة لن تُحذف.',
          ),
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
      await _service.tryDeleteStorageUrl(lab.imageUrl);
      await _service.deleteLab(lab.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('المختبرات'),
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
          label: const Text('إضافة مختبر'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _labs.isEmpty
            ? const Center(child: Text('لا توجد مختبرات بعد'))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: _labs.length,
                  itemBuilder: (context, index) {
                    final lab = _labs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              leading: Builder(
                                builder: (context) {
                                  final imageUrl = LabDefaultImages.displayUrl(
                                    imageUrl: lab.imageUrl,
                                    labId: lab.id,
                                  );
                                  final provider = labImageProvider(imageUrl);
                                  return CircleAvatar(
                                    backgroundColor: const Color(0xFFEAF4F3),
                                    backgroundImage: provider,
                                    child: provider == null
                                        ? const Icon(Icons.biotech_rounded)
                                        : null,
                                  );
                                },
                              ),
                              title: Text(
                                lab.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  lab.isActive ? 'مفعّل' : 'مخفي',
                                  'ترتيب: ${lab.displayOrder}',
                                  if (lab.address.isNotEmpty) lab.address,
                                ].join(' • '),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _openForm(lab: lab);
                                  if (value == 'delete') _delete(lab);
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
                              onTap: () => _openForm(lab: lab),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (ctx) => LabPeriodStatsDialog(
                                      labId: lab.id,
                                      labName: lab.name,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.bar_chart_rounded),
                                label: const Text('الإحصائيات'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
