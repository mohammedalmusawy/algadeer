import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/models/radiology_models.dart';
import 'package:ghadeer_clinic/services/offline_rows_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مثل إنستا/فيس: بدون نت تظهر آخر بيانات ناجحة بدل شاشة فارغة.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('successful fetch is saved and returned', () async {
    final rows = await OfflineRowsCache.fetchOrCache(
      'doctors',
      () async => [
        {'id': 'd1', 'name': 'د. علي', 'phone': '0770'},
      ],
    );
    expect(rows.single['name'], 'د. علي');
    expect((await OfflineRowsCache.read('doctors'))!.single['id'], 'd1');
    expect(await OfflineRowsCache.savedAt('doctors'), isNotNull);
  });

  test('network failure serves the last saved copy and flags offline', () async {
    await OfflineRowsCache.save('labs', [
      {'id': 'l1', 'lab_name': 'مختبر الشطرة', 'display_order': 1},
    ]);
    OfflineRowsCache.lastOfflineServe.value = null;

    final rows = await OfflineRowsCache.fetchOrCache(
      'labs',
      () async => throw Exception('SocketException: no internet'),
    );
    expect(rows.single['lab_name'], 'مختبر الشطرة');
    expect(OfflineRowsCache.lastOfflineServe.value, isNotNull);
    // نفس الصف يتحوّل لنموذج المختبر بلا أخطاء.
    expect(LabItem.fromMap(rows.single).id, 'l1');
  });

  test('no saved copy keeps the original error (existing error UI)', () async {
    expect(
      () => OfflineRowsCache.fetchOrCache(
        'radiology_centers',
        () async => throw Exception('offline'),
      ),
      throwsException,
    );
  });

  test('fresh data replaces the old copy', () async {
    await OfflineRowsCache.save('radiology_centers', [
      {'id': 'old', 'name': 'قديم'},
    ]);
    await OfflineRowsCache.fetchOrCache(
      'radiology_centers',
      () async => [
        {'id': 'r1', 'name': 'أشعة الشطرة', 'is_active': true},
      ],
    );
    final saved = await OfflineRowsCache.read('radiology_centers');
    expect(saved!.map((e) => e['id']), ['r1']);
    expect(RadiologyCenter.fromMap(saved.single).id, 'r1');
  });

  test('non-JSON values (DateTime) do not break saving', () async {
    await OfflineRowsCache.save('doctors', [
      {'id': 'd2', 'updated_at': DateTime(2026, 10, 13)},
    ]);
    final saved = await OfflineRowsCache.read('doctors');
    expect(saved!.single['updated_at'], startsWith('2026-10-13'));
  });
}
