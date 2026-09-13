import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import 'specialty_catalog.dart';

/// صفحة كل الاختصاصات الطبية — Design Target (يمين الصورة المرجعية).
class AllSpecialtiesPage extends StatefulWidget {
  const AllSpecialtiesPage({
    super.key,
    required this.doctorSpecialties,
    required this.onSpecialtySelected,
  });

  /// نصوص الاختصاص كما هي من الأطباء (Supabase).
  final List<String> doctorSpecialties;
  final void Function(String specialty) onSpecialtySelected;

  @override
  State<AllSpecialtiesPage> createState() => _AllSpecialtiesPageState();
}

class _AllSpecialtiesPageState extends State<AllSpecialtiesPage> {
  final _search = TextEditingController();
  String _query = '';
  String _chip = 'all'; // all | popular | with_doctors

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = SpecialtyCatalog.countBySpecialty(widget.doctorSpecialties);
    var entries = SpecialtyCatalog.gridEntries(counts);

    if (_chip == 'popular') {
      entries = entries
          .where((e) => e.def?.popular == true || e.count > 0)
          .toList();
      entries.sort((a, b) => b.count.compareTo(a.count));
    } else if (_chip == 'with_doctors') {
      entries = entries.where((e) => e.count > 0).toList();
    }

    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      entries = entries
          .where(
            (e) =>
                e.name.toLowerCase().contains(q) ||
                (e.def?.shortNameAr.toLowerCase().contains(q) ?? false) ||
                (e.def?.keywords.any((k) => k.toLowerCase().contains(q)) ??
                    false),
          )
          .toList();
    }

    final crossAxisCount = AppResponsive.specialtyColumns(context);
    final pad = AppResponsive.pagePadding(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBFC),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                // الرجوع يسار الشاشة، العنوان بجانبه باتجاه عربي.
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                        ),
                        color: const Color(0xFF123B42),
                      ),
                      const Expanded(
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الاختصاصات الطبية',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF123B42),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'اختر الاختصاص المناسب لك',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6D8084),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن اختصاص...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF8A9A9E),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF0FAFA3),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE4EEEE)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE4EEEE)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF0FAFA3),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chipButton('all', 'الكل'),
                    const SizedBox(width: 8),
                    _chipButton('popular', 'الأكثر طلباً'),
                    const SizedBox(width: 8),
                    _chipButton('with_doctors', 'المتوفرة'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    final icon = e.def?.icon ??
                        SpecialtyCatalog.iconFor(e.name);
                    return Material(
                      color: const Color(0xFFEEF5F7),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: e.count <= 0
                            ? null
                            : () {
                                widget.onSpecialtySelected(e.name);
                                Navigator.pop(context);
                              },
                        child: Opacity(
                          opacity: e.count <= 0 ? 0.55 : 1,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  size: 34,
                                  color: const Color(0xFF0FAFA3),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  e.def?.shortNameAr ?? e.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF123B42),
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.count > 0
                                      ? '${e.count} طبيب'
                                      : 'قريباً',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: e.count > 0
                                        ? const Color(0xFF6D8084)
                                        : const Color(0xFF9AA8AB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipButton(String id, String label) {
    final active = _chip == id;
    return ChoiceChip(
      selected: active,
      showCheckmark: false,
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
          color: active ? Colors.white : const Color(0xFF456066),
        ),
      ),
      selectedColor: const Color(0xFF0FAFA3),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: active ? const Color(0xFF0FAFA3) : const Color(0xFFE0E8EA),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      onSelected: (_) => setState(() => _chip = id),
    );
  }
}
