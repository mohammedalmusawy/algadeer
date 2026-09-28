import '../../search/arabic_text_utils.dart';
import '../../search/voice_contact_command.dart';
import '../../search/voice_specialty_search_command.dart';
import '../context_resolver.dart';
import 'assistant_intent.dart';
import 'entity_extractor.dart';
import 'ghadeer_scope_gate.dart';
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
    // توحيد أخطاء واتساب/راسل قبل أي استخراج — ينطبق على أي طبيب/مختبر جديد.
    final prepared = ArabicTextUtils.prepareQuery(
      VoiceContactCommand.canonicalizeAliases(query),
    );
    if (prepared.originalText.isEmpty) {
      return IntentResult.unknown('', '');
    }

    final original = prepared.originalText;
    final normalized = prepared.normalizedText;
    final meaning = prepared.searchMeaning;
    final entities = _extractor.extract(original, normalized);

    // 0) أوامر صوت قصيرة: إيقاف النطق / إعادة آخر رد — قبل البحث العام.
    // جمل ضيقة فقط حتى لا تسرق «وقف متابعة» أو أوامر أخرى.
    if (_looksLikeStopSpeaking(normalized)) {
      return IntentResult(
        intent: AssistantIntent.stopSpeaking,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        confidence: 96,
      );
    }
    if (_looksLikeRepeatResponse(normalized)) {
      return IntentResult(
        intent: AssistantIntent.repeatResponse,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        confidence: 96,
      );
    }

    // 0b) خارج نطاق الغدير مبكرًا — قبل تصنيف خاطئ كبحث طبيب/اسم.
    // معرفة عامة واضحة تفوز على أي إشارة ضعيفة.
    if (GhadeerScopeGate.isOutOfScope(original) ||
        GhadeerScopeGate.isOutOfScope(normalized) ||
        GhadeerScopeGate.isOutOfScope(meaning)) {
      return IntentResult.unknown(original, normalized);
    }

    // تصحيح نوع الخدمة: «لا قصدي X قصدي Y» — الغالبية للهدف الأخير بعد قصدي/أقصد.
    final correctionIntent = _intentFromCorrectionPhrase(normalized);
    if (correctionIntent != null) {
      return IntentResult(
        intent: correctionIntent,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities,
        confidence: 91,
        requiresContext: false,
      );
    }


    // 1) اختيار ترتيبي — فقط للجمل السياقية النقية (الثاني / اختار الثاني).
    // لا يبتلع «أريد دكتور علي الثاني» كـ selectResult.
    final ordinalCorrection = _extractOrdinalCorrection(normalized);
    if (ordinalCorrection != null) {
      return IntentResult(
        intent: AssistantIntent.selectResult,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(resultIndex: ordinalCorrection),
        confidence: 93,
        requiresContext: true,
      );
    }
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
        ? ArabicTextUtils.prepareLabNameQuery(entities.laboratory!)
        : null;
    final hasRadiologyEntity = _hasExplicitRadiologyName(entities.radiology) ||
        _mentionsRadiology(normalized);
    final radiologyName = _hasExplicitRadiologyName(entities.radiology)
        ? ArabicTextUtils.prepareRadiologyNameQuery(entities.radiology!)
        : null;
    final hasPharmacyEntity = _hasExplicitPharmacyName(entities.pharmacy) ||
        _mentionsPharmacy(normalized);
    final pharmacyName = _hasExplicitPharmacyName(entities.pharmacy)
        ? ArabicTextUtils.preparePharmacyNameQuery(entities.pharmacy!)
        : null;
    final hasPhysioEntity = _hasExplicitPhysioName(entities.physio) ||
        _mentionsPhysio(normalized);
    final physioName = _hasExplicitPhysioName(entities.physio)
        ? ArabicTextUtils.preparePhysioNameQuery(entities.physio!)
        : null;
    final hasSupplyEntity = _hasExplicitSupplyName(entities.supply) ||
        _mentionsSupply(normalized);
    final supplyName = _hasExplicitSupplyName(entities.supply)
        ? ArabicTextUtils.prepareSupplyNameQuery(entities.supply!)
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
    // لا تبتلع «عرض المزيد» كعروض.
    if (_looksLikeShowMore(normalized)) {
      return IntentResult(
        intent: AssistantIntent.showMore,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        confidence: 92,
        requiresContext: true,
      );
    }
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

    // كتالوج باقات («باقة تحليلات» / «بحثلي عن باقة») قبل مسار التحليل
    // حتى لا تُسرق كلمة «تحليلات» كاسم تحليل.
    if (_looksLikePackages(normalized)) {
      return IntentResult(
        intent: AssistantIntent.findPackage,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          packageName: packageName.isNotEmpty ? packageName : null,
          laboratory: labName,
          doctorName: null,
          analysis: null,
          actionHint: entities.actionHint ?? 'list',
        ),
        confidence: 86,
        requiresContext: false,
      );
    }

    // 2a) بحث/توفر تحليل بالاسم — قبل كتالوج مختبر.
    // «مختبر تحاليل» = بحث مختبر (وصف نوع) وليس findAnalysis.
    final labFramedAnalysisCatalogue = RegExp(r'مختبر').hasMatch(normalized) &&
        !_hasExplicitAnalysisName(analysisName) &&
        !RegExp(r'(?:ال)?تحليل\s+\S{2,}').hasMatch(normalized);
    if (!labFramedAnalysisCatalogue &&
        (analysisName != null ||
            _looksLikeAnalysisSearch(normalized, original) ||
            entities.actionHint == 'analyses')) {
      final name = analysisName ??
          _extractFallbackAnalysisName(original, normalized);
      if (name != null &&
          name.isNotEmpty &&
          _hasExplicitAnalysisName(name)) {
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
      // «تحليل» / «أريد تحليل» بلا اسم صريح → مسار التحاليل (توضيح/كتالوج)
      // وليس doctorSearch باسم «تحليل».
      if (_looksLikeAnalysisSearch(normalized, original) ||
          entities.actionHint == 'analyses') {
        return IntentResult(
          intent: AssistantIntent.findAnalysis,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            analysis: null,
            laboratory: null,
            doctorName: null,
            actionHint: 'lab_catalogue',
          ),
          confidence: 84,
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

    // 2b) باقات — احتياطي إن وصلنا هنا (المسار الأساسي صار قبل التحليل).
    if (_looksLikePackages(normalized)) {
      return IntentResult(
        intent: AssistantIntent.findPackage,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          laboratory: labName,
          doctorName: null,
          analysis: null,
          actionHint: entities.actionHint ?? 'packages',
        ),
        confidence: labName != null ? 88 : 84,
        requiresContext: false,
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
      // مسار صيدلية صريح — قبل الأشعة/المختبر.
      if (hasPharmacyEntity ||
          RegExp(r'(?:ال)?(?:صيدليه|صيدلية|صيدليات)').hasMatch(normalized)) {
        final fromContact =
            _pharmacyNameFromContactTarget(contact.targetQuery);
        final resolved = (fromContact != null && fromContact.isNotEmpty)
            ? fromContact
            : pharmacyName;
        final contextual =
            resolved == null || resolved.trim().isEmpty;
        if (contact.kind == VoiceContactKind.whatsapp) {
          return IntentResult(
            intent: AssistantIntent.messagePharmacy,
            originalText: original,
            normalizedText: normalized,
            searchMeaning: meaning,
            entities: entities.copyWith(
              pharmacy: contextual ? null : resolved,
              radiology: null,
              laboratory: null,
              doctorName: null,
              actionHint: 'whatsapp',
            ),
            confidence: contextual ? 86 : 90,
            requiresContext: contextual,
          );
        }
        return IntentResult(
          intent: AssistantIntent.callPharmacy,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            pharmacy: contextual ? null : resolved,
            radiology: null,
            laboratory: null,
            doctorName: null,
            actionHint: 'call',
          ),
          confidence: contextual ? 86 : 90,
          requiresContext: contextual,
        );
      }

      // مسار علاج طبيعي صريح — قبل الأشعة/المختبر.
      // STT: علااج / فيزيييو عبر + على الحروف المكرّرة.
      if (hasPhysioEntity ||
          RegExp(r'(?:ال)?(?:علا+ج\s*طبي+عي|فيزي+و|تاهيل|تأهيل)')
              .hasMatch(normalized)) {
        final fromContact = _physioNameFromContactTarget(contact.targetQuery);
        final resolved = (fromContact != null && fromContact.isNotEmpty)
            ? fromContact
            : physioName;
        final contextual =
            resolved == null || resolved.trim().isEmpty;
        if (contact.kind == VoiceContactKind.whatsapp) {
          return IntentResult(
            intent: AssistantIntent.messagePhysio,
            originalText: original,
            normalizedText: normalized,
            searchMeaning: meaning,
            entities: entities.copyWith(
              physio: contextual ? null : resolved,
              supply: null,
              pharmacy: null,
              radiology: null,
              laboratory: null,
              doctorName: null,
              actionHint: 'whatsapp',
            ),
            confidence: contextual ? 86 : 90,
            requiresContext: contextual,
          );
        }
        return IntentResult(
          intent: AssistantIntent.callPhysio,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            physio: contextual ? null : resolved,
            supply: null,
            pharmacy: null,
            radiology: null,
            laboratory: null,
            doctorName: null,
            actionHint: 'call',
          ),
          confidence: contextual ? 86 : 90,
          requiresContext: contextual,
        );
      }

      // مسار مستلزمات صريح — قبل الأشعة/المختبر.
      if (hasSupplyEntity ||
          RegExp(r'(?:ال)?(?:مستلزم+ات|تجهيزا+ت|مواد\s*طبيه|معدات\s*طبيه)')
              .hasMatch(normalized)) {
        final fromContact = _supplyNameFromContactTarget(contact.targetQuery);
        final resolved = (fromContact != null && fromContact.isNotEmpty)
            ? fromContact
            : supplyName;
        final contextual =
            resolved == null || resolved.trim().isEmpty;
        if (contact.kind == VoiceContactKind.whatsapp) {
          return IntentResult(
            intent: AssistantIntent.messageSupply,
            originalText: original,
            normalizedText: normalized,
            searchMeaning: meaning,
            entities: entities.copyWith(
              supply: contextual ? null : resolved,
              physio: null,
              pharmacy: null,
              radiology: null,
              laboratory: null,
              doctorName: null,
              actionHint: 'whatsapp',
            ),
            confidence: contextual ? 86 : 90,
            requiresContext: contextual,
          );
        }
        return IntentResult(
          intent: AssistantIntent.callSupply,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            supply: contextual ? null : resolved,
            physio: null,
            pharmacy: null,
            radiology: null,
            laboratory: null,
            doctorName: null,
            actionHint: 'call',
          ),
          confidence: contextual ? 86 : 90,
          requiresContext: contextual,
        );
      }

      // مسار أشعة صريح — قبل المختبر حتى لا يُخلط مع كلمات أخرى.
      if (hasRadiologyEntity ||
          RegExp(r'(?:ال)?(?:اشعه|اشعة|أشعة)').hasMatch(normalized)) {
        final fromContact =
            _radiologyNameFromContactTarget(contact.targetQuery);
        final resolved = (fromContact != null && fromContact.isNotEmpty)
            ? fromContact
            : radiologyName;
        final contextual =
            resolved == null || resolved.trim().isEmpty;
        if (contact.kind == VoiceContactKind.whatsapp) {
          return IntentResult(
            intent: AssistantIntent.messageRadiology,
            originalText: original,
            normalizedText: normalized,
            searchMeaning: meaning,
            entities: entities.copyWith(
              radiology: contextual ? null : resolved,
              laboratory: null,
              doctorName: null,
              actionHint: 'whatsapp',
            ),
            confidence: contextual ? 86 : 90,
            requiresContext: contextual,
          );
        }
        return IntentResult(
          intent: AssistantIntent.callRadiology,
          originalText: original,
          normalizedText: normalized,
          searchMeaning: meaning,
          entities: entities.copyWith(
            radiology: contextual ? null : resolved,
            laboratory: null,
            doctorName: null,
            actionHint: 'call',
          ),
          confidence: contextual ? 86 : 90,
          requiresContext: contextual,
        );
      }

      // مسار مختبر صريح: «اتصل بمختبر الحياة» / واتساب — نفس قواعد الأطباء.
      // الهدف من أمر الاتصال أوثق من استخراج الكيان (قد يلوّثه وتساب/رسالة).
      if (hasLabEntity || RegExp(r'(?:ال)?مختبر').hasMatch(normalized)) {
        final fromContact = _labNameFromContactTarget(contact.targetQuery);
        final resolvedLab = (fromContact != null && fromContact.isNotEmpty)
            ? fromContact
            : labName;
        final contextualLab =
            resolvedLab == null || resolvedLab.trim().isEmpty;
        if (contact.kind == VoiceContactKind.whatsapp) {
          return IntentResult(
            intent: AssistantIntent.messageLab,
            originalText: original,
            normalizedText: normalized,
            searchMeaning: meaning,
            entities: entities.copyWith(
              laboratory: contextualLab ? null : resolvedLab,
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
            laboratory: contextualLab ? null : resolvedLab,
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
      // هدف أمر الاتصال/واتساب أوثق من استخراج الكيان العام
      // (الذي قد يبقي «رسالة» داخل الاسم).
      final fromContact = target.isNotEmpty
          ? ArabicTextUtils.prepareDoctorNameQuery(target)
          : '';
      final name = contextualTarget
          ? null
          : (fromContact.isNotEmpty
              ? fromContact
              : (extractedName.isNotEmpty
                  ? ArabicTextUtils.prepareDoctorNameQuery(extractedName)
                  : null));
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

    // 2e) حجز سياقي قصير (احجز عنده) — بلا حجز تلقائي؛ الهدف من السياق فقط.
    if (_looksLikeContextualBooking(normalized)) {
      final hasName = _hasExplicitDoctorName(entities.doctorName);
      return IntentResult(
        intent: AssistantIntent.bookAppointment,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(
          doctorName: hasName ? entities.doctorName : null,
          actionHint: 'book',
        ),
        confidence: 84,
        requiresContext: !hasName,
      );
    }

    // 2f) مشاركة / مفضلة — توضيح آمن (التنفيذ من بطاقة التطبيق حالياً).
    if (_looksLikeShareOrFavorite(normalized)) {
      return IntentResult(
        intent: AssistantIntent.showProfile,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(actionHint: 'share_or_favorite'),
        confidence: 90,
        requiresContext: true,
      );
    }

    // 3) علاج طبيعي / مستلزمات / صيدلية — قبل الاختصاص حتى لا تُخطف جمل «مراكز علاج طبيعي».
    if (_looksLikePhysioSearch(normalized) || physioName != null) {
      return IntentResult(
        intent: AssistantIntent.findPhysio,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(physio: physioName),
        confidence: physioName != null ? 80 : 70,
      );
    }

    if (_looksLikeSupplySearch(normalized) || supplyName != null) {
      return IntentResult(
        intent: AssistantIntent.findSupply,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(supply: supplyName),
        confidence: supplyName != null ? 80 : 70,
      );
    }

    if (_looksLikePharmacySearch(normalized) || pharmacyName != null) {
      return IntentResult(
        intent: AssistantIntent.findPharmacy,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(pharmacy: pharmacyName),
        confidence: pharmacyName != null ? 80 : 70,
      );
    }

    // أشعة / مختبر قبل الاختصاص — «طلعلي اشعة» ليست اختصاصاً عاماً.
    if (_looksLikeRadiologySearch(normalized) || radiologyName != null) {
      return IntentResult(
        intent: AssistantIntent.findRadiology,
        originalText: original,
        normalizedText: normalized,
        searchMeaning: meaning,
        entities: entities.copyWith(radiology: radiologyName),
        confidence: radiologyName != null ? 80 : 70,
      );
    }

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

    // 4) اختصاص — نفس منطق VoiceSpecialtySearchCommand للنص والصوت.
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

    // 4a/4b احتياطي إن وصلنا هنا بلا تلميح أعلاه.

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

    // خارج نطاق الغدير → unknown (المخطِّط يرفض بلا بحث عام).
    if (GhadeerScopeGate.isOutOfScope(original) ||
        GhadeerScopeGate.isOutOfScope(normalized)) {
      return IntentResult.unknown(original, normalized);
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

  /// تصحيح ترتيب عراقي: «لا مو الثاني الأول» / «مو الثاني قصدي الأول».
  /// يعيد الترتيب المقصود (الأخير في الجملة)، لا المرفوض.
  static int? _extractOrdinalCorrection(String n) {
    final t = n
        .replaceAll(RegExp(r'[،,]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final ordinalTok =
        r'(?:ال)?(?:اول|أول|ثاني|ثالث|رابع|خامس|اخير|أخير)\S*(?:\s*واحد)?';
    final m = RegExp(
      '^(?:لا\\s+)?مو\\s+$ordinalTok'
      r'(?:\s+(?:قصدي|أقصد|اقصد))?\s+'
      '($ordinalTok)\$',
    ).firstMatch(t);
    if (m == null) return null;
    return ContextResolver.extractOrdinal(m.group(1)!);
  }

  /// «لا قصدي مختبر قصدي صيدلية» → نوع الهدف بعد آخر قصدي/أقصد.
  static AssistantIntent? _intentFromCorrectionPhrase(String n) {
    if (!RegExp(r'(?:قصدي|أقصد|اقصد)').hasMatch(n)) return null;
    // تصحيح ترتيب لا يُفسَّر كتبديل نوع.
    if (_extractOrdinalCorrection(n) != null) return null;
    final parts = n.split(RegExp(r'(?:قصدي|أقصد|اقصد)'));
    if (parts.length < 2) return null;
    final focus = parts.last.trim();
    if (focus.isEmpty) return null;
    if (_looksLikePharmacySearch(focus) || _mentionsPharmacy(focus)) {
      return AssistantIntent.findPharmacy;
    }
    if (_looksLikePhysioSearch(focus) || _mentionsPhysio(focus)) {
      return AssistantIntent.findPhysio;
    }
    if (_looksLikeSupplySearch(focus) || _mentionsSupply(focus)) {
      return AssistantIntent.findSupply;
    }
    if (_mentionsRadiology(focus)) return AssistantIntent.findRadiology;
    if (_mentionsLab(focus)) return AssistantIntent.findLab;
    if (_looksLikePackages(focus)) return AssistantIntent.findPackage;
    if (_looksLikeOffers(focus)) return AssistantIntent.findOffer;
    if (RegExp(r'(?:طبيب|دكتور|اطفال|أطفال|جهال|باطن|قلب)').hasMatch(focus)) {
      return AssistantIntent.specialtySearch;
    }
    return null;
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
    // «وين اكو مختبر» بحث كتالوج — ليس موقع كيان محدد.
    if (RegExp(r'(?:اكو|أكو|عدكم|عندكم|طلعلي|أريد|اريد)\s+.*(?:مختبر|صيدلي|اشع)')
        .hasMatch(n)) {
      return false;
    }
    return RegExp(
          r'(?:وين|اين|أين).{0,28}(?:عياد|مكان|موقع|عنوان)',
        ).hasMatch(n) ||
        RegExp(r'(?:عيادته|عيادتها|مكانه|موقعه|عنوانه)').hasMatch(n) ||
        RegExp(r'^(?:العنوان|الموقع|وينه|وينها|وينهم|مكانهم)$')
            .hasMatch(n.trim()) ||
        RegExp(r'وين\s+ال\s*مختبر(?:\s|$)').hasMatch(n) ||
        RegExp(r'دلني\s+عل(?:يه|يها|يهم)').hasMatch(n);
  }

  static bool _looksLikeCallVocab(String n) {
    return RegExp(
      r'(?:اتصل|اتصال|دقله|دگله|دكله|دكلهم|دكلها|'
      r'(?:^|\s)(?:دق|دك)(?:\s|$)|احجي\s*ويا(?:ه|ها)|أريد\s*أحجي|اريد\s*احجي)',
    ).hasMatch(n);
  }

  static bool _looksLikeWhatsAppVocab(String n) {
    return RegExp(
          r'(?:واتساب|واتس|وتساب|ووتساب|واتسب|whatsapp|watsapp|whatsap|'
          r'دزله|دزّله|دزوله|دز\b|راسله|راسل|مارسل|احجي\s*وياه\s*واتس)',
        ).hasMatch(n) ||
        n.contains('whatsapp') ||
        n.contains('watsapp');
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
        RegExp(r'^(?:افتحه|افتحها)\s*$').hasMatch(n.trim()) ||
        RegExp(r'(?:نبذة|معلومات)\s*(?:ال)?مختبر').hasMatch(n) ||
        RegExp(
          r'(?:شوف|طلع|وريني|ورّيني)\s+(?:ال)?(?:تفاصيل|تفصيل|ملف)',
        ).hasMatch(n) ||
        RegExp(r'^(?:وريني|ورّيني)$').hasMatch(n.trim());
  }

  static bool _looksLikeContextualBooking(String n) {
    return RegExp(
      r'(?:احجز|أحجز|احجزلي).{0,16}عند(?:ه|ها)|'
      r'(?:أريد|اريد|ابي)\s*(?:احجز|أحجز).{0,16}عند(?:ه|ها)',
    ).hasMatch(n);
  }

  /// إيقاف النطق فقط — لا إلغاء جلسة سريرية ولا وقف متابعة.
  static bool _looksLikeStopSpeaking(String n) {
    final t = n.trim();
    if (t.isEmpty) return false;
    // ارفض أي جملة فيها هدف آخر (متابعة/هدف/علاج/ملف…).
    if (RegExp(
      r'(?:متابعه|متابعة|هدف|علاج|دوا|دواء|ملف|تذكر|الهدف|الجرعه|الجرعة)',
    ).hasMatch(t)) {
      return false;
    }
    return RegExp(
      r'^(?:وقف|اوقف|أوقف|اسكت|اسكات|كافي|'
      r'وقف\s*(?:الصوت|النطق)|'
      r'(?:ايقاف|إيقاف|اوقف|أوقف)\s*(?:الصوت|النطق)|'
      r'كافي\s*(?:صوت|نطق)|'
      r'stop)$',
    ).hasMatch(t);
  }

  /// إعادة آخر رد للمساعد — جملة قصيرة فقط.
  static bool _looksLikeRepeatResponse(String n) {
    final t = n.trim();
    if (t.isEmpty) return false;
    return RegExp(
      r'^(?:كرر|كرري|عيد|عيدها|اعيد|أعيد|'
      r'كرر\s*(?:الرد|الكلام|الجواب)|'
      r'عيد\s*(?:الكلام|الرد|الجواب)|'
      r'repeat)$',
    ).hasMatch(t);
  }

  static bool _looksLikePackages(String n) {
    return RegExp(
      r'(?:باقات|باقاته|الباقات)|'
      r'(?:^|\s)(?:ال)?(?:باقه|باقة)(?=\s|$)|'
      r'(?:عرض(?:لي)?\s*(?:ال)?باق)|'
      r'(?:شنو\s+(?:عنده\s+)?باق)|'
      r'(?:أريد|اريد|ابي).{0,12}(?:باقات|باقه|باقة)|'
      r'(?:ابحث(?:لي)?|بحث(?:لي)?|دور(?:لي)?).{0,16}(?:باقات|باقه|باقة)|'
      r'(?:اختار(?:لي)?|وريني|ورّيني|جيب(?:لي)?).{0,12}باق',
    ).hasMatch(n);
  }

  static bool _looksLikeOffers(String n) {
    // «عرض المزيد» أمر قائمة — ليس عروضاً مخفّضة.
    if (_looksLikeShowMore(n)) return false;
    return RegExp(
      r'(?:^|\s)(?:ال)?(?:عرو+ض)(?=\s|$)|'
      r'(?:^|\s)(?:ال)?عرض(?=\s|$)|'
      r'(?:اكو|أكو)\s+(?:عرو+ض|عرض)|'
      r'(?:تخفيض|مخفضه|مخفضة)|'
      r'(?:الباقات\s+المخف)|'
      r'(?:خصم|خصومات)',
    ).hasMatch(n);
  }

  /// عرض المزيد من نتائج الجلسة — ليس عروضاً تجارية.
  static bool _looksLikeShowMore(String n) {
    final t = n.trim();
    return RegExp(
      r'^(?:عرض|اعرض|وريني|ورّيني|جيب|جيبلي)?\s*(?:ال)?مزيد(?:\s*(?:من\s*(?:ال)?نتائج)?)?$|'
      r'^(?:عرض|اعرض)\s+المزيد$|'
      r'^(?:المزيد)$',
    ).hasMatch(t);
  }

  static bool _looksLikeShareOrFavorite(String n) {
    final t = n.trim();
    return RegExp(
      r'^(?:شاركه|شاركها|شارك|'
      r'ضيفه\s*(?:ل+)?(?:ال)?مفضل[ةه]|'
      r'ضيفها\s*(?:ل+)?(?:ال)?مفضل[ةه]|'
      r'اضفه\s*(?:ل+)?(?:ال)?مفضل[ةه]|'
      r'(?:لل)?مفضل[ةه])$',
    ).hasMatch(t);
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
    // «تحليل» / «أريد تحليل» بلا اسم — كتالوج تحاليل، ليس بحث طبيب.
    if (RegExp(
      r'^(?:أريد|اريد|ابي|أبغى|ابحث(?:لي)?|دور(?:لي)?)?\s*'
      r'(?:عن\s+)?(?:ال)?تحليل(?:ات|ات)?\s*$',
    ).hasMatch(n.trim())) {
      return true;
    }
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
          r'(?:أريد|اريد|ابي|ابحث|دور|طل[عّ]|طلعلي|طلّعلي|شوفلي|وريني|جيبلي|دلني|وين|اين|اكو|عدكم|عندكم|يمكم).{0,24}'
          r'(?:مختبر|مختبرات)',
        ).hasMatch(n) ||
        RegExp(r'^(?:ال)?مختبر(?:ات)?(?:\s+|$)').hasMatch(n.trim()) ||
        RegExp(r'(?:^|\s)(?:ال)?مختبر\s+\S+').hasMatch(n);
  }

  static bool _looksLikeRadiologySearch(String n) {
    return RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور|طل[عّ]|طلعلي|طلّعلي|شوفلي|وريني|جيبلي|دلني|وين|اين|اكو).{0,24}'
          r'(?:اشعه|اشعة|أشعة|شعاع|تصوير\s*شعاعي|صوره\s*شعاعيه|صورة\s*شعاعية)',
        ).hasMatch(n) ||
        RegExp(
          r'^(?:ال)?(?:اشعه|اشعة|أشعة|شعاع)(?:\s+|$)',
        ).hasMatch(n.trim()) ||
        RegExp(r'(?:^|\s)(?:ال)?(?:اشعه|اشعة|أشعة)\s+\S+').hasMatch(n) ||
        RegExp(r'(?:تصوير\s*شعاعي|صوره\s*شعاعيه|صورة\s*شعاعية)').hasMatch(n);
  }

  static bool _looksLikePharmacySearch(String n) {
    return RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور|طل[عّ]|طلعلي|طلّعلي|شوفلي|وريني|جيبلي|دلني|وين|اين|اكو|عدكم|عندكم|يمكم).{0,24}'
          r'(?:صيدليه|صيدلية|صيدليات)',
        ).hasMatch(n) ||
        RegExp(r'^(?:ال)?(?:صيدليه|صيدلية|صيدليات)(?:\s+|$)')
            .hasMatch(n.trim()) ||
        RegExp(r'(?:^|\s)(?:ال)?(?:صيدليه|صيدلية|صيدليات)\s+\S+')
            .hasMatch(n);
  }

  static bool _looksLikePhysioSearch(String n) {
    // يدعم «للعلاج الطبيعي» و«علااج طبييعي» / «فيزيييو» (STT) بلا كلمة «علاج» وحدها.
    final physioPhrase = RegExp(
      r'(?:ل)?(?:ال)?علا+ج\s*(?:ال)?طبي+عي|'
      r'معالج\s*طبي+عي|'
      r'فيزي+و(?:ثيرابي)?|'
      r'تاهيل(?:\s*حركي)?|تأهيل(?:\s*حركي)?|'
      r'مراكز?\s*(?:ل)?(?:ال)?علا+ج\s*(?:ال)?طبي+عي',
    ).hasMatch(n);
    if (!physioPhrase) return false;
    return RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور|طل[عّ]|طلعلي|طلّعلي|وريني|جيبلي|شوفلي|دلني|وين|اين|اكو|مركز|مراكز)',
        ).hasMatch(n) ||
        RegExp(r'^(?:ال)?علا+ج\s*طبي+عي').hasMatch(n.trim());
  }

  static bool _looksLikeSupplySearch(String n) {
    return RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور|طل[عّ]|طلعلي|طلّعلي|وريني|جيبلي|شوفلي|دلني|وين|اين|اكو).{0,24}'
          r'(?:مستلزم+ات|تجهيزا+ت|مواد\s*طبيه|معدات\s*طبيه)',
        ).hasMatch(n) ||
        RegExp(
          r'^(?:ال)?(?:مستلزم+ات|تجهيزا+ت)(?:\s*طبيه)?(?:\s+|$)',
        ).hasMatch(n.trim());
  }

  static bool _mentionsLab(String n) =>
      RegExp(r'(?:ال)?مختبر(?:ات)?').hasMatch(n);

  static bool _mentionsRadiology(String n) =>
      RegExp(r'(?:ال)?(?:اشعه|اشعة|أشعة)').hasMatch(n);

  static bool _mentionsPharmacy(String n) =>
      RegExp(r'(?:ال)?(?:صيدليه|صيدلية|صيدليات)').hasMatch(n);

  static bool _mentionsPhysio(String n) => RegExp(
        r'(?:ل)?(?:ال)?علا+ج\s*(?:ال)?طبي+عي|'
        r'معالج\s*طبي+عي|فيزي+و(?:ثيرابي)?|'
        r'تاهيل(?:\s*حركي)?|تأهيل(?:\s*حركي)?',
      ).hasMatch(n);

  static bool _mentionsSupply(String n) =>
      RegExp(r'(?:ال)?(?:مستلزم+ات|تجهيزا+ت|مواد\s*طبيه|معدات\s*طبيه)')
          .hasMatch(n);

  static bool _hasExplicitLabName(String? name) {
    final cleaned = ArabicTextUtils.prepareLabNameQuery(name ?? '');
    if (cleaned.isEmpty || cleaned.length <= 1) return false;
    if (RegExp(r'^(?:ال)?(?:مختبر|مختبرات)$').hasMatch(cleaned)) return false;
    if (RegExp(
      r'^(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|الاول|الأول|الثاني|الثالث)$',
    ).hasMatch(cleaned)) {
      return false;
    }
    return true;
  }

  static bool _hasExplicitRadiologyName(String? name) {
    final cleaned = ArabicTextUtils.prepareRadiologyNameQuery(name ?? '');
    if (cleaned.isEmpty || cleaned.length <= 1) return false;
    if (RegExp(r'^(?:ال)?(?:اشعه|اشعة|أشعة|مركز)$').hasMatch(cleaned)) {
      return false;
    }
    if (RegExp(
      r'^(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|الاول|الأول|الثاني|الثالث)$',
    ).hasMatch(cleaned)) {
      return false;
    }
    return true;
  }

  /// اسم مختبر نظيف من هدف أمر الاتصال/واتساب — عام لأي مختبر جديد.
  static String? _labNameFromContactTarget(String target) {
    final cleaned = ArabicTextUtils.prepareLabNameQuery(target);
    if (!_hasExplicitLabName(cleaned)) return null;
    return cleaned;
  }

  static String? _radiologyNameFromContactTarget(String target) {
    final cleaned = ArabicTextUtils.prepareRadiologyNameQuery(target);
    if (!_hasExplicitRadiologyName(cleaned)) return null;
    return cleaned;
  }

  static bool _hasExplicitPharmacyName(String? name) {
    final cleaned = ArabicTextUtils.preparePharmacyNameQuery(name ?? '');
    if (cleaned.isEmpty || cleaned.length <= 1) return false;
    if (RegExp(r'^(?:ال)?(?:صيدليه|صيدلية|صيدليات)$').hasMatch(cleaned)) {
      return false;
    }
    if (RegExp(
      r'^(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|الاول|الأول|الثاني|الثالث|عن|في|من|الى|إلى)$',
    ).hasMatch(cleaned)) {
      return false;
    }
    return true;
  }

  static String? _pharmacyNameFromContactTarget(String target) {
    final cleaned = ArabicTextUtils.preparePharmacyNameQuery(target);
    if (!_hasExplicitPharmacyName(cleaned)) return null;
    return cleaned;
  }

  static bool _hasExplicitPhysioName(String? name) {
    final cleaned = ArabicTextUtils.preparePhysioNameQuery(name ?? '');
    if (cleaned.isEmpty || cleaned.length <= 1) return false;
    if (RegExp(
      r'^(?:ال)?(?:علا+ج\s*طبي+عي|فيزي+و|تاهيل|تأهيل|مركز|مراكز)$',
    ).hasMatch(cleaned)) {
      return false;
    }
    if (RegExp(
      r'^(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|الاول|الأول|الثاني|الثالث|عن|في|من|الى|إلى)$',
    ).hasMatch(cleaned)) {
      return false;
    }
    return true;
  }

  static String? _physioNameFromContactTarget(String target) {
    final cleaned = ArabicTextUtils.preparePhysioNameQuery(target);
    if (!_hasExplicitPhysioName(cleaned)) return null;
    return cleaned;
  }

  static bool _hasExplicitSupplyName(String? name) {
    final cleaned = ArabicTextUtils.prepareSupplyNameQuery(name ?? '');
    if (cleaned.isEmpty || cleaned.length <= 1) return false;
    if (RegExp(
      r'^(?:ال)?(?:مستلزم+ات|تجهيزا+ت|مواد\s*طبيه|معدات\s*طبيه|محل|محلات)$',
    ).hasMatch(cleaned)) {
      return false;
    }
    if (RegExp(
      r'^(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|الاول|الأول|الثاني|الثالث|عن|في|من|الى|إلى)$',
    ).hasMatch(cleaned)) {
      return false;
    }
    return true;
  }

  static String? _supplyNameFromContactTarget(String target) {
    final cleaned = ArabicTextUtils.prepareSupplyNameQuery(target);
    if (!_hasExplicitSupplyName(cleaned)) return null;
    return cleaned;
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
