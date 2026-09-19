import '../../voice/guided_conversation/arabic_duration_parser.dart';
import 'health_language_detector.dart';
import 'health_language_normalizer.dart';
import 'local_symptom_catalog.dart';
import 'symptom_catalog_source.dart';
import 'symptom_matcher.dart';
import 'symptom_models.dart';

/// محرك فهم صحي — تحويل لغة المستخدم إلى مفاهيم مهيكلة فقط.
///
/// لا تشخيص، لا توصية، لا تخصص، لا تحليل، لا دواء.
/// لا يعتمد على TTS ولا يُصرّف النتائج.
class HealthUnderstandingEngine {
  HealthUnderstandingEngine({
    SyncSymptomCatalogSource? catalog,
    HealthLanguageNormalizer? normalizer,
    ArabicDurationParser? durationParser,
    SymptomMatcher? matcher,
    HealthLanguageDetector? detector,
  })  : _catalog = catalog ?? const LocalSymptomCatalog(),
        _normalizer = normalizer ?? const HealthLanguageNormalizer(),
        _durationParser = durationParser ?? const ArabicDurationParser(),
        _detector = detector ?? HealthLanguageDetector(),
        _matcher = matcher;

  final SyncSymptomCatalogSource _catalog;
  final HealthLanguageNormalizer _normalizer;
  final ArabicDurationParser _durationParser;
  final HealthLanguageDetector _detector;
  SymptomMatcher? _matcher;

  /// نفس محلل المدة من Step 10A — لا نسخة منافسة.
  ArabicDurationParser get durationParser => _durationParser;

  SyncSymptomCatalogSource get catalog => _catalog;

  SymptomMatcher get _m {
    return _matcher ??= SymptomMatcher(
      catalog: _catalog,
      normalizer: _normalizer,
      durationParser: _durationParser,
    );
  }

  /// فهم هيكلي للنص (صوت أو كتابة — نفس المسار).
  HealthUnderstandingResult understand(String text) {
    final original = text.trim();
    if (original.isEmpty) {
      return HealthUnderstandingResult.empty(original);
    }
    if (_detector.isAppCommand(original)) {
      return HealthUnderstandingResult(
        originalText: original,
        normalizedText: _normalizer.normalize(original),
        containsHealthLanguage: false,
      );
    }
    return _m.match(original);
  }

  bool looksLikeHealthLanguage(String text) {
    if (_detector.isAppCommand(text)) return false;
    final r = understand(text);
    return _detector.containsHealthLanguage(
      text,
      hasStructuredSymptoms: (_) => r.symptoms.isNotEmpty,
    );
  }
}
