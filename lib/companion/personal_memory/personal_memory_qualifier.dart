import '../../health/subject/health_subject_detector.dart';
import '../../health/subject/health_subject_models.dart';
import '../../search/arabic_text_utils.dart';
import 'personal_memory_models.dart';

/// تأهيل ذاكرة شخصية — حتمي، بلا تخمين هوية/نفس/صحة.
class PersonalMemoryQualifier {
  const PersonalMemoryQualifier({
    HealthSubjectDetector? subjects,
  }) : _subjects = subjects ?? const HealthSubjectDetector();

  final HealthSubjectDetector _subjects;

  bool hasExplicitRememberIntent(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(
      r'(?:تذكر|تذكّر|احفظ|خلي\s*ببالك|من\s*هسه\s*اعرف|'
      r'من\s*هسه\s*اعرف|سجل\s*ان|سجّل\s*ان)',
    ).hasMatch(n);
  }

  bool isOwnerOnlyStatement(String raw) {
    final subj = _subjects.detect(raw);
    if (subj.evidence == HealthSubjectEvidence.explicitRelationship &&
        subj.type != HealthSubjectType.self &&
        subj.type != HealthSubjectType.unknown) {
      return false;
    }
    final n = ArabicTextUtils.normalize(raw);
    // حدود كلمة — لا تلتقط «امي» داخل «اهتمامي».
    if (RegExp(
      r'(?:^|\s)(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي)(?:\s|$)',
    ).hasMatch(n)) {
      return false;
    }
    return true;
  }

  bool looksLikeEmotionalState(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(
      r'(?:حزين|خايف|متوتر|مضغوط|قلقان|زعلان|مرهق\s*نفسيا)',
    ).hasMatch(n);
  }

  bool looksLikePersonalityLabel(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(
      r'(?:كسول|منضبط|قلِق|انطوائي|انبساطي|ذكي|ضعيف|متحمس|غير\s*متحمس)',
    ).hasMatch(n);
  }

  bool looksLikeSensitiveHealthFact(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(
      r'(?:مشخص|مشخّص|تشخيص|دواء|حساسيه|حساسية|'
      r'سكري|ضغط|ربو).{0,20}(?:عندي|اني|أنا)|'
      r'(?:عندي\s*(?:سكري|ضغط|ربو)\s*مشخص)',
    ).hasMatch(n);
  }

  bool looksLikeFleetingPreference(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(
      r'(?:اليوم|هسه|حاليا|هالمره|هالمرة)\s*.{0,24}'
      r'(?:ما\s*أريد|ما\s*اريد|ما\s*احب|ما\s*أحتاج)',
    ).hasMatch(n);
  }

  /// يستخرج مرشّحاً فقط عند نية تذكّر صريحة + محتوى واضح.
  PersonalMemoryCandidate? extractExplicitCandidate(String raw) {
    if (!isOwnerOnlyStatement(raw)) return null;
    if (!hasExplicitRememberIntent(raw)) return null;
    if (looksLikeEmotionalState(raw)) return null;
    if (looksLikePersonalityLabel(raw)) return null;
    if (looksLikeSensitiveHealthFact(raw)) return null;
    if (looksLikeFleetingPreference(raw)) return null;

    final n = ArabicTextUtils.normalize(raw);

    // تفضيلات مساعدة
    final pref = _extractPreference(n);
    if (pref != null) return pref;

    // أهداف
    final goal = _extractGoal(n);
    if (goal != null) return goal;

    // اهتمامات
    final interest = _extractInterest(n);
    if (interest != null) return interest;

    return null;
  }

  /// جملة ضمنية — جلسة فقط.
  bool isImplicitOnly(String raw) {
    if (hasExplicitRememberIntent(raw)) return false;
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(
      r'(?:اتعلم|أتعلم|احب|أحب|مهتم|هدفي|أريد\s*ألتزم)',
    ).hasMatch(n);
  }

  PersonalMemoryCandidate? _extractGoal(String n) {
    if (!RegExp(
          r'(?:هدف|هدفي|اريد\s*التزم|أريد\s*ألتزم|التزم|اتعلم|أتعلم|ارتب\s*نومي|امشي|أمشي)',
        ).hasMatch(n) &&
        !RegExp(r'(?:هدفي|هدف)').hasMatch(n)) {
      if (!RegExp(r'(?:اتعلم|أتعلم)').hasMatch(n)) return null;
    }

    String key = 'goal_other';
    String label = 'هدف شخصي';
    String category = PersonalGoalCategory.other.name;

    if (RegExp(r'(?:flutter|فلتر)').hasMatch(n)) {
      key = 'goal_learn_flutter';
      label = 'تعلم Flutter';
      category = PersonalGoalCategory.technology.name;
    } else if (RegExp(r'(?:انكليز|إنكليز|انجليز|إنجليز|english)').hasMatch(n)) {
      key = 'goal_learn_english';
      label = 'تعلم الإنكليزي';
      category = PersonalGoalCategory.languageLearning.name;
    } else if (RegExp(r'(?:figma|فيجما)').hasMatch(n)) {
      key = 'goal_learn_figma';
      label = 'تعلم Figma';
      category = PersonalGoalCategory.other.name;
    } else if (RegExp(r'(?:مشي|امشي|أمشي)').hasMatch(n)) {
      key = 'goal_walking';
      label = 'الالتزام بالمشي';
      category = PersonalGoalCategory.fitness.name;
    } else if (RegExp(r'(?:نوم|انام|أنام)').hasMatch(n)) {
      key = 'goal_sleep_routine';
      label = 'ترتيب النوم';
      category = PersonalGoalCategory.sleepRoutine.name;
    } else if (RegExp(r'(?:مونتاج|محتوي|محتوى|صناعه\s*المحتوي|صناعة\s*المحتوى)')
        .hasMatch(n)) {
      key = 'goal_content_creation';
      label = 'صناعة المحتوى / المونتاج';
      category = PersonalGoalCategory.contentCreation.name;
    } else if (RegExp(r'(?:سكري|ضغط|ربو)').hasMatch(n)) {
      // هدف مرتبط بصحة بدون تكرار التشخيص كذاكرة عادية
      key = 'goal_health_lifestyle';
      label = 'هدف أسلوب حياة صحي';
      category = PersonalGoalCategory.fitness.name;
    } else {
      final m = RegExp(r'(?:اتعلم|أتعلم|هدفي)\s+(.{2,40})$').firstMatch(n);
      final topic = m?.group(1)?.trim();
      if (topic != null && topic.isNotEmpty) {
        key = 'goal_${topic.hashCode.abs()}';
        label = topic;
        category = PersonalGoalCategory.other.name;
      } else if (!RegExp(r'(?:هدف|هدفي|اتعلم|أتعلم|التزم|ألتزم)').hasMatch(n)) {
        return null;
      }
    }

    return PersonalMemoryCandidate(
      memoryType: PersonalMemoryType.goal,
      canonicalKey: key,
      displayLabel: label,
      category: category,
    );
  }

  PersonalMemoryCandidate? _extractInterest(String n) {
    if (!RegExp(r'(?:مهتم|احب|أحب|اهتمام)').hasMatch(n) &&
        !RegExp(r'(?:تصوير|مونتاج|برمجه|برمجة|اشعه|أشعة)').hasMatch(n)) {
      return null;
    }
    // إذا هدف صريح يُفضَّل الهدف
    if (RegExp(r'(?:هدف|هدفي|أريد\s*ألتزم|اريد\s*التزم)').hasMatch(n)) {
      return null;
    }

    String key = 'interest_other';
    String label = 'اهتمام شخصي';
    String category = PersonalInterestCategory.other.name;

    if (RegExp(r'(?:تصوير|فوتو|photography)').hasMatch(n)) {
      key = 'interest_photography';
      label = 'التصوير';
      category = PersonalInterestCategory.photography.name;
    } else if (RegExp(r'(?:مونتاج|محتوي|محتوى)').hasMatch(n)) {
      key = 'interest_content_creation';
      label = 'صناعة المحتوى';
      category = PersonalInterestCategory.contentCreation.name;
    } else if (RegExp(r'(?:برمجه|برمجة|flutter|فلتر|coding)').hasMatch(n)) {
      key = 'interest_programming';
      label = 'البرمجة';
      category = PersonalInterestCategory.programming.name;
    } else if (RegExp(r'(?:اشعه|أشعة|radiology)').hasMatch(n)) {
      key = 'interest_radiology';
      label = 'الأشعة';
      category = PersonalInterestCategory.radiology.name;
    } else if (RegExp(r'(?:تصميم|design|figma)').hasMatch(n)) {
      key = 'interest_design';
      label = 'التصميم';
      category = PersonalInterestCategory.design.name;
    } else {
      final m = RegExp(r'(?:مهتم\s*(?:ب|في)|احب|أحب)\s+(.{2,40})').firstMatch(n);
      final topic = m?.group(1)?.trim();
      if (topic == null || topic.isEmpty) return null;
      key = 'interest_${topic.hashCode.abs()}';
      label = topic;
      category = PersonalInterestCategory.other.name;
    }

    return PersonalMemoryCandidate(
      memoryType: PersonalMemoryType.interest,
      canonicalKey: key,
      displayLabel: label,
      category: category,
    );
  }

  PersonalMemoryCandidate? _extractPreference(String n) {
    if (!RegExp(r'(?:افضل|أفضل|احب\s*الشرح|أفضل\s*الشرح|النص\s*اكثر|النص\s*أكثر)')
        .hasMatch(n)) {
      return null;
    }
    // «من هسه اعرف» نية دائمة — ليست تفضيلاً عابراً.
    if (RegExp(r'(?:اليوم|هالمره|هالمرة)\b').hasMatch(n) &&
        !RegExp(r'من\s*هسه\s*اعرف').hasMatch(n)) {
      return null;
    }
    if (RegExp(r'(?:^|[^\u0600-\u06FF])هسه(?:$|[^\u0600-\u06FF])').hasMatch(n) &&
        !RegExp(r'من\s*هسه\s*اعرف').hasMatch(n) &&
        RegExp(r'(?:ما\s*أريد|ما\s*اريد|ما\s*احب)').hasMatch(n)) {
      return null;
    }

    if (RegExp(r'(?:عربي|بالعربي)').hasMatch(n)) {
      return const PersonalMemoryCandidate(
        memoryType: PersonalMemoryType.preference,
        canonicalKey: 'pref_explain_arabic',
        displayLabel: 'تفضيل الشرح بالعربي',
        category: 'assistance',
        preferenceDomain: 'explanationLanguage',
      );
    }
    if (RegExp(r'(?:خطوه\s*خطوه|خطوة\s*خطوة)').hasMatch(n)) {
      return const PersonalMemoryCandidate(
        memoryType: PersonalMemoryType.preference,
        canonicalKey: 'pref_step_by_step',
        displayLabel: 'تفضيل الشرح خطوة خطوة',
        category: 'assistance',
        preferenceDomain: 'explanationStyle',
      );
    }
    if (RegExp(r'(?:النص\s*اكثر|النص\s*أكثر|افضل\s*النص)').hasMatch(n)) {
      return const PersonalMemoryCandidate(
        memoryType: PersonalMemoryType.preference,
        canonicalKey: 'pref_text_over_voice',
        displayLabel: 'تفضيل النص أكثر من الصوت',
        category: 'assistance',
        preferenceDomain: 'modalityTextPreferred',
      );
    }
    return null;
  }
}
