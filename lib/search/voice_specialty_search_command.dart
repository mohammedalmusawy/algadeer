import '../doctors/specialty_catalog.dart';
import 'arabic_text_utils.dart';

/// أمر بحث اختصاص: «ابحثلي عن طبيب جملة عصبية».
/// لا يلتقط أسماء الأطباء مثل «دكتور ناجي».
class VoiceSpecialtySearchCommand {
  const VoiceSpecialtySearchCommand({
    required this.specialtyQuery,
    required this.resolvedSpecialtyName,
    required this.rawQuery,
  });

  final String specialtyQuery;
  final String resolvedSpecialtyName;
  final String rawQuery;

  static VoiceSpecialtySearchCommand? tryParse(String raw) {
    final original = raw.trim();
    if (original.isEmpty) return null;

    final hasVerb = _hasSearchVerb(original);
    final hasDoctorsPlural = RegExp(
      r'(?:^|\s)(?:أطباء|اطباء|دكاترة)\s+',
      caseSensitive: false,
    ).hasMatch(original);
    final hasDoctorPlusSpecialtyHint = RegExp(
      r'(?:طبيب|دكتور)\s+(?:اختصاص|تخصص|جملة|باطن|أطفال|اطفال|عظام|قلب|أعصاب|اعصاب|نساء|جلد|أسنان|اسنان)',
      caseSensitive: false,
    ).hasMatch(original) ||
        _hasCatalogSpecialtyAfterDoctorWord(original);

    if (!hasVerb && !hasDoctorsPlural && !hasDoctorPlusSpecialtyHint) {
      return null;
    }

    var rest = original.replaceFirst(
      RegExp(
        r'^(?:أريد|اريد|ابي|أبغى|من\s+فضلك|لو\s+سمحت)?\s*'
        r'(?:ابحث(?:لي| لي)?|دور(?:لي| لي)?|طلّع|طلع|ورّيني|وريني|اعرض)\s*'
        r'(?:عن\s+|على\s+)?'
        r'(?:طبيب|دكتور|أطباء|اطباء|دكاترة)?\s*'
        r'(?:اختصاص\s+|تخصص\s+)?'
        r'(?:في\s+|ب)?\s*',
        caseSensitive: false,
      ),
      '',
    );

    if (rest.trim() == original.trim()) {
      rest = original.replaceFirst(
        RegExp(
          r'^(?:أريد|اريد)?\s*'
          r'(?:أطباء|اطباء|دكاترة|طبيب|دكتور)\s*'
          r'(?:اختصاص\s+|تخصص\s+)?',
          caseSensitive: false,
        ),
        '',
      );
    }

    rest = rest
        .replaceAll(
          RegExp(r'^(?:ال)?(?:اختصاص|تخصص)\s+', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s+(?:من فضلك|لو سمحت|رجاء|رجاءً|حالًا|حاليا|الآن|الان)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    if (rest.isEmpty) return null;

    final lower = rest.toLowerCase();
    if (lower.contains('اتصل') ||
        lower.contains('واتس') ||
        lower.contains('whatsapp')) {
      return null;
    }

    // اسم شخص بعد «دكتور …» ليس اختصاصًا — نطلب مصطلح كتالوج بكلمة كاملة
    // حتى لا يصبح «حسن» بحث أسنان عبر الاحتواء الجزئي لـ«سن».
    if (_looksLikePersonName(rest) && !SpecialtyCatalog.isSpecialtyTerm(rest)) {
      return null;
    }

    final matched = SpecialtyCatalog.matchPhrase(rest);
    if (matched == null && !hasVerb) {
      // بدون فعل بحث: نطلب تطابق كتالوج فقط.
      return null;
    }
    if (matched == null && hasVerb && rest.trim().split(RegExp(r'\s+')).length <= 2) {
      // «ابحثلي عن ناجي» → بحث عادي بالاسم، مو اختصاص.
      if (_looksLikePersonName(rest)) return null;
    }

    return VoiceSpecialtySearchCommand(
      specialtyQuery: rest,
      resolvedSpecialtyName: matched?.nameAr ?? rest,
      rawQuery: original,
    );
  }

  /// «طبيب/دكتور/أطباء + مصطلح اختصاص من الكتالوج» بكلمة كاملة.
  ///
  /// يغطي الصيغ الطبيعية («اريد طبيب كسور»، «طبيب مفاصل») بلا قاموس جديد:
  /// مصدر المصطلحات هو [SpecialtyCatalog] نفسه.
  static bool _hasCatalogSpecialtyAfterDoctorWord(String original) {
    final match = RegExp(
      r'(?:^|\s)(?:ال)?(?:طبيب|طبيبه|طبيبة|دكتور|دكتوره|دكتورة|أطباء|اطباء|دكاترة|دكاتره)\s+(.{2,})$',
      caseSensitive: false,
    ).firstMatch(original.trim());
    if (match == null) return false;

    final rest = (match.group(1) ?? '').trim();
    if (rest.isEmpty) return false;
    if (SpecialtyCatalog.isSpecialtyTerm(rest)) return true;
    for (final token in rest.split(RegExp(r'\s+'))) {
      if (SpecialtyCatalog.isSpecialtyTerm(token)) return true;
    }
    return false;
  }

  static bool _hasSearchVerb(String original) {
    final q = ArabicTextUtils.normalize(original);
    return q.contains('ابحث') ||
        RegExp(r'(^|\s)دور(لي|)\s').hasMatch(q) ||
        q.contains('طلّع') ||
        RegExp(r'(^|\s)طلع(لي|)\s').hasMatch(q) ||
        q.contains('وريني') ||
        q.contains('ورّيني') ||
        RegExp(r'(^|\s)اعرض\s').hasMatch(q);
  }

  static bool _looksLikePersonName(String rest) {
    final tokens = ArabicTextUtils.normalize(rest)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return true;
    if (tokens.length >= 4) return false;
    // إن لم يحتوِ كلمات اختصاص شائعة فهو غالبًا اسم.
    const specialtyHints = [
      'جملة',
      'عصب',
      'باطن',
      'اطفال',
      'أطفال',
      'عظام',
      'قلب',
      'نساء',
      'جلد',
      'اسنان',
      'أسنان',
      'هضم',
      'كلى',
      'صدر',
      'اختصاص',
      'تخصص',
    ];
    final joined = tokens.join(' ');
    for (final h in specialtyHints) {
      if (joined.contains(ArabicTextUtils.normalize(h))) return false;
    }
    return true;
  }
}
