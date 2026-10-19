import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import '../widgets/app_slot_icon.dart';
import 'specialty_catalog.dart';
import 'specialty_stats.dart';
import '../ads/widgets/home_ad_slot.dart';
import '../home/ghadeer_home_colors.dart';
import '../widgets/entity_contact_actions.dart';

/// صفحة كل الاختصاصات الطبية — Design Target (يمين الصورة المرجعية).
class AllSpecialtiesPage extends StatefulWidget {
  const AllSpecialtiesPage({
    super.key,
    required this.doctorSpecialties,
    required this.onSpecialtySelected,
    this.stats = const SpecialtyStats(),
  });

  /// نصوص الاختصاص كما هي من الأطباء (Supabase).
  final List<String> doctorSpecialties;
  final void Function(String specialty) onSpecialtySelected;

  /// الطلب الحقيقي والمتوفر اليوم لكل اختصاص (من صفوف الأطباء).
  final SpecialtyStats stats;

  @override
  State<AllSpecialtiesPage> createState() => _AllSpecialtiesPageState();
}

class _AllSpecialtiesPageState extends State<AllSpecialtiesPage> {
  final _search = TextEditingController();
  String _query = '';
  String _chip = 'all'; // all | popular | today

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = SpecialtyCatalog.countByTile(widget.doctorSpecialties);
    var entries = SpecialtyCatalog.gridEntries(counts);

    final demand = widget.stats.demand;
    final today = widget.stats.availableToday;
    if (_chip == 'popular') {
      // الأكثر طلباً فعلاً: مشاهدات + اتصال + واتساب الناس، مو عدد الأطباء.
      entries = entries.where((e) => e.count > 0).toList();
      entries.sort((a, b) {
        final d = (demand[b.name] ?? 0).compareTo(demand[a.name] ?? 0);
        if (d != 0) return d;
        return b.count.compareTo(a.count);
      });
    } else if (_chip == 'today') {
      // اختصاصات بيها طبيب دوامه اليوم ومو مجاز.
      entries = entries.where((e) => (today[e.name] ?? 0) > 0).toList();
      entries.sort(
        (a, b) => (today[b.name] ?? 0).compareTo(today[a.name] ?? 0),
      );
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
        backgroundColor: GhadeerHomeColors.pageBg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                // الرجوع أعلى اليمين (موحّد)، والعنوان بجانبه.
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    children: [
                      GhadeerBackButton(
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
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
                                  fontWeight: FontWeight.w800,
                                  color: GhadeerHomeColors.secondary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'اختر الاختصاص المناسب لك',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: GhadeerHomeColors.muted,
                                  fontWeight: FontWeight.w500,
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
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chipButton('all', 'الكل'),
                    const SizedBox(width: 8),
                    _chipButton('popular', 'الأكثر طلبًا'),
                    const SizedBox(width: 8),
                    _chipButton('today', 'متوفر اليوم'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // شريط إعلان قسم الأطباء (موضع «الأطباء» في إدارة الإعلانات).
              const HomeAdSlot(placement: 'doctors'),
              if (entries.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _chip == 'today'
                            ? 'ماكو طبيب دوامه مؤكد اليوم. شوف «الكل».'
                            : 'ما لكينا اختصاص بهذا الاسم.',
                        key: const Key('specialties-empty'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6D8084),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      // 0.92 كان يقص اسم الاختصاص بسطرين على موبايل 360px.
                      childAspectRatio: 0.8,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      final icon =
                          e.def?.icon ?? SpecialtyCatalog.iconFor(e.name);
                      return Material(
                        color: const Color(0xFFEEF5F7),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: e.count <= 0
                              ? null
                              // الصفحة تبقى وراك: الرجوع من القائمة يرجعك
                              // للاختصاصات، مو للرئيسية.
                              : () => widget.onSpecialtySelected(e.name),
                          child: Opacity(
                            opacity: e.count <= 0 ? 0.55 : 1,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AppSlotIcon(
                                    slotId: e.def != null
                                        ? 'specialty.${e.def!.id}'
                                        : 'specialty.custom',
                                    fallback: icon,
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
                                  // سطر واحد يصغر إذا ضاق المربع، حتى «N متوفر اليوم» ما ينزل لسطر ثاني ويقص.
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _chip == 'today'
                                          ? '${today[e.name] ?? 0} متوفر اليوم'
                                          : e.count > 0
                                          ? '${e.count} طبيب'
                                          : 'قريباً',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: e.count > 0
                                            ? const Color(0xFF6D8084)
                                            : const Color(0xFF9AA8AB),
                                      ),
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
      // سطر واحد دائماً: بخط الغدير «الأكثر طلباً» جان ينكسر لسطرين وينقص.
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      label: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: active ? Colors.white : const Color(0xFF456066),
        ),
      ),
      selectedColor: GhadeerHomeColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: active ? const Color(0xFF0FAFA3) : const Color(0xFFE0E8EA),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      onSelected: (_) => setState(() => _chip = id),
    );
  }
}
