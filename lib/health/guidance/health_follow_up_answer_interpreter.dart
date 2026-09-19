import '../../search/arabic_text_utils.dart';
import '../../voice/guided_conversation/arabic_answer_normalizer.dart';
import '../../voice/guided_conversation/arabic_duration_parser.dart';
import '../../voice/guided_conversation/guided_answer_resolver.dart';
import '../../voice/guided_conversation/guided_conversation_models.dart';
import '../understanding/symptom_models.dart';
import 'health_follow_up_models.dart';
import 'health_guidance_models.dart';

/// يفسّر إجابات قصيرة عراقية حسب سؤال المتابعة الحالي — بلا بحث عام.
class HealthFollowUpAnswerInterpreter {
  HealthFollowUpAnswerInterpreter({
    ArabicDurationParser? durationParser,
    GuidedAnswerResolver? answerResolver,
  })  : _duration = durationParser ?? const ArabicDurationParser(),
        _answers = answerResolver ?? const GuidedAnswerResolver();

  final ArabicDurationParser _duration;
  final GuidedAnswerResolver _answers;

  HealthFollowUpInterpretation interpret({
    required String rawAnswer,
    required GuidedQuestion question,
    required HealthSessionFacts facts,
    GuidedAnswer? guidedAnswer,
  }) {
    final text = rawAnswer.trim();
    final n = ArabicTextUtils.normalize(text);
    final meta = HealthQuestionMeta.fromQuestion(question);

    // إلغاء التدفق بالكامل
    if (_isFullCancel(n)) {
      return const HealthFollowUpInterpretation(
        kind: HealthFollowUpInterpretKind.cancelFlow,
        cancelFlow: true,
      );
    }

    // رفض جواب السؤال فقط
    if (_isRefuseAnswer(n)) {
      return const HealthFollowUpInterpretation(
        kind: HealthFollowUpInterpretKind.refuseQuestion,
        refuseAnswerOnly: true,
        skipCurrentQuestion: true,
      );
    }

    // ليش تسأل؟
    if (_isWhyAsk(n)) {
      return HealthFollowUpInterpretation(
        kind: HealthFollowUpInterpretKind.whyAsk,
        explanation: meta?.whyExplanation ??
            'حتى أفهم وصف الأعراض بشكل أدق وأحدد نوع التوجيه المناسب.',
        keepPendingQuestion: true,
      );
    }

    // شنو تقصد؟
    if (_isWhatMean(n)) {
      return HealthFollowUpInterpretation(
        kind: HealthFollowUpInterpretKind.rephrase,
        explanation: meta?.clarificationPrompt ?? question.prompt,
        keepPendingQuestion: true,
      );
    }

    // ما أدري
    if (_isDontKnow(n)) {
      return const HealthFollowUpInterpretation(
        kind: HealthFollowUpInterpretKind.unknownSkip,
        skipCurrentQuestion: true,
      );
    }

    final factKey = meta?.factKey;
    final symptomId = meta?.symptomConceptId;
    var next = facts;

    // «لا، يسار» / «لا يمين» — استبدال جهة سابقة
    final flipLat = RegExp(
      r'^لا\s*[,،]?\s*(?:ال)?(يمين|يسار)\b',
    ).firstMatch(n);
    if (flipLat != null) {
      final side = flipLat.group(1);
      final lat =
          side == 'يسار' ? Laterality.left : Laterality.right;
      var updated = next.copyWith(
        laterality: lat,
        abdominalLocationResolved: true,
      );
      if (symptomId != null) {
        updated = _updateScoped(
          updated,
          symptomId,
          (s) => s.copyWith(laterality: lat),
        );
      }
      final keep = factKey != null &&
          factKey != HealthFactKey.laterality &&
          factKey != HealthFactKey.abdominalLocation &&
          factKey != HealthFactKey.bodyRegion;
      return HealthFollowUpInterpretation(
        kind: HealthFollowUpInterpretKind.factUpdated,
        updatedFacts: updated,
        keepPendingQuestion: keep,
      );
    }

    // تصحيح لاحق — قد يستبدل مدة/جهة سابقة حتى لو السؤال الحالي مختلف
    final isCorrection = ArabicAnswerNormalizer.looksLikeCorrection(text);
    final working = isCorrection
        ? ArabicAnswerNormalizer.stripCorrectionPrefix(text)
        : text;
    final wn = ArabicTextUtils.normalize(working);

    if (isCorrection) {
      final d = _duration.parse(working);
      if (d != null) {
        final keep = factKey != null && factKey != HealthFactKey.duration;
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.factUpdated,
          updatedFacts:
              _setDuration(next, d, symptomId ?? _lastDurationSymptom(next)),
          keepPendingQuestion: keep,
          explanation: keep ? null : null,
        );
      }
      final latOnly = _parseLocation(wn, null);
      if (latOnly?.laterality != null) {
        var updated = next.copyWith(
          laterality: latOnly!.laterality,
          abdominalLocationResolved: true,
        );
        if (symptomId != null) {
          updated = _updateScoped(
            updated,
            symptomId,
            (s) => s.copyWith(laterality: latOnly.laterality),
          );
        }
        final keep = factKey != null &&
            factKey != HealthFactKey.laterality &&
            factKey != HealthFactKey.abdominalLocation &&
            factKey != HealthFactKey.bodyRegion;
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.factUpdated,
          updatedFacts: updated,
          keepPendingQuestion: keep,
        );
      }
      final sev = _parseSeverity(wn, null);
      if (sev != null) {
        final keep = factKey != null && factKey != HealthFactKey.severity;
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.factUpdated,
          updatedFacts: _setSeverity(next, sev, symptomId),
          keepPendingQuestion: keep,
        );
      }
    }

    if (factKey == HealthFactKey.duration ||
        question.expectedAnswerType == GuidedAnswerType.duration) {
      final d = guidedAnswer?.durationValue ?? _duration.parse(working);
      if (d != null) {
        next = _setDuration(next, d, symptomId);
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.factUpdated,
          updatedFacts: next,
        );
      }
    }

    if (factKey == HealthFactKey.severity ||
        (meta?.purpose == HealthQuestionPurpose.severity)) {
      final sev = _parseSeverity(wn, guidedAnswer);
      if (sev != null) {
        next = _setSeverity(next, sev, symptomId);
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.factUpdated,
          updatedFacts: next,
        );
      }
    }

    if (factKey == HealthFactKey.onset ||
        meta?.purpose == HealthQuestionPurpose.onset) {
      final on = _parseOnset(wn, guidedAnswer);
      if (on != null) {
        next = _setOnset(next, on, symptomId);
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.factUpdated,
          updatedFacts: next,
        );
      }
    }

    if (factKey == HealthFactKey.pattern ||
        meta?.purpose == HealthQuestionPurpose.pattern) {
      final pat = _parsePattern(wn, guidedAnswer);
      if (pat != null) {
        next = next.copyWith(
          temporalModifiers: List.unmodifiable(
            {...next.temporalModifiers, pat}.toList(),
          ),
        );
        if (symptomId != null) {
          next = _updateScoped(
            next,
            symptomId,
            (s) => s.copyWith(
              temporalModifiers: List.unmodifiable(
                {...s.temporalModifiers, pat}.toList(),
              ),
            ),
          );
        }
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.factUpdated,
          updatedFacts: next,
        );
      }
    }

    if (factKey == HealthFactKey.laterality ||
        factKey == HealthFactKey.abdominalLocation ||
        factKey == HealthFactKey.bodyRegion ||
        meta?.purpose == HealthQuestionPurpose.location) {
      final loc = _parseLocation(wn, guidedAnswer);
      if (loc != null) {
        next = next.copyWith(
          laterality: loc.laterality ?? next.laterality,
          bodyRegions: loc.regions ?? next.bodyRegions,
          abdominalLocationResolved: true,
        );
        if (symptomId != null && loc.laterality != null) {
          next = _updateScoped(
            next,
            symptomId,
            (s) => s.copyWith(laterality: loc.laterality),
          );
        }
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.factUpdated,
          updatedFacts: next,
        );
      }
    }

    if (factKey == HealthFactKey.symptomPresence &&
        meta?.symptomConceptId != null) {
      final concept = meta!.symptomConceptId!;
      // يمكن → uncertain
      if (RegExp(r'^(?:يمكن|يمكن\s*اي|مو\s*متاكد|مو\s*متأكد)$').hasMatch(wn)) {
        final m = Map<String, SymptomPolarity>.from(next.symptomStatuses);
        m[concept] = SymptomPolarity.uncertain;
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.uncertain,
          updatedFacts: next.copyWith(symptomStatuses: Map.unmodifiable(m)),
        );
      }
      final yn = guidedAnswer?.yesNo ?? ArabicAnswerNormalizer.tryYesNo(working);
      if (yn != null) {
        final m = Map<String, SymptomPolarity>.from(next.symptomStatuses);
        m[concept] = yn ? SymptomPolarity.present : SymptomPolarity.absent;
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.factUpdated,
          updatedFacts: next.copyWith(symptomStatuses: Map.unmodifiable(m)),
        );
      }
    }

    if (factKey == HealthFactKey.patientIsChild) {
      final yn = guidedAnswer?.yesNo ?? ArabicAnswerNormalizer.tryYesNo(working);
      if (yn != null) {
        return HealthFollowUpInterpretation(
          kind: HealthFollowUpInterpretKind.factUpdated,
          updatedFacts: next.copyWith(patientIsChild: yn),
        );
      }
    }

    // محاولة GuidedAnswerResolver كحل أخير حسب نوع السؤال (مرة واحدة فقط)
    if (guidedAnswer == null) {
      final resolved = _answers.resolve(
        query: working,
        question: question,
        allowTopicEscape: false,
      );
      if (resolved.status == GuidedAnswerResolveStatus.resolved &&
          resolved.answer != null) {
        return interpret(
          rawAnswer: working,
          question: question,
          facts: facts,
          guidedAnswer: resolved.answer,
        );
      }
    }

    return const HealthFollowUpInterpretation(
      kind: HealthFollowUpInterpretKind.unresolved,
    );
  }

  bool _isFullCancel(String n) =>
      ArabicAnswerNormalizer.isCancelCommand(n) ||
      RegExp(
        r'(?:ما\s*(?:اريد|أريد)\s*(?:اكمل|أكمل)|وقف|الغاء|إلغاء|خلاص|اترك\s*الموضوع|خلينا\s*من)',
      ).hasMatch(n);

  bool _isRefuseAnswer(String n) => RegExp(
        r'(?:ما\s*(?:اريد|أريد|احب|أحب)\s*(?:اجاوب|أجاوب)|اترك\s*(?:هذا\s*)?السؤال)',
      ).hasMatch(n);

  bool _isWhyAsk(String n) => RegExp(
        r'(?:ليش|لماذا|لماذا)\s*(?:تسأل|تسال|السؤال)|(?:ليش\s*هذا)',
      ).hasMatch(n);

  bool _isWhatMean(String n) => RegExp(
        r'(?:شنو|ماذا|وش)\s*(?:تقصد|يعني)|(?:ما\s*قصدك)|(?:وضح)|(?:اشرح)',
      ).hasMatch(n);

  bool _isDontKnow(String n) => RegExp(
        r'^(?:ما\s*ادري|ما\s*اعرف|ما\s*أعرف|ماعرف|مو\s*متاكد|مو\s*متأكد|ما\s*متاكد|ما\s*متأكد)$',
      ).hasMatch(n);

  UserStatedSeverity? _parseSeverity(String n, GuidedAnswer? a) {
    if (a?.optionIds.isNotEmpty == true) {
      switch (a!.optionIds.first) {
        case 'mild':
          return UserStatedSeverity.mild;
        case 'moderate':
          return UserStatedSeverity.moderate;
        case 'severe':
          return UserStatedSeverity.severe;
      }
    }
    // ترتيب اختياري: الثاني = متوسط لخيارات خفيف/متوسط/شديد
    if (RegExp(r'(?:^|\s)(?:الثاني|ثاني)(?:\s|$)').hasMatch(n)) {
      return UserStatedSeverity.moderate;
    }
    if (RegExp(r'(?:الاول|الأول|اول)').hasMatch(n)) {
      return UserStatedSeverity.mild;
    }
    if (RegExp(r'(?:الثالث|ثالث)').hasMatch(n)) {
      return UserStatedSeverity.severe;
    }
    if (RegExp(r'(?:كلش\s*قوي|ما\s*اتحمله|شديد|قوي)').hasMatch(n)) {
      return UserStatedSeverity.severe;
    }
    if (RegExp(r'(?:متوسط|وسط)').hasMatch(n)) {
      return UserStatedSeverity.moderate;
    }
    if (RegExp(r'(?:خفيف|بسيط)').hasMatch(n)) {
      return UserStatedSeverity.mild;
    }
    return null;
  }

  OnsetPattern? _parseOnset(String n, GuidedAnswer? a) {
    if (a?.optionIds.contains('sudden') == true) return OnsetPattern.sudden;
    if (a?.optionIds.contains('gradual') == true) return OnsetPattern.gradual;
    if (RegExp(r'(?:فجاه|فجأة|مره\s*وحده|مرة\s*وحدة)').hasMatch(n)) {
      return OnsetPattern.sudden;
    }
    if (RegExp(r'(?:بالتدريج|شوي\s*شوي|شوية\s*شوية)').hasMatch(n)) {
      return OnsetPattern.gradual;
    }
    return null;
  }

  String? _parsePattern(String n, GuidedAnswer? a) {
    if (a?.optionIds.contains('intermittent') == true) return 'intermittent';
    if (a?.optionIds.contains('continuous') == true) return 'continuous';
    if (RegExp(r'(?:يروح\s*و\s*يجي|متقطع|مرات)').hasMatch(n)) {
      return 'intermittent';
    }
    if (RegExp(r'(?:مستمر|باستمرار)').hasMatch(n)) return 'continuous';
    if (RegExp(r'(?:بالليل)').hasMatch(n)) return 'at_night';
    if (RegExp(r'(?:وقت\s*المشي|عند\s*المشي)').hasMatch(n)) {
      return 'while_walking';
    }
    if (RegExp(r'(?:بعد\s*الاكل|بعد\s*الأكل)').hasMatch(n)) {
      return 'after_eating';
    }
    return null;
  }

  ({Laterality? laterality, Set<BodyRegionId>? regions})? _parseLocation(
    String n,
    GuidedAnswer? a,
  ) {
    Laterality? lat;
    final regions = <BodyRegionId>{BodyRegionId.abdomen};

    void applyId(String id) {
      switch (id) {
        case 'right':
          lat = Laterality.right;
        case 'left':
          lat = Laterality.left;
        case 'upper':
          break;
        case 'lower':
          regions.add(BodyRegionId.lowerBack);
        case 'center':
          break;
      }
    }

    if (a?.optionIds.isNotEmpty == true) {
      for (final id in a!.optionIds) {
        applyId(id);
      }
    }

    if (RegExp(r'(?:يمين\s*جوه|يسار\s*فوك|يمين|اليمنى|اليمين)').hasMatch(n)) {
      if (RegExp(r'يسار').hasMatch(n) && !RegExp(r'يمين').hasMatch(n)) {
        lat = Laterality.left;
      } else if (RegExp(r'يمين').hasMatch(n)) {
        lat = Laterality.right;
      }
    }
    if (RegExp(r'(?:يسار|اليسرى|اليسار)').hasMatch(n)) {
      lat = Laterality.left;
    }
    if (RegExp(r'(?:جوه|اسفل|أسفل|تحت)').hasMatch(n)) {
      regions.add(BodyRegionId.lowerBack);
    }
    if (RegExp(r'(?:بالنص|وسط|منتصف|النص)').hasMatch(n)) {
      // وسط
    }
    if (RegExp(r'(?:فوك|فوق|اعلى|أعلى)').hasMatch(n)) {
      // أعلى
    }

    if (lat == null &&
        a == null &&
        !RegExp(r'(?:يمين|يسار|جوه|فوك|تحت|فوق|وسط|نص|اسفل|أسفل)')
            .hasMatch(n)) {
      return null;
    }
    return (laterality: lat, regions: regions);
  }

  HealthSessionFacts _setDuration(
    HealthSessionFacts facts,
    DurationValue d,
    String? symptomId,
  ) {
    var next = facts.copyWith(duration: d);
    if (symptomId != null) {
      next = _updateScoped(next, symptomId, (s) => s.copyWith(duration: d));
    }
    return next;
  }

  HealthSessionFacts _setSeverity(
    HealthSessionFacts facts,
    UserStatedSeverity sev,
    String? symptomId,
  ) {
    var next = facts.copyWith(userSeverity: sev);
    if (symptomId != null) {
      next = _updateScoped(next, symptomId, (s) => s.copyWith(severity: sev));
    }
    return next;
  }

  HealthSessionFacts _setOnset(
    HealthSessionFacts facts,
    OnsetPattern on,
    String? symptomId,
  ) {
    var next = facts.copyWith(onset: on);
    if (symptomId != null) {
      next = _updateScoped(next, symptomId, (s) => s.copyWith(onset: on));
    }
    return next;
  }

  HealthSessionFacts _updateScoped(
    HealthSessionFacts facts,
    String symptomId,
    SymptomScopedFacts Function(SymptomScopedFacts) update,
  ) {
    final map = Map<String, SymptomScopedFacts>.from(facts.symptomFacts);
    final cur = map[symptomId] ?? const SymptomScopedFacts();
    map[symptomId] = update(cur);
    return facts.copyWith(symptomFacts: Map.unmodifiable(map));
  }

  String? _lastDurationSymptom(HealthSessionFacts facts) {
    for (final e in facts.symptomFacts.entries) {
      if (e.value.duration != null) return e.key;
    }
    return null;
  }
}
