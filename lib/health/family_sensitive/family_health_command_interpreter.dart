import '../../companion/people/family_person_profile.dart';
import '../../health/subject/health_subject_detector.dart';
import '../../health/subject/health_subject_models.dart';
import '../../search/arabic_text_utils.dart';
import '../sensitive_profile/sensitive_health_profile_models.dart';
import 'family_health_command_models.dart';
import 'family_health_condition_qualifier.dart';
import 'family_health_consent_coordinator.dart';

/// مفسّر أوامر صحة العائلة الحسّاسة — حتمي.
class FamilyHealthCommandInterpreter {
  FamilyHealthCommandInterpreter({
    FamilyHealthConditionQualifier? qualifier,
    HealthSubjectDetector? subjectDetector,
  })  : _qualifier = qualifier ?? const FamilyHealthConditionQualifier(),
        _subjects = subjectDetector ?? const HealthSubjectDetector();

  final FamilyHealthConditionQualifier _qualifier;
  final HealthSubjectDetector _subjects;

  FamilyHealthCommandInterpretation interpret({
    required String raw,
    required FamilyHealthPendingOp pending,
  }) {
    final original = raw.trim();
    final n = ArabicTextUtils.normalize(original);
    if (n.isEmpty) return FamilyHealthCommandInterpretation.none;

    // موافقة معلّقة
    if (pending.kind == FamilyHealthPendingKind.rememberConsent ||
        pending.consent.isActive) {
      if (_isWhy(n)) {
        return const FamilyHealthCommandInterpretation(
          kind: FamilyHealthCommandKind.consentWhy,
          message: FamilyHealthConsentCoordinator.whyExplanation,
        );
      }
      if (_isLater(n)) {
        return const FamilyHealthCommandInterpretation(
          kind: FamilyHealthCommandKind.consentLater,
        );
      }
      if (_isNo(n)) {
        return const FamilyHealthCommandInterpretation(
          kind: FamilyHealthCommandKind.consentNo,
        );
      }
      if (_isYes(n)) {
        return FamilyHealthCommandInterpretation(
          kind: FamilyHealthCommandKind.consentYes,
          candidates: pending.consent.candidates,
        );
      }
    }

    // تأكيد حذف كل صحة شخص
    if (pending.kind == FamilyHealthPendingKind.deleteAllHealthForPerson ||
        pending.kind == FamilyHealthPendingKind.deletePersonWithHealth) {
      if (_isYes(n)) {
        return const FamilyHealthCommandInterpretation(
          kind: FamilyHealthCommandKind.confirmDeleteAllHealth,
        );
      }
      if (_isNo(n) || _isCancel(n)) {
        return const FamilyHealthCommandInterpretation(
          kind: FamilyHealthCommandKind.cancelDelete,
        );
      }
    }

    // توضيح شخص قبل الموافقة
    if (pending.kind == FamilyHealthPendingKind.clarifyPersonBeforeConsent) {
      return FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.clarifyPerson,
        personNameHint: original,
        candidates: pending.pendingCandidates,
        message: pending.originalQuery,
      );
    }

    if (_looksLikeProviderEscape(n)) {
      return const FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.deferToProvider,
      );
    }

    if (_looksLikeUrgentSafety(n)) {
      return const FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.deferToUrgentSafety,
      );
    }

    if (_looksLikeMentalSafety(n)) {
      return const FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.deferToMentalSafety,
      );
    }

    // حذف كل الصحة لشخص — قبل العرض لأن الأنماط تتشابه
    if (_looksLikeDeleteAllHealth(n)) {
      return FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.deleteAllHealthRequest,
        personNameHint: _extractNameHint(n),
        relationshipHint: _extractRelationshipToken(n),
      );
    }

    // نسيان حالة واحدة
    final forgetKey = _parseForgetKey(n);
    if (forgetKey != null) {
      return FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.forgetCondition,
        conditionKey: forgetKey,
        personNameHint: _extractNameHint(n),
        relationshipHint: _extractRelationshipToken(n),
      );
    }

    // عرض صحة شخص / نظرة عامة
    if (_looksLikeGlobalFamilyHealthQuery(n)) {
      return const FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.showFamilyHealthOverview,
      );
    }
    if (_looksLikeShowPersonHealth(n)) {
      return FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.showPersonHealth,
        personNameHint: _extractNameHint(n),
        relationshipHint: _extractRelationshipToken(n),
      );
    }

    if (_looksLikeChronicNotImpl(n)) {
      return const FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.notImplementedChronic,
        message:
            'متابعة الحالات المزمنة للعائلة لسه مو مفعّلة. '
            'أكدر أتذكر الحالة المشخّصة إذا وافقت، بدون قياسات أو متابعة تلقائية الآن.',
      );
    }

    if (_qualifier.looksLikeAllergyWorkflow(original)) {
      return const FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.notImplementedAllergy,
        message: 'حفظ الحساسية الدائم لسه مو مفعّل.',
      );
    }

    if (_qualifier.looksLikeMedicationMention(original) &&
        !_hasDiagnosedCondition(n) &&
        _looksLikeRememberOrClaim(n)) {
      return const FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.notImplementedMedication,
        message: 'ما أحفظ الأدوية في هذه المرحلة. أكدر أتذكر التشخيص فقط إذا كان واضحاً ووافقت.',
      );
    }

    // تذكّر / تصريح صحة عائلة
    if (_looksLikeFamilyHealthRemember(n, original)) {
      final detailed = _qualifier.qualifyDetailed(original);
      if (!detailed.hasEligible) {
        final status = detailed.ineligibleStatus ??
            _qualifier.classifyIneligible(original);
        final msg = status == HealthDiagnosisStatus.symptomOnly
            ? 'هاي تبدو ملاحظة أو عرض، مو حالة مشخّصة ثابتة. ما أحفظها كصحة دائمة للعائلة.'
            : 'ما أقدر أحفظها كحالة مشخّصة لأن الكلام فيه شك أو مو واضح كتشخيص. «تذكر» وحدها ما تكفي.';
        return FamilyHealthCommandInterpretation(
          kind: FamilyHealthCommandKind.rejectIneligible,
          message: msg,
          personNameHint: _extractNameHint(n),
          relationshipHint: _extractRelationshipToken(n),
        );
      }
      return FamilyHealthCommandInterpretation(
        kind: FamilyHealthCommandKind.rememberCandidates,
        candidates: detailed.eligible,
        personNameHint: _extractNameHint(n),
        relationshipHint: _extractRelationshipToken(n),
        mixedClarify: detailed.mixedEstablishedAndUncertain,
      );
    }

    return FamilyHealthCommandInterpretation.none;
  }

  bool looksLikeFamilyHealthCommand(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return false;
    if (_looksLikeOwnerSelfOnly(n)) return false;
    return _looksLikeShowPersonHealth(n) ||
        _looksLikeGlobalFamilyHealthQuery(n) ||
        _looksLikeDeleteAllHealth(n) ||
        _parseForgetKey(n) != null ||
        _looksLikeFamilyHealthRemember(n, raw) ||
        _looksLikeChronicNotImpl(n);
  }

  bool _looksLikeFamilyHealthRemember(String n, String original) {
    if (_looksLikeOwnerSelfOnly(n)) return false;
    final subj = _subjects.detect(original);
    final otherSubject = subj.type != HealthSubjectType.self &&
        subj.type != HealthSubjectType.unknown &&
        subj.evidence == HealthSubjectEvidence.explicitRelationship;
    final namedOther = _extractNameHint(n) != null &&
        (_looksLikeRememberOrClaim(n) || _hasDiagnosedCondition(n));
    final familyRel = _extractRelationshipToken(n) != null;
    if (!(otherSubject || namedOther || familyRel)) return false;
    return _looksLikeRememberOrClaim(n) || _hasDiagnosedCondition(n);
  }

  bool _looksLikeOwnerSelfOnly(String n) => RegExp(
        r'(?:^|\s)(?:عندي|انا|أنا)\s*(?:سكري|ضغط|ربو)|'
        r'(?:مشخصني|شخصني)|'
        r'(?:معلوماتي\s*الصحيه|صحتي)(?!\s*عن)',
      ).hasMatch(n);

  bool _looksLikeRememberOrClaim(String n) => RegExp(
        r'(?:تذكر|تذكّر|احفظ)\s*(?:ان|أن|هذا|هاي)?|'
        r'(?:مشخص|مشخّص|الطبيب\s*قال|الدكتور\s*قال|مثبت)',
      ).hasMatch(n);

  bool _hasDiagnosedCondition(String n) => RegExp(
        r'(?:مشخص|مشخّص).{0,24}(?:سكري|ضغط|ربو)|'
        r'(?:سكري|ضغط|ربو).{0,24}(?:مشخص|مشخّص)|'
        r'(?:عنده|عندها)\s*(?:سكري|ضغط|ربو)\s*(?:مشخص|مشخّص)?',
      ).hasMatch(n);

  bool _looksLikeShowPersonHealth(String n) {
    if (RegExp(r'(?:امسح|احذف)').hasMatch(n)) return false;
    return RegExp(
      r'(?:شنو|ماذا|ايش)\s*(?:متذكر|تعرف|المعلومات\s*الصحيه\s*المحفوظه)\s*'
      r'(?:عن\s*)?(?:صحه|صحة)?\s*(?:علي|احمد|حسين|فاطمه|فاطمة|\S{2,})|'
      r'(?:شنو|ماذا)\s*(?:تعرف|متذكر)\s*عن\s*صحه\s*(?:ابني|ابنتي|امي|ابوي|زوجتي)|'
      r'(?:المعلومات\s*الصحيه\s*المحفوظه\s*عن)',
    ).hasMatch(n);
  }

  bool _looksLikeGlobalFamilyHealthQuery(String n) => RegExp(
        r'(?:شنو|ماذا)\s*(?:المعلومات\s*الصحيه)\s*(?:اللي\s*)?(?:حافظها|محفوظه)\s*'
        r'(?:عن\s*)?(?:عا?يلتي|العائله|العائلة)|'
        r'(?:صحه\s*عا?يلتي\s*المحفوظه)',
      ).hasMatch(n);

  bool _looksLikeDeleteAllHealth(String n) => RegExp(
        r'(?:امسح|احذف)\s*(?:كل\s*)?(?:المعلومات\s*الصحيه\s*(?:المحفوظه)?)\s*عن|'
        r'(?:امسح|احذف)\s*كل\s*(?:المعلومات\s*الصحيه)\s*عن|'
        r'(?:امسح|احذف)\s*كل\s*المعلومات\s*الصحيه\s*المحفوظه\s*عن',
      ).hasMatch(n);

  bool _looksLikeChronicNotImpl(String n) => RegExp(
        r'(?:شلون\s*سكر\s*(?:علي|ابني|امي)|جدول\s*متابعه\s*(?:علي|ابني)|'
        r'متابعة\s*مزمنه\s*(?:للعائله|لابني))',
      ).hasMatch(n);

  bool _looksLikeProviderEscape(String n) => RegExp(
        r'(?:أريد|اريد|ابي|دور)\s*(?:طبيب|دكتور|مختبر)',
      ).hasMatch(n);

  bool _looksLikeUrgentSafety(String n) => RegExp(
        r'(?:ضيق\s*نفس|اختناق|فاقد\s*وعي|نزيف|الم\s*صدر|ألم\s*صدر)',
      ).hasMatch(n);

  bool _looksLikeMentalSafety(String n) => RegExp(
        r'(?:انتحار|اذي\s*نفسي|أذي\s*نفسي|اقتل\s*نفسي|ما\s*اريد\s*اعيش)',
      ).hasMatch(n);

  String? _parseForgetKey(String n) {
    if (!RegExp(
      r'(?:امسح|احذف|لا\s*تتذكر)\s*(?:ال)?(?:سكري|ضغط|ربو)',
    ).hasMatch(n)) {
      return null;
    }
    if (RegExp(r'سكري').hasMatch(n)) {
      return HealthCanonicalConditionKey.diabetes.name;
    }
    if (RegExp(r'ضغط').hasMatch(n)) {
      return HealthCanonicalConditionKey.hypertension.name;
    }
    if (RegExp(r'ربو').hasMatch(n)) {
      return HealthCanonicalConditionKey.asthma.name;
    }
    return null;
  }

  String? _extractNameHint(String n) {
    final m1 = RegExp(
      r'(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي)\s+([^\s،,]{2,})',
    ).firstMatch(n);
    if (m1 != null) {
      final g = m1.group(1)!;
      if (!_isNoise(g)) return g;
    }
    final m2 = RegExp(
      r'([^\s،,]{2,})\s+(?:ابني|ابنتي)',
    ).firstMatch(n);
    if (m2 != null) {
      final g = m2.group(1)!;
      if (!_isNoise(g)) return g;
    }
    final m3 = RegExp(
      r'(?:صحه|صحة|عن)\s+([^\s،?]{2,})|'
      r'(?:^|\s)([^\s،]{2,})\s+(?:مشخص|عنده|عندها|خايف)',
    ).firstMatch(n);
    final g = m3?.group(1) ?? m3?.group(2);
    if (g != null && !_isNoise(g) && !_isRel(g)) return g;
    return null;
  }

  String? _extractRelationshipToken(String n) {
    if (RegExp(r'(?:ابني|ولدي)').hasMatch(n)) return 'son';
    if (RegExp(r'(?:ابنتي|بنتي)').hasMatch(n)) return 'daughter';
    if (RegExp(r'(?:امي|أمي)').hasMatch(n)) return 'mother';
    if (RegExp(r'(?:ابوي|أبوي)').hasMatch(n)) return 'father';
    if (RegExp(r'(?:زوجتي)').hasMatch(n)) return 'wife';
    if (RegExp(r'(?:زوجي)').hasMatch(n)) return 'husband';
    return null;
  }

  PersonRelationship? relationshipFromHint(String? hint) {
    switch (hint) {
      case 'son':
        return PersonRelationship.son;
      case 'daughter':
        return PersonRelationship.daughter;
      case 'mother':
        return PersonRelationship.mother;
      case 'father':
        return PersonRelationship.father;
      case 'wife':
        return PersonRelationship.wife;
      case 'husband':
        return PersonRelationship.husband;
      default:
        return null;
    }
  }

  bool _isNoise(String w) => RegExp(
        r'^(?:عنده|عندها|مشخص|سكري|ضغط|ربو|صحه|صحة|عن|كل|المعلومات)$',
      ).hasMatch(w);

  bool _isRel(String w) => RegExp(
        r'^(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي)$',
      ).hasMatch(w);

  bool _isYes(String n) =>
      RegExp(r'^(?:نعم|اي|أي|موافق|اوك|ok|yes)$').hasMatch(n);
  bool _isNo(String n) => RegExp(r'^(?:لا|كلا|مو)$').hasMatch(n);
  bool _isLater(String n) =>
      RegExp(r'(?:بعدين|لاحقا|مو\s*هسه|مو\s*الحين)').hasMatch(n);
  bool _isWhy(String n) => RegExp(r'^(?:ليش|لماذا|ليش\؟|\?)$').hasMatch(n);
  bool _isCancel(String n) => RegExp(r'(?:الغ|إلغ|cancel)').hasMatch(n);
}
