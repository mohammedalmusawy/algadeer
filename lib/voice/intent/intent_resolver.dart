import '../../search/arabic_text_utils.dart';
import '../../search/voice_contact_command.dart';
import '../../search/voice_specialty_search_command.dart';
import '../context_resolver.dart';
import 'assistant_intent.dart';
import 'entity_extractor.dart';
import 'intent_result.dart';

/// تجريد حل النية — الحالي قاعدي؛ مستقبلًا يمكن إضافة AIIntentResolver بدون إعادة بناء.
abstract class IntentResolver {
  IntentResult resolve(String query);
}

/// حل نية موحّد (Step 4) — نص وصوت بنفس القواعد.
///
/// ترتيب الأولوية (موثّق):
/// 1. selectResult — فقط للجمل الترتيبية السياقية النقية
/// 2. إجراءات صريحة/إشارية: call / whatsapp / location / profile
/// 3. specialtySearch (إعادة استخدام VoiceSpecialtySearchCommand)
/// 4. doctorSearch
/// 5. generalSearch
/// 6. unknown
///
/// لا يحتوي أسماء أطباء ثابتة — المطابقة عبر DoctorNameMatcher لاحقاً.
class RuleBasedIntentResolver implements IntentResolver {
  RuleBasedIntentResolver({EntityExtractor? extractor})
    : _extractor = extractor ?? const RuleBasedEntityExtractor();

  final EntityExtractor _extractor;

  @override
  IntentResult resolve(String query) {
    final prepared = ArabicTextUtils.prepareQuery(query);
    if (prepared.originalText.isEmpty) {
      return IntentResult.unknown('', '');
    }

    final original = prepared.originalText;
    final normalized = prepared.normalizedText;
    final meaning = prepared.searchMeaning;
    final entities = _extractor.extract(original, normalized);

    // 1) اختيار ترتيبي — فقط للجمل السياقية النقية (الثاني / اختار الثاني).
    // لا يبتلع «أريد دكتور علي الثاني» كـ selectResult.
    final ordinal = ContextResolver.extractOrdinal(normalized);
    if (ordinal != null && _isPureContextualOrdinal(normalized)) {
      return IntentResult(
        intent: AssistantIntent.selectResult,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(resultIndex: ordinal),
        confidence: 92,
        requiresContext: true,
      );
    }

    // 1a) عودة تركيز صريحة — Step 9.
    final returnHint = _returnFocusHint(normalized);
    if (returnHint != null) {
      return IntentResult(
        intent: AssistantIntent.selectResult,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(actionHint: returnHint),
        confidence: 90,
        requiresContext: true,
      );
    }

    final hasLabEntity = _hasExplicitLabName(entities.laboratory) ||
        _mentionsLab(normalized);
    final labName = _hasExplicitLabName(entities.laboratory)
        ? entities.laboratory
        : null;
    final analysisName = _hasExplicitAnalysisName(entities.analysis)
        ? entities.analysis
        : null;
    final packageName = (entities.packageName ?? '').trim();
    final analysisTerms = entities.allAnalysisTerms;

    // 1b) أفضل باقة بدون معيار — لا توصية ذاتية.
    if (_looksLikeBestPackage(normalized)) {
      return IntentResult(
        intent: AssistantIntent.findPackage,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(actionHint: 'best_unsupported'),
        confidence: 86,
        requiresContext: false,
      );
    }

    // 1c) عروض = باقات مخفّضة حقيقية (ليس dynamic_messages).
    if (_looksLikeOffers(normalized)) {
      return IntentResult(
        intent: AssistantIntent.findOffer,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          laboratory: labName,
          actionHint: 'offers',
        ),
        confidence: 88,
        requiresContext: false,
      );
    }

    // 1c2) Step 7 سياقي: بأي باقة؟ / وين موجود؟ / أي مختبر عنده؟ — قبل مسار الباقة.
    if (_looksLikePackagesForAnalysis(normalized) ||
        _looksLikeWhereAnalysis(normalized) ||
        _looksLikeLabsForAnalysis(normalized)) {
      return IntentResult(
        intent: AssistantIntent.findAnalysis,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          analysis: analysisName,
          packageName: null,
          laboratory: null,
          doctorName: null,
          actionHint: _looksLikeLabsForAnalysis(normalized)
              ? 'labs_for_analysis'
              : (_looksLikePackagesForAnalysis(normalized)
                  ? 'packages_for_analysis'
                  : 'where_analysis'),
        ),
        confidence: 84,
        requiresContext: analysisName == null,
      );
    }

    // 1d) باقة بالاسم / فلتر تحاليل / أرخص / مقارنة.
    if (packageName.isNotEmpty ||
        analysisTerms.length >= 2 ||
        _looksLikePackageAnalysisFilter(normalized) ||
        _looksLikeCheapestPackage(normalized) ||
        _looksLikePackageCompare(normalized) ||
        _looksLikePackagePrice(normalized) ||
        _looksLikePackageAnalysesQuestion(normalized) ||
        _looksLikePackageLabQuestion(normalized)) {
      String hint = entities.actionHint ?? 'search';
      if (_looksLikeCheapestPackage(normalized)) {
        hint = analysisTerms.isNotEmpty ? 'cheapest_filter' : 'cheapest';
      } else if (analysisTerms.length >= 2 ||
          _looksLikePackageAnalysisFilter(normalized)) {
        hint = 'filter_analyses';
      } else if (_looksLikePackageCompare(normalized)) {
        hint = 'compare_packages';
      } else if (_looksLikePackagePrice(normalized)) {
        hint = 'package_price';
      } else if (_looksLikePackageAnalysesQuestion(normalized)) {
        hint = 'package_analyses';
      } else if (_looksLikePackageLabQuestion(normalized)) {
        hint = 'package_lab';
      } else if (packageName.isNotEmpty) {
        hint = 'search';
      }
      return IntentResult(
        intent: AssistantIntent.findPackage,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          packageName: packageName.isNotEmpty ? packageName : null,
          analysis: analysisTerms.isNotEmpty ? analysisTerms.first : analysisName,
          analysisTerms: analysisTerms,
          laboratory: labName,
          doctorName: null,
          actionHint: hint,
        ),
        confidence: 88,
        requiresContext: packageName.isEmpty &&
            analysisTerms.isEmpty &&
            (hint == 'package_price' ||
                hint == 'package_analyses' ||
                hint == 'package_lab' ||
                hint == 'compare_packages'),
      );
    }

    // 2a) بحث/توفر تحليل بالاسم — قبل كتالوج مختبر.
    if (analysisName != null || _looksLikeAnalysisSearch(normalized, original)) {
      final name = analysisName ??
          _extractFallbackAnalysisName(original, normalized);
      if (name != null && name.isNotEmpty) {
        String? hint = entities.actionHint;
        if (_looksLikePackagesForAnalysis(normalized)) {
          hint = 'packages_for_analysis';
        } else if (_looksLikeLabsForAnalysis(normalized)) {
          hint = 'labs_for_analysis';
        } else if (_looksLikeWhereAnalysis(normalized)) {
          hint = 'where_analysis';
        }
        return IntentResult(
          intent: AssistantIntent.findAnalysis,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            analysis: name,
            laboratory: null,
            doctorName: null,
            actionHint: hint ?? 'search',
          ),
          confidence: 88,
          requiresContext: false,
        );
      }
    }

    // سياقي: بأي باقة؟ / وين موجود؟ / أي مختبر؟ بدون اسم — يعتمد على selectedAnalysis.
    if (_looksLikePackagesForAnalysis(normalized) ||
        _looksLikeWhereAnalysis(normalized) ||
        _looksLikeLabsForAnalysis(normalized)) {
      return IntentResult(
        intent: AssistantIntent.findAnalysis,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          actionHint: _looksLikeLabsForAnalysis(normalized)
              ? 'labs_for_analysis'
              : (_looksLikePackagesForAnalysis(normalized)
                  ? 'packages_for_analysis'
                  : 'where_analysis'),
        ),
        confidence: 84,
        requiresContext: true,
      );
    }

    // 2b) باقات / تحاليل — مرتبطة بالمختبر (كتالوج باقات المختبر).
    if (_looksLikePackages(normalized)) {
      return IntentResult(
        intent: AssistantIntent.findPackage,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          laboratory: labName,
          actionHint: 'packages',
        ),
        confidence: labName != null ? 88 : 84,
        requiresContext: labName == null,
      );
    }
    if (_looksLikeLabAnalysesCatalogue(normalized)) {
      return IntentResult(
        intent: AssistantIntent.findAnalysis,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          laboratory: labName,
          analysis: null,
          actionHint: 'lab_catalogue',
        ),
        confidence: labName != null ? 88 : 84,
        requiresContext: labName == null,
      );
    }

    // 2b) موقع — صريح أو سياقي (طبيب أو مختبر).
    if (_looksLikeLocation(normalized)) {
      if (hasLabEntity || RegExp(r'(?:ال)?مختبر').hasMatch(normalized)) {
        return IntentResult(
          intent: AssistantIntent.showLocation,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            laboratory: labName,
            doctorName: null,
            actionHint: 'location',
          ),
          confidence: labName != null ? 88 : 85,
          requiresContext: labName == null,
        );
      }
      final hasName = _hasExplicitDoctorName(entities.doctorName);
      return IntentResult(
        intent: AssistantIntent.showLocation,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          doctorName: hasName ? entities.doctorName : null,
          actionHint: 'location',
        ),
        confidence: hasName ? 88 : 85,
        requiresContext: !hasName,
      );
    }

    // 2c) اتصال / واتساب — نعيد استخدام محلّل الأوامر المختبَر + مفردات عراقية.
    final contact = VoiceContactCommand.tryParse(original);
    if (contact != null) {
      // مسار مختبر صريح: «اتصل بمختبر الحياة»
      if (hasLabEntity || RegExp(r'(?:ال)?مختبر').hasMatch(normalized)) {
        final contextualLab = labName == null;
        if (contact.kind == VoiceContactKind.whatsapp) {
          return IntentResult(
            intent: AssistantIntent.messageLab,
            originalText: original,
            normalizedText: normalized,
            searchMeaning: meaning,
            entities: entities.copyWith(
              laboratory: labName,
              doctorName: null,
              actionHint: 'whatsapp',
            ),
            confidence: contextualLab ? 86 : 90,
            requiresContext: contextualLab,
          );
        }
        return IntentResult(
          intent: AssistantIntent.callLab,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            laboratory: labName,
            doctorName: null,
            actionHint: 'call',
          ),
          confidence: contextualLab ? 86 : 90,
          requiresContext: contextualLab,
        );
      }

      final target = contact.targetQuery.trim();
      final extractedName = (entities.doctorName ?? '').trim();
      final contextualTarget = _needsContextualTarget(
        normalized: normalized,
        contactTarget: target,
        extractedName: extractedName,
      );
      final name = contextualTarget
          ? null
          : (extractedName.isNotEmpty
              ? extractedName
              : ArabicTextUtils.prepareDoctorNameQuery(target));
      if (contact.kind == VoiceContactKind.whatsapp) {
        return IntentResult(
          intent: AssistantIntent.messageDoctor,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            doctorName: name,
            actionHint: 'whatsapp',
          ),
          confidence: contextualTarget ? 86 : 90,
          requiresContext: contextualTarget,
        );
      }
      return IntentResult(
        intent: AssistantIntent.callDoctor,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          doctorName: name,
          actionHint: 'call',
        ),
        confidence: contextualTarget ? 86 : 90,
        requiresContext: contextualTarget,
      );
    }

    // صيغ اتصال إضافية (دق / دك / احجي وياه) إن فاتها VoiceContactCommand.
    if (_looksLikeCallVocab(normalized)) {
      if (hasLabEntity || RegExp(r'(?:ال)?مختبر').hasMatch(normalized)) {
        return IntentResult(
          intent: AssistantIntent.callLab,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            laboratory: labName,
            doctorName: null,
            actionHint: 'call',
          ),
          confidence: 84,
          requiresContext: labName == null,
        );
      }
      final hasName = _hasExplicitDoctorName(entities.doctorName);
      return IntentResult(
        intent: AssistantIntent.callDoctor,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          doctorName: hasName ? entities.doctorName : null,
          actionHint: 'call',
        ),
        confidence: 84,
        requiresContext: !hasName,
      );
    }

    // صيغ واتساب إضافية (دزله…) + تصحيح «لا، دزله واتساب».
    if (_looksLikeWhatsAppVocab(normalized)) {
      final correction = RegExp(
        r'(?:^|\s)(?:لا|لاء|مو|بدل)(?=\s|$)',
      ).hasMatch(normalized);
      if (!correction &&
          (hasLabEntity || RegExp(r'(?:ال)?مختبر').hasMatch(normalized))) {
        return IntentResult(
          intent: AssistantIntent.messageLab,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            laboratory: labName,
            doctorName: null,
            actionHint: 'whatsapp',
          ),
          confidence: 84,
          requiresContext: labName == null,
        );
      }
      final hasName =
          !correction && _hasExplicitDoctorName(entities.doctorName);
      return IntentResult(
        intent: AssistantIntent.messageDoctor,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          doctorName: hasName ? entities.doctorName : null,
          actionHint: 'whatsapp',
        ),
        confidence: correction ? 87 : 84,
        requiresContext: !hasName,
      );
    }

    // 2d) فتح ملف / نبذة / معلومات المختبر.
    if (_looksLikeProfile(normalized)) {
      if (hasLabEntity || RegExp(r'(?:ال)?مختبر').hasMatch(normalized)) {
        return IntentResult(
          intent: AssistantIntent.showProfile,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            laboratory: labName,
            doctorName: null,
            actionHint: 'profile',
          ),
          confidence: labName != null ? 86 : 84,
          requiresContext: labName == null,
        );
      }
      final hasName = _hasExplicitDoctorName(entities.doctorName);
      return IntentResult(
        intent: AssistantIntent.showProfile,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          doctorName: hasName ? entities.doctorName : null,
          actionHint: 'profile',
        ),
        confidence: hasName ? 86 : 84,
        requiresContext: !hasName,
      );
    }

    // 3) اختصاص — نفس منطق VoiceSpecialtySearchCommand للنص والصوت.
    final specialty = VoiceSpecialtySearchCommand.tryParse(original);
    if (specialty != null) {
      return IntentResult(
        intent: AssistantIntent.specialtySearch,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(specialty: specialty.resolvedSpecialtyName),
        confidence: 90,
      );
    }

    // 4) بحث مختبر.
    if (_looksLikeLabSearch(normalized) || labName != null) {
      return IntentResult(
        intent: AssistantIntent.findLab,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(laboratory: labName),
        confidence: labName != null ? 80 : 70,
      );
    }

    // 5) بحث طبيب بالاسم.
    if (ArabicTextUtils.looksLikeDoctorNameQuery(original) ||
        (entities.doctorName != null && entities.doctorName!.trim().isNotEmpty)) {
      final doctorName = entities.doctorName ??
          ArabicTextUtils.prepareDoctorNameQuery(
            ArabicTextUtils.stripHonorifics(original),
          );
      if (doctorName.isNotEmpty) {
        return IntentResult(
          intent: AssistantIntent.doctorSearch,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(doctorName: doctorName),
          confidence: 75,
        );
      }
    }

    // 6) إشارات عامة.
    if (_looksLikeDoctorOrSpecialtySearch(meaning)) {
      return IntentResult(
        intent: entities.specialty != null
            ? AssistantIntent.specialtySearch
            : AssistantIntent.doctorSearch,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities,
        confidence: 55,
      );
    }

    if (meaning.isNotEmpty) {
      return IntentResult(
        intent: AssistantIntent.generalSearch,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities,
        confidence: 40,
      );
    }

    return IntentResult.unknown(original, normalized);
  }

  /// جملة ترتيبية سياقية فقط — بعد إزالة أفعال الاختيار/الألقاب/الترتيب لا يبقى اسم.
  static bool _isPureContextualOrdinal(String n) {
    var stripped = n
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:اختار|اختَر|اريد|أريد|ابي|افتح|فتح|عرض|وريني|منهم|منهن|هذا|هاي|الطبيب|الدكتور|دكتور|طبيب|المختبر|مختبر)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:الاول|الأول|اول|أول|الاولى|الأولى|الاولي|اولي|أولى|الثاني|ثاني|الثانيه|الثانية|ثانيه|ثانية|الثالث|ثالث|الثالثه|الثالثة|الرابع|رابع|الرابعه|الرابعة|الخامس|خامس|الخامسه|الخامسة|الاخير|الأخير|اخر|آخر|الاخيره|الأخيرة)(?:\s*واحد)?(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'(?:^|\s)رقم\s*[123١٢٣](?=\s|$)'),
          ' ',
        )
        .replaceAll(
          RegExp(r'(?:^|\s)واحد(?=\s|$)'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped.isEmpty;
  }

  static bool _isContextualReference(String target) {
    final t = ArabicTextUtils.normalize(target);
    if (t.isEmpty) return true;
    if (_isRoleOnlyWord(t)) return true;
    if (_isOrdinalOnly(t)) return true;
    return RegExp(
      r'^(?:بيه|به|يه|بيها|بها|وياه|عليه|عليها|عليهم|بيهم|'
      r'هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|'
      r'هذا\s*الطبيب|هذا\s*الدكتور)$',
    ).hasMatch(t);
  }

  static bool _isOrdinalOnly(String raw) {
    var t = ArabicTextUtils.normalize(raw.trim());
    t = t.replaceFirst(RegExp(r'^(?:ل|ب|على)'), '').trim();
    return RegExp(
      r'^(?:ال)?(?:اول|أول|ثاني|ثالث|رابع|خامس|اخير|أخير)(?:\s*واحد)?$',
    ).hasMatch(t);
  }

  /// لقب مهني بدون اسم — إشارة للطبيب المحدد سياقياً وليست كيان بحث.
  static bool _isRoleOnlyWord(String raw) {
    final t = ArabicTextUtils.normalize(raw.trim());
    if (t.isEmpty) return true;
    return RegExp(
      r'^(?:ال)?(?:دكتور|دكتوره|دكتورة|طبيب|طبيبه|طبيبة|مختبر)$',
    ).hasMatch(t);
  }

  /// هدف سياقي إن كان الضمير/بقايا الفعل/اللقب فقط — لا اسم صريح.
  static bool _needsContextualTarget({
    required String normalized,
    required String contactTarget,
    required String extractedName,
  }) {
    if (_hasContextualPronoun(normalized)) return true;
    if (_isCorrectionSwitch(normalized)) return true;
    if (_isContextualReference(contactTarget)) return true;
    if (_isRoleOnlyWord(contactTarget)) return true;
    if (_isNoiseOnlyTarget(contactTarget)) return true;
    if (_isRoleOnlyWord(extractedName)) return true;
    if (!_hasExplicitDoctorName(extractedName) &&
        !_hasExplicitDoctorName(contactTarget)) {
      return true;
    }
    return false;
  }

  static bool _isCorrectionSwitch(String n) {
    return RegExp(r'(?:^|\s)(?:لا|لاء|مو|بدل)(?=\s|$|[،,])').hasMatch(n) &&
        (_looksLikeWhatsAppVocab(n) || _looksLikeCallVocab(n));
  }

  static bool _isNoiseOnlyTarget(String raw) {
    final tokens = ArabicTextUtils.normalize(raw)
        .replaceAll(RegExp(r'[،,؟?!.]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return true;
    return tokens.every(
      (t) =>
          _isActionVocabToken(t) ||
          _isContextualReference(t) ||
          _isRoleOnlyWord(t),
    );
  }

  static bool _hasContextualPronoun(String n) {
    return RegExp(
      r'(?:^|\s)(?:بيه|به|بيها|بها|وياه|عليه|عليها|عليهم|بيهم|'
      r'هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|'
      r'ملفه|نبذته|عيادته|مكانه|موقعه)(?:\s|$|[؟?!.،])',
    ).hasMatch(n);
  }

  static bool _hasExplicitDoctorName(String? name) {
    final cleaned = ArabicTextUtils.normalize((name ?? '').trim())
        .replaceAll(RegExp(r'[،,؟?!.]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty || cleaned.length <= 1) return false;
    if (_isContextualReference(cleaned) ||
        _isActionVocabToken(cleaned) ||
        _isRoleOnlyWord(cleaned) ||
        _isOrdinalOnly(cleaned)) {
      return false;
    }
    if (_isNoiseOnlyTarget(cleaned)) return false;
    final tokens = cleaned.split(RegExp(r'\s+'));
    final meaningful = tokens.where(
      (t) =>
          !_isActionVocabToken(t) &&
          !_isContextualReference(t) &&
          !_isRoleOnlyWord(t) &&
          !_isOrdinalOnly(t),
    );
    return meaningful.any((t) => t.length > 1);
  }

  static bool _isActionVocabToken(String raw) {
    final t = ArabicTextUtils.normalize(raw.trim());
    if (t.isEmpty) return true;
    return RegExp(
      r'^(?:دزله|دزّله|دزوله|راسله|راسل|ارسل|أرسل|رسالة|رساله|اتصل|اتصال|دق|دك|احجي|وياه|واتساب|واتس|whatsapp|لا|لاء|مو|بدل)$',
    ).hasMatch(t);
  }

  static bool _looksLikeLocation(String n) {
    return RegExp(
          r'(?:وين|اين|أين).{0,28}(?:عياد|مكان|موقع|عنوان|مختبر)',
        ).hasMatch(n) ||
        RegExp(r'(?:عيادته|عيادتها|مكانه|موقعه|عنوانه)').hasMatch(n) ||
        RegExp(r'^(?:العنوان|الموقع)$').hasMatch(n.trim()) ||
        RegExp(r'وين\s+(?:ال)?مختبر').hasMatch(n);
  }

  static bool _looksLikeCallVocab(String n) {
    return RegExp(
      r'(?:اتصل|اتصال|دقله|دگله|(?:^|\s)(?:دق|دك)(?:\s|$)|احجي\s*وياه)',
    ).hasMatch(n);
  }

  static bool _looksLikeWhatsAppVocab(String n) {
    return RegExp(
      r'(?:واتساب|واتس|whatsapp|دزله|دزّله|دزوله|دز\b|راسله|راسل|احجي\s*وياه\s*واتس)',
    ).hasMatch(n);
  }

  static bool _looksLikeProfile(String n) {
    return RegExp(
          r'(?:افتح|اعرض).{0,28}(?:ملف|نبذه|نبذة|بطاقه|بطاقة|مختبر)',
        ).hasMatch(n) ||
        RegExp(r'(?:ملفه|نبذته|معلومات\s*عنه|عرض\s*الملف)').hasMatch(n) ||
        RegExp(r'(?:افتح|اعرض)\s+(?:ال)?(?:دكتور|طبيب|ملف|مختبر)').hasMatch(n) ||
        RegExp(
          r'(?:افتح|اعرض|اختار)\s+(?:هذا|هاي|هذي|هذه|هذاك|ذاك)',
        ).hasMatch(n) ||
        RegExp(r'(?:نبذة|معلومات)\s*(?:ال)?مختبر').hasMatch(n);
  }

  static bool _looksLikePackages(String n) {
    return RegExp(
      r'(?:باقات|باقاته|الباقات)|(?:عرض(?:لي)?\s*(?:ال)?باق)|(?:شنو\s+(?:عنده\s+)?باق)|(?:أريد|اريد|ابي).{0,12}(?:باقات|باقه|باقة)',
    ).hasMatch(n);
  }

  static bool _looksLikeOffers(String n) {
    return RegExp(
      r'(?:^|\s)(?:ال)?(?:عروض|عرض)(?=\s|$)|(?:اكو|أكو)\s+(?:عروض|عرض)|(?:تخفيض|مخفضه|مخفضة)|(?:الباقات\s+المخف)',
    ).hasMatch(n);
  }

  static bool _looksLikeBestPackage(String n) {
    return RegExp(r'(?:افضل|أفضل)\s+(?:باقه|باقة|عرض)').hasMatch(n);
  }

  static bool _looksLikeCheapestPackage(String n) {
    return RegExp(r'(?:ارخص|أرخص)\s+(?:باقه|باقة|عرض)').hasMatch(n) ||
        RegExp(r'(?:اقل|أقل)\s+سعر').hasMatch(n);
  }

  static bool _looksLikePackageAnalysisFilter(String n) {
    // يتطلب تحليلاً مسمّى بعد بيها/فيها — ليس «الباقات اللي بيها» السياقي (Step 7).
    return RegExp(
      r'(?:باق(?:ه|ة|ات).{0,30}(?:بيها|فيها|تحتوي)\s+\S)',
    ).hasMatch(n);
  }

  static bool _looksLikePackageCompare(String n) {
    return RegExp(r'(?:قارن|مقارن|الفرق\s+بين)').hasMatch(n);
  }

  static bool _looksLikePackagePrice(String n) {
    return RegExp(
      r'(?:شكد|بكم)\s*(?:سعرها|سعره|سعر)?|(?:سعرها|سعره|السعر)\s*$|(?:سعر\s+(?:ال)?(?:باقه|باقة))',
    ).hasMatch(n.trim());
  }

  static bool _looksLikePackageAnalysesQuestion(String n) {
    // تحاليل الباقة المحددة — ليس كتالوج «شنو التحاليل الموجودة» للمختبر.
    return RegExp(r'(?:تحاليلها|تحاليله)').hasMatch(n) ||
        RegExp(
          r'(?:شنو\s+(?:ال)?تحاليل\s+(?:بيها|فيها|(?:ال)?باق))',
        ).hasMatch(n);
  }

  static bool _looksLikePackageLabQuestion(String n) {
    return RegExp(
      r'(?:اي\s+مختبر)|(?:أي\s+مختبر)|(?:المختبر\s+(?:حقها|تاعها|مالها))',
    ).hasMatch(n);
  }

  /// كتالوج تحاليل المختبر المحدد — بدون اسم تحليل صريح.
  static bool _looksLikeLabAnalysesCatalogue(String n) {
    return RegExp(
      r'(?:شنو\s+(?:ال)?تحاليل)|(?:التحاليل\s+(?:الموجودة|بهذا|بيها))|(?:تحاليله|تحاليل\s+هذا\s*المختبر)',
    ).hasMatch(n);
  }

  static bool _looksLikeAnalysisSearch(String n, String original) {
    if (RegExp(r'(?:أريد|اريد|ابي|ابحث|دور|عندكم|عندك).{0,20}(?:تحليل)').hasMatch(n)) {
      return true;
    }
    if (RegExp(r'^(?:ال)?تحليل\s+\S+').hasMatch(n.trim())) return true;
    if (RegExp(r'(?:وين\s+موجود).{0,20}(?:تحليل)').hasMatch(n)) return true;
    // أسماء شائعة بدون كلمة «تحليل».
    if (RegExp(
      r'(?:فيتامين\s*(?:د|دي|دال|d3?)\b)|(?:\bhba1c\b)|(?:\bcbc\b)|(?:\btsh\b)',
      caseSensitive: false,
    ).hasMatch(n) ||
        RegExp(
          r'(?:فيتامين\s*(?:د|دي|دال))|(?:هيموغلوبين\s*سكري)|(?:السكر\s*التراكمي)',
        ).hasMatch(n)) {
      return true;
    }
    // اختصار لاتيني وحيد.
    if (RegExp(r'^[A-Za-z][A-Za-z0-9.\s\-]{1,20}$').hasMatch(original.trim())) {
      return true;
    }
    return false;
  }

  static bool _looksLikePackagesForAnalysis(String n) {
    // بعد ArabicTextUtils.normalize: بأي → باي، باقة → باقه.
    return RegExp(
      r'(?:باي\s+باق)|(?:الباقات\s+اللي\s+بيها)|(?:شنو\s+الباقات\s+اللي)|'
      r'(?:هذا\s+التحليل\s+باي\s+باق)|(?:ضمن\s+اي\s+باق)',
    ).hasMatch(n);
  }

  static bool _looksLikeLabsForAnalysis(String n) {
    // بعد التطبيع: أي → اي
    return RegExp(
      r'(?:اي\s+مختبر\s+عنده)|(?:اي\s+مختبرات)|(?:المختبرات\s+اللي)|'
      r'(?:مختبر\s+عنده\s+هذا)',
    ).hasMatch(n);
  }

  static bool _looksLikeWhereAnalysis(String n) {
    return RegExp(r'^(?:وين|اين|أين)\s*موجود').hasMatch(n.trim()) ||
        RegExp(r'وين\s+موجود\s*(?:هذا\s*)?(?:ال)?تحليل').hasMatch(n);
  }

  static bool _hasExplicitAnalysisName(String? name) {
    final cleaned = (name ?? '').trim();
    if (cleaned.isEmpty || cleaned.length <= 1) return false;
    if (RegExp(r'^(?:ال)?(?:تحليل|تحاليل)$').hasMatch(ArabicTextUtils.normalize(cleaned))) {
      return false;
    }
    return true;
  }

  static String? _extractFallbackAnalysisName(String original, String normalized) {
    final m = RegExp(r'(?:ال)?تحليل\s+(.+)$').firstMatch(normalized);
    if (m != null) {
      final t = m.group(1)?.trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    if (RegExp(r'^[A-Za-z][A-Za-z0-9.\s\-]{1,20}$').hasMatch(original.trim())) {
      return original.trim();
    }
    return null;
  }

  static bool _looksLikeLabSearch(String n) {
    return RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور).{0,16}(?:مختبر|مختبرات)',
        ).hasMatch(n) ||
        RegExp(r'^(?:ال)?مختبر(?:ات)?(?:\s+|$)').hasMatch(n.trim()) ||
        RegExp(r'(?:^|\s)(?:ال)?مختبر\s+\S+').hasMatch(n);
  }

  static bool _mentionsLab(String n) =>
      RegExp(r'(?:ال)?مختبر(?:ات)?').hasMatch(n);

  static bool _hasExplicitLabName(String? name) {
    final cleaned = ArabicTextUtils.normalize((name ?? '').trim());
    if (cleaned.isEmpty || cleaned.length <= 1) return false;
    if (RegExp(r'^(?:ال)?(?:مختبر|مختبرات)$').hasMatch(cleaned)) return false;
    if (RegExp(
      r'^(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|الاول|الأول|الثاني|الثالث)$',
    ).hasMatch(cleaned)) {
      return false;
    }
    return true;
  }

  static bool _looksLikeDoctorOrSpecialtySearch(String meaning) {
    return RegExp(r'(?:طبيب|دكتور|اختصاص|تخصص|اطفال|عياده)').hasMatch(meaning);
  }

  /// Step 9: ارجع للطبيب/المختبر/التحليل/الباقة.
  static String? _returnFocusHint(String n) {
    if (RegExp(
      r'(?:ارجع|ارجعي|رجع|رجعني)\s+(?:ل|لل|الى|إلى)?\s*(?:ال)?(?:طبيب|دكتور)',
    ).hasMatch(n)) {
      return 'return_doctor';
    }
    if (RegExp(
      r'(?:ارجع|ارجعي|رجع|رجعني)\s+(?:ل|لل|الى|إلى)?\s*(?:ال)?مختبر',
    ).hasMatch(n)) {
      return 'return_lab';
    }
    if (RegExp(
      r'(?:ارجع|ارجعي|رجع|رجعني)\s+(?:ل|لل|الى|إلى)?\s*(?:ال)?تحليل',
    ).hasMatch(n)) {
      return 'return_analysis';
    }
    if (RegExp(
      r'(?:ارجع|ارجعي|رجع|رجعني)\s+(?:ل|لل|الى|إلى)?\s*(?:ال)?باق',
    ).hasMatch(n)) {
      return 'return_package';
    }
    return null;
  }
}
