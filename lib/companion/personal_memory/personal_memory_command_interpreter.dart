import '../../search/arabic_text_utils.dart';
import 'personal_memory_command_models.dart';
import 'personal_memory_models.dart';
import 'personal_memory_qualifier.dart';

/// مفسّر أوامر الذاكرة الشخصية — حتمي.
class PersonalMemoryCommandInterpreter {
  PersonalMemoryCommandInterpreter({
    PersonalMemoryQualifier? qualifier,
  }) : _qualifier = qualifier ?? const PersonalMemoryQualifier();

  final PersonalMemoryQualifier _qualifier;

  PersonalMemoryCommandInterpretation interpret({
    required String raw,
    required PersonalMemoryPendingOp pending,
  }) {
    final original = raw.trim();
    final n = ArabicTextUtils.normalize(original);
    if (n.isEmpty) return PersonalMemoryCommandInterpretation.none;

    if (pending.kind == PersonalMemoryPendingKind.rememberConfirm ||
        pending.consent.isActive) {
      if (_isYes(n)) {
        return PersonalMemoryCommandInterpretation(
          kind: PersonalMemoryCommandKind.consentYes,
          candidate: pending.consent.candidate,
        );
      }
      if (_isNo(n)) {
        return const PersonalMemoryCommandInterpretation(
          kind: PersonalMemoryCommandKind.consentNo,
        );
      }
      final corr = _parseCorrection(n);
      if (corr != null) return corr;
    }

    if (pending.kind == PersonalMemoryPendingKind.bulkDelete) {
      if (_isYes(n)) {
        return PersonalMemoryCommandInterpretation(
          kind: PersonalMemoryCommandKind.confirmBulkDelete,
          bulkType: pending.bulkType,
        );
      }
      if (_isNo(n)) {
        return const PersonalMemoryCommandInterpretation(
          kind: PersonalMemoryCommandKind.cancelBulkDelete,
        );
      }
    }

    if (!_qualifier.isOwnerOnlyStatement(original)) {
      if (_looksLikeMemorySurface(n)) {
        return const PersonalMemoryCommandInterpretation(
          kind: PersonalMemoryCommandKind.rejectNonOwner,
          message:
              'هاي المعلومة تخص شخص ثاني. ما أحفظها بذاكرتك الشخصية.',
        );
      }
    }

    if (_qualifier.looksLikeEmotionalState(original) &&
        _looksLikeMemorySurface(n)) {
      return const PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.rejectEmotional,
        message: 'ما أحفظ المزاج أو التوتر كاهتمام أو تفضيل دائم.',
      );
    }

    if (_qualifier.looksLikePersonalityLabel(original)) {
      return const PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.rejectPersonality,
        message: 'ما أسوي تصنيف شخصية. أكدر أساعدك بالموضوع بدون هالتسميات.',
      );
    }

    if (_qualifier.looksLikeSensitiveHealthFact(original) &&
        _qualifier.hasExplicitRememberIntent(original)) {
      return const PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.rejectSensitiveHealth,
        message:
            'المعلومات الصحية الحسّاسة لها مسار خاص بموافقة منفصلة، مو ذاكرة أهداف/اهتمامات عادية.',
      );
    }

    if (_looksLikeShowAboutMe(n)) {
      return const PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.showAboutMeBroad,
      );
    }
    if (_looksLikeShowGoals(n)) {
      return const PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.showGoals,
      );
    }
    if (_looksLikeShowInterests(n)) {
      return const PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.showInterests,
      );
    }
    if (_looksLikeShowPreferences(n)) {
      return const PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.showPreferences,
      );
    }
    if (_looksLikeShowMemorySummary(n)) {
      return const PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.showPersonalMemorySummary,
      );
    }

    if (_looksLikeBulkDelete(n)) {
      final t = _bulkType(n);
      return PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.deleteAllOfTypeRequest,
        bulkType: t,
      );
    }

    if (_looksLikeComplete(n)) {
      return PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.completeGoal,
        needle: _needleGoal(n),
      );
    }
    if (_looksLikePause(n)) {
      return PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.pauseGoal,
        needle: _needleGoal(n),
      );
    }
    if (_looksLikeResume(n)) {
      return PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.resumeGoal,
        needle: _needleGoal(n),
      );
    }

    if (_looksLikeDeleteOne(n)) {
      return PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.deleteOne,
        needle: _needleDelete(n),
      );
    }

    final correction = _parseCorrection(n);
    if (correction != null) {
      return PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.rememberCandidate,
        candidate: correction.candidate,
      );
    }

    if (_qualifier.hasExplicitRememberIntent(original)) {
      final cand = _qualifier.extractExplicitCandidate(original);
      if (cand == null) {
        if (_qualifier.isImplicitOnly(original)) {
          return const PersonalMemoryCommandInterpretation(
            kind: PersonalMemoryCommandKind.rejectImplicit,
            message: 'فهمت للفترة الحالية، بس ما أحفظها دائمة بدون طلب أوضح.',
          );
        }
        return const PersonalMemoryCommandInterpretation(
          kind: PersonalMemoryCommandKind.rejectImplicit,
          message: 'ما قدرت أحدد شيء واضح للحفظ بذاكرتك الشخصية.',
        );
      }
      return PersonalMemoryCommandInterpretation(
        kind: PersonalMemoryCommandKind.rememberCandidate,
        candidate: cand,
      );
    }

    // ضمني بدون تذكر → لا أمر
    if (_qualifier.isImplicitOnly(original)) {
      return PersonalMemoryCommandInterpretation.none;
    }

    return PersonalMemoryCommandInterpretation.none;
  }

  bool looksLikePersonalMemoryCommand(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return false;
    return _looksLikeShowAboutMe(n) ||
        _looksLikeShowGoals(n) ||
        _looksLikeShowInterests(n) ||
        _looksLikeShowPreferences(n) ||
        _looksLikeShowMemorySummary(n) ||
        _looksLikeBulkDelete(n) ||
        _looksLikeDeleteOne(n) ||
        _looksLikeComplete(n) ||
        _looksLikePause(n) ||
        _looksLikeResume(n) ||
        _qualifier.hasExplicitRememberIntent(raw);
  }

  bool _looksLikeMemorySurface(String n) => RegExp(
        r'(?:تذكر|احفظ|هدف|اهتمام|افضل|أفضل|احب|أحب|اتعلم|أتعلم)',
      ).hasMatch(n);

  bool _looksLikeShowAboutMe(String n) => RegExp(
        r'(?:شنو|ماذا|ايش|وش)\s*(?:تعرف|حافظ)\s*(?:عني|علي)|'
        r'عرفني\s*شنو\s*تعرف\s*عني',
      ).hasMatch(n);

  bool _looksLikeShowGoals(String n) =>
      RegExp(r'(?:شنو|ماذا)\s*(?:اهدافي|أهدافي)').hasMatch(n);

  bool _looksLikeShowInterests(String n) => RegExp(
        r'(?:شنو|ماذا)\s*(?:تعرف\s*عن\s*)?(?:اهتماماتي|اهتمامي)',
      ).hasMatch(n);

  bool _looksLikeShowPreferences(String n) =>
      RegExp(r'(?:شنو|ماذا)\s*(?:تفضيلاتي|تفضيلاتي)').hasMatch(n) ||
      RegExp(r'(?:شنو|ماذا)\s*تفضيلاتي').hasMatch(n);

  bool _looksLikeShowMemorySummary(String n) => RegExp(
        r'(?:شنو|ماذا)\s*(?:تعرف\s*عني\s*غير\s*معلوماتي\s*الشخصيه)|'
        r'(?:شنو|ماذا)\s*(?:الاشياء|الأشياء)\s*(?:اللي\s*)?(?:طلبت\s*منك\s*)?تتذكرها',
      ).hasMatch(n);

  bool _looksLikeBulkDelete(String n) => RegExp(
        r'(?:امسح|احذف)\s*كل\s*(?:اهدافي|أهدافي|اهتماماتي|تفضيلاتي)',
      ).hasMatch(n);

  bool _looksLikeDeleteOne(String n) => RegExp(
        r'(?:احذف|امسح|لا\s*تتذكر)\s*(?:اهتمامي|هدفي|هدف|تفضيل)|'
        r'(?:لا\s*تتذكر\s*اني|لا\s*تتذكر\s*أني)',
      ).hasMatch(n);

  bool _looksLikeComplete(String n) => RegExp(
        r'(?:كملت\s*هدفي|اعتبر\s*(?:هذا\s*)?الهدف\s*مكتمل)',
      ).hasMatch(n);

  bool _looksLikePause(String n) => RegExp(
        r'(?:وقف\s*(?:هذا\s*)?الهدف|خليه\s*بعدين)',
      ).hasMatch(n);

  bool _looksLikeResume(String n) => RegExp(
        r'(?:رجع\s*هدفي|أريد\s*أكمل|اريد\s*أكمل)',
      ).hasMatch(n);

  PersonalMemoryType _bulkType(String n) {
    if (RegExp(r'(?:اهتمام)').hasMatch(n)) return PersonalMemoryType.interest;
    if (RegExp(r'(?:تفضيل)').hasMatch(n)) return PersonalMemoryType.preference;
    return PersonalMemoryType.goal;
  }

  String _needleGoal(String n) {
    if (RegExp(r'flutter|فلتر').hasMatch(n)) return 'flutter';
    if (RegExp(r'figma|فيجما').hasMatch(n)) return 'figma';
    if (RegExp(r'انكليز|إنكليز|انجليز').hasMatch(n)) return 'english';
    if (RegExp(r'مشي').hasMatch(n)) return 'walking';
    return '';
  }

  String _needleDelete(String n) {
    if (RegExp(r'تصوير').hasMatch(n)) return 'تصوير';
    if (RegExp(r'flutter|فلتر').hasMatch(n)) return 'flutter';
    if (RegExp(r'خطوه|خطوة').hasMatch(n)) return 'خطوة';
    if (RegExp(r'عربي').hasMatch(n)) return 'عربي';
    final m = RegExp(r'(?:اهتمامي\s*(?:ب|في)|هدفي|هدف)\s*(.{2,40})')
        .firstMatch(n);
    return m?.group(1)?.trim() ?? _needleGoal(n);
  }

  PersonalMemoryCommandInterpretation? _parseCorrection(String n) {
    // مو Flutter، هدفي أتعلم Figma / مو Flutter أقصد Figma
    final m = RegExp(
      r'(?:مو|مش)\s*(?:flutter|فلتر).{0,40}'
      r'(?:اقصد|أقصد|هدفي|اتعلم|أتعلم)\s*(figma|فيجما|.{2,30})',
    ).firstMatch(n);
    if (m == null) return null;
    final topic = m.group(1)!.trim();
    final isFigma = topic.contains('figma') || topic.contains('فيجما');
    return PersonalMemoryCommandInterpretation(
      kind: PersonalMemoryCommandKind.correctPending,
      candidate: PersonalMemoryCandidate(
        memoryType: PersonalMemoryType.goal,
        canonicalKey: isFigma ? 'goal_learn_figma' : 'goal_${topic.hashCode.abs()}',
        displayLabel: isFigma ? 'تعلم Figma' : topic,
        category: isFigma
            ? PersonalGoalCategory.other.name
            : PersonalGoalCategory.other.name,
        replacesCanonicalKeys: const ['goal_learn_flutter'],
      ),
    );
  }

  bool _isYes(String n) =>
      RegExp(r'^(?:نعم|اي|أي|موافق|اوك|ok|yes)$').hasMatch(n);
  bool _isNo(String n) => RegExp(r'^(?:لا|كلا|مو)$').hasMatch(n);
}
