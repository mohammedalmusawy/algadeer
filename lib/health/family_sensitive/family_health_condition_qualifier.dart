import '../../search/arabic_text_utils.dart';
import '../sensitive_profile/health_condition_qualifier.dart';
import '../sensitive_profile/sensitive_health_profile_models.dart';

/// تأهيل حالات صحية عائلية — دلالات PC-1.4 + حدود القياس/الدواء/الشك.
class FamilyHealthConditionQualifier {
  const FamilyHealthConditionQualifier({
    HealthConditionQualifier? ownerQualifier,
  }) : _owner = ownerQualifier ?? const HealthConditionQualifier();

  final HealthConditionQualifier _owner;

  List<HealthConditionCandidate> extractEligibleCandidates(String raw) =>
      qualifyDetailed(raw).eligible;

  FamilyHealthQualificationResult qualifyDetailed(String raw) {
    final cleaned = _stripNonDiagnosisNoise(raw);
    final n = ArabicTextUtils.normalize(cleaned);
    if (n.isEmpty) {
      return const FamilyHealthQualificationResult(
        eligible: [],
        ineligibleStatus: HealthDiagnosisStatus.uncertain,
      );
    }

    // «تذكر» لا يرقّي الشك إلى تشخيص.
    if (_hasUncertainty(n) && !_hasAnyDiagnosedCue(n)) {
      return FamilyHealthQualificationResult(
        eligible: const [],
        ineligibleMentionedKeys: _mentionedKeys(n),
        ineligibleStatus: HealthDiagnosisStatus.uncertain,
      );
    }

    final eligible = <HealthConditionCandidate>[];
    final ineligible = <String>[];

    for (final item in _conditionDefs) {
      if (!RegExp(item.mentioned).hasMatch(n)) continue;
      if (_uncertainNear(n, item.cue)) {
        ineligible.add(item.key);
        continue;
      }
      if (!_diagnosedCueFor(n, item.cue)) {
        // مذكور بدون مشخص صريح لهذه الحالة
        ineligible.add(item.key);
        continue;
      }
      eligible.add(
        HealthConditionCandidate(
          canonicalConditionKey: item.key,
          displayName: item.display,
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
        ),
      );
    }

    // بدون شك: اسمح بمسار المالك (مشخص / ثبات / تذكر+حالة واضحة)
    if (eligible.isEmpty && !_hasUncertainty(n)) {
      final fromOwner = _owner.extractEligibleCandidates(cleaned);
      if (fromOwner.isNotEmpty) {
        return FamilyHealthQualificationResult(eligible: fromOwner);
      }
    }

    return FamilyHealthQualificationResult(
      eligible: List.unmodifiable(eligible),
      ineligibleMentionedKeys: ineligible,
      mixedEstablishedAndUncertain:
          eligible.isNotEmpty && ineligible.isNotEmpty,
      ineligibleStatus: eligible.isEmpty
          ? _owner.classifyIneligible(raw)
          : null,
    );
  }

  HealthDiagnosisStatus classifyIneligible(String raw) =>
      _owner.classifyIneligible(raw);

  bool looksLikeMeasurementOnly(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(
      r'(?:\d{2,3}|قياس|قراءه|قراءة).{0,12}(?:سكر|ضغط)|'
      r'(?:سكر|ضغط).{0,12}(?:\d{2,3}|مرتفع|عالي|اليوم)',
    ).hasMatch(n);
  }

  bool looksLikeMedicationMention(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(r'(?:ياخذ|يأخذ|دواء|علاج|حبه|حبة)').hasMatch(n);
  }

  bool looksLikeAllergyWorkflow(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(r'(?:حساسيه|حساسية|allergy)').hasMatch(n) &&
        !RegExp(r'(?:سكري|ضغط|ربو)').hasMatch(n);
  }

  bool looksLikeFearOnly(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(r'(?:خايف|خوف|فزع)').hasMatch(n) &&
        !RegExp(r'(?:مشخص|مشخّص|تذكر|احفظ)').hasMatch(n);
  }

  static const _conditionDefs = <_CondDef>[
    _CondDef(
      key: 'diabetes',
      display: 'السكري',
      mentioned: r'(?:سكري|السكري|سكر\s*الدم)',
      cue: r'(?:سكري|السكري|سكر\s*الدم)',
    ),
    _CondDef(
      key: 'hypertension',
      display: 'ارتفاع ضغط الدم',
      mentioned: r'(?:ضغط|ارتفاع\s*ضغط)',
      cue: r'(?:ضغط|ارتفاع\s*ضغط)',
    ),
    _CondDef(
      key: 'asthma',
      display: 'الربو',
      mentioned: r'(?:ربو|الربو)',
      cue: r'(?:ربو|الربو)',
    ),
  ];

  String _stripNonDiagnosisNoise(String raw) {
    var t = raw;
    t = t.replaceAll(
      RegExp(r'(?:و)?(?:سكره|سكر|ضغطه|الضغط)\s*(?:اليوم|هسه)?\s*\d{2,3}'),
      '',
    );
    t = t.replaceAll(RegExp(r'(?:و)?(?:ياخذ|يأخذ)\s+\S+'), '');
    t = t.replaceAll(RegExp(r'(?:و)?(?:خايف|خوف).{0,24}'), '');
    return t.trim();
  }

  bool _hasUncertainty(String n) => RegExp(
        r'(?:يمكن|ممكن|اشك|أشك|يبدو|احتمال|ما\s*ادري|أحس|احس)',
      ).hasMatch(n);

  bool _uncertainNear(String n, String conditionPat) => RegExp(
        '(?:يمكن|ممكن|اشك|أحس|احس|يبدو)\\s+(?:عنده|عندها|ان|أن)?\\s*$conditionPat|'
        '(?:يمكن|ممكن|اشك|أحس|احس|يبدو)\\s+$conditionPat',
      ).hasMatch(n);

  bool _hasAnyDiagnosedCue(String n) => RegExp(
        r'(?:مشخص|مشخّص|مثبت|الطبيب\s*قال|الدكتور\s*قال)',
      ).hasMatch(n);

  bool _diagnosedCueFor(String n, String cue) => RegExp(
        '(?:مشخص|مشخّص|مثبت).{0,24}$cue|$cue.{0,24}(?:مشخص|مشخّص|مثبت)|'
        '(?:الطبيب|الدكتور).{0,24}$cue',
      ).hasMatch(n);

  List<String> _mentionedKeys(String n) {
    final out = <String>[];
    for (final d in _conditionDefs) {
      if (RegExp(d.mentioned).hasMatch(n)) out.add(d.key);
    }
    return out;
  }
}

class _CondDef {
  const _CondDef({
    required this.key,
    required this.display,
    required this.mentioned,
    required this.cue,
  });
  final String key;
  final String display;
  final String mentioned;
  final String cue;
}

class FamilyHealthQualificationResult {
  const FamilyHealthQualificationResult({
    required this.eligible,
    this.ineligibleMentionedKeys = const [],
    this.mixedEstablishedAndUncertain = false,
    this.ineligibleStatus,
  });

  final List<HealthConditionCandidate> eligible;
  final List<String> ineligibleMentionedKeys;
  final bool mixedEstablishedAndUncertain;
  final HealthDiagnosisStatus? ineligibleStatus;

  bool get hasEligible => eligible.isNotEmpty;
}
