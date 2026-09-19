import '../../search/arabic_text_utils.dart';

/// بوابة سلامة للصحة النفسية — عالية الأولوية، محافظة ضد التعابير المجازية.
class MentalHealthSafetyGate {
  const MentalHealthSafetyGate();

  /// هل اللغة تشير لخطر جاد محتمل؟
  bool triggersCrisis(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return false;

    // تعبيرات مجازية شائعة — لا تُفعّل الأزمة وحدها
    if (_isClearlyIdiomatic(n) && !_hasGenuineDangerMarkers(n)) {
      return false;
    }

    // نية إيذاء صريحة / خطر فوري
    if (RegExp(
      r'(?:ابي\s*اقتل\s*نفسي|أريد\s*أقتل\s*نفسي|اريد\s*اقتل\s*نفسي|'
      r'راح\s*اقتل\s*نفسي|بقتل\s*نفسي|انتحر|الانتحار|'
      r'ما\s*اريد\s*اعيش|ما\s*أريد\s*أعيش|'
      r'ابي\s*اذي\s*نفسي|أريد\s*أؤذي\s*نفسي|'
      r'راح\s*اذي\s*(?:حد|احد|أحد)|ابي\s*اذي\s*(?:حد|احد)|'
      r'اذي\s*نفسي\s*هسه|أؤذي\s*نفسي\s*الآن)',
    ).hasMatch(n)) {
      return true;
    }

    // عبارات خطر غامضة مع نية واضحة نسبياً
    if (RegExp(
      r'(?:افضل\s*الموت|أفضل\s*الموت|اتمنى\s*اموت|أتمنى\s*أموت)',
    ).hasMatch(n) &&
        RegExp(r'(?:جدا|هسه|الآن|اليوم|بجد|صدق)').hasMatch(n)) {
      return true;
    }

    return false;
  }

  bool _isClearlyIdiomatic(String n) => RegExp(
        r'(?:موتني\s*(?:الامتحان|الشغل|الحر)|'
        r'هذا\s*الشغل\s*قاتلني|'
        r'راح\s*اموت\s*من\s*(?:الخوف|الضحك|الجوع)|'
        r'قتلني\s*(?:التعب|الامتحان|الشغل))',
      ).hasMatch(n);

  bool _hasGenuineDangerMarkers(String n) => RegExp(
        r'(?:اقتل\s*نفسي|انتحر|اذي\s*نفسي|أؤذي\s*نفسي)',
      ).hasMatch(n);

  /// رد أزمة قصير وهادئ — بلا أرقام طوارئ مخترعة، بلا تعليمات ضارة.
  String crisisMessage() {
    return 'يبدو إنك بوضع صعب ويحتاج اهتمام فوري.\n'
        'إذا في خطر على نفسك أو غيرك، اطلب مساعدة شخص تثق بيه قريب منك الآن، '
        'أو توجه لأقرب جهة طبية/طارئة متاحة عندك.\n'
        'ما أقدر أستبدل المساعدة الميدانية.';
  }
}
