import '../models/entity_social_links.dart';
import 'pharmacy_catalog_bundles.dart';

class PharmacyBundle {
  const PharmacyBundle({
    required this.id,
    required this.title,
    required this.price,
    required this.oldPrice,
    this.subtitle = '',
    this.icon = '',
    this.imageUrl = '',
    this.isPopular = true,
    this.isVisible = true,
    this.supplements = const [],
    this.optionalSupplements = const [],
    this.note = '',
  });

  final String id;
  final String title;
  final String subtitle;
  final int price;
  final int oldPrice;
  final String icon; // emoji fallback
  final String imageUrl;
  /// تظهر في شريط «الأكثر رواجاً» على صفحة الصيدلية.
  final bool isPopular;
  /// إن false: مخفية عن الزبون، ظاهرة للإدارة فقط.
  final bool isVisible;
  final List<String> supplements;
  final List<String> optionalSupplements;
  final String note;

  List<String> get allSupplementLines {
    final out = <String>[...supplements];
    for (final o in optionalSupplements) {
      if (!out.contains(o)) out.add(o);
    }
    return out;
  }

  PharmacyBundle copyWith({
    String? title,
    String? subtitle,
    int? price,
    int? oldPrice,
    String? icon,
    String? imageUrl,
    bool? isPopular,
    bool? isVisible,
    List<String>? supplements,
    List<String>? optionalSupplements,
    String? note,
  }) {
    return PharmacyBundle(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      icon: icon ?? this.icon,
      imageUrl: imageUrl ?? this.imageUrl,
      isPopular: isPopular ?? this.isPopular,
      isVisible: isVisible ?? this.isVisible,
      supplements: supplements ?? this.supplements,
      optionalSupplements: optionalSupplements ?? this.optionalSupplements,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'price': price,
        'oldPrice': oldPrice,
        'icon': icon,
        'imageUrl': imageUrl,
        'isPopular': isPopular,
        'isVisible': isVisible,
        'supplements': supplements,
        'optionalSupplements': optionalSupplements,
        'note': note,
      };

  factory PharmacyBundle.fromMap(Map<String, dynamic> m) => PharmacyBundle(
        id: m['id']?.toString() ?? '',
        title: m['title']?.toString() ?? '',
        subtitle: m['subtitle']?.toString() ?? '',
        price: (m['price'] as num?)?.toInt() ?? 0,
        oldPrice: (m['oldPrice'] as num?)?.toInt() ?? 0,
        icon: m['icon']?.toString() ?? '',
        imageUrl: m['imageUrl']?.toString() ?? '',
        isPopular: m['isPopular'] != false,
        isVisible: m['isVisible'] != false,
        supplements: (m['supplements'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            const [],
        optionalSupplements: (m['optionalSupplements'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            const [],
        note: m['note']?.toString() ?? '',
      );
}

class PharmacyItem {
  const PharmacyItem({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.whatsapp,
    required this.tags,
    required this.openFrom,
    required this.openTo,
    required this.isOpenNow,
    this.slogan = 'صحتك تهمنا دائماً',
    this.imageUrl = '',
    this.logoUrl = '',
    this.hasSupplements = false,
    this.offerPercent = 0,
    this.offerImageUrl = '',
    this.offerIconUrl = '',
    this.bundles = const [],
    this.latitude,
    this.longitude,
    this.isActive = true,
    this.social = EntitySocialLinks.empty,
  });

  final String id;
  final String name;
  final String address;
  final String phone;
  final String whatsapp;
  final List<String> tags;
  final String openFrom;
  final String openTo;
  final bool isOpenNow;
  final String slogan;
  final String imageUrl;
  final String logoUrl;
  final bool hasSupplements;
  final int offerPercent;
  /// صورة منتجات بانر العروض (قابلة للتغيير من الإدارة).
  final String offerImageUrl;
  /// أيقونة العروض المخصصة (رابط صورة اختياري).
  final String offerIconUrl;
  final List<PharmacyBundle> bundles;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final EntitySocialLinks social;

  PharmacyItem copyWith({
    String? name,
    String? address,
    String? phone,
    String? whatsapp,
    List<String>? tags,
    String? openFrom,
    String? openTo,
    bool? isOpenNow,
    String? slogan,
    String? imageUrl,
    String? logoUrl,
    bool? hasSupplements,
    int? offerPercent,
    String? offerImageUrl,
    String? offerIconUrl,
    List<PharmacyBundle>? bundles,
    double? latitude,
    double? longitude,
    bool? isActive,
    EntitySocialLinks? social,
  }) {
    return PharmacyItem(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      tags: tags ?? this.tags,
      openFrom: openFrom ?? this.openFrom,
      openTo: openTo ?? this.openTo,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      slogan: slogan ?? this.slogan,
      imageUrl: imageUrl ?? this.imageUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      hasSupplements: hasSupplements ?? this.hasSupplements,
      offerPercent: offerPercent ?? this.offerPercent,
      offerImageUrl: offerImageUrl ?? this.offerImageUrl,
      offerIconUrl: offerIconUrl ?? this.offerIconUrl,
      bundles: bundles ?? this.bundles,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      social: social ?? this.social,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'whatsapp': whatsapp,
        'tags': tags,
        'openFrom': openFrom,
        'openTo': openTo,
        'isOpenNow': isOpenNow,
        'slogan': slogan,
        'imageUrl': imageUrl,
        'logoUrl': logoUrl,
        'hasSupplements': hasSupplements,
        'offerPercent': offerPercent,
        'offerImageUrl': offerImageUrl,
        'offerIconUrl': offerIconUrl,
        'bundles': bundles.map((b) => b.toMap()).toList(),
        'latitude': latitude,
        'longitude': longitude,
        'isActive': isActive,
        ...social.toDbMap(),
      };

  factory PharmacyItem.fromMap(Map<String, dynamic> m) {
    final rawBundles = m['bundles'];
    final bundles = <PharmacyBundle>[];
    if (rawBundles is List) {
      for (final b in rawBundles) {
        if (b is Map) {
          bundles.add(PharmacyBundle.fromMap(Map<String, dynamic>.from(b)));
        }
      }
    }
    return PharmacyItem(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      address: m['address']?.toString() ?? '',
      phone: m['phone']?.toString() ?? '',
      whatsapp: m['whatsapp']?.toString() ?? '',
      tags: (m['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      openFrom: m['openFrom']?.toString() ?? '',
      openTo: m['openTo']?.toString() ?? '',
      isOpenNow: m['isOpenNow'] == true,
      slogan: m['slogan']?.toString() ?? 'صحتك تهمنا دائماً',
      imageUrl: m['imageUrl']?.toString() ?? '',
      logoUrl: m['logoUrl']?.toString() ?? '',
      hasSupplements: m['hasSupplements'] == true,
      offerPercent: (m['offerPercent'] as num?)?.toInt() ?? 0,
      offerImageUrl: m['offerImageUrl']?.toString() ?? '',
      offerIconUrl: m['offerIconUrl']?.toString() ?? '',
      bundles: bundles,
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      isActive: m['isActive'] != false,
      social: EntitySocialLinks.fromMap(m),
    );
  }
}

/// بيانات افتراضية — تعمل بدون جدول؛ الإدارة تحفظ فوقها محلياً.
class PharmaciesCatalog {
  PharmaciesCatalog._();

  /// صور افتراضية مرتبة للمكملات (تُستخدم إن لم تُرفع صورة من الإدارة).
  static const defaultOfferImage =
      'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&q=80';
  static const defaultOfferIcon =
      'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=200&q=80';

  static List<PharmacyBundle> get _sampleBundles => PharmacyCatalogBundles.all;

  static PharmacyBundle? sampleBundleById(String id) {
    for (final b in _sampleBundles) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// يملأ صورة/مكملات ناقصة من الكتالوج دون مسح بيانات الإدارة.
  static PharmacyBundle enrichBundle(PharmacyBundle b) {
    final sample = sampleBundleById(b.id);
    if (sample == null) {
      if (b.imageUrl.isNotEmpty) return b;
      return b.copyWith(imageUrl: _sampleBundles.first.imageUrl);
    }
    return b.copyWith(
      subtitle: b.subtitle.isEmpty ? sample.subtitle : b.subtitle,
      imageUrl: b.imageUrl.isEmpty ? sample.imageUrl : b.imageUrl,
      icon: b.icon.isEmpty ? sample.icon : b.icon,
      supplements:
          b.supplements.isEmpty ? sample.supplements : b.supplements,
      optionalSupplements: b.optionalSupplements.isEmpty
          ? sample.optionalSupplements
          : b.optionalSupplements,
      note: b.note.isEmpty ? sample.note : b.note,
    );
  }

  /// دمج محفوظات الصيدلية مع الكتالوج (باقات جديدة تظهر، والتعديلات تبقى).
  static List<PharmacyBundle> mergeWithCatalog(List<PharmacyBundle> saved) {
    final byId = <String, PharmacyBundle>{
      for (final b in saved) b.id: b,
    };
    final out = <PharmacyBundle>[];
    for (final c in _sampleBundles) {
      final s = byId.remove(c.id);
      if (s == null) {
        out.add(c);
      } else {
        out.add(enrichBundle(s));
      }
    }
    for (final custom in byId.values) {
      out.add(enrichBundle(custom));
    }
    return out;
  }

  /// شريط الصفحة: الأكثر رواجاً الظاهرة فقط (حد أقصى 5).
  static const int stripPopularLimit = 5;

  static List<PharmacyBundle> visibleOnly(List<PharmacyBundle> all) => [
        for (final b in allEnriched(all))
          if (b.isVisible) b,
      ];

  static List<PharmacyBundle> popularForStrip(List<PharmacyBundle> all) {
    final visible = visibleOnly(all);
    final popular = visible.where((b) => b.isPopular).toList();
    final source = popular.isNotEmpty ? popular : visible;
    if (source.length <= stripPopularLimit) return source;
    return source.take(stripPopularLimit).toList(growable: false);
  }

  static List<PharmacyBundle> allEnriched(List<PharmacyBundle> all) =>
      [for (final b in all) enrichBundle(b)];

  static String resolveOfferImage(PharmacyItem p) =>
      p.offerImageUrl.trim().isNotEmpty ? p.offerImageUrl : defaultOfferImage;

  static String resolveOfferIcon(PharmacyItem p) =>
      p.offerIconUrl.trim().isNotEmpty ? p.offerIconUrl : '';

  static final items = <PharmacyItem>[
    PharmacyItem(
      id: 'rehab',
      name: 'صيدلية رحاب',
      slogan: 'صحتك تهمنا دائماً',
      address: 'الشطرة - شارع الأطباء قرب صيدلية رحاب',
      phone: '07801234567',
      whatsapp: '9647801234567',
      tags: ['مكملات غذائية', 'أدوية عامة', 'مستلزمات طبية'],
      openFrom: '8:00 صباحاً',
      openTo: '11:00 مساءً',
      isOpenNow: true,
      hasSupplements: true,
      offerPercent: 30,
      offerImageUrl: defaultOfferImage,
      bundles: PharmacyCatalogBundles.all,
      latitude: 31.4112,
      longitude: 46.1735,
      imageUrl:
          'https://images.unsplash.com/photo-1576602976047-174e57a47881?w=600&q=80',
    ),
    PharmacyItem(
      id: 'shatra',
      name: 'صيدلية الشطرة',
      slogan: 'دوائك بأمان وثقة',
      address: 'قرب المستشفى العام - الشطرة',
      phone: '07807654321',
      whatsapp: '9647807654321',
      tags: ['أدوية عامة', 'مستلزمات طبية'],
      openFrom: '8:00 صباحاً',
      openTo: '10:00 مساءً',
      isOpenNow: true,
      hasSupplements: false,
      offerPercent: 15,
      offerImageUrl: defaultOfferImage,
      bundles: PharmacyCatalogBundles.all,
      latitude: 31.4080,
      longitude: 46.1690,
      imageUrl:
          'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=600&q=80',
    ),
    PharmacyItem(
      id: 'hayat',
      name: 'صيدلية الحياة',
      slogan: 'راحة بالك تبدأ من هنا',
      address: 'شارع الجمهورية - الشطرة',
      phone: '07701112233',
      whatsapp: '9647701112233',
      tags: ['مكملات غذائية', 'أدوية عامة'],
      openFrom: '9:00 صباحاً',
      openTo: '9:00 مساءً',
      isOpenNow: false,
      hasSupplements: true,
      offerPercent: 20,
      offerImageUrl: defaultOfferImage,
      bundles: PharmacyCatalogBundles.all,
      latitude: 31.4140,
      longitude: 46.1760,
      imageUrl:
          'https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=600&q=80',
    ),
    PharmacyItem(
      id: 'nour',
      name: 'صيدلية النور',
      slogan: 'خدمة على مدار الساعة تقريباً',
      address: 'حي العصري - قرب السوق',
      phone: '07805556677',
      whatsapp: '9647805556677',
      tags: ['مكملات غذائية', 'مستلزمات طبية', 'أدوية عامة'],
      openFrom: '7:00 صباحاً',
      openTo: '12:00 مساءً',
      isOpenNow: true,
      hasSupplements: true,
      offerPercent: 25,
      offerImageUrl: defaultOfferImage,
      bundles: PharmacyCatalogBundles.all,
      latitude: 31.4065,
      longitude: 46.1805,
      imageUrl:
          'https://images.unsplash.com/photo-1585435557343-3b092031a831?w=600&q=80',
    ),
  ];
}
