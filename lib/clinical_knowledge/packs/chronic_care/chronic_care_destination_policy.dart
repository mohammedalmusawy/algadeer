import '../../clinical_knowledge_models.dart';
import 'chronic_care_models.dart';
import 'diabetes_rule_catalog.dart';
import 'hypertension_rule_catalog.dart';

/// مجمّع خطة رعاية — أولوية سلامة ثم ≤3 عناصر افتراضياً.
class ChronicCarePlanAssembler {
  const ChronicCarePlanAssembler();

  List<AssembledCarePriority> assemble({
    required ChronicClinicalSession session,
    required DiabetesRuleCatalog diabetesRules,
    required HypertensionRuleCatalog htnRules,
    bool fullChecklist = false,
    bool footWound = false,
    bool safetyFirst = false,
  }) {
    final out = <AssembledCarePriority>[];

    if (safetyFirst || session.redFlagCandidate) {
      out.add(const AssembledCarePriority(
        id: 'safety',
        status: CareItemStatus.needsClinicianReview,
        arabicLabel: 'تقييم عاجل/سلامة أولاً',
        reasonCode: 'safetyFirst',
      ));
    }

    if (footWound && session.hasEstablishedDiabetes) {
      out.add(AssembledCarePriority(
        id: DiabetesCareItem.footAssessment.name,
        status: CareItemStatus.needsClinicianReview,
        arabicLabel: 'مراجعة القدم/الجرح مع مختص',
        reasonCode: 'footWound',
        matchedRuleId: 'dm_foot_evaluation_ada2026',
      ));
    }

    if (session.hasEstablishedDiabetes) {
      _addDm(out, session, diabetesRules, fullChecklist);
    }
    if (session.hasEstablishedHypertension) {
      _addHtn(out, session, htnRules, fullChecklist);
    }

    // إزالة تكرار نصائح نمط الحياة
    final seen = <String>{};
    final deduped = <AssembledCarePriority>[];
    for (final p in out) {
      final key = p.id == DiabetesCareItem.lifestyleReview.name ||
              p.id == HypertensionCareItem.lifestyleReview.name
          ? 'lifestyle'
          : p.id;
      if (seen.add(key)) deduped.add(p);
    }

    if (fullChecklist) return deduped;
    return deduped.take(3).toList(growable: false);
  }

  void _addDm(
    List<AssembledCarePriority> out,
    ChronicClinicalSession session,
    DiabetesRuleCatalog rules,
    bool full,
  ) {
    final completed = session.completedCareItems.toSet();

    void add(DiabetesCareItem item, CareItemStatus status, String label) {
      if (completed.contains(item.name) &&
          status != CareItemStatus.needsClinicianReview) {
        if (full) {
          out.add(AssembledCarePriority(
            id: item.name,
            status: CareItemStatus.recentlyCompleted,
            arabicLabel: '$label (مكتمل/حديث حسب ما ذكرت)',
            matchedRuleId: rules.forCareItem(item)?.ruleId,
          ));
        }
        return;
      }
      final st = completed.contains(item.name)
          ? CareItemStatus.recentlyCompleted
          : (session.unknownCareItems.contains(item.name)
              ? CareItemStatus.unknown
              : status);
      out.add(AssembledCarePriority(
        id: item.name,
        status: st,
        arabicLabel: label,
        matchedRuleId: rules.forCareItem(item)?.ruleId,
      ));
    }

    add(
      DiabetesCareItem.glycemicAssessment,
      CareItemStatus.unknown,
      'تقييم السكر/التراكمي',
    );
    add(
      DiabetesCareItem.kidneyAssessment,
      CareItemStatus.unknown,
      'فحص الكلى (UACR و eGFR)',
    );
    add(
      DiabetesCareItem.eyeAssessment,
      CareItemStatus.unknown,
      'فحص العين',
    );
    if (full) {
      add(DiabetesCareItem.footAssessment, CareItemStatus.unknown, 'تقييم القدم');
      add(DiabetesCareItem.lipidAssessment, CareItemStatus.unknown, 'تقييم الدهون');
      add(
        DiabetesCareItem.lifestyleReview,
        CareItemStatus.notYetDue,
        'نمط حياة داعم',
      );
      add(
        DiabetesCareItem.dentalReview,
        CareItemStatus.unknown,
        'مراجعة أسنان عند المناسبة',
      );
      add(
        DiabetesCareItem.vaccinationReview,
        CareItemStatus.unknown,
        'مراجعة تطعيمات مع الطبيب (بلا توفر محلي مخترع)',
      );
    } else {
      add(
        DiabetesCareItem.lifestyleReview,
        CareItemStatus.notYetDue,
        'نشاط وتغذية متوازنة — بلا خطة وجبات صارمة',
      );
    }
  }

  void _addHtn(
    List<AssembledCarePriority> out,
    ChronicClinicalSession session,
    HypertensionRuleCatalog rules,
    bool full,
  ) {
    out.add(AssembledCarePriority(
      id: HypertensionCareItem.measurementQuality.name,
      status: CareItemStatus.notYetDue,
      arabicLabel: 'جودة قياس الضغط المنزلي',
      matchedRuleId: rules.findById('htn_home_measurement_technique')?.ruleId,
    ));
    out.add(AssembledCarePriority(
      id: HypertensionCareItem.bloodPressureGoalDiscussion.name,
      status: CareItemStatus.needsClinicianReview,
      arabicLabel: 'مناقشة هدف الضغط مع طبيبك (ليس هدفاً موحّداً)',
      matchedRuleId: rules.findById('htn_classification_aha_acc_2025')?.ruleId,
    ));
    if (full) {
      out.add(const AssembledCarePriority(
        id: 'htn_lifestyle',
        status: CareItemStatus.notYetDue,
        arabicLabel: 'نمط حياة داعم للضغط',
      ));
    }
  }
}

class ChronicCareDestinationPolicy {
  const ChronicCareDestinationPolicy();

  ClinicalCareDestination? forCareItem(String careItemId) {
    if (careItemId == DiabetesCareItem.eyeAssessment.name) {
      return ClinicalCareDestination.specialist; // ophthalmology semantic
    }
    if (careItemId == DiabetesCareItem.kidneyAssessment.name ||
        careItemId == DiabetesCareItem.glycemicAssessment.name ||
        careItemId == DiabetesCareItem.lipidAssessment.name) {
      return ClinicalCareDestination.laboratory;
    }
    if (careItemId == DiabetesCareItem.dentalReview.name) {
      return ClinicalCareDestination.dentist;
    }
    if (careItemId == 'safety') return ClinicalCareDestination.emergency;
    return ClinicalCareDestination.generalPractitioner;
  }

  bool hardcodesProviderNames() => false;
  bool hardcodesPackageIds() => false;
}
