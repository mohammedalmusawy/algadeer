import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../doctors/doctor_card_access_client.dart';
import '../home/ghadeer_home_colors.dart';
import '../widgets/clinic_app_bar.dart';
import 'pharmacy_fit_image.dart';
import 'pharmacy_models.dart';
import 'pharmacy_package_suggestions.dart';

/// محرّر باقة صيدلية مبسّط على أسلوب باقات المختبر.
class PharmacyPackageFormPage extends StatefulWidget {
  const PharmacyPackageFormPage({
    super.key,
    required this.pharmacyId,
    this.initial,
    this.ownerSession,
    this.canAdd = true,
    this.canEdit = true,
  });

  final String pharmacyId;
  final PharmacyBundle? initial;
  final DoctorCardSession? ownerSession;
  final bool canAdd;
  final bool canEdit;

  @override
  State<PharmacyPackageFormPage> createState() =>
      _PharmacyPackageFormPageState();
}

class _PharmacyPackageFormPageState extends State<PharmacyPackageFormPage> {
  late bool _pickingSuggestion;

  String _categoryFilter = '';
  String _templateId = '';
  PharmacyPackageTemplate? _template;

  final List<PharmacyPackageProduct> _products = [];
  final Map<String, TextEditingController> _productNames = {};
  final Map<String, TextEditingController> _productDescriptions = {};
  final _suggestionSearch = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _note = TextEditingController();
  final _price = TextEditingController();
  final _oldPrice = TextEditingController();
  final _displayOrder = TextEditingController(text: '0');
  final _customName = TextEditingController();
  final _customDescription = TextEditingController();

  String _coverUrl = '';
  bool _isVisible = true;
  bool _isPopular = false;
  bool _showOnHome = false;
  bool _dirty = false;

  bool get _isEditing => widget.initial != null;

  /// مثل المختبر: خيارات الصفحة الرئيسية وترتيبها للإدارة فقط.
  bool get _adminControls =>
      widget.ownerSession == null || widget.ownerSession!.isAdmin;

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    if (b != null) {
      _pickingSuggestion = false;
      _templateId = b.templateId;
      if (_templateId.isNotEmpty) {
        for (final t in packageTemplates) {
          if (t.id == _templateId) {
            _template = t;
            break;
          }
        }
      }
      _products.addAll(b.resolvedProducts);
      _title.text = b.title;
      _description.text = b.description.isNotEmpty ? b.description : b.subtitle;
      _note.text = b.note;
      _price.text = b.price > 0 ? '${b.price}' : '';
      _oldPrice.text = b.oldPrice > 0 ? '${b.oldPrice}' : '';
      _coverUrl = b.imageUrl;
      _isVisible = b.isVisible;
      _isPopular = b.isPopular;
      _showOnHome = b.showOnHome;
      _displayOrder.text = '${b.displayOrder}';
      _bindProductFields();
    } else {
      _pickingSuggestion = true;
    }
  }

  @override
  void dispose() {
    _suggestionSearch.dispose();
    _title.dispose();
    _description.dispose();
    _note.dispose();
    _price.dispose();
    _oldPrice.dispose();
    _displayOrder.dispose();
    _customName.dispose();
    _customDescription.dispose();
    for (final c in _productNames.values) {
      c.dispose();
    }
    for (final c in _productDescriptions.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _bindProductFields() {
    final ids = _products.map((p) => p.id).toSet();
    final stale = <TextEditingController>[];
    for (final id in _productNames.keys.toList()) {
      if (ids.contains(id)) continue;
      final name = _productNames.remove(id);
      final description = _productDescriptions.remove(id);
      if (name != null) stale.add(name);
      if (description != null) stale.add(description);
    }
    for (final product in _products) {
      final name = _productNames[product.id];
      final description = _productDescriptions[product.id];
      if (name == null || description == null) {
        _productNames[product.id] = TextEditingController(text: product.name);
        _productDescriptions[product.id] =
            TextEditingController(text: product.instructions);
      } else {
        if (name.text != product.name) name.text = product.name;
        if (description.text != product.instructions) {
          description.text = product.instructions;
        }
      }
    }
    if (stale.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in stale) {
        controller.dispose();
      }
    });
  }

  void _flushProducts() {
    for (var i = 0; i < _products.length; i++) {
      final product = _products[i];
      final name = _productNames[product.id]?.text.trim() ?? product.name;
      final description =
          _productDescriptions[product.id]?.text.trim() ?? product.instructions;
      _products[i] = product.copyWith(
        name: name,
        ingredient: name,
        instructions: description,
        strength: '',
      );
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Map<String, List<PharmacyPackageTemplate>> get _groupedTemplates {
    final map = <String, List<PharmacyPackageTemplate>>{};
    for (final t in searchTemplates(_categoryFilter, _suggestionSearch.text)) {
      map.putIfAbsent(t.categoryId, () => []).add(t);
    }
    return map;
  }

  void _startCustom() {
    setState(() {
      _pickingSuggestion = false;
      _template = null;
      _templateId = '';
      if (_title.text.trim().isEmpty) _title.text = 'باقة مخصصة';
      _description.clear();
      _replaceDraftProducts(const []);
      _dirty = true;
    });
  }

  void _replaceDraftProducts(List<PharmacyPackageProduct> next) {
    _products
      ..clear()
      ..addAll(next);
    _bindProductFields();
  }

  void _applyTemplate(PharmacyPackageTemplate t) {
    setState(() {
      _template = t;
      _templateId = t.id;
      _pickingSuggestion = false;
      _title.text = t.titleAr;
      _description.clear();
      _note.clear();
      _replaceDraftProducts(draftProductsFromTemplate(t));
      _dirty = true;
    });
  }

  Future<void> _acceptSuggestions() async {
    final template = _template;
    if (template == null) return;
    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اعتماد المقترحات؟'),
        content: const Text(
          'ترجع عناصر المسودة إلى أسماء مقترحات هذه الباقة فقط، '
          'ويُمسح وصف العناصر. القالب الأصلي والباقات المحفوظة ما تتغير '
          'إلا إذا ضغطت «حفظ الباقة».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );
    if (restore != true || !mounted) return;
    setState(() {
      _replaceDraftProducts(draftProductsFromTemplate(template));
      _dirty = true;
    });
  }

  Future<void> _pickCover() async {
    final url = await PharmacyImageHelper.pickFromDevice();
    if (url == null || !mounted) return;
    setState(() {
      _coverUrl = url;
      _markDirty();
    });
  }

  Future<void> _pickProductImage(int index) async {
    final url = await PharmacyImageHelper.pickFromDevice();
    if (url == null || !mounted) return;
    setState(() {
      _products[index] = _products[index].copyWith(imageUrl: url);
      _markDirty();
    });
  }

  void _addCustomProduct() {
    final n = _customName.text.trim();
    if (n.isEmpty) return;
    setState(() {
      _flushProducts();
      _products.add(
        PharmacyPackageProduct(
          id: 'p_${DateTime.now().microsecondsSinceEpoch}',
          name: n,
          ingredient: n,
          instructions: _customDescription.text.trim(),
        ),
      );
      _customName.clear();
      _customDescription.clear();
      _bindProductFields();
      _dirty = true;
    });
  }

  Future<void> _cancel() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء التعديل؟'),
        content: const Text('التغييرات غير المحفوظة ستضيع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('متابعة'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  void _save() {
    if (_isEditing && !widget.canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا تملك صلاحية تعديل الباقات')),
      );
      return;
    }
    if (!_isEditing && !widget.canAdd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا تملك صلاحية إضافة باقات')),
      );
      return;
    }
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم الباقة')),
      );
      return;
    }
    _flushProducts();
    if (_products.isEmpty || _products.any((p) => p.name.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف عنصراً واحداً على الأقل ولكل عنصر اسم')),
      );
      return;
    }
    final price = int.tryParse(_price.text.trim()) ?? 0;
    final old = int.tryParse(_oldPrice.text.trim()) ?? 0;
    final order = int.tryParse(_displayOrder.text.trim()) ?? 0;
    final id = widget.initial?.id ??
        'b_${DateTime.now().millisecondsSinceEpoch}';
    final lines = [for (final p in _products) p.name];
    Navigator.pop(
      context,
      PharmacyBundle(
        id: id,
        title: _title.text.trim(),
        subtitle: _description.text.trim().isNotEmpty
            ? _description.text.trim()
            : lines.take(3).join(' · '),
        description: _description.text.trim(),
        price: price,
        oldPrice: old,
        imageUrl: _coverUrl,
        isPopular: _adminControls ? _isPopular : (widget.initial?.isPopular ?? false),
        showOnHome:
            _adminControls ? _showOnHome : (widget.initial?.showOnHome ?? false),
        displayOrder: _adminControls
            ? order
            : (widget.initial?.displayOrder ?? 0),
        isVisible: _isVisible,
        products: List.of(_products),
        supplements: [
          for (final p in _products)
            if (!p.optional) p.name,
        ],
        optionalSupplements: [
          for (final p in _products)
            if (p.optional) p.name,
        ],
        note: _note.text.trim(),
        categoryId: _template?.categoryId ?? '',
        templateId: _templateId,
        pharmacistReviewed: true,
      ),
    );
  }

  InputDecoration _dec(String label, {Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD7E4E4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0FAFA3), width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8F8),
        appBar: ClinicAppBar(
          title: Text(_isEditing ? 'تعديل باقة' : 'إضافة باقة'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: _cancel,
              child: const Text('إلغاء', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _pickingSuggestion
                    ? _suggestionPicker()
                    : _editor(),
              ),
              if (!_pickingSuggestion) _bottomBar(bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionPicker() {
    final grouped = _groupedTemplates;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'اختر باقة مقترحة. الاختيار ينشئ مسودة قابلة للتعديل، '
          'ولا يغيّر القالب ولا الباقات المحفوظة حتى تضغط «حفظ الباقة».',
          style: TextStyle(
            color: GhadeerHomeColors.muted,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _suggestionSearch,
          decoration: _dec('بحث', prefix: const Icon(Icons.search)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: const Text('الكل'),
                  selected: _categoryFilter.isEmpty,
                  onSelected: (_) => setState(() => _categoryFilter = ''),
                ),
              ),
              for (final c in categories)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(c.titleAr),
                    selected: _categoryFilter == c.id,
                    onSelected: (_) => setState(() => _categoryFilter = c.id),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _startCustom,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('باقة مخصصة'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 16),
        if (grouped.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              'لا نتائج مطابقة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GhadeerHomeColors.muted),
            ),
          ),
        for (final entry in grouped.entries) ...[
          Text(
            categoryTitleAr(entry.key),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: GhadeerHomeColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final t in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: ValueKey('template-${t.id}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _applyTemplate(t),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE4EEEE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t.titleAr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.summaryAr,
                          style: const TextStyle(
                            height: 1.35,
                            color: GhadeerHomeColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _editor() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (!_isEditing)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _pickingSuggestion = true),
              child: const Text('تغيير الاقتراح'),
            ),
          ),
        if (_template != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'مقترحات «${_template!.titleAr}» فقط. '
              'عدّلها أو اعتمدها ثم اضغط «حفظ الباقة». الإلغاء لا يغيّر المحفوظ.',
              style: const TextStyle(
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0C7F76),
              ),
            ),
          ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'عناصر الباقة',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: GhadeerHomeColors.secondary,
                ),
              ),
            ),
            if (_template != null)
              TextButton(
                onPressed: _acceptSuggestions,
                child: const Text('اعتماد المقترحات كما هي'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'المحتوى الذي تعتمده مسؤوليتك. لا يُضاف وصف جرعة أو توصية علاجية تلقائياً.',
          style: TextStyle(
            color: GhadeerHomeColors.muted,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _products.length; i++) _productRow(i),
        if (_products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'لا عناصر بعد. أضف عنصراً جديداً.',
              style: TextStyle(color: GhadeerHomeColors.muted),
            ),
          ),
        TextField(
          controller: _customName,
          decoration: _dec('عنصر جديد — الاسم'),
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _customDescription,
          decoration: _dec('وصف العنصر (اختياري)'),
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonal(
            onPressed: _addCustomProduct,
            child: const Text('إضافة عنصر'),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'تفاصيل الباقة',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: GhadeerHomeColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('package-title'),
          controller: _title,
          decoration: _dec('اسم الباقة'),
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _description,
          maxLines: 3,
          decoration: _dec('الوصف'),
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: _dec('تعليمات الصيدلي للزبون'),
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('السعر (د.ع)'),
                onChanged: (_) => _markDirty(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _oldPrice,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('السعر السابق'),
                onChanged: (_) => _markDirty(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PharmacyFitImage(
              source: _coverUrl,
              width: 96,
              height: 112,
              fallback: Icons.local_pharmacy_outlined,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _pickCover,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(
                      _coverUrl.isEmpty ? 'صورة الباقة' : 'استبدال الصورة',
                    ),
                  ),
                  if (_coverUrl.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() {
                        _coverUrl = '';
                        _markDirty();
                      }),
                      child: const Text(
                        'إزالة الصورة',
                        style: TextStyle(color: Color(0xFFC62828)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ظاهرة للزبائن'),
          value: _isVisible,
          onChanged: (v) => setState(() {
            _isVisible = v;
            _markDirty();
          }),
        ),
        if (_adminControls) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('باقة مميزة'),
            value: _isPopular,
            onChanged: (v) => setState(() {
              _isPopular = v;
              _markDirty();
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('إظهار في الصفحة الرئيسية للصيدلية'),
            subtitle: const Text('الإدارة فقط — مثل باقات المختبر'),
            value: _showOnHome,
            onChanged: (v) => setState(() {
              _showOnHome = v;
              _markDirty();
            }),
          ),
          TextField(
            controller: _displayOrder,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dec('ترتيب الظهور'),
            onChanged: (_) => _markDirty(),
          ),
        ],
      ],
    );
  }

  Widget _productRow(int i) {
    final p = _products[i];
    final name = _productNames[p.id];
    final description = _productDescriptions[p.id];
    if (name == null || description == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _pickProductImage(i),
                  child: PharmacyFitImage(
                    source: p.imageUrl,
                    width: 48,
                    height: 48,
                    fallback: Icons.medication_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: ValueKey('product-${p.id}'),
                    controller: name,
                    decoration: _dec('اسم العنصر'),
                    onChanged: (_) => _markDirty(),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف العنصر',
                  onPressed: () => setState(() {
                    _flushProducts();
                    _products.removeAt(i);
                    _bindProductFields();
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.close, color: Color(0xFFC62828)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: description,
              decoration: _dec('وصف العنصر'),
              onChanged: (_) => _markDirty(),
            ),
            if (p.imageUrl.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => setState(() {
                    _products[i] = p.copyWith(clearImage: true);
                    _dirty = true;
                  }),
                  child: const Text(
                    'إزالة صورة العنصر',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(double bottomInset) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset > 0 ? 8 : 12),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _cancel,
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: GhadeerHomeColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('حفظ الباقة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
