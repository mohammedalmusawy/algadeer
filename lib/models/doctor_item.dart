import '../branding/ghadeer_brand_mark.dart';
import '../doctors/doctor_gender.dart';
import '../utils/flags.dart';
import 'entity_social_links.dart';

class DoctorItem {
  final String name;
  final String specialty;
  final String location;
  final bool available;
  final String phone;
  final String whatsapp;
  final String imageUrl;
  final String logoUrl;
  final String id;
  final bool ghadeerBadge;
  final String bio;
  final String services;
  final String shortDescription;
  final String workingDays;
  final String workingHours;
  final String bookingStatus;
  final String absenceFrom;
  final String absenceTo;
  final String consultationFee;
  final bool showCallButton;
  final bool showWhatsAppButton;
  final bool showBookingButton;
  final int yearsExperience;
  final int patientsServed;
  final int profileViews;
  final String languages;
  final String qualifications;
  final String ageGroup;
  final String profileQuote;
  final bool notificationsEnabled;
  /// '' | male | female — فارغ = صياغة مذكر (السلوك الحالي).
  final String gender;
  final EntitySocialLinks social;
  final int contentRevision;

  const DoctorItem({
    required this.name,
    required this.specialty,
    required this.location,
    required this.available,
    required this.phone,
    required this.whatsapp,
    required this.imageUrl,
    this.logoUrl = '',
    required this.id,
    required this.ghadeerBadge,
    required this.bio,
    this.services = '',
    required this.shortDescription,
    required this.workingDays,
    required this.workingHours,
    required this.bookingStatus,
    required this.absenceFrom,
    required this.absenceTo,
    this.consultationFee = '',
    this.showCallButton = true,
    this.showWhatsAppButton = true,
    this.showBookingButton = false,
    this.yearsExperience = 0,
    this.patientsServed = 0,
    this.profileViews = 0,
    this.languages = '',
    this.qualifications = '',
    this.ageGroup = '',
    this.profileQuote = '',
    this.notificationsEnabled = true,
    this.gender = DoctorGender.unspecified,
    this.social = EntitySocialLinks.empty,
    this.contentRevision = 1,
  });

  bool get isFemale => DoctorGender.isFemale(gender);

  DoctorItem copyWith({
    String? name,
    String? specialty,
    String? location,
    bool? available,
    String? phone,
    String? whatsapp,
    String? imageUrl,
    String? logoUrl,
    String? bio,
    String? services,
    String? shortDescription,
    String? workingDays,
    String? workingHours,
    String? bookingStatus,
    int? contentRevision,
  }) {
    final nextStatus = bookingStatus ?? this.bookingStatus;
    return DoctorItem(
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      location: location ?? this.location,
      available: available ?? nextStatus == 'available',
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      imageUrl: imageUrl ?? this.imageUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      id: id,
      ghadeerBadge: ghadeerBadge,
      bio: bio ?? this.bio,
      services: services ?? this.services,
      shortDescription: shortDescription ?? this.shortDescription,
      workingDays: workingDays ?? this.workingDays,
      workingHours: workingHours ?? this.workingHours,
      bookingStatus: nextStatus,
      absenceFrom: absenceFrom,
      absenceTo: absenceTo,
      consultationFee: consultationFee,
      showCallButton: showCallButton,
      showWhatsAppButton: showWhatsAppButton,
      showBookingButton: showBookingButton,
      yearsExperience: yearsExperience,
      patientsServed: patientsServed,
      profileViews: profileViews,
      languages: languages,
      qualifications: qualifications,
      ageGroup: ageGroup,
      profileQuote: profileQuote,
      notificationsEnabled: notificationsEnabled,
      gender: gender,
      social: social,
      contentRevision: contentRevision ?? this.contentRevision,
    );
  }

  factory DoctorItem.fromMap(Map<String, dynamic> data) {
    return DoctorItem(
      name: data['doctor_name']?.toString() ?? '',
      specialty: data['specialty']?.toString() ?? '',
      location: data['clinic_location']?.toString() ?? '',
      available: data['booking_status']?.toString() == 'available',
      phone: data['phone']?.toString() ?? '',
      whatsapp: data['whatsapp']?.toString() ?? '',
      imageUrl: GhadeerBranding.normalizeEntityImageUrl(
        data['image_url']?.toString() ?? '',
      ),
      logoUrl: data['logo_url']?.toString() ?? '',
      id: data['id']?.toString() ?? '',
      ghadeerBadge: readBoolFlag(data['ghadeer_badge']),
      bio: data['bio']?.toString() ?? '',
      services: data['services']?.toString() ?? '',
      shortDescription: data['short_description']?.toString() ?? '',
      workingDays: data['working_days']?.toString() ?? '',
      workingHours: data['working_hours']?.toString() ?? '',
      bookingStatus: data['booking_status']?.toString() ?? 'available',
      absenceFrom: data['absence_from']?.toString() ?? '',
      absenceTo: data['absence_to']?.toString() ?? '',
      consultationFee: data['consultation_fee']?.toString() ?? '',
      showCallButton: readBoolFlag(data['show_call_button'], fallback: true),
      showWhatsAppButton: readBoolFlag(
        data['show_whatsapp_button'],
        fallback: true,
      ),
      showBookingButton: readBoolFlag(data['show_booking_button']),
      yearsExperience: int.tryParse('${data['years_experience'] ?? 0}') ?? 0,
      patientsServed: int.tryParse('${data['patients_served'] ?? 0}') ?? 0,
      profileViews: int.tryParse('${data['profile_views'] ?? 0}') ?? 0,
      languages: data['languages']?.toString() ?? '',
      qualifications: data['qualifications']?.toString() ?? '',
      ageGroup: data['age_group']?.toString() ?? '',
      profileQuote: data['profile_quote']?.toString() ?? '',
      notificationsEnabled: readBoolFlag(
        data['notifications_enabled'],
        fallback: true,
      ),
      gender: DoctorGender.normalize(data['gender']?.toString()),
      social: EntitySocialLinks.fromMap(data),
      contentRevision: int.tryParse('${data['content_revision'] ?? 1}') ?? 1,
    );
  }
}
