import '../../search/arabic_text_utils.dart';
import 'assistant_intent.dart';
import 'intent_result.dart';

/// قفل نطاق الغدير: مساعد بحث/تنفيذ داخل المنصة فقط — بلا اختراع وبلا معرفة عامة.
class GhadeerScopeGate {
  GhadeerScopeGate._();

  /// الرد العراقي المهذّب خارج نطاق المنصة.
  static const String outOfScopeMessage =
      'أعتذر منك، أنا مساعد خاص بمنصة الغدير، وأكدر أساعدك بالبحث عن '
      'الأطباء والاختصاصات والصيدليات والمختبرات والباقات والأشعة '
      'والعلاج الطبيعي والمستلزمات والخدمات الموجودة بالمنصة.';

  /// نية صريحة داخل المنصة — لا تُرفض حتى لو فيها كلمات عامة.
  static bool isPlatformOwnedIntent(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.doctorSearch:
      case AssistantIntent.specialtySearch:
      case AssistantIntent.findLab:
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
      case AssistantIntent.findAnalysis:
      case AssistantIntent.findRadiology:
      case AssistantIntent.findPharmacy:
      case AssistantIntent.findPhysio:
      case AssistantIntent.findSupply:
      case AssistantIntent.doctorAvailability:
      case AssistantIntent.bookAppointment:
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.callRadiology:
      case AssistantIntent.messageRadiology:
      case AssistantIntent.callPharmacy:
      case AssistantIntent.messagePharmacy:
      case AssistantIntent.callPhysio:
      case AssistantIntent.messagePhysio:
      case AssistantIntent.callSupply:
      case AssistantIntent.messageSupply:
      case AssistantIntent.showLocation:
      case AssistantIntent.showProfile:
      case AssistantIntent.showMore:
      case AssistantIntent.selectResult:
      case AssistantIntent.repeatResponse:
      case AssistantIntent.stopSpeaking:
      case AssistantIntent.help:
        return true;
      case AssistantIntent.generalSearch:
      case AssistantIntent.unknown:
      case AssistantIntent.symptomGuidance:
        return false;
    }
  }

  /// إشارات بحث/تنفيذ داخل بيانات الغدير.
  static bool hasPlatformCue(String query) {
    final n = ArabicTextUtils.normalize(query);
    if (n.isEmpty) return false;
    return RegExp(
      r'(?:طبيب|دكتور|د\.|دكتوره|دكتورة|اختصاص|تخصص|'
      r'صيدل|مختبر|مختبرات|باق|عرض|عروض|تحليل|تحاليل|'
      r'اشع|أشعة|شعاع|سونار|رنين|مفراس|تصوير|'
      r'واتس|وتساب|اتصال|اتصل|دز|راسل|احجز|حجز|'
      r'افتح|بطاقة|ملف|موقع|عنوان|دوام|متوفر|متواجد|'
      r'اطفال|أطفال|جهال|نسائية|عظام|جلدية|اسنان|أسنان|'
      r'الغدير|منصة)',
    ).hasMatch(n);
  }

  /// معرفة عامة / خارج المنصة بوضوح.
  static bool isOutOfScope(String query) {
    final n = ArabicTextUtils.normalize(query);
    if (n.isEmpty) return false;
    // إن وُجدت إشارة منصة قوية مع سؤال عام، لا نرفض (نادر).
    // الرفض يعتمد على أنماط خارج النطاق أولاً.
    return _outOfScopePattern.hasMatch(n);
  }

  static final RegExp _outOfScopePattern = RegExp(
    // بعد ArabicTextUtils.normalize: ة→ه، ى→ي، أ/إ/آ→ا، ئ→ي (نتائج→نتايج).
    r'(?:كاس\s*العالم|فيفا|مبارا|دوري\s*الابطال|نتايج\s*الدوري|منو\s*احسن\s*لاعب|'
    r'من\s*(?:فاز|فازت|فازوا)|منو\s*فاز|'
    r'الطقس|الجو\s*(?:اليوم|باجر|هسه)|درجه\s*الحراره|حاله\s*الطقس|'
    r'سعر\s*(?:الدولار|الذهب|النفط|البيتكوين)|بورصه|اسهم|'
    r'ترجم|ترجمه|معني\s*كلمه|'
    r'وصفه|طبخه|اكله|طبخ\s|تحضير\s*كيك|وصفه\s*كبه|'
    r'الرييس|الرئيس|الممثل|المغني|اخبار\s*(?:ال)?سياس|اخبار\s*هوليود|'
    r'عاصمه|'
    r'يوتيوب|فيسبوك|انستا|تيك\s*توك|افتح\s*انستغرام|'
    r'ذكاء\s*اصطناعي\s*عام|شات\s*جي\s*بي\s*تي|'
    r'اعطني\s*دواء|عطني\s*دواء|وصف\s*لي\s*علاج|شنو\s*التشخيص|'
    r'هل\s*عندي\s*(?:سرطان|سكري|ضغط)|'
    r'منو\s+ريي+س|ريي+س\s*(?:ال)?جمهور|ريي+س\s*(?:ال)?وزرا\S*|'
    r'شغل\s*(?:اغنيه|اغنية|موسيقى)|كلمات\s*اغنيه|'
    r'احسب\s*لي|احسبلي|حل\s*معادله|برمجه\s*بايثون|بايثون|'
    r'اطلب\s*بيتزا|شراء\s*ملابس|سافر\s*لي|تذكره\s*طيران|'
    r'توقعات\s*الابراج|قصيده\s*غزل|نكت(?:ه|ة)|يانصيب|'
    r'احجز\s*فندق|شراء\s*سياره|من\s*اخترع|'
    r'سودوكو|sudoku|حل\s*سودوكو|'
    r'عاصمه\s+\S+)',
    caseSensitive: false,
  );

  /// هل يجب رفض الدور بدل البحث العام؟
  static bool shouldRefuse({
    required String query,
    required IntentResult intent,
  }) {
    // معرفة عامة واضحة → رفض حتى لو صُنّفت النية خطأً كبحث طبيب.
    if (isOutOfScope(query)) return true;
    if (isPlatformOwnedIntent(intent.intent)) return false;
    // unknown بلا محتوى منصة → رفض مهذّب (لا ترقية لبحث عام).
    if (intent.intent == AssistantIntent.unknown) return true;
    // generalSearch بلا إشارة منصة وبلا اسم يبدو ككيان قصير → رفض.
    if (intent.intent == AssistantIntent.generalSearch) {
      if (hasPlatformCue(query)) return false;
      final n = ArabicTextUtils.normalize(query);
      final words = n.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.isEmpty) return true;
      if (words.length <= 4 && !_looksLikeTriviaQuestion(n)) return false;
      return true;
    }
    return false;
  }

  static bool _looksLikeTriviaQuestion(String n) {
    return RegExp(
      r'(?:من\s|منو\s|شنو\s|ايش\s|كم\s|متى\s|وين\s*(?:تقع|صارت)|'
      r'هل\s*(?:تعرف|تعلم)|اخبرني|قل\s*لي)',
    ).hasMatch(n);
  }
}
