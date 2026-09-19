import '../../search/arabic_text_utils.dart';
import '../context_resolver.dart';
import 'arabic_answer_normalizer.dart';
import 'arabic_duration_parser.dart';
import 'guided_conversation_models.dart';
import 'guided_topic_change_detector.dart';
import '../intent/intent_result.dart';

enum GuidedAnswerResolveStatus {
  resolved,
  needsClarification,
  topicChanged,
  cancelled,
  unresolved,
}

class GuidedAnswerResolveResult {
  const GuidedAnswerResolveResult({
    required this.status,
    this.answer,
    this.message = '',
    this.forwardQuery,
    this.isCorrection = false,
  });

  final GuidedAnswerResolveStatus status;
  final GuidedAnswer? answer;
  final String message;
  final String? forwardQuery;
  final bool isCorrection;

  static const unresolved = GuidedAnswerResolveResult(
    status: GuidedAnswerResolveStatus.unresolved,
  );
}

/// يحل إجابات الأسئلة الموجَّهة حسب النوع المتوقع — حتمي.
class GuidedAnswerResolver {
  const GuidedAnswerResolver({
    ArabicDurationParser? durationParser,
    GuidedTopicChangeDetector? topicChangeDetector,
  })  : _duration = durationParser ?? const ArabicDurationParser(),
        _topic = topicChangeDetector ?? const GuidedTopicChangeDetector();

  final ArabicDurationParser _duration;
  final GuidedTopicChangeDetector _topic;

  GuidedAnswerResolveResult resolve({
    required String query,
    required GuidedQuestion question,
    IntentResult? intentResult,
    bool allowTopicEscape = true,
  }) {
    final original = query.trim();
    if (original.isEmpty) return GuidedAnswerResolveResult.unresolved;

    if (allowTopicEscape) {
      final topic = _topic.detect(query: original, intentResult: intentResult);
      switch (topic.kind) {
        case GuidedTopicChangeKind.cancelOnly:
          return const GuidedAnswerResolveResult(
            status: GuidedAnswerResolveStatus.cancelled,
            message: 'تم إلغاء المساعدة الموجّهة.',
          );
        case GuidedTopicChangeKind.topicChanged:
          return GuidedAnswerResolveResult(
            status: GuidedAnswerResolveStatus.topicChanged,
            forwardQuery: topic.forwardQuery ?? original,
          );
        case GuidedTopicChangeKind.none:
          break;
      }
    }

    final isCorrection = ArabicAnswerNormalizer.looksLikeCorrection(original);
    final working = isCorrection
        ? ArabicAnswerNormalizer.stripCorrectionPrefix(original)
        : original;

    switch (question.expectedAnswerType) {
      case GuidedAnswerType.yesNo:
        return _resolveYesNo(working, question, isCorrection: isCorrection);
      case GuidedAnswerType.duration:
        return _resolveDuration(working, question, isCorrection: isCorrection);
      case GuidedAnswerType.number:
        return _resolveNumber(working, question, isCorrection: isCorrection);
      case GuidedAnswerType.singleChoice:
        return _resolveSingleChoice(
          working,
          question,
          isCorrection: isCorrection,
        );
      case GuidedAnswerType.multipleChoice:
        return _resolveMultipleChoice(
          working,
          question,
          isCorrection: isCorrection,
        );
      case GuidedAnswerType.freeText:
      case GuidedAnswerType.date:
      case GuidedAnswerType.time:
      case GuidedAnswerType.unknown:
        return GuidedAnswerResolveResult(
          status: GuidedAnswerResolveStatus.resolved,
          isCorrection: isCorrection,
          answer: GuidedAnswer(
            questionId: question.id,
            rawText: working,
            normalizedValue: ArabicTextUtils.normalize(working),
            answerType: question.expectedAnswerType,
          ),
        );
    }
  }

  GuidedAnswerResolveResult _resolveYesNo(
    String text,
    GuidedQuestion question, {
    required bool isCorrection,
  }) {
    final yn = ArabicAnswerNormalizer.tryYesNo(text);
    if (yn == null) {
      return const GuidedAnswerResolveResult(
        status: GuidedAnswerResolveStatus.needsClarification,
        message: 'جاوب بنعم أو لا لو سمحت.',
      );
    }
    return GuidedAnswerResolveResult(
      status: GuidedAnswerResolveStatus.resolved,
      isCorrection: isCorrection,
      answer: GuidedAnswer(
        questionId: question.id,
        rawText: text,
        normalizedValue: yn,
        answerType: GuidedAnswerType.yesNo,
        yesNo: yn,
      ),
    );
  }

  GuidedAnswerResolveResult _resolveDuration(
    String text,
    GuidedQuestion question, {
    required bool isCorrection,
  }) {
    final d = _duration.parse(text);
    if (d == null) {
      // إجابات قصيرة متوافقة لا تذهب لبحث عام.
      if (_isShortAnswer(text)) {
        return const GuidedAnswerResolveResult(
          status: GuidedAnswerResolveStatus.needsClarification,
          message: 'ما فهمت المدة. مثال: من يومين، من البارحة، أسبوعين.',
        );
      }
      return GuidedAnswerResolveResult.unresolved;
    }
    return GuidedAnswerResolveResult(
      status: GuidedAnswerResolveStatus.resolved,
      isCorrection: isCorrection,
      answer: GuidedAnswer(
        questionId: question.id,
        rawText: text,
        normalizedValue: {
          'amount': d.amount,
          'unit': d.unit,
          'approximate': d.approximate,
        },
        answerType: GuidedAnswerType.duration,
        durationValue: d,
      ),
    );
  }

  GuidedAnswerResolveResult _resolveNumber(
    String text,
    GuidedQuestion question, {
    required bool isCorrection,
  }) {
    final numVal = ArabicAnswerNormalizer.tryNumber(text);
    if (numVal == null) {
      if (_isShortAnswer(text)) {
        return const GuidedAnswerResolveResult(
          status: GuidedAnswerResolveStatus.needsClarification,
          message: 'جاوب برقم لو سمحت.',
        );
      }
      return GuidedAnswerResolveResult.unresolved;
    }
    return GuidedAnswerResolveResult(
      status: GuidedAnswerResolveStatus.resolved,
      isCorrection: isCorrection,
      answer: GuidedAnswer(
        questionId: question.id,
        rawText: text,
        normalizedValue: numVal,
        answerType: GuidedAnswerType.number,
        numberValue: numVal,
      ),
    );
  }

  GuidedAnswerResolveResult _resolveSingleChoice(
    String text,
    GuidedQuestion question, {
    required bool isCorrection,
  }) {
    final options = question.options;
    if (options.isEmpty) {
      return GuidedAnswerResolveResult(
        status: GuidedAnswerResolveStatus.resolved,
        isCorrection: isCorrection,
        answer: GuidedAnswer(
          questionId: question.id,
          rawText: text,
          normalizedValue: ArabicTextUtils.normalize(text),
          answerType: GuidedAnswerType.singleChoice,
        ),
      );
    }

    final n = ArabicTextUtils.normalize(text);
    final ordinal = ContextResolver.extractOrdinal(n);
    if (ordinal != null && ordinal >= 1 && ordinal <= options.length) {
      final opt = options[ordinal - 1];
      return GuidedAnswerResolveResult(
        status: GuidedAnswerResolveStatus.resolved,
        isCorrection: isCorrection,
        answer: GuidedAnswer(
          questionId: question.id,
          rawText: text,
          normalizedValue: opt.id,
          answerType: GuidedAnswerType.singleChoice,
          optionIds: [opt.id],
        ),
      );
    }

    GuidedChoiceOption? hit;
    for (final opt in options) {
      if (_optionMatches(n, opt)) {
        if (hit != null && hit.id != opt.id) {
          return const GuidedAnswerResolveResult(
            status: GuidedAnswerResolveStatus.needsClarification,
            message: 'أي خيار تقصد بالضبط؟',
          );
        }
        hit = opt;
      }
    }
    if (hit != null) {
      return GuidedAnswerResolveResult(
        status: GuidedAnswerResolveStatus.resolved,
        isCorrection: isCorrection,
        answer: GuidedAnswer(
          questionId: question.id,
          rawText: text,
          normalizedValue: hit.id,
          answerType: GuidedAnswerType.singleChoice,
          optionIds: [hit.id],
        ),
      );
    }

    if (_isShortAnswer(text)) {
      return const GuidedAnswerResolveResult(
        status: GuidedAnswerResolveStatus.needsClarification,
        message: 'اختر واحد من الخيارات المذكورة لو سمحت.',
      );
    }
    return GuidedAnswerResolveResult.unresolved;
  }

  GuidedAnswerResolveResult _resolveMultipleChoice(
    String text,
    GuidedQuestion question, {
    required bool isCorrection,
  }) {
    final options = question.options;
    final n = ArabicTextUtils.normalize(text);
    final ids = <String>[];

    // «الأول والثالث»
    final ordinalMatches = RegExp(
      r'(?:ال)?(?:اول|أول|اولي|أولى|ثاني|ثانيه|ثانية|ثالث|ثالثه|ثالثة|رابع|رابعه|رابعة|خامس|خامسه|خامسة)',
    ).allMatches(n);
    for (final m in ordinalMatches) {
      final token = m.group(0)!;
      final idx = _ordinalTokenToIndex(token);
      if (idx != null && idx >= 1 && idx <= options.length) {
        final id = options[idx - 1].id;
        if (!ids.contains(id)) ids.add(id);
      }
    }

    for (final opt in options) {
      if (_optionMatches(n, opt) && !ids.contains(opt.id)) {
        ids.add(opt.id);
      }
    }

    if (ids.isEmpty) {
      if (_isShortAnswer(text)) {
        return const GuidedAnswerResolveResult(
          status: GuidedAnswerResolveStatus.needsClarification,
          message: 'حدد الخيارات المناسبة (مثلاً: الأول والثالث).',
        );
      }
      return GuidedAnswerResolveResult.unresolved;
    }

    return GuidedAnswerResolveResult(
      status: GuidedAnswerResolveStatus.resolved,
      isCorrection: isCorrection,
      answer: GuidedAnswer(
        questionId: question.id,
        rawText: text,
        normalizedValue: ids,
        answerType: GuidedAnswerType.multipleChoice,
        optionIds: ids,
      ),
    );
  }

  bool _optionMatches(String normalizedQuery, GuidedChoiceOption opt) {
    final q = normalizedQuery.replaceAll(RegExp(r'\s+'), ' ').trim();
    final labels = <String>[
      opt.id,
      opt.label,
      ...opt.aliases,
    ];
    for (final label in labels) {
      final ln = ArabicTextUtils.normalize(label).trim();
      if (ln.isEmpty) continue;
      if (q == ln) return true;
      if (RegExp('(?:^|\\s)${RegExp.escape(ln)}(?:\\s|\$)').hasMatch(q)) {
        return true;
      }
    }
    return false;
  }

  int? _ordinalTokenToIndex(String token) {
    final t = ArabicTextUtils.normalize(token);
    if (RegExp(r'اول|أولى|اولي').hasMatch(t)) return 1;
    if (RegExp(r'ثاني').hasMatch(t)) return 2;
    if (RegExp(r'ثالث').hasMatch(t)) return 3;
    if (RegExp(r'رابع').hasMatch(t)) return 4;
    if (RegExp(r'خامس').hasMatch(t)) return 5;
    return null;
  }

  bool _isShortAnswer(String text) {
    final t = text.trim();
    if (t.length <= 24) return true;
    final words = t.split(RegExp(r'\s+'));
    return words.length <= 5;
  }
}
