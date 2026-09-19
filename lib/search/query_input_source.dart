/// مصدر الاستعلام — يفصل سلوك البحث الكتابي عن الصوتي.
enum QueryInputSource {
  /// إدخال لوحة المفاتيح / debounce — صامت دائمًا.
  typed,

  /// جلسة مايك مكتملة — يُسمح بالرد الصوتي عند الأوامر المناسبة.
  voice,

  /// مسارات داخلية (إعادة محاولة، نظام) — صامت افتراضيًا.
  system,
}

extension QueryInputSourceX on QueryInputSource {
  /// النطق مسموح فقط لمصدر الصوت (أو طلب قراءة صريح من الواجهة).
  bool get allowsAutoSpeak => this == QueryInputSource.voice;

  /// شريط «جاري معالجة الطلب الصوتي…» وحالة processing للصوت فقط.
  bool get showsVoiceProcessingUi => this == QueryInputSource.voice;
}
