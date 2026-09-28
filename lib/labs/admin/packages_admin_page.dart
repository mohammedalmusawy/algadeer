import 'package:flutter/material.dart';

import '../../models/lab_models.dart';
import '../../services/entity_access_pin_service.dart';
import '../labs_service.dart';
import '../widgets/package_hero_image.dart';
import 'package_form_page.dart';
import '../../widgets/clinic_app_bar.dart';

class PackagesAdminPage extends StatefulWidget {
  const PackagesAdminPage({super.key, this.lockedLabId, this.lockedLabName});

  /// إن وُجد: المختبر يدير باقاته فقط (بعد الرقم السري).
  final String? lockedLabId;
  final String? lockedLabName;

  @override
  State<PackagesAdminPage> createState() => _PackagesAdminPageState();
}

class _PackagesAdminPageState extends State<PackagesAdminPage> {
  final _service = LabsService();
  final _pins = EntityAccessPinService.instance;
  List<LabPackageItem> _packages = [];
  List<LabItem> _labs = [];
  String? _filterLabId;
  bool _loading = true;

  bool get _locked =>
      widget.lockedLabId != null && widget.lockedLabId!.isNotEmpty;

  String? get _entityKey =>
      _locked ? EntityAccessPinService.labKey(widget.lockedLabId!) : null;

  @override
  void initState() {
    super.initState();
    if (_locked) _filterLabId = widget.lockedLabId;
    _load();
  }

  @override
  void dispose() {
    // تُغلق الجلسة عند الخروج من الإعدادات فقط — مو أثناء الشغل.
    final key = _entityKey;
    if (key != null) _pins.clearSession(key);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final labs = await _service.fetchAllLabs();
      final labId = _locked ? widget.lockedLabId : _filterLabId;
      final packages = await _service.fetchAllPackages(labId: labId);
      if (!mounted) return;
      setState(() {
        _labs = _locked
            ? labs.where((l) => l.id == widget.lockedLabId).toList()
            : labs;
        _packages = packages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر التحميل: $e')));
    }
  }

  String _labName(String labId) {
    for (final lab in _labs) {
      if (lab.id == labId) return lab.name;
    }
    return widget.lockedLabName ?? 'مختبر';
  }

  Future<void> _openForm({LabPackageItem? package}) async {
    final labsForForm = _locked
        ? _labs
        : await _service.fetchAllLabs();
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PackageFormPage(
          package: package,
          labs: labsForForm.isNotEmpty ? labsForForm : _labs,
          lockedLabId: widget.lockedLabId,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _toggleVisible(LabPackageItem package) async {
    final next = !package.isActive;
    try {
      await _service.setPackageActive(package.id, next);
      if (!mounted) return;
      setState(() {
        final i = _packages.indexWhere((p) => p.id == package.id);
        if (i >= 0) {
          _packages[i] = package.copyWith(isActive: next);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next ? 'الباقة ظاهرة للزبون الآن' : 'تم إخفاء الباقة عن الزبون',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تغيير الظهور: $e')),
      );
    }
  }

  Future<void> _delete(LabPackageItem package) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الباقة؟'),
          content: Text('سيتم حذف «${package.name}» وعلاقاتها بالتحاليل فقط.'),
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
      await _service.deletePackage(package.id);
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
        backgroundColor: const Color(0xFFF4F8F8),
        appBar: ClinicAppBar(
          title: Text(
            _locked
                ? 'باقات ${widget.lockedLabName ?? 'المختبر'}'
                : 'باقات المختبرات',
          ),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _labs.isEmpty ? null : () => _openForm(),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('إضافة باقة جديدة'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (!_locked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use
                    value: _filterLabId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'تصفية حسب المختبر',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('كل المختبرات'),
                      ),
                      ..._labs.map(
                        (lab) => DropdownMenuItem<String?>(
                          value: lab.id,
                          child:
                              Text(lab.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _filterLabId = value);
                      _load();
                    },
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _packages.isEmpty
                    ? const Center(child: Text('لا توجد باقات بعد'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _packages.length,
                          itemBuilder: (context, index) {
                            final pkg = _packages[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AdminPackageCard(
                                package: pkg,
                                labName: _labName(pkg.labId),
                                onEdit: () => _openForm(package: pkg),
                                onDelete: () => _delete(pkg),
                                onToggleVisible: () => _toggleVisible(pkg),
                              ),
                            );
                          },
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

class _AdminPackageCard extends StatelessWidget {
  const _AdminPackageCard({
    required this.package,
    required this.labName,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleVisible,
  });

  final LabPackageItem package;
  final String labName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleVisible;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: package.isActive ? Colors.white : const Color(0xFFF3F3F3),
      elevation: 1.5,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: package.isActive
                  ? const Color(0xFFE4EEEE)
                  : const Color(0xFFD0D0D0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                            color: Color(0xFF123B42),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            labName,
                            package.isActive ? 'ظاهرة' : 'مخفية',
                            '${package.analysesCount} تحليل',
                          ].join(' • '),
                          style: TextStyle(
                            color: package.isActive
                                ? const Color(0xFF5B6C70)
                                : const Color(0xFFC94A4A),
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (package.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            package.description.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF708084),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        PackagePriceBlock(package: package),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      IconButton(
                        tooltip: package.isActive
                            ? 'إخفاء الباقة عن الزبون'
                            : 'إظهار الباقة للزبون',
                        onPressed: onToggleVisible,
                        icon: Icon(
                          package.isActive
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_outlined,
                          color: package.isActive
                              ? const Color(0xFF0FAFA3)
                              : const Color(0xFF8A9A9E),
                        ),
                      ),
                      PackageHeroImage(
                        packageName: package.name,
                        imageUrl: package.imageUrl,
                        isFeatured: package.isFeatured,
                        width: 104,
                        height: 132,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onToggleVisible,
                      icon: Icon(
                        package.isActive
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_rounded,
                        size: 18,
                      ),
                      label: Text(
                        package.isActive ? 'إخفاء الباقة' : 'إظهار الباقة',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF123B42),
                        side: const BorderSide(color: Color(0xFF9AA6A8)),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('تعديل'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0FAFA3),
                        side: const BorderSide(color: Color(0xFF0FAFA3)),
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'حذف',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFC94A4A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
