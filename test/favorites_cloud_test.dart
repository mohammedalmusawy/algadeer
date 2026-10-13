import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/services/favorites_cloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// المفضلة كانت محلية فقط، فانمسحت لما انمسح التطبيق. هسه تنحفظ بالحساب
/// إذا المستخدم مسجّل دخول، وبدون دخول تبقى مثل قبل.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('الدمج بدون تكرار ويحافظ على ترتيب الجهاز', () {
    expect(unionFavorites(['a', 'b'], ['b', 'c', ' ', 'a']), ['a', 'b', 'c']);
    expect(unionFavorites(const [], ['x']), ['x']);
  });

  test('المفاتيح نفس اللي يستخدمها التطبيق من قبل', () {
    expect(FavoriteKeys.doctors, 'favoriteDoctorIds');
    expect(FavoriteKeys.labs, 'favoriteLabIds');
    expect(FavoriteKeys.radiology, 'favoriteRadiologyIds');
    expect(FavoriteKeys.pharmacies, 'favoritePharmacyIds');
  });

  test(
    'بدون حساب (أو بدون Supabase) المفضلة المحلية تبقى ولا شي يكسر',
    () async {
      SharedPreferences.setMockInitialValues({
        'favoriteDoctorIds': ['d1', 'd2'],
      });
      final cloud = FavoritesCloud.instance;
      expect(cloud.isSignedIn, isFalse);
      expect(await cloud.merge(FavoriteKeys.doctors, ['d1', 'd2']), [
        'd1',
        'd2',
      ]);
      await cloud.push(FavoriteKeys.doctors, ['d1']);
      await cloud.syncAll();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('favoriteDoctorIds'), ['d1', 'd2']);
    },
  );
}
