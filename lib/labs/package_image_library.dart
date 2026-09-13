import 'package:flutter/material.dart';

/// مكتبة صور الباقات المقترحة (Fallback محلي + ترتيب ذكي).
/// الصورة النهائية للباقة تُحفظ في Supabase عبر image_url على الباقة.

class PackageImageItem {
  final String id;
  final String title;
  final String category;
  final String imageUrl;
  final List<String> keywords;
  final bool isActive;

  const PackageImageItem({
    required this.id,
    required this.title,
    required this.category,
    required this.imageUrl,
    this.keywords = const [],
    this.isActive = true,
  });

  factory PackageImageItem.fromMap(Map<String, dynamic> data) {
    final raw = data['keywords'];
    final keywords = <String>[];
    if (raw is List) {
      for (final item in raw) {
        final t = item?.toString().trim() ?? '';
        if (t.isNotEmpty) keywords.add(t);
      }
    } else if (raw is String && raw.trim().isNotEmpty) {
      keywords.addAll(
        raw
            .split(RegExp(r'[,|]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    return PackageImageItem(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      category: data['category']?.toString() ?? 'general',
      imageUrl: data['image_url']?.toString() ?? '',
      keywords: keywords,
      isActive: data['is_active'] != false,
    );
  }

  List<String> get searchableTerms => [
    title,
    category,
    ...keywords,
  ].map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
}

/// صور مقترحة عامة — تُنسخ إلى image_url عند موافقة المدير فقط.
const List<PackageImageItem> kBuiltinPackageImages = [
  PackageImageItem(
    id: 'general',
    title: 'فحص شامل / مختبر',
    category: 'general',
    imageUrl: 'https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&w=900&q=80',
    keywords: [
      'general',
      'checkup',
      'lab',
      'medical',
      'شامل',
      'فحص',
      'مختبر',
      'تحاليل',
    ],
  ),
  PackageImageItem(
    id: 'heart',
    title: 'صحة القلب',
    category: 'heart',
    imageUrl: 'https://images.unsplash.com/photo-1628348068343-c358b319181f?auto=format&fit=crop&w=900&q=80',
    keywords: [
      'heart',
      'cardiac',
      'ecg',
      'cardiovascular',
      'قلب',
      'قلبية',
      'شرايين',
    ],
  ),
  PackageImageItem(
    id: 'vitamin_d',
    title: 'فيتامين D',
    category: 'vitamins',
    imageUrl: 'https://images.unsplash.com/photo-1550572017-edd951aa8f72?auto=format&fit=crop&w=900&q=80',
    keywords: ['vitamin d', 'vitamind', 'sun', 'فيتامين د', 'فيتامين d', 'شمس'],
  ),
  PackageImageItem(
    id: 'hair',
    title: 'تساقط الشعر',
    category: 'hair',
    imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?auto=format&fit=crop&w=900&q=80',
    keywords: ['hair', 'scalp', 'hair loss', 'شعر', 'تساقط', 'فروة'],
  ),
  PackageImageItem(
    id: 'thyroid',
    title: 'الغدة الدرقية',
    category: 'thyroid',
    imageUrl: 'https://images.unsplash.com/photo-1582719471384-894fbb16e074?auto=format&fit=crop&w=900&q=80',
    keywords: ['thyroid', 'tsh', 'غدة', 'درقية', 'thyroid gland'],
  ),
  PackageImageItem(
    id: 'diabetes',
    title: 'السكري',
    category: 'diabetes',
    imageUrl: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=900&q=80',
    keywords: [
      'diabetes',
      'glucose',
      'sugar',
      'hba1c',
      'سكري',
      'سكر',
      'جلوكوز',
    ],
  ),
  PackageImageItem(
    id: 'joints',
    title: 'المفاصل والعظام',
    category: 'joints',
    imageUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&w=900&q=80',
    keywords: ['joint', 'bone', 'rheumatology', 'مفاصل', 'عظام', 'روماتيزم'],
  ),
  PackageImageItem(
    id: 'kidney',
    title: 'الكلى',
    category: 'kidney',
    imageUrl: 'https://images.unsplash.com/photo-1559757175-5700dde97648?auto=format&fit=crop&w=900&q=80',
    keywords: ['kidney', 'renal', 'كلى', 'كلية', 'وظائف الكلى'],
  ),
  PackageImageItem(
    id: 'liver',
    title: 'الكبد',
    category: 'liver',
    imageUrl: 'https://images.unsplash.com/photo-1581594693702-fbdc51b2763b?auto=format&fit=crop&w=900&q=80',
    keywords: ['liver', 'hepatic', 'alt', 'ast', 'كبد', 'وظائف الكبد'],
  ),
  PackageImageItem(
    id: 'anemia',
    title: 'فقر الدم',
    category: 'anemia',
    imageUrl: 'https://images.unsplash.com/photo-1615461066159-fea0960485d5?auto=format&fit=crop&w=900&q=80',
    keywords: ['anemia', 'blood', 'iron', 'rbc', 'cbc', 'فقر', 'دم', 'حديد'],
  ),
  PackageImageItem(
    id: 'vitamins',
    title: 'فيتامينات ومعادن',
    category: 'vitamins',
    imageUrl: 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?auto=format&fit=crop&w=900&q=80',
    keywords: [
      'vitamins',
      'minerals',
      'vitamin',
      'فيتامينات',
      'معادن',
      'تغذية',
    ],
  ),
  PackageImageItem(
    id: 'sports',
    title: 'الرياضيين',
    category: 'sports',
    imageUrl: 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=900&q=80',
    keywords: [
      'sports',
      'fitness',
      'athlete',
      'muscle',
      'رياض',
      'رياضيين',
      'لياقة',
    ],
  ),
  PackageImageItem(
    id: 'women',
    title: 'صحة المرأة',
    category: 'women',
    imageUrl: 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=900&q=80',
    keywords: ['women', 'woman', 'female', 'امرأة', 'المرأة', 'نسائية'],
  ),
  PackageImageItem(
    id: 'men',
    title: 'صحة الرجل',
    category: 'men',
    imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?auto=format&fit=crop&w=900&q=80',
    keywords: ['men', 'man', 'male', 'رجل', 'الرجل', 'رجالية'],
  ),
  PackageImageItem(
    id: 'children',
    title: 'الأطفال',
    category: 'children',
    imageUrl: 'https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?auto=format&fit=crop&w=900&q=80',
    keywords: ['children', 'pediatric', 'kids', 'child', 'أطفال', 'طفل'],
  ),
  PackageImageItem(
    id: 'seniors',
    title: 'كبار السن',
    category: 'seniors',
    imageUrl: 'https://images.unsplash.com/photo-1581579438747-1dc8d17bbce4?auto=format&fit=crop&w=900&q=80',
    keywords: ['senior', 'elderly', 'aging', 'كبار', 'مسنين', 'شيخوخة'],
  ),
];

int _scorePackageImage(PackageImageItem image, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0;
  var score = 0;
  for (final term in image.searchableTerms) {
    if (term.isEmpty) continue;
    if (q == term || term == q) {
      score += 100;
    } else if (q.contains(term) || term.contains(q)) {
      score += 40 + (term.length.clamp(0, 20));
    } else {
      for (final token in q.split(RegExp(r'\s+'))) {
        if (token.length < 2) continue;
        if (term.contains(token) || token.contains(term)) {
          score += 18;
        }
      }
    }
  }
  return score;
}

List<PackageImageItem> rankPackageImages(
  List<PackageImageItem> catalog,
  String query, {
  int limit = 12,
}) {
  final active = catalog
      .where((e) => e.isActive && e.imageUrl.isNotEmpty)
      .toList();
  if (query.trim().isEmpty) {
    return active.take(limit).toList();
  }

  final scored = <({PackageImageItem item, int score})>[];
  for (final item in active) {
    final score = _scorePackageImage(item, query);
    if (score > 0) scored.add((item: item, score: score));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  if (scored.isEmpty) {
    return active.take(limit).toList();
  }
  return scored.map((e) => e.item).take(limit).toList();
}

PackageImageItem? suggestPackageImage(
  List<PackageImageItem> catalog,
  String packageName,
) {
  final active = catalog
      .where((e) => e.isActive && e.imageUrl.isNotEmpty)
      .toList();
  if (active.isEmpty) return null;

  final ranked = rankPackageImages(active, packageName, limit: 1);
  if (ranked.isEmpty) return active.first;

  final top = ranked.first;
  if (_scorePackageImage(top, packageName) <= 0) {
    for (final item in active) {
      if (item.category == 'general') return item;
    }
    return active.first;
  }
  return top;
}

({Color bg, Color accent, IconData icon}) packagePlaceholderStyle(
  String packageName,
) {
  final q = packageName.toLowerCase();
  if (q.contains('قلب') || q.contains('heart') || q.contains('cardiac')) {
    return (
      bg: const Color(0xFFFFE8EC),
      accent: const Color(0xFFD4536A),
      icon: Icons.favorite_rounded,
    );
  }
  if (q.contains('شعر') || q.contains('hair')) {
    return (
      bg: const Color(0xFFFFF0E8),
      accent: const Color(0xFFC47A4A),
      icon: Icons.face_retouching_natural,
    );
  }
  if (q.contains('سكر') || q.contains('diabetes') || q.contains('glucose')) {
    return (
      bg: const Color(0xFFE8F4FF),
      accent: const Color(0xFF3B7DD8),
      icon: Icons.water_drop_rounded,
    );
  }
  if (q.contains('كلى') || q.contains('kidney')) {
    return (
      bg: const Color(0xFFEAF7F0),
      accent: const Color(0xFF2F9E6B),
      icon: Icons.spa_rounded,
    );
  }
  if (q.contains('كبد') || q.contains('liver')) {
    return (
      bg: const Color(0xFFFFF6E8),
      accent: const Color(0xFFD0892F),
      icon: Icons.biotech_rounded,
    );
  }
  if (q.contains('رياض') || q.contains('sport') || q.contains('fitness')) {
    return (
      bg: const Color(0xFFE8FFF6),
      accent: const Color(0xFF1FAF7A),
      icon: Icons.fitness_center_rounded,
    );
  }
  if (q.contains('طفل') || q.contains('أطفال') || q.contains('child')) {
    return (
      bg: const Color(0xFFFFF4E8),
      accent: const Color(0xFFE39A3C),
      icon: Icons.child_care_rounded,
    );
  }
  if (q.contains('مرأة') || q.contains('women')) {
    return (
      bg: const Color(0xFFF8E8FF),
      accent: const Color(0xFFA35BC8),
      icon: Icons.woman_rounded,
    );
  }
  if (q.contains('رجل') || q.contains('men')) {
    return (
      bg: const Color(0xFFE8F0FF),
      accent: const Color(0xFF4A6FD4),
      icon: Icons.man_rounded,
    );
  }
  return (
    bg: const Color(0xFFE8F7F5),
    accent: const Color(0xFF0FAFA3),
    icon: Icons.card_giftcard_rounded,
  );
}
