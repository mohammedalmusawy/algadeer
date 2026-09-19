import '../../search/arabic_text_utils.dart';
import '../../voice/guided_conversation/arabic_answer_normalizer.dart';
import 'family_person_profile.dart';
import 'family_profile_command_models.dart';

/// مفسّر أوامر ملفات الأشخاص — إنشاء صريح فقط.
class FamilyProfileCommandInterpreter {
  const FamilyProfileCommandInterpreter();

  bool looksLikeFamilyProfileCommand(String raw) {
    return interpret(raw: raw, pending: FamilyProfilePendingOp.none).isCommand;
  }

  /// جلسة صحية مؤقتة — لا إنشاء ملف.
  bool isTemporaryHealthOnly(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    final hasHealth =
        RegExp(r'(?:حراره|حرارة|حمى|الم|ألم|سكر|ضغط|سعال|حراره)').hasMatch(n);
    final hasExplicitRemember =
        RegExp(r'(?:تذكر|احفظ)\s*(?:ابني|ابنتي|امي|زوج)').hasMatch(n);
    return hasHealth && !hasExplicitRemember;
  }

  FamilyProfileCommandInterpretation interpret({
    required String raw,
    required FamilyProfilePendingOp pending,
  }) {
    final original = raw.trim();
    final n = ArabicTextUtils.normalize(original);
    if (n.isEmpty) return FamilyProfileCommandInterpretation.none;

    if (pending.kind == FamilyProfilePendingKind.deletePerson) {
      if (_isYes(n)) {
        return const FamilyProfileCommandInterpretation(
          kind: FamilyProfileCommandKind.confirmDelete,
        );
      }
      if (_isNo(n) || _isCancel(n)) {
        return const FamilyProfileCommandInterpretation(
          kind: FamilyProfileCommandKind.cancelOperation,
        );
      }
    }

    if (isTemporaryHealthOnly(original)) {
      return const FamilyProfileCommandInterpretation(
        kind: FamilyProfileCommandKind.rejectHealthOnly,
      );
    }

    // عرض الكل
    if (RegExp(
      r'(?:منو\s*متذكر\s*من\s*عا?يلتي|شنو\s*الاشخاص\s*اللي\s*حافظهم|'
      r'شنو\s*الأشخاص\s*اللي\s*حافظهم)',
    ).hasMatch(n)) {
      return const FamilyProfileCommandInterpretation(
        kind: FamilyProfileCommandKind.showAllPeople,
      );
    }

    // عرض شخص
    if (RegExp(
      r'(?:شنو\s*تعرف\s*عن\s*(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي)|'
      r'شنو\s*تعرف\s*عن)',
    ).hasMatch(n)) {
      return FamilyProfileCommandInterpretation(
        kind: FamilyProfileCommandKind.showPerson,
        relationship: _parseRelationship(n),
        targetName: _extractName(n),
      );
    }

    // حذف
    if (RegExp(
      r'(?:امسح|احذف|لا\s*تتذكر)\s*(?:ملف\s*)?(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي|)',
    ).hasMatch(n) &&
        RegExp(r'(?:امسح|احذف|لا\s*تتذكر)').hasMatch(n)) {
      return FamilyProfileCommandInterpretation(
        kind: FamilyProfileCommandKind.deletePersonRequest,
        relationship: _parseRelationship(n),
        targetName: _extractName(n),
      );
    }

    // تعطيل
    if (RegExp(r'(?:عطل|وقف)\s*(?:ملف|تذكر)').hasMatch(n)) {
      return FamilyProfileCommandInterpretation(
        kind: FamilyProfileCommandKind.disablePerson,
        relationship: _parseRelationship(n),
        targetName: _extractName(n),
      );
    }

    // تعديل اسم
    final rename = RegExp(
      r'(?:غير|بدّل|بدل|صحح)\s*اسم\s*(?:ابني|ابنتي|امي|ابوي|زوجتي)\s+(\S+)\s*(?:إلى|الى|الا|الي|to)\s*(\S+)',
    ).firstMatch(n);
    if (rename != null) {
      return FamilyProfileCommandInterpretation(
        kind: FamilyProfileCommandKind.updateName,
        relationship: _parseRelationship(n),
        targetName: rename.group(1),
        newName: rename.group(2),
      );
    }

    // مواليد
    final birthFix = RegExp(
      r'(?:صحح|غير|بدّل)\s*مواليد\s*(?:ابني|ابنتي)?\s*(?:\S+\s*)?(?:إلى|الى|الا|الي)\s*(\d{4})',
    ).firstMatch(n);
    if (birthFix != null) {
      return FamilyProfileCommandInterpretation(
        kind: FamilyProfileCommandKind.updateBirthYear,
        relationship: _parseRelationship(n),
        targetName: _extractName(n),
        birthYear: int.tryParse(birthFix.group(1) ?? ''),
      );
    }

    // إنشاء صريح
    if (RegExp(
      r'(?:تذكر|احفظ|سجل)\s*(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي|اسم)',
    ).hasMatch(n)) {
      final rel = _parseRelationship(n);
      final name = _extractName(n);
      final year = _extractBirthYear(n);
      if (RegExp(r'(?:عمره|عمرها)\s*\d').hasMatch(n) && year == null) {
        return const FamilyProfileCommandInterpretation(
          kind: FamilyProfileCommandKind.progressiveAskBirthYear,
          message:
              'ما أخزّن العمر رقم ثابت. إذا تحب، قل سنة ميلاده مثل: مواليد 2018.',
        );
      }
      return FamilyProfileCommandInterpretation(
        kind: FamilyProfileCommandKind.rememberPerson,
        relationship: rel ?? PersonRelationship.child,
        preferredName: name.isEmpty ? null : name,
        birthYear: year,
      );
    }

    // اسم صريح — لا يلتقط أوامر التعديل (غير/صحح)
    if (!RegExp(r'(?:غير|بدّل|بدل|صحح)').hasMatch(n) &&
        RegExp(r'(?:اسم\s*ابني|اسم\s*امي|اسم\s*زوجتي)').hasMatch(n)) {
      final name = _extractNameAfterLabel(n);
      return FamilyProfileCommandInterpretation(
        kind: FamilyProfileCommandKind.rememberPerson,
        relationship: _parseRelationship(n),
        preferredName: name,
      );
    }

    return FamilyProfileCommandInterpretation.none;
  }

  PersonRelationship? _parseRelationship(String n) {
    if (RegExp(r'(?:ابني|ولدي)').hasMatch(n)) return PersonRelationship.son;
    if (RegExp(r'(?:بنتي|بنيتي)').hasMatch(n)) return PersonRelationship.daughter;
    if (RegExp(r'(?:ابني|ابنتي|طفلي|ولدي)').hasMatch(n)) {
      return PersonRelationship.child;
    }
    if (RegExp(r'(?:امي|أمي)').hasMatch(n)) return PersonRelationship.mother;
    if (RegExp(r'(?:ابوي|ابي|أبي)').hasMatch(n)) return PersonRelationship.father;
    if (RegExp(r'(?:زوجتي|مراتي)').hasMatch(n)) return PersonRelationship.wife;
    if (RegExp(r'(?:زوجي)').hasMatch(n)) return PersonRelationship.husband;
    return null;
  }

  String _extractName(String n) {
    final m = RegExp(
      r'(?:تذكر|احفظ|اسم|عن|ملف)\s*(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي)?\s*([a-zA-Z\u0600-\u06FF]{2,})',
    ).firstMatch(n);
    var name = m?.group(1)?.trim() ?? '';
    if (_isStopWord(name)) name = '';
    return name;
  }

  String _extractNameAfterLabel(String n) {
    final m = RegExp(
      r'(?:اسم\s*(?:ابني|ابنتي|امي|زوجتي))\s*(?:هو|هي)?\s*([a-zA-Z\u0600-\u06FF]{2,})',
    ).firstMatch(n);
    return m?.group(1)?.trim() ?? '';
  }

  int? _extractBirthYear(String n) {
    final m = RegExp(r'(?:مواليد|سنه\s*ميلاد|سنة\s*ميلاد)\s*(\d{4})').firstMatch(n);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }

  bool _isStopWord(String w) {
    return RegExp(
      r'^(?:ابني|ابنتي|امي|ابوي|زوجتي|عمره|عمرها|مواليد|سنوات|سنه)$',
    ).hasMatch(w);
  }

  bool _isYes(String n) => ArabicAnswerNormalizer.isBareYes(n);
  bool _isNo(String n) => ArabicAnswerNormalizer.isBareNo(n);
  bool _isCancel(String n) =>
      RegExp(r'(?:الغ|إلغ|الغاء|cancel)').hasMatch(n);
}
