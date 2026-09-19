import 'chronic_care_due_policy.dart';
import 'chronic_care_models.dart';
import 'diabetes_rule_catalog.dart';

/// سياسة رعاية سكري — تستهلك الكتالوج؛ بلا محرك مرض منفصل.
class DiabetesCarePolicy {
  DiabetesCarePolicy({
    DiabetesRuleCatalog? catalog,
    ChronicCareDuePolicy? due,
  })  : catalog = catalog ?? DiabetesRuleCatalog(),
        due = due ?? ChronicCareDuePolicy();

  final DiabetesRuleCatalog catalog;
  final ChronicCareDuePolicy due;

  bool insulinInfersType1() => false;
  bool diagnosesFromSingleGlucose() => false;
  bool universalPersonalA1cTarget() => false;
  bool initiatesStatin() => false;
  bool adjustsInsulinDose() => false;
  bool numbnessDiagnosesNeuropathy() => false;
  bool footWoundAutoXray() => false;
  bool diabetesAloneChestXray() => false;
  bool inventsAscvdPercent() => false;

  String? explainCareItem(DiabetesCareItem item) =>
      catalog.forCareItem(item)?.arabicGuidance;
}
