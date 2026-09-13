/// بوابة دخول الإدارة لـ **تشغيل التطبيق الحالي فقط**.
///
/// - تُفتح بعد إدخال كلمة السر بنجاح مرة واحدة.
/// - تبقى حتى يُغلق التطبيق أو يُحدَّث المتصفح (Hot restart / Refresh).
/// - ليست جلسة Supabase المخزّنة في المتصفح لأيام.
class AdminLaunchSession {
  AdminLaunchSession._();

  static bool unlocked = false;

  static void markUnlocked() => unlocked = true;

  static void clear() => unlocked = false;
}
