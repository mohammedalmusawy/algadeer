import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/radiology_models.dart';

/// الأشعة صارت مثل الأطباء/المختبرات: رقم نسخة يمنع حفظ فوق تعديل شخص ثاني.
void main() {
  test('content_revision is read from the row, default 1', () {
    expect(
      RadiologyCenter.fromMap({'id': 'r1', 'name': 'أشعة', 'content_revision': 4})
          .contentRevision,
      4,
    );
    expect(
      RadiologyCenter.fromMap({'id': 'r2', 'name': 'أشعة'}).contentRevision,
      1,
    );
  });

  test('toMap does not send a stale revision by itself', () {
    const c = RadiologyCenter(id: 'r1', name: 'أشعة', contentRevision: 3);
    expect(c.toMap().containsKey('content_revision'), isFalse);
  });
}
