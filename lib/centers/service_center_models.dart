import '../search/smart_search_models.dart';
import 'service_center_kind.dart';

/// مركز دليل مشترك. الحقول الفارغة تبقى فارغة ولا تُملأ بقيم افتراضية.
class ServiceCenter {
  const ServiceCenter({
    required this.id,
    required this.kind,
    required this.name,
    this.isActive = true,
    this.displayOrder = 0,
    this.contentRevision = 0,
    this.bio = '',
    this.services = const [],
    this.hours = '',
    this.address = '',
    this.phone = '',
    this.whatsapp = '',
    this.imageUrl = '',
    this.logoUrl = '',
    this.mapUrl = '',
    this.latitude,
    this.longitude,
  });

  final String id;
  final ServiceCenterKind kind;
  final String name;
  final bool isActive;
  final int displayOrder;
  final int contentRevision;
  final String bio;
  final List<String> services;
  final String hours;
  final String address;
  final String phone;
  final String whatsapp;
  final String imageUrl;
  final String logoUrl;
  final String mapUrl;
  final double? latitude;
  final double? longitude;

  String get displayImage {
    final logo = logoUrl.trim();
    if (logo.isNotEmpty) return logo;
    return imageUrl.trim();
  }

  String get locationText {
    final map = mapUrl.trim();
    if (map.isNotEmpty) return map;
    return address.trim();
  }

  List<String> get actualServices => [
        for (final s in services)
          if (s.trim().isNotEmpty) s.trim(),
      ];

  ServiceCenter copyWith({
    String? name,
    bool? isActive,
    int? displayOrder,
    int? contentRevision,
    String? bio,
    List<String>? services,
    String? hours,
    String? address,
    String? phone,
    String? whatsapp,
    String? imageUrl,
    String? logoUrl,
    String? mapUrl,
    double? latitude,
    double? longitude,
    bool clearImage = false,
    bool clearLogo = false,
    bool clearCoords = false,
  }) {
    return ServiceCenter(
      id: id,
      kind: kind,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      contentRevision: contentRevision ?? this.contentRevision,
      bio: bio ?? this.bio,
      services: services ?? this.services,
      hours: hours ?? this.hours,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      imageUrl: clearImage ? '' : (imageUrl ?? this.imageUrl),
      logoUrl: clearLogo ? '' : (logoUrl ?? this.logoUrl),
      mapUrl: mapUrl ?? this.mapUrl,
      latitude: clearCoords ? null : (latitude ?? this.latitude),
      longitude: clearCoords ? null : (longitude ?? this.longitude),
    );
  }

  Map<String, dynamic> profileMap() => {
        'bio': bio,
        'services': actualServices,
        'hours': hours,
        'address': address,
        'phone': phone,
        'whatsapp': whatsapp,
        'imageUrl': imageUrl,
        'logoUrl': logoUrl,
        'mapUrl': mapUrl,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind.dbValue,
        'name': name,
        'isActive': isActive,
        'displayOrder': displayOrder,
        'contentRevision': contentRevision,
        ...profileMap(),
      };

  factory ServiceCenter.fromSharedRow(Map<String, dynamic> row) {
    final profile = row['profile'];
    final map = profile is Map
        ? Map<String, dynamic>.from(profile)
        : <String, dynamic>{};
    final kind = ServiceCenterKind.fromDb(row['kind']?.toString()) ??
        ServiceCenterKind.fromDb(map['kind']?.toString());
    if (kind == null) {
      throw FormatException('service center kind');
    }
    final servicesRaw = map['services'];
    final services = <String>[];
    if (servicesRaw is List) {
      for (final item in servicesRaw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) services.add(text);
      }
    }
    return ServiceCenter(
      id: row['id']?.toString() ?? '',
      kind: kind,
      name: (row['name'] ?? map['name'] ?? '').toString().trim(),
      isActive: row['is_active'] == true || map['isActive'] == true,
      displayOrder: int.tryParse('${row['display_order'] ?? map['displayOrder'] ?? 0}') ??
          0,
      contentRevision:
          int.tryParse('${row['content_revision'] ?? map['contentRevision'] ?? 1}') ??
              1,
      bio: map['bio']?.toString() ?? '',
      services: services,
      hours: map['hours']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      whatsapp: map['whatsapp']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString() ?? '',
      logoUrl: map['logoUrl']?.toString() ?? '',
      mapUrl: map['mapUrl']?.toString() ?? '',
      latitude: double.tryParse('${map['latitude'] ?? ''}'),
      longitude: double.tryParse('${map['longitude'] ?? ''}'),
    );
  }

  factory ServiceCenter.fromMap(Map<String, dynamic> map) {
    return ServiceCenter.fromSharedRow({
      'id': map['id'],
      'kind': map['kind'],
      'name': map['name'],
      'is_active': map['isActive'] == true,
      'display_order': map['displayOrder'],
      'content_revision': map['contentRevision'],
      'profile': map,
    });
  }

  SmartSearchResult toSearchResult({int score = 80}) {
    final location = locationText;
    final image = displayImage;
    return SmartSearchResult(
      type: switch (kind) {
        ServiceCenterKind.optics => SmartSearchResultType.optics,
        ServiceCenterKind.beauty => SmartSearchResultType.beauty,
        ServiceCenterKind.nursing => SmartSearchResultType.nursing,
      },
      title: name,
      subtitle: address.trim().isNotEmpty ? address.trim() : kind.sectionTitle,
      opticsId: kind == ServiceCenterKind.optics ? id : null,
      beautyId: kind == ServiceCenterKind.beauty ? id : null,
      nursingId: kind == ServiceCenterKind.nursing ? id : null,
      score: score,
      imageUrl: image.isEmpty ? null : image,
      bioSnippet: bio.trim().isEmpty ? null : bio.trim(),
      phone: phone.trim().isEmpty ? null : phone.trim(),
      whatsapp: whatsapp.trim().isEmpty ? null : whatsapp.trim(),
      clinicLocation: location.isEmpty ? null : location,
      workingHours: hours.trim().isEmpty ? null : hours.trim(),
    );
  }

  static int compareOrder(ServiceCenter a, ServiceCenter b) {
    final byOrder = a.displayOrder.compareTo(b.displayOrder);
    if (byOrder != 0) return byOrder;
    return a.name.compareTo(b.name);
  }
}

/// ما يراه الزائر: الصفوف المنشورة النشطة فقط. لا كتالوج مضمّن.
List<ServiceCenter> serviceCentersForVisitors({
  required List<ServiceCenter> shared,
  required bool sharedReady,
  required ServiceCenterKind kind,
}) {
  if (!sharedReady) return const [];
  final list = [
    for (final center in shared)
      if (center.kind == kind && center.isActive && center.name.trim().isNotEmpty)
        center,
  ];
  list.sort(ServiceCenter.compareOrder);
  return list;
}

/// الإدارة ترى الظاهر والمخفي من الصفوف المشتركة فقط.
List<ServiceCenter> serviceCentersForAdmin({
  required List<ServiceCenter> shared,
  required ServiceCenterKind kind,
}) {
  final list = [
    for (final center in shared)
      if (center.kind == kind && center.name.trim().isNotEmpty) center,
  ];
  list.sort(ServiceCenter.compareOrder);
  return list;
}

/// يقسّم أسطر الخدمات كما كتبتها الإدارة، بلا خدمات جاهزة.
List<String> parseServiceLines(String raw) {
  final out = <String>[];
  for (final line in raw.split(RegExp(r'[\n,،]'))) {
    final text = line.trim();
    if (text.isNotEmpty) out.add(text);
  }
  return out;
}
