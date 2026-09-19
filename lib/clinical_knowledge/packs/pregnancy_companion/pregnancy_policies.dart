import '../../clinical_knowledge_models.dart';
import 'pregnancy_evidence_catalog.dart';
import 'pregnancy_models.dart';

/// سياسة سونار الحمل — أهلية سريرية أولاً؛ بلا انحياز تجاري.
class PregnancyUltrasoundPolicy {
  const PregnancyUltrasoundPolicy();

  bool commercialCanAlterIndication() => false;
  bool packagePresenceCreatesNeed() => false;
  bool sponsorCanAlterIndication() => false;
  bool interpretsUltrasoundImages() => false;
  bool recommendsRepeatedScansBlindly() => false;

  bool mayDiscussRoutineUltrasound({
    required int? weeks,
    required bool recentlyCompleted,
  }) {
    if (recentlyCompleted) return false;
    if (weeks == null) return true; // نقاش حذر فقط
    return weeks < PregnancyEvidenceCatalog.ultrasoundBeforeWeek;
  }
}

class PregnancyGestationalCalculator {
  const PregnancyGestationalCalculator();

  /// حساب حتمي من LMP — بلا تخمين نصي.
  /// يعيد null إن كان التاريخ تقريبياً جداً أو غير صالح.
  ({int weeks, int days, bool approximate})? fromLmp({
    required DateTime lmp,
    required DateTime now,
    bool approximate = false,
  }) {
    final diff = now.difference(lmp);
    if (diff.isNegative || diff.inDays > 300) return null;
    final weeks = diff.inDays ~/ 7;
    final days = diff.inDays % 7;
    return (weeks: weeks, days: days, approximate: approximate);
  }

  /// من EDD مفترض (280 يوماً من LMP اصطلاحاً) — تقديري فقط.
  ({int weeks, int days})? fromEdd({
    required DateTime edd,
    required DateTime now,
  }) {
    final remaining = edd.difference(now).inDays;
    final gestationalDays = 280 - remaining;
    if (gestationalDays < 0 || gestationalDays > 300) return null;
    return (weeks: gestationalDays ~/ 7, days: gestationalDays % 7);
  }

  DateTime? estimatedEddFromLmp(DateTime lmp) =>
      lmp.add(const Duration(days: 280));
}

class PregnancyDuePolicy {
  PregnancyDuePolicy({PregnancyEvidenceCatalog? catalog})
      : catalog = catalog ?? PregnancyEvidenceCatalog();

  final PregnancyEvidenceCatalog catalog;

  PregnancyCareItemStatus statusFor({
    required bool recentlyCompleted,
    required bool dateKnown,
    required bool evidenceWindowOpen,
  }) {
    if (recentlyCompleted) return PregnancyCareItemStatus.recentlyCompleted;
    if (!dateKnown) return PregnancyCareItemStatus.unknown;
    if (evidenceWindowOpen) return PregnancyCareItemStatus.due;
    return PregnancyCareItemStatus.notYetDue;
  }

  bool gdmWindowOpen(int? weeks) {
    if (weeks == null) return false;
    return weeks >= PregnancyEvidenceCatalog.gdmScreenStartWeek &&
        weeks <= PregnancyEvidenceCatalog.gdmScreenEndWeek;
  }

  bool anatomyWindowOpen(int? weeks) {
    if (weeks == null) return false;
    return weeks >= PregnancyEvidenceCatalog.anatomyWindowStartWeek &&
        weeks <= PregnancyEvidenceCatalog.anatomyWindowEndWeek;
  }
}

class PregnancyCareAssembler {
  const PregnancyCareAssembler();

  List<PregnancyCarePriority> assemble({
    required PregnancyCompanionSession session,
    required PregnancyEvidenceCatalog catalog,
    required PregnancyDuePolicy due,
    bool fullChecklist = false,
  }) {
    final out = <PregnancyCarePriority>[];
    final done = session.completedCareItems.toSet();
    final weeks = session.gestationalWeeks;

    void add(PregnancyCareItem item, PregnancyCareItemStatus st, String label) {
      if (done.contains(item.name) && !fullChecklist) return;
      if (done.contains(item.name)) {
        out.add(PregnancyCarePriority(
          id: item.name,
          status: PregnancyCareItemStatus.recentlyCompleted,
          arabicLabel: '$label (مذكور كمكتمل)',
          matchedRuleId: catalog.forCareItem(item)?.ruleId,
        ));
        return;
      }
      out.add(PregnancyCarePriority(
        id: item.name,
        status: st,
        arabicLabel: label,
        matchedRuleId: catalog.forCareItem(item)?.ruleId,
      ));
    }

    if (session.redFlagCandidate) {
      out.add(const PregnancyCarePriority(
        id: 'safety',
        status: PregnancyCareItemStatus.needsClinicianReview,
        arabicLabel: 'سلامة أولاً — تقييم عاجل',
      ));
    }

    add(
      PregnancyCareItem.antenatalContact,
      PregnancyCareItemStatus.unknown,
      'متابعة/مراجعة توليد',
    );

    final usRecent = done.contains(PregnancyCareItem.ultrasoundDating.name);
    add(
      PregnancyCareItem.ultrasoundDating,
      usRecent
          ? PregnancyCareItemStatus.recentlyCompleted
          : PregnancyCareItemStatus.unknown,
      'سونار (حسب الدليل/خطة الطبيبة)',
    );

    if (due.anatomyWindowOpen(weeks)) {
      add(
        PregnancyCareItem.fetalAnatomyAssessment,
        done.contains(PregnancyCareItem.fetalAnatomyAssessment.name)
            ? PregnancyCareItemStatus.recentlyCompleted
            : PregnancyCareItemStatus.due,
        'تقييم تشريح جنيني (نافذة دليلية)',
      );
    } else {
      add(
        PregnancyCareItem.fetalAnatomyAssessment,
        PregnancyCareItemStatus.unknown,
        'تقييم تشريح جنيني',
      );
    }

    if (due.gdmWindowOpen(weeks)) {
      add(
        PregnancyCareItem.gestationalDiabetesScreening,
        done.contains(PregnancyCareItem.gestationalDiabetesScreening.name)
            ? PregnancyCareItemStatus.recentlyCompleted
            : PregnancyCareItemStatus.due,
        'فحص سكر الحمل',
      );
    } else {
      add(
        PregnancyCareItem.gestationalDiabetesScreening,
        PregnancyCareItemStatus.unknown,
        'فحص سكر الحمل',
      );
    }

    if (fullChecklist) {
      add(
        PregnancyCareItem.nutritionReview,
        PregnancyCareItemStatus.notYetDue,
        'تغذية عامة آمنة',
      );
      add(
        PregnancyCareItem.physicalActivityReview,
        PregnancyCareItemStatus.notYetDue,
        'نشاط بدني حسب السياق',
      );
      add(
        PregnancyCareItem.birthPreparedness,
        (weeks ?? 0) >= 28
            ? PregnancyCareItemStatus.notYetDue
            : PregnancyCareItemStatus.notApplicable,
        'استعداد للولادة (لاحقاً)',
      );
    }

    // UNKNOWN never becomes OVERDUE in output
    final cleaned = out
        .map((p) => p.status == PregnancyCareItemStatus.overdue
            ? PregnancyCarePriority(
                id: p.id,
                status: PregnancyCareItemStatus.unknown,
                arabicLabel: p.arabicLabel,
                matchedRuleId: p.matchedRuleId,
              )
            : p)
        .toList();

    if (fullChecklist) return cleaned;
    return cleaned.take(3).toList(growable: false);
  }

  ClinicalCareDestination destinationFor(String careId) {
    if (careId.contains('ultrasound') || careId.contains('Ultrasound') ||
        careId == PregnancyCareItem.ultrasoundDating.name ||
        careId == PregnancyCareItem.fetalAnatomyAssessment.name) {
      return ClinicalCareDestination.radiology;
    }
    if (careId == PregnancyCareItem.gestationalDiabetesScreening.name ||
        careId == PregnancyCareItem.routineBloodTesting.name) {
      return ClinicalCareDestination.laboratory;
    }
    if (careId == 'safety') return ClinicalCareDestination.emergency;
    return ClinicalCareDestination.obstetricsGynecology;
  }
}
