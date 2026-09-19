import 'chronic_care_models.dart';
import 'diabetes_rule_catalog.dart';
import 'hypertension_rule_catalog.dart';

/// سياسة استحقاق عناصر الرعاية — UNKNOWN ≠ OVERDUE.
class ChronicCareDuePolicy {
  ChronicCareDuePolicy({
    DiabetesRuleCatalog? diabetes,
    HypertensionRuleCatalog? hypertension,
  })  : diabetes = diabetes ?? DiabetesRuleCatalog(),
        hypertension = hypertension ?? HypertensionRuleCatalog();

  final DiabetesRuleCatalog diabetes;
  final HypertensionRuleCatalog hypertension;

  CareItemStatus statusFor({
    required String careItemId,
    required bool recentlyCompleted,
    required bool dateKnown,
    required bool evidenceSupportsDue,
    required bool needsClinician,
  }) {
    if (needsClinician) return CareItemStatus.needsClinicianReview;
    if (recentlyCompleted) return CareItemStatus.recentlyCompleted;
    if (!dateKnown) return CareItemStatus.unknown;
    if (evidenceSupportsDue) return CareItemStatus.due;
    return CareItemStatus.notYetDue;
  }

  bool type1KidneyEligible({
    required DiabetesTypeContext type,
    required int? durationYearsKnown,
  }) {
    final rule = diabetes.forCareItem(DiabetesCareItem.kidneyAssessment);
    final minYears = rule?.type1MinDurationYears ??
        DiabetesRuleCatalog.type1KidneyScreenMinYears;
    if (type != DiabetesTypeContext.type1) return true;
    if (durationYearsKnown == null) return false;
    return durationYearsKnown >= minYears;
  }

  bool hba1cDueSuggested({required bool unstableContext}) {
    final rule = diabetes.forCareItem(DiabetesCareItem.glycemicAssessment);
    return (unstableContext
            ? rule?.intervalMonthsUnstable
            : rule?.intervalMonthsStable) !=
        null;
  }

  bool bpReadingElevated(int? sys, int? dia) {
    final rule = hypertension.findById('htn_classification_aha_acc_2025');
    final sTh = rule?.systolicElevatedThreshold ??
        HypertensionRuleCatalog.systolicElevated;
    final dTh = rule?.diastolicElevatedThreshold ??
        HypertensionRuleCatalog.diastolicElevated;
    if (sys == null || dia == null) return false;
    return sys >= sTh || dia >= dTh;
  }

  bool bpSevereConcern(int? sys) {
    final rule = hypertension.findById('htn_classification_aha_acc_2025');
    final th = rule?.systolicSevereThreshold ??
        HypertensionRuleCatalog.systolicSevereConcern;
    return sys != null && sys >= th;
  }

  bool commercialCanAlterEligibility() => false;
  bool packageCanCreateMedicalNeed() => false;
  bool sponsorCanAlterEligibility() => false;
  bool discountCanAlterFrequency() => false;
}
