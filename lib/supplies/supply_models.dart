import '../models/entity_social_links.dart';

/// محل / معرض مستلزمات وتجهيزات طبية.
class SupplyVendor {
  const SupplyVendor({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.whatsapp,
    required this.categories,
    required this.openFrom,
    required this.openTo,
    required this.isOpenNow,
    this.slogan = 'تجهيزات طبية موثوقة',
    this.imageUrl = '',
    this.description = '',
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
  final List<String> categories;
  final String openFrom;
  final String openTo;
  final bool isOpenNow;
  final String slogan;
  final String imageUrl;
  final String description;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final EntitySocialLinks social;

  SupplyVendor copyWith({
    String? name,
    String? address,
    String? phone,
    String? whatsapp,
    List<String>? categories,
    String? openFrom,
    String? openTo,
    bool? isOpenNow,
    String? slogan,
    String? imageUrl,
    String? description,
    double? latitude,
    double? longitude,
    bool? isActive,
    EntitySocialLinks? social,
  }) {
    return SupplyVendor(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      categories: categories ?? this.categories,
      openFrom: openFrom ?? this.openFrom,
      openTo: openTo ?? this.openTo,
      isOpenNow: isOpenNow ?? this.isOpenNow,
      slogan: slogan ?? this.slogan,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
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
        'categories': categories,
        'openFrom': openFrom,
        'openTo': openTo,
        'isOpenNow': isOpenNow,
        'slogan': slogan,
        'imageUrl': imageUrl,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'isActive': isActive,
        ...social.toDbMap(),
      };

  factory SupplyVendor.fromMap(Map<String, dynamic> m) => SupplyVendor(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        address: m['address']?.toString() ?? '',
        phone: m['phone']?.toString() ?? '',
        whatsapp: m['whatsapp']?.toString() ?? '',
        categories: (m['categories'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        openFrom: m['openFrom']?.toString() ?? '',
        openTo: m['openTo']?.toString() ?? '',
        isOpenNow: m['isOpenNow'] == true,
        slogan: m['slogan']?.toString() ?? 'تجهيزات طبية موثوقة',
        imageUrl: m['imageUrl']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        isActive: m['isActive'] != false,
        social: EntitySocialLinks.fromMap(m),
      );
}

/// كتالوج افتراضي — الإدارة تعدّل فوقه محلياً.
class SuppliesCatalog {
  SuppliesCatalog._();

  static const defaultImage =
      'https://images.unsplash.com/photo-1581594693702-fbdc51b2763b?w=600&q=80';

  static const items = <SupplyVendor>[
    SupplyVendor(
      id: 'medequip_shatra',
      name: 'معرض الشطرة للمستلزمات الطبية',
      slogan: 'تجهيزات موثوقة لعيادتك ومنزلك',
      address: 'الشطرة - شارع الأطباء',
      phone: '07801112233',
      whatsapp: '9647801112233',
      categories: [
        'كراسي متحركة',
        'أسرّة طبية',
        'أجهزة قياس',
        'مستلزمات عيادات',
      ],
      openFrom: '9:00 صباحاً',
      openTo: '9:00 مساءً',
      isOpenNow: true,
      description:
          'توفير كراسي متحركة وأسرّة طبية وأجهزة قياس ضغط وسكر ومستلزمات عيادات.',
      latitude: 31.4110,
      longitude: 46.1720,
      imageUrl: defaultImage,
    ),
    SupplyVendor(
      id: 'hayat_equip',
      name: 'مؤسسة الحياة للتجهيزات',
      slogan: 'جودة وخدمة سريعة',
      address: 'قرب المستشفى العام - الشطرة',
      phone: '07804445566',
      whatsapp: '9647804445566',
      categories: [
        'أوكسجين منزلي',
        'أجهزة طبية',
        'أجهزة ضغط وسكر',
        'مستلزمات جراحة',
      ],
      openFrom: '8:00 صباحاً',
      openTo: '8:00 مساءً',
      isOpenNow: true,
      description: 'أجهزة أوكسجين منزلية ومعدات رعاية وتمريض.',
      latitude: 31.4085,
      longitude: 46.1700,
      imageUrl:
          'https://images.unsplash.com/photo-1516549655169-df83a0774514?w=600&q=80',
    ),
    SupplyVendor(
      id: 'nour_medical',
      name: 'النور للمستلزمات الطبية',
      slogan: 'كل ما تحتاجه تحت سقف واحد',
      address: 'حي العصري - قرب السوق',
      phone: '07703334455',
      whatsapp: '9647703334455',
      categories: [
        'مستلزمات أسنان',
        'تجهيزات مختبر',
        'قفازات وكمامات',
        'تعقيم',
      ],
      openFrom: '9:00 صباحاً',
      openTo: '10:00 مساءً',
      isOpenNow: false,
      description: 'مستلزمات عيادات أسنان ومختبرات ومواد تعقيم.',
      latitude: 31.4135,
      longitude: 46.1755,
      imageUrl:
          'https://images.unsplash.com/photo-1579684385127-1ef15d508118?w=600&q=80',
    ),
  ];
}
