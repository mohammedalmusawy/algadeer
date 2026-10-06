import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../doctors/doctor_card_access_client.dart';
import '../home/ghadeer_home_colors.dart';
import '../services/content_conflict.dart';
import '../services/entity_access_pin_service.dart';
import '../widgets/clinic_app_bar.dart';
import 'pharmacies_store.dart';
import 'pharmacy_fit_image.dart';
import 'pharmacy_models.dart';
import 'pharmacy_package_form_page.dart';

/// قائمة باقات صيدلية محفوظة + مسار إنشاء منظم منفصل.
class PharmacyBundlesManagePage extends StatefulWidget {
  const PharmacyBundlesManagePage({
    super.key,
    required this.pharmacyId,
    this.ownerSession,
  });

  final String pharmacyId;
  final DoctorCardSession? ownerSession;

  @override
  State<PharmacyBundlesManagePage> createState() =>
      _PharmacyBundlesManagePageState();
}

class _PharmacyBundlesManagePageState extends State<PharmacyBundlesManagePage> {
  final _store = PharmaciesStore.instance;
  final _pins = EntityAccessPinService.instance;
  bool _loading = true;
  bool _saving = false;
  PharmacyItem? _pharmacy;
  List<PharmacyBundle> _bundles = [];
  int _revision = 1;

  String get _entityKey =>
      EntityAccessPinService.pharmacyKey(widget.pharmacyId);

  bool get _admin => widget.ownerSession?.isAdmin == true;

  bool get _canAdd =>
      _admin ||
      widget.ownerSession == null ||
      (widget.ownerSession?.allows('packages_add') ?? false) ||
      (widget.ownerSession?.allows('products') ?? false);

  bool get _canEdit =>
      _admin ||
      widget.ownerSession == null ||
      (widget.ownerSession?.allows('packages_edit') ?? false) ||
      (widget.ownerSession?.allows('products') ?? false);

  bool get _canDelete =>
      _admin ||
      widget.ownerSession == null ||
      (widget.ownerSession?.allows('packages_delete') ?? false) ||
      (widget.ownerSession?.allows('products') ?? false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pins.clearSession(_entityKey);
    super.dispose();
  }

  Future<void> _load() async {
    await _store.load();
    final p = _store.byId(widget.pharmacyId);
    PharmacyItem? fromCatalog;
    for (final e in PharmaciesCatalog.items) {
      if (e.id == widget.pharmacyId) {
        fromCatalog = e;
        break;
      }
    }
    final pharmacy = p ?? fromCatalog;
    if (!mounted) return;
    if (pharmacy == null) {
      setState(() {
        _loading = false;
        _pharmacy = null;
      });
      return;
    }
    // الباقات المحفوظة فقط في قائمة الإدارة؛ القوالب تبقى في مسار الإنشاء.
    final saved = pharmacy.bundles;
    setState(() {
      _pharmacy = pharmacy;
      _bundles = List<PharmacyBundle>.of(saved);
      _revision = pharmacy.contentRevision;
      _loading = false;
    });
  }

  Future<void> _openForm({PharmacyBundle? initial}) async {
    if (initial == null && !_canAdd) {
      _toast('ليس لديك صلاحية إضافة باقة');
      return;
    }
    if (initial != null && !_canEdit) {
      _toast('ليس لديك صلاحية تعديل باقة');
      return;
    }
    final result = await Navigator.push<PharmacyBundle?>(
      context,
      MaterialPageRoute(
        builder: (_) => PharmacyPackageFormPage(
          pharmacyId: widget.pharmacyId,
          initial: initial,
          ownerSession: widget.ownerSession,
          canAdd: _canAdd,
          canEdit: _canEdit,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final next = List<PharmacyBundle>.of(_bundles);
    final i = next.indexWhere((b) => b.id == result.id);
    if (i >= 0) {
      next[i] = result;
    } else {
      next.add(result);
    }
    await _persist(next);
  }

  Future<void> _deleteBundle(PharmacyBundle bundle) async {
    if (!_canDelete) {
      _toast('ليس لديك صلاحية حذف باقة محفوظة');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الباقة؟'),
          content: Text(
            'سيتم حذف «${bundle.title}» من الكتالوج المنشور بعد الحفظ. '
            'إزالة منتج من مسودة غير محفوظة لا تحتاج هذا التأكيد.',
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
    if (ok != true || !mounted) return;
    final next = [for (final b in _bundles) if (b.id != bundle.id) b];
    await _persist(next);
  }

  Uint8List _bytesFromDataUrl(String value) {
    final comma = value.indexOf(',');
    if (comma < 0) {
      throw const DoctorCardAccessException('الصورة غير مقبولة.');
    }
    return Uint8List.fromList(base64Decode(value.substring(comma + 1)));
  }

  Future<PharmacyBundle> _hostBundleImages(
    PharmacyBundle bundle,
    DoctorCardSession session,
  ) async {
    var cover = bundle.imageUrl;
    if (cover.startsWith('data:')) {
      cover = await DoctorCardAccessClient().uploadPharmacyAsset(
        session: session,
        bytes: _bytesFromDataUrl(cover),
      );
    }
    final products = <PharmacyPackageProduct>[];
    for (final product in bundle.resolvedProducts) {
      var image = product.imageUrl;
      if (image.startsWith('data:')) {
        image = await DoctorCardAccessClient().uploadPharmacyAsset(
          session: session,
          bytes: _bytesFromDataUrl(image),
        );
      }
      products.add(product.copyWith(imageUrl: image));
    }
    return bundle.copyWith(imageUrl: cover, products: products);
  }

  Future<void> _persist(List<PharmacyBundle> next) async {
    final p = _pharmacy;
    if (p == null) return;
    setState(() => _saving = true);
    try {
      var bundles = next;
      if (widget.ownerSession != null) {
        final uploaded = <PharmacyBundle>[];
        for (final bundle in next) {
          uploaded.add(await _hostBundleImages(bundle, widget.ownerSession!));
        }
        bundles = uploaded;
        await DoctorCardAccessClient().updateFields(
          session: widget.ownerSession!,
          fields: {
            'bundles': [for (final b in bundles) b.toMap()],
          },
          baseRevision: _revision,
        );
        _revision += 1;
        final published = p.copyWith(
          bundles: bundles,
          contentRevision: _revision,
        );
        await _store.cachePublished(published);
        _pharmacy = published;
      } else {
        await _store.upsert(p.copyWith(bundles: bundles));
        final refreshed = _store.byId(p.id) ?? p.copyWith(bundles: bundles);
        _pharmacy = refreshed;
        _revision = refreshed.contentRevision;
      }
      if (!mounted) return;
      setState(() => _bundles = bundles);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الباقات')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageForSaveError(e, 'تعذر الحفظ: $e'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: Text(_pharmacy?.name ?? 'باقات الصيدلية'),
        ),
        floatingActionButton: _canAdd
            ? FloatingActionButton.extended(
                onPressed: _saving ? null : () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة باقة'),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _pharmacy == null
                ? const Center(child: Text('الصيدلية غير موجودة'))
                : Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          'الباقات المحفوظة هنا. «إضافة باقة» يفتح الباقات المقترحة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: GhadeerHomeColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (_saving) const LinearProgressIndicator(minHeight: 2),
                      Expanded(
                        child: _bundles.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا باقات محفوظة بعد.\nاضغط «إضافة باقة» للبدء.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: GhadeerHomeColors.muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                                itemCount: _bundles.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final bundle = _bundles[index];
                                  final priceText = bundle.price > 0
                                      ? '${bundle.price} د.ع'
                                      : 'بدون سعر';
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: PharmacyFitImage(
                                          source: bundle.imageUrl,
                                          width: 48,
                                          height: 48,
                                          fallback: Icons.medication_outlined,
                                        ),
                                      ),
                                      title: Text(
                                        bundle.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '$priceText · ${bundle.resolvedProducts.length} منتج'
                                        '${bundle.isVisible ? '' : ' · مخفية'}',
                                      ),
                                      onTap: _canEdit
                                          ? () => _openForm(initial: bundle)
                                          : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_canEdit)
                                            IconButton(
                                              tooltip: 'تعديل',
                                              onPressed: _saving
                                                  ? null
                                                  : () => _openForm(
                                                        initial: bundle,
                                                      ),
                                              icon: const Icon(Icons.edit_outlined),
                                            ),
                                          if (_canDelete)
                                            IconButton(
                                              tooltip: 'حذف',
                                              onPressed: _saving
                                                  ? null
                                                  : () => _deleteBundle(bundle),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Color(0xFFC94A4A),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
