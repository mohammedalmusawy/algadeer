import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacies_store.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';

PharmacyItem _item(String id, {String slogan = 'محلي', bool active = true}) {
  return PharmacyItem(
    id: id,
    name: id,
    address: 'عنوان',
    phone: '1',
    whatsapp: '1',
    tags: const [],
    openFrom: '8',
    openTo: '10',
    isOpenNow: true,
    slogan: slogan,
    isActive: active,
  );
}

void main() {
  test('الكتالوج المنشور يُخفي تعديلًا محليًا عن الزائر ويبقيه للإدارة إن لم يُنشر', () {
    final local = [_item('rehab', slogan: 'تعديل جهاز'), _item('local-only')];
    final shared = [_item('rehab', slogan: 'منشور')];

    final visitors = pharmacyPublicItems(
      shared: shared,
      sharedReady: true,
      local: local,
    );
    expect(visitors.map((item) => item.id), ['rehab']);
    expect(visitors.single.slogan, 'منشور');

    final admin = pharmacyAdminItems(
      shared: shared,
      sharedReady: true,
      local: local,
    );
    expect(admin.map((item) => item.id), containsAll(['rehab', 'local-only']));
    expect(admin.firstWhere((item) => item.id == 'rehab').slogan, 'منشور');
    expect(admin.firstWhere((item) => item.id == 'local-only').slogan, 'محلي');
  });

  test('صيدلية أخفاها المدير أو حذفها لا تعود من النسخة المحلية أو الكتالوج المضمّن', () {
    final hiddenAll = pharmacyPublicItems(
      shared: const [],
      sharedReady: true,
      local: [_item('rehab', slogan: 'على الجهاز')],
    );
    expect(hiddenAll, isEmpty);

    final inactive = pharmacyPublicItems(
      shared: [_item('rehab', active: false)],
      sharedReady: true,
      local: [_item('rehab'), _item('shatra')],
    );
    expect(inactive, isEmpty);

    final onlyPublished = pharmacyPublicItems(
      shared: [_item('rehab')],
      sharedReady: true,
      local: [_item('rehab'), _item('shatra')],
    );
    expect(onlyPublished.map((item) => item.id), ['rehab']);

    final beforePublish = pharmacyPublicItems(
      shared: const [],
      sharedReady: false,
      local: [_item('rehab', slogan: 'على الجهاز')],
    );
    expect(beforePublish.single.slogan, 'على الجهاز');

    final bundled = pharmacyPublicItems(
      shared: const [],
      sharedReady: false,
      local: const [],
    );
    expect(bundled.map((item) => item.id), contains('rehab'));
  });
}
