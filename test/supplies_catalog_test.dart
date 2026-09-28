import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/supplies/supplies_store.dart';
import 'package:ghadeer_clinic/supplies/supply_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog has default supply vendors', () {
    expect(SuppliesCatalog.items, isNotEmpty);
    expect(SuppliesCatalog.items.every((v) => v.name.isNotEmpty), isTrue);
    expect(SuppliesCatalog.items.every((v) => v.isActive), isTrue);
  });

  test('fromMap defaults isActive true and merges social', () {
    final v = SupplyVendor.fromMap({
      'id': 'x',
      'name': 'محل',
      'address': 'ا',
      'phone': '1',
      'whatsapp': '1',
      'categories': ['كراسي'],
      'openFrom': '9',
      'openTo': '9',
      'isOpenNow': true,
      'website_url': 'example.com',
    });
    expect(v.isActive, isTrue);
    expect(v.social.website, 'example.com');
  });

  test('store loads catalog when prefs empty', () async {
    SharedPreferences.setMockInitialValues({});
    // force fresh instance path via load on singleton after reset prefs
    final store = SuppliesStore.instance;
    // ignore private _loaded by calling through fresh prefs only once per process
    await store.load();
    expect(store.items, isNotEmpty);
  });

  test('sortByDistance puts nearer first', () {
    const near = SupplyVendor(
      id: 'n',
      name: 'قريب',
      address: 'a',
      phone: '1',
      whatsapp: '1',
      categories: [],
      openFrom: '',
      openTo: '',
      isOpenNow: true,
      latitude: 31.4100,
      longitude: 46.1720,
    );
    const far = SupplyVendor(
      id: 'f',
      name: 'بعيد',
      address: 'a',
      phone: '1',
      whatsapp: '1',
      categories: [],
      openFrom: '',
      openTo: '',
      isOpenNow: true,
      latitude: 31.5000,
      longitude: 46.3000,
    );
    final sorted = SupplyDistance.sortByDistance(
      [far, near],
      originLat: SupplyDistance.shatraLat,
      originLng: SupplyDistance.shatraLng,
    );
    expect(sorted.first.id, 'n');
  });
}
