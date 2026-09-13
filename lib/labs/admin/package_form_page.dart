import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../branding/ghadeer_brand_mark.dart';
import '../../models/lab_models.dart';
import '../labs_service.dart';
import '../package_image_library.dart';
import '../widgets/package_hero_image.dart';
import '../../widgets/clinic_app_bar.dart';

class PackageFormPage extends StatefulWidget {
  const PackageFormPage({super.key, this.package, required this.labs});

  final LabPackageItem? package;
  final List<LabItem> labs;

  @override
  State<PackageFormPage> createState() => _PackageFormPageState();
}

class _PackageFormPageState extends State<PackageFormPage> {
  final _service = LabsService();
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _nameFocus = FocusNode();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  final _addAnalysisKey = GlobalKey();
  final Map<String, TextEditingController> _descControllers = {};

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _oldPrice;
  late final TextEditingController _newPrice;
  late final TextEditingController _order;

  String? _labId;
  bool _isActive = true;
  bool _isFeatured = false;
  bool _showOnHome = false;
  bool _saving = false;
  bool _loadingAnalyses = true;
  bool _hasAnalysesTable = false;
  bool _showTemplateSuggestions = true;

  PackageTemplateItem? _appliedTemplate;
  List<PackageTemplateItem> _allTemplates = const [];
  List<PackageTemplateItem> _templateSuggestions = const [];

  List<AnalysisItem> _catalog = [];
  List<AnalysisItem> _analysisSuggestions = [];
  final List<AnalysisItem> _selected = [];

  /// تحاليل مقترحة من القالب (قد لا تكون كلها في القاموس بعد).
  List<AnalysisItem> _templateSuggestedAnalyses = [];

  List<PackageImageItem> _imageCatalog = const [];
  PackageImageItem? _suggestedImage;
  String _imageUrl = '';
  late final TextEditingController _imageUrlField;
  Uint8List? _pickedBytes;
  String? _pickedName;
  bool _acceptedSuggestion = false;

  bool get _isEditing => widget.package != null;

  String get _previewImageUrl {
    if (_pickedBytes != null) return '';
    if (_imageUrl.trim().isNotEmpty) return _imageUrl.trim();
    return '';
  }

  bool get _hasChosenImage =>
      _pickedBytes != null || _imageUrl.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final pkg = widget.package;
    _name = TextEditingController(text: pkg?.name ?? '');
    _description = TextEditingController(text: pkg?.description ?? '');
    _oldPrice = TextEditingController(text: labPriceFieldText(pkg?.oldPrice));
    _newPrice = TextEditingController(text: labPriceFieldText(pkg?.newPrice));
    _order = TextEditingController(text: '${pkg?.displayOrder ?? 0}');
    _labId =
        pkg?.labId ?? (widget.labs.isNotEmpty ? widget.labs.first.id : null);
    _isActive = pkg?.isActive ?? true;
    _isFeatured = pkg?.isFeatured ?? false;
    _showOnHome = pkg?.showOnHome ?? false;
    _imageUrl = GhadeerBranding.normalizeEntityImageUrl(pkg?.imageUrl.trim() ?? '');
    _imageUrlField = TextEditingController(text: _imageUrl);
    _showTemplateSuggestions = !_isEditing;
    _refreshTemplateSuggestions(_name.text);
    _name.addListener(_onNameChanged);
    _loadAnalyses();
  }

  void _refreshSuggestedImage([String? rawName]) {
    final name = (rawName ?? _name.text).trim();
    final catalog = _imageCatalog.isNotEmpty
        ? _imageCatalog
        : kBuiltinPackageImages;
    _suggestedImage = suggestPackageImage(catalog, name);
  }

  void _onNameChanged() {
    if (!_showTemplateSuggestions) {
      setState(_refreshSuggestedImage);
      return;
    }
    _refreshTemplateSuggestions(_name.text);
    setState(_refreshSuggestedImage);
  }

  void _refreshTemplateSuggestions(String query) {
    final next = rankPackageTemplates(_allTemplates, query);
    setState(() => _templateSuggestions = next);
  }

  Future<void> _loadAnalyses() async {
    try {
      final hasTable = await _service.hasAnalysesTable();
      final catalog = hasTable
          ? await _service.fetchAnalyses(activeOnly: true)
          : <AnalysisItem>[];
      final templates = await _service.fetchPackageTemplates();
      final images = await _service.fetchPackageImages();

      final selected = <AnalysisItem>[];
      if (widget.package != null) {
        try {
          final details = await _service.fetchPackageDetails(
            widget.package!.id,
          );
          if (details.analyses.isNotEmpty) {
            selected.addAll(details.analyses);
          } else {
            for (final name in details.testNames) {
              final match = _findInCatalog(catalog, name);
              if (match != null) selected.add(match);
            }
          }
        } catch (_) {
          selected.addAll(widget.package!.analyses);
        }
      }

      final unique = <AnalysisItem>[];
      final seen = <String>{};
      for (final item in selected) {
        final key = item.id.isNotEmpty ? item.id : item.name.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        unique.add(item);
      }

      if (!mounted) return;
      setState(() {
        _hasAnalysesTable = hasTable;
        _catalog = catalog;
        _allTemplates = templates;
        _imageCatalog = images;
        _refreshSuggestedImage();
        for (final id in _descControllers.keys.toList()) {
          _disposeDescController(id);
        }
        _selected
          ..clear()
          ..addAll(unique);
        for (final item in _selected) {
          _descControllerFor(item);
        }
        _loadingAnalyses = false;
        _templateSuggestions = rankPackageTemplates(templates, _name.text);
        _updateAnalysisSuggestions(_searchController.text);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAnalyses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل التحاليل: ${formatLabSupabaseError(e)}'),
        ),
      );
    }
  }

  AnalysisItem? _findInCatalog(List<AnalysisItem> catalog, String raw) {
    final ranked = rankAnalysisMatches(catalog, raw, limit: 1);
    if (ranked.isNotEmpty) {
      final top = ranked.first;
      final q = raw.trim().toLowerCase();
      if (top.name.toLowerCase() == q ||
          top.shortName.toLowerCase() == q ||
          top.nameAr.toLowerCase() == q ||
          top.aliases.any((a) => a.toLowerCase() == q)) {
        return top;
      }
    }
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final a in catalog) {
      if (a.name.toLowerCase() == q || a.shortName.toLowerCase() == q) {
        return a;
      }
    }
    return null;
  }

  void _applyTemplate(PackageTemplateItem template) {
    FocusScope.of(context).unfocus();
    final matched = <AnalysisItem>[];
    final missing = <String>[];

    if (template.analyses.isNotEmpty) {
      for (final item in template.analyses) {
        AnalysisItem? found;
        if (item.id.length >= 32) {
          for (final a in _catalog) {
            if (a.id == item.id) {
              found = a;
              break;
            }
          }
        }
        found ??= _findInCatalog(_catalog, item.name);
        if (found != null) {
          if (!matched.any((e) => e.id == found!.id)) matched.add(found);
        } else {
          missing.add(item.name);
        }
      }
    }

    setState(() {
      _appliedTemplate = template;
      _showTemplateSuggestions = false;
      _templateSuggestedAnalyses = List<AnalysisItem>.from(
        matched.isNotEmpty ? matched : template.analyses,
      );
      _name.text = template.name;
      if (_description.text.trim().isEmpty) {
        _description.text = template.description;
      }
      _refreshSuggestedImage(template.name);
      // لا نطبّق الصورة تلقائيًا — المدير يوافق عبر «استخدام الصورة المقترحة»
      for (final id in _descControllers.keys.toList()) {
        _disposeDescController(id);
      }
      _selected
        ..clear()
        ..addAll(matched);
      for (final item in _selected) {
        _descControllerFor(item);
      }
      _searchController.clear();
      _analysisSuggestions = [];
    });

    if (missing.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تطبيق القالب. بعض التحاليل غير موجودة في القاموس: ${missing.join(', ')}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _updateAnalysisSuggestions(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _analysisSuggestions = []);
      return;
    }
    final selectedIds = _selected.map((e) => e.id).toSet();
    setState(() {
      _analysisSuggestions = rankAnalysisMatches(
        _catalog,
        q,
        limit: 16,
        excludeIds: selectedIds,
      );
    });
  }

  TextEditingController _descControllerFor(AnalysisItem item) {
    final existing = _descControllers[item.id];
    if (existing != null) return existing;
    final created = TextEditingController(text: item.descriptionAr);
    _descControllers[item.id] = created;
    return created;
  }

  void _disposeDescController(String id) {
    final c = _descControllers.remove(id);
    c?.dispose();
  }

  void _focusAddAnalysis() {
    final ctx = _addAnalysisKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    }
    _searchFocus.requestFocus();
  }

  void _setSelectedDescription(String analysisId, String descriptionAr) {
    final index = _selected.indexWhere((e) => e.id == analysisId);
    if (index < 0) return;
    final updated = _selected[index].copyWith(descriptionAr: descriptionAr);
    _selected[index] = updated;
    final ctrl = _descControllers[analysisId];
    if (ctrl != null && ctrl.text != descriptionAr) {
      ctrl.text = descriptionAr;
    }
    final catalogIndex = _catalog.indexWhere((e) => e.id == analysisId);
    if (catalogIndex >= 0) {
      _catalog[catalogIndex] = _catalog[catalogIndex].copyWith(
        descriptionAr: descriptionAr,
      );
    }
  }

  Future<void> _openEditAnalysisSheet(AnalysisItem item) async {
    final draft = TextEditingController(text: _descControllerFor(item).text);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final inset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E4E4),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'تعديل وصف التحليل',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF123B42),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0FAFA3),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: draft,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'وصف التحليل بالعربي',
                  hintText: 'اكتب وصف التحليل بالعربي...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFD7E4E4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF0FAFA3),
                      width: 1.6,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0FAFA3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'حفظ الوصف',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    final text = draft.text.trim();
    draft.dispose();
    if (saved != true || !mounted) return;

    setState(() => _setSelectedDescription(item.id, text));

    if (item.id.length >= 32) {
      try {
        await _service.updateAnalysisDescriptionAr(
          analysisId: item.id,
          descriptionAr: text,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر حفظ الوصف في السيرفر: ${formatLabSupabaseError(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _syncSelectedDescriptions() async {
    for (final item in _selected) {
      if (item.id.length < 32) continue;
      final text = (_descControllers[item.id]?.text ?? item.descriptionAr)
          .trim();
      await _service.updateAnalysisDescriptionAr(
        analysisId: item.id,
        descriptionAr: text,
      );
      _setSelectedDescription(item.id, text);
    }
  }

  void _addAnalysis(AnalysisItem item) {
    if (_selected.any((e) => e.id == item.id)) return;
    if (_selected.any((e) => e.name.toLowerCase() == item.name.toLowerCase())) {
      return;
    }
    setState(() {
      _selected.add(item);
      _descControllerFor(item);
      _searchController.clear();
      _analysisSuggestions = [];
    });
    _searchFocus.requestFocus();
  }

  void _removeAnalysis(String id) {
    setState(() {
      _selected.removeWhere((e) => e.id == id);
      _disposeDescController(id);
      _updateAnalysisSuggestions(_searchController.text);
    });
  }

  void _toggleTemplateSuggestion(AnalysisItem item) {
    final found = item.id.length >= 32
        ? item
        : (_findInCatalog(_catalog, item.name) ?? item);
    if (found.id.length < 32 && !_catalog.any((a) => a.id == found.id)) {
      final resolved = _findInCatalog(_catalog, found.name);
      if (resolved == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«${found.name}» غير موجود في قاموس التحاليل'),
          ),
        );
        return;
      }
      _toggleById(resolved);
      return;
    }
    _toggleById(found);
  }

  void _toggleById(AnalysisItem found) {
    final exists = _selected.any((e) => e.id == found.id);
    setState(() {
      if (exists) {
        _selected.removeWhere((e) => e.id == found.id);
        _disposeDescController(found.id);
      } else {
        _selected.add(found);
        _descControllerFor(found);
      }
    });
  }

  void _acceptSuggestedImage() {
    final suggested = _suggestedImage;
    if (suggested == null || suggested.imageUrl.trim().isEmpty) return;
    setState(() {
      _pickedBytes = null;
      _pickedName = null;
      _imageUrl = GhadeerBranding.normalizeEntityImageUrl(
        suggested.imageUrl.trim(),
      );
      _imageUrlField.text = _imageUrl;
      _acceptedSuggestion = true;
    });
  }

  void _clearPackageImage() {
    setState(() {
      _pickedBytes = null;
      _pickedName = null;
      _imageUrl = '';
      _imageUrlField.text = '';
      _acceptedSuggestion = false;
    });
  }

  Future<void> _pickDeviceImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _pickedName = image.name;
      _imageUrl = '';
      _imageUrlField.text = '';
      _acceptedSuggestion = false;
    });
  }

  void _selectLibraryImage(PackageImageItem item) {
    setState(() {
      _pickedBytes = null;
      _pickedName = null;
      _imageUrl = GhadeerBranding.normalizeEntityImageUrl(item.imageUrl.trim());
      _imageUrlField.text = _imageUrl;
      _acceptedSuggestion = false;
    });
  }

  Future<void> _openImageSheet() async {
    final catalog = _imageCatalog.isNotEmpty
        ? _imageCatalog
        : kBuiltinPackageImages;
    final ranked = rankPackageImages(catalog, _name.text, limit: 18);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7E4E4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تغيير صورة الباقة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF123B42),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('استخدام المقترحة'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _acceptSuggestedImage();
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('رفع من الجهاز'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _pickDeviceImage();
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('إزالة الصورة'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _clearPackageImage();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'مكتبة الصور',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF123B42),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: ranked.length,
                      itemBuilder: (context, index) {
                        final item = ranked[index];
                        final selected =
                            _imageUrl == item.imageUrl && _pickedBytes == null;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(ctx);
                            _selectLibraryImage(item);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF0FAFA3)
                                    : const Color(0xFFE4EEEE),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: GhadeerResolvedImage(
                                    item.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      final style = packagePlaceholderStyle(
                                        item.title,
                                      );
                                      return ColoredBox(
                                        color: style.bg,
                                        child: Icon(
                                          style.icon,
                                          color: style.accent,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
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
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_labId == null || _labId!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اختر المختبر')));
      return;
    }

    setState(() => _saving = true);
    try {
      // مزامنة أوصاف التحاليل من الحقول المحلية قبل حفظ الباقة
      for (var i = 0; i < _selected.length; i++) {
        final item = _selected[i];
        final text = (_descControllers[item.id]?.text ?? item.descriptionAr)
            .trim();
        _selected[i] = item.copyWith(descriptionAr: text);
      }

      try {
        await _syncSelectedDescriptions();
      } catch (e) {
        debugPrint('description_ar sync warning: $e');
      }

      var imageUrl = GhadeerBranding.normalizeEntityImageUrl(_imageUrl.trim());
      final oldUrl = widget.package?.imageUrl.trim() ?? '';

      if (_pickedBytes != null) {
        imageUrl = await _service.uploadPackageImage(
          bytes: _pickedBytes!,
          originalName: _pickedName ?? 'package.jpg',
          packageId: widget.package?.id,
        );
      }

      final package = LabPackageItem(
        id: widget.package?.id ?? '',
        labId: _labId!,
        name: _name.text.trim(),
        description: _description.text.trim(),
        oldPrice: labParsePrice(_oldPrice.text),
        newPrice: labParsePrice(_newPrice.text),
        imageUrl: GhadeerBranding.normalizeEntityImageUrl(imageUrl),
        isActive: _isActive,
        displayOrder: labParseDisplayOrder(_order.text),
        isFeatured: _isFeatured,
        showOnHome: _showOnHome,
        testNames: _selected.map((e) => e.name).toList(),
        analyses: List<AnalysisItem>.from(_selected),
      );

      await _service.upsertPackage(
        package,
        existingId: widget.package?.id,
        analysisIds: _selected.map((e) => e.id).toList(),
        testNames: _selected.map((e) => e.name).toList(),
      );

      if (_pickedBytes != null &&
          oldUrl.isNotEmpty &&
          oldUrl != imageUrl &&
          oldUrl.contains('/packages/')) {
        await _service.tryDeleteStorageUrl(oldUrl);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ الباقة بنجاح')));
      Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint('package form save error: $e\n$st');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الحفظ: ${formatLabSupabaseError(e)}'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _description.dispose();
    _oldPrice.dispose();
    _newPrice.dispose();
    _order.dispose();
    _imageUrlField.dispose();
    _searchController.dispose();
    _nameFocus.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    for (final c in _descControllers.values) {
      c.dispose();
    }
    _descControllers.clear();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {Widget? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD7E4E4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF0FAFA3), width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIcon: prefixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFF4F8F8),
        appBar: ClinicAppBar(
          title: Text(_isEditing ? 'تعديل باقة' : 'إضافة باقة'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _sectionLabel('المختبر'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _labId,
                        isExpanded: true,
                        decoration: _fieldDecoration('اختر المختبر'),
                        items: widget.labs
                            .map(
                              (lab) => DropdownMenuItem(
                                value: lab.id,
                                child: Text(
                                  lab.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _labId = value),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'اختر المختبر' : null,
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel('اسم الباقة'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _name,
                        focusNode: _nameFocus,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _fieldDecoration('مثال: باقة تساقط الشعر'),
                        onTap: () {
                          setState(() => _showTemplateSuggestions = true);
                          _refreshTemplateSuggestions(_name.text);
                        },
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'أدخل اسم الباقة'
                            : null,
                      ),
                      if (_showTemplateSuggestions &&
                          _templateSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'اقتراحات قوالب (لن تُحفظ حتى تضغط حفظ)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5B6C70),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._templateSuggestions.map(_templateTile),
                      ],
                      if (_appliedTemplate != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F7F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'تم اختيار قالب: ${_appliedTemplate!.name}\nعدّل التحاليل كما تريد ثم احفظ.',
                            style: const TextStyle(
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0C7F76),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _buildPackageImageSection(),
                      const SizedBox(height: 20),
                      _sectionLabel('الوصف'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _description,
                        minLines: 2,
                        maxLines: 4,
                        decoration: _fieldDecoration('وصف مختصر للباقة'),
                      ),
                      const SizedBox(height: 16),
                      _sectionLabel('الأسعار'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _oldPrice,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration('السعر القديم'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPrice,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration('السعر الجديد'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _order,
                        keyboardType: TextInputType.number,
                        decoration: _fieldDecoration('ترتيب الظهور'),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'تفعيل الباقة',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'باقة مميزة',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        value: _isFeatured,
                        onChanged: (v) => setState(() => _isFeatured = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'إظهار في الصفحة الرئيسية',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        value: _showOnHome,
                        onChanged: (v) => setState(() => _showOnHome = v),
                      ),
                      if (_templateSuggestedAnalyses.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _sectionLabel('التحاليل المقترحة'),
                        const SizedBox(height: 8),
                        ..._templateSuggestedAnalyses.map((item) {
                          final resolved =
                              _findInCatalog(_catalog, item.name) ?? item;
                          final selected = _selected.any(
                            (e) =>
                                e.id == resolved.id ||
                                e.name.toLowerCase() ==
                                    resolved.name.toLowerCase(),
                          );
                          final available =
                              resolved.id.length >= 32 ||
                              _findInCatalog(_catalog, item.name) != null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: available
                                    ? () => _toggleTemplateSuggestion(resolved)
                                    : null,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 56,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF0FAFA3)
                                          : const Color(0xFFE4EEEE),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selected
                                            ? Icons.check_box_rounded
                                            : Icons.check_box_outline_blank,
                                        color: available
                                            ? const Color(0xFF0FAFA3)
                                            : const Color(0xFFB0BEC0),
                                        size: 26,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              resolved.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: available
                                                    ? const Color(0xFF123B42)
                                                    : const Color(0xFF9AA6A8),
                                              ),
                                            ),
                                            if (resolved.nameAr
                                                .trim()
                                                .isNotEmpty)
                                              Text(
                                                resolved.nameAr,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: Color(0xFF708084),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (!available)
                                        const Text(
                                          'غير موجود',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFC94A4A),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      KeyedSubtree(
                        key: _addAnalysisKey,
                        child: _sectionLabel('إضافة تحاليل إضافية'),
                      ),
                      const SizedBox(height: 8),
                      if (!_loadingAnalyses && !_hasAnalysesTable)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF6E5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE8D4A8)),
                          ),
                          child: const Text(
                            'جدول analyses غير موجود.\nنفّذ supabase/labs_schema.sql لتفعيل البحث.',
                            style: TextStyle(height: 1.45),
                          ),
                        ),
                      if (_loadingAnalyses)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          enabled: _hasAnalysesTable,
                          onChanged: _updateAnalysisSuggestions,
                          style: const TextStyle(fontSize: 16),
                          decoration: _fieldDecoration(
                            'اكتب اسم التحليل للبحث...',
                            prefixIcon: const Icon(Icons.search),
                          ),
                        ),
                        if (_analysisSuggestions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE4EEEE),
                              ),
                            ),
                            child: Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < _analysisSuggestions.length;
                                  i++
                                ) ...[
                                  if (i > 0)
                                    const Divider(height: 1, thickness: 1),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          _addAnalysis(_analysisSuggestions[i]),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: 56,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.add_circle_outline,
                                                color: Color(0xFF0FAFA3),
                                                size: 26,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _analysisSuggestions[i]
                                                          .name,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                    Builder(
                                                      builder: (context) {
                                                        final short =
                                                            _analysisSuggestions[i]
                                                                .shortName
                                                                .trim();
                                                        final ar =
                                                            _analysisSuggestions[i]
                                                                .nameAr
                                                                .trim();
                                                        final sub = [
                                                          if (short.isNotEmpty)
                                                            short,
                                                          if (ar.isNotEmpty) ar,
                                                        ].join(' • ');
                                                        if (sub.isEmpty) {
                                                          return const SizedBox.shrink();
                                                        }
                                                        return Text(
                                                          sub,
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFF708084,
                                                                ),
                                                                fontSize: 13,
                                                              ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _buildSelectedAnalysesSection(),
                      ],
                      SizedBox(height: bottomInset > 0 ? 12 : 8),
                    ],
                  ),
                ),
                _buildStickySave(bottomInset),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedAnalysesSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'التحاليل المختارة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF123B42),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'يمكنك تعديل أو حذف التحاليل وإضافة وصف لكل تحليل',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Color(0xFF708084),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: const Color(0xFFE8F7F5),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _focusAddAnalysis,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Color(0xFF0C7F76),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'إضافة تحليل',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0C7F76),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_selected.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'لم يُختر أي تحليل بعد',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF708084)),
              ),
            )
          else
            ...List.generate(_selected.length, (index) {
              return _buildSelectedAnalysisRow(
                index: index,
                item: _selected[index],
                isLast: index == _selected.length - 1,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSelectedAnalysisRow({
    required int index,
    required AnalysisItem item,
    required bool isLast,
  }) {
    final descController = _descControllerFor(item);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE8EEEE))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 360;

          final nameBlock = Row(
            children: [
              Text(
                '${index + 1}.',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF0FAFA3),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: Color(0xFF123B42),
                  ),
                ),
              ),
            ],
          );

          final descField = TextField(
            controller: descController,
            minLines: 1,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF123B42),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'اكتب وصف التحليل بالعربي...',
              hintStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9AA6A8),
              ),
              filled: true,
              fillColor: const Color(0xFFF7FAFA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4EEEE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4EEEE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF0FAFA3),
                  width: 1.4,
                ),
              ),
            ),
            onChanged: (value) {
              final i = _selected.indexWhere((e) => e.id == item.id);
              if (i >= 0) {
                _selected[i] = _selected[i].copyWith(descriptionAr: value);
              }
            },
          );

          final editButton = Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _openEditAnalysisSheet(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF0FAFA3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 15,
                      color: Color(0xFF0FAFA3),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'تعديل',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0FAFA3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          final deleteButton = Material(
            color: const Color(0xFFFFF5F5),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _removeAnalysis(item.id),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFC94A4A),
                  size: 22,
                ),
              ),
            ),
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: nameBlock),
                    editButton,
                    const SizedBox(width: 8),
                    deleteButton,
                  ],
                ),
                const SizedBox(height: 8),
                descField,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: nameBlock,
              ),
              const SizedBox(width: 8),
              Expanded(child: descField),
              const SizedBox(width: 8),
              editButton,
              const SizedBox(width: 8),
              deleteButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPackageImageSection() {
    final suggested = _suggestedImage;
    final suggestionIsSelected =
        suggested != null &&
        _pickedBytes == null &&
        _imageUrl == suggested.imageUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'صورة الباقة',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF123B42),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'الاقتراح مجرد Suggestion — لا يُحفظ إلا بموافقتك',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF708084),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _imageUrlField,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              GhadeerBranding.applyOfficialLogoToField(
                _imageUrlField,
                onApplied: () {
                  if (!mounted) return;
                  setState(() {
                    _imageUrl = GhadeerBranding.officialLogoAsset;
                    _pickedBytes = null;
                    _pickedName = null;
                    _acceptedSuggestion = false;
                  });
                },
              );
              setState(() {
                _imageUrl = GhadeerBranding.normalizeEntityImageUrl(
                  _imageUrlField.text.trim(),
                );
                if (_imageUrl.isNotEmpty &&
                    !GhadeerBranding.looksLikeGhadeerLogo(_imageUrlField.text)) {
                  _imageUrl = _imageUrlField.text.trim();
                }
                _pickedBytes = null;
                _pickedName = null;
              });
            },
            decoration: const InputDecoration(
              labelText: 'رابط الصورة أو اكتب: لوغو الغدير',
              hintText: 'لوغو الغدير',
              helperText:
                  'إذا كتبت «لوغو الغدير» يُستبدل تلقائيًا بالشعار المعتمد',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PackageHeroImage(
                packageName: _name.text.trim().isEmpty
                    ? 'باقة مختبر'
                    : _name.text.trim(),
                imageUrl: _previewImageUrl,
                bytes: _pickedBytes,
                isFeatured: _isFeatured,
                width: 118,
                height: 150,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (suggested != null) ...[
                      Text(
                        'المقترحة: ${suggested.title}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0C7F76),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: suggestionIsSelected
                            ? null
                            : _acceptSuggestedImage,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          suggestionIsSelected || _acceptedSuggestion
                              ? 'تم استخدام المقترحة'
                              : 'استخدام الصورة المقترحة',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0FAFA3),
                          side: const BorderSide(color: Color(0xFF0FAFA3)),
                          minimumSize: const Size.fromHeight(42),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton.tonalIcon(
                      onPressed: _openImageSheet,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('تغيير صورة الباقة'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        backgroundColor: const Color(0xFFE8F7F5),
                        foregroundColor: const Color(0xFF0C7F76),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickDeviceImage,
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('رفع من الجهاز'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                      ),
                    ),
                    if (_hasChosenImage) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _clearPackageImage,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFC94A4A),
                        ),
                        label: const Text(
                          'حذف الصورة',
                          style: TextStyle(color: Color(0xFFC94A4A)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: Color(0xFF123B42),
      ),
    );
  }

  Widget _templateTile(PackageTemplateItem template) {
    final selected =
        _appliedTemplate?.id == template.id ||
        _appliedTemplate?.name == template.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFE8F7F5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _applyTemplate(template),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0FAFA3)
                    : const Color(0xFFE4EEEE),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF0FAFA3),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF123B42),
                        ),
                      ),
                      if (template.description.isNotEmpty)
                        Text(
                          template.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF708084),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFF9AA6A8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickySave(double bottomInset) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset > 0 ? 10 : 12),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0FAFA3),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('حفظ الباقة'),
            ),
          ),
        ),
      ),
    );
  }
}
