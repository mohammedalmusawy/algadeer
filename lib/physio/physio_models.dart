import '../models/entity_social_links.dart';

/// مركز علاج طبيعي وتأهيل.
class PhysioCenter {
  const PhysioCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.whatsapp,
    required this.services,
    required this.openFrom,
    required this.openTo,
    required this.isOpenNow,
    this.slogan = 'حركة أفضل لحياة أفضل',
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
  final List<String> services;
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

  PhysioCenter copyWith({
    String? name,
    String? address,
    String? phone,
    String? whatsapp,
    List<String>? services,
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
    return PhysioCenter(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      services: services ?? this.services,
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
        'services': services,
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

  factory PhysioCenter.fromMap(Map<String, dynamic> m) => PhysioCenter(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        address: m['address']?.toString() ?? '',
        phone: m['phone']?.toString() ?? '',
        whatsapp: m['whatsapp']?.toString() ?? '',
        services: (m['services'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        openFrom: m['openFrom']?.toString() ?? '',
        openTo: m['openTo']?.toString() ?? '',
        isOpenNow: m['isOpenNow'] == true,
        slogan: m['slogan']?.toString() ?? 'حركة أفضل لحياة أفضل',
        imageUrl: m['imageUrl']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        isActive: m['isActive'] != false,
        social: EntitySocialLinks.fromMap(m),
      );
}

class PhysioCatalog {
  PhysioCatalog._();

  static const defaultImage =
      'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=600&q=80';

  static const items = <PhysioCenter>[
    PhysioCenter(
      id: 'physio_shatra',
      name: 'مركز الشطرة للعلاج الطبيعي',
      slogan: 'تأهيل وحركة بثقة',
      address: 'الشطرة - قرب شارع الأطباء',
      phone: '07801230001',
      whatsapp: '9647801230001',
      services: [
        'علاج طبيعي عام',
        'تأهيل ما بعد الكسور',
        'آلام الظهر والرقبة',
        'تمارين علاجية',
      ],
      openFrom: '9:00 صباحاً',
      openTo: '8:00 مساءً',
      isOpenNow: true,
      description: 'جلسات علاج طبيعي وتأهيل حركي بإشراف مختصين.',
      latitude: 31.4105,
      longitude: 46.1715,
      imageUrl: defaultImage,
    ),
    PhysioCenter(
      id: 'rehab_hayat',
      name: 'مركز الحياة للتأهيل الطبي',
      slogan: 'خطوة بخطوة نحو التعافي',
      address: 'قرب المستشفى العام - الشطرة',
      phone: '07805550011',
      whatsapp: '9647805550011',
      services: [
        'تأهيل رياضي',
        'علاج المفاصل',
        'تحفيز عضلي',
        'جلسات منزلية',
      ],
      openFrom: '8:00 صباحاً',
      openTo: '9:00 مساءً',
      isOpenNow: true,
      description: 'تأهيل رياضي وعلاج آلام المفاصل والعضلات.',
      latitude: 31.4078,
      longitude: 46.1695,
      imageUrl:
          'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600&q=80',
    ),
  ];
}
