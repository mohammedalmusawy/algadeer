import '../health/subject/health_subject_detector.dart';
import '../health/subject/health_subject_models.dart';
import '../search/arabic_text_utils.dart';
import '../voice/guided_conversation/arabic_answer_normalizer.dart';
import 'companion_profile_command_models.dart';
import 'personal_companion_profile.dart';
import 'personal_companion_profile_repository.dart';

/// مفسّر أوامر ملف صاحب الحساب — حتمي، بلا AI.
class CompanionProfileCommandInterpreter {
  CompanionProfileCommandInterpreter({
    HealthSubjectDetector? subjectDetector,
  }) : _subjects = subjectDetector ?? const HealthSubjectDetector();

  final HealthSubjectDetector _subjects;

  CompanionProfileCommandInterpretation interpret({
    required String raw,
    required CompanionProfilePendingOp pending,
    bool doctorEntityActive = false,
  }) {
    final original = raw.trim();
    final n = ArabicTextUtils.normalize(original);
    if (n.isEmpty) return CompanionProfileCommandInterpretation.none;

    // تأكيد/إلغاء عملية معلّقة
    if (pending.kind == CompanionProfilePendingKind.deleteWholeProfile) {
      if (_isYes(n)) {
        return const CompanionProfileCommandInterpretation(
          kind: CompanionProfileCommandKind.deleteProfileRequest,
          message: 'confirm_delete',
        );
      }
      if (_isNo(n) || _isCancel(n)) {
        return const CompanionProfileCommandInterpretation(
          kind: CompanionProfileCommandKind.cancelProfileOperation,
        );
      }
    }

    // حماية المالك: ابن/أم/زوجة ليست لصاحب الحساب
    final subj = _subjects.detect(original);
    if (subj.type != HealthSubjectType.self &&
        subj.type != HealthSubjectType.unknown &&
        subj.evidence == HealthSubjectEvidence.explicitRelationship) {
      if (_looksLikeProfileMutation(n) || _looksLikeShow(n)) {
        return const CompanionProfileCommandInterpretation(
          kind: CompanionProfileCommandKind.rejectNonOwner,
          message:
              'هاي المعلومة تخص شخص ثاني، مو ملفك الشخصي. ما أعدّل ملف صاحب الحساب منها.',
        );
      }
    }

    // نسيان عرضي لجلسة صحية — ليس ذاكرة دائمة
    if (_looksLikeForgetSessionHealth(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.notPersistentMemory,
        message:
            'ما عندي ذاكرة صحية دائمة عن هاي الشكوى. إذا كانت بس بهالجلسة، ما محفوظة بملفك الأساسي.',
      );
    }

    // حذف غامض
    if (RegExp(r'^(?:احذف|امسح)\s*(?:هذا|هذ|هاي|هذي)$').hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.clarifyAmbiguous,
        message:
            'شنو تقصد بالضبط؟ إذا تريد حذف الملف الشخصي كله، قل: احذف ملفي الشخصي كله.',
        confidenceHigh: false,
      );
    }

    // حذف الملف كاملاً
    if (RegExp(
      r'(?:احذف|امسح)\s*(?:ملفي\s*الشخصي|الملف\s*الشخصي)\s*(?:كله|كاملا|كامل)?|'
      r'(?:احذف|امسح)\s*كل\s*(?:ملفي|معلوماتي\s*الاساسيه|معلوماتي\s*الأساسية)',
    ).hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.deleteProfileRequest,
        message: 'request_delete',
      );
    }

    // «لا تستخدم جنسي بالتخصيص» ≠ تعطيل الملف كله
    if (RegExp(r'لا\s*تستخدم\s*جنسي').hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.updateSexSelection,
        field: CompanionProfileFieldKind.sexSelection,
        sexSelectionName: 'preferNotToSpecify',
      );
    }

    // تعطيل / تفعيل
    if (RegExp(
      r'(?:عطل\s*(?:التخصيص|الملف|ملفي)|لا\s*تستخدم\s*ملفي(?:\s*حاليا)?)',
    ).hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.disableProfile,
      );
    }
    if (RegExp(r'(?:فعل\s*ملفي|رجع\s*التخصيص|فعل\s*التخصيص|فعل\s*الملف)')
        .hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.enableProfile,
      );
    }

    // عرض الملف
    if (_looksLikeShow(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.showProfile,
      );
    }

    // حقل محدد
    final specific = _interpretSpecificFieldQuery(n);
    if (specific != null) return specific;

    // مسح حقل / انسَ حقل ملف
    final clear = _interpretClear(n);
    if (clear != null) return clear;

    // غموض مع كيان طبيب نشط
    if (doctorEntityActive &&
        RegExp(r'غير\s*(?:ال)?اسم(?:\s*الى|\s*إلى)?').hasMatch(n) &&
        !RegExp(r'اسمي|ناديني').hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.clarifyAmbiguous,
        message:
            'تقصد اسمك المفضل بملفك، لو اسم الطبيب بالنتائج؟ وضّح لو سمحت.',
        confidenceHigh: false,
      );
    }

    // تحديثات
    final update = _interpretUpdate(original, n);
    if (update != null) return update;

    // تصحيحات قصيرة إن كانت تشبه أوامر ملف
    if (ArabicAnswerNormalizer.looksLikeCorrection(n) &&
        (_parseYear(n) != null || _parseContext(n) != null)) {
      final year = _parseYear(n);
      if (year != null) {
        return CompanionProfileCommandInterpretation(
          kind: CompanionProfileCommandKind.updateBirth,
          field: CompanionProfileFieldKind.birth,
          birthYear: year,
        );
      }
      final ctx = _parseContext(n);
      if (ctx != null) {
        return CompanionProfileCommandInterpretation(
          kind: CompanionProfileCommandKind.updateUserContext,
          field: CompanionProfileFieldKind.userContext,
          userContextName: ctx,
        );
      }
    }

    return CompanionProfileCommandInterpretation.none;
  }

  bool looksLikeProfileCommand(String raw) {
    final r = interpret(
      raw: raw,
      pending: CompanionProfilePendingOp.none,
    );
    return r.isProfileCommand;
  }

  CompanionProfileCommandInterpretation? _interpretSpecificFieldQuery(String n) {
    if (RegExp(r'(?:شنو|ماذا|ايش)\s*اسمي(?:\s*عندك)?|اسمي\s*عندك')
        .hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.showSpecificField,
        field: CompanionProfileFieldKind.preferredName,
      );
    }
    if (RegExp(r'(?:كم\s*عمري(?:\s*عندك)?|شنو\s*عمري(?:\s*عندك)?)')
        .hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.showSpecificField,
        field: CompanionProfileFieldKind.age,
      );
    }
    if (RegExp(r'(?:شنو|ماذا)\s*(?:سنه|سنة)\s*ميلادي').hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.showSpecificField,
        field: CompanionProfileFieldKind.birth,
      );
    }
    if (RegExp(r'(?:شنو|ماذا)\s*مسجل\s*شغلي|شغلي\s*عندك').hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.showSpecificField,
        field: CompanionProfileFieldKind.userContext,
      );
    }
    if (RegExp(r'(?:شنو|ماذا)\s*مسجل\s*جنسي|جنسي\s*عندك').hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.showSpecificField,
        field: CompanionProfileFieldKind.sexSelection,
      );
    }
    return null;
  }

  CompanionProfileCommandInterpretation? _interpretClear(String n) {
    if (RegExp(
      r'(?:امسح|احذف|انس[ىي]?)\s*(?:اسمي\s*المفضل|اسمي)|'
      r'لا\s*تحتفط\s*باسمي|لا\s*تحتفظ\s*باسمي',
    ).hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.clearField,
        clearField: ProfileOptionalField.preferredName,
        field: CompanionProfileFieldKind.preferredName,
      );
    }
    if (RegExp(
      r'(?:امسح|احذف|انس[ىي]?)\s*(?:سنه|سنة)\s*ميلادي|'
      r'(?:امسح|احذف)\s*تاريخ\s*ميلادي',
    ).hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.clearField,
        clearField: ProfileOptionalField.birthYear,
        field: CompanionProfileFieldKind.birth,
      );
    }
    if (RegExp(
      r'(?:امسح|احذف|انس[ىي]?)\s*(?:اختيار\s*الجنس|جنسي)|'
      r'لا\s*تحتفظ\s*ب(?:اختيار\s*)?الجنس',
    ).hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.clearField,
        clearField: ProfileOptionalField.sexSelection,
        field: CompanionProfileFieldKind.sexSelection,
      );
    }
    if (RegExp(
      r'(?:امسح|احذف|انس[ىي]?)\s*(?:شغلي|سياق\s*عملي)|'
      r'لا\s*تحتفظ\s*بسياق\s*عملي',
    ).hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.clearField,
        clearField: ProfileOptionalField.userContext,
        field: CompanionProfileFieldKind.userContext,
      );
    }
    return null;
  }

  CompanionProfileCommandInterpretation? _interpretUpdate(
    String original,
    String n,
  ) {
    // بعد التطبيع: إلى → الي
    final nameM = RegExp(
      r'(?:غير\s*اسمي\s*(?:الي|الى|إلى|ل)?\s+(\S{2,40})|'
      r'ناديني\s+(\S{2,40})|'
      r'من\s*هسه\s*ناديني\s+(\S{2,40})|'
      r'اسمي\s*المفضل\s+(\S{2,40}))',
    ).firstMatch(n);
    if (nameM != null) {
      final rawName =
          nameM.group(1) ?? nameM.group(2) ?? nameM.group(3) ?? nameM.group(4)!;
      final name = _cleanName(rawName);
      if (name != null) {
        return CompanionProfileCommandInterpretation(
          kind: CompanionProfileCommandKind.updatePreferredName,
          field: CompanionProfileFieldKind.preferredName,
          preferredName: name,
        );
      }
    }

    // جنس — صريح فقط
    if (RegExp(r'سجلني\s*ذكر').hasMatch(n) ||
        RegExp(r'غير\s*اختيار\s*الجنس\s*(?:الى|إلى)\s*ذكر').hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.updateSexSelection,
        field: CompanionProfileFieldKind.sexSelection,
        sexSelectionName: 'male',
      );
    }
    if (RegExp(r'سجلني\s*(?:انثي|انثى|أنثى)').hasMatch(n) ||
        RegExp(r'غير\s*اختيار\s*الجنس\s*(?:الى|إلى)\s*(?:انثي|انثى)')
            .hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.updateSexSelection,
        field: CompanionProfileFieldKind.sexSelection,
        sexSelectionName: 'female',
      );
    }
    if (RegExp(
      r'(?:افضل\s*عدم\s*تحديد\s*الجنس|عدم\s*تحديد\s*الجنس|'
      r'غير\s*اختيار\s*الجنس\s*(?:الى|إلى)\s*(?:عدم\s*التحديد|افضل\s*عدم))',
    ).hasMatch(n)) {
      return const CompanionProfileCommandInterpretation(
        kind: CompanionProfileCommandKind.updateSexSelection,
        field: CompanionProfileFieldKind.sexSelection,
        sexSelectionName: 'preferNotToSpecify',
      );
    }

    // ميلاد
    if (RegExp(
      r'(?:غير|صحح)\s*(?:سنه|سنة)?\s*ميلاد(?:ي)?|'
      r'انا\s*مواليد|مواليد\s*\d',
    ).hasMatch(n)) {
      final full = _parseFullDate(n);
      if (full != null) {
        return CompanionProfileCommandInterpretation(
          kind: CompanionProfileCommandKind.updateBirth,
          field: CompanionProfileFieldKind.birth,
          birthDate: full,
          birthYear: full.year,
        );
      }
      final year = _parseYear(n);
      if (year != null) {
        return CompanionProfileCommandInterpretation(
          kind: CompanionProfileCommandKind.updateBirth,
          field: CompanionProfileFieldKind.birth,
          birthYear: year,
        );
      }
      // سنة غير صالحة ظاهرة
      if (RegExp(r'\d{4}').hasMatch(n)) {
        return const CompanionProfileCommandInterpretation(
          kind: CompanionProfileCommandKind.updateBirth,
          field: CompanionProfileFieldKind.birth,
          message: 'invalid_birth',
          confidenceHigh: false,
        );
      }
    }

    // سياق عمل
    if (RegExp(
      r'(?:صرت|انا\s*(?:مو\s*)?(?:موظف|طالب|عمل)|غير\s*شغلي|'
      r'مو\s*موظف|هسه\s*(?:عمل|موظف|طالب))',
    ).hasMatch(n)) {
      final ctx = _parseContext(n);
      if (ctx != null) {
        return CompanionProfileCommandInterpretation(
          kind: CompanionProfileCommandKind.updateUserContext,
          field: CompanionProfileFieldKind.userContext,
          userContextName: ctx,
        );
      }
    }

    return null;
  }

  bool _looksLikeShow(String n) => RegExp(
        r'(?:شنو|ماذا|ايش|وش)\s*(?:تعرف|حافظ)\s*(?:عني|علي)|'
        r'شنو\s*معلوماتي|'
        r'عرفني\s*شنو\s*تعرف\s*عني|'
        r'وش\s*تعرف\s*عني',
      ).hasMatch(n);

  bool _looksLikeProfileMutation(String n) => RegExp(
        r'(?:غير|امسح|احذف|سجل|مواليد|صرت|ناديني|عمر)',
      ).hasMatch(n);

  bool _looksLikeForgetSessionHealth(String n) => RegExp(
        r'انس[ىي]?\s*(?:اللي\s*)?(?:حكيتلك|قلتللك|قلت\s*لك)?\s*(?:عن\s*)?'
        r'(?:صداع|الالم|الألم|الاعراض|الأعراض|الشكوى|ضي[قغ]\s*نفس)',
      ).hasMatch(n);

  String? _parseContext(String n) {
    // استبدال: مو موظف → عمل حر له الأولوية إن وُجد
    if (RegExp(r'(?:عمل\s*حر|اعمال\s*حره|ذاتي|فريلانس)').hasMatch(n)) {
      return ProfileUserContext.selfEmployed.name;
    }
    if (RegExp(r'(?:طالب|طالبه|طالبة|دراس)').hasMatch(n)) {
      return ProfileUserContext.student.name;
    }
    if (RegExp(r'(?:موظف|موظفه|موظفة)').hasMatch(n) &&
        !RegExp(r'(?:مو\s*موظف|لست\s*موظف)').hasMatch(n)) {
      return ProfileUserContext.employee.name;
    }
    if (RegExp(r'(?:اخري|اخرى|أخرى)').hasMatch(n)) {
      return ProfileUserContext.other.name;
    }
    if (RegExp(r'(?:افضل\s*عدم|عدم\s*التحديد)').hasMatch(n)) {
      return ProfileUserContext.preferNotToSpecify.name;
    }
    return null;
  }

  String? _cleanName(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'[^\u0600-\u06FFa-zA-Z\s]'), '').trim();
    if (s.length < 2 || s.length > 40) return null;
    if (RegExp(r'^(?:تخطي|بعدين|لاحقا|لا|نعم|ما اريد)$').hasMatch(
      ArabicTextUtils.normalize(s),
    )) {
      return null;
    }
    return s.split(RegExp(r'\s+')).first;
  }

  int? _parseYear(String n) {
    final mawalid = RegExp(r'مواليد\s*(\d{4})').firstMatch(n);
    if (mawalid != null) {
      return _validateYear(int.tryParse(mawalid.group(1)!));
    }
    final bare = RegExp(r'(?:^|\s)(\d{4})(?:\s|$)').firstMatch(n);
    if (bare != null) {
      return _validateYear(int.tryParse(bare.group(1)!));
    }
    // «إلى» بعد التطبيع → «الي»
    final to = RegExp(r'(?:الي|الى|إلى)\s*(\d{4})').firstMatch(n);
    if (to != null) {
      return _validateYear(int.tryParse(to.group(1)!));
    }
    return null;
  }

  DateTime? _parseFullDate(String n) {
    final m = RegExp(r'(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})').firstMatch(n);
    if (m == null) return null;
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    if (_validateYear(y) == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, mo, d);
    if (dt.isAfter(DateTime.now())) return null;
    return dt;
  }

  int? _validateYear(int? y) {
    if (y == null) return null;
    final now = DateTime.now().year;
    if (y > now || y < now - 130) return null;
    return y;
  }

  bool _isYes(String n) =>
      RegExp(r'(?:^|\s)(?:اي|نعم|هيه|زين|موافق)(?:\s|$)').hasMatch(n) ||
      n == 'اي' ||
      n == 'نعم';

  bool _isNo(String n) =>
      RegExp(r'(?:^|\s)(?:لا|كلا|مو|لا\s*اريد)(?:\s|$)').hasMatch(n) ||
      n == 'لا';

  bool _isCancel(String n) =>
      RegExp(r'(?:الغي|ألغي|تراجع|بطل)').hasMatch(n);
}
