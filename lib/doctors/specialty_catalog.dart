import 'package:flutter/material.dart';

/// كتالوج اختصارات بصرية للاختصاصات.
/// مصدر الحقيقة لبيانات الطبيب يبقى: doctors.specialty في Supabase.
class SpecialtyDefinition {
  const SpecialtyDefinition({
    required this.id,
    required this.nameAr,
    required this.shortNameAr,
    required this.icon,
    this.keywords = const [],
    this.popular = false,
  });

  final String id;
  final String nameAr;
  final String shortNameAr;
  final IconData icon;
  final List<String> keywords;
  final bool popular;
}

class SpecialtyCatalog {
  SpecialtyCatalog._();

  static const List<SpecialtyDefinition> all = [
    SpecialtyDefinition(
      id: 'internal',
      nameAr: 'الباطنية',
      shortNameAr: 'الباطنية',
      icon: Icons.monitor_heart_outlined,
      keywords: ['باطن', 'داخلية', 'internal'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'pediatrics',
      nameAr: 'طب الأطفال',
      shortNameAr: 'الأطفال',
      icon: Icons.child_care_outlined,
      keywords: ['أطفال', 'اطفال', 'طفل', 'pediatric'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'obgyn',
      nameAr: 'النساء والولادة',
      shortNameAr: 'النساء والولادة',
      icon: Icons.pregnant_woman_outlined,
      keywords: ['نساء', 'ولادة', 'نسائية', 'obgyn', 'gyn'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'ent',
      nameAr: 'الأنف والأذن والحنجرة',
      shortNameAr: 'الأنف والأذن',
      icon: Icons.hearing_outlined,
      keywords: ['أنف', 'اذن', 'أذن', 'حنجرة', 'انف', 'ent'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'ortho',
      nameAr: 'العظام والكسور والمفاصل',
      shortNameAr: 'العظام',
      icon: Icons.accessibility_new_outlined,
      keywords: ['عظام', 'كسور', 'ortho'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'joints',
      nameAr: 'المفاصل',
      shortNameAr: 'المفاصل',
      icon: Icons.back_hand_outlined,
      keywords: ['مفصل', 'مفاصل', 'joints'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'general_surgery',
      nameAr: 'الجراحة العامة',
      shortNameAr: 'الجراحة',
      icon: Icons.content_cut_outlined,
      keywords: ['جراحة عامة', 'جراح', 'surgery'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'ophthalmology',
      nameAr: 'طب العيون',
      shortNameAr: 'العيون',
      icon: Icons.visibility_outlined,
      keywords: ['عيون', 'عين', 'ophthal'],
    ),
    SpecialtyDefinition(
      id: 'dentistry',
      nameAr: 'طب الأسنان',
      shortNameAr: 'أطباء الأسنان',
      icon: Icons.health_and_safety_outlined,
      keywords: ['أسنان', 'اسنان', 'سن', 'dental', 'dent'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'dermatology',
      nameAr: 'الجلدية',
      shortNameAr: 'الجلدية',
      icon: Icons.spa_outlined,
      keywords: ['جلد', 'تجميل جلدي', 'derma'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'cardiology',
      nameAr: 'القلب',
      shortNameAr: 'القلب',
      icon: Icons.favorite_border_rounded,
      keywords: ['قلب', 'قلبية', 'cardio'],
    ),
    SpecialtyDefinition(
      id: 'neurology',
      nameAr: 'الجملة العصبية',
      shortNameAr: 'الجملة العصبية',
      icon: Icons.psychology_alt_outlined,
      keywords: ['عصب', 'أعصاب', 'اعصاب', 'دماغ', 'neuro', 'جملة عصبية'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'gastro',
      nameAr: 'الجهاز الهضمي',
      shortNameAr: 'الهضمية',
      icon: Icons.restaurant_outlined,
      keywords: ['هضم', 'معدة', 'كبد', 'gastro'],
    ),
    SpecialtyDefinition(
      id: 'urology',
      nameAr: 'المسالك البولية',
      shortNameAr: 'المسالك',
      icon: Icons.water_drop_outlined,
      keywords: ['مسالك', 'بول', 'urol'],
    ),
    SpecialtyDefinition(
      id: 'nephrology',
      nameAr: 'الكلى',
      shortNameAr: 'الكلى',
      icon: Icons.bubble_chart_outlined,
      keywords: ['كلى', 'كلية', 'nephro'],
    ),
    SpecialtyDefinition(
      id: 'endocrine',
      nameAr: 'الغدد الصماء والسكري',
      shortNameAr: 'الغدد',
      icon: Icons.science_outlined,
      keywords: ['غدد', 'سكري', 'درقية', 'endocrine'],
    ),
    SpecialtyDefinition(
      id: 'rheumatology',
      nameAr: 'الروماتيزم',
      shortNameAr: 'الروماتيزم',
      icon: Icons.back_hand_outlined,
      keywords: ['رومات', 'مفاصل رومات', 'rheum'],
    ),
    SpecialtyDefinition(
      id: 'pulmonology',
      nameAr: 'الصدرية والتنفسية',
      shortNameAr: 'الصدرية',
      icon: Icons.air_outlined,
      keywords: ['صدر', 'تنفس', 'رئة', 'pulmo'],
    ),
    SpecialtyDefinition(
      id: 'oncology',
      nameAr: 'الأورام',
      shortNameAr: 'الأورام',
      icon: Icons.coronavirus_outlined,
      keywords: ['ورم', 'أورام', 'اورام', 'onco'],
    ),
    SpecialtyDefinition(
      id: 'hematology',
      nameAr: 'الدم',
      shortNameAr: 'الدم',
      icon: Icons.bloodtype_outlined,
      keywords: ['دم', 'هيمات', 'hema'],
    ),
    SpecialtyDefinition(
      id: 'psychiatry',
      nameAr: 'الطب النفسي',
      shortNameAr: 'النفسية',
      icon: Icons.self_improvement_outlined,
      keywords: ['نفس', 'psychiatric', 'psych'],
    ),
    SpecialtyDefinition(
      id: 'allergy',
      nameAr: 'الحساسية والمناعة',
      shortNameAr: 'الحساسية',
      icon: Icons.masks_outlined,
      keywords: ['حساسية', 'مناعة', 'allergy', 'immuno'],
    ),
    SpecialtyDefinition(
      id: 'infectious',
      nameAr: 'الأمراض الانتقالية',
      shortNameAr: 'الانتقالية',
      icon: Icons.coronavirus_outlined,
      keywords: ['انتقال', 'عدوى', 'infect'],
    ),
    SpecialtyDefinition(
      id: 'family',
      nameAr: 'طب الأسرة',
      shortNameAr: 'الأسرة',
      icon: Icons.family_restroom_outlined,
      keywords: ['أسرة', 'اسرة', 'family'],
    ),
    SpecialtyDefinition(
      id: 'gp',
      nameAr: 'الطب العام',
      shortNameAr: 'الطب العام',
      icon: Icons.medical_information_outlined,
      keywords: ['عام', 'ممارس', 'general practice', 'gp'],
    ),
    SpecialtyDefinition(
      id: 'neurosurgery',
      nameAr: 'جراحة الأعصاب',
      shortNameAr: 'جراحة الأعصاب',
      icon: Icons.psychology_outlined,
      keywords: ['جراحة أعصاب', 'جراحة اعصاب', 'neurosurg'],
    ),
    SpecialtyDefinition(
      id: 'cardiac_surgery',
      nameAr: 'جراحة القلب والصدر',
      shortNameAr: 'جراحة القلب',
      icon: Icons.favorite_outline,
      keywords: ['جراحة قلب', 'صدر جراح'],
    ),
    SpecialtyDefinition(
      id: 'pediatric_surgery',
      nameAr: 'جراحة الأطفال',
      shortNameAr: 'جراحة الأطفال',
      icon: Icons.child_friendly_outlined,
      keywords: ['جراحة أطفال', 'جراحة اطفال'],
    ),
    SpecialtyDefinition(
      id: 'urology_surgery',
      nameAr: 'جراحة المسالك',
      shortNameAr: 'جراحة المسالك',
      icon: Icons.water_drop_outlined,
      keywords: ['جراحة مسالك'],
    ),
    SpecialtyDefinition(
      id: 'plastic',
      nameAr: 'الجراحة التجميلية',
      shortNameAr: 'التجميلية',
      icon: Icons.face_outlined,
      keywords: ['تجميل', 'plastic'],
    ),
    SpecialtyDefinition(
      id: 'vascular',
      nameAr: 'الأوعية الدموية',
      shortNameAr: 'الأوعية',
      icon: Icons.timeline_outlined,
      keywords: ['أوعية', 'اوعية', 'vascular'],
    ),
    SpecialtyDefinition(
      id: 'anesthesia',
      nameAr: 'التخدير',
      shortNameAr: 'التخدير',
      icon: Icons.hotel_outlined,
      keywords: ['تخدير', 'anesth'],
    ),
    SpecialtyDefinition(
      id: 'radiology',
      nameAr: 'الأشعة التشخيصية',
      shortNameAr: 'الأشعة',
      icon: Icons.radar_outlined,
      keywords: ['أشعة', 'اشعة', 'راديو', 'radio', 'xray', 'ct', 'mri'],
      popular: true,
    ),
    SpecialtyDefinition(
      id: 'ultrasound',
      nameAr: 'السونار',
      shortNameAr: 'السونار',
      icon: Icons.waves_outlined,
      keywords: ['سونار', 'ultrasound', 'echo', 'إيكو', 'ايكو'],
      popular: true,
    ),
  ];

  static List<String> get namesForAdmin =>
      all.map((e) => e.nameAr).toList(growable: false);

  static SpecialtyDefinition? match(String raw) {
    final needle = raw.trim().toLowerCase();
    if (needle.isEmpty) return null;

    for (final s in all) {
      if (s.nameAr == raw.trim() || s.shortNameAr == raw.trim()) return s;
    }
    for (final s in all) {
      if (needle.contains(s.nameAr) || s.nameAr.contains(raw.trim())) {
        return s;
      }
      for (final k in s.keywords) {
        if (needle.contains(k.toLowerCase())) return s;
      }
    }
    return null;
  }

  static IconData iconFor(String specialty) {
    return match(specialty)?.icon ?? Icons.medical_information_outlined;
  }

  static String shortLabel(String specialty) {
    return match(specialty)?.shortNameAr ?? specialty.trim();
  }

  /// ترتيب فلاتر الشاشة الرئيسية (بعد «الكل»).
  static const List<String> homeChipIds = [
    'general_surgery', // الجراحة
    'pediatrics', // الأطفال
    'ent', // الأنف والأذن
    'ortho', // العظام
    'ultrasound', // السونار
    'joints', // المفاصل
    'neurology', // الجملة العصبية
    'dentistry', // أطباء الأسنان
  ];

  /// اختصارات الشاشة الرئيسية: قائمة ثابتة بالترتيب المطلوب.
  static List<String> homeShortcuts(
    Iterable<String> doctorSpecialties, {
    int limit = 8,
  }) {
    final byId = {for (final s in all) s.id: s};
    final curated = <String>[];
    for (final id in homeChipIds) {
      final def = byId[id];
      if (def != null) curated.add(def.nameAr);
    }
    if (curated.length >= limit) return curated.take(limit).toList();

    // إن بقي فراغ: أضف اختصاصات موجودة فعليًا وغير مكررة.
    final counts = <String, int>{};
    for (final raw in doctorSpecialties) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      final matched = match(s);
      final key = matched?.nameAr ?? s;
      if (curated.contains(key)) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final extras = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in extras) {
      if (curated.length >= limit) break;
      curated.add(e.key);
    }
    return curated;
  }

  static Map<String, int> countBySpecialty(Iterable<String> doctorSpecialties) {
    final counts = <String, int>{};
    for (final raw in doctorSpecialties) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      final matched = match(s);
      final key = matched?.nameAr ?? s;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// شبكة صفحة «كل الاختصاصات»: الكتالوج + أي اختصاص حر موجود في البيانات.
  static List<({SpecialtyDefinition? def, String name, int count})>
      gridEntries(Map<String, int> counts) {
    final used = <String>{};
    final result = <({SpecialtyDefinition? def, String name, int count})>[];

    for (final def in all) {
      used.add(def.nameAr);
      result.add((def: def, name: def.nameAr, count: counts[def.nameAr] ?? 0));
    }

    for (final entry in counts.entries) {
      if (used.contains(entry.key)) continue;
      result.add((def: match(entry.key), name: entry.key, count: entry.value));
    }

    result.sort((a, b) {
      if (a.count != b.count) return b.count.compareTo(a.count);
      return a.name.compareTo(b.name);
    });
    return result;
  }
}
