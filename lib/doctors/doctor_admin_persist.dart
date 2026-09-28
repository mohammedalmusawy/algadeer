// مساعدات حفظ سجل الطبيب من لوحة الإدارة.
//
// بعض أعمدة doctor_profile_schema.sql قد لا تكون مطبّقة على الإنتاج بعد.
// لا نرسلها في الحمولة حتى لا يفشل التحديث (PGRST204)، مع الإبقاء على
// إعادة المحاولة كشبكة أمان في نموذج الإدارة.

/// أعمدة ملف الطبيب الإضافية — موجودة في SQL لكن غير مؤكّدة على الإنتاج.
const Set<String> kDoctorProfileColumnsPendingMigration = {
  'age_group',
  'years_experience',
  'patients_served',
  'languages',
  'qualifications',
  'profile_quote',
};

/// يستخرج اسم العمود المفقود من رسالة PostgREST (PGRST204).
String? missingDoctorColumnFromPostgrest(String message) {
  final match = RegExp(
    r"Could not find the '([^']+)' column",
    caseSensitive: false,
  ).firstMatch(message);
  return match?.group(1);
}

/// يزيل أعمدة الملف الشخصي غير الموجودة على الإنتاج من حمولة الحفظ.
Map<String, dynamic> doctorSavePayloadForProduction(
  Map<String, dynamic> raw,
) {
  final payload = Map<String, dynamic>.from(raw);
  for (final column in kDoctorProfileColumnsPendingMigration) {
    payload.remove(column);
  }
  return payload;
}

/// توحيد الاسم للمقارنة (مسافات زائدة + همزات شائعة).
String normalizeDoctorNameKey(String raw) {
  var t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  t = t
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
  return t;
}

/// أرقام الهاتف فقط للمقارنة (يتجاهل مسافات ورموز الاتجاه).
String normalizeDoctorPhoneKey(String raw) {
  return raw.replaceAll(RegExp(r'[^0-9+]'), '');
}

/// هل صفّان يمثلان نفس الطبيب (اسم + هاتف)؟
bool isSameDoctorIdentity({
  required String nameA,
  required String phoneA,
  required String nameB,
  required String phoneB,
}) {
  final nA = normalizeDoctorNameKey(nameA);
  final nB = normalizeDoctorNameKey(nameB);
  if (nA.isEmpty || nB.isEmpty || nA != nB) return false;
  final pA = normalizeDoctorPhoneKey(phoneA);
  final pB = normalizeDoctorPhoneKey(phoneB);
  if (pA.isEmpty || pB.isEmpty) return false;
  return pA == pB;
}

/// أول مطابقة موجودة لنفس الاسم+الهاتف (لتحديث بدل إدراج مكرر).
String? findExistingDoctorIdByNamePhone({
  required List<Map<String, dynamic>> rows,
  required String name,
  required String phone,
  String? excludeId,
}) {
  for (final row in rows) {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) continue;
    if (excludeId != null && id == excludeId) continue;
    if (isSameDoctorIdentity(
      nameA: name,
      phoneA: phone,
      nameB: row['doctor_name']?.toString() ?? '',
      phoneB: row['phone']?.toString() ?? '',
    )) {
      return id;
    }
  }
  return null;
}
