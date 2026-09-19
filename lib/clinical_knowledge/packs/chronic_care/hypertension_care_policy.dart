import 'chronic_care_due_policy.dart';
import 'hypertension_rule_catalog.dart';

/// سياسة رعاية ضغط — تستهلك الكتالوج؛ بلا محرك مرض منفصل.
class HypertensionCarePolicy {
  HypertensionCarePolicy({
    HypertensionRuleCatalog? catalog,
    ChronicCareDuePolicy? due,
  })  : catalog = catalog ?? HypertensionRuleCatalog(),
        due = due ?? ChronicCareDuePolicy();

  final HypertensionRuleCatalog catalog;
  final ChronicCareDuePolicy due;

  bool singleReadingEstablishesHypertension() => false;
  bool universalPersonalBpTarget() => false;
  bool adjustsAntihypertensiveDose() => false;
  bool hypertensionAloneChestXray() => false;
  bool cufflessEqualsValidatedCuff() => false;
  bool thresholdsLiveInCatalogOnly() => true;
}
