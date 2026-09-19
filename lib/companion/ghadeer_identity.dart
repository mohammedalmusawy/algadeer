import '../core/app_config.dart';
import '../search/arabic_text_utils.dart';

/// Phase 3D — هوية المساعد/التطبيق فقط (ليست ملف المستخدم ولا healthSubject).
///
/// حتمي، محلي، بلا OpenAI/NLU/بحث/تشخيص.
class GhadeerIdentity {
  const GhadeerIdentity();

  // —— حقائق ثابتة معتمدة ——
  static const String spiritualFatherName =
      'محمد عبد الحسن آل مسافر الموسوي';
  static const String supporterName = 'ليلى صلاح حسن آل مسافر الموسوي';
  static const String buildingAssistantName = 'حيدر عبد علي العبادي';
  static const String buildingAssistantFriendName =
      'مصطفى كامل سعود العبودي';

  /// مصدر واحد للراعي الحالي — قابل للتغيير عبر [AppConfig.ghadeerOfficialSponsor].
  static String get currentOfficialSponsorName =>
      AppConfig.ghadeerOfficialSponsor;

  static const String answerSelf =
      'آني الغدير، مساعدك الصحي الذكي، أساعدك توصل للطبيب والمختبر وخدمات الأشعة المناسبة داخل منصة الغدير.';

  static const String answerRole =
      'أساعدك توصل للطبيب أو المختبر أو خدمة الأشعة المناسبة داخل منصة الغدير، وأساعدك بالمعلومات والتنظيم بدون ما أستبدل تشخيص الطبيب.';

  static const String answerSpiritualFather =
      'الأب الروحي لتطبيق الغدير هو محمد عبد الحسن آل مسافر الموسوي.';

  static const String answerSupporter =
      'الداعم بتكوين تطبيق الغدير هي ليلى صلاح حسن آل مسافر الموسوي.';

  static const String answerBuildingAssistant =
      'ساعدوني ببناء وتطوير تطبيق الغدير حيدر عبد علي العبادي، '
      'والصديق العزيز مصطفى كامل سعود العبودي.';

  static const String answerUnknownIdentity =
      'هاي المعلومة بعد ما محددة عندي.';

  static String get answerCurrentSponsor =>
      'الراعي الرسمي الحالي لتطبيق الغدير هو $currentOfficialSponsorName.';

  /// إن وُجدت حقيقة هوية معروفة يُرجع النص؛ وإلا null.
  String? tryAnswer(String query) {
    final n = _normalizeIdentityQuery(query);
    if (n.isEmpty) return null;

    // ترتيب: الأكثر تحديداً أولاً.
    // المساعد البنائي قبل الداعم لأن «ساعد بتكوين تطبيق…» تخص المساعد.
    if (_isSpiritualFatherQuestion(n)) return answerSpiritualFather;
    if (_isSponsorQuestion(n)) return answerCurrentSponsor;
    if (_isBuildingAssistantQuestion(n)) return answerBuildingAssistant;
    if (_isSupporterQuestion(n)) return answerSupporter;
    if (_isRoleQuestion(n)) return answerRole;
    if (_isSelfIdentityQuestion(n)) return answerSelf;
    if (_isUnknownIdentityQuestion(n)) return answerUnknownIdentity;
    return null;
  }

  bool isIdentityQuestion(String query) => tryAnswer(query) != null;

  /// تطبيع خفيف للهوية — يعتمد تطبيع المشروع + إزالة ترقيم السؤال.
  static String _normalizeIdentityQuery(String raw) {
    var s = ArabicTextUtils.normalize(raw.trim());
    s = s
        .replaceAll(RegExp(r'[؟?!.،,;:]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  /// الأب الروحي للتطبيق — ليس «أبوي/أبي/والدي» كموضوع عائلي طبي.
  static bool _isSpiritualFatherQuestion(String n) {
    // رفض صريح لأسئلة والد المستخدم الطبية/العائلية.
    if (RegExp(
      r'(?:^|\s)(?:ابوي|ابي|والدي)(?:\s|$)',
    ).hasMatch(n)) {
      return false;
    }
    if (RegExp(r'(?:عنده|عندها|مريض|سعال|حرار|(?:^|\s)الم(?:\s|$)|ألم)').hasMatch(n)) {
      // جملة طبية حتى لو ذكرت «اب» — ليست سؤال هوية.
      return false;
    }

    // من(و) ابوك/ابيك الروحي
    if (RegExp(
      r'^(?:منو|من)\s*(?:ابوك|ابيك)\s*الروحي$',
    ).hasMatch(n)) {
      return true;
    }
    // من(و) (ال)اب الروحي … غدير/تطبيق
    if (RegExp(
      r'^(?:منو|من)\s*(?:ال)?اب\s*الروحي'
      r'(?:\s*(?:ل(?:ل)?(?:غدير|تطبيق)|للتطبيق|للغدير|'
      r'لتطبيق(?:\s*الغدير)?|تطبيق(?:\s*الغدير)?))?$',
    ).hasMatch(n)) {
      return true;
    }
    return false;
  }

  static bool _isSponsorQuestion(String n) {
    // من(و) الراعي الرسمي / راعي التطبيق / الراعي الرسمي للغدير
    if (RegExp(
      r'^(?:منو|من)\s*(?:ال)?راعي(?:\s*الرسمي)?'
      r'(?:\s*(?:'
      r'ل(?:ل)?(?:تطبيق|غدير)|للتطبيق|للغدير|'
      r'(?:ال)?تطبيق(?:\s*الغدير)?|(?:ال)?غدير'
      r'))?$',
    ).hasMatch(n)) {
      return true;
    }
    // يرعى / يرعي تطبيق الغدير
    if (RegExp(
      r'^(?:منو|من)\s*يرع[يى]\s*(?:ال)?تطبيق(?:\s*الغدير)?$',
    ).hasMatch(n)) {
      return true;
    }
    return false;
  }

  static bool _isSupporterQuestion(String n) {
    // الداعم / داعم + سياق تطبيق أو غدير أو تكوين
    if (RegExp(
      r'^(?:منو|من)\s*(?:ال)?داعم(?:\s*(?:ل(?:ل)?(?:تطبيق|غدير)|للتطبيق|للغدير|'
      r'في\s*تكوين(?:\s*(?:ال)?تطبيق)?|بتكوين(?:\s*(?:ال)?تطبيق(?:\s*الغدير)?)?|'
      r'ببناء(?:\s*تطبيق(?:\s*الغدير)?)?))?$',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'^(?:منو|من)\s*داعم(?:\s*(?:ال)?(?:تطبيق|غدير)|(?:\s*الغدير))?$',
    ).hasMatch(n)) {
      return true;
    }
    // «ساعد بتكوين الغدير» للداعم — بدون كلمة تطبيق (تلك للمساعد البنائي).
    if (RegExp(
      r'^(?:منو|من)\s*ساعد\s*(?:ب|في)?\s*تكوين\s*(?:ال)?غدير$',
    ).hasMatch(n)) {
      return true;
    }
    return false;
  }

  /// مساعدو بناء التطبيق — ليس «ساعدني عندي ألم…» / «أريد مساعدتك».
  static bool _isBuildingAssistantQuestion(String n) {
    // رفض طلب المساعدة السريرية/العامة (ليس سؤال هوية البناء).
    if (RegExp(
      r'(?:ساعدني|تساعدني|مساعدتك|اساعدك|أساعدك)',
    ).hasMatch(n) &&
        !RegExp(r'(?:بناء|تكوين|تطوير)').hasMatch(n)) {
      return false;
    }
    // «الم» بعد التطبيع = ألم — كلمة كاملة فقط (لا تُمسك «المساعد»).
    if (RegExp(
      r'(?:عنده|عندها|سعال|حرار|ضيق|ألم|(?:^|\s)الم(?:\s|$)|طبيب|مختبر)',
    ).hasMatch(n)) {
      return false;
    }

    // من(و) المساعد / المساعدين / مساعدك
    if (RegExp(
      r'^(?:منو|من)\s*(?:ال)?مساعد(?:ين|ك)?$',
    ).hasMatch(n)) {
      return true;
    }
    // من(و) المساعد(ين)/مساعدك ببناء|تكوين|تطوير …
    if (RegExp(
      r'^(?:منو|من)\s*(?:ال)?مساعد(?:ين|ك)?\s*(?:ب|في)?\s*(?:بناء|تكوين|تطوير)'
      r'(?:\s*(?:ال)?(?:تطبيق|غدير)(?:\s*الغدير)?)?$',
    ).hasMatch(n)) {
      return true;
    }
    // من(و) ساعد(ك) ببناء|تكوين …
    if (RegExp(
      r'^(?:منو|من)\s*ساعد(?:ك)?\s*(?:ب|في)?\s*(?:بناء|تكوين|تطوير)'
      r'(?:\s*(?:ال)?(?:تطبيق|غدير)(?:\s*الغدير)?)?$',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'^(?:منو|من)\s*ساعد\s*في\s*تكوين\s*تطبيق(?:\s*الغدير)?$',
    ).hasMatch(n)) {
      return true;
    }
    return false;
  }

  static bool _isRoleQuestion(String n) {
    if (RegExp(
      r'^(?:شنو|ما)\s*(?:دورك|شغلك|وظيفه(?:\s*(?:ال)?غدير)?|وظيفة(?:\s*(?:ال)?غدير)?)$',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(r'^(?:شتسوي|شنو\s*تسوي)$').hasMatch(n)) return true;
    if (RegExp(
      r'^(?:شنو|شلون)\s*تساعد(?:ني)?$',
    ).hasMatch(n)) {
      return true;
    }
    return false;
  }

  static bool _isSelfIdentityQuestion(String n) {
    if (RegExp(
      r'^(?:منو|من|شنو)\s*انت$',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(r'^عرفني\s*بنفسك$').hasMatch(n)) return true;
    if (RegExp(r'^(?:منو|من)\s*(?:ال)?غدير$').hasMatch(n)) return true;
    return false;
  }

  /// أسئلة هوية صريحة بلا حقيقة معتمدة — بلا اختراع أسماء.
  static bool _isUnknownIdentityQuestion(String n) {
    if (RegExp(
      r'^(?:منو|من)\s*(?:صنعك|برمجك|طورك)$',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'^(?:منو|من)\s*(?:مؤسس|صاحب)\s*(?:ال)?تطبيق(?:\s*الغدير)?$',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'^(?:منو|من)\s*(?:ال)?مدير(?:\s*(?:ال)?(?:تطبيق|غدير))?$',
    ).hasMatch(n)) {
      return true;
    }
    return false;
  }
}
