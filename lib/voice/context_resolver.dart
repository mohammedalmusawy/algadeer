import '../search/arabic_text_utils.dart';
import '../search/smart_search_models.dart';
import 'conversation_context.dart';
import 'ghadeer_followup_context.dart';
import 'intent/assistant_intent.dart';

/// ناتج حل سياق — حتمي وخفيف بدون AI.
enum ContextResolutionStatus {
  /// ليس متابعة سياقية — أكمل مسار البحث العادي.
  notContextual,

  selectResult,
  selectionOutOfRange,
  noPreviousResults,

  showLocation,
  locationUnavailable,

  callDoctor,
  messageDoctor,
  contactUnavailable,

  showProfile,
}

class ContextResolution {
  const ContextResolution({
    required this.status,
    this.intent,
    this.target,
    this.requestedOrdinal,
    this.availableCount,
    this.message = '',
    this.pendingAction,
  });

  final ContextResolutionStatus status;
  final AssistantIntent? intent;
  final SmartSearchResult? target;
  final int? requestedOrdinal;
  final int? availableCount;
  final String message;

  /// call | whatsapp
  final String? pendingAction;

  bool get handled => status != ContextResolutionStatus.notContextual;

  static const notContextual = ContextResolution(
    status: ContextResolutionStatus.notContextual,
  );
}

/// يحل المتابعات الترتيبية/الإشارية داخل الجلسة — نص وصوت بنفس المنطق.
class ContextResolver {
  const ContextResolver();

  ContextResolution resolve(String rawQuery, ConversationContext context) {
    final original = rawQuery.trim();
    if (original.isEmpty) return ContextResolution.notContextual;

    final normalized = ArabicTextUtils.normalize(original);

    // 1) ترتيب: الثاني / الأخير / اختار الثاني…
    final ordinal = extractOrdinal(normalized);
    if (ordinal != null) {
      return _resolveOrdinal(ordinal, context);
    }

    // 2) تصحيح إجراء مع الإبقاء على التحديد: لا، دزله واتساب
    final actionSwitch = _resolveActionCorrection(normalized, context);
    if (actionSwitch != null) return actionSwitch;

    // 3) موقع / اتصال / واتساب بإشارة للطبيب المحدد
    if (_looksLikeLocationFollowUp(normalized)) {
      return _resolveLocation(context);
    }
    if (_looksLikeCallFollowUp(normalized)) {
      return _resolveContact(context, whatsapp: false);
    }
    if (_looksLikeWhatsAppFollowUp(normalized)) {
      return _resolveContact(context, whatsapp: true);
    }
    if (_looksLikeProfileFollowUp(normalized)) {
      return _resolveProfile(context);
    }

    return ContextResolution.notContextual;
  }

  /// يستخرج ترتيباً 1-based، أو -1 للأخير. null إن لم يوجد.
  /// يتجاهل أفعال الإجراء حتى تعمل «اتصل على الأول» / «واتساب للثاني».
  static int? extractOrdinal(String normalized) {
    final q = normalized.trim();
    if (q.isEmpty) return null;

    // الأخير / آخر واحد
    if (RegExp(
      r'(?:^|\s)(?:الاخير|الأخير|اخر\s*واحد|آخر\s*واحد|الاخيره|الأخيرة)(?:\s|$)',
    ).hasMatch(q)) {
      return -1;
    }

    const map = <String, int>{
      'الاول': 1,
      'الأول': 1,
      'اول': 1,
      'أول': 1,
      'الاولى': 1,
      'الأولى': 1,
      'الاولي': 1,
      'اولي': 1,
      'أولى': 1,
      'الثاني': 2,
      'ثاني': 2,
      'الثانيه': 2,
      'الثانية': 2,
      'ثانيه': 2,
      'ثانية': 2,
      'الثالث': 3,
      'ثالث': 3,
      'الثالثه': 3,
      'الثالثة': 3,
      'الرابع': 4,
      'رابع': 4,
      'الرابعه': 4,
      'الرابعة': 4,
      'الخامس': 5,
      'خامس': 5,
      'الخامسه': 5,
      'الخامسة': 5,
    };

    // جملة قصيرة تتمحور حول الترتيب (مع كلمات ضجيج آمنة بما فيها أفعال الإجراء).
    var stripped = q
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:اختار|اختَر|اختري|اريد|أريد|ابي|افتح|فتح|عرض|وريني|ورّيني|منهم|منهن|هذا|هاي)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:اتصل|اتصال|دقله|دگله|دزله|دزّله|دز|راسل|ارسل|أرسل|رسالة|رساله|واتساب|واتس|whatsapp|وين|اين|أين|عيادة|عيادته|مكان|مكانه|موقع|موقعه|عنوان|عنوانه|نبذته|ملفه|على|ل|ب|في)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:الطبيب|الطبيبه|الطبيبة|الدكتور|الدكتوره|الدكتورة|دكتور|طبيب|المختبر|مختبر)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'(?:^|\s)واحد(?=\s|$)'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (stripped.isEmpty) stripped = q;

    // «رقم 1/2/3» فقط — الرقم العاري «2» ليس ترتيباً عاماً.
    final numbered =
        _numberedResultOrdinal(stripped) ?? _numberedResultOrdinal(q);
    if (numbered != null) {
      final tokens =
          stripped.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).length;
      if (tokens <= 4) return numbered;
    }

    // للثاني / بالاول — حرف جر ± أداة تعريف ملتصقة بالترتيب.
    for (final e in map.entries) {
      for (final candidate in _ordinalTokenCandidates(stripped)) {
        if (candidate == e.key) return e.value;
      }
      if (RegExp('(?:^|\\s)${RegExp.escape(e.key)}(?:\\s|\$)').hasMatch(stripped) ||
          RegExp('(?:^|\\s)[لب]?${RegExp.escape(e.key)}(?:\\s|\$)')
              .hasMatch(q) ||
          RegExp('(?:^|\\s)لل?${RegExp.escape(e.key.replaceFirst(RegExp(r'^ال'), ''))}(?:\\s|\$)')
              .hasMatch(q)) {
        final tokens = stripped.split(RegExp(r'\s+'));
        if (tokens.length <= 4) return e.value;
      }
    }
    return null;
  }

  static Iterable<String> _ordinalTokenCandidates(String token) sync* {
    yield token;
    var s = token;
    if (s.startsWith('ل') || s.startsWith('ب')) {
      s = s.substring(1);
      yield s;
    }
    if (s.startsWith('ل') || s.startsWith('ب')) {
      s = s.substring(1);
      yield s;
    }
    if (s.startsWith('ال') && s.length > 2) {
      yield s.substring(2);
    } else if (s.isNotEmpty) {
      yield 'ال$s';
    }
  }

  /// «رقم 1/2/3» في سياق اختيار نتائج — ليس رقماً عارياً.
  static int? _numberedResultOrdinal(String text) {
    final m = RegExp(r'(?:^|\s)رقم\s*([123١٢٣])(?:\s|$)').firstMatch(text);
    if (m == null) return null;
    return switch (m.group(1)) {
      '1' || '١' => 1,
      '2' || '٢' => 2,
      '3' || '٣' => 3,
      _ => null,
    };
  }

  ContextResolution _resolveOrdinal(int ordinal, ConversationContext context) {
    // PC-0.2: ResultContext الحالي (أو توضيح معلّق صريح) — ليس lastResults.
    final type = _ordinalEntityType(context);
    if (type == null || type == ConversationEntityType.none) {
      return ContextResolution(
        status: ContextResolutionStatus.noPreviousResults,
        intent: AssistantIntent.selectResult,
        requestedOrdinal: ordinal == -1 ? null : ordinal,
        message: GhadeerFollowUpContext.noSelectableResultsMessage(
          requestedOrdinal: ordinal == -1 ? null : ordinal,
        ),
      );
    }

    final items = context.authoritativeItemsFor(type);
    if (items.isEmpty) {
      return ContextResolution(
        status: ContextResolutionStatus.noPreviousResults,
        intent: AssistantIntent.selectResult,
        requestedOrdinal: ordinal == -1 ? null : ordinal,
        message: GhadeerFollowUpContext.noSelectableResultsMessage(
          requestedOrdinal: ordinal == -1 ? null : ordinal,
        ),
      );
    }

    final index = ordinal == -1 ? items.length : ordinal;
    if (index < 1 || index > items.length) {
      final requested = ordinal == -1 ? items.length + 1 : ordinal;
      return ContextResolution(
        status: ContextResolutionStatus.selectionOutOfRange,
        intent: AssistantIntent.selectResult,
        requestedOrdinal: requested,
        availableCount: items.length,
        message: GhadeerFollowUpContext.outOfRangeMessage(
          requestedOrdinal: requested,
          availableCount: items.length,
        ),
      );
    }

    final chosen = _selectByOrdinal(context, type, index);
    if (chosen == null) {
      return ContextResolution(
        status: ContextResolutionStatus.selectionOutOfRange,
        intent: AssistantIntent.selectResult,
        requestedOrdinal: index,
        availableCount: items.length,
        message: GhadeerFollowUpContext.outOfRangeMessage(
          requestedOrdinal: index,
          availableCount: items.length,
        ),
      );
    }

    context.lastIntent = AssistantIntent.selectResult;
    context.setAssistantResponse('تم اختيار ${chosen.title}');
    return ContextResolution(
      status: ContextResolutionStatus.selectResult,
      intent: AssistantIntent.selectResult,
      target: chosen,
      requestedOrdinal: index,
      availableCount: items.length,
      message: 'تم اختيار ${chosen.title}.',
    );
  }

  static ConversationEntityType? _ordinalEntityType(
    ConversationContext context,
  ) {
    final resultCtx = context.currentResultContext;
    if (resultCtx != null &&
        resultCtx.isNotEmpty &&
        resultCtx.entityType != ConversationEntityType.none) {
      return resultCtx.entityType;
    }

    final pending = context.pendingClarification;
    if (pending == null) return null;
    if (pending.doctorResults.isNotEmpty) {
      return ConversationEntityType.doctor;
    }
    if (pending.labResults.isNotEmpty) {
      return ConversationEntityType.laboratory;
    }
    if (pending.packageResults.isNotEmpty) {
      return ConversationEntityType.package;
    }
    if (pending.analysisResults.isNotEmpty) {
      return ConversationEntityType.analysis;
    }
    return null;
  }

  static SmartSearchResult? _selectByOrdinal(
    ConversationContext context,
    ConversationEntityType type,
    int index,
  ) {
    return switch (type) {
      ConversationEntityType.doctor => context.selectDoctorByOrdinal(index),
      ConversationEntityType.laboratory =>
        context.selectLaboratoryByOrdinal(index),
      ConversationEntityType.package => context.selectPackageByOrdinal(index),
      ConversationEntityType.analysis =>
        context.selectAnalysisByOrdinal(index),
      ConversationEntityType.none => null,
    };
  }

  ContextResolution? _resolveActionCorrection(
    String normalized,
    ConversationContext context,
  ) {
    if (!context.hasSelection) return null;
    final hasNegation = RegExp(r'(?:^|\s)(?:لا|لاء|مو|بدل)(?=\s|$)').hasMatch(
      normalized,
    );
    if (!hasNegation) return null;

    if (_looksLikeWhatsAppFollowUp(normalized) ||
        normalized.contains('واتس') ||
        normalized.contains('whatsapp')) {
      return _resolveContact(context, whatsapp: true);
    }
    if (_looksLikeCallFollowUp(normalized) || normalized.contains('اتصل')) {
      return _resolveContact(context, whatsapp: false);
    }
    return null;
  }

  ContextResolution _resolveLocation(ConversationContext context) {
    final target = context.selectedEntity;
    if (target == null || target.type != SmartSearchResultType.doctor) {
      if (!context.hasDoctorResults) {
        return const ContextResolution(
          status: ContextResolutionStatus.noPreviousResults,
          intent: AssistantIntent.showLocation,
          message:
              'ما عندي طبيب محدد. ابحث أو اختار طبيباً من النتائج أولاً.',
        );
      }
      return const ContextResolution(
        status: ContextResolutionStatus.noPreviousResults,
        intent: AssistantIntent.showLocation,
        message: 'حدد الطبيب أولاً (مثلاً: الثاني) ثم اسأل عن العيادة.',
      );
    }

    final location = target.clinicLocation?.trim() ?? '';
    if (location.isEmpty) {
      context.lastIntent = AssistantIntent.showLocation;
      return ContextResolution(
        status: ContextResolutionStatus.locationUnavailable,
        intent: AssistantIntent.showLocation,
        target: target,
        message:
            'موقع عيادة ${target.title} غير متوفر حالياً في البيانات.',
      );
    }

    context.lastIntent = AssistantIntent.showLocation;
    context.clearPending();
    final msg = 'عيادة ${target.title}: $location';
    context.setAssistantResponse(msg);
    return ContextResolution(
      status: ContextResolutionStatus.showLocation,
      intent: AssistantIntent.showLocation,
      target: target,
      message: msg,
    );
  }

  ContextResolution _resolveContact(
    ConversationContext context, {
    required bool whatsapp,
  }) {
    final target = context.selectedEntity;
    final intent =
        whatsapp ? AssistantIntent.messageDoctor : AssistantIntent.callDoctor;
    final action = whatsapp ? 'whatsapp' : 'call';

    if (target == null || target.type != SmartSearchResultType.doctor) {
      return ContextResolution(
        status: ContextResolutionStatus.noPreviousResults,
        intent: intent,
        message: whatsapp
            ? 'أي طبيب تقصد؟ ابحث عن الطبيب أو اذكر اسمه أولاً.'
            : 'أي طبيب تقصد؟ ابحث عن الطبيب أو اذكر اسمه أولاً.',
      );
    }

    if (whatsapp) {
      if (!target.canWhatsApp) {
        return ContextResolution(
          status: ContextResolutionStatus.contactUnavailable,
          intent: intent,
          target: target,
          message: 'واتساب ${target.title} غير متوفر حالياً.',
        );
      }
    } else if (!target.canCall) {
      return ContextResolution(
        status: ContextResolutionStatus.contactUnavailable,
        intent: intent,
        target: target,
        message: 'رقم اتصال ${target.title} غير متوفر حالياً.',
      );
    }

    // يصحّح الإجراء دون مسح التحديد.
    context.setPendingAction(action);
    context.lastIntent = intent;
    final msg = whatsapp
        ? 'جاهز لفتح واتساب ${target.title}.'
        : 'جاهز للاتصال بـ ${target.title}.';
    context.setAssistantResponse(msg);
    return ContextResolution(
      status: whatsapp
          ? ContextResolutionStatus.messageDoctor
          : ContextResolutionStatus.callDoctor,
      intent: intent,
      target: target,
      pendingAction: action,
      message: msg,
    );
  }

  ContextResolution _resolveProfile(ConversationContext context) {
    final target = context.selectedEntity;
    if (target == null || target.type != SmartSearchResultType.doctor) {
      return const ContextResolution(
        status: ContextResolutionStatus.noPreviousResults,
        intent: AssistantIntent.showProfile,
        message: 'حدد الطبيب أولاً حتى أفتح ملفه.',
      );
    }
    context.lastIntent = AssistantIntent.showProfile;
    context.clearPending();
    final msg = 'فتح ملف ${target.title}.';
    context.setAssistantResponse(msg);
    return ContextResolution(
      status: ContextResolutionStatus.showProfile,
      intent: AssistantIntent.showProfile,
      target: target,
      message: msg,
    );
  }

  static bool _looksLikeProfileFollowUp(String n) {
    if (RegExp(r'(?:ملفه|نبذته|بطاقته|معلومات\s*عنه)').hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'(?:افتح|اعرض)\s+(?:ملف|نبذه|نبذة|بطاقه|بطاقة)?\s*(?:ه|ها)?$',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(r'عرض\s*الملف').hasMatch(n)) return true;
    if (n.length <= 24 &&
        RegExp(r'(?:افتح|اعرض)\s+(?:ال)?(?:طبيب|دكتور)$').hasMatch(n)) {
      return true;
    }
    return false;
  }

  static bool _looksLikeLocationFollowUp(String n) {
    if (RegExp(
      r'(?:وين|اين|أين).{0,20}(?:عياد|مكان|موقع|عنوان)',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(
      r'(?:عيادته|عيادتها|مكانه|مكانها|موقعه|موقعها|عنوانه|عنوانها)',
    ).hasMatch(n)) {
      return true;
    }
    if (RegExp(r'^(?:العنوان|الموقع)$').hasMatch(n.trim())) {
      return true;
    }
    // جملة قصيرة إشارية للموقع.
    if (n.length <= 28 &&
        RegExp(r'(?:^|\s)(?:وين|اين|أين)(?=\s|$)').hasMatch(n) &&
        RegExp(r'(?:عياد|مكان|موقع|هنا|هناك)').hasMatch(n)) {
      return true;
    }
    return false;
  }

  static bool _looksLikeCallFollowUp(String n) {
    if (RegExp(
      r'(?:اتصل|اتصال|كلمه|كلّمه|دقله|دگله|احجي\s*ويا|احجي\s*وياه)',
    ).hasMatch(n)) {
      // إن وُجد اسم صريح طويل، اترك VoiceContactCommand/البحث.
      if (_hasLikelyExplicitDoctorName(n)) return false;
      return true;
    }
    if (RegExp(r'(?:اتصل\s*)?(?:بيه|به|بيها|بها|وياه|عليه|عليها)').hasMatch(n) &&
        n.length <= 24) {
      return true;
    }
    return false;
  }

  static bool _looksLikeWhatsAppFollowUp(String n) {
    if (RegExp(
      r'(?:واتساب|واتس\s*اب|واتس|whatsapp|دزله|دزّله|دزوله|راسل|رساله|رسالة)',
    ).hasMatch(n)) {
      if (_hasLikelyExplicitDoctorName(n) &&
          !RegExp(r'(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|الدكتور|الطبيب)\b').hasMatch(n) &&
          !RegExp(r'(?:دزله|دزّله|راسل)\s*$').hasMatch(n)) {
        // «واتساب الدكتور علي» → مسار الأمر الصريح إن وُجد اسم.
        final after = n.replaceFirst(
          RegExp(r'.*(?:واتساب|واتس|whatsapp|دزله|راسل)\s*'),
          '',
        );
        if (after.trim().split(RegExp(r'\s+')).length >= 2) return false;
      }
      return true;
    }
    if (RegExp(r'احجي\s*وياه').hasMatch(n) && n.contains('واتس')) {
      return true;
    }
    return false;
  }

  /// اسم صريح محتمل بعد لقب — لتجنّب ابتلاع «اتصل بالدكتور علي».
  static bool _hasLikelyExplicitDoctorName(String n) {
    final m = RegExp(
      r'(?:الدكتور|الدكتورة|دكتور|دكتورة|الطبيب|الطبيبة)\s+(\S+)',
    ).firstMatch(n);
    if (m == null) return false;
    final name = m.group(1) ?? '';
    // كلمات إشارة ليست أسماء.
    const refs = {
      'هذا',
      'هاي',
      'بيه',
      'به',
      'وياه',
      'الثاني',
      'الاول',
      'الأول',
      'الثالث',
    };
    return name.length >= 2 && !refs.contains(name);
  }
}
