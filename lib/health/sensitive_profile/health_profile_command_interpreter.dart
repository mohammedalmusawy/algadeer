import '../../health/subject/health_subject_detector.dart';
import '../../health/subject/health_subject_models.dart';
import '../../search/arabic_text_utils.dart';
import 'health_condition_qualifier.dart';
import 'health_consent_coordinator.dart';
import 'health_profile_command_models.dart';
import 'sensitive_health_profile_models.dart';

/// مفسّر أوامر ملف الصحة الحسّاس — حتمي.
class HealthProfileCommandInterpreter {
  HealthProfileCommandInterpreter({
    HealthConditionQualifier? qualifier,
    HealthSubjectDetector? subjectDetector,
  })  : _qualifier = qualifier ?? const HealthConditionQualifier(),
        _subjects = subjectDetector ?? const HealthSubjectDetector();

  final HealthConditionQualifier _qualifier;
  final HealthSubjectDetector _subjects;

  HealthProfileCommandInterpretation interpret({
    required String raw,
    required HealthProfilePendingOp pending,
  }) {
    final original = raw.trim();
    final n = ArabicTextUtils.normalize(original);
    if (n.isEmpty) return HealthProfileCommandInterpretation.none;

    // موافقة معلّقة
    if (pending.kind == HealthProfilePendingKind.rememberConsent ||
        pending.consent.isActive) {
      if (_isWhy(n)) {
        return const HealthProfileCommandInterpretation(
          kind: HealthProfileCommandKind.consentWhy,
          message: HealthConsentCoordinator.whyExplanation,
        );
      }
      if (_isLater(n)) {
        return const HealthProfileCommandInterpretation(
          kind: HealthProfileCommandKind.consentLater,
        );
      }
      if (_isNo(n)) {
        return const HealthProfileCommandInterpretation(
          kind: HealthProfileCommandKind.consentNo,
        );
      }
      if (_isYes(n)) {
        return HealthProfileCommandInterpretation(
          kind: HealthProfileCommandKind.consentYes,
          candidates: pending.consent.candidates,
        );
      }
    }

    // تأكيد حذف كامل
    if (pending.kind == HealthProfilePendingKind.deleteWholeHealthProfile) {
      if (_isYes(n)) {
        return const HealthProfileCommandInterpretation(
          kind: HealthProfileCommandKind.confirmDelete,
        );
      }
      if (_isNo(n) || _isCancel(n)) {
        return const HealthProfileCommandInterpretation(
          kind: HealthProfileCommandKind.cancelDelete,
        );
      }
    }

    // جدار المالك
    final subj = _subjects.detect(original);
    if (subj.type != HealthSubjectType.self &&
        subj.type != HealthSubjectType.unknown &&
        subj.evidence == HealthSubjectEvidence.explicitRelationship) {
      if (_looksLikeHealthMemorySurface(n)) {
        return const HealthProfileCommandInterpretation(
          kind: HealthProfileCommandKind.rejectNonOwner,
          message:
              'هاي المعلومة تخص شخص ثاني. ما أحفظها بملفك الصحي الشخصي.',
        );
      }
    }

    // حالات عاطفية — ليست تشخيصاً
    if (_isEmotionalOnly(n)) {
      return const HealthProfileCommandInterpretation(
        kind: HealthProfileCommandKind.rejectIneligible,
        message:
            'ما أحفظ المزاج أو التوتر كتشخيص صحي. إذا عندك حالة مشخّصة وتريد تذكيري فيها، قلها بوضوح.',
      );
    }

    // عرض
    if (_looksLikeShow(n)) {
      return const HealthProfileCommandInterpretation(
        kind: HealthProfileCommandKind.showHealthProfile,
      );
    }

    // تعطيل / تفعيل
    if (RegExp(
      r'(?:عطل\s*(?:استخدام\s*)?(?:معلوماتي\s*الصحيه|الملف\s*الصحي)|'
      r'لا\s*تستخدم\s*معلوماتي\s*الصحيه)',
    ).hasMatch(n)) {
      return const HealthProfileCommandInterpretation(
        kind: HealthProfileCommandKind.disableHealthPersonalization,
      );
    }
    if (RegExp(
      r'(?:فعل\s*(?:معلوماتي\s*الصحيه|الملف\s*الصحي)|'
      r'رجع\s*(?:استخدام\s*)?معلوماتي\s*الصحيه)',
    ).hasMatch(n)) {
      return const HealthProfileCommandInterpretation(
        kind: HealthProfileCommandKind.enableHealthPersonalization,
      );
    }

    // حذف الكل
    if (RegExp(
      r'(?:امسح|احذف)\s*(?:كل\s*)?(?:معلوماتي\s*الصحيه|الملف\s*الصحي)(?:\s*كلها)?',
    ).hasMatch(n)) {
      return const HealthProfileCommandInterpretation(
        kind: HealthProfileCommandKind.deleteAllRequest,
      );
    }

    // نسيان حالة واحدة
    final forgetKey = _parseForgetKey(n);
    if (forgetKey != null) {
      return HealthProfileCommandInterpretation(
        kind: HealthProfileCommandKind.forgetCondition,
        conditionKey: forgetKey,
      );
    }

    // رفض متابعة مزمنة مبكرة
    if (RegExp(r'(?:شلون\s*(?:السكر|الضغط)|جدول\s*متابعه|متابعة\s*مزمنه)')
        .hasMatch(n)) {
      return const HealthProfileCommandInterpretation(
        kind: HealthProfileCommandKind.notImplementedChronic,
        message:
            'متابعة الحالات المزمنة لسه مو مفعّلة. أكدر أتذكر الحالة المشخّصة إذا وافقت، بدون متابعة تلقائية الآن.',
      );
    }

    // تذكّر / تصريح حالة
    if (_looksLikeRememberOrClaim(n)) {
      final candidates = _qualifier.extractEligibleCandidates(original);
      if (candidates.isEmpty) {
        final status = _qualifier.classifyIneligible(original);
        final msg = status == HealthDiagnosisStatus.symptomOnly
            ? 'هاي تبدو ملاحظة أو عرض، مو حالة مشخّصة ثابتة. ما أحفظها بملفك الصحي الدائم.'
            : 'ما أقدر أحفظها كحالة مشخّصة لأن الكلام فيه شك أو مو واضح كتشخيص. إذا مشخصك الطبيب، قلها بصيغة أوضح.';
        return HealthProfileCommandInterpretation(
          kind: HealthProfileCommandKind.rejectIneligible,
          message: msg,
        );
      }
      return HealthProfileCommandInterpretation(
        kind: HealthProfileCommandKind.rememberCandidates,
        candidates: candidates,
      );
    }

    if (RegExp(r'^(?:احذف|امسح)\s*(?:هذا|هذ|هاي)$').hasMatch(n)) {
      return const HealthProfileCommandInterpretation(
        kind: HealthProfileCommandKind.clarifyAmbiguous,
        message:
            'شنو تقصد؟ إذا تريد مسح معلوماتك الصحية كلها، قل: امسح معلوماتي الصحية كلها.',
      );
    }

    return HealthProfileCommandInterpretation.none;
  }

  bool looksLikeHealthCommand(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return _looksLikeHealthMemorySurface(n) ||
        _looksLikeShow(n) ||
        _looksLikeRememberOrClaim(n) ||
        RegExp(r'(?:معلوماتي\s*الصحيه|الملف\s*الصحي)').hasMatch(n);
  }

  bool _looksLikeHealthMemorySurface(String n) => RegExp(
        r'(?:صحي|صحه|صحة|سكري|ضغط|ربو|امراض|أمراض|تشخيص|مشخص)',
      ).hasMatch(n);

  bool _looksLikeShow(String n) => RegExp(
        r'(?:شنو|ماذا|ايش)\s*(?:تعرف\s*عن\s*صحتي|الامراض|الأمراض)\s*(?:اللي\s*)?(?:حافظها|محفوظه)?|'
        r'شنو\s*(?:الامراض|الأمراض)\s*(?:اللي\s*)?(?:حافظها|عندك)|'
        r'عرفني\s*شنو\s*تعرف\s*عن\s*صحتي',
      ).hasMatch(n);

  bool _looksLikeRememberOrClaim(String n) => RegExp(
        r'(?:تذكر|تذكّر|احفظ)\s*(?:ان|أن)?|'
        r'(?:عندي\s*(?:سكري|ضغط|ربو)|مشخص|مشخّص|شخصني|'
        r'انا\s*مشخص|مصاب\s*ب)',
      ).hasMatch(n);

  String? _parseForgetKey(String n) {
    if (!RegExp(
      r'(?:امسح|احذف|لا\s*تتذكر|انس[ىي]?)\s*.*(?:سكري|ضغط|ربو)|'
      r'(?:السكري|الضغط|الربو)\s*من\s*معلوماتي',
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

  bool _isEmotionalOnly(String n) =>
      RegExp(r'^(?:اني\s*)?(?:متوتر|خايف|حزين|مضغوط|قلقان)$').hasMatch(n) ||
      RegExp(
        r'(?:تذكر|احفظ)\s*(?:اني\s*)?(?:متوتر|خايف|حزين|مضغوط)',
      ).hasMatch(n);

  bool _isWhy(String n) =>
      n.contains('ليش') || n.contains('لماذا') || n == 'ليش؟' || n == 'ليش';

  bool _isLater(String n) =>
      RegExp(r'(?:بعدين|لاحقا|مو\s*هسه)').hasMatch(n);

  bool _isYes(String n) =>
      RegExp(r'(?:^|\s)(?:اي|نعم|هيه|زين|موافق)(?:\s|$)').hasMatch(n) ||
      n == 'اي' ||
      n == 'نعم';

  bool _isNo(String n) =>
      RegExp(r'(?:^|\s)(?:لا|كلا|ما\s*اريد|لا\s*اريد)(?:\s|$)').hasMatch(n) ||
      n == 'لا';

  bool _isCancel(String n) =>
      RegExp(r'(?:الغي|ألغي|تراجع|بطل)').hasMatch(n);
}
