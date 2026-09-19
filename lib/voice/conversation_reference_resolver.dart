import '../search/arabic_text_utils.dart';
import 'conversation_context.dart';
import 'ghadeer_followup_context.dart';
import 'intent/assistant_intent.dart';
import 'intent/intent_result.dart';
import 'result_context.dart';
import '../search/smart_search_models.dart';

/// نتيجة حل مرجع حواري (ضمير / اسم كيان / عودة / أرخص…).
class ConversationReferenceResolution {
  const ConversationReferenceResolution({
    required this.confidence,
    this.focusEntityType,
    this.target,
    this.ordinal,
    this.cheapest = false,
    this.mostExpensive = false,
    this.returnFocus = false,
    this.message = '',
    this.requiresClarification = false,
    this.candidates = const [],
  });

  final ReferenceConfidence confidence;
  final ConversationEntityType? focusEntityType;
  final SmartSearchResult? target;
  final int? ordinal;
  final bool cheapest;
  final bool mostExpensive;
  final bool returnFocus;
  final String message;
  final bool requiresClarification;
  final List<SmartSearchResult> candidates;

  bool get hasTarget => target != null;

  static const unresolved = ConversationReferenceResolution(
    confidence: ReferenceConfidence.unresolved,
  );
}

/// يحل المراجع السياقية الحتمية — ليس chatbot عربي عام.
class ConversationReferenceResolver {
  const ConversationReferenceResolver();

  ConversationReferenceResolution resolve({
    required String query,
    required IntentResult intent,
    required ConversationContext context,
  }) {
    final original = query.trim();
    final n = ArabicTextUtils.normalize(original);
    if (n.isEmpty) return ConversationReferenceResolution.unresolved;

    // 1) أوامر العودة الصريحة للتركيز.
    final ret = _resolveReturnFocus(n, context);
    if (ret != null) return ret;

    // 2) أسماء كيان صريحة («هذا التحليل» / «هاي الباقة»…).
    // حديث سريري مثل «هاي الأعراض» لا يُحل ككيان.
    if (!_looksLikeClinicalSubjectTalk(n)) {
      final noun = _resolveExplicitEntityNoun(n, context);
      if (noun != null) return noun;
    }

    // 3) أرخص / أغلى ضمن سياق نتائج الباقات الحالي فقط.
    final priceRef = _resolvePriceExtreme(n, intent, context);
    if (priceRef != null) return priceRef;

    // 4) ضمائر عامة — توافق الفعل + التركيز النشط.
    final pronoun = _resolveGenericPronoun(n, intent, context);
    if (pronoun != null) return pronoun;

    return ConversationReferenceResolution.unresolved;
  }

  ConversationReferenceResolution? _resolveReturnFocus(
    String n,
    ConversationContext context,
  ) {
    ConversationEntityType? want;
    if (RegExp(r'(?:ارجع|ارجعي|رجع|رجعني)\s+(?:ل|لل|الى|إلى)?\s*(?:ال)?طبيب')
            .hasMatch(n) ||
        RegExp(r'(?:ارجع|رجع)\s+(?:ل|لل)?(?:ال)?دكتور').hasMatch(n)) {
      want = ConversationEntityType.doctor;
    } else if (RegExp(
      r'(?:ارجع|ارجعي|رجع|رجعني)\s+(?:ل|لل|الى|إلى)?\s*(?:ال)?مختبر',
    ).hasMatch(n)) {
      want = ConversationEntityType.laboratory;
    } else if (RegExp(
      r'(?:ارجع|ارجعي|رجع|رجعني)\s+(?:ل|لل|الى|إلى)?\s*(?:ال)?تحليل',
    ).hasMatch(n)) {
      want = ConversationEntityType.analysis;
    } else if (RegExp(
      r'(?:ارجع|ارجعي|رجع|رجعني)\s+(?:ل|لل|الى|إلى)?\s*(?:ال)?باق',
    ).hasMatch(n)) {
      want = ConversationEntityType.package;
    }
    if (want == null) return null;

    final selected = context.selectedOf(want);
    if (selected == null) {
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.unresolved,
        focusEntityType: want,
        returnFocus: true,
        requiresClarification: true,
        message: _missingReturnMessage(want),
      );
    }
    return ConversationReferenceResolution(
      confidence: ReferenceConfidence.explicit,
      focusEntityType: want,
      target: selected,
      returnFocus: true,
    );
  }

  ConversationReferenceResolution? _resolveExplicitEntityNoun(
    String n,
    ConversationContext context,
  ) {
    // تحليل — يتطلب إشارة صريحة حتى لا تُلتقط أفعال الاتصال.
    if (RegExp('$_demonstrative\\s*(?:ال)?تحليل').hasMatch(n)) {
      return _typedNounResolution(
        context,
        ConversationEntityType.analysis,
        missing: 'ما عندي تحليل محدد بالسياق. ابحث عن التحليل أولاً.',
      );
    }

    // باقة
    if (RegExp('$_demonstrative\\s*(?:ال)?باق').hasMatch(n)) {
      return _typedNounResolution(
        context,
        ConversationEntityType.package,
        missing: 'ما عندي باقة محددة بالسياق. اختر باقة أولاً.',
      );
    }

    // مختبر
    if (RegExp('$_demonstrative\\s*(?:ال)?مختبر').hasMatch(n)) {
      return _typedNounResolution(
        context,
        ConversationEntityType.laboratory,
        missing: 'ما عندي مختبر محدد بالسياق.',
      );
    }

    // طبيب — لا يُحيي طبيباً قديماً بعد الانتقال لمختبر/باقة.
    if (RegExp('$_demonstrative\\s*(?:ال)?(?:طبيب|دكتور)').hasMatch(n)) {
      return _typedNounResolution(
        context,
        ConversationEntityType.doctor,
        missing: 'ما عندي طبيب محدد بالسياق.',
      );
    }

    return null;
  }

  ConversationReferenceResolution _typedNounResolution(
    ConversationContext context,
    ConversationEntityType type, {
    required String missing,
  }) {
    final current = _currentTypedAntecedent(context, type);
    if (current != null) {
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.explicit,
        focusEntityType: type,
        target: current,
      );
    }
    return ConversationReferenceResolution(
      confidence: ReferenceConfidence.unresolved,
      focusEntityType: type,
      requiresClarification: true,
      message: missing,
    );
  }

  ConversationReferenceResolution? _resolvePriceExtreme(
    String n,
    IntentResult intent,
    ConversationContext context,
  ) {
    final wantsCheapest = RegExp(
      r'(?:ارخص|أرخص)(?:\s+وحده|\s+وحدة)?|(?:اقل|أقل)\s+سعر',
    ).hasMatch(n);
    final wantsExpensive = RegExp(
      r'(?:اغلى|أغلى|اعلى|أعلى)\s*(?:سعر|وحده|وحدة)?',
    ).hasMatch(n);
    if (!wantsCheapest && !wantsExpensive) return null;

    // فقط ضمن سياق نتائج باقات حالي — ليس أطباء/تحاليل.
    final packages = context.currentPackageResultItems;
    if (packages.isEmpty) {
      // اترك للمسار العام (بحث أرخص عالمي) إن لم يوجد سياق نتائج.
      return null;
    }

    final priced = packages
        .where((p) => p.newPrice != null && p.newPrice! > 0)
        .toList();
    if (priced.isEmpty) {
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.unresolved,
        cheapest: wantsCheapest,
        mostExpensive: wantsExpensive,
        requiresClarification: true,
        message: 'ماكو أسعار متوفرة على الباقات المعروضة حالياً للمقارنة.',
      );
    }

    priced.sort((a, b) => a.newPrice!.compareTo(b.newPrice!));
    final chosen = wantsExpensive ? priced.last : priced.first;
    return ConversationReferenceResolution(
      confidence: ReferenceConfidence.strongContext,
      focusEntityType: ConversationEntityType.package,
      target: chosen,
      cheapest: wantsCheapest,
      mostExpensive: wantsExpensive,
    );
  }

  ConversationReferenceResolution? _resolveGenericPronoun(
    String n,
    IntentResult intent,
    ConversationContext context,
  ) {
    // «هو عنده حرارة» / «هاي الأعراض» تبقى للمسار السريري — ليست كياناً.
    if (_looksLikeClinicalSubjectTalk(n)) return null;

    // الاسم الصريح في الدور الحالي يغلب الضمير.
    if (_hasCurrentTurnExplicitName(n, intent)) return null;

    final hasPronoun = _iraqiEntityPronoun.hasMatch(n);
    final bareAction = _isBareContextualAction(n, intent);
    if (!hasPronoun && !bareAction) return null;

    // لا تُحل «هذا/هاي» عالمياً خارج فعل/تنقّل متوافق.
    if (hasPronoun && !bareAction && !_isActionAnchoredReference(n, intent)) {
      return null;
    }

    final action = intent.intent;
    final active = context.activeEntityType;
    final selected = context.selectedEntity;

    // اتصال/واتساب
    if (action == AssistantIntent.callDoctor ||
        action == AssistantIntent.messageDoctor ||
        action == AssistantIntent.callLab ||
        action == AssistantIntent.messageLab ||
        RegExp(r'(?:اتصل|اتصال|راسل|دزله|دزّله|واتساب|واتس)').hasMatch(n)) {
      return _resolveContactPronoun(context, n, intent);
    }

    // سعر
    if (RegExp(r'(?:سعر|شكد|بكم)').hasMatch(n) ||
        intent.entities.actionHint == 'price') {
      if (active == ConversationEntityType.package &&
          context.selectedPackage != null) {
        return ConversationReferenceResolution(
          confidence: ReferenceConfidence.strongContext,
          focusEntityType: ConversationEntityType.package,
          target: context.selectedPackage,
        );
      }
      if (active == ConversationEntityType.analysis) {
        return ConversationReferenceResolution(
          confidence: ReferenceConfidence.strongContext,
          focusEntityType: ConversationEntityType.analysis,
          target: context.selectedAnalysis,
          message: 'ماكو سعر مباشر للتحليل؛ الأسعار على الباقات المرتبطة به.',
        );
      }
    }

    // موقع
    if (action == AssistantIntent.showLocation ||
        RegExp(r'(?:وين|اين|أين)\s*(?:موقع|موقعه|عيادت|عنوان|موجود)').hasMatch(n)) {
      if (active == ConversationEntityType.doctor &&
          context.selectedDoctor != null) {
        return ConversationReferenceResolution(
          confidence: ReferenceConfidence.strongContext,
          focusEntityType: ConversationEntityType.doctor,
          target: context.selectedDoctor,
        );
      }
      if (active == ConversationEntityType.laboratory &&
          context.selectedLaboratory != null) {
        return ConversationReferenceResolution(
          confidence: ReferenceConfidence.strongContext,
          focusEntityType: ConversationEntityType.laboratory,
          target: context.selectedLaboratory,
        );
      }
      if (active == ConversationEntityType.package &&
          context.selectedPackage != null) {
        return ConversationReferenceResolution(
          confidence: ReferenceConfidence.relationshipContext,
          focusEntityType: ConversationEntityType.package,
          target: context.selectedPackage,
        );
      }
      if (active == ConversationEntityType.analysis &&
          context.selectedAnalysis != null) {
        return ConversationReferenceResolution(
          confidence: ReferenceConfidence.relationshipContext,
          focusEntityType: ConversationEntityType.analysis,
          target: context.selectedAnalysis,
        );
      }
    }

    if (selected != null && active != ConversationEntityType.none) {
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.strongContext,
        focusEntityType: active,
        target: selected,
      );
    }

    return null;
  }

  ConversationReferenceResolution _resolveContactPronoun(
    ConversationContext context,
    String n,
    IntentResult intent,
  ) {
    final active = context.activeEntityType;

    if (active == ConversationEntityType.analysis) {
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.strongContext,
        focusEntityType: ConversationEntityType.analysis,
        target: context.selectedAnalysis,
        message:
            'التحليل نفسه ما عنده رقم اتصال. أگدر أعرض لك المختبرات اللي ظهر ضمن باقاتها.',
      );
    }

    if (active == ConversationEntityType.package) {
      // جمع متوافق («اتصل بيهم») أو فعل اتصال عارٍ بعد معرفة المختبر الأب.
      // المفرد «بيه/بيها» لا يحوّل الباقة إلى طبيب.
      final lab = context.selectedLaboratory;
      if (_isPluralIraqiContact(n) && lab != null) {
        return ConversationReferenceResolution(
          confidence: ReferenceConfidence.relationshipContext,
          focusEntityType: ConversationEntityType.laboratory,
          target: lab,
        );
      }
      if (_isSingularIraqiContactPronoun(n)) {
        return ConversationReferenceResolution(
          confidence: ReferenceConfidence.unresolved,
          focusEntityType: ConversationEntityType.package,
          target: context.selectedPackage,
          requiresClarification: true,
          message: 'الباقة نفسها ما بيها اتصال مباشر. حدّد المختبر المرتبط بها.',
        );
      }
      if (lab != null) {
        return ConversationReferenceResolution(
          confidence: ReferenceConfidence.relationshipContext,
          focusEntityType: ConversationEntityType.laboratory,
          target: lab,
        );
      }
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.unresolved,
        focusEntityType: ConversationEntityType.package,
        target: context.selectedPackage,
        requiresClarification: true,
        message: 'الباقة نفسها ما بيها اتصال مباشر. حدّد المختبر المرتبط بها.',
      );
    }

    if (active == ConversationEntityType.doctor &&
        context.selectedDoctor != null) {
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.strongContext,
        focusEntityType: ConversationEntityType.doctor,
        target: context.selectedDoctor,
      );
    }

    if (active == ConversationEntityType.laboratory &&
        context.selectedLaboratory != null) {
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.strongContext,
        focusEntityType: ConversationEntityType.laboratory,
        target: context.selectedLaboratory,
      );
    }

    // لا سقوط إلى lastResults ولا إحياء selected قديم خارج التركيز/ResultContext الحالي.
    final hasDoc = context.selectedDoctor != null;
    final hasLab = context.selectedLaboratory != null;
    if (hasDoc && hasLab) {
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.ambiguous,
        requiresClarification: true,
        candidates: [
          context.selectedDoctor!,
          context.selectedLaboratory!,
        ],
        message: 'تقصد الطبيب أم المختبر؟',
      );
    }
    final uniqueRecent = _uniqueCompatibleRecent(context, contact: true);
    if (uniqueRecent != null) {
      return uniqueRecent;
    }
    if (hasDoc &&
        context.currentResultContext?.entityType ==
            ConversationEntityType.doctor) {
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.strongContext,
        focusEntityType: ConversationEntityType.doctor,
        target: context.selectedDoctor,
      );
    }
    if (hasLab &&
        context.currentResultContext?.entityType ==
            ConversationEntityType.laboratory) {
      return ConversationReferenceResolution(
        confidence: ReferenceConfidence.strongContext,
        focusEntityType: ConversationEntityType.laboratory,
        target: context.selectedLaboratory,
      );
    }

    return ConversationReferenceResolution(
      confidence: ReferenceConfidence.unresolved,
      requiresClarification: true,
      message: GhadeerFollowUpContext.noPronounTargetMessage(),
    );
  }

  static bool _isBareContextualAction(String n, IntentResult intent) {
    if (intent.requiresContext) return true;
    return RegExp(
      r'^(?:سعرها|سعره|تحاليلها|تحاليله|موقعه|عيادته|باقاته|'
      r'اتصل\s*(?:بيه|به|بيها|بها)?|'
      r'راسل(?:ه|ها|هم)?|'
      r'دزله(?:\s+واتساب)?|'
      r'(?:افتحه|افتحها)|'
      r'(?:افتح|اعرض|اختار)\s*(?:هذا|هاي|هذي|هذه|هذاك|ذاك)|'
      r'(?:احجز|أحجز)\s*عند(?:ه|ها)|'
      r'ضيفه(?:\s+للمفضله)?)\s*$',
    ).hasMatch(n.trim());
  }

  static const _demonstrative = r'(?:هذا|هاي|هذ|هذه|هذي|هذاك|ذاك|نفس)';

  static final _iraqiEntityPronoun = RegExp(
    r'(?:^|\s)(?:هذا|هاي|هذي|هذه|هذاك|ذاك|بيه|به|بيها|بها|'
    r'وياه|عليها|عليه|عليهم|بيهم|نفسه|نفسها|مالته|مالتها)(?=\s|$)',
  );

  static bool _isPluralIraqiContact(String n) {
    return RegExp(r'(?:بيهم|عليهم|راسلهم)').hasMatch(n);
  }

  static bool _isSingularIraqiContactPronoun(String n) {
    if (_isPluralIraqiContact(n)) return false;
    return RegExp(
      r'(?:^|\s)(?:بيه|به|بيها|بها|هذا|هاي|هذي|هذه|هذاك|ذاك)(?=\s|$)',
    ).hasMatch(n);
  }

  static bool _isActionAnchoredReference(String n, IntentResult intent) {
    if (intent.requiresContext) return true;
    switch (intent.intent) {
      case AssistantIntent.callDoctor:
      case AssistantIntent.callLab:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.messageLab:
      case AssistantIntent.showProfile:
      case AssistantIntent.showLocation:
        return true;
      default:
        break;
    }
    return RegExp(
      r'(?:اتصل|اتصال|راسل|دزله|دزّله|واتس|افتح|اعرض|اختار|شارك|ضيف|'
      r'ملفه|نبذته|عيادته|سعرها|سعره|تحاليلها|موقعه)',
    ).hasMatch(n);
  }

  static bool _looksLikeClinicalSubjectTalk(String n) {
    if (RegExp(
      r'(?:^|\s)(?:هو|هي)\s+(?:عنده|عندها|يعاني|تعاني)',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'(?:هذا|هاي|هذي|هذه|هذاك)\s*(?:ال)?(?:اعراض|أعراض|سعال|كحه|كحة|حراره|حرارة)',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'(?:ابني|ابنتي|بنتي|ولدي|طفلي|زوجي|زوجتي).{0,24}(?:عند|سعال|حراره|كحه)',
    ).hasMatch(n)) {
      return true;
    }
    return false;
  }

  static bool _hasCurrentTurnExplicitName(String n, IntentResult intent) {
    final raw = (intent.entities.doctorName ?? '').trim();
    final name = ArabicTextUtils.normalize(raw);
    if (name.isNotEmpty &&
        !_iraqiEntityPronoun.hasMatch(' $name') &&
        !RegExp(r'^(?:ال)?(?:دكتور|طبيب|دكتوره|طبيبه)$').hasMatch(name)) {
      return true;
    }
    if (RegExp(r'(?:ال)?(?:دكتور|طبيب)\s+\S{2,}').hasMatch(n) &&
        !RegExp(
          '$_demonstrative\\s+(?:ال)?(?:دكتور|طبيب)',
        ).hasMatch(n)) {
      return true;
    }
    return false;
  }

  /// كيان محدد من النوع المطلوب في التركيز النشط أو ResultContext الحالي فقط.
  static SmartSearchResult? _currentTypedAntecedent(
    ConversationContext context,
    ConversationEntityType type,
  ) {
    final selected = context.selectedOf(type);
    if (selected == null) return null;
    // الطبيب فقط: لا إحياء selectedDoctor بعد انتقال نتائج/تركيز غير طبيب.
    if (type == ConversationEntityType.doctor) {
      if (context.activeEntityType == type) return selected;
      if (context.currentResultContext?.entityType == type) return selected;
      return null;
    }
    return selected;
  }

  static ConversationReferenceResolution? _uniqueCompatibleRecent(
    ConversationContext context, {
    required bool contact,
  }) {
    if (context.activeEntityType == ConversationEntityType.none) return null;
    final type = context.activeEntityType;
    if (contact && !EntityActionCompatibility.supportsCall(type)) return null;
    final selected = context.selectedOf(type);
    if (selected == null) return null;
    final matches = context.recentReferences
        .where((r) => r.entityType == type)
        .toList();
    if (matches.length != 1) return null;
    final id = matches.first.entityId;
    final selectedId = switch (type) {
      ConversationEntityType.doctor => (selected.doctorId ?? '').trim(),
      ConversationEntityType.laboratory => (selected.labId ?? '').trim(),
      ConversationEntityType.analysis => (selected.analysisId ?? '').trim(),
      ConversationEntityType.package => (selected.packageId ?? '').trim(),
      ConversationEntityType.none => '',
    };
    if (id.isEmpty || id != selectedId) return null;
    return ConversationReferenceResolution(
      confidence: ReferenceConfidence.strongContext,
      focusEntityType: type,
      target: selected,
    );
  }

  static String _missingReturnMessage(ConversationEntityType t) {
    switch (t) {
      case ConversationEntityType.doctor:
        return 'ما عندي طبيب محفوظ بالسياق. ابحث عن طبيب أولاً.';
      case ConversationEntityType.laboratory:
        return 'ما عندي مختبر محفوظ بالسياق. ابحث عن مختبر أولاً.';
      case ConversationEntityType.analysis:
        return 'ما عندي تحليل محفوظ بالسياق.';
      case ConversationEntityType.package:
        return 'ما عندي باقة محفوظة بالسياق.';
      case ConversationEntityType.none:
        return 'ما عندي كيان محفوظ للعودة إليه.';
    }
  }
}
