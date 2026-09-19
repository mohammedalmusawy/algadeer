/// توجيه أوامر Companion حسب المجال — للتمديد المستقبلي بلا if/else عملاق.
import '../search/arabic_text_utils.dart';

enum CompanionCommandDomain {
  /// PC-1.3 — ملف صاحب الحساب الأساسي فقط.
  accountOwnerProfile,

  /// PC-1.12 — أهداف/اهتمامات/تفضيلات.
  personalMemory,

  /// PC-1.4 — ذاكرة صحية حسّاسة.
  sensitiveHealthMemory,

  /// PC-1.8 — ملفات العائلة.
  familyProfiles,

  /// مستقبل: أهداف ومتابعة (التفصيل عبر personalMemory + PC-1.11).
  goals,
  followUps,
}

/// نتيجة توجيه خفيفة — بدون تخمين AI.
class CompanionCommandRoute {
  const CompanionCommandRoute({
    required this.domain,
    required this.matched,
    this.notes = '',
  });

  final CompanionCommandDomain domain;
  final bool matched;
  final String notes;

  static const none = CompanionCommandRoute(
    domain: CompanionCommandDomain.accountOwnerProfile,
    matched: false,
  );
}

/// موجّه مجالات — PC-1.3 ملف أساسي + PC-1.4 صحة حسّاسة.
class CompanionCommandRouter {
  const CompanionCommandRouter();

  /// توجيه عام — الصحة الحسّاسة قبل الملف الأساسي عند التعارض السطحي.
  CompanionCommandRoute? route(String query) {
    final n = ArabicTextUtils.normalize(query);
    if (n.isEmpty) return null;

    if (_looksLikeSensitiveHealthCommand(n)) {
      return const CompanionCommandRoute(
        domain: CompanionCommandDomain.sensitiveHealthMemory,
        matched: true,
        notes: 'pc14_sensitive_health',
      );
    }
    if (_looksLikeFamilyPeopleCommand(n)) {
      return const CompanionCommandRoute(
        domain: CompanionCommandDomain.familyProfiles,
        matched: true,
        notes: 'pc18_family_people',
      );
    }
    if (_looksLikePersonalMemoryCommand(n)) {
      return const CompanionCommandRoute(
        domain: CompanionCommandDomain.personalMemory,
        matched: true,
        notes: 'pc12_personal_memory',
      );
    }
    if (_looksLikeAccountOwnerProfileCommand(n)) {
      return const CompanionCommandRoute(
        domain: CompanionCommandDomain.accountOwnerProfile,
        matched: true,
        notes: 'pc13_basic_profile',
      );
    }
    return null;
  }

  /// PC-1.12 — أهداف/اهتمامات/تفضيلات.
  CompanionCommandRoute? routePersonalMemory(String query) {
    final r = route(query);
    if (r != null && r.domain == CompanionCommandDomain.personalMemory) {
      return r;
    }
    return null;
  }

  /// PC-1.8 — ملفات الأشخاص.
  CompanionCommandRoute? routeFamilyPeople(String query) {
    final r = route(query);
    if (r != null && r.domain == CompanionCommandDomain.familyProfiles) {
      return r;
    }
    return null;
  }

  /// توافق مع PC-1.3.
  CompanionCommandRoute? routeProfileSurface(String query) {
    final r = route(query);
    if (r == null) return null;
    if (r.domain == CompanionCommandDomain.accountOwnerProfile) return r;
    return null;
  }

  bool _looksLikeSensitiveHealthCommand(String n) {
    return RegExp(
      r'(?:شنو|ماذا|ايش)\s*(?:تعرف\s*عن\s*صحتي|الامراض|الأمراض)|'
      r'(?:معلوماتي\s*الصحيه|الملف\s*الصحي)|'
      r'(?:تذكر|تذكّر|احفظ)\s*(?:ان|أن)?\s*(?:عندي\s*)?(?:سكري|ضغط|ربو)|'
      r'(?:امسح|احذف|لا\s*تتذكر)\s*(?:ال)?(?:سكري|ضغط|ربو)|'
      r'(?:عطل|فعل)\s*(?:استخدام\s*)?(?:معلوماتي\s*الصحيه|الملف\s*الصحي)|'
      r'(?:عندي\s*(?:سكري|ضغط|ربو).*(?:مشخص|مشخّص|شخص)|'
      r'مشخص(?:ني|ين|هن).*(?:سكري|ضغط)|'
      r'(?:سكري|ضغط).*(?:مشخص|مشخّص))',
    ).hasMatch(n);
  }

  bool _looksLikeFamilyPeopleCommand(String n) {
    if (_looksLikeSensitiveHealthCommand(n)) return false;
    // جلسة صحية مؤقتة — لا ملف
    if (RegExp(r'(?:حراره|حرارة|حمى|الم|ألم|سكر|ضغط|سعال)').hasMatch(n) &&
        !RegExp(r'(?:تذكر|احفظ)\s*(?:ابني|ابنتي|امي|زوج)').hasMatch(n)) {
      return false;
    }
    // طبيب/مختبر — discovery
    if (RegExp(r'(?:أريد|اريد|ابي|دور)\s*(?:طبيب|دكتور|مختبر)').hasMatch(n)) {
      return false;
    }
    return RegExp(
      r'(?:تذكر|احفظ|سجل)\s*(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي|اسم)|'
      r'(?:اسم\s*(?:ابني|ابنتي|امي|زوجتي))|'
      r'(?:منو\s*متذكر\s*من\s*عا?يلتي|شنو\s*الاشخاص\s*اللي\s*حافظهم)|'
      r'(?:شنو\s*تعرف\s*عن\s*(?:ابني|ابنتي|امي|ابوي|زوجتي))|'
      r'(?:غير|بدّل|بدل|صحح)\s*(?:اسم|مواليد)\s*(?:ابني|ابنتي|امي|ابوي|زوجتي)|'
      r'(?:امسح|احذف|لا\s*تتذكر)\s*(?:ملف)?\s*(?:ابني|ابنتي|امي|زوجتي)|'
      r'(?:عطل|وقف)\s*(?:ملف|تذكر)',
    ).hasMatch(n);
  }

  bool _looksLikePersonalMemoryCommand(String n) {
    return RegExp(
      r'(?:تذكر|تذكّر|احفظ|خلي\s*ببالك)\s*(?:ان|أن|اني|أني|هدي|هدفي|اني\s*اتعلم)|'
      r'(?:شنو|ماذا)\s*(?:اهدافي|أهدافي|اهتماماتي|تفضيلاتي)|'
      r'(?:شنو|ماذا)\s*(?:الاشياء|الأشياء)\s*(?:اللي\s*)?تتذكرها|'
      r'(?:شنو|ماذا)\s*(?:تعرف|حافظ)\s*(?:عني|علي)|'
      r'(?:امسح|احذف)\s*كل\s*(?:اهدافي|أهدافي|اهتماماتي|تفضيلاتي)|'
      r'(?:كملت\s*هدفي|اعتبر\s*(?:هذا\s*)?الهدف\s*مكتمل)|'
      r'(?:وقف\s*(?:هذا\s*)?الهدف|رجع\s*هدفي)|'
      r'(?:احذف|امسح|لا\s*تتذكر)\s*(?:اهتمامي|هدفي|هدف)|'
      r'(?:افضل|أفضل)\s*(?:الشرح|النص)|'
      r'(?:مو|مش)\s*(?:flutter|فلتر).{0,40}(?:figma|فيجما|هدفي)',
    ).hasMatch(n);
  }

  bool _looksLikeAccountOwnerProfileCommand(String n) {
    // لا تلتقط أوامر الصحة كأوامر ملف أساسي
    if (_looksLikeSensitiveHealthCommand(n)) return false;
    if (_looksLikeFamilyPeopleCommand(n)) return false;
    if (_looksLikePersonalMemoryCommand(n)) return false;
    return RegExp(
      r'(?:شنو|ماذا|ايش|وش)\s*(?:تعرف|حافظ|معلوماتي)|'
      r'عرفني\s*شنو\s*تعرف|'
      r'(?:شنو|كم)\s*(?:اسمي|عمري|سنه\s*ميلادي|سنة\s*ميلادي|مسجل)|'
      r'(?:غير|بدّل|بدل|صحح|خلّي|خلي)\s*(?:اسمي|اسم|سنه|سنة|ميلاد|شغلي|اختياريه\s*الجنس|اختيار\s*الجنس)|'
      r'(?:ناديني|من\s*هسه\s*ناديني|اسمي\s*المفضل)|'
      r'(?:انا\s*مواليد|مواليد\s*\d)|'
      r'(?:صرت|انا\s*(?:مو\s*)?(?:موظف|طالب|عمل\s*حر))|'
      r'(?:سجلني\s*(?:ذكر|انثي|انثى)|افضل\s*عدم\s*تحديد\s*الجنس|غير\s*اختيار\s*الجنس)|'
      r'(?:امسح|احذف|لا\s*تحتفظ)\s*(?:اسمي|سنه|سنة|تاريخ\s*ميلاد|اختيار\s*الجنس|سياق)|'
      r'(?:انس[ىي]?\s*(?:سنه|سنة|اسمي|ميلاد|شغلي|جنسي))|'
      r'(?:احذف\s*ملفي|امسح\s*ملفي)|'
      r'(?:عطل|فعل)\s*(?:الملف|التخصيص|ملفي)|'
      r'(?:لا\s*تستخدم\s*(?:جنسي|ملفي)|رجع\s*التخصيص)',
    ).hasMatch(n);
  }
}
