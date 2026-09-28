import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_distance.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';

void main() {
  PharmacyItem pharmacy(String id, {double? lat, double? lng}) => PharmacyItem(
        id: id,
        name: id,
        address: 'a',
        phone: '1',
        whatsapp: '1',
        tags: const [],
        openFrom: '',
        openTo: '',
        isOpenNow: true,
        latitude: lat,
        longitude: lng,
      );

  test('sortByDistance puts nearer pharmacies first', () {
    final originLat = PharmacyDistance.shatraLat;
    final originLng = PharmacyDistance.shatraLng;
    final far = pharmacy('far', lat: 31.50, lng: 46.30);
    final near = pharmacy('near', lat: 31.4100, lng: 46.1720);
    final mid = pharmacy('mid', lat: 31.4200, lng: 46.1900);
    final sorted = PharmacyDistance.sortByDistance(
      [far, mid, near],
      originLat: originLat,
      originLng: originLng,
    );
    expect(sorted.map((e) => e.id).toList(), ['near', 'mid', 'far']);
  });

  test('pharmacies without coordinates stay at the end', () {
    final withCoords = pharmacy('ok', lat: 31.41, lng: 46.17);
    final missing = pharmacy('missing');
    final sorted = PharmacyDistance.sortByDistance(
      [missing, withCoords],
      originLat: PharmacyDistance.shatraLat,
      originLng: PharmacyDistance.shatraLng,
    );
    expect(sorted.first.id, 'ok');
    expect(sorted.last.id, 'missing');
  });

  test('open/supplements filters remain independent of distance helper', () {
    final open =
        pharmacy('open', lat: 31.41, lng: 46.17).copyWith(isOpenNow: true);
    final closed =
        pharmacy('closed', lat: 31.42, lng: 46.18).copyWith(isOpenNow: false);
    final onlyOpen = [open, closed].where((p) => p.isOpenNow).toList();
    expect(onlyOpen.map((e) => e.id), ['open']);
  });
}
