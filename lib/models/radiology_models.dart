import '../branding/ghadeer_brand_mark.dart';

bool radiologyBoolFlag(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value == true || value == 1 || value == 'true') return true;
  if (value == false || value == 0 || value == 'false') return false;
  return fallback;
}

class RadiologyCenter {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String address;
  final String phone;
  final String whatsapp;
  final bool isActive;
  final bool isFeatured;
  final int displayOrder;
  final String mapUrl;
  final String workingHours;
  final String slogan;
  final DateTime? createdAt;

  const RadiologyCenter({
    required this.id,
    required this.name,
    this.description = '',
    this.imageUrl = '',
    this.address = '',
    this.phone = '',
    this.whatsapp = '',
    this.isActive = true,
    this.isFeatured = false,
    this.displayOrder = 0,
    this.mapUrl = '',
    this.workingHours = '',
    this.slogan = '',
    this.createdAt,
  });

  factory RadiologyCenter.fromMap(Map<String, dynamic> data) {
    return RadiologyCenter(
      id: data['id']?.toString() ?? '',
      name: (data['name'] ?? data['center_name'])?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      imageUrl: GhadeerBranding.normalizeEntityImageUrl(
        data['image_url']?.toString() ?? '',
      ),
      address: data['address']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      whatsapp: data['whatsapp']?.toString() ?? '',
      isActive: radiologyBoolFlag(data['is_active'], fallback: true),
      isFeatured: radiologyBoolFlag(data['is_featured']),
      displayOrder: int.tryParse('${data['display_order'] ?? 0}') ?? 0,
      mapUrl: data['map_url']?.toString() ?? '',
      workingHours: data['working_hours']?.toString() ?? '',
      slogan: data['slogan']?.toString() ?? '',
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl.isEmpty ? null : imageUrl,
      'address': address,
      'phone': phone,
      'whatsapp': whatsapp,
      'is_active': isActive,
      'is_featured': isFeatured,
      'display_order': displayOrder,
      'map_url': mapUrl.trim(),
      'working_hours': workingHours.trim(),
      'slogan': slogan.trim(),
    };
  }
}
