import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ai/ai_service.dart';
import '../doctors/doctor_profile_page.dart';
import '../labs/lab_package_detail_page.dart';
import '../labs/lab_profile_page.dart';
import '../labs/labs_service.dart';
import '../medical/medical_navigation_service.dart';
import '../models/doctor_item.dart';
import '../voice/voice_settings.dart';
import '../voice/assistant_orchestrator.dart';
import '../voice/speech_recognition_service.dart';
import '../voice/voice_response_controller.dart';
import 'smart_search_models.dart';
import 'smart_search_result_cards.dart';
import 'smart_search_service.dart';
import '../widgets/clinic_app_bar.dart';

/// بحث ذكي (نص + صوت) — محلي أولاً، AI عبر Edge Function عند التفعيل.
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
  final _search = SmartSearchService();
  final _medical = MedicalNavigationService();
  late final AssistantOrchestrator _assistant;
  final _voiceSettings = VoiceSettingsService();
  late final VoiceResponseController _voice;

  Timer? _debounce;
  List<SmartSearchResult> _results = [];
  AssistantReply? _assistantReply;
  bool _loading = false;
  bool _listening = false;

  /// جلسة صوت نشطة حتى يضغط المستخدم إيقاف/إنهاء (حتى لو توقف الميكروفون داخليًا).
  bool _voiceSessionActive = false;
  bool _voiceBusy = false;
  bool _suppressQueryListener = false;
  bool _manualStopRequested = false;
  bool _resumingListen = false;
  Future<void>? _speechWarmUp;
  String? _listenPreview;
  String? _searchError;
  int _searchEpoch = 0;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = VoiceResponseController(settings: _voiceSettings);
    _assistant = AssistantOrchestrator(
      search: _search,
      medical: _medical,
      voice: _voice,
      stt: DeviceSpeechRecognitionService(),
    );
    if (widget.initialQuery.trim().isNotEmpty) {
      _controller.text = widget.initialQuery.trim();
      _runSearch(widget.initialQuery.trim());
    }
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // تهيئة صامتة مرة واحدة حتى تكون الضغطة الأولى = listen مباشرة.
      _speechWarmUp = _warmUpSpeechRecognition();
      unawaited(_speechWarmUp!);
      if (widget.autoStartVoice) {
        unawaited(_toggleVoice());
      }
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
    if (state == AppLifecycleState.paused) {
      unawaited(_cancelListening());
    }
  }

  Future<void> _cancelListening() async {
    if (!_listening && !_voiceSessionActive && !_assistant.stt.isListening) {
      return;
    }
    _manualStopRequested = true;
    try {
      await _assistant.stt.cancel();
    } catch (e, st) {
      debugPrint('Smart search STT cancel failed: $e\n$st');
    }
    if (mounted) {
      setState(() {
        _listening = false;
        _voiceSessionActive = false;
      });
    } else {
      _listening = false;
      _voiceSessionActive = false;
    }
  }

  void _onQueryChanged() {
    if (_suppressQueryListener) return;
    // Keep clear-button / hint state in sync while typing.
    if (mounted) setState(() {});
    if (_listening || _voiceSessionActive || _loading) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(_controller.text);
    });
  }

  void _setFieldText(String text) {
    _suppressQueryListener = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _suppressQueryListener = false;
  }

  void _clearQuery() {
    if (_loading) return;
    _debounce?.cancel();
    _manualStopRequested = true;
    unawaited(_assistant.stt.cancel());
    _setFieldText('');
    if (!mounted) return;
    setState(() {
      _results = [];
      _assistantReply = null;
      _loading = false;
      _listening = false;
      _voiceSessionActive = false;
      _listenPreview = null;
      _searchError = null;
    });
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _assistantReply = null;
        _loading = false;
        _searchError = null;
      });
      return;
    }

    _debounce?.cancel();
    final epoch = ++_searchEpoch;
    setState(() {
      _loading = true;
      _searchError = null;
      _assistantReply = null;
      _listening = false;
      _voiceSessionActive = false;
    });

    try {
      final reply = await _assistant.processQuery(
        trimmed,
        context: const AiRequestContext(screen: 'smart_search'),
      );

      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _results = reply.searchResults;
        _assistantReply = reply;
        _loading = false;
        _searchError = null;
      });
      // لا تنقّل تلقائيًا بعد النتيجة — تبقى ظاهرة حتى يخرج المستخدم.
    } catch (e, st) {
      debugPrint('Smart search / assistant failed: $e\n$st');
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _loading = false;
        _assistantReply = null;
        _results = [];
        _searchError = 'تعذّر إكمال البحث الذكي. حاول مرة أخرى.';
      });
    }
  }

  /// اعتماد النتيجة يدويًا فقط — يفتح الهدف المباشر إن وُجد، وإلا يبقي القائمة.
  Future<void> _acceptResult() async {
    if (_loading || _navigating || _voiceSessionActive) return;
    final reply = _assistantReply;
    if (reply == null) return;

    if (reply.source == AssistantReplySource.urgentCare ||
        reply.source == AssistantReplySource.safety) {
      return;
    }

    final nav = reply.smartNav;
    if (nav != null && nav.shouldNavigateDirectly && nav.target != null) {
      await _openResult(nav.target!);
      return;
    }

    if (_results.length == 1 && _results.first.hasNavigableEntity) {
      await _openResult(_results.first);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _results.isEmpty
              ? 'تم اعتماد الرد. لا توجد بطاقة للتنقل إليها حاليًا.'
              : 'تم اعتماد النتيجة — اختر من القائمة أدناه.',
        ),
      ),
    );
  }

  Future<void> _retrySameSearch() async {
    if (_loading || _voiceSessionActive) return;
    final q = (_assistantReply?.query ?? _controller.text).trim();
    if (q.isEmpty) return;
    _setFieldText(q);
    await _runSearch(q);
  }

  void _editSearch() {
    if (_loading || _voiceSessionActive) return;
    _debounce?.cancel();
    _fieldFocus.requestFocus();
    final text = _controller.text;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('عدّل نص البحث ثم اضغط بحث أو Enter')),
    );
  }

  void _cancelAiResult() {
    if (_loading) return;
    _voice.stop();
    if (!mounted) return;
    setState(() {
      _assistantReply = null;
      _searchError = null;
      _results = [];
    });
  }

  /// إيقاف يدوي من المستخدم → تثبيت النص → تشغيل البحث الحالي.
  Future<void> _manualStopAndSearch() async {
    if (_voiceBusy || _loading) return;
    if (!_voiceSessionActive && !_listening) return;

    _voiceBusy = true;
    _manualStopRequested = true;
    try {
      final text = (_listenPreview ?? _controller.text).trim();
      try {
        await _assistant.stt.stopListening();
      } catch (e, st) {
        debugPrint('Manual voice stop failed: $e\n$st');
      }

      if (!mounted) return;
      setState(() {
        _listening = false;
        _voiceSessionActive = false;
      });

      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لم يُلتقط كلام واضح. اضغط الميكروفون وحاول مرة أخرى.',
            ),
          ),
        );
        return;
      }

      _setFieldText(text);
      await _runSearch(text);
    } finally {
      _voiceBusy = false;
    }
  }

  /// توقف الالتقاط داخليًا (صمت قصير/محرك) — لا نغلق ولا نبحث؛ نعيد الاستماع إن أمكن.
  void _onMicCaptureEnded(String lastText) {
    if (!mounted || _manualStopRequested || _loading) return;
    final trimmed = lastText.trim();
    if (trimmed.isNotEmpty) {
      _setFieldText(trimmed);
      _listenPreview = trimmed;
    }
    // أبقِ حالة الاستماع ظاهرة وأعد تشغيل الالتقاط بهدوء.
    if (!_voiceSessionActive) {
      setState(() => _voiceSessionActive = true);
    }
    if (!_listening) {
      setState(() => _listening = true);
    } else if (mounted) {
      setState(() {});
    }
    unawaited(_resumeListeningQuietly());
  }

  Future<void> _resumeListeningQuietly() async {
    if (!mounted || _manualStopRequested || _loading || _voiceBusy) return;
    if (!_voiceSessionActive || _resumingListen) return;
    if (_assistant.stt.isListening) return;

    _resumingListen = true;
    try {
      // مهلة قصيرة حتى لا ندخل حلقة فورية مع محرك التعرف.
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted || _manualStopRequested || !_voiceSessionActive) return;
      if (_assistant.stt.isListening) return;

      await _assistant.stt.startListening(
        onResult: (text, {isFinal = false}) {
          if (!mounted || _manualStopRequested || !_voiceSessionActive) {
            return;
          }
          final trimmed = text.trim();
          if (trimmed.isNotEmpty) {
            _setFieldText(trimmed);
            setState(() {
              _listenPreview = trimmed;
              _listening = true;
            });
          }
        },
        onSessionEnd: (lastText) {
          _onMicCaptureEnded(lastText);
        },
        onError: (msg) {
          debugPrint('Smart search STT resume error: $msg');
          if (!mounted || _manualStopRequested) return;
          setState(() => _listening = true);
        },
      );
      if (mounted &&
          _voiceSessionActive &&
          !_manualStopRequested &&
          !_assistant.stt.isListening) {
        setState(() => _listening = true);
      }
    } catch (e, st) {
      debugPrint('Smart search quiet resume failed: $e\n$st');
    } finally {
      _resumingListen = false;
    }
  }

  Future<void> _startVoiceSession({bool clearQuery = true}) async {
    if (_voiceBusy || _loading) return;
    _voiceBusy = true;
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

      // لا relaunch / لا إغلاق. نسمح بالاستماع إذا:
      // - الصلاحيات ممنوحة مسبقًا (يعمل حتى من Cursor/flutter run)، أو
      // - التطبيق منسوب عبر Launch Services ويمكن عرض حوار النظام بأمان.
      final ready =
          await DeviceSpeechRecognitionService.macosSpeechReadyState();
      if (!ready.canInitializeSafely) {
        if (!mounted) return;
        final msg = (ready.speech == 'denied' ||
                ready.microphone == 'denied' ||
                ready.speech == 'restricted' ||
                ready.microphone == 'restricted')
            ? DeviceSpeechRecognitionService.enablePermissionMessage
            : DeviceSpeechRecognitionService.macosFirstGrantBlockedMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return;
      }

      if (!mounted) return;

      // جنس الصوت خاص بـ TTS فقط — لا نعرض ورقة منبثقة هنا حتى لا تومض الصفحة
      // ولا تستهلك الضغطة الأولى. الافتراضي «ولد» إن لم يُحدَّد.
      if (!await _voiceSettings.isGenderExplicitlySet()) {
        await _voiceSettings.setGender(AssistantVoiceGender.male);
      }

      if (!mounted) return;

      // انتظر التهيئة الصامتة إن كانت جارية (نفس Future) ثم أكمل listen في نفس الضغطة.
      final warmUp = _speechWarmUp;
      if (warmUp != null) {
        await warmUp;
        if (!mounted) return;
      }

      _debounce?.cancel();
      _manualStopRequested = false;
      if (clearQuery) {
        _setFieldText('');
      }

      // حدّث واجهة الاستماع فورًا على نفس الصفحة (بدون navigation/rebuild كامل).
      setState(() {
        _listening = true;
        _voiceSessionActive = true;
        _listenPreview = clearQuery ? '' : _controller.text;
        if (clearQuery) {
          _results = [];
          _assistantReply = null;
          _searchError = null;
        }
        _loading = false;
      });

      // نفس الضغطة: initialize (إن لزم) ثم listen مباشرة.
      await _assistant.stt.startListening(
        onResult: (text, {isFinal = false}) {
          if (!mounted || _manualStopRequested || !_voiceSessionActive) {
            return;
          }
          final trimmed = text.trim();
          if (trimmed.isNotEmpty) {
            _setFieldText(trimmed);
            setState(() => _listenPreview = trimmed);
          }
        },
        onSessionEnd: (lastText) {
          _onMicCaptureEnded(lastText);
        },
        onError: (msg) {
          debugPrint('Smart search STT error: $msg');
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
          setState(() {
            _listening = false;
            _voiceSessionActive = false;
          });
        },
      );

      if (!mounted || _manualStopRequested) return;
      if (_voiceSessionActive) {
        setState(() => _listening = true);
      }
    } catch (e, st) {
      debugPrint('Smart search voice start failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _listening = false;
        _voiceSessionActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            DeviceSpeechRecognitionService.recognitionFailedMessage,
          ),
        ),
      );
    } finally {
      _voiceBusy = false;
    }
  }

  Future<void> _toggleVoice() async {
    if (_voiceBusy || _loading) return;

    // أثناء جلسة صوت: زر الميكروفون = إيقاف وإنهاء يدوي ثم بحث.
    if (_voiceSessionActive || _listening) {
      await _manualStopAndSearch();
      return;
    }

    await _startVoiceSession(clearQuery: true);
  }

  Future<void> _submitManual() async {
    if (_loading || _listening || _voiceSessionActive) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _debounce?.cancel();
    await _runSearch(text);
  }

  Future<void> _openResult(SmartSearchResult result) async {
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
          await _runSearch(result.title);
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
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _fieldFocus.dispose();
    unawaited(_assistant.stt.cancel());
    _assistant.voice.dispose();
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
                  'جاري الاستماع — اضغط زر الميكروفون مرة أخرى للإيقاف',
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

  Widget _resultActionsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _acceptResult,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('اعتماد النتيجة'),
            style: FilledButton.styleFrom(backgroundColor: _teal),
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : _retrySameSearch,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة البحث'),
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : _editSearch,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('تعديل البحث'),
          ),
          TextButton.icon(
            onPressed: _loading ? null : _cancelAiResult,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('إلغاء'),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reply = _assistantReply;
    final isUrgent = reply?.source == AssistantReplySource.urgentCare;
    final showResultActions =
        !_loading &&
        !_voiceSessionActive &&
        (reply != null || _searchError != null);

    return ColoredBox(
      color: const Color(0xFFF7FBFC),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7FBFC),
          appBar: ClinicAppBar(
            title: const Text('بحث ذكي'),
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _fieldFocus,
                        autofocus: true,
                        enabled:
                            !_listening && !_voiceSessionActive && !_loading,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText:
                              'ابحث عن طبيب، اختصاص، مختبر، تحليل، باقة أو عرض',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _teal,
                          ),
                          suffixIcon: _controller.text.trim().isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'مسح',
                                  onPressed:
                                      (_listening ||
                                          _voiceSessionActive ||
                                          _loading)
                                      ? null
                                      : _clearQuery,
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onSubmitted: (_) => _submitManual(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: (_loading || _voiceBusy) ? null : _toggleVoice,
                      style: IconButton.styleFrom(
                        backgroundColor: (_listening || _voiceSessionActive)
                            ? Colors.red
                            : _teal,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      icon: Icon(
                        (_listening || _voiceSessionActive)
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              if (_voiceSessionActive) _voiceSessionPanel(),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'جاري معالجة الطلب الصوتي...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5B6C70),
                      ),
                    ),
                  ),
                ),
              if (!_voiceSessionActive)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: (_loading || _listening)
                          ? null
                          : () {
                              if (_controller.text.trim().isEmpty) {
                                _controller.text = 'عندي ';
                              }
                              _submitManual();
                            },
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('اسأل الغدير'),
                      style: TextButton.styleFrom(foregroundColor: _teal),
                    ),
                  ),
                ),
              if (_searchError != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _searchError!,
                        style: const TextStyle(
                          height: 1.45,
                          color: Color(0xFF9F1239),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _loading ? null : _retrySameSearch,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('إعادة المحاولة'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFBE123C),
                        ),
                      ),
                    ],
                  ),
                ),
              if (reply?.text != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.38,
                  ),
                  child: SingleChildScrollView(
                    child: AnimatedBuilder(
                      animation: _voice,
                      builder: (context, _) {
                        final speaking = _voice.isSpeaking;
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUrgent
                                ? const Color(0xFFFFF1F2)
                                : const Color(0xFFE6F8F6),
                            borderRadius: BorderRadius.circular(12),
                            border: isUrgent
                                ? Border.all(color: const Color(0xFFFECACA))
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reply!.text!,
                                style: TextStyle(
                                  height: 1.5,
                                  color: isUrgent
                                      ? const Color(0xFF9F1239)
                                      : const Color(0xFF123B42),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: speaking
                                        ? OutlinedButton.icon(
                                            onPressed: () {
                                              _voice.stop();
                                            },
                                            icon: const Icon(
                                              Icons.stop_rounded,
                                            ),
                                            label: const Text('⏹ إيقاف'),
                                          )
                                        : FilledButton.icon(
                                            onPressed: () {
                                              _voice.speak(reply.text!);
                                            },
                                            icon: const Icon(
                                              Icons.volume_up_rounded,
                                            ),
                                            label: const Text('🔊 تشغيل'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: _teal,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton.filled(
                                    tooltip: 'إعادة',
                                    onPressed: speaking
                                        ? null
                                        : () {
                                            _voice.replay();
                                          },
                                    icon: const Icon(Icons.replay_rounded),
                                    style: IconButton.styleFrom(
                                      backgroundColor: speaking
                                          ? Colors.grey.shade300
                                          : _teal,
                                    ),
                                  ),
                                ],
                              ),
                              if (_voice.lastError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _voice.lastError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (showResultActions) _resultActionsBar(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: _teal),
                            SizedBox(height: 12),
                            Text(
                              'جاري البحث...',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : _results.isEmpty
                    ? Center(
                        child: Text(
                          _searchError != null
                              ? 'لم تكتمل عملية البحث'
                              : _controller.text.trim().isEmpty
                              ? 'ابدأ الكتابة أو استخدم الميكروفون'
                              : 'لا توجد نتائج',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return SmartSearchResultCard(
                            result: item,
                            onTap: _loading ? () {} : () => _openResult(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
