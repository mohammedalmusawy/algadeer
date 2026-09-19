import '../../clinical_knowledge/clinical_knowledge_models.dart';
import 'adolescent_models.dart';

/// حدود عمرية وعتبات رقمية — ملكية الكتالوج فقط (WHO adolescence 10–19).
class AdolescentEvidenceRule {
  const AdolescentEvidenceRule({
    required this.ruleId,
    required this.topic,
    required this.evidence,
    required this.reviewedAt,
    required this.freshness,
    required this.clinicalReviewRequired,
    required this.isActive,
    this.arabicGuidance = '',
    this.priority = 50,
  });

  final String ruleId;
  final AdolescentTopic topic;
  final ClinicalEvidenceReference evidence;
  final DateTime reviewedAt;
  final ClinicalEvidenceFreshness freshness;
  final bool clinicalReviewRequired;
  final bool isActive;
  final String arabicGuidance;
  final int priority;

  bool get hasEvidenceMetadata =>
      evidence.sourceOrganization.isNotEmpty &&
      evidence.sourceReference.isNotEmpty;
}

class AdolescentEvidenceCatalog {
  AdolescentEvidenceCatalog({List<AdolescentEvidenceRule>? rules})
      : _rules = rules ?? activeRules;

  final List<AdolescentEvidenceRule> _rules;
  static final DateTime _reviewed = DateTime(2026, 3, 1);

  static const int adolescenceMinAgeInclusive = 10;
  static const int adolescenceMaxAgeInclusive = 19;
  static const int recommendedSleepHoursMin = 8;
  static const int recommendedSleepHoursMax = 10;
  static const int activityMinutesPerDayApprox = 60;

  static bool isAdolescentAge(int? years) {
    if (years == null) return false;
    return years >= adolescenceMinAgeInclusive &&
        years <= adolescenceMaxAgeInclusive;
  }

  static bool isYoungerChildAge(int? years) {
    if (years == null) return false;
    return years > 0 && years < adolescenceMinAgeInclusive;
  }

  static bool isAdultAge(int? years) {
    if (years == null) return false;
    return years > adolescenceMaxAgeInclusive;
  }

  static final List<AdolescentEvidenceRule> activeRules = [
    AdolescentEvidenceRule(
      ruleId: 'ado_who_age_boundary_10_19',
      topic: AdolescentTopic.generalAdolescentHealth,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Adolescent health — ages 10 to 19',
        sourceReference: 'WHO adolescent health overview',
        sourceVersionOrDate: 'WHO',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 99,
      arabicGuidance:
          'المراهقة مرحلة نمائية (تقريباً 10–19 حسب منظمة الصحة العالمية) وليست تشخيصاً. '
          'لا نستنتج العمر من الاسم أو الأسلوب.',
    ),
    AdolescentEvidenceRule(
      ruleId: 'ado_who_sleep_wellbeing',
      topic: AdolescentTopic.sleepRoutine,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Adolescent sleep and wellbeing context',
        sourceReference: 'WHO adolescent health / sleep wellbeing principles',
        sourceVersionOrDate: 'WHO',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 90,
      arabicGuidance:
          'النوم المنتظم مهم للمراهقين. كثيرون يحتاجون تقريباً 8–10 ساعات حسب الدليل العام — '
          'بلا تشخيص أرق وبلا توبيخ على السهر.',
    ),
    AdolescentEvidenceRule(
      ruleId: 'ado_who_activity',
      topic: AdolescentTopic.physicalActivity,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Physical activity for adolescents',
        sourceReference: 'WHO physical activity guidelines — children/adolescents',
        sourceVersionOrDate: 'WHO PA',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 88,
      arabicGuidance:
          'الحركة اليومية مفيدة للمراهقين (تقريباً نحو ساعة نشاط متوسط إلى قوي يومياً حسب الدليل العام). '
          'سلطة النشاط تبقى PC-1.14 — بلا هدف 10 آلاف خطوة.',
    ),
    AdolescentEvidenceRule(
      ruleId: 'ado_study_stress_support',
      topic: AdolescentTopic.examStress,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Adolescent mental wellbeing — non-diagnostic support',
        sourceReference: 'WHO adolescent mental health / wellbeing principles',
        sourceVersionOrDate: 'WHO',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 85,
      arabicGuidance:
          'ضغط الامتحان شائع كملاحظة. نساعد بخطوة صغيرة عملية — بدون لصق تسمية طبية من المحادثة.',
    ),
    AdolescentEvidenceRule(
      ruleId: 'ado_body_image_safe',
      topic: AdolescentTopic.bodyImageConcern,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Adolescent body image — non-shaming support',
        sourceReference: 'WHO adolescent wellbeing / nutrition principles',
        sourceVersionOrDate: 'WHO',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 87,
      arabicGuidance:
          'عدم الرضا عن الشكل يستحق احتراماً. بلا خجل من الوزن، بلا حمية قاسية، بلا حبوب تخسيس، '
          'وبلا خطط إنقاص وزن شخصية من هنا.',
    ),
    AdolescentEvidenceRule(
      ruleId: 'ado_bullying_support',
      topic: AdolescentTopic.bullying,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Bullying and adolescent safety — trusted support',
        sourceReference: 'WHO adolescent violence / bullying prevention principles',
        sourceVersionOrDate: 'WHO',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 92,
      arabicGuidance:
          'التنمر المتكرر يختلف عن خلاف مرة واحدة. السلامة أولاً؛ بالغ موثوق/دعم مدرسي عند الحاجة — '
          'بلا دفع للرد الجسدي.',
    ),
    AdolescentEvidenceRule(
      ruleId: 'ado_puberty_education',
      topic: AdolescentTopic.generalPubertyEducation,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Puberty — general adolescent education',
        sourceReference: 'WHO adolescent sexual/reproductive health education principles',
        sourceVersionOrDate: 'WHO',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 80,
      arabicGuidance:
          'البلوغ مرحلة نمو طبيعية باختلافات فردية. الشرح تعليمي عام — بلا تشخيص تأخر/بكور، '
          'وبلا استنتاج جنس من الاسم.',
    ),
    AdolescentEvidenceRule(
      ruleId: 'ado_incomplete_inactive',
      topic: AdolescentTopic.unknown,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'pending',
        sourceTitle: 'placeholder',
        sourceReference: 'pending',
        sourceVersionOrDate: 'pending',
        evidenceType: ClinicalEvidenceType.other,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.reviewDue,
      clinicalReviewRequired: true,
      isActive: false,
      priority: 1,
      arabicGuidance: 'غير نشطة',
    ),
  ];

  List<AdolescentEvidenceRule> get all => List.unmodifiable(_rules);
  List<AdolescentEvidenceRule> get active =>
      _rules.where((r) => r.isActive).toList(growable: false);

  AdolescentEvidenceRule? findById(String id) {
    for (final r in _rules) {
      if (r.ruleId == id) return r;
    }
    return null;
  }

  AdolescentEvidenceRule? forTopic(AdolescentTopic topic) {
    for (final r in active) {
      if (r.topic == topic) return r;
    }
    return null;
  }
}
