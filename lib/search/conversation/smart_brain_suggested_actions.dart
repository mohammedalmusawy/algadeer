import '../../search/smart_search_models.dart';
import '../../voice/conversation_context.dart';
import '../../voice/intent/assistant_intent.dart';
import '../../voice/intent/search_modifiers.dart';
import '../../voice/intent/smart_brain_planner.dart';
import '../arabic_text_utils.dart';

/// نوع اقتراح خطوة تالية بعد نتيجة Smart Brain.
enum SmartBrainSuggestedActionKind {
  openDetails,
  call,
  whatsapp,
  showMoreResults,
  showLocation,
  showPackages,
  showOffers,
  selectOrdinal,
  showAvailability,
  bookingGuidance,
  showAnalyses,
  showPackagePrice,
  showPhone,
  openPatientHealth,
  relaxFilter,
}

/// هدف مستنتج من آخر طلب — يوجّه ترتيب الاقتراحات فقط.
enum SmartBrainNextStepGoal {
  booking,
  location,
  details,
  availability,
  contact,
  health,
  general,
}

/// اقتراح ديناميكي منظم — التنفيذ بالمعرّف/الاستعلام لا بعنوان الزر.
class SmartBrainSuggestedAction {
  const SmartBrainSuggestedAction({
    required this.id,
    required this.kind,
    required this.label,
    this.result,
    this.entityId,
    this.entityType,
    this.ordinal,
    this.resultTurnId = 0,
    this.conversationGeneration = 0,
    this.executionQuery,
    this.functionId,
    this.infoTag,
  });

  /// معرّف فريد لنسخة الاقتراح في هذه الرسالة.
  final String id;
  final SmartBrainSuggestedActionKind kind;
  final String label;

  /// لقطة كيان وقت البناء — التنفيذ يفضّل [entityId] + إعادة التحقق.
  final SmartSearchResult? result;
  final String? entityId;
  final SmartSearchResultType? entityType;

  /// ترتيب 1-based كما شاهده المستخدم.
  final int? ordinal;
  final int resultTurnId;
  final int conversationGeneration;

  /// نص يمر بنفس مسار الأمر الكتابي عند التنفيذ.
  final String? executionQuery;

  /// ربط بسجل الوظائف إن وُجد.
  final String? functionId;

  /// وسم المعلومة التي يكشفها هذا الاقتراح (لتجنب التكرار).
  final String? infoTag;
}

/// حزمة اقتراحات + جملة قصيرة اختيارية أسفل الرد.
class SmartBrainNextStepBundle {
  const SmartBrainNextStepBundle({
    this.leadText,
    this.actions = const [],
    this.awaitsSingleYes = false,
  });

  final String? leadText;
  final List<SmartBrainSuggestedAction> actions;

  /// إن true: «نعم» تنفّذ الاقتراح الوحيد؛ وإلا عند تعدد الاقتراحات يُطلب توضيح.
  final bool awaitsSingleYes;

  static const empty = SmartBrainNextStepBundle();
}

/// بناء اقتراحات من سياق المحادثة ووظائف التطبيق الحالية — بلا قائمة ثابتة.
class SmartBrainSuggestedActionsBuilder {
  SmartBrainSuggestedActionsBuilder._();

  /// توافق قديم: اقتراحات من قائمة نتائج فقط (حد أقصى 3).
  static List<SmartBrainSuggestedAction> forResults(
    List<SmartSearchResult> results, {
    int maxActions = 3,
  }) {
    return suggest(
      presented: results,
      maxActions: maxActions,
    ).actions;
  }

  static SmartBrainNextStepBundle suggest({
    ConversationContext? context,
    List<SmartSearchResult> presented = const [],
    AssistantIntent? lastIntent,
    AssistantActionKind? planKind,
    String lastQuery = '',
    String lastMessage = '',
    Set<String> alreadyShownInfo = const {},
    SmartBrainSuggestedActionKind? justExecuted,
    bool patientSignedIn = false,
    SearchModifiers modifiers = SearchModifiers.none,
    int maxActions = 3,
  }) {
    final q = ArabicTextUtils.normalize(lastQuery);
    if (_looksLikeThanks(q)) return SmartBrainNextStepBundle.empty;

    final ctx = context;
    final gen = ctx?.conversationGeneration ?? 0;
    final resultTurn = ctx?.currentResultContext?.turnId ?? 0;
    final selected = ctx?.selectedEntity;
    final items = presented.isNotEmpty
        ? presented
        : (ctx?.currentResultContext?.items ?? const <SmartSearchResult>[]);
    final goal = _inferGoal(q, lastIntent);
    final shown = {...alreadyShownInfo};
    if (justExecuted != null) {
      shown.add(_tagForKind(justExecuted));
    }
    // بعد شرح طريقة الحجز لا نعيد اقتراح نفس الشريحة في نفس الجلسة.
    if (lastIntent == AssistantIntent.bookAppointment) {
      shown.add('booking');
    }

    // غموض / توضيح: خيارات تمييز بالاسم (حتى 3).
    if (planKind == AssistantActionKind.showClarification && items.length >= 2) {
      final hoursAsk = lastIntent == AssistantIntent.doctorAvailability;
      return _ordinalOpenBundle(
        items: items,
        lead: hoursAsk
            ? 'تقصد أي طبيب؟ اضغط الاسم أو اكتب رقمه.'
            : 'أي واحد تقصد؟ اضغط الاسم أو اكتب رقمه.',
        gen: gen,
        resultTurn: resultTurn,
        maxActions: maxActions,
        open: false,
      );
    }

    // بلا نتائج بحث: تخفيف شرط — ليس لسؤال عن دوام/موقع/حجز كيان.
    if (items.isEmpty &&
        lastIntent != AssistantIntent.doctorAvailability &&
        lastIntent != AssistantIntent.bookAppointment &&
        lastIntent != AssistantIntent.showLocation &&
        lastIntent != AssistantIntent.showProfile &&
        (planKind == AssistantActionKind.showMessage ||
            lastMessage.contains('ما لقيت') ||
            lastMessage.contains('لم أجد'))) {
      return _emptyResultsBundle(
        lastQuery: lastQuery,
        modifiers: modifiers,
        gen: gen,
        resultTurn: resultTurn,
      );
    }

    // ملف صحي — بوابات فقط، بلا قراءة بيانات.
    if (lastIntent == AssistantIntent.openPatientHealth ||
        goal == SmartBrainNextStepGoal.health ||
        _looksLikeHealth(q)) {
      return _healthBundle(
        gen: gen,
        resultTurn: resultTurn,
        patientSignedIn: patientSignedIn,
        shown: shown,
        maxActions: maxActions,
      );
    }

    // بعد اختيار كيان أو رد سياقي على كيان واحد.
    final focus = selected ??
        (items.length == 1
            ? items.first
            : (planKind == AssistantActionKind.selectEntity ||
                    planKind == AssistantActionKind.openProfile ||
                    planKind == AssistantActionKind.showLocation ||
                    planKind == AssistantActionKind.prepareCall ||
                    planKind == AssistantActionKind.prepareWhatsApp
                ? (ctx?.selectedEntity ??
                    (items.isEmpty ? null : items.first))
                : null));

    if (focus != null &&
        (selected != null ||
            items.length == 1 ||
            planKind == AssistantActionKind.selectEntity ||
            lastIntent == AssistantIntent.doctorAvailability ||
            lastIntent == AssistantIntent.bookAppointment ||
            lastIntent == AssistantIntent.showLocation ||
            lastIntent == AssistantIntent.showProfile ||
            lastIntent == AssistantIntent.callDoctor ||
            lastIntent == AssistantIntent.messageDoctor)) {
      if (focus.type == SmartSearchResultType.package ||
          focus.type == SmartSearchResultType.offer) {
        return _packageBundle(
          focus,
          goal: goal,
          shown: shown,
          gen: gen,
          resultTurn: resultTurn,
          justExecuted: justExecuted,
          maxActions: maxActions,
        );
      }
      if (focus.type == SmartSearchResultType.lab) {
        return _labBundle(
          focus,
          goal: goal,
          shown: shown,
          gen: gen,
          resultTurn: resultTurn,
          justExecuted: justExecuted,
          maxActions: maxActions,
        );
      }
      if (focus.type == SmartSearchResultType.doctor) {
        return _doctorSelectedBundle(
          focus,
          goal: goal,
          shown: shown,
          gen: gen,
          resultTurn: resultTurn,
          justExecuted: justExecuted,
          lastIntent: lastIntent,
          maxActions: maxActions,
        );
      }
      return _genericEntityBundle(
        focus,
        goal: goal,
        shown: shown,
        gen: gen,
        resultTurn: resultTurn,
        justExecuted: justExecuted,
        maxActions: maxActions,
      );
    }

    // نتائج بحث متعددة: أسماء مرقّمة للفتح — لا قائمة أزرار اتصال ثابتة.
    if (items.length >= 2) {
      final type = items.first.type;
      if (type == SmartSearchResultType.doctor ||
          type == SmartSearchResultType.lab ||
          type == SmartSearchResultType.pharmacy ||
          type == SmartSearchResultType.radiology ||
          type == SmartSearchResultType.physio ||
          type == SmartSearchResultType.optics ||
          type == SmartSearchResultType.beauty ||
          type == SmartSearchResultType.nursing) {
        final lead = type == SmartSearchResultType.doctor
            ? 'تريد تفاصيل أي طبيب؟ اضغط اسمه أو اكتب رقمه.'
            : 'أي نتيجة تريد تفاصيلها؟ اضغط اسمها أو اكتب رقمها.';
        return _ordinalOpenBundle(
          items: items,
          lead: lead,
          gen: gen,
          resultTurn: resultTurn,
          maxActions: maxActions,
          open: true,
        );
      }
    }

    if (items.length == 1) {
      final only = items.first;
      if (only.type == SmartSearchResultType.lab) {
        return _labBundle(
          only,
          goal: goal,
          shown: shown,
          gen: gen,
          resultTurn: resultTurn,
          justExecuted: justExecuted,
          maxActions: maxActions,
        );
      }
      if (only.type == SmartSearchResultType.doctor) {
        return _doctorSelectedBundle(
          only,
          goal: goal,
          shown: shown,
          gen: gen,
          resultTurn: resultTurn,
          justExecuted: justExecuted,
          lastIntent: lastIntent,
          maxActions: maxActions,
        );
      }
      return _genericEntityBundle(
        only,
        goal: goal,
        shown: shown,
        gen: gen,
        resultTurn: resultTurn,
        justExecuted: justExecuted,
        maxActions: maxActions,
      );
    }

    return SmartBrainNextStepBundle.empty;
  }

  static SmartBrainNextStepGoal _inferGoal(String q, AssistantIntent? intent) {
    if (intent == AssistantIntent.bookAppointment ||
        RegExp(r'احجز|حجز|موعد').hasMatch(q)) {
      return SmartBrainNextStepGoal.booking;
    }
    if (intent == AssistantIntent.showLocation ||
        RegExp(r'وين|عنوان|موقع|عياد').hasMatch(q)) {
      return SmartBrainNextStepGoal.location;
    }
    if (intent == AssistantIntent.doctorAvailability ||
        RegExp(r'دوام|متواجد|موجود|متوفر').hasMatch(q)) {
      return SmartBrainNextStepGoal.availability;
    }
    if (intent == AssistantIntent.showProfile ||
        RegExp(r'تفاصيل|بطاق|معلومات|ملف').hasMatch(q)) {
      return SmartBrainNextStepGoal.details;
    }
    if (intent == AssistantIntent.callDoctor ||
        intent == AssistantIntent.messageDoctor ||
        RegExp(r'اتصل|واتس|رقم').hasMatch(q)) {
      return SmartBrainNextStepGoal.contact;
    }
    if (intent == AssistantIntent.openPatientHealth || _looksLikeHealth(q)) {
      return SmartBrainNextStepGoal.health;
    }
    return SmartBrainNextStepGoal.general;
  }

  static bool _looksLikeThanks(String q) {
    final t = q.trim();
    return RegExp(
      r'^(?:شكرا|شكراً|شكرًا|مشكور|مشكورين|تسلم|الله\s*يسلمك|زین|زين)$',
    ).hasMatch(t);
  }

  static bool _looksLikeHealth(String q) {
    return RegExp(
      r'ملف(?:ي)?\s*الصحي|بطاقه?\s*المتابعه?|قراء(?:ة|ه)\s*(?:ضغط|سكر)',
    ).hasMatch(q);
  }

  static String _tagForKind(SmartBrainSuggestedActionKind k) {
    switch (k) {
      case SmartBrainSuggestedActionKind.showAvailability:
        return 'availability';
      case SmartBrainSuggestedActionKind.showLocation:
        return 'location';
      case SmartBrainSuggestedActionKind.bookingGuidance:
        return 'booking';
      case SmartBrainSuggestedActionKind.openDetails:
        return 'details';
      case SmartBrainSuggestedActionKind.call:
        return 'call';
      case SmartBrainSuggestedActionKind.whatsapp:
        return 'whatsapp';
      case SmartBrainSuggestedActionKind.showPhone:
        return 'phone';
      case SmartBrainSuggestedActionKind.showPackages:
        return 'packages';
      case SmartBrainSuggestedActionKind.showAnalyses:
        return 'analyses';
      case SmartBrainSuggestedActionKind.showPackagePrice:
        return 'price';
      case SmartBrainSuggestedActionKind.openPatientHealth:
        return 'health';
      default:
        return k.name;
    }
  }

  static String _entityIdOf(SmartSearchResult r) {
    switch (r.type) {
      case SmartSearchResultType.doctor:
        return (r.doctorId ?? '').trim();
      case SmartSearchResultType.lab:
        return (r.labId ?? '').trim();
      case SmartSearchResultType.radiology:
        return (r.radiologyId ?? '').trim();
      case SmartSearchResultType.pharmacy:
        return (r.pharmacyId ?? '').trim();
      case SmartSearchResultType.physio:
        return (r.physioId ?? '').trim();
      case SmartSearchResultType.supply:
        return (r.supplyId ?? '').trim();
      case SmartSearchResultType.optics:
        return (r.opticsId ?? '').trim();
      case SmartSearchResultType.beauty:
        return (r.beautyId ?? '').trim();
      case SmartSearchResultType.nursing:
        return (r.nursingId ?? '').trim();
      case SmartSearchResultType.package:
      case SmartSearchResultType.offer:
        return (r.packageId ?? '').trim();
      case SmartSearchResultType.analysis:
        return (r.analysisId ?? '').trim();
      case SmartSearchResultType.specialty:
        return '';
    }
  }

  static String _shortName(SmartSearchResult r) {
    final raw = ArabicTextUtils.stripHonorifics(r.title).trim();
    if (raw.isEmpty) return r.title.trim();
    if (r.type == SmartSearchResultType.doctor) return 'د. $raw';
    return raw;
  }

  static SmartBrainSuggestedAction _action({
    required SmartBrainSuggestedActionKind kind,
    required String label,
    required int gen,
    required int resultTurn,
    SmartSearchResult? result,
    int? ordinal,
    String? executionQuery,
    String? functionId,
    String? infoTag,
  }) {
    final eid = result == null ? null : _entityIdOf(result);
    return SmartBrainSuggestedAction(
      id: '${kind.name}_${eid ?? 'none'}_${ordinal ?? 0}_$resultTurn',
      kind: kind,
      label: label,
      result: result,
      entityId: (eid == null || eid.isEmpty) ? null : eid,
      entityType: result?.type,
      ordinal: ordinal,
      resultTurnId: resultTurn,
      conversationGeneration: gen,
      executionQuery: executionQuery,
      functionId: functionId,
      infoTag: infoTag ?? _tagForKind(kind),
    );
  }

  static SmartBrainNextStepBundle _ordinalOpenBundle({
    required List<SmartSearchResult> items,
    required String lead,
    required int gen,
    required int resultTurn,
    required int maxActions,
    required bool open,
  }) {
    final take = items.length > maxActions ? maxActions : items.length;
    final actions = <SmartBrainSuggestedAction>[];
    for (var i = 0; i < take; i++) {
      final r = items[i];
      final n = i + 1;
      final name = _shortName(r);
      final q = open ? 'افتح ${_ordinalWord(n)}' : _ordinalWord(n);
      actions.add(
        _action(
          kind: open
              ? SmartBrainSuggestedActionKind.openDetails
              : SmartBrainSuggestedActionKind.selectOrdinal,
          label: '$n. $name',
          result: r,
          ordinal: n,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: q,
          functionId: open ? 'open_ordinal' : 'select_ordinal',
          infoTag: 'ordinal_$n',
        ),
      );
    }
    return SmartBrainNextStepBundle(leadText: lead, actions: actions);
  }

  static String _ordinalWord(int n) {
    return switch (n) {
      1 => 'الأول',
      2 => 'الثاني',
      3 => 'الثالث',
      4 => 'الرابع',
      5 => 'الخامس',
      _ => 'رقم $n',
    };
  }

  static SmartBrainNextStepBundle _emptyResultsBundle({
    required String lastQuery,
    required SearchModifiers modifiers,
    required int gen,
    required int resultTurn,
  }) {
    final actions = <SmartBrainSuggestedAction>[];
    final cleaned = modifiers.cleanedQuery.trim().isNotEmpty
        ? modifiers.cleanedQuery.trim()
        : lastQuery.trim();
    if (modifiers.availableOnly && cleaned.isNotEmpty) {
      actions.add(
        _action(
          kind: SmartBrainSuggestedActionKind.relaxFilter,
          label: 'دور بدون شرط المتوفر',
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: cleaned,
          functionId: 'specialty_search',
          infoTag: 'relax_available',
        ),
      );
    }
    if (actions.isEmpty && cleaned.isNotEmpty) {
      actions.add(
        _action(
          kind: SmartBrainSuggestedActionKind.relaxFilter,
          label: 'غيّر البحث',
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: cleaned,
          infoTag: 'retry_search',
        ),
      );
    }
    if (actions.isEmpty) return SmartBrainNextStepBundle.empty;
    return SmartBrainNextStepBundle(
      leadText: 'أكدر أخفف شرط واحد إن تحب — اختر من الاقتراحات.',
      actions: actions.take(3).toList(growable: false),
      awaitsSingleYes: actions.length == 1,
    );
  }

  static SmartBrainNextStepBundle _healthBundle({
    required int gen,
    required int resultTurn,
    required bool patientSignedIn,
    required Set<String> shown,
    required int maxActions,
  }) {
    final actions = <SmartBrainSuggestedAction>[];
    if (!shown.contains('health')) {
      actions.add(
        _action(
          kind: SmartBrainSuggestedActionKind.openPatientHealth,
          label: patientSignedIn ? 'فتح ملفي الصحي' : 'دخول ملفي الصحي',
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'ملفي الصحي',
          functionId: 'patient_health',
        ),
      );
    }
    // لا نقترح مشاركة أو قراءة بيانات قبل التحقق — بوابة واحدة فقط.
    return SmartBrainNextStepBundle(
      leadText: patientSignedIn
          ? null
          : 'الملف الصحي يحتاج دخول المريض أولًا.',
      actions: actions.take(maxActions).toList(growable: false),
      awaitsSingleYes: actions.length == 1,
    );
  }

  static SmartBrainNextStepBundle _doctorSelectedBundle(
    SmartSearchResult doctor, {
    required SmartBrainNextStepGoal goal,
    required Set<String> shown,
    required int gen,
    required int resultTurn,
    required SmartBrainSuggestedActionKind? justExecuted,
    required AssistantIntent? lastIntent,
    required int maxActions,
  }) {
    final candidates = <SmartBrainSuggestedAction>[];

    void add(SmartBrainSuggestedAction a) {
      if (justExecuted == a.kind) return;
      if (a.infoTag != null && shown.contains(a.infoTag!)) return;
      candidates.add(a);
    }

    add(
      _action(
        kind: SmartBrainSuggestedActionKind.openDetails,
        label: 'عرض التفاصيل',
        result: doctor,
        gen: gen,
        resultTurn: resultTurn,
        executionQuery: 'افتح التفاصيل',
        functionId: 'open_selected_profile',
      ),
    );
    add(
      _action(
        kind: SmartBrainSuggestedActionKind.showAvailability,
        label: 'الدوام',
        result: doctor,
        gen: gen,
        resultTurn: resultTurn,
        executionQuery: 'شنو دوامه',
        functionId: 'availability_question',
      ),
    );
    add(
      _action(
        kind: SmartBrainSuggestedActionKind.bookingGuidance,
        label: 'طريقة الحجز',
        result: doctor,
        gen: gen,
        resultTurn: resultTurn,
        executionQuery: 'شلون أحجز',
        functionId: 'booking_guidance',
      ),
    );
    final loc = (doctor.clinicLocation ?? '').trim();
    if (loc.isNotEmpty) {
      add(
        _action(
          kind: SmartBrainSuggestedActionKind.showLocation,
          label: 'موقع العيادة',
          result: doctor,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'وين عيادته',
          functionId: 'show_location',
        ),
      );
    }
    if (doctor.canWhatsApp) {
      add(
        _action(
          kind: SmartBrainSuggestedActionKind.whatsapp,
          label: 'واتساب',
          result: doctor,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'دزله واتساب',
          functionId: 'whatsapp_selected',
        ),
      );
    }
    if (doctor.canCall) {
      add(
        _action(
          kind: SmartBrainSuggestedActionKind.call,
          label: 'اتصال',
          result: doctor,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'اتصل بيه',
          functionId: 'call_selected',
        ),
      );
    }
    if ((doctor.phone ?? '').trim().isNotEmpty) {
      add(
        _action(
          kind: SmartBrainSuggestedActionKind.showPhone,
          label: 'عرض الرقم',
          result: doctor,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'وريني رقمه',
          functionId: 'show_phone',
        ),
      );
    }

    // بعد الدوام: طريقة الحجز ثم موقع العيادة (ثم واتساب إن متاح).
    // بعد شرح الحجز: اتصال/واتساب أولاً بدون إعادة شريحة الحجز.
    final afterAvailability = lastIntent == AssistantIntent.doctorAvailability ||
        shown.contains('availability');
    final afterBooking = shown.contains('booking');
    final List<SmartBrainSuggestedAction> ordered;
    if (afterBooking) {
      int rank(SmartBrainSuggestedActionKind k) => switch (k) {
            SmartBrainSuggestedActionKind.call => 0,
            SmartBrainSuggestedActionKind.whatsapp => 1,
            SmartBrainSuggestedActionKind.showPhone => 2,
            SmartBrainSuggestedActionKind.showLocation => 3,
            SmartBrainSuggestedActionKind.openDetails => 4,
            _ => 9,
          };
      ordered = [...candidates]..sort((a, b) => rank(a.kind).compareTo(rank(b.kind)));
    } else if (afterAvailability) {
      int rank(SmartBrainSuggestedActionKind k) => switch (k) {
            SmartBrainSuggestedActionKind.bookingGuidance => 0,
            SmartBrainSuggestedActionKind.showLocation => 1,
            SmartBrainSuggestedActionKind.whatsapp => 2,
            SmartBrainSuggestedActionKind.call => 3,
            SmartBrainSuggestedActionKind.openDetails => 4,
            _ => 9,
          };
      ordered = [...candidates]..sort((a, b) => rank(a.kind).compareTo(rank(b.kind)));
    } else {
      ordered = _orderByGoal(candidates, goal);
    }

    String? lead;
    if (afterAvailability) {
      lead = null;
    } else if (goal == SmartBrainNextStepGoal.booking &&
        !shown.contains('booking')) {
      lead = 'تقدر تكمل بطريقة الحجز أو واتساب إن متوفر.';
    } else if (shown.contains('booking') &&
        (doctor.canCall || doctor.canWhatsApp)) {
      lead = null;
    }

    return SmartBrainNextStepBundle(
      leadText: lead,
      actions: ordered.take(maxActions).toList(growable: false),
    );
  }

  static SmartBrainNextStepBundle _labBundle(
    SmartSearchResult lab, {
    required SmartBrainNextStepGoal goal,
    required Set<String> shown,
    required int gen,
    required int resultTurn,
    required SmartBrainSuggestedActionKind? justExecuted,
    required int maxActions,
  }) {
    final candidates = <SmartBrainSuggestedAction>[];
    void add(SmartBrainSuggestedAction a) {
      if (justExecuted == a.kind) return;
      if (a.infoTag != null && shown.contains(a.infoTag!)) return;
      candidates.add(a);
    }

    add(
      _action(
        kind: SmartBrainSuggestedActionKind.openDetails,
        label: 'تفاصيل المختبر',
        result: lab,
        gen: gen,
        resultTurn: resultTurn,
        executionQuery: 'افتح التفاصيل',
        functionId: 'open_selected_profile',
      ),
    );
    add(
      _action(
        kind: SmartBrainSuggestedActionKind.showPackages,
        label: 'الباقات',
        result: lab,
        gen: gen,
        resultTurn: resultTurn,
        executionQuery: 'شنو الباقات',
        functionId: 'specialty_search',
      ),
    );
    add(
      _action(
        kind: SmartBrainSuggestedActionKind.showAnalyses,
        label: 'التحاليل',
        result: lab,
        gen: gen,
        resultTurn: resultTurn,
        executionQuery: 'شنو التحاليل',
      ),
    );
    final loc = (lab.clinicLocation ?? '').trim();
    if (loc.isNotEmpty) {
      add(
        _action(
          kind: SmartBrainSuggestedActionKind.showLocation,
          label: 'الموقع',
          result: lab,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'وين المختبر',
          functionId: 'show_location',
        ),
      );
    }
    if (lab.canWhatsApp) {
      add(
        _action(
          kind: SmartBrainSuggestedActionKind.whatsapp,
          label: 'واتساب',
          result: lab,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'دزله واتساب',
          functionId: 'whatsapp_selected',
        ),
      );
    }
    if (lab.canCall) {
      add(
        _action(
          kind: SmartBrainSuggestedActionKind.call,
          label: 'اتصال',
          result: lab,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'اتصل بيه',
          functionId: 'call_selected',
        ),
      );
    }

    return SmartBrainNextStepBundle(
      actions: _orderByGoal(candidates, goal).take(maxActions).toList(),
    );
  }

  static SmartBrainNextStepBundle _packageBundle(
    SmartSearchResult package, {
    required SmartBrainNextStepGoal goal,
    required Set<String> shown,
    required int gen,
    required int resultTurn,
    required SmartBrainSuggestedActionKind? justExecuted,
    required int maxActions,
  }) {
    final candidates = <SmartBrainSuggestedAction>[];
    void add(SmartBrainSuggestedAction a) {
      if (justExecuted == a.kind) return;
      if (a.infoTag != null && shown.contains(a.infoTag!)) return;
      candidates.add(a);
    }

    add(
      _action(
        kind: SmartBrainSuggestedActionKind.openDetails,
        label: 'تفاصيل الباقة',
        result: package,
        gen: gen,
        resultTurn: resultTurn,
        executionQuery: 'افتح التفاصيل',
      ),
    );
    add(
      _action(
        kind: SmartBrainSuggestedActionKind.showPackagePrice,
        label: 'السعر المسجّل',
        result: package,
        gen: gen,
        resultTurn: resultTurn,
        executionQuery: 'شنو سعرها',
      ),
    );
    if (package.canWhatsApp || package.canCall) {
      add(
        _action(
          kind: package.canWhatsApp
              ? SmartBrainSuggestedActionKind.whatsapp
              : SmartBrainSuggestedActionKind.call,
          label: package.canWhatsApp ? 'طريقة التواصل' : 'اتصال',
          result: package,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: package.canWhatsApp ? 'دزله واتساب' : 'اتصل بيه',
        ),
      );
    }
    return SmartBrainNextStepBundle(
      actions: _orderByGoal(candidates, goal).take(maxActions).toList(),
    );
  }

  static SmartBrainNextStepBundle _genericEntityBundle(
    SmartSearchResult entity, {
    required SmartBrainNextStepGoal goal,
    required Set<String> shown,
    required int gen,
    required int resultTurn,
    required SmartBrainSuggestedActionKind? justExecuted,
    required int maxActions,
  }) {
    final candidates = <SmartBrainSuggestedAction>[];
    void add(SmartBrainSuggestedAction a) {
      if (justExecuted == a.kind) return;
      if (a.infoTag != null && shown.contains(a.infoTag!)) return;
      candidates.add(a);
    }

    add(
      _action(
        kind: SmartBrainSuggestedActionKind.openDetails,
        label: 'عرض التفاصيل',
        result: entity,
        gen: gen,
        resultTurn: resultTurn,
        executionQuery: 'افتح التفاصيل',
        functionId: 'open_selected_profile',
      ),
    );
    final loc = (entity.clinicLocation ?? '').trim();
    if (loc.isNotEmpty) {
      add(
        _action(
          kind: SmartBrainSuggestedActionKind.showLocation,
          label: 'الموقع',
          result: entity,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'وين مكانه',
          functionId: 'show_location',
        ),
      );
    }
    if (entity.canWhatsApp) {
      add(
        _action(
          kind: SmartBrainSuggestedActionKind.whatsapp,
          label: 'واتساب',
          result: entity,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'دزله واتساب',
        ),
      );
    }
    if (entity.canCall) {
      add(
        _action(
          kind: SmartBrainSuggestedActionKind.call,
          label: 'اتصال',
          result: entity,
          gen: gen,
          resultTurn: resultTurn,
          executionQuery: 'اتصل بيه',
        ),
      );
    }
    return SmartBrainNextStepBundle(
      actions: _orderByGoal(candidates, goal).take(maxActions).toList(),
    );
  }

  static List<SmartBrainSuggestedAction> _orderByGoal(
    List<SmartBrainSuggestedAction> input,
    SmartBrainNextStepGoal goal,
  ) {
    int rank(SmartBrainSuggestedActionKind k) {
      switch (goal) {
        case SmartBrainNextStepGoal.booking:
          return switch (k) {
            SmartBrainSuggestedActionKind.bookingGuidance => 0,
            SmartBrainSuggestedActionKind.whatsapp => 1,
            SmartBrainSuggestedActionKind.call => 2,
            SmartBrainSuggestedActionKind.showAvailability => 3,
            SmartBrainSuggestedActionKind.openDetails => 4,
            SmartBrainSuggestedActionKind.showLocation => 5,
            _ => 9,
          };
        case SmartBrainNextStepGoal.location:
          return switch (k) {
            SmartBrainSuggestedActionKind.showLocation => 0,
            SmartBrainSuggestedActionKind.openDetails => 1,
            SmartBrainSuggestedActionKind.bookingGuidance => 2,
            _ => 9,
          };
        case SmartBrainNextStepGoal.details:
          return switch (k) {
            SmartBrainSuggestedActionKind.openDetails => 0,
            SmartBrainSuggestedActionKind.showAvailability => 1,
            SmartBrainSuggestedActionKind.bookingGuidance => 2,
            _ => 9,
          };
        case SmartBrainNextStepGoal.availability:
          return switch (k) {
            SmartBrainSuggestedActionKind.showAvailability => 0,
            SmartBrainSuggestedActionKind.bookingGuidance => 1,
            SmartBrainSuggestedActionKind.showLocation => 2,
            _ => 9,
          };
        case SmartBrainNextStepGoal.contact:
          return switch (k) {
            SmartBrainSuggestedActionKind.whatsapp => 0,
            SmartBrainSuggestedActionKind.call => 1,
            SmartBrainSuggestedActionKind.showPhone => 2,
            SmartBrainSuggestedActionKind.bookingGuidance => 3,
            _ => 9,
          };
        case SmartBrainNextStepGoal.health:
          return switch (k) {
            SmartBrainSuggestedActionKind.openPatientHealth => 0,
            _ => 9,
          };
        case SmartBrainNextStepGoal.general:
          return switch (k) {
            SmartBrainSuggestedActionKind.openDetails => 0,
            SmartBrainSuggestedActionKind.showPackages => 1,
            SmartBrainSuggestedActionKind.showAnalyses => 2,
            SmartBrainSuggestedActionKind.bookingGuidance => 3,
            SmartBrainSuggestedActionKind.showAvailability => 4,
            SmartBrainSuggestedActionKind.showLocation => 5,
            SmartBrainSuggestedActionKind.showPackagePrice => 6,
            SmartBrainSuggestedActionKind.whatsapp => 7,
            SmartBrainSuggestedActionKind.call => 8,
            _ => 9,
          };
      }
    }

    final copy = [...input];
    copy.sort((a, b) => rank(a.kind).compareTo(rank(b.kind)));
    return copy;
  }
}
