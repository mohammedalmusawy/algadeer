/// إعدادات التطبيق — بدون أسرار AI في العميل.
///
/// القيم الافتراضية تُبقي التطبيق يعمل كما هو.
/// للإنتاج يُفضَّل تمرير:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ployefiobsnqqahdwnkh.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_81HwY5goKkjgSClDuGX_Gw_xm_it86y',
  );

  /// رابط Edge Function مستقبلي للذكاء الاصطناعي (فارغ = غير مفعّل).
  /// لا تضع API Key هنا أبدًا.
  static const String aiEdgeFunctionUrl = String.fromEnvironment(
    'AI_EDGE_FUNCTION_URL',
    defaultValue: '',
  );

  static bool get isAiBackendConfigured => aiEdgeFunctionUrl.trim().isNotEmpty;

  /// الراعي الرسمي الحالي لتطبيق الغدير (قيمة تجارية قابلة للتغيير).
  /// مصدر واحد — غيّره هنا أو عبر:
  /// `--dart-define=GHADEER_OFFICIAL_SPONSOR=...`
  static const String ghadeerOfficialSponsor = String.fromEnvironment(
    'GHADEER_OFFICIAL_SPONSOR',
    defaultValue: 'أبو سعدية للموبايلات',
  );
}
