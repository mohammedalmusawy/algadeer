import 'package:flutter/material.dart';

import '../doctors/specialty_catalog.dart';

/// فتحات الأيقونات القابلة للتغيير من الإدارة.
/// شعار الغدير الرسمي غير مدرج هنا أبداً — ثابت.
class AppIconSlot {
  const AppIconSlot({
    required this.id,
    required this.group,
    required this.titleAr,
    required this.fallbackIcon,
  });

  final String id;
  final String group; // home | specialty | nav
  final String titleAr;
  final IconData fallbackIcon;
}

class AppIconSlots {
  AppIconSlots._();

  static const groupHome = 'home';
  static const groupSpecialty = 'specialty';
  static const groupNav = 'nav';

  static const home = <AppIconSlot>[
    AppIconSlot(
      id: 'home.doctors',
      group: groupHome,
      titleAr: 'الأطباء',
      fallbackIcon: Icons.medical_services_outlined,
    ),
    AppIconSlot(
      id: 'home.radiology',
      group: groupHome,
      titleAr: 'الأشعة',
      fallbackIcon: Icons.radar_outlined,
    ),
    AppIconSlot(
      id: 'home.labs',
      group: groupHome,
      titleAr: 'المختبرات',
      fallbackIcon: Icons.biotech_outlined,
    ),
    AppIconSlot(
      id: 'home.physio',
      group: groupHome,
      titleAr: 'العلاج الطبيعي والتأهيل',
      fallbackIcon: Icons.accessibility_new_rounded,
    ),
    AppIconSlot(
      id: 'home.supplies',
      group: groupHome,
      titleAr: 'المستلزمات والتجهيزات',
      fallbackIcon: Icons.wheelchair_pickup_rounded,
    ),
    AppIconSlot(
      id: 'home.pharmacy',
      group: groupHome,
      titleAr: 'الصيدليات',
      fallbackIcon: Icons.medication_liquid_outlined,
    ),
  ];

  static const nav = <AppIconSlot>[
    AppIconSlot(
      id: 'nav.home',
      group: groupNav,
      titleAr: 'الرئيسية',
      fallbackIcon: Icons.home_rounded,
    ),
    AppIconSlot(
      id: 'nav.search',
      group: groupNav,
      titleAr: 'البحث',
      fallbackIcon: Icons.search_rounded,
    ),
    AppIconSlot(
      id: 'nav.appointments',
      group: groupNav,
      titleAr: 'مواعيدي',
      fallbackIcon: Icons.calendar_month_rounded,
    ),
    AppIconSlot(
      id: 'nav.favorites',
      group: groupNav,
      titleAr: 'المفضلة',
      fallbackIcon: Icons.favorite_rounded,
    ),
    AppIconSlot(
      id: 'nav.account',
      group: groupNav,
      titleAr: 'حسابي',
      fallbackIcon: Icons.person_rounded,
    ),
  ];

  static List<AppIconSlot> get specialties {
    return [
      for (final s in SpecialtyCatalog.all)
        AppIconSlot(
          id: 'specialty.${s.id}',
          group: groupSpecialty,
          titleAr: s.nameAr,
          fallbackIcon: s.icon,
        ),
    ];
  }

  static List<AppIconSlot> get all => [
        ...home,
        ...nav,
        ...specialties,
      ];

  static AppIconSlot? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  static String? homeSlotIdForService(String serviceId) =>
      'home.$serviceId';

  static String? specialtySlotId(String specialtyId) =>
      'specialty.$specialtyId';
}
