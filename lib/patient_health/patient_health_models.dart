class PatientAccessDenied implements Exception {
  const PatientAccessDenied();
}

/// سجل المريض نفسه. لا يُفسَّر كتشخيص من الغدير.
enum ConditionKind { hypertension, diabetes, thalassemia, other }

enum GlucoseTiming { fasting, afterMeal, random }

enum GlucoseUnit { mgDl, mmolL }

enum ThalassemiaEventKind { appointment, transfusion, labResult }

enum FollowUpPeriod { days7, days30, days90, all }

class PatientHealthProfile {
  const PatientHealthProfile({
    required this.userId,
    required this.displayName,
    required this.consentAt,
  });

  final String userId;
  final String displayName;
  final DateTime consentAt;

  PatientHealthProfile copyWith({String? displayName, DateTime? consentAt}) {
    return PatientHealthProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      consentAt: consentAt ?? this.consentAt,
    );
  }
}

class PatientCondition {
  const PatientCondition({
    required this.id,
    required this.userId,
    required this.kind,
    this.label = '',
    this.thalassemiaType = '',
    this.prescribedTreatment = '',
    this.reviewsNote = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final ConditionKind kind;
  final String label;
  final String thalassemiaType;
  final String prescribedTreatment;
  final String reviewsNote;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get title {
    final named = label.trim();
    if (named.isNotEmpty) return named;
    return conditionKindLabel(kind);
  }

  PatientCondition copyWith({
    String? label,
    String? thalassemiaType,
    String? prescribedTreatment,
    String? reviewsNote,
    String? notes,
    DateTime? updatedAt,
  }) {
    return PatientCondition(
      id: id,
      userId: userId,
      kind: kind,
      label: label ?? this.label,
      thalassemiaType: thalassemiaType ?? this.thalassemiaType,
      prescribedTreatment: prescribedTreatment ?? this.prescribedTreatment,
      reviewsNote: reviewsNote ?? this.reviewsNote,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BpReading {
  const BpReading({
    required this.id,
    required this.userId,
    required this.conditionId,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    required this.measuredAt,
  });

  final String id;
  final String userId;
  final String conditionId;
  final int systolic;
  final int diastolic;
  final int? pulse;
  final DateTime measuredAt;
}

class GlucoseReading {
  const GlucoseReading({
    required this.id,
    required this.userId,
    required this.conditionId,
    required this.value,
    required this.unit,
    required this.timing,
    required this.measuredAt,
  });

  final String id;
  final String userId;
  final String conditionId;
  final double value;
  final GlucoseUnit unit;
  final GlucoseTiming timing;
  final DateTime measuredAt;
}

class ThalassemiaEvent {
  const ThalassemiaEvent({
    required this.id,
    required this.userId,
    required this.conditionId,
    required this.kind,
    required this.title,
    this.details = '',
    required this.occurredAt,
  });

  final String id;
  final String userId;
  final String conditionId;
  final ThalassemiaEventKind kind;
  final String title;
  final String details;
  final DateTime occurredAt;
}

class HealthAttachment {
  const HealthAttachment({
    required this.id,
    required this.userId,
    required this.conditionId,
    required this.storagePath,
    required this.fileName,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String conditionId;
  final String storagePath;
  final String fileName;
  final DateTime createdAt;
}

class PatientHealthSnapshot {
  const PatientHealthSnapshot({
    this.profile,
    this.conditions = const [],
    this.bpReadings = const [],
    this.glucoseReadings = const [],
    this.events = const [],
    this.attachments = const [],
  });

  final PatientHealthProfile? profile;
  final List<PatientCondition> conditions;
  final List<BpReading> bpReadings;
  final List<GlucoseReading> glucoseReadings;
  final List<ThalassemiaEvent> events;
  final List<HealthAttachment> attachments;
}

class FollowUpSelection {
  const FollowUpSelection({
    required this.conditionId,
    required this.period,
    required this.issuedAt,
    this.includeMeasurements = true,
    this.includeTreatment = false,
    this.includeReviews = false,
    this.includeNotes = false,
    this.includeEvents = true,
    this.showName = false,
  });

  final String conditionId;
  final FollowUpPeriod period;
  final DateTime issuedAt;
  final bool includeMeasurements;
  final bool includeTreatment;
  final bool includeReviews;
  final bool includeNotes;
  final bool includeEvents;
  final bool showName;

  DateTime? get periodStart {
    switch (period) {
      case FollowUpPeriod.days7:
        return issuedAt.subtract(const Duration(days: 7));
      case FollowUpPeriod.days30:
        return issuedAt.subtract(const Duration(days: 30));
      case FollowUpPeriod.days90:
        return issuedAt.subtract(const Duration(days: 90));
      case FollowUpPeriod.all:
        return null;
    }
  }
}

class FollowUpLine {
  const FollowUpLine({required this.title, required this.detail});

  final String title;
  final String detail;
}

/// صف قراءة منظم لجدول بطاقة المتابعة / PDF.
class FollowUpReadingRow {
  const FollowUpReadingRow({
    required this.dateTimeLabel,
    required this.valueLabel,
    required this.unitLabel,
    required this.kindLabel,
    this.note = '',
  });

  final String dateTimeLabel;
  final String valueLabel;
  final String unitLabel;
  final String kindLabel;
  final String note;
}

class FollowUpCardContent {
  const FollowUpCardContent({
    required this.conditionTitle,
    required this.patientName,
    this.lines = const [],
    required this.issuedAt,
    this.emptyNote = '',
    this.readings = const [],
  });

  final String conditionTitle;
  final String? patientName;
  final List<FollowUpLine> lines;
  final List<FollowUpReadingRow> readings;
  final DateTime issuedAt;
  final String emptyNote;
}

const patientEnteredBanner =
    'هذي المعلومات أنت دخلتها بنفسك. مو تشخيص من الغدير، '
    'وما تنرسل للطبيب أو الإدارة إلا إذا صدّرت البطاقة بيدك.';

const patientShareNotice =
    'هالنسخة تطلع من جهازك بفعلك. بعد ما توصل الصورة أو ملف PDF للمستلم '
    'ما نكدر نسحبها من جهازه، وما ينشأ رابط عام داخل الغدير.';

const patientDataAttribution = 'بيانات أدخلها المريض';

String conditionKindLabel(ConditionKind kind) {
  switch (kind) {
    case ConditionKind.hypertension:
      return 'الضغط';
    case ConditionKind.diabetes:
      return 'السكري';
    case ConditionKind.thalassemia:
      return 'الثلاسيميا';
    case ConditionKind.other:
      return 'مرض مزمن آخر';
  }
}

String glucoseTimingLabel(GlucoseTiming timing) {
  switch (timing) {
    case GlucoseTiming.fasting:
      return 'صائم';
    case GlucoseTiming.afterMeal:
      return 'بعد الأكل';
    case GlucoseTiming.random:
      return 'عشوائي';
  }
}

String glucoseUnitLabel(GlucoseUnit unit) {
  switch (unit) {
    case GlucoseUnit.mgDl:
      return 'ملغ/دل (mg/dL)';
    case GlucoseUnit.mmolL:
      return 'مليمول/لتر (mmol/L)';
  }
}

String thalassemiaEventLabel(ThalassemiaEventKind kind) {
  switch (kind) {
    case ThalassemiaEventKind.appointment:
      return 'موعد';
    case ThalassemiaEventKind.transfusion:
      return 'نقل دم';
    case ThalassemiaEventKind.labResult:
      return 'نتيجة تحليل';
  }
}

String followUpPeriodLabel(FollowUpPeriod period) {
  switch (period) {
    case FollowUpPeriod.days7:
      return 'آخر 7 أيام';
    case FollowUpPeriod.days30:
      return 'آخر شهر';
    case FollowUpPeriod.days90:
      return 'آخر 3 أشهر';
    case FollowUpPeriod.all:
      return 'كل السجل';
  }
}

String formatHealthStamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String? kindToDb(ConditionKind kind) {
  switch (kind) {
    case ConditionKind.hypertension:
      return 'hypertension';
    case ConditionKind.diabetes:
      return 'diabetes';
    case ConditionKind.thalassemia:
      return 'thalassemia';
    case ConditionKind.other:
      return 'other';
  }
}

ConditionKind kindFromDb(String raw) {
  switch (raw) {
    case 'hypertension':
      return ConditionKind.hypertension;
    case 'diabetes':
      return ConditionKind.diabetes;
    case 'thalassemia':
      return ConditionKind.thalassemia;
    default:
      return ConditionKind.other;
  }
}

String timingToDb(GlucoseTiming timing) {
  switch (timing) {
    case GlucoseTiming.fasting:
      return 'fasting';
    case GlucoseTiming.afterMeal:
      return 'after_meal';
    case GlucoseTiming.random:
      return 'random';
  }
}

GlucoseTiming timingFromDb(String raw) {
  switch (raw) {
    case 'fasting':
      return GlucoseTiming.fasting;
    case 'after_meal':
      return GlucoseTiming.afterMeal;
    default:
      return GlucoseTiming.random;
  }
}

String unitToDb(GlucoseUnit unit) {
  switch (unit) {
    case GlucoseUnit.mgDl:
      return 'mg/dL';
    case GlucoseUnit.mmolL:
      return 'mmol/L';
  }
}

GlucoseUnit unitFromDb(String raw) {
  if (raw == 'mmol/L') return GlucoseUnit.mmolL;
  return GlucoseUnit.mgDl;
}

String eventKindToDb(ThalassemiaEventKind kind) {
  switch (kind) {
    case ThalassemiaEventKind.appointment:
      return 'appointment';
    case ThalassemiaEventKind.transfusion:
      return 'transfusion';
    case ThalassemiaEventKind.labResult:
      return 'lab_result';
  }
}

ThalassemiaEventKind eventKindFromDb(String raw) {
  switch (raw) {
    case 'appointment':
      return ThalassemiaEventKind.appointment;
    case 'transfusion':
      return ThalassemiaEventKind.transfusion;
    default:
      return ThalassemiaEventKind.labResult;
  }
}
