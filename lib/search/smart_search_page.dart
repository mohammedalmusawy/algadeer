import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../companion/personal_companion_profile_service.dart';
import '../doctors/doctor_profile_page.dart';
import '../doctors/specialty_catalog.dart';
import '../labs/lab_package_detail_page.dart';
import '../labs/lab_profile_page.dart';
import '../labs/labs_service.dart';
import '../medical/medical_navigation_service.dart';
import '../models/doctor_item.dart';
import '../utils/contact_launch.dart';
import '../utils/clinic_contact_message.dart';
import '../voice/arabic_speech_numbers.dart';
import '../voice/assistant_orchestrator.dart';
import '../voice/clarification/clarification_models.dart';
import '../voice/context_resolver.dart';
import '../voice/conversation_context.dart';
import '../voice/intent/intent_resolver.dart';
import '../voice/intent/smart_brain_fallback_policy.dart';
import '../voice/intent/smart_brain_planner.dart';
import '../voice/speech_recognition_service.dart';
import '../voice/voice_assistant_state.dart';
import '../voice/voice_input_service.dart';
import '../voice/voice_response_controller.dart';
import '../voice/voice_settings.dart';
import 'arabic_text_utils.dart';
import 'conversation/smart_brain_chat_models.dart';
import 'conversation/smart_brain_chat_widgets.dart';
import 'conversation/smart_brain_turn_results.dart';
import 'doctor_name_matcher.dart';
import 'query_input_source.dart';
import 'smart_search_models.dart';
import 'smart_search_service.dart';
import 'voice_contact_command.dart';
import 'voice_specialty_search_command.dart';
import '../widgets/clinic_app_bar.dart';

/// مساعد الغدير الذكي — واجهة محادثة فوق مسار Unified Brain الموحّد (نص + صوت).
class SmartSearchPage extends StatefulWidget {
  const SmartSearchPage({
    super.key,
    this.initialQuery = '',
    this.autoStartVoice = false,
  });

  final String initialQuery;
  final bool autoStartVoice;

  @override
  State<SmartSearchPage> createState() => _SmartSearchPageState();
}

class _SmartSearchPageState extends State<SmartSearchPage>
    with WidgetsBindingObserver {
  static const _teal = Color(0xFF0FAFA3);

  final _controller = TextEditingController();
  final _fieldFocus = FocusNode();
  final _scrollController = ScrollController();
  final _search = SmartSearchService();
  final _medical = MedicalNavigationService();
  final _conversation = ConversationContext();
  final _contextResolver = const ContextResolver();
  final _intentResolver = RuleBasedIntentResolver();
  late final SmartBrainPlanner _brainPlanner;
  late final VoiceInputService _voiceInput;
  late final AssistantOrchestrator _assistant;
  final _voiceSettings = VoiceSettingsService();
  late final VoiceResponseController _voice;
  final _fallbackPolicy = SmartBrainFallbackPolicy();
  final _profileService = PersonalCompanionProfileService();

  /// آخر قرار سقوط آمن — للاختبارات (بلا نص أعراض خام).
  SmartBrainSafeFallbackOutcome? lastSafeFallbackOutcomeForTest;

  Timer? _debounce;
  Timer? _voiceLiveDebounce;
  VoiceContactKind? _pendingContactKind;
  String _pendingWhatsAppMessage = '';

  /// نتائج جلسة — جسر مؤقت للتوافق مع أوامر الاتصال القديمة.
  /// المصدر الأساسي: [_conversation.lastDoctorSnapshot] فقط.
  List<SmartSearchResult> get _sessionDoctorResults =>
      _conversation.lastDoctorSnapshot;

  String? get _sessionSpecialtyLabel => _conversation.sessionSpecialtyLabel;

  /// النتائج المحفوظة للجلسة. الكتابة تُنسِب النتائج لدور المحادثة الحالي،
  /// فبطاقات الرد تُرسم من مخرجات الدور لا من الذاكرة التاريخية.
  final _turnResults = SmartBrainTurnResults();

  List<SmartSearchResult> get _results => _turnResults.retained;

  set _results(List<SmartSearchResult> value) =>
      _turnResults.remember(value, turn: _searchEpoch);

  AssistantReply? _assistantReply;
  bool _loading = false;
  bool _suppressQueryListener = false;
  Future<void>? _speechWarmUp;
  String? _listenPreview;
  String? _searchError;
  int _searchEpoch = 0;
  bool _navigating = false;

  /// عدّاد إطلاق اتصال/واتساب خارجي — لا نسترجع تركيز الكتابة بعده.
  int _externalContactLaunches = 0;

  /// سجل عرض الجلسة فقط — ليس سلطة سياق الدماغ.
  final List<SmartBrainChatTurn> _chatTurns = [];
  int _chatTurnSeq = 0;

  @visibleForTesting
  List<SmartBrainChatTurn> get chatTurnsForTest =>
      List<SmartBrainChatTurn>.unmodifiable(_chatTurns);

  @visibleForTesting
  ConversationContext get conversationForTest => _conversation;

  /// autoStartVoice يُستهلك مرة واحدة لكل نسخة route — لا يتكرر مع rebuild.
  bool _autoStartVoiceConsumed = false;

  /// إلغاء autoStart إن ضغط المستخدم المايك قبل تنفيذ الـ post-frame.
  bool _autoStartCancelled = false;

  /// قفل متزامن قبل أي await — يمنع startSession مرتين من سباق async.
  bool _voiceStartInFlight = false;

  /// عدّاد محاولات startSession لهذه الصفحة (للتشخيص/الاختبار).
  int _voiceStartAttemptCount = 0;

  @visibleForTesting
  int get voiceStartAttemptCountForTest => _voiceStartAttemptCount;

  bool get _listening => _voiceInput.isListeningUi;
  bool get _voiceSessionActive => _voiceInput.sessionActive;
  bool get _voiceBusy => _voiceInput.busy;
  bool get _manualStopRequested => _voiceInput.manualStopRequested;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[SMART_SEARCH] initState autoStartVoice=${widget.autoStartVoice} '
      'hash=$hashCode',
    );
    WidgetsBinding.instance.addObserver(this);
    final stt = DeviceSpeechRecognitionService();
    _voiceInput = VoiceInputService(stt: stt);
    _voiceInput.addListener(_onVoiceInputChanged);
    _voice = VoiceResponseController(settings: _voiceSettings);
    _assistant = AssistantOrchestrator(
      search: _search,
      medical: _medical,
      voice: _voice,
      stt: stt,
    );
    _brainPlanner = SmartBrainPlanner(
      intentResolver: _intentResolver,
      contextResolver: _contextResolver,
      search: _search,
    );
    _seedWelcomeTurn();
    unawaited(_loadWelcomeName());
    if (widget.initialQuery.trim().isNotEmpty) {
      _controller.text = widget.initialQuery.trim();
      unawaited(
        _runSearch(widget.initialQuery.trim(), source: QueryInputSource.system),
      );
    }
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Prefetch doctors cache حتى أول حرف يبحث محليًا بدون انتظار.
      unawaited(_search.prefetchDoctorsCache());
      // تهيئة صامتة مرة واحدة حتى تكون الضغطة الأولى = listen مباشرة.
      _speechWarmUp = _warmUpSpeechRecognition();
      unawaited(_speechWarmUp!);
      if (widget.autoStartVoice && !_autoStartVoiceConsumed) {
        _autoStartVoiceConsumed = true;
        if (_autoStartCancelled) {
          debugPrint(
            '[MIC] autoStart skipped — already cancelled by manual tap',
          );
          return;
        }
        debugPrint('[MIC] autoStartVoice → startSession source=autoStart');
        unawaited(_toggleVoice(source: 'autoStart'));
      }
    });
  }

  void _seedWelcomeTurn() {
    _chatTurns.add(
      SmartBrainChatTurn.assistant(
        id: 'welcome',
        text: _welcomeTextFor(null),
        isWelcome: true,
      ),
    );
  }

  String _welcomeTextFor(String? preferredName) {
    final name = preferredName?.trim();
    if (name != null && name.isNotEmpty) {
      return 'هلا $name 👋\nآني الغدير. شلون أگدر أساعدك اليوم؟';
    }
    return 'هلا 👋\nآني الغدير. شلون أگدر أساعدك اليوم؟';
  }

  Future<void> _loadWelcomeName() async {
    try {
      final name = await _profileService.preferredNameForPersonalization();
      if (!mounted) return;
      if (_chatTurns.length == 1 && _chatTurns.first.isWelcome) {
        setState(() {
          _chatTurns[0] = SmartBrainChatTurn.assistant(
            id: 'welcome',
            text: _welcomeTextFor(name),
            isWelcome: true,
          );
        });
      }
    } catch (_) {
      // فشل الملف لا يكسر واجهة المحادثة.
    }
  }

  String _nextTurnId(String prefix) {
    _chatTurnSeq += 1;
    return '${prefix}_$_chatTurnSeq';
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  /// يبدأ دورة مستخدم في سجل العرض فقط — الدماغ يبقى [_conversation].
  void _beginUserTurn(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _chatTurns.removeWhere((t) => t.isThinking);
      _chatTurns.add(
        SmartBrainChatTurn.user(trimmed, id: _nextTurnId('user')),
      );
      _chatTurns.add(
        SmartBrainChatTurn.thinking(id: _nextTurnId('thinking')),
      );
      _loading = true;
      _searchError = null;
    });
    _scrollChatToEnd();
  }

  /// يلحق رد مساعد واحد من حالة الدماغ الحالية — بلا تكرار بانر/فقاعة.
  void _commitAssistantTurn() {
    if (!mounted) return;
    // بطاقات هذا الرد = ما أنتجه هذا الدور فقط. طبيب محدد أو نتائج سابقة
    // تبقى في الذاكرة للأفعال، لكنها لا تُعرض تحت رد لا يرجّعها.
    final presented = _turnResults.presentedIn(_searchEpoch);
    final replyText = (_assistantReply?.text ?? '').trim();
    final err = (_searchError ?? '').trim();
    late final String text;
    if (replyText.isNotEmpty && err.isNotEmpty && replyText == err) {
      text = replyText;
    } else if (replyText.isNotEmpty) {
      text = replyText;
    } else if (err.isNotEmpty) {
      text = err;
    } else if (presented.isNotEmpty) {
      text = presented.length == 1
          ? 'لقيت نتيجة مناسبة لطلبك.'
          : 'لقيت ${presented.length} نتائج قريبة من طلبك.';
    } else {
      text = 'ما كدرت أكمل الطلب حالياً. جرّب صياغة ثانية إن تحب.';
    }

    final attached = List<SmartSearchResult>.from(presented);
    final urgent = _assistantReply?.source == AssistantReplySource.urgentCare;

    setState(() {
      _chatTurns.removeWhere((t) => t.isThinking);
      _chatTurns.add(
        SmartBrainChatTurn.assistant(
          id: _nextTurnId('assistant'),
          text: text,
          results: attached,
          isUrgent: urgent,
        ),
      );
      _loading = false;
    });
    _scrollChatToEnd();
  }

  void _cancelThinkingIfStale() {
    if (!mounted) return;
    setState(() {
      _chatTurns.removeWhere((t) => t.isThinking);
      _loading = false;
    });
  }

  void _onVoiceInputChanged() {
    if (!mounted) return;
    setState(() {
      final t = _voiceInput.transcript.trim();
      if (t.isNotEmpty) _listenPreview = t;
    });
  }

  /// تهيئة STT صامتة فقط عندما يمكن ذلك بأمان (صلاحيات ممنوحة أو attribution آمن).
  Future<void> _warmUpSpeechRecognition() async {
    if (!DeviceSpeechRecognitionService.isSupportedOnThisPlatform) return;
    try {
      if (!await DeviceSpeechRecognitionService.canInitializeSafely()) {
        debugPrint('Smart search STT warm-up skipped — not safe to init yet');
        return;
      }
      if (!mounted) return;
      await _assistant.stt.initialize();
    } catch (e, st) {
      debugPrint('Smart search STT warm-up failed: $e\n$st');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[LIFECYCLE] SmartSearch AppLifecycleState=$state');
    if (state == AppLifecycleState.paused) {
      unawaited(_cancelListening());
    }
  }

  Future<void> _cancelListening() async {
    if (!_listening && !_voiceSessionActive && !_assistant.stt.isListening) {
      return;
    }
    await _voiceInput.cancelSession();
    if (mounted) setState(() {});
  }

  void _onQueryChanged() {
    if (_suppressQueryListener) return;
    // تحديث زر المسح/الواجهة فقط — لا بحث تلقائي أثناء الكتابة (محادثة submit-only).
    if (mounted) setState(() {});
  }

  void _setFieldText(String text) {
    _suppressQueryListener = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _suppressQueryListener = false;
  }

  Future<void> _silenceVoice() async {
    try {
      await _voice.stop();
    } catch (_) {}
  }

  /// أثناء الاستماع: حدّث النص فقط — بلا بحث محلي موازٍ في سجل المحادثة.
  void _onVoiceTranscript(String text, {required bool isFinal}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _setFieldText(trimmed);
    if (!mounted) return;
    setState(() {
      _listenPreview = trimmed;
    });
    // النهائي يُثبَّت عند إيقاف المايك عبر Unified Brain — لا مقترحات بحث حيّة.
  }

  Future<void> _runSearch(
    String query, {
    QueryInputSource source = QueryInputSource.typed,
  }) async {
    final trimmed = query.trim();
    final allowSpeak = source.allowsAutoSpeak;
    final showVoiceUi = source.showsVoiceProcessingUi;

    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      return;
    }

    // أوقف نطقًا سابقًا فقط إن كان يعمل فعلًا.
    // استدعاء stop على محرك خامل قبل الرد الصوتي يقطع الجملة على بعض المنصات.
    if (_voice.isSpeaking) {
      await _silenceVoice();
    }
    _debounce?.cancel();
    final epoch = ++_searchEpoch;

    _beginUserTurn(trimmed);
    // امسح الحقل بعد تثبيت رسالة المستخدم في السجل.
    _setFieldText('');

    // Phase 2 Step 4: مسار نية موحّد (نص = صوت) ثم تخطيط فعل آمن.
    final plan = await _brainPlanner.plan(
      query: trimmed,
      context: _conversation,
    );
    if (!mounted || epoch != _searchEpoch) {
      if (showVoiceUi && mounted) {
        _voiceInput.setIdle();
      }
      _cancelThinkingIfStale();
      return;
    }

    final handled = await _executeActionPlan(
      plan,
      query: trimmed,
      epoch: epoch,
      announce: allowSpeak,
      showLoading: showVoiceUi,
    );
    if (!mounted || epoch != _searchEpoch) {
      _cancelThinkingIfStale();
      return;
    }
    if (handled) {
      if (showVoiceUi &&
          mounted &&
          (_voiceInput.state == VoiceAssistantState.processing ||
              _voiceInput.state == VoiceAssistantState.result)) {
        _voiceInput.setIdle();
      }
      _commitAssistantTurn();
      return;
    }

    // PC-0.1: سقوط آمن تحت سلطة الدماغ — بلا AssistantOrchestrator / MedicalNavigation.
    await _runAuthoritativeSafeFallback(
      plan: plan,
      query: trimmed,
      epoch: epoch,
      announce: allowSpeak,
      showLoading: showVoiceUi,
    );
    if (!mounted || epoch != _searchEpoch) {
      _cancelThinkingIfStale();
      return;
    }
    _commitAssistantTurn();
  }

  /// بحث بيانات و/أو رد مسيطر — ممنوع processQuery و MedicalNavigation كتفسير.
  Future<void> _runAuthoritativeSafeFallback({
    required AssistantActionPlan plan,
    required String query,
    required int epoch,
    required bool announce,
    required bool showLoading,
  }) async {
    final decision = _fallbackPolicy.decide(
      query: query,
      plan: plan,
      context: _conversation,
    );

    _pendingContactKind = null;
    _pendingWhatsAppMessage = '';

    // جدار خصوصية: لا Orchestrator legacy إطلاقاً من SmartSearchPage.
    assert(!decision.allowLegacyOrchestrator);

    if (!decision.allowGeneralSearch) {
      final msg = (decision.controlledMessage ?? plan.message).trim().isNotEmpty
          ? (decision.controlledMessage ?? plan.message).trim()
          : SmartBrainFallbackPolicy.controlledUnknownHealthMessage;
      lastSafeFallbackOutcomeForTest = SmartBrainSafeFallbackOutcome(
        decision: decision,
        usedLegacyOrchestrator: false,
        usedMedicalNavigation: false,
        sentRawQueryToLegacyAi: false,
        searchRan: false,
        message: msg,
      );
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _loading = false;
        _searchError = null;
        _assistantReply = AssistantReply(
          query: query,
          text: msg,
          spoken: false,
          source: AssistantReplySource.localSearch,
          searchResults: const [],
        );
      });
      if (showLoading) {
        _voiceInput.setResult();
        _voiceInput.setIdle();
      }
      if (announce && msg.isNotEmpty) {
        await _voice.speak(msg);
      }
      return;
    }

    if (showLoading) {
      _voiceInput.setProcessing();
      if (mounted) {
        setState(() {
          _loading = true;
          _searchError = null;
        });
      }
    } else if (mounted) {
      setState(() => _searchError = null);
    }

    try {
      final local = await _search.search(query, limit: 24);
      if (!mounted || epoch != _searchEpoch) return;

      // بطاقة الاختصاص مساعدة تنقّل لا كيان مستقل — لا تُحتسب نتيجة ثانية.
      final counted = SmartSearchResult.semanticPrimary(local);

      DoctorNameSuggestion? typoSuggestion;
      if (local.isEmpty && plan.message.trim().isEmpty) {
        typoSuggestion = await _suggestDoctorNameCorrection(query);
        if (!mounted || epoch != _searchEpoch) return;
      }
      final typoLabel = typoSuggestion == null
          ? null
          : ArabicTextUtils.stripHonorifics(typoSuggestion.doctorName).trim();

      final msg = plan.message.trim().isNotEmpty
          ? plan.message.trim()
          : (local.isEmpty
              ? (typoLabel != null
                  ? 'ما لقيت مطابقة دقيقة. هل تقصد د. $typoLabel؟'
                  : 'ما لقيت نتيجة مطابقة حالياً.')
              : (counted.length == 1
                  ? 'وجدت ${counted.first.title}.'
                  : 'وجدت ${counted.length} نتائج.'));

      _conversation.rememberResults(
        local,
        query: query,
        intent: plan.intentResult.intent,
        assistantResponse: msg,
      );

      // حالة قصيرة الأمد بعد تثبيت نتائج الدور: «نعم» التالية تؤكد هذا الطبيب
      // فقط. الطبيب لا يدخل النتائج ولا يُختار هنا.
      if (typoSuggestion != null) {
        _conversation.setPendingDoctorSuggestion(
          PendingDoctorSuggestion(
            doctorId: typoSuggestion.doctorId!.trim(),
            doctorName: typoSuggestion.doctorName,
          ),
        );
      }

      lastSafeFallbackOutcomeForTest = SmartBrainSafeFallbackOutcome(
        decision: decision,
        usedLegacyOrchestrator: false,
        usedMedicalNavigation: false,
        sentRawQueryToLegacyAi: false,
        searchRan: true,
        message: msg,
      );

      if (showLoading) {
        _voiceInput.setResult();
      } else if (_voiceInput.state == VoiceAssistantState.processing ||
          _voiceInput.state == VoiceAssistantState.error) {
        _voiceInput.setIdle();
      }
      setState(() {
        _results = local;
        _assistantReply = AssistantReply(
          query: query,
          text: msg,
          spoken: false,
          source: AssistantReplySource.localSearch,
          searchResults: local,
        );
        if (showLoading) _loading = false;
        _searchError = null;
      });
      if (announce && msg.isNotEmpty && local.isNotEmpty) {
        // لا ننطق تلقائياً لبحث عام طويل — فقط إن announce=true ونتيجة محدودة.
        if (local.length <= 3) {
          await _voice.speak(msg);
        }
      }
    } catch (e, st) {
      debugPrint('Smart search data fallback failed: $e\n$st');
      lastSafeFallbackOutcomeForTest = SmartBrainSafeFallbackOutcome(
        decision: decision,
        usedLegacyOrchestrator: false,
        usedMedicalNavigation: false,
        sentRawQueryToLegacyAi: false,
        searchRan: false,
        message: 'تعذّر إكمال البحث.',
      );
      if (!mounted || epoch != _searchEpoch) return;
      if (showLoading) {
        _voiceInput.enterErrorState('تعذّر إكمال البحث الذكي. حاول مرة أخرى.');
      }
      setState(() {
        if (showLoading) _loading = false;
        if (_results.isEmpty) {
          _assistantReply = null;
          _searchError = 'تعذّر إكمال البحث الذكي. حاول مرة أخرى.';
        }
      });
    }
  }

  /// ينفّذ خطة Smart Brain عبر الآليات الحالية. true = تم التعامل ولا نكمل البحث العام.
  Future<bool> _executeActionPlan(
    AssistantActionPlan plan, {
    required String query,
    required int epoch,
    bool announce = true,
    bool showLoading = true,
  }) async {
    switch (plan.kind) {
      case AssistantActionKind.none:
        return false;

      case AssistantActionKind.runGeneralSearch:
      case AssistantActionKind.runDoctorSearch:
      case AssistantActionKind.runAnalysisSearch:
        return false; // يكمل مسار البحث أدناه

      case AssistantActionKind.runLabSearch:
        final labQ = (plan.labQuery ?? query).trim();
        if (labQ.isEmpty) return false;
        if (showLoading) {
          _voiceInput.setProcessing();
          if (mounted) {
            setState(() {
              _loading = true;
              _searchError = null;
            });
          }
        } else if (mounted) {
          setState(() => _searchError = null);
        }
        try {
          final local = await _search.search(labQ, limit: 24);
          if (!mounted || epoch != _searchEpoch) return true;
          final labs = local
              .where((r) => r.type == SmartSearchResultType.lab)
              .toList();
          final shown = labs.isNotEmpty ? labs : local;
          _conversation.rememberResults(
            shown,
            query: labQ,
            intent: plan.intentResult.intent,
            assistantResponse: shown.length == 1
                ? 'وجدت ${shown.first.title}.'
                : (shown.isEmpty
                    ? 'لم أجد مختبرات حالياً.'
                    : 'هذه المختبرات المتوفرة.'),
          );
          final msg = shown.length == 1
              ? 'وجدت ${shown.first.title}.'
              : (shown.isEmpty
                  ? 'لم أجد مختبرات حالياً.'
                  : 'وجدت ${shown.length} مختبرات.');
          setState(() {
            _results = shown;
            _loading = false;
            _searchError = null;
            _assistantReply = AssistantReply(
              query: query,
              text: msg,
              spoken: false,
              source: AssistantReplySource.localSearch,
              searchResults: shown,
            );
          });
          if (showLoading) _voiceInput.setResult();
          if (announce && msg.isNotEmpty) {
            await _voice.speak(msg);
          }
        } catch (e, st) {
          debugPrint('Lab search failed: $e\n$st');
          if (!mounted || epoch != _searchEpoch) return true;
          setState(() {
            _loading = false;
            _searchError = 'تعذّر البحث عن المختبرات.';
          });
        }
        return true;

      case AssistantActionKind.runSpecialtySearch:
        final specialtyName = plan.specialtyQuery ?? query;
        final cmd = VoiceSpecialtySearchCommand.tryParse(query) ??
            VoiceSpecialtySearchCommand(
              specialtyQuery: specialtyName,
              resolvedSpecialtyName: specialtyName,
              rawQuery: query,
            );
        await _handleSpecialtySearchCommand(
          cmd,
          epoch: epoch,
          speakNames: announce,
          showLoading: showLoading,
        );
        return true;

      case AssistantActionKind.selectEntity:
      case AssistantActionKind.showLocation:
      case AssistantActionKind.showMessage:
        if (plan.contextResolution != null) {
          await _handleContextualResolution(
            plan.contextResolution!,
            query: query,
            epoch: epoch,
            announce: announce,
            showLoading: showLoading,
          );
          return true;
        }
        await _showPlanMessage(
          plan,
          query: query,
          epoch: epoch,
          announce: announce,
          showLoading: showLoading,
        );
        return true;

      case AssistantActionKind.showClarification:
        if (!mounted || epoch != _searchEpoch) return true;
        if (showLoading) {
          _voiceInput.setProcessing();
        }
        setState(() {
          _results = plan.candidates;
          _loading = false;
          _searchError = null;
          _assistantReply = AssistantReply(
            query: query,
            text: plan.message,
            spoken: false,
            source: AssistantReplySource.localSearch,
            searchResults: plan.candidates,
          );
        });
        if (showLoading) _voiceInput.setResult();
        if (announce && !plan.textFirstOnly && plan.message.isNotEmpty) {
          await _voice.speak(plan.message);
        }
        return true;

      case AssistantActionKind.prepareCall:
      case AssistantActionKind.prepareWhatsApp:
        final target = plan.target;
        if (target == null || !plan.canExecute) {
          await _showPlanMessage(
            plan,
            query: query,
            epoch: epoch,
            announce: announce,
            showLoading: showLoading,
          );
          return true;
        }
        final kind = plan.kind == AssistantActionKind.prepareWhatsApp
            ? VoiceContactKind.whatsapp
            : VoiceContactKind.call;
        if (showLoading) {
          _voiceInput.setProcessing();
          if (mounted) {
            setState(() {
              _loading = true;
              _searchError = null;
            });
          }
        }
        if (!mounted || epoch != _searchEpoch) return true;
        setState(() {
          _results = [target];
          _loading = false;
          _assistantReply = AssistantReply(
            query: query,
            text: plan.message,
            spoken: false,
            source: AssistantReplySource.localSearch,
            searchResults: [target],
          );
        });
        if (showLoading) _voiceInput.setResult();
        await _launchContactForResult(target, kind, announce: announce);
        return true;

      case AssistantActionKind.openProfile:
        final target = plan.target;
        if (target == null) {
          await _showPlanMessage(
            plan,
            query: query,
            epoch: epoch,
            announce: announce,
            showLoading: showLoading,
          );
          return true;
        }
        if (target.type == SmartSearchResultType.lab &&
            target.labId != null &&
            target.labId!.isNotEmpty) {
          if (!mounted || epoch != _searchEpoch) return true;
          setState(() {
            _results = [target];
            _loading = false;
            _assistantReply = AssistantReply(
              query: query,
              text: plan.message,
              spoken: false,
              source: AssistantReplySource.localSearch,
              searchResults: [target],
            );
          });
          if (announce && plan.message.isNotEmpty) {
            await _voice.speak(plan.message);
          }
          await _openLab(target.labId!);
          return true;
        }
        if (target.doctorId == null) {
          await _showPlanMessage(
            plan,
            query: query,
            epoch: epoch,
            announce: announce,
            showLoading: showLoading,
          );
          return true;
        }
        if (!mounted || epoch != _searchEpoch) return true;
        setState(() {
          _results = [target];
          _loading = false;
          _assistantReply = AssistantReply(
            query: query,
            text: plan.message,
            spoken: false,
            source: AssistantReplySource.localSearch,
            searchResults: [target],
          );
        });
        if (announce && plan.message.isNotEmpty) {
          await _voice.speak(plan.message);
        }
        await _openDoctor(target.doctorId!);
        return true;

      case AssistantActionKind.showLabPackages:
      case AssistantActionKind.showLabAnalyses:
      case AssistantActionKind.showPackagesContainingAnalysis:
      case AssistantActionKind.showLabsViaAnalysisPackages:
      case AssistantActionKind.showPackagePrice:
      case AssistantActionKind.showPackageAnalyses:
      case AssistantActionKind.showPackageComparison:
      case AssistantActionKind.showOffers:
      case AssistantActionKind.runPackageSearch:
        if (!mounted || epoch != _searchEpoch) return true;
        if (showLoading) {
          _voiceInput.setProcessing();
        }
        setState(() {
          // بلا مرشّحين ولا هدف: أبقِ الذاكرة كما هي ولا تنسبها لهذا الدور.
          if (plan.candidates.isNotEmpty) {
            _results = plan.candidates;
          } else if (plan.target != null) {
            _results = [plan.target!];
          }
          _loading = false;
          _searchError = null;
          _assistantReply = AssistantReply(
            query: query,
            text: plan.message,
            spoken: false,
            source: AssistantReplySource.localSearch,
            searchResults: plan.candidates,
          );
        });
        if (showLoading) _voiceInput.setResult();
        if (announce && plan.message.isNotEmpty) {
          await _voice.speak(plan.message);
        }
        return true;

      case AssistantActionKind.guidedConversation:
      case AssistantActionKind.healthGuidance:
        // Step 10A/10C: عرض رسالة التدفق أو التوجيه الصحي.
        await _showPlanMessage(
          plan,
          query: query,
          epoch: epoch,
          announce: announce,
          showLoading: showLoading,
        );
        return true;
    }
  }

  Future<void> _showPlanMessage(
    AssistantActionPlan plan, {
    required String query,
    required int epoch,
    bool announce = true,
    bool showLoading = true,
  }) async {
    if (!mounted || epoch != _searchEpoch) return;
    if (showLoading) _voiceInput.setResult();
    setState(() {
      if (plan.candidates.isNotEmpty) _results = plan.candidates;
      if (plan.target != null) {
        _results = [plan.target!, ..._results.where((r) => r != plan.target)];
      }
      _loading = false;
      _searchError =
          plan.kind == AssistantActionKind.showMessage ? plan.message : null;
      _assistantReply = AssistantReply(
        query: query,
        text: plan.message,
        spoken: false,
        source: AssistantReplySource.localSearch,
        searchResults: _results,
      );
    });
    if (announce && !plan.textFirstOnly && plan.message.isNotEmpty) {
      await _voice.speak(plan.message);
    }
  }

  Future<void> _handleContextualResolution(
    ContextResolution resolution, {
    required String query,
    required int epoch,
    bool announce = true,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _voiceInput.setProcessing();
      if (mounted) {
        setState(() {
          _loading = true;
          _searchError = null;
        });
      }
    }

    void finishUi({
      required String message,
      List<SmartSearchResult>? results,
      String? error,
    }) {
      if (!mounted || epoch != _searchEpoch) return;
      if (showLoading) _voiceInput.setResult();
      setState(() {
        if (results != null) _results = results;
        if (showLoading) _loading = false;
        _searchError = error;
        _assistantReply = AssistantReply(
          query: query,
          text: message,
          spoken: false,
          source: AssistantReplySource.localSearch,
          searchResults: results ?? _results,
        );
      });
    }

    switch (resolution.status) {
      case ContextResolutionStatus.notContextual:
        return;
      case ContextResolutionStatus.noPreviousResults:
      case ContextResolutionStatus.selectionOutOfRange:
      case ContextResolutionStatus.locationUnavailable:
      case ContextResolutionStatus.contactUnavailable:
        finishUi(message: resolution.message, error: resolution.message);
        if (announce) await _voice.speak(resolution.message);
        return;
      case ContextResolutionStatus.selectResult:
        final doctors = _conversation.lastDoctorSnapshot;
        finishUi(
          message: resolution.message,
          results: doctors.isNotEmpty ? doctors : _results,
        );
        if (announce) await _voice.speak(resolution.message);
        return;
      case ContextResolutionStatus.showLocation:
        finishUi(
          message: resolution.message,
          results: resolution.target == null
              ? _results
              : [resolution.target!, ..._results.where((r) => r != resolution.target)],
        );
        if (announce) await _voice.speak(resolution.message);
        return;
      case ContextResolutionStatus.showProfile:
        final profileTarget = resolution.target;
        finishUi(
          message: resolution.message,
          results: profileTarget == null ? _results : [profileTarget],
        );
        if (announce) await _voice.speak(resolution.message);
        if (profileTarget?.doctorId != null) {
          await _openDoctor(profileTarget!.doctorId!);
        }
        return;
      case ContextResolutionStatus.callDoctor:
      case ContextResolutionStatus.messageDoctor:
        final target = resolution.target;
        if (target == null) {
          finishUi(message: resolution.message, error: resolution.message);
          if (announce) await _voice.speak(resolution.message);
          return;
        }
        final kind = resolution.status == ContextResolutionStatus.messageDoctor
            ? VoiceContactKind.whatsapp
            : VoiceContactKind.call;
        finishUi(message: resolution.message, results: [target]);
        await _launchContactForResult(
          target,
          kind,
          announce: announce,
        );
        return;
    }
  }

  Future<void> _handleSpecialtySearchCommand(
    VoiceSpecialtySearchCommand command, {
    required int epoch,
    bool speakNames = true,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _voiceInput.setProcessing();
      setState(() {
        _loading = true;
        _searchError = null;
        _assistantReply = null;
        _results = [];
      });
    } else if (mounted) {
      setState(() {
        _searchError = null;
        _assistantReply = null;
      });
    }

    try {
      final needle = command.resolvedSpecialtyName;
      final results = await _search.search(needle, limit: 24);
      if (!mounted || epoch != _searchEpoch) return;

      final doctors = _doctorsForSpecialty(
        results,
        specialtyQuery: command.specialtyQuery,
        resolvedName: command.resolvedSpecialtyName,
      );

      _pendingContactKind = null;
      _pendingWhatsAppMessage = '';
      _conversation.rememberResults(
        doctors.isNotEmpty ? doctors : results,
        query: command.rawQuery,
        intent: _intentResolver.resolve(command.rawQuery).intent,
        specialtyLabel: command.resolvedSpecialtyName,
      );

      if (doctors.isEmpty) {
        final msg =
            'لم أجد أطباء لاختصاص ${command.resolvedSpecialtyName} حاليًا.';
        if (showLoading) _voiceInput.setResult();
        setState(() {
          _results = results;
          if (showLoading) _loading = false;
          _assistantReply = AssistantReply(
            query: command.rawQuery,
            text: msg,
            spoken: false,
            source: AssistantReplySource.localSearch,
            searchResults: results,
          );
        });
        if (speakNames) await _voice.speak(msg);
        return;
      }

      final speech = _buildSpecialtyDoctorsSpeech(
        specialty: command.resolvedSpecialtyName,
        doctors: doctors,
      );
      if (showLoading) _voiceInput.setResult();
      setState(() {
        _results = doctors;
        if (showLoading) _loading = false;
        _assistantReply = AssistantReply(
          query: command.rawQuery,
          text: speech,
          spoken: false,
          source: AssistantReplySource.localSearch,
          searchResults: doctors,
        );
      });
      if (speakNames) {
        await _voice.speak(speech);
      }
    } catch (e, st) {
      debugPrint('Specialty search command failed: $e\n$st');
      if (!mounted || epoch != _searchEpoch) return;
      if (showLoading) {
        _voiceInput.enterErrorState('تعذّر بحث الاختصاص. حاول مرة أخرى.');
      }
      setState(() {
        if (showLoading) _loading = false;
        _searchError = 'تعذّر بحث الاختصاص. حاول مرة أخرى.';
      });
    }
  }

  /// اقتراح «هل تقصد …؟» عند صفر نتائج — من أطباء المنصة الحقيقيين فقط.
  ///
  /// لا يختار الطبيب ولا يعرضه في النتائج ولا ينفّذ اتصال/واتساب؛ المستخدم
  /// هو من يثبّت الطبيب بـ«نعم» عبر مسار المحادثة القائم.
  Future<DoctorNameSuggestion?> _suggestDoctorNameCorrection(
    String query,
  ) async {
    try {
      final doctors = await _search.doctorNameIndex();
      if (doctors.isEmpty) return null;
      final suggestion = const DoctorNameMatcher().suggestCorrection(
        query: query,
        doctors: doctors,
      );
      if (suggestion == null) return null;
      if ((suggestion.doctorId ?? '').trim().isEmpty) return null;
      return ArabicTextUtils.stripHonorifics(suggestion.doctorName)
              .trim()
              .isEmpty
          ? null
          : suggestion;
    } catch (e) {
      debugPrint('Doctor name suggestion failed: $e');
      return null;
    }
  }

  List<SmartSearchResult> _doctorsForSpecialty(
    List<SmartSearchResult> results, {
    required String specialtyQuery,
    required String resolvedName,
  }) {
    final qNorm = ArabicTextUtils.normalize(specialtyQuery);
    final resolvedNorm = ArabicTextUtils.normalize(resolvedName);

    final doctors = results.where((r) {
      if (r.type != SmartSearchResultType.doctor) return false;
      final specialty = (r.specialty ?? '').trim();
      if (specialty.isEmpty) return false;
      final matched = SpecialtyCatalog.match(specialty);
      final canon = ArabicTextUtils.normalize(matched?.nameAr ?? specialty);
      final raw = ArabicTextUtils.normalize(specialty);
      return canon.contains(resolvedNorm) ||
          resolvedNorm.contains(canon) ||
          raw.contains(qNorm) ||
          qNorm.contains(raw) ||
          canon.contains(qNorm) ||
          ArabicTextUtils.scoreMatch(specialty, specialtyQuery) >= 55 ||
          ArabicTextUtils.scoreMatch(specialty, resolvedName) >= 55;
    }).toList();

    doctors.sort((a, b) => b.score.compareTo(a.score));
    return doctors;
  }

  String _buildSpecialtyDoctorsSpeech({
    required String specialty,
    required List<SmartSearchResult> doctors,
  }) {
    final buf = StringBuffer();
    final n = doctors.length;
    buf.write(
      'وجدت ${ArabicSpeechNumbers.count(n)} '
      '${n == 1 ? 'طبيب' : (n == 2 ? 'طبيبين' : 'أطباء')} '
      'في اختصاص $specialty. ',
    );

    if (n == 1) {
      final name = doctors.first.title.trim();
      final specialtyLabel =
          (doctors.first.specialty ?? specialty).trim();
      if (name.isNotEmpty) {
        buf.write('وجدت الدكتور $name');
        if (specialtyLabel.isNotEmpty) {
          buf.write('، اختصاص $specialtyLabel');
        }
        buf.write('.');
      }
      return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final take = doctors.take(5).toList();
    for (var i = 0; i < take.length; i++) {
      final name = take[i].title.trim();
      if (name.isEmpty) continue;
      buf.write('${ArabicSpeechNumbers.ordinal(i + 1)}: $name. ');
    }
    if (doctors.length > take.length) {
      buf.write('وهناك المزيد في القائمة. ');
    }
    buf.write('يمكنك القول: اتصل على الطبيب الأول، أو واتساب للدكتور بالاسم.');
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// مسار legacy مؤقت — الإدخال يمر عبر SmartBrainPlanner أولاً.
  // ignore: unused_element
  Future<void> _handleContactCommand(
    VoiceContactCommand command, {
    required int epoch,
    bool announce = true,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _voiceInput.setProcessing();
      setState(() {
        _loading = true;
        _searchError = null;
        _assistantReply = null;
      });
    } else if (mounted) {
      setState(() {
        _searchError = null;
        _assistantReply = null;
      });
    }

    try {
      if (!command.hasTarget && _sessionDoctorResults.isEmpty) {
        if (!mounted || epoch != _searchEpoch) return;
        final tip = command.kind == VoiceContactKind.call
            ? 'قل مثلًا: اتصل بالدكتور علي، أو اتصل على الطبيب الأول.'
            : 'قل مثلًا: واتساب الدكتور علي، أو واتساب للطبيب الثاني.';
        if (showLoading) _voiceInput.setResult();
        setState(() {
          if (showLoading) _loading = false;
          _searchError = tip;
        });
        if (announce) await _voice.speak(tip);
        return;
      }

      // دفعة 2: فضّل مطابقة نتائج جلسة الاختصاص أولًا.
      final fromSession = _matchContactInSession(command);
      if (fromSession != null) {
        if (!mounted || epoch != _searchEpoch) return;
        _pendingContactKind = null;
        _pendingWhatsAppMessage = '';
        setState(() {
          _results = _sessionDoctorResults.isNotEmpty
              ? _sessionDoctorResults
              : [fromSession];
          _loading = false;
          _assistantReply = AssistantReply(
            query: command.rawQuery,
            text: command.kind == VoiceContactKind.call
                ? 'جاري الاتصال بـ ${fromSession.title}'
                : 'جاري فتح واتساب ${fromSession.title}',
            spoken: false,
            source: AssistantReplySource.localSearch,
            searchResults: _results,
          );
        });
        await _launchContactForResult(
          fromSession,
          command.kind,
          whatsappMessage: command.message,
          announce: announce,
        );
        return;
      }

      if (!command.hasTarget) {
        if (!mounted || epoch != _searchEpoch) return;
        final tip = _sessionDoctorResults.isNotEmpty
            ? 'حدد الطبيب من نتائج ${_sessionSpecialtyLabel ?? 'الاختصاص'} بالاسم أو الترتيب، مثل: اتصل على الأول.'
            : (command.kind == VoiceContactKind.call
                  ? 'قل مثلًا: اتصل بالدكتور علي.'
                  : 'قل مثلًا: واتساب الدكتور علي.');
        setState(() {
          _loading = false;
          if (_sessionDoctorResults.isNotEmpty) {
            _results = _sessionDoctorResults;
          }
          _searchError = tip;
        });
        if (announce) await _voice.speak(tip);
        return;
      }

      final results = await _search.search(command.targetQuery, limit: 16);
      if (!mounted || epoch != _searchEpoch) return;

      final contactable = _contactableResults(results, command.kind);
      if (contactable.isEmpty) {
        final msg = command.kind == VoiceContactKind.call
            ? 'لم أجد رقم اتصال لـ «${command.targetQuery}».'
            : 'لم أجد واتساب لـ «${command.targetQuery}».';
        setState(() {
          _results = _sessionDoctorResults.isNotEmpty
              ? _sessionDoctorResults
              : results;
          _loading = false;
          _assistantReply = AssistantReply(
            query: command.rawQuery,
            text: msg,
            spoken: false,
            source: AssistantReplySource.localSearch,
            searchResults: _results,
          );
        });
        if (announce) await _voice.speak(msg);
        return;
      }

      final best = contactable.first;
      final ambiguous =
          contactable.length > 1 &&
          contactable[1].score >= (best.score - 12) &&
          contactable[1].score >= 45;

      if (ambiguous) {
        _pendingContactKind = command.kind;
        _pendingWhatsAppMessage = command.message;
        final msg =
            'وجدت أكثر من نتيجة. اختر من القائمة لل${command.kind == VoiceContactKind.call ? 'اتصال' : 'واتساب'}.';
        setState(() {
          _results = contactable;
          _loading = false;
          _assistantReply = AssistantReply(
            query: command.rawQuery,
            text: msg,
            spoken: false,
            source: AssistantReplySource.localSearch,
            searchResults: contactable,
          );
        });
        if (announce) await _voice.speak(msg);
        return;
      }

      _pendingContactKind = null;
      _pendingWhatsAppMessage = '';
      setState(() {
        _results = contactable;
        _loading = false;
        _assistantReply = AssistantReply(
          query: command.rawQuery,
          text: command.kind == VoiceContactKind.call
              ? 'جاري الاتصال بـ ${best.title}'
              : 'جاري فتح واتساب ${best.title}',
          spoken: false,
          source: AssistantReplySource.localSearch,
          searchResults: contactable,
        );
      });

      await _launchContactForResult(
        best,
        command.kind,
        whatsappMessage: command.message,
        announce: announce,
      );
    } catch (e, st) {
      debugPrint('Contact command failed: $e\n$st');
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _loading = false;
        _searchError = 'تعذّر تنفيذ أمر التواصل. حاول مرة أخرى.';
      });
    }
  }

  /// مطابقة اتصل/واتساب داخل نتائج جلسة الاختصاص (اسم أو ترتيب).
  SmartSearchResult? _matchContactInSession(VoiceContactCommand command) {
    final session = _sessionDoctorResults;
    if (session.isEmpty) return null;

    final usable = session.where((r) {
      return command.kind == VoiceContactKind.call ? r.canCall : r.canWhatsApp;
    }).toList();
    if (usable.isEmpty) return null;

    final target = command.targetQuery.trim();
    if (target.isEmpty) return null;

    final ordinal = _parseSpokenOrdinal(target);
    if (ordinal != null && ordinal >= 1 && ordinal <= usable.length) {
      return usable[ordinal - 1];
    }

    SmartSearchResult? best;
    var bestScore = 0;
    for (final r in usable) {
      final score = ArabicTextUtils.scoreDoctorNameMatch(r.title, target);
      if (score > bestScore) {
        bestScore = score;
        best = r;
      }
    }
    if (best == null || bestScore < 40) return null;

    // غموض داخل الجلسة: اسمين بدرجة متقاربة
    final close = usable.where((r) {
      final s = ArabicTextUtils.scoreDoctorNameMatch(r.title, target);
      return s >= bestScore - 10 && s >= 40;
    }).toList();
    if (close.length > 1) return null;

    return best;
  }

  int? _parseSpokenOrdinal(String raw) {
    final q = ArabicTextUtils.normalize(raw);
    const map = <String, int>{
      'الاول': 1,
      'اول': 1,
      'الثاني': 2,
      'ثاني': 2,
      'الثالث': 3,
      'ثالث': 3,
      'الرابع': 4,
      'رابع': 4,
      'الخامس': 5,
      'خامس': 5,
      'السادس': 6,
      'السابع': 7,
      'الثامن': 8,
      'التاسع': 9,
      'العاشر': 10,
    };

    for (final e in map.entries) {
      final key = e.key;
      if (q == key) return e.value;
      if (q == 'الطبيب $key' ||
          q == 'الطبيبه $key' ||
          q == 'دكتور $key' ||
          q == 'الدكتور $key' ||
          q == 'الطبيب ال$key' ||
          q == 'الدكتور ال$key') {
        return e.value;
      }
      if (RegExp(
        r'(?:^|\s)(?:ال)?(?:طبيب|دكتور)\s+(?:ال)?' +
            RegExp.escape(key) +
            r'(?:\s|$)',
      ).hasMatch(q)) {
        return e.value;
      }
    }

    final numMatch = RegExp(r'رقم\s*(\d+)').firstMatch(q);
    if (numMatch != null) {
      return int.tryParse(numMatch.group(1) ?? '');
    }
    if (RegExp(r'^\d+$').hasMatch(q)) return int.tryParse(q);
    return null;
  }

  Future<void> _launchContactForResult(
    SmartSearchResult result,
    VoiceContactKind kind, {
    String whatsappMessage = '',
    bool announce = false,
  }) async {
    if (kind == VoiceContactKind.call) {
      if (!result.canCall) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد رقم اتصال لهذه النتيجة.')),
        );
        return;
      }
      if (announce) await _voice.speak('جاري الاتصال بـ ${result.title}');
      _externalContactLaunches++;
      await launchClinicCall(result.effectivePhone);
      return;
    }

    if (!result.canWhatsApp) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد واتساب لهذه النتيجة.')),
      );
      return;
    }
    if (announce) await _voice.speak('جاري فتح واتساب ${result.title}');
    _externalContactLaunches++;
    final patientName =
        await _profileService.preferredNameForPersonalization();
    final isDoctor = result.type == SmartSearchResultType.doctor;
    await launchClinicWhatsApp(
      result.effectiveWhatsApp,
      message: whatsappMessage.isNotEmpty
          ? whatsappMessage
          : ClinicContactMessage.whatsAppPrefill(
              patientFullName: patientName,
              providerTitle: isDoctor ? result.title : null,
              preferBookingWording: isDoctor,
            ),
    );
  }

  List<SmartSearchResult> _contactableResults(
    List<SmartSearchResult> results,
    VoiceContactKind kind,
  ) {
    final filtered = results.where((r) {
      if (r.type == SmartSearchResultType.specialty ||
          r.type == SmartSearchResultType.analysis) {
        return false;
      }
      return kind == VoiceContactKind.call ? r.canCall : r.canWhatsApp;
    }).toList();

    int rank(SmartSearchResult r) {
      switch (r.type) {
        case SmartSearchResultType.doctor:
          return 0;
        case SmartSearchResultType.lab:
          return 1;
        case SmartSearchResultType.package:
        case SmartSearchResultType.offer:
          return 2;
        default:
          return 9;
      }
    }

    filtered.sort((a, b) {
      final byType = rank(a).compareTo(rank(b));
      if (byType != 0) return byType;
      return b.score.compareTo(a.score);
    });
    return filtered;
  }

  /// إيقاف يدوي أو صمت تلقائي → تثبيت النص → تشغيل البحث الكامل (مرة واحدة).
  Future<void> _finalizeVoiceTurnAndSearch({
    VoiceTurnFinalizeReason reason = VoiceTurnFinalizeReason.manualStop,
  }) async {
    if (_voiceBusy && !_voiceInput.isFinalizing) return;
    if (!_voiceSessionActive &&
        !_listening &&
        reason == VoiceTurnFinalizeReason.manualStop) {
      // قد تكون الدورة بدأت الإنهاء من مؤقّت الصمت.
      if (!_voiceInput.isFinalizing) return;
    }

    _voiceLiveDebounce?.cancel();
    final controllerSnap = _controller.text.trim();
    final previewSnap = (_listenPreview ?? '').trim();
    final text = await _voiceInput.finalizeTurn(reason: reason);
    if (!mounted) return;

    final trimmed = [
      (text ?? '').trim(),
      previewSnap,
      controllerSnap,
      _voiceInput.transcript.trim(),
    ].firstWhere((e) => e.isNotEmpty, orElse: () => '');

    setState(() {
      _listenPreview = trimmed;
    });

    if (trimmed.isEmpty) {
      _voiceInput.setIdle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لم يُلتقط كلام واضح. اضغط الميكروفون وحاول مرة أخرى.',
            ),
          ),
        );
      }
      return;
    }

    if (!_voiceInput.consumeFinalQuery(trimmed)) {
      debugPrint('Smart search: skipped duplicate final voice query');
      _voiceInput.setIdle();
      return;
    }

    _setFieldText(trimmed);
    await _runSearch(trimmed, source: QueryInputSource.voice);
    if (!mounted) return;
    // بعد المعالجة: جاهز لضغطة ميكروفون جديدة — بدون إعادة فتح تلقائي.
    if (_voiceInput.state == VoiceAssistantState.processing ||
        _voiceInput.state == VoiceAssistantState.result) {
      _voiceInput.setIdle();
    }
  }

  /// توافق: الإيقاف اليدوي يستخدم المسار الموحّد.
  Future<void> _manualStopAndSearch() => _finalizeVoiceTurnAndSearch(
        reason: VoiceTurnFinalizeReason.manualStop,
      );

  /// توقف الالتقاط داخليًا — لا نستأنف؛ الإنهاء يتم عبر onTurnFinalizeRequested.
  void _onMicCaptureEnded(String lastText) {
    if (!mounted || _manualStopRequested || _loading) return;
    final trimmed = lastText.trim();
    if (trimmed.isNotEmpty) {
      _setFieldText(trimmed);
      _listenPreview = trimmed;
      if (mounted) setState(() {});
    }
    // لا resumeIfNeeded — الدورات أصبحت turn-based.
  }

  void _wireVoiceInputCallbacks() {
    _voiceInput.onTranscript = (text, {required isFinal}) {
      if (!mounted || _manualStopRequested || !_voiceSessionActive) return;
      _onVoiceTranscript(text, isFinal: isFinal);
    };
    _voiceInput.onCaptureEnded = (lastText) {
      _onMicCaptureEnded(lastText);
    };
    _voiceInput.onTurnFinalizeRequested = (reason) {
      if (!mounted) return;
      unawaited(_finalizeVoiceTurnAndSearch(reason: reason));
    };
    _voiceInput.onError = (msg) {
      debugPrint('Smart search STT error: $msg');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    };
  }

  Future<void> _startVoiceSession({
    bool clearQuery = true,
    String source = 'manualTap',
  }) async {
    // قفل متزامن فوراً — قبل أي await — لمنع stop+restart من استدعاء مزدوج.
    if (_voiceStartInFlight || _voiceBusy || _loading) {
      debugPrint(
        '[MIC] start blocked inFlight=$_voiceStartInFlight '
        'busy=$_voiceBusy loading=$_loading source=$source',
      );
      return;
    }
    if (_voiceSessionActive ||
        _listening ||
        _voiceInput.isFinalizing ||
        _voiceInput.state == VoiceAssistantState.processing) {
      debugPrint(
        '[MIC] start blocked — already active/finalizing '
        'session=$_voiceSessionActive state=${_voiceInput.state} source=$source',
      );
      return;
    }
    _voiceStartInFlight = true;
    _voiceStartAttemptCount++;
    final attempt = _voiceStartAttemptCount;
    debugPrint(
      '[MIC] start attempt=$attempt source=$source '
      'token=${_voiceInput.sessionToken}',
    );
    try {
      if (!DeviceSpeechRecognitionService.isSupportedOnThisPlatform) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('التعرف على الصوت غير متاح على هذا الجهاز'),
          ),
        );
        return;
      }

      // صلاحيات macOS — CRITICAL FIX 3:
      // نفس العملية فقط. لا يُفتح Ghadeer.app ثانٍ أبداً.
      final pidLabel =
          await DeviceSpeechRecognitionService.diagnosticPidLabel();
      debugPrint('[MIC] PID=$pidLabel start attempt=$attempt source=$source');

      var ready =
          await DeviceSpeechRecognitionService.macosSpeechReadyState();

      if (ready.isDeniedOrRestricted) {
        if (!mounted) return;
        debugPrint(
          '[MIC] PID=$pidLabel permission denied/restricted — message only',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              DeviceSpeechRecognitionService.enablePermissionMessage,
            ),
            action: SnackBarAction(
              label: 'الإعدادات',
              onPressed: () {
                unawaited(
                  DeviceSpeechRecognitionService.openSystemPrivacySettings(),
                );
              },
            ),
          ),
        );
        return;
      }

      if (ready.speech == 'unknown' || ready.microphone == 'unknown') {
        if (!mounted) return;
        debugPrint('[MIC] PID=$pidLabel ready unknown — abort (no app launch)');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              DeviceSpeechRecognitionService.recognitionFailedMessage,
            ),
          ),
        );
        return;
      }

      // Gate Speech/AV permission APIs BEFORE any request — IDE host = SIGABRT.
      if (!ready.canInitializeSafely) {
        if (!mounted) return;
        debugPrint(
          '[MIC] PID=$pidLabel cannot initialize safely — message only '
          'launchAttr=${ready.launchServicesAttributed} '
          '(NO Speech API, NO second-app)',
        );
        final msg = !ready.launchServicesAttributed
            ? DeviceSpeechRecognitionService.macosDevHostBlockedMessage
            : DeviceSpeechRecognitionService.enablePermissionMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return;
      }

      if (!ready.isFullyAuthorized && ready.isNotDetermined) {
        debugPrint(
          '[MIC] PID=$pidLabel notDetermined — in-process permission request',
        );
        ready =
            await DeviceSpeechRecognitionService.requestPermissionsInProcess();
        final afterPid =
            await DeviceSpeechRecognitionService.diagnosticPidLabel();
        debugPrint(
          '[MIC] PID=$afterPid after in-process request '
          'auth=${ready.isFullyAuthorized} speech=${ready.speech} '
          'mic=${ready.microphone}',
        );
        if (!mounted) return;
        if (!ready.isFullyAuthorized) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                DeviceSpeechRecognitionService.enablePermissionMessage,
              ),
              action: SnackBarAction(
                label: 'الإعدادات',
                onPressed: () {
                  unawaited(
                    DeviceSpeechRecognitionService.openSystemPrivacySettings(),
                  );
                },
              ),
            ),
          );
          return;
        }
      }

      debugPrint(
        '[MIC] PID=$pidLabel proceeding in-process listen '
        '(mayLaunchSecondApp=${DeviceSpeechRecognitionService.mayLaunchSecondAppInstance})',
      );

      if (!mounted) return;

      if (!await _voiceSettings.isGenderExplicitlySet()) {
        await _voiceSettings.setGender(AssistantVoiceGender.male);
      }

      if (!mounted) return;

      final warmUp = _speechWarmUp;
      if (warmUp != null) {
        await warmUp;
        if (!mounted) return;
      }

      // إن أُلغِي autoStart أثناء الانتظار أو بدأت جلسة أخرى — لا تبدأ.
      if (source == 'autoStart' && _autoStartCancelled) {
        debugPrint('[MIC] autoStart aborted after await — cancelled');
        return;
      }
      if (_voiceSessionActive || _voiceInput.sessionActive) {
        debugPrint('[MIC] start aborted — session already active after await');
        return;
      }

      _debounce?.cancel();
      _voiceLiveDebounce?.cancel();
      if (clearQuery) {
        _setFieldText('');
      }

      // لا نمسح ConversationContext ولا نتائج الجلسة — دورات صوت متعددة = سياق واحد.
      setState(() {
        _listenPreview = clearQuery ? '' : _controller.text;
        _loading = false;
      });

      _wireVoiceInputCallbacks();
      await _voiceInput.startSession(clearTranscript: clearQuery);
      final afterStartPid =
          await DeviceSpeechRecognitionService.diagnosticPidLabel();
      debugPrint(
        '[MIC] PID=$afterStartPid startSession done attempt=$attempt '
        'token=${_voiceInput.sessionToken} source=$source',
      );
      if (!mounted) return;
      setState(() {});
    } catch (e, st) {
      debugPrint('Smart search voice start failed: $e\n$st');
      if (!mounted) return;
      await _voiceInput.cancelSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            DeviceSpeechRecognitionService.recognitionFailedMessage,
          ),
        ),
      );
    } finally {
      _voiceStartInFlight = false;
    }
  }

  Future<void> _toggleVoice({String source = 'manualTap'}) async {
    debugPrint(
      '[MIC] toggleVoice source=$source session=$_voiceSessionActive '
      'listening=$_listening busy=$_voiceBusy loading=$_loading '
      'inFlight=$_voiceStartInFlight',
    );
    if (source == 'manualTap') {
      // أي ضغطة يدوية تلغي autoStart المعلّق وتستهلكه.
      _autoStartCancelled = true;
      _autoStartVoiceConsumed = true;
    }
    if (_voiceBusy || _voiceStartInFlight) return;
    // عند بدء مايك جديد أو قبل معالجة الإيقاف: أوقف نطقًا نشطًا فقط.
    if (_voice.isSpeaking) {
      await _silenceVoice();
    }

    // أثناء جلسة صوت: زر الميكروفون = إيقاف ثم بحث كامل.
    if (_voiceSessionActive || _listening) {
      await _finalizeVoiceTurnAndSearch(
        reason: VoiceTurnFinalizeReason.manualStop,
      );
      return;
    }

    // لا تبدأ استماعًا جديدًا أثناء المعالجة أو النطق.
    if (_loading) return;
    if (_voiceInput.state == VoiceAssistantState.processing ||
        _voiceInput.state == VoiceAssistantState.speaking) {
      return;
    }
    await _startVoiceSession(clearQuery: true, source: source);
  }

  Future<void> _submitManual() async {
    if (_voice.isSpeaking) {
      await _silenceVoice();
    }
    if (_loading) return;
    if (_listening || _voiceSessionActive) {
      await _manualStopAndSearch();
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _debounce?.cancel();
    final launchesBefore = _externalContactLaunches;
    await _runSearch(text, source: QueryInputSource.typed);
    if (_externalContactLaunches != launchesBefore) return;
    _restoreComposerFocusAfterTypedSend();
  }

  /// سطح المكتب: زر الإرسال يسحب التركيز من الحقل، فنعيده لنفس FocusNode
  /// حتى تُكتب الرسالة التالية فوراً. الهواتف تحتفظ بتركيزها أصلاً، فلا
  /// نعيد فتح لوحة مفاتيح أُغلقت بنيّة المستخدم.
  bool get _restoresComposerFocusOnSend =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  void _restoreComposerFocusAfterTypedSend() {
    if (!mounted || !_restoresComposerFocusOnSend) return;
    // صوت/مايك نشط، أو تنقّل جارٍ، أو صفحة ليست الحالية → لا تسحب التركيز.
    if (_listening || _voiceSessionActive || _voiceBusy) return;
    if (_navigating || ModalRoute.of(context)?.isCurrent == false) return;
    if (_fieldFocus.hasFocus) return;
    _fieldFocus.requestFocus();
  }

  Future<void> _openResultFromList(SmartSearchResult result) async {
    await _silenceVoice();
    if (_voiceSessionActive || _listening) {
      _voiceLiveDebounce?.cancel();
      await _voiceInput.stopSession();
      _voiceInput.setIdle();
      if (mounted) {
        }
    }

    _conversation.selectEntity(result);

    final pending = _pendingContactKind;
    if (pending != null) {
      final msg = _pendingWhatsAppMessage;
      _pendingContactKind = null;
      _pendingWhatsAppMessage = '';
      await _launchContactForResult(
        result,
        pending,
        whatsappMessage: msg,
        announce: false,
      );
      return;
    }

    await _openResult(result);
  }

  Future<void> _openResult(SmartSearchResult result) async {
    await _silenceVoice();
    if (_navigating) return;
    _navigating = true;

    try {
      final medical = _medical.decideForResult(result);
      if (medical.action == MedicalNavigationAction.blocked ||
          medical.action == MedicalNavigationAction.urgentCare) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(medical.safeMessage)));
        return;
      }

      switch (result.type) {
        case SmartSearchResultType.doctor:
          if (result.doctorId != null) {
            await _openDoctor(result.doctorId!);
          }
        case SmartSearchResultType.lab:
          if (result.labId != null) {
            await _openLab(result.labId!);
          }
        case SmartSearchResultType.package:
        case SmartSearchResultType.offer:
          if (result.labId != null && result.packageId != null) {
            await _openPackage(result.labId!, result.packageId!);
          }
        case SmartSearchResultType.specialty:
          await _runSearch(result.title, source: QueryInputSource.typed);
        case SmartSearchResultType.analysis:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'التحليل ${result.title} — راجع الباقات المرتبطة أدناه إن وُجدت',
                ),
              ),
            );
          }
      }
    } finally {
      _navigating = false;
    }
  }

  Future<void> _openDoctor(String id) async {
    try {
      final row = await Supabase.instance.client
          .from('doctors')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (!mounted || row == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DoctorProfilePage(
            doctor: DoctorItem.fromMap(Map<String, dynamic>.from(row)),
            isFavorite: false,
            onToggleFavorite: () {},
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _openLab(String labId) async {
    final lab = await LabsService().fetchLabById(labId);
    if (!mounted || lab == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabProfilePage(lab: lab)),
    );
  }

  Future<void> _openPackage(String labId, String packageId) async {
    final lab = await LabsService().fetchLabById(labId);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabPackageDetailPage(
          packageId: packageId,
          labName: lab?.name ?? '',
        ),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('[SMART_SEARCH] dispose hash=$hashCode');
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _voiceLiveDebounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _fieldFocus.dispose();
    _scrollController.dispose();
    _voiceInput.removeListener(_onVoiceInputChanged);
    unawaited(_voiceInput.cancelSession());
    _voiceInput.dispose();
    _assistant.voice.dispose();
    _conversation.reset();
    super.dispose();
  }

  Widget _voiceSessionPanel() {
    final preview = (_listenPreview ?? '').trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                color: Color(0xFFBE123C),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'جاري الاستماع — اضغط زر الميكروفون مرة أخرى للإرسال',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9F1239),
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              preview,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF123B42),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _showSuggestionChips {
    if (_loading || _voiceSessionActive) return false;
    if (_chatTurns.isEmpty) return true;
    return _chatTurns.length == 1 && _chatTurns.first.isWelcome;
  }

  Future<void> _onSuggestionSelected(String label) async {
    if (_loading) return;
    _setFieldText(label);
    await _submitManual();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7FBFC),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7FBFC),
          appBar: ClinicAppBar(
            title: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الغدير',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'مساعدك الصحي الذكي',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Color(0xFFE6F8F6),
                  ),
                ),
              ],
            ),
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  key: const Key('smart_brain_chat_list'),
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  itemCount: _chatTurns.length,
                  itemBuilder: (context, index) {
                    final turn = _chatTurns[index];
                    if (turn.role == SmartBrainChatRole.user) {
                      return SmartBrainUserBubble(text: turn.text);
                    }
                    return AnimatedBuilder(
                      animation: _voice,
                      builder: (context, _) {
                        return SmartBrainAssistantBubble(
                          turn: turn,
                          onResultTap: (item) {
                            if (_loading) return;
                            unawaited(_openResultFromList(item));
                          },
                          isSpeaking: _voice.isSpeaking,
                          onSpeak: turn.isThinking || turn.text.isEmpty
                              ? null
                              : () => _voice.speak(turn.text),
                          onStopSpeak: () => _voice.stop(),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_voiceSessionActive) _voiceSessionPanel(),
              if (_showSuggestionChips)
                SmartBrainSuggestionChips(onSelected: _onSuggestionSelected),
              SmartBrainComposerBar(
                controller: _controller,
                focusNode: _fieldFocus,
                onSubmit: () => unawaited(_submitManual()),
                onToggleVoice: () => unawaited(_toggleVoice()),
                loading: _loading,
                voiceBusy: _voiceBusy,
                listening: _listening,
                voiceSessionActive: _voiceSessionActive,
                readOnly: _listening || _voiceSessionActive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
