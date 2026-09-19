import '../../search/arabic_text_utils.dart';
import 'chronic_care_date_parser.dart';
import 'chronic_care_models.dart';

enum ChronicCareInterpretKind {
  none,
  optInFollowUp,
  optOutFollowUp,
  permissionYes,
  permissionNo,
  permissionLater,
  skip,
  stopAskingForever,
  controlStatus,
  glucoseMeasurement,
  needsGlucoseContext,
  bpMeasurement,
  relativeTimingAnswer,
  doctorFollowUpMention,
  labFollowUpMention,
  showLastAbout,
  deleteLastMeasurement,
  deleteMeasurementsForCondition,
  rejectNonOwner,
  rejectMedicationAdvice,
  rejectSupplement,
  topicChangedUrgent,
}

class ChronicCareInterpretation {
  const ChronicCareInterpretation({
    required this.kind,
    this.conditionKey,
    this.controlStatus,
    this.glucoseValue,
    this.glucoseType,
    this.glucoseContext = ChronicMeasurementContext.unknown,
    this.systolic,
    this.diastolic,
    this.relativeTiming,
    this.exactDate,
    this.message = '',
  });

  final ChronicCareInterpretKind kind;
  final String? conditionKey;
  final ChronicUserControlStatus? controlStatus;
  final double? glucoseValue;
  final ChronicMeasurementType? glucoseType;
  final ChronicMeasurementContext glucoseContext;
  final double? systolic;
  final double? diastolic;
  final ChronicRelativeTiming? relativeTiming;
  final DateTime? exactDate;
  final String message;

  static const none = ChronicCareInterpretation(
    kind: ChronicCareInterpretKind.none,
  );
}

/// مفسّر إجابات/أوامر المتابعة المزمنة — حتمي.
class ChronicCareAnswerInterpreter {
  ChronicCareAnswerInterpreter({
    ChronicCareDateParser? dates,
  }) : _dates = dates ?? const ChronicCareDateParser();

  final ChronicCareDateParser _dates;

  ChronicCareInterpretation interpret({
    required String raw,
    required ChronicCareSession session,
  }) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (n.isEmpty) return ChronicCareInterpretation.none;

    if (RegExp(r'(?:ضاعف\s*الجرعه|ضاعف\s*الجرعة|وقف\s*العلاج|خذ\s*حبه\s*اضافيه|'
            r'خذ\s*حبة\s*إضافية)')
        .hasMatch(n)) {
      return const ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.rejectMedicationAdvice,
        message: 'ما أكدر أغيّر علاج أو جرعة. راجع طبيبك لهذا القرار.',
      );
    }
    if (RegExp(r'(?:اوميغا|أوميغا|فيتامين|عشبه|عشبة|مكمل)').hasMatch(n) &&
        RegExp(r'(?:خذ|استخدم|انصح|أحتاج|ابي)').hasMatch(n)) {
      return const ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.rejectSupplement,
        message: 'ما أنصح بمكملات من هنا. هذا يحتاج رأي طبي متخصص.',
      );
    }

    if (session.status == ChronicCareFlowStatus.awaitingPermissionAnswer ||
        session.status == ChronicCareFlowStatus.offeringFollowUpPermission) {
      if (_isYes(n)) {
        return const ChronicCareInterpretation(
          kind: ChronicCareInterpretKind.permissionYes,
        );
      }
      if (_isLater(n)) {
        return const ChronicCareInterpretation(
          kind: ChronicCareInterpretKind.permissionLater,
        );
      }
      if (_isNo(n)) {
        return const ChronicCareInterpretation(
          kind: ChronicCareInterpretKind.permissionNo,
        );
      }
    }

    final optIn = _parseOptIn(n);
    if (optIn != null) return optIn;
    final optOut = _parseOptOut(n);
    if (optOut != null) return optOut;

    if (RegExp(r'لا\s*تسالني\s*(?:عن\s*)?(?:السكر|الضغط)?\s*بعد').hasMatch(n) ||
        RegExp(r'لا\s*تسالني\s*بعد').hasMatch(n)) {
      final key = n.contains('ضغط')
          ? 'hypertension'
          : (n.contains('سكر')
              ? 'diabetes'
              : session.activeConditionKey);
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.stopAskingForever,
        conditionKey: key,
      );
    }

    if (RegExp(r'(?:شنو|ماذا)\s*اخر\s*شي\s*مسجل|متى\s*اخر\s*مره\s*سجلت')
        .hasMatch(n)) {
      final key = n.contains('ضغط')
          ? 'hypertension'
          : (n.contains('سكر') ? 'diabetes' : session.activeConditionKey);
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.showLastAbout,
        conditionKey: key,
      );
    }

    if (RegExp(r'امسح\s*اخر\s*قياس').hasMatch(n)) {
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.deleteLastMeasurement,
        conditionKey: session.activeConditionKey,
      );
    }
    if (RegExp(r'امسح\s*قياسات\s*الضغط').hasMatch(n)) {
      return const ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.deleteMeasurementsForCondition,
        conditionKey: 'hypertension',
      );
    }

    final bp = _parseBp(n);
    if (bp != null) return bp;

    final glucose = _parseGlucose(n, session);
    if (glucose != null) return glucose;

    if (session.awaitingMeasurementContext && session.draftGlucoseValue != null) {
      final ctx = _parseGlucoseContext(n);
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.glucoseMeasurement,
        conditionKey: 'diabetes',
        glucoseValue: session.draftGlucoseValue,
        glucoseType: ctx == ChronicMeasurementContext.fasting
            ? ChronicMeasurementType.fastingGlucose
            : (ctx == ChronicMeasurementContext.postMeal
                ? ChronicMeasurementType.postMealGlucose
                : ChronicMeasurementType.bloodGlucose),
        glucoseContext: ctx,
      );
    }

    final control = _parseControl(n, session.activeConditionKey);
    if (control != null) return control;

    if (RegExp(
      r'(?:راجعت\s*الطبيب|متابعة\s*عند\s*طبيب|عند\s*الطبيب|راجع(?:ت)?\s*دكتور)',
    ).hasMatch(n)) {
      final timing = _dates.parse(n);
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.doctorFollowUpMention,
        conditionKey: session.activeConditionKey ??
            (n.contains('ضغط') ? 'hypertension' : 'diabetes'),
        relativeTiming: timing.timing,
        exactDate: timing.exact,
      );
    }
    if (RegExp(
      r'(?:فحصت|فحص)\s*(?:السكر|الضغط|hba1c|تحليل)|'
      r'تحليل\s*مختبر|اخر\s*فحص',
    ).hasMatch(n)) {
      final timing = _dates.parse(n);
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.labFollowUpMention,
        conditionKey: session.activeConditionKey ??
            (n.contains('ضغط') ? 'hypertension' : 'diabetes'),
        relativeTiming: timing.timing,
        exactDate: timing.exact,
      );
    }

    if (session.pendingQuestion == ChronicCareQuestionKind.lastMeasurement ||
        session.pendingQuestion == ChronicCareQuestionKind.lastFollowUp) {
      final timing = _dates.parse(n);
      if (timing.timing != ChronicRelativeTiming.unknown) {
        return ChronicCareInterpretation(
          kind: ChronicCareInterpretKind.relativeTimingAnswer,
          conditionKey: session.activeConditionKey,
          relativeTiming: timing.timing,
          exactDate: timing.exact,
        );
      }
    }

    if (_isSkip(n)) {
      return const ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.skip,
      );
    }

    return ChronicCareInterpretation.none;
  }

  ChronicCareInterpretation? _parseOptIn(String n) {
    if (RegExp(
      r'(?:تابع\s*وياي|ذكرني\s*اتابع|يريد\s*الغدير\s*يتابع|اريد\s*الغدير\s*يتابع)',
    ).hasMatch(n)) {
      final key = n.contains('ضغط')
          ? 'hypertension'
          : (n.contains('سكر') ? 'diabetes' : null);
      if (key == null) return null;
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.optInFollowUp,
        conditionKey: key,
      );
    }
    return null;
  }

  ChronicCareInterpretation? _parseOptOut(String n) {
    if (RegExp(r'(?:لا\s*تابع|وقف\s*متابعه|وقف\s*متابعة)').hasMatch(n)) {
      final key = n.contains('ضغط')
          ? 'hypertension'
          : (n.contains('سكر') ? 'diabetes' : null);
      if (key == null) return null;
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.optOutFollowUp,
        conditionKey: key,
      );
    }
    return null;
  }

  ChronicCareInterpretation? _parseControl(String n, String? activeKey) {
    final aboutSugar = n.contains('سكر');
    final aboutBp = n.contains('ضغط');
    final key = aboutSugar
        ? 'diabetes'
        : (aboutBp ? 'hypertension' : activeKey);
    if (key == null) return null;

    if (RegExp(r'(?:مو\s*مضبوط|غير\s*مضبوط|طالع|مرتفع\s*دائما)').hasMatch(n) &&
        (aboutSugar || aboutBp || activeKey != null)) {
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.controlStatus,
        conditionKey: key,
        controlStatus: ChronicUserControlStatus.userReportsNotControlled,
      );
    }
    if (RegExp(r'(?:متقلب|يوم\s*ويوم|يتغير)').hasMatch(n)) {
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.controlStatus,
        conditionKey: key,
        controlStatus: ChronicUserControlStatus.userReportsVariable,
      );
    }
    if (RegExp(r'(?:مضبوط|منضبط|زين|تمام)').hasMatch(n) &&
        (aboutSugar || aboutBp || activeKey != null)) {
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.controlStatus,
        conditionKey: key,
        controlStatus: ChronicUserControlStatus.userReportsControlled,
      );
    }
    return null;
  }

  ChronicCareInterpretation? _parseBp(String n) {
    // بعد التطبيع: على → علي
    final m = RegExp(
      r'(\d{2,3})\s*(?:علي|على|\/)\s*(\d{2,3})',
    ).firstMatch(n);
    if (m == null) return null;
    if (!RegExp(r'(?:ضغط|ضغطي)').hasMatch(n)) return null;
    final sys = double.tryParse(m.group(1)!);
    final dia = double.tryParse(m.group(2)!);
    if (sys == null || dia == null) return null;
    if (sys < 70 || sys > 250 || dia < 40 || dia > 150) return null;
    return ChronicCareInterpretation(
      kind: ChronicCareInterpretKind.bpMeasurement,
      conditionKey: 'hypertension',
      systolic: sys,
      diastolic: dia,
    );
  }

  ChronicCareInterpretation? _parseGlucose(String n, ChronicCareSession session) {
    if (!n.contains('سكر') &&
        session.activeConditionKey != 'diabetes' &&
        !RegExp(r'hba1c|تحرري').hasMatch(n)) {
      return null;
    }
    final hba = RegExp(r'(?:hba1c|السكر\s*التراكمي)\s*(\d+(?:\.\d+)?)')
        .firstMatch(n);
    if (hba != null) {
      final v = double.tryParse(hba.group(1)!);
      if (v == null) return null;
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.glucoseMeasurement,
        conditionKey: 'diabetes',
        glucoseValue: v,
        glucoseType: ChronicMeasurementType.hba1c,
        glucoseContext: ChronicMeasurementContext.unknown,
      );
    }
    final m = RegExp(r'(?:السكر|سكري)?\s*(\d{2,3})(?:\s|$)').firstMatch(n) ??
        RegExp(r'(\d{2,3})').firstMatch(n);
    if (m == null || (!n.contains('سكر') && session.activeConditionKey != 'diabetes')) {
      return null;
    }
    final v = double.tryParse(m.group(1)!);
    if (v == null || v < 40 || v > 600) return null;
    final ctx = _parseGlucoseContext(n);
    if (ctx == ChronicMeasurementContext.unknown &&
        !session.awaitingMeasurementContext) {
      // سياق مهم وغير معروف → توضيح
      return ChronicCareInterpretation(
        kind: ChronicCareInterpretKind.needsGlucoseContext,
        conditionKey: 'diabetes',
        glucoseValue: v,
        glucoseType: ChronicMeasurementType.bloodGlucose,
      );
    }
    return ChronicCareInterpretation(
      kind: ChronicCareInterpretKind.glucoseMeasurement,
      conditionKey: 'diabetes',
      glucoseValue: v,
      glucoseType: ctx == ChronicMeasurementContext.fasting
          ? ChronicMeasurementType.fastingGlucose
          : (ctx == ChronicMeasurementContext.postMeal
              ? ChronicMeasurementType.postMealGlucose
              : ChronicMeasurementType.bloodGlucose),
      glucoseContext: ctx,
    );
  }

  ChronicMeasurementContext _parseGlucoseContext(String n) {
    if (RegExp(r'(?:صايم|صيام|فاستنج|fasting)').hasMatch(n)) {
      return ChronicMeasurementContext.fasting;
    }
    if (RegExp(r'(?:بعد\s*(?:الاكل|الأكل|الوجبه|الوجبة)|بوست)').hasMatch(n)) {
      return ChronicMeasurementContext.postMeal;
    }
    return ChronicMeasurementContext.unknown;
  }

  bool _isYes(String n) =>
      RegExp(r'(?:^|\s)(?:اي|نعم|هيه|زين|موافق)(?:\s|$)').hasMatch(n) ||
      n == 'نعم' ||
      n == 'اي';

  bool _isNo(String n) =>
      RegExp(r'(?:^|\s)(?:لا|كلا|ما\s*اريد)(?:\s|$)').hasMatch(n) || n == 'لا';

  bool _isLater(String n) =>
      RegExp(r'(?:بعدين|لاحقا|مو\s*هسه)').hasMatch(n);

  bool _isSkip(String n) =>
      RegExp(r'(?:تخطي|ما\s*اريد\s*اجاوب|مو\s*هسه)').hasMatch(n);
}
