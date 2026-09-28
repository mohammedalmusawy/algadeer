import 'dart:math' as math;

import 'pharmacy_models.dart';

/// مسافة وترتيب صيدليات «قريب مني» — منطق نقي بدون GPS.
class PharmacyDistance {
  PharmacyDistance._();

  /// مركز تقريبي للشطرة — يُستخدم إن تعذّر الحصول على موقع المستخدم.
  static const shatraLat = 31.4095;
  static const shatraLng = 46.1718;

  /// مسافة تقريبية بالكيلومتر (Haversine).
  static double kmBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthKm = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthKm * c;
  }

  static double? distanceKmFor(
    PharmacyItem p, {
    required double originLat,
    required double originLng,
  }) {
    final lat = p.latitude;
    final lng = p.longitude;
    if (lat == null || lng == null) return null;
    return kmBetween(originLat, originLng, lat, lng);
  }

  /// الأقرب أولاً؛ بدون إحداثيات في النهاية (ترتيب ثابت بينها).
  static List<PharmacyItem> sortByDistance(
    List<PharmacyItem> items, {
    required double originLat,
    required double originLng,
  }) {
    final indexed = <({PharmacyItem p, double? d, int i})>[
      for (var i = 0; i < items.length; i++)
        (
          p: items[i],
          d: distanceKmFor(
            items[i],
            originLat: originLat,
            originLng: originLng,
          ),
          i: i,
        ),
    ];
    indexed.sort((a, b) {
      if (a.d == null && b.d == null) return a.i.compareTo(b.i);
      if (a.d == null) return 1;
      if (b.d == null) return -1;
      final c = a.d!.compareTo(b.d!);
      return c != 0 ? c : a.i.compareTo(b.i);
    });
    return [for (final e in indexed) e.p];
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}
