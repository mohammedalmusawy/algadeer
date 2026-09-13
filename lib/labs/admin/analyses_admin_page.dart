import 'package:flutter/material.dart';

import '../../models/lab_models.dart';
import '../labs_service.dart';
import '../../widgets/clinic_app_bar.dart';

class AnalysesAdminPage extends StatefulWidget {
  const AnalysesAdminPage({super.key});

  @override
  State<AnalysesAdminPage> createState() => _AnalysesAdminPageState();
}

class _AnalysesAdminPageState extends State<AnalysesAdminPage> {
  final _service = LabsService();
  final _search = TextEditingController();
  List<AnalysisItem> _items = [];
  bool _loading = true;

  /// true عندما لا يوجد جدول analyses ونعرض أسماءً من عمود tests فقط
  bool _fromPackagesOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final hasTable = await _service.hasAnalysesTable();
      final items = await _service.fetchAnalyses(query: _search.text);
      if (!mounted) return;
      setState(() {
        _fromPackagesOnly = !hasTable;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر التحميل: $e')));
    }
  }

  Future<void> _openForm({AnalysisItem? item}) async {
    final nameController = TextEditingController(text: item?.name ?? '');
    final shortController = TextEditingController(text: item?.shortName ?? '');
    final descController = TextEditingController(text: item?.description ?? '');
    var isActive = item?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(item == null ? 'إضافة تحليل' : 'تعديل تحليل'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم التحليل',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: shortController,
                        decoration: const InputDecoration(
                          labelText: 'اختصار (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'وصف (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('مفعّل'),
                        value: isActive,
                        onChanged: (v) => setDialogState(() => isActive = v),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) return;
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (saved != true) {
      nameController.dispose();
      shortController.dispose();
      descController.dispose();
      return;
    }

    if (_fromPackagesOnly) {
      nameController.dispose();
      shortController.dispose();
      descController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'قاموس التحاليل غير مفعّل بعد. نفّذ supabase/labs_schema.sql أو أضف التحاليل داخل نموذج الباقة.',
          ),
        ),
      );
      return;
    }

    try {
      await _service.upsertAnalysis(
        AnalysisItem(
          id: item?.id ?? '',
          name: nameController.text.trim(),
          shortName: shortController.text.trim(),
          description: descController.text.trim(),
          isActive: isActive,
        ),
        existingId: item?.id,
      );
      nameController.dispose();
      shortController.dispose();
      descController.dispose();
      _load();
    } catch (e) {
      nameController.dispose();
      shortController.dispose();
      descController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    }
  }

  Future<void> _delete(AnalysisItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف التحليل؟'),
          content: Text(
            'لا يمكن حذف «${item.name}» إذا كان مستخدماً داخل باقات. أزلّه من الباقات أولاً أو عطّله.',
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
      await _service.deleteAnalysis(item.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر الحذف (قد يكون مرتبطاً بباقات). عطّل التحليل بدلاً من ذلك.\n$e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('قاموس التحاليل'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        floatingActionButton: _fromPackagesOnly
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openForm(),
                backgroundColor: const Color(0xFF0FAFA3),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('تحليل جديد'),
              ),
        body: Column(
          children: [
            if (_fromPackagesOnly)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8D4A8)),
                ),
                child: const Text(
                  'عرض أسماء التحاليل المستخدمة داخل الباقات (عمود tests).\nلإدارة قاموس مستقل نفّذ ملف supabase/labs_schema.sql في Supabase.',
                  style: TextStyle(height: 1.4),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _search,
                onChanged: (_) => _load(),
                decoration: const InputDecoration(
                  labelText: 'بحث في التحاليل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                  ? const Center(child: Text('لا توجد تحاليل بعد'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if (item.shortName.isNotEmpty) item.shortName,
                                  item.isActive ? 'مفعّل' : 'معطّل',
                                ].join(' • '),
                              ),
                              trailing: _fromPackagesOnly
                                  ? null
                                  : PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _openForm(item: item);
                                        }
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
                              onTap: _fromPackagesOnly
                                  ? null
                                  : () => _openForm(item: item),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
