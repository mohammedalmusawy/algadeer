import '../../search/arabic_text_utils.dart';
import 'adolescent_evidence_catalog.dart';
import 'adolescent_models.dart';

class AdolescentInterpreter {
  const AdolescentInterpreter();

  AdolescentInterpretation interpret(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (n.isEmpty) return AdolescentInterpretation.none;

    final medicalForeign = RegExp(
      r'(?:سعال|كحه|ظهري|ركبتي|سني|ضرس|حامل|سكري|ضغط\s*الدم|نزيف)',
    ).hasMatch(n);

    final ageMatch = RegExp(r'(?:عمري|عمره|عمرها)\s*(\d{1,2})').firstMatch(n);
    int? age;
    if (ageMatch != null) age = int.tryParse(ageMatch.group(1)!);

    final correctionAge =
        RegExp(r'(?:مو\s*عمري\s*\d+|عمري\s*\d+)').hasMatch(n) &&
            RegExp(r'مو').hasMatch(n);

    var development = AdolescentDevelopmentState.unknown;
    if (age != null) {
      if (AdolescentEvidenceCatalog.isAdolescentAge(age)) {
        development = AdolescentDevelopmentState.confirmedAdolescent;
      } else if (AdolescentEvidenceCatalog.isYoungerChildAge(age)) {
        development = AdolescentDevelopmentState.youngerChild;
      } else if (AdolescentEvidenceCatalog.isAdultAge(age)) {
        development = AdolescentDevelopmentState.adult;
      }
    }

    final other = _otherPerson(n);
    final parentAbout = RegExp(
      r'(?:ابني|بنتي|اخوي|أختي|اختي).{0,40}(?:عمر|ما\s*يدرس|يسهر|متوتر|تنام|يركز|تركيز|امتحان)',
    ).hasMatch(n);
    final correctionSubject = RegExp(
      r'(?:مو\s*إلي|لابني|مو\s*ابني|لاخوي|مو\s*بنتي)',
    ).hasMatch(n);

    final schoolCue = RegExp(
      r'(?:دراسه|امتحان|امتحانات|مدرسه|تركيز|يركز|اذاكره|اذاكر|واجبات|ماد[ةه])',
    ).hasMatch(n);
    final sleepCue = RegExp(
      r'(?:اسهر|أنام|نوم|سهر|اصحى|أصحى|متاخر)',
    ).hasMatch(n);
    final activityCue = RegExp(
      r'(?:رياضه|اتمرن|أمشي|امشي|حركه)',
    ).hasMatch(n);
    final bodyCue = RegExp(
      r'(?:ما\s*احب\s*شكلي|جسمي|شكلي|وزني|اخس|حبوب\s*تخسيس)',
    ).hasMatch(n);
    final bullyCue = RegExp(
      r'(?:يتنمر|تنمر|يضايقني|يهينني|يستهزئ)',
    ).hasMatch(n);
    final cyberCue = RegExp(
      r'(?:اونلاين|إلكتروني|بالنت|رسائل\s*مضايقه|صوره\s*خاصة)',
    ).hasMatch(n);
    final familyCue = RegExp(
      r'(?:اهلي\s*ما\s*يفهمون|أهلي|نتعارك|اهلي)',
    ).hasMatch(n);
    final friendCue = RegExp(
      r'(?:اصدقائي|أصحابي|اصدقاء|يستبعدون|ضغط\s*اصدقاء)',
    ).hasMatch(n);
    final pubertyCue = RegExp(
      r'(?:بلوغ|مراهقه|مراهقة|تغيرات\s*الجسم|شعر\s*الجسم|صوت\s*يتغير)',
    ).hasMatch(n);
    final emotionalCue = RegExp(
      r'(?:خايف|متوتر|حزين|وحيد|زعلان|ثقتي|ضغط)',
    ).hasMatch(n);

    // "عندي امتحان" alone ≠ adolescent without age
    final lifeCue = schoolCue ||
        sleepCue ||
        activityCue ||
        bodyCue ||
        bullyCue ||
        familyCue ||
        friendCue ||
        pubertyCue ||
        (emotionalCue && (age != null || parentAbout));

    final asksEducation = RegExp(
      r'(?:شنو\s*(?:يعني|يصير)|ليش\s*النوم\s*مهم|شنو\s*التغيرات)',
    ).hasMatch(n);
    final asksPlan = RegExp(r'(?:رتبلي\s*يومي|اريد\s*ارتب|خططلي)').hasMatch(n);
    final followUp = RegExp(r'(?:ذكرني|تابع\s*وياي)').hasMatch(n);

    final topic = _topic(
      n: n,
      schoolCue: schoolCue,
      sleepCue: sleepCue,
      activityCue: activityCue,
      bodyCue: bodyCue,
      bullyCue: bullyCue,
      cyberCue: cyberCue,
      familyCue: familyCue,
      friendCue: friendCue,
      pubertyCue: pubertyCue,
      asksEducation: asksEducation,
      asksPlan: asksPlan,
    );

    final impacts = <AdolescentFunctionalImpact>[];
    if (schoolCue) impacts.add(AdolescentFunctionalImpact.studyAffected);
    if (sleepCue) impacts.add(AdolescentFunctionalImpact.sleepAffected);
    if (RegExp(r'(?:ما\s*اكدر\s*اسوي|ما\s*أقدر)').hasMatch(n)) {
      impacts.add(AdolescentFunctionalImpact.dailyActivitiesAffected);
    }

    final isTurn = !medicalForeign &&
        (development == AdolescentDevelopmentState.confirmedAdolescent ||
            parentAbout ||
            (asksEducation && pubertyCue) ||
            (lifeCue &&
                (development == AdolescentDevelopmentState.confirmedAdolescent ||
                    parentAbout ||
                    age != null)) ||
            (lifeCue &&
                RegExp(r'(?:مراهق|مراهقه|عمري\s*1[0-9])').hasMatch(n)));

    // School alone without age: not full adolescent turn
    final schoolOnlyNoAge = schoolCue &&
        age == null &&
        !parentAbout &&
        !pubertyCue &&
        development == AdolescentDevelopmentState.unknown;

    return AdolescentInterpretation(
      isAdolescentTurn: isTurn && !schoolOnlyNoAge,
      topic: topic,
      statedAgeYears: age,
      developmentState: development,
      functionalImpacts: impacts,
      isAboutOtherPerson: other || correctionSubject || parentAbout,
      otherPersonLabel: _otherLabel(n),
      parentAskingAboutTeen: parentAbout,
      correctionSubject: correctionSubject,
      correctionAge: correctionAge,
      asksEducation: asksEducation,
      asksPlan: asksPlan,
      asksActivity: activityCue,
      asksSleep: sleepCue,
      asksStudyHelp: schoolCue,
      explicitFollowUp: followUp,
      bullyingHint: bullyCue,
      cyberbullyingHint: cyberCue && bullyCue,
      threatHint: RegExp(r'(?:يهددني|ضربني|عنف)').hasMatch(n),
      bodyImageHint: bodyCue,
      weightLossRequest: RegExp(r'(?:اريد\s*اخس|انقص\s*وزني)').hasMatch(n),
      dietPillRequest: RegExp(r'(?:حبوب\s*تخسيس|مكمل\s*تخسيس)').hasMatch(n),
      extremeDietHint: RegExp(r'(?:صيام\s*قاسي|ما\s*آكل|تجويع)').hasMatch(n),
      pubertyEducation: pubertyCue || (asksEducation && pubertyCue),
      medicalForeignDomain: medicalForeign,
    );
  }

  AdolescentTopic _topic({
    required String n,
    required bool schoolCue,
    required bool sleepCue,
    required bool activityCue,
    required bool bodyCue,
    required bool bullyCue,
    required bool cyberCue,
    required bool familyCue,
    required bool friendCue,
    required bool pubertyCue,
    required bool asksEducation,
    required bool asksPlan,
  }) {
    if (asksEducation && pubertyCue) {
      return AdolescentTopic.generalPubertyEducation;
    }
    if (asksEducation) return AdolescentTopic.educationOnly;
    if (cyberCue && bullyCue) return AdolescentTopic.cyberbullying;
    if (bullyCue) return AdolescentTopic.bullying;
    if (bodyCue) return AdolescentTopic.bodyImageConcern;
    if (familyCue) return AdolescentTopic.familyTension;
    if (friendCue && RegExp(r'ضغط').hasMatch(n)) {
      return AdolescentTopic.peerPressure;
    }
    if (friendCue) return AdolescentTopic.friendship;
    if (RegExp(r'امتحان|خايف').hasMatch(n) && schoolCue) {
      return AdolescentTopic.examStress;
    }
    if (RegExp(r'تركيز|أركز|اركز').hasMatch(n)) {
      return AdolescentTopic.concentrationDifficulty;
    }
    if (RegExp(r'(?:ما\s*عندي\s*نفس|ما\s*اريد\s*ادرس)').hasMatch(n)) {
      return AdolescentTopic.motivationDifficulty;
    }
    if (asksPlan || RegExp(r'رتب|وقت|جدول').hasMatch(n)) {
      return AdolescentTopic.timeManagement;
    }
    if (sleepCue) return AdolescentTopic.sleepRoutine;
    if (activityCue) return AdolescentTopic.physicalActivity;
    if (RegExp(r'ثقتي|ثقه').hasMatch(n)) return AdolescentTopic.selfConfidence;
    if (schoolCue) return AdolescentTopic.studyDifficulty;
    if (pubertyCue) return AdolescentTopic.generalPubertyEducation;
    return AdolescentTopic.unknown;
  }

  bool _otherPerson(String n) {
    if (RegExp(r'(?:^|\s)(?:اني|انا|عمري)(?:\s|$)').hasMatch(n) &&
        !RegExp(r'(?:ابني|بنتي|اخوي|اختي)').hasMatch(n)) {
      return false;
    }
    return RegExp(r'(?:ابني|بنتي|اخوي|اختي|أختي)').hasMatch(n);
  }

  String _otherLabel(String n) {
    if (RegExp(r'ابني').hasMatch(n)) return 'son';
    if (RegExp(r'بنتي').hasMatch(n)) return 'daughter';
    if (RegExp(r'اخوي').hasMatch(n)) return 'brother';
    if (RegExp(r'(?:اختي|أختي)').hasMatch(n)) return 'sister';
    return '';
  }
}
