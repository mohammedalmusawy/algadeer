import '../voice/guided_conversation/arabic_answer_normalizer.dart';
import '../health/subject/health_subject_detector.dart';
import '../health/subject/health_subject_models.dart';
import '../search/arabic_text_utils.dart';
import 'companion_onboarding_models.dart';
import 'personal_companion_profile.dart';

/// مفسّر إجابات onboarding — حتمي، بلا AI.
class CompanionOnboardingInterpreter {
  CompanionOnboardingInterpreter({
    HealthSubjectDetector? subjectDetector,
  }) : _subjects = subjectDetector ?? const HealthSubjectDetector();

  final HealthSubjectDetector _subjects;

  CompanionOnboardingInterpretation interpret({
    required String raw,
    required CompanionOnboardingStep step,
    required CompanionOnboardingState state,
  }) {
    final original = raw.trim();
    final n = ArabicTextUtils.normalize(original);
    if (n.isEmpty) {
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.invalid,
        message: 'ما سمعت جواب واضح. تكدر تعيد أو تقول تخطي.',
      );
    }

    // حماية PC-0.3: بيانات ابن/أم… ليست لصاحب الحساب.
    final subj = _subjects.detect(original);
    if (subj.type != HealthSubjectType.self &&
        subj.type != HealthSubjectType.unknown &&
        subj.evidence == HealthSubjectEvidence.explicitRelationship) {
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.topicChanged,
        message: '',
      );
    }

    if (_isWhy(n)) {
      return CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.whyQuestion,
        explanation: _whyFor(step),
      );
    }

    if (_isLater(n)) {
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.pause,
      );
    }

    if (_isSkip(n)) {
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.skip,
      );
    }

    if (step == CompanionOnboardingStep.offer) {
      // decline قبل yes — «لا اريد» يحتوي «اريد».
      if (_isDecline(n)) {
        return const CompanionOnboardingInterpretation(
          kind: CompanionOnboardingInterpretKind.declineOffer,
        );
      }
      if (_isLater(n) || n.contains('لاحقا') || n.contains('بعدين')) {
        return const CompanionOnboardingInterpretation(
          kind: CompanionOnboardingInterpretKind.laterOffer,
        );
      }
      if (_isYes(n)) {
        return const CompanionOnboardingInterpretation(
          kind: CompanionOnboardingInterpretKind.acceptOffer,
        );
      }
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.invalid,
        message: 'تكدر تقول نعم، لاحقاً، أو لا أريد.',
      );
    }

    // تأكيد سنة مشتقة من عمر
    if (state.awaitingAgeYearConfirm &&
        step == CompanionOnboardingStep.birthYear) {
      if (_isYes(n)) {
        return CompanionOnboardingInterpretation(
          kind: CompanionOnboardingInterpretKind.resolved,
          birthYear: state.proposedBirthYear,
        );
      }
      if (_isNo(n) || _isSkip(n)) {
        return const CompanionOnboardingInterpretation(
          kind: CompanionOnboardingInterpretKind.skip,
        );
      }
      final year = _parseYear(n);
      if (year != null) {
        return CompanionOnboardingInterpretation(
          kind: CompanionOnboardingInterpretKind.correction,
          birthYear: year,
        );
      }
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.invalid,
        message: 'تحب أأكد سنة الميلاد؟ قل نعم، أو اكتب السنة، أو تخطي.',
      );
    }

    switch (step) {
      case CompanionOnboardingStep.preferredName:
        return _interpretName(original, n);
      case CompanionOnboardingStep.birthYear:
        return _interpretBirth(n);
      case CompanionOnboardingStep.sexSelection:
        return _interpretSex(n);
      case CompanionOnboardingStep.userContext:
        return _interpretContext(n);
      case CompanionOnboardingStep.offer:
      case CompanionOnboardingStep.done:
        return const CompanionOnboardingInterpretation(
          kind: CompanionOnboardingInterpretKind.invalid,
        );
    }
  }

  CompanionOnboardingInterpretation _interpretName(String original, String n) {
    if (_isSkip(n) || _isLater(n) || _isDecline(n) || _isWhy(n)) {
      // already handled above
    }
    // رفض نص مسيء كاسم
    if (RegExp(r'(?:غبي|حمار|تافه|كلب|عرص|قذر)').hasMatch(n)) {
      // إن وُجد «اسمي X» نستخرج الاسم فقط
      final m = RegExp(r'(?:اسمي|نادني|ناديني)\s+(\S{2,40})').firstMatch(n);
      if (m != null) {
        final name = _cleanName(m.group(1)!);
        if (name != null) {
          return CompanionOnboardingInterpretation(
            kind: CompanionOnboardingInterpretKind.resolved,
            preferredName: name,
          );
        }
      }
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.invalid,
        message: 'ما أكدر أحفظ هاي كاسم. شنو تحب أناديك؟',
      );
    }
    final named = RegExp(r'(?:اسمي|نادني|ناديني)\s+(\S{2,40})').firstMatch(n);
    final candidate = named != null ? named.group(1)! : n;
    final name = _cleanName(candidate);
    if (name == null) {
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.invalid,
        message: 'ما فهمت الاسم. شنو تحب أناديك؟ أو قل تخطي.',
      );
    }
    return CompanionOnboardingInterpretation(
      kind: CompanionOnboardingInterpretKind.resolved,
      preferredName: name,
    );
  }

  CompanionOnboardingInterpretation _interpretBirth(String n) {
    // عمري 35 → لا نخزّن عمراً ثابتاً
    final ageM = RegExp(r'(?:عمري|العمر)\s*(\d{1,3})').firstMatch(n);
    if (ageM != null) {
      final age = int.tryParse(ageM.group(1)!);
      if (age == null || age < 5 || age > 120) {
        return const CompanionOnboardingInterpretation(
          kind: CompanionOnboardingInterpretKind.invalid,
          message: 'العمر غير واضح. تكدر تعطي سنة الميلاد؟',
        );
      }
      final year = DateTime.now().year - age;
      return CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.ageNeedsConfirm,
        proposedBirthYear: year,
        message:
            'تحب أخلي سنة الميلاد $year بدل العمر حتى يبقى العمر يتحدث تلقائياً؟',
      );
    }

    final year = _parseYear(n);
    if (year != null) {
      final kind = ArabicAnswerNormalizer.looksLikeCorrection(n)
          ? CompanionOnboardingInterpretKind.correction
          : CompanionOnboardingInterpretKind.resolved;
      return CompanionOnboardingInterpretation(kind: kind, birthYear: year);
    }

    final full = _parseFullDate(n);
    if (full != null) {
      return CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.resolved,
        birthDate: full,
        birthYear: full.year,
      );
    }

    return const CompanionOnboardingInterpretation(
      kind: CompanionOnboardingInterpretKind.invalid,
      message: 'ما فهمت السنة. مثال: 1990 أو مواليد 1990، أو تخطي.',
    );
  }

  CompanionOnboardingInterpretation _interpretSex(String n) {
    if (RegExp(r'(?:ذكر|رجل|ولد)').hasMatch(n) &&
        !RegExp(r'عدم').hasMatch(n)) {
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.resolved,
        sexSelectionName: 'male',
      );
    }
    // بعد التطبيع: أنثى → انثي
    if (RegExp(r'(?:انثي|انثى|أنثى|بنت|امراه|امرأة|امراة)').hasMatch(n)) {
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.resolved,
        sexSelectionName: 'female',
      );
    }
    if (RegExp(r'(?:افضل عدم|عدم التحديد|ما احب احدد|ما احدد)').hasMatch(n)) {
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.resolved,
        sexSelectionName: 'preferNotToSpecify',
      );
    }
    return const CompanionOnboardingInterpretation(
      kind: CompanionOnboardingInterpretKind.invalid,
      message: 'اختَر: ذكر، أنثى، أو أفضل عدم التحديد. أو تخطي.',
    );
  }

  CompanionOnboardingInterpretation _interpretContext(String n) {
    String? map;
    if (RegExp(r'(?:طالب|طالبه|طالبة|دراس)').hasMatch(n)) {
      map = ProfileUserContext.student.name;
    } else if (RegExp(r'(?:عمل حر|اعمال حره|ذاتي|فريلانس)').hasMatch(n)) {
      map = ProfileUserContext.selfEmployed.name;
    } else if (RegExp(r'(?:موظف|موظفه|موظفة|وظيفة|وظيفه)').hasMatch(n)) {
      map = ProfileUserContext.employee.name;
    } else if (RegExp(r'(?:افضل عدم|عدم التحديد)').hasMatch(n)) {
      map = ProfileUserContext.preferNotToSpecify.name;
    } else if (RegExp(r'(?:اخري|اخرى|أخرى|غير|شي ثاني)').hasMatch(n)) {
      map = ProfileUserContext.other.name;
    }
    if (map == null) {
      return const CompanionOnboardingInterpretation(
        kind: CompanionOnboardingInterpretKind.invalid,
        message:
            'اختَر: طالب، موظف، عمل حر، أخرى، أو أفضل عدم التحديد. أو تخطي.',
      );
    }
    final kind = ArabicAnswerNormalizer.looksLikeCorrection(n)
        ? CompanionOnboardingInterpretKind.correction
        : CompanionOnboardingInterpretKind.resolved;
    return CompanionOnboardingInterpretation(
      kind: kind,
      userContextName: map,
    );
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
    // أول كلمة معقولة
    final parts = s.split(RegExp(r'\s+'));
    return parts.first;
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

  bool _isWhy(String n) =>
      RegExp(r'(?:ليش|لماذا|لش|\?)\s*(?:تسال|تسأل|السؤال)?').hasMatch(n) ||
      n == 'ليش' ||
      n.contains('ليش تسأل') ||
      n.contains('ليش تسال');

  bool _isSkip(String n) => RegExp(
        r'(?:^|\s)(?:تخطي|تخطى|ما اريد اجاوب|ما اريد أجاوب|مو هسه|مو هسة)(?:\s|$)',
      ).hasMatch(n);

  bool _isLater(String n) =>
      RegExp(r'(?:بعدين|لاحقا|مو هسه|مو هسة|مو الحين)').hasMatch(n);

  bool _isDecline(String n) => RegExp(
        r'(?:لا\s*اريد|ما\s*اريد|لا\s*شكرا|مو\s*لازم|^لا$)',
      ).hasMatch(n);

  bool _isYes(String n) =>
      RegExp(r'(?:^|\s)(?:اي|إي|نعم|هيه|زين|موافق)(?:\s|$)').hasMatch(n) ||
      n == 'اي' ||
      n == 'نعم';

  bool _isNo(String n) =>
      RegExp(r'(?:^|\s)(?:لا|كلا|مو)(?:\s|$)').hasMatch(n);

  String _whyFor(CompanionOnboardingStep step) {
    switch (step) {
      case CompanionOnboardingStep.offer:
        return 'حتى أخلي الغدير أنسب إلك تدريجياً، وبإمكانك التخطي بأي وقت.';
      case CompanionOnboardingStep.preferredName:
        return 'حتى أناديك بالاسم اللي تفضّله.';
      case CompanionOnboardingStep.birthYear:
        return 'حتى أحسب العمر بشكل صحيح إذا احتجناه بالتخصيص.';
      case CompanionOnboardingStep.sexSelection:
        return 'حتى تكون صيغة الكلام والتخصيص أنسب إلك، وتكدر تختار عدم التحديد.';
      case CompanionOnboardingStep.userContext:
        return 'حتى أخلي الاقتراحات والمساعدة أقرب لاحتياجاتك.';
      case CompanionOnboardingStep.done:
        return '';
    }
  }
}
