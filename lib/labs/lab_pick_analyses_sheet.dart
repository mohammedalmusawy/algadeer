import 'package:flutter/material.dart';

import '../companion/personal_companion_profile_service.dart';
import '../models/lab_models.dart';
import '../services/app_stats_service.dart';
import '../utils/clinic_contact_message.dart';
import '../utils/contact_launch.dart';
import 'labs_service.dart';

/// اختيار تحاليل من قاموس التطبيق ثم إرسالها لواتساب المختبر الحالي.
Future<void> openLabPickAnalysesSheet({
  required BuildContext context,
  required String labId,
  required String labName,
  required String labWhatsApp,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LabPickAnalysesSheet(
      labId: labId,
      labName: labName,
      labWhatsApp: labWhatsApp,
    ),
  );
}

class _LabPickAnalysesSheet extends StatefulWidget {
  const _LabPickAnalysesSheet({
    required this.labId,
    required this.labName,
    required this.labWhatsApp,
  });

  final String labId;
  final String labName;
  final String labWhatsApp;

  @override
  State<_LabPickAnalysesSheet> createState() => _LabPickAnalysesSheetState();
}

class _LabPickAnalysesSheetState extends State<_LabPickAnalysesSheet> {
  final _service = LabsService();
  final _stats = AppStatsService();
  final _search = TextEditingController();
  final _note = TextEditingController();

  List<AnalysisItem> _catalog = [];
  List<AnalysisItem> _visible = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  String? _error;

  static const _navy = Color(0xFF123B42);
  static const _teal = Color(0xFF0FAFA3);
  static const _muted = Color(0xFF5B6C70);
  static const _line = Color(0xFFE4EEF0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.fetchAnalyses(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _catalog = items;
        _visible = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل قاموس التحاليل';
      });
    }
  }

  void _filter(String query) {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _visible = _catalog);
      return;
    }
    setState(() {
      _visible = rankAnalysisMatches(_catalog, q, limit: 80);
    });
  }

  String _keyOf(AnalysisItem item) =>
      item.id.isNotEmpty ? item.id : item.name.toLowerCase();

  void _toggle(AnalysisItem item) {
    final key = _keyOf(item);
    setState(() {
      if (_selectedIds.contains(key)) {
        _selectedIds.remove(key);
      } else {
        _selectedIds.add(key);
      }
    });
  }

  List<AnalysisItem> get _selectedItems {
    final map = <String, AnalysisItem>{};
    for (final item in _catalog) {
      map[_keyOf(item)] = item;
    }
    // ترتيب الاختيار كما أضافها المستخدم.
    return _selectedIds
        .map((id) => map[id])
        .whereType<AnalysisItem>()
        .toList();
  }

  String _buildWhatsAppMessage(
    List<AnalysisItem> selected, {
    String? patientFullName,
  }) {
    final lab = widget.labName.trim().isEmpty ? 'المختبر' : widget.labName.trim();
    final buf = StringBuffer();
    buf.writeln('السلام عليكم،');
    buf.writeln('أرغب بإجراء التحاليل التالية في مختبر $lab:');
    buf.writeln();
    for (var i = 0; i < selected.length; i++) {
      final item = selected[i];
      final ar = item.arabicDisplayName;
      final en = item.englishDisplayName;
      if (en.isNotEmpty && en != ar) {
        buf.writeln('${i + 1}. $ar ($en)');
      } else {
        buf.writeln('${i + 1}. $ar');
      }
    }
    buf.writeln();
    final note = _note.text.trim();
    if (note.isNotEmpty) {
      buf.writeln('استفسار:');
      buf.writeln(note);
      buf.writeln();
    }
    buf.write('من تطبيق عيادة الغدير');
    return ClinicContactMessage.appendPatientNameIfPresent(
      buf.toString(),
      patientFullName: patientFullName,
    );
  }

  Future<void> _sendWhatsApp() async {
    final wa = widget.labWhatsApp.trim();
    if (wa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد رقم واتساب لهذا المختبر')),
      );
      return;
    }
    final selected = _selectedItems;
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر تحليلًا واحدًا على الأقل')),
      );
      return;
    }

    final patientName =
        await PersonalCompanionProfileService().preferredNameForPersonalization();
    _stats.recordLabWhatsAppTap(widget.labId);
    await launchClinicWhatsApp(
      wa,
      message: _buildWhatsAppMessage(
        selected,
        patientFullName: patientName,
      ),
    );
  }

  Future<void> _openSelectedOverview() async {
    if (_selectedIds.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final selected = _selectedItems;
              final height = MediaQuery.sizeOf(context).height * 0.62;

              return Container(
                height: height,
                decoration: const BoxDecoration(
                  color: Color(0xFFF7FBFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5E2E6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'اختياراتك (${selected.length})',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: _navy,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _line),
                    Expanded(
                      child: selected.isEmpty
                          ? const Center(
                              child: Text(
                                'لا توجد اختيارات',
                                style: TextStyle(
                                  color: _muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                20,
                              ),
                              itemCount: selected.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = selected[index];
                                final ar = item.arabicDisplayName;
                                final en = item.englishDisplayName;
                                return Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    8,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _line),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F7F5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: _teal,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ar.isEmpty ? en : ar,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: _navy,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                            if (en.isNotEmpty && en != ar) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                en,
                                                style: const TextStyle(
                                                  color: _muted,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'إزالة',
                                        onPressed: () {
                                          _toggle(item);
                                          setSheetState(() {});
                                          if (_selectedIds.isEmpty &&
                                              sheetContext.mounted) {
                                            Navigator.pop(sheetContext);
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Color(0xFF9AA6A8),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFFF7FBFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5E2E6),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'اختر تحليلك بنفسك',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'ابحث بالعربي أو الإنجليزي…',
                  prefixIcon: const Icon(Icons.search_rounded, color: _teal),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _teal, width: 1.4),
                  ),
                ),
              ),
            ),
            if (_selectedIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openSelectedOverview,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'اختياراتك (${_selectedIds.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _teal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const Text(
                                'عرض الكل',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _navy,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.expand_more_rounded,
                                size: 20,
                                color: _navy,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedItems.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final item = _selectedItems[index];
                          final label = item.arabicDisplayName.isNotEmpty
                              ? item.arabicDisplayName
                              : item.englishDisplayName;
                          return InputChip(
                            label: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: _navy,
                              ),
                            ),
                            selected: true,
                            showCheckmark: false,
                            onPressed: _openSelectedOverview,
                            onDeleted: () => _toggle(item),
                            deleteIconColor: _navy,
                            backgroundColor: const Color(0xFFE8F7F5),
                            selectedColor: const Color(0xFFE8F7F5),
                            side: const BorderSide(color: Color(0xFFBFE6E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: _body()),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: 'استفسار (اختياري)',
                        hintText: 'مثلاً: أريد معرفة الأسعار أو موعد الاستلام…',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.fromLTRB(
                          14,
                          12,
                          14,
                          12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: _teal, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            _selectedIds.isEmpty ? null : _sendWhatsApp,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          disabledBackgroundColor: const Color(0xFFB7D9C4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.chat_rounded),
                        label: Text(
                          _selectedIds.isEmpty
                              ? 'إرسال عبر واتساب'
                              : 'إرسال ${_selectedIds.length} تحليل عبر واتساب',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('إعادة')),
            ],
          ),
        ),
      );
    }
    if (_visible.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد نتائج',
          style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      itemCount: _visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _visible[index];
        final key = _keyOf(item);
        final selected = _selectedIds.contains(key);
        final ar = item.arabicDisplayName;
        final en = item.englishDisplayName;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggle(item),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _teal : _line,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: selected ? _teal : const Color(0xFF9AA6A8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ar.isEmpty ? en : ar,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _navy,
                            fontSize: 14.5,
                            height: 1.3,
                          ),
                        ),
                        if (en.isNotEmpty && en != ar) ...[
                          const SizedBox(height: 3),
                          Text(
                            en,
                            style: const TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
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
