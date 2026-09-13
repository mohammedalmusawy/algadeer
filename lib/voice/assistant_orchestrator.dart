import 'package:flutter/foundation.dart';

import '../ai/ai_service.dart';
import '../core/app_config.dart';
import '../medical/medical_navigation_service.dart';
import '../search/smart_navigation.dart';
import '../search/smart_search_models.dart';
import '../search/smart_search_service.dart';
import '../services/user_profile_service.dart';
import 'speech_recognition_service.dart';
import 'voice_response_controller.dart';

/// ينسّق STT → بحث محلي → AI (نص) → أمان → TTS — طبقات منفصلة.
class AssistantOrchestrator {
  AssistantOrchestrator({
    AiService? ai,
    SpeechRecognitionService? stt,
    VoiceResponseController? voice,
    SmartSearchService? search,
    MedicalNavigationService? medical,
    SmartNavigationResolver? navigator,
    UserProfileService? userProfile,
  })  : _ai = ai ?? EdgeFunctionAiService.fromConfig(),
        _stt = stt ?? DeviceSpeechRecognitionService(),
        _voice = voice ?? VoiceResponseController(),
        _search = search ?? SmartSearchService(),
        _medical = medical ?? MedicalNavigationService(),
        _navigator = navigator ?? SmartNavigationResolver(),
        _userProfile = userProfile ?? UserProfileService();

  final AiService _ai;
  final SpeechRecognitionService _stt;
  final VoiceResponseController _voice;
  final SmartSearchService _search;
  final MedicalNavigationService _medical;
  final SmartNavigationResolver _navigator;
  final UserProfileService _userProfile;

  VoiceResponseController get voice => _voice;
  SpeechRecognitionService get stt => _stt;

  Future<String> _personalize(String text) async {
    final name = await _userProfile.getDisplayName();
    return UserProfileService.addressByName(text, name);
  }

  /// معالجة استعلام — بحث محلي أولاً، ثم AI اختياري، ثم أمان، ثم TTS اختياري.
  Future<AssistantReply> processQuery(
    String query, {
    AiRequestContext context = const AiRequestContext(),
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const AssistantReply(
        query: '',
        text: null,
        spoken: false,
        source: AssistantReplySource.empty,
        searchResults: [],
      );
    }

    final userName = await _userProfile.getDisplayName();
    final enrichedContext = context.copyWith(
      extras: {
        ...context.extras,
        if (userName != null && userName.isNotEmpty) 'user_name': userName,
      },
    );

    final safety = _medical.decideForQuery(trimmed);
    if (safety.action == MedicalNavigationAction.blocked ||
        safety.action == MedicalNavigationAction.urgentCare) {
      final text = await _personalize(
        _medical.sanitizeAssistantReply(safety.safeMessage),
      );
      final spoken = await _voice.speakIfAutoEnabled(text);
      return AssistantReply(
        query: trimmed,
        text: text,
        spoken: spoken,
        source: safety.action == MedicalNavigationAction.urgentCare
            ? AssistantReplySource.urgentCare
            : AssistantReplySource.safety,
        searchResults: const [],
        navigation: safety,
        smartNav: SmartNavigationDecision(
          action: safety.action == MedicalNavigationAction.urgentCare
              ? SmartNavAction.urgentCare
              : SmartNavAction.none,
          message: text,
          confidence: 100,
        ),
      );
    }

    // Medical Navigation (بدون AI):
    // إذا كان الاستعلام وصفًا لأعراض، نوجه للاختصاصات ثم نرتّب أطباء حقيقيين من Supabase.
    if (_medical.looksLikeMedicalDescription(trimmed)) {
      final plan = await _medical.buildPlanForMedicalDescription(trimmed);
      if (plan.doctors.isNotEmpty && plan.specialties.isNotEmpty) {
        final specialtyLines = <String>[];
        for (var i = 0; i < plan.specialties.length; i++) {
          final s = plan.specialties[i];
          specialtyLines.add(
            'الأولوية ${i + 1}: ${s.specialty} — ${s.reason}',
          );
        }

        // لا نفتح طبيباً عشوائياً بعد الأعراض — إلا إذا طبيب واحد فقط مناسب.
        final availableDoctors =
            plan.doctors.where((d) => !d.isOnLeave).toList();
        final smartNav = availableDoctors.length == 1
            ? SmartNavigationDecision(
                action: SmartNavAction.openDoctor,
                message: 'يمكن فتح بطاقة الطبيب المتاح الوحيد.',
                target: availableDoctors.first,
                confidence: 85,
              )
            : SmartNavigationDecision(
                action: SmartNavAction.showResults,
                message: availableDoctors.length > 1
                    ? 'اختر الطبيب المناسب من القائمة.'
                    : 'راجع الاختصاص ثم اختر طبيباً.',
                confidence: 70,
                ambiguous: true,
              );

        final rawText =
            'توجيه للاختصاص الأقرب حسب وصفك:\n${specialtyLines.join('\n')}\n\n${MedicalNavigationService.defaultDisclaimer}';
        final text = await _personalize(
          _medical.sanitizeAssistantReply(rawText),
        );
        final spoken = await _voice.speakIfAutoEnabled(text);
        return AssistantReply(
          query: trimmed,
          text: text,
          spoken: spoken,
          source: AssistantReplySource.medicalNavigation,
          searchResults: plan.doctors,
          smartNav: smartNav,
        );
      }
      // إذا لم نستطع استخراج تخصصات كافية، نرجع لمسار البحث العادي.
    }

    var searchResults = await _search.search(trimmed);

    // Local-first: لا نستدعي AI إلا عند الحاجة.
    final hasStrongEntity = searchResults.any(
      (e) =>
          e.score >= 80 &&
          (e.type == SmartSearchResultType.doctor ||
              e.type == SmartSearchResultType.lab ||
              e.type == SmartSearchResultType.package ||
              e.type == SmartSearchResultType.offer ||
              e.type == SmartSearchResultType.analysis),
    );
    final topScore = searchResults.isNotEmpty ? searchResults.first.score : 0;
    final needsAi = searchResults.isEmpty || (!hasStrongEntity && topScore < 55);

    String? aiText;
    AssistantStructuredIntent? structured;
    if (needsAi && AppConfig.isAiBackendConfigured) {
      try {
        final aiReply = await _ai.answerAssistantQueryStructured(
          query: trimmed,
          context: enrichedContext.copyWith(extras: {
            ...enrichedContext.extras,
            'results_count': '${searchResults.length}',
            if (userName != null && userName.isNotEmpty)
              'address_user_as': userName,
          }),
          searchResults: searchResults.map((e) => e.toAiContext()).toList(),
        );
        aiText = aiReply.answer;
        structured = aiReply.structured;
        // AI لا يخترع بيانات — إن أعطى search_terms نعيد البحث محلياً فقط.
        if (searchResults.isEmpty &&
            structured != null &&
            structured.searchTerms.isNotEmpty) {
          final refined = await _search.search(structured.searchTerms.first);
          if (refined.isNotEmpty) {
            searchResults = refined;
          }
        }
      } catch (e, st) {
        debugPrint('AI assistant query failed: $e\n$st');
      }
    }

    final allowDirect =
        structured?.directIfSingleConfidentMatch ?? true;
    final smartNav = _navigator.resolve(
      query: trimmed,
      results: searchResults,
      allowDirect: allowDirect && !(structured?.isUrgent ?? false),
    );

    String text;
    AssistantReplySource source;
    if (structured?.isUrgent == true) {
      text = _medical.sanitizeAssistantReply(
        MedicalNavigationService.urgentCareMessage,
      );
      source = AssistantReplySource.urgentCare;
    } else if (aiText != null && aiText.trim().isNotEmpty) {
      text = _medical.sanitizeAssistantReply(aiText);
      source = AssistantReplySource.ai;
    } else if (searchResults.isNotEmpty) {
      text = _medical.sanitizeAssistantReply(
        smartNav.message.isNotEmpty
            ? smartNav.message
            : 'وجدت ${searchResults.length} نتيجة.',
      );
      source = AssistantReplySource.localSearch;
    } else if (needsAi && !AppConfig.isAiBackendConfigured) {
      // لا ندّعي وجود ذكاء اصطناعي كامل — توجيه بسيط للمنصة فقط.
      text = _medical.sanitizeAssistantReply(
        'يمكنني مساعدتك في البحث عن الطبيب أو الاختصاص أو المختبر أو التحليل أو الباقة الموجودة في المنصة.',
      );
      source = AssistantReplySource.aiUnavailable;
      debugPrint(
        'Assistant: AI backend not configured — using local guidance fallback.',
      );
    } else {
      text = _medical.sanitizeAssistantReply(
        'لم نجد نتيجة مطابقة حاليًا. جرّب كتابة اسم الطبيب أو الاختصاص بطريقة أبسط.',
      );
      source = AssistantReplySource.localSearch;
    }

    text = await _personalize(text);
    final spoken = await _voice.speakIfAutoEnabled(text);
    return AssistantReply(
      query: trimmed,
      text: text,
      spoken: spoken,
      source: source,
      searchResults: searchResults,
      smartNav: structured?.isUrgent == true
          ? const SmartNavigationDecision(
              action: SmartNavAction.urgentCare,
              message: MedicalNavigationService.urgentCareMessage,
              confidence: 100,
            )
          : smartNav,
      structuredIntent: structured,
    );
  }

  Future<void> speakDemo(String text) async {
    final personalized = await _personalize(text);
    await _voice.speak(personalized);
  }
}

enum AssistantReplySource {
  ai,
  localSearch,
  safety,
  urgentCare,
  empty,
  aiUnavailable,
  medicalNavigation,
}

class AssistantReply {
  const AssistantReply({
    required this.query,
    required this.text,
    required this.spoken,
    required this.source,
    required this.searchResults,
    this.navigation,
    this.smartNav,
    this.structuredIntent,
  });

  final String query;
  final String? text;
  final bool spoken;
  final AssistantReplySource source;
  final List<SmartSearchResult> searchResults;
  final MedicalNavigationDecision? navigation;
  final SmartNavigationDecision? smartNav;
  final AssistantStructuredIntent? structuredIntent;
}

extension on AiRequestContext {
  AiRequestContext copyWith({
    String? screen,
    String? specialty,
    String? labName,
    String? packageName,
    Map<String, String>? extras,
  }) {
    return AiRequestContext(
      screen: screen ?? this.screen,
      specialty: specialty ?? this.specialty,
      labName: labName ?? this.labName,
      packageName: packageName ?? this.packageName,
      extras: extras ?? this.extras,
    );
  }
}
