import '../../search/arabic_text_utils.dart';
import '../../search/doctor_name_matcher.dart';
import '../../search/smart_search_models.dart';
import '../context_resolver.dart';
import '../conversation_context.dart';
import '../ghadeer_followup_context.dart';
import 'assistant_intent.dart';
import 'intent_result.dart';

/// مصدر هدف الطبيب بعد حل موحّد.
enum DoctorTargetSource {
  /// اسم صريح حقيقي في العبارة الحالية.
  explicitName,

  /// ترتيب يشير لنتائج الجلسة السابقة (الأول / الثاني…).
  ordinal,

  /// الطبيب المحدد حالياً في ConversationContext.
  selectedContext,

  /// لا هدف كافٍ — توضيح أو بحث حسب النية.
  unresolved,
}

/// ناتج حل هدف الطبيب — طبقة واحدة قبل البحث/المطابقة/التنفيذ.
class DoctorTargetResolution {
  const DoctorTargetResolution({
    required this.source,
    this.doctor,
    this.explicitName,
    this.resultIndex,
    this.requiresSearch = false,
    this.requiresClarification = false,
    this.candidates = const [],
    this.message = '',
  });

  final DoctorTargetSource source;
  final SmartSearchResult? doctor;
  final String? explicitName;

  /// 1-based، أو -1 للأخير.
  final int? resultIndex;
  final bool requiresSearch;
  final bool requiresClarification;
  final List<SmartSearchResult> candidates;
  final String message;

  bool get hasDoctor =>
      doctor != null && doctor!.type == SmartSearchResultType.doctor;

  bool get isResolved =>
      source == DoctorTargetSource.explicitName ||
      source == DoctorTargetSource.ordinal ||
      source == DoctorTargetSource.selectedContext;

  static const unresolved = DoctorTargetResolution(
    source: DoctorTargetSource.unresolved,
    requiresClarification: true,
    message: 'أي طبيب تقصد؟ ابحث عن الطبيب أو اذكر اسمه أولاً.',
  );
}

/// طبقة موحّدة لحل هدف الطبيب: INTENT + TARGET + CONTEXT.
///
/// ترتيب الأولوية للإجراءات:
/// 1) اسم صريح حقيقي في العبارة
/// 2) ترتيب صريح على نتائج سابقة
/// 3) selectedEntity / نتيجة طبيب وحيدة في السياق
/// 4) غير محلول → توضيح (بدون بحث عن «الدكتور»)
class DoctorTargetResolver {
  const DoctorTargetResolver();

  DoctorTargetResolution resolve({
    required IntentResult intentResult,
    required ConversationContext context,
  }) {
    final entities = intentResult.entities;
    final normalized = intentResult.normalizedText;

    // 1) اسم صريح — نتائج ResultContext الحالية أولاً، ثم بحث إن لزم.
    final explicit = _explicitRealName(entities.doctorName);
    if (explicit != null) {
      final fromCurrent = _resolveExplicitNameInCurrentResults(
        explicit,
        context,
      );
      if (fromCurrent != null) return fromCurrent;
      return DoctorTargetResolution(
        source: DoctorTargetSource.explicitName,
        explicitName: explicit,
        requiresSearch: true,
      );
    }

    // 2) ترتيب على نتائج سابقة (مع أو بدون فعل إجراء).
    final ordinal = entities.resultIndex ??
        ContextResolver.extractOrdinal(normalized);
    if (ordinal != null && _ordinalApplies(intentResult, normalized)) {
      return _resolveOrdinal(ordinal, context);
    }

    // 3) الطبيب المحدد — لا يُستخدم إن كان المختبر هو الكيان النشط لإجراء سياقي.
    final selected = context.selectedDoctor;
    if (selected != null &&
        selected.type == SmartSearchResultType.doctor &&
        !(intentResult.requiresContext &&
            (context.activeEntityType == ConversationEntityType.laboratory ||
                context.activeEntityType == ConversationEntityType.package ||
                context.activeEntityType ==
                    ConversationEntityType.analysis))) {
      return DoctorTargetResolution(
        source: DoctorTargetSource.selectedContext,
        doctor: selected,
      );
    }

    // 3b) نتيجة طبيب وحيدة ظاهرة — اعتمدها فوراً (حتى لو فات التحديد).
    final sole = _soleDoctor(context);
    if (sole != null) {
      context.selectDoctor(sole);
      return DoctorTargetResolution(
        source: DoctorTargetSource.selectedContext,
        doctor: sole,
      );
    }

    // 4) غير محلول.
    if (intentResult.isActionIntent &&
        intentResult.intent != AssistantIntent.selectResult) {
      return DoctorTargetResolution(
        source: DoctorTargetSource.unresolved,
        requiresClarification: true,
        candidates: context.clarificationCandidates,
        message: _missingMessage(intentResult.intent),
      );
    }

    return DoctorTargetResolution.unresolved;
  }

  /// هل الترتيب صالح كهدف لهذه النية؟
  bool _ordinalApplies(IntentResult intent, String normalized) {
    if (intent.intent == AssistantIntent.selectResult) return true;
    if (intent.isActionIntent) return true;
    // جملة قصيرة تتمحور حول الترتيب.
    return ContextResolver.extractOrdinal(normalized) != null;
  }

  DoctorTargetResolution _resolveOrdinal(
    int ordinal,
    ConversationContext context,
  ) {
    // PC-0.2: ResultContext / clarification فقط — ليس lastDoctorSnapshot.
    final doctors = context.authoritativeItemsFor(ConversationEntityType.doctor);
    if (doctors.isEmpty) {
      return DoctorTargetResolution(
        source: DoctorTargetSource.unresolved,
        requiresClarification: true,
        message: GhadeerFollowUpContext.noSelectableResultsMessage(
          requestedOrdinal: ordinal == -1 ? null : ordinal,
        ),
      );
    }

    final index = ordinal == -1 ? doctors.length : ordinal;
    if (index < 1 || index > doctors.length) {
      final requested = ordinal == -1 ? doctors.length + 1 : ordinal;
      return DoctorTargetResolution(
        source: DoctorTargetSource.unresolved,
        requiresClarification: true,
        resultIndex: ordinal,
        candidates: doctors,
        message: GhadeerFollowUpContext.outOfRangeMessage(
          requestedOrdinal: requested,
          availableCount: doctors.length,
        ),
      );
    }

    final chosen = context.selectDoctorByOrdinal(index);
    return DoctorTargetResolution(
      source: DoctorTargetSource.ordinal,
      doctor: chosen,
      resultIndex: index,
    );
  }

  static SmartSearchResult? _soleDoctor(ConversationContext context) {
    final doctors = context.authoritativeItemsFor(ConversationEntityType.doctor);
    if (doctors.length == 1) return doctors.first;
    return null;
  }

  /// اسم حقيقي فقط — الألقاب المهنية / الترتيب وحدها ليست أسماء.
  static String? _explicitRealName(String? raw) {
    var cleaned = ArabicTextUtils.normalize((raw ?? '').trim())
        .replaceAll(RegExp(r'[،,؟?!.]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty || cleaned.length <= 1) return null;

    // بقايا حرف جر قبل ترتيب: للثاني / على الاول
    cleaned = cleaned.replaceFirst(RegExp(r'^(?:ل|ب|على)'), '').trim();
    cleaned = ArabicTextUtils.normalize(cleaned);

    if (_isRoleOnly(cleaned)) return null;
    if (_isOrdinalPhrase(cleaned)) return null;
    if (_isActionNoise(cleaned)) return null;

    // انزع ألقاباً متبقية ثم تحقق أن الباقي اسم.
    final withoutRole = ArabicTextUtils.stripHonorifics(cleaned).trim();
    final prepared = ArabicTextUtils.prepareDoctorNameQuery(
      withoutRole.isNotEmpty ? withoutRole : cleaned,
    );
    final p = ArabicTextUtils.normalize(prepared).trim();
    if (p.isEmpty || p.length <= 1) return null;
    if (_isRoleOnly(p) || _isOrdinalPhrase(p) || _isActionNoise(p)) {
      return null;
    }
    return prepared.trim();
  }

  static bool _isRoleOnly(String t) {
    return RegExp(
      r'^(?:ال)?(?:دكتور|دكتوره|دكتورة|طبيب|طبيبه|طبيبة)$',
    ).hasMatch(t);
  }

  static bool _isOrdinalPhrase(String t) {
    final n = ArabicTextUtils.normalize(t.trim());
    return RegExp(
      r'^(?:ال)?(?:اول|أول|ثاني|ثالث|رابع|خامس|اخير|أخير)(?:\s*واحد)?$|^رقم\s*[123١٢٣]$',
    ).hasMatch(n);
  }

  /// تطابق اسم صريح مع نتائج الطبيب السلطوية الحالية فقط — بلا تخمين.
  DoctorTargetResolution? _resolveExplicitNameInCurrentResults(
    String explicit,
    ConversationContext context,
  ) {
    final resultCtx = context.currentResultContext;
    if (resultCtx == null ||
        resultCtx.entityType != ConversationEntityType.doctor ||
        resultCtx.isEmpty) {
      return null;
    }

    final items = context.authoritativeItemsFor(ConversationEntityType.doctor);
    if (items.isEmpty) return null;

    final batch = const DoctorNameMatcher().matchDoctors(
      query: explicit,
      doctors: [
        for (final d in items) (id: d.doctorId ?? d.title, name: d.title),
      ],
    );
    if (batch.matches.isEmpty) return null;

    if (batch.isAmbiguous ||
        (batch.matches.length > 1 && !batch.best!.isStrong)) {
      final matchedIds = <String>{
        for (final m in batch.plausible) m.doctorId ?? m.doctorName,
      };
      final candidates = items
          .where(
            (d) =>
                matchedIds.contains(d.doctorId ?? d.title) ||
                matchedIds.contains(d.title),
          )
          .toList();
      return DoctorTargetResolution(
        source: DoctorTargetSource.explicitName,
        explicitName: explicit,
        requiresClarification: true,
        candidates: candidates.isNotEmpty ? candidates : items,
        message: 'وجدت أكثر من طبيب. حدّد من القائمة أو قل: الثاني / الأول.',
      );
    }

    final best = batch.best!;
    SmartSearchResult? chosen;
    for (final d in items) {
      if (d.doctorId == best.doctorId ||
          d.title == best.doctorName ||
          (best.doctorId != null && d.title == best.doctorId)) {
        chosen = d;
        break;
      }
    }
    if (chosen == null) return null;

    context.selectDoctor(chosen);
    return DoctorTargetResolution(
      source: DoctorTargetSource.explicitName,
      doctor: chosen,
      explicitName: explicit,
    );
  }

  static bool _isActionNoise(String t) {
    return RegExp(
      r'^(?:دزله|دزّله|دزوله|راسله|راسلها|راسل|ارسل|أرسل|رسالة|رساله|اتصل|اتصال|دق|دك|واتساب|واتس|whatsapp|بيه|به|بيها|بها|وياه|عليه|عليها|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها)$',
    ).hasMatch(t);
  }

  static String _missingMessage(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.bookAppointment:
        return GhadeerFollowUpContext.noPronounTargetMessage();
      case AssistantIntent.showLocation:
        return 'حدد الطبيب أولاً ثم اسأل عن العيادة.';
      case AssistantIntent.showProfile:
        return 'حدد الطبيب أولاً حتى أفتح ملفه.';
      default:
        return 'حدد الطبيب أولاً من نتائج البحث.';
    }
  }

  /// هل الاستعلام بحث جديد يجب أن يُبطل الهدف القديم؟
  static bool isNewDoctorSearchIntent(AssistantIntent intent) {
    return intent == AssistantIntent.specialtySearch ||
        intent == AssistantIntent.doctorSearch ||
        intent == AssistantIntent.generalSearch;
  }
}

/// أدوات مساعدة للكيانات — تنظيف مضبوط للغة الإجراء مقابل الاسم.
class ActionLanguageCleanup {
  const ActionLanguageCleanup._();

  /// يزيل أفعال الإجراء وحروف الجر والألقاب ويترك مرشّح الاسم فقط.
  static String? extractExplicitDoctorName(String original) {
    var s = original.trim();
    if (s.isEmpty) return null;

    s = s.replaceFirst(
      RegExp(
        r'^(?:أريد|اريد|ابي|أبغى|من\s+فضلك|لو\s+سمحت)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:أرسل|ارسل|راسل|ابعث|إرسال)?\s*'
        r'(?:رسالة\s*)?(?:واتساب|واتس\s*اب|واتس|whatsapp)\s*'
        r'(?:رسالة\s*)?',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        // «دك/دق/دگ» كلمة كاملة فقط — لا تقطع بادئة «دكتور».
        r'^(?:اتصل|اتصال|كلّم|كلم|(?:دق|دك|دگ)(?=\s|$)|دگله|دقله|دزله|دزّله|دز|راسل|أرسل|ارسل|افتح|اعرض)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:وين|اين|أين)\s*(?:عيادة|عيادته|مكان|مكانه|موقع|موقعه|عنوان|عنوانه)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(r'^(?:ب|على|ل|في|مع|عن|إلى|الى)?\s*', caseSensitive: false),
      '',
    );
    // بقايا «ل» من «للدكتور».
    s = s.replaceFirst(RegExp(r'^ل(?=دكتور|طبيب|دكتورة|طبيبة)'), '').trim();
    s = ArabicTextUtils.stripHonorifics(s).trim();
    s = s
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:الاول|الأول|اول|أول|الثاني|ثاني|الثالث|ثالث|الرابع|رابع|الخامس|خامس|الاخير|الأخير)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|ملفه|نبذته|عيادته|مكانه|موقعه)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return DoctorTargetResolver._explicitRealName(s);
  }
}
