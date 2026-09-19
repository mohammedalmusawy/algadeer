import '../../search/arabic_text_utils.dart';
import 'sensitive_health_profile_models.dart';

/// تأهيل حالات صحية للحفظ — حتمي، بلا AI.
class HealthConditionQualifier {
  const HealthConditionQualifier();

  /// يستخرج مرشّحين مؤهّلين فقط (مشخّص / ثابت صريح).
  List<HealthConditionCandidate> extractEligibleCandidates(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return const [];

    // عدم اليقين / شك → لا أهلية
    if (_isUncertain(n)) return const [];

    // ملاحظة سكر مرتفع اليوم → ليست تشخيصاً
    if (_isObservationNotDiagnosis(n)) return const [];

    // أعراض فقط
    if (_isSymptomOnly(n) && !_hasConditionKeyword(n)) return const [];

    final diagnosed = _hasClinicianAttribution(n);
    final establishedSelf = _hasEstablishedSelfReport(n);
    final remember = _hasRememberCommand(n);

    // أهلية الحفظ: تشخيص / ثبات صريح / أمر تذكّر صريح فقط.
    if (!diagnosed && !establishedSelf && !remember) {
      return const [];
    }

    final out = <HealthConditionCandidate>[];

    void add(String key, String display) {
      if (out.any((c) => c.canonicalConditionKey == key)) return;
      out.add(
        HealthConditionCandidate(
          canonicalConditionKey: key,
          displayName: display,
          diagnosisStatus: diagnosed
              ? HealthDiagnosisStatus.diagnosed
              : HealthDiagnosisStatus.userReportedEstablished,
          diagnosisSource: diagnosed
              ? HealthDiagnosisSource.clinicianAttributed
              : HealthDiagnosisSource.selfReported,
          approximateSince: _parseSince(n),
        ),
      );
    }

    if (RegExp(r'(?:سكري|السكري|سكر\s*الدم|diabetes)').hasMatch(n) &&
        !_isGlucoseObservation(n)) {
      add(HealthCanonicalConditionKey.diabetes.name, 'السكري');
    }
    if (RegExp(r'(?:ضغط|ارتفاع\s*ضغط|ضغط\s*الدم|hypertension)').hasMatch(n)) {
      add(HealthCanonicalConditionKey.hypertension.name, 'ارتفاع ضغط الدم');
    }
    if (RegExp(r'(?:ربو|الربو|asthma)').hasMatch(n)) {
      add(HealthCanonicalConditionKey.asthma.name, 'الربو');
    }

    return List.unmodifiable(out);
  }

  /// تصنيف جملة غير مؤهّلة — للرسائل.
  HealthDiagnosisStatus classifyIneligible(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (_isUncertain(n)) return HealthDiagnosisStatus.uncertain;
    if (_isSymptomOnly(n) || _isObservationNotDiagnosis(n)) {
      return HealthDiagnosisStatus.symptomOnly;
    }
    return HealthDiagnosisStatus.uncertain;
  }

  bool _isUncertain(String n) => RegExp(
        r'(?:يمكن|ممكن|اشك|أشك|يبدو|احتمال|ما\s*ادري|لعله|لعله)',
      ).hasMatch(n);

  bool _isObservationNotDiagnosis(String n) =>
      _isGlucoseObservation(n) ||
      RegExp(r'(?:اليوم|هسه|حاليا)\s*.*(?:مرتفع|عالي|نازل)').hasMatch(n);

  bool _isGlucoseObservation(String n) => RegExp(
        r'(?:السكر|سكر)\s*(?:عندي\s*)?(?:مرتفع|عالي|نازل|واطي)|'
        r'(?:قياس|قراءه|قراءة)\s*(?:السكر|الضغط)',
      ).hasMatch(n);

  bool _isSymptomOnly(String n) => RegExp(
        r'(?:صداع|راسي\s*يوجع|الم\s*راس|وجع\s*راس|كحه|سعال|حراره|حمى|'
        r'متوتر|خايف|حزين|مضغوط|قلقان)',
      ).hasMatch(n);

  bool _hasConditionKeyword(String n) => RegExp(
        r'(?:سكري|ضغط|ربو)',
      ).hasMatch(n);

  bool _hasClinicianAttribution(String n) => RegExp(
        r'(?:مشخص|مشخّص|شخصني|شخصها|الطبيب\s*قال|الدكتور\s*قال|'
        r'مشخصني\s*(?:الطبيب|الدكتور)|شخصني\s*(?:الطبيب|الدكتور)|'
        r'مشخصين|مشخصهن|مشخّصين)',
      ).hasMatch(n);

  bool _hasEstablishedSelfReport(String n) => RegExp(
        r'(?:من\s*(?:\d+|خمس|عشر|سنين|سنه|سنة)|عندي\s*(?:سكري|ضغط|ربو)\s*من)',
      ).hasMatch(n);

  bool _hasRememberCommand(String n) => RegExp(
        r'(?:تذكر|تذكّر|احفظ)\s*(?:ان|أن)?',
      ).hasMatch(n);

  String? _parseSince(String n) {
    final m = RegExp(r'من\s+(\S+\s+\S+|\S+)').firstMatch(n);
    return m?.group(1);
  }
}
