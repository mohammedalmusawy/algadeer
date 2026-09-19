import '../../../health/chronic_care/chronic_care.dart' as pc15;
import '../../../health/sensitive_profile/sensitive_health_profile_service.dart';

/// لقطة قراءة فقط لما تحتاجه حزمة PC-1.20 من سلطات PC-1.5 / الملف الحسّاس.
class ChronicCareClinicalSnapshot {
  const ChronicCareClinicalSnapshot({
    this.establishedDiabetes = false,
    this.establishedHypertension = false,
    this.diabetesMeasurementCount = 0,
    this.hypertensionMeasurementCount = 0,
    this.hasMultipleDiabetesMeasurements = false,
    this.hasMultipleHypertensionMeasurements = false,
    this.loadFailed = false,
    this.activeConditionKey,
  });

  final bool establishedDiabetes;
  final bool establishedHypertension;
  final int diabetesMeasurementCount;
  final int hypertensionMeasurementCount;
  final bool hasMultipleDiabetesMeasurements;
  final bool hasMultipleHypertensionMeasurements;
  final bool loadFailed;
  final String? activeConditionKey;

  static const empty = ChronicCareClinicalSnapshot();
  static const failed = ChronicCareClinicalSnapshot(loadFailed: true);
}

/// محوّل قراءة فقط — بلا حفظ/تشخيص/متابعة.
class ChronicCareQueryAdapter {
  ChronicCareQueryAdapter({
    pc15.ChronicCareRepository? repository,
    SensitiveHealthProfileService? profiles,
  })  : _repository = repository,
        _profiles = profiles;

  final pc15.ChronicCareRepository? _repository;
  final SensitiveHealthProfileService? _profiles;

  Future<ChronicCareClinicalSnapshot> loadSnapshot({
    pc15.ChronicCareSession? liveSession,
  }) async {
    try {
      var establishedDm = false;
      var establishedHtn = false;
      final profiles = _profiles;
      if (profiles != null) {
        final dm = await profiles.findCondition('diabetes');
        final htn = await profiles.findCondition('hypertension');
        establishedDm = dm?.isPersistableEstablished == true;
        establishedHtn = htn?.isPersistableEstablished == true;
      }

      var dmCount = 0;
      var htnCount = 0;
      final repo = _repository;
      if (repo != null) {
        final store = await repo.load();
        dmCount = store.measurements
            .where((m) => m.conditionKey == 'diabetes')
            .length;
        htnCount = store.measurements
            .where((m) => m.conditionKey == 'hypertension')
            .length;
      }

      return ChronicCareClinicalSnapshot(
        establishedDiabetes: establishedDm,
        establishedHypertension: establishedHtn,
        diabetesMeasurementCount: dmCount,
        hypertensionMeasurementCount: htnCount,
        hasMultipleDiabetesMeasurements: dmCount >= 2,
        hasMultipleHypertensionMeasurements: htnCount >= 2,
        activeConditionKey: liveSession?.activeConditionKey,
      );
    } catch (_) {
      return ChronicCareClinicalSnapshot.failed;
    }
  }

  bool get isReadOnly => true;
  bool createsMeasurementStore() => false;
  bool createsConditionStore() => false;
  bool createsFollowUpStore() => false;
  bool mutatesChronicCareStore() => false;
}
