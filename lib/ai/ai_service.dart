import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';
import '../search/smart_search_models.dart';

/// طبقة AI آمنة للمستقبل — بدون مزود وبدون مفاتيح في العميل.
///
/// أي توليد فعلي يجب أن يمر عبر Backend / Edge Function
/// المعرّف في [AppConfig.aiEdgeFunctionUrl].

class AiRequestContext {
  final String? screen;
  final String? specialty;
  final String? labName;
  final String? packageName;
  final Map<String, String> extras;

  const AiRequestContext({
    this.screen,
    this.specialty,
    this.labName,
    this.packageName,
    this.extras = const {},
  });

  Map<String, dynamic> toJson() => {
        if (screen != null) 'screen': screen,
        if (specialty != null) 'specialty': specialty,
        if (labName != null) 'lab_name': labName,
        if (packageName != null) 'package_name': packageName,
        if (extras.isNotEmpty) 'extras': extras,
      };
}

/// رد AI: نص + Intent منظم (لا بيانات تجارية مخترعة).
class AiAssistantResponse {
  const AiAssistantResponse({
    this.answer,
    this.structured,
    this.providerConfigured = false,
  });

  final String? answer;
  final AssistantStructuredIntent? structured;
  final bool providerConfigured;
}

/// واجهة مجردة — لا تربط مزود AI هنا حتى يُتفق عليه.
abstract class AiService {
  Future<String?> generateDynamicMessage({
    required String purpose,
    AiRequestContext context = const AiRequestContext(),
  });

  /// استعلام المساعد — يرجع نصاً فقط؛ TTS منفصل.
  Future<String?> answerAssistantQuery({
    required String query,
    AiRequestContext context = const AiRequestContext(),
    List<Map<String, dynamic>> searchResults = const [],
  });

  /// نفس الاستعلام مع Structured Intent جاهز للاستهلاك.
  Future<AiAssistantResponse> answerAssistantQueryStructured({
    required String query,
    AiRequestContext context = const AiRequestContext(),
    List<Map<String, dynamic>> searchResults = const [],
  }) async {
    final text = await answerAssistantQuery(
      query: query,
      context: context,
      searchResults: searchResults,
    );
    return AiAssistantResponse(answer: text);
  }
}

/// تنفيذ افتراضي آمن: Edge Function فقط عند التفعيل.
class EdgeFunctionAiService implements AiService {
  EdgeFunctionAiService({
    this.endpoint = '',
    http.Client? httpClient,
    SupabaseClient? supabase,
  })  : _http = httpClient ?? http.Client(),
        _supabase = supabase;

  final String endpoint;
  final http.Client _http;
  final SupabaseClient? _supabase;

  factory EdgeFunctionAiService.fromConfig({SupabaseClient? supabase}) {
    SupabaseClient? client = supabase;
    if (client == null) {
      try {
        client = Supabase.instance.client;
      } catch (_) {
        client = null;
      }
    }
    return EdgeFunctionAiService(
      endpoint: AppConfig.aiEdgeFunctionUrl,
      supabase: client,
    );
  }

  String? get _authBearer {
    final session = _supabase?.auth.currentSession;
    if (session != null) return session.accessToken;
    if (AppConfig.supabaseAnonKey.trim().isNotEmpty) {
      return AppConfig.supabaseAnonKey;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _postEdgeFunctionRaw(
    Map<String, dynamic> body,
  ) async {
    final url = endpoint.trim();
    if (url.isEmpty) return null;

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final bearer = _authBearer;
    if (bearer != null) {
      headers['Authorization'] = 'Bearer $bearer';
    }

    try {
      final response = await _http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        if (decoded is String && decoded.trim().isNotEmpty) {
          return {'answer': decoded.trim()};
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<String?> _postEdgeFunction(Map<String, dynamic> body) async {
    final map = await _postEdgeFunctionRaw(body);
    if (map == null) return null;
    final answer = map['answer'] ?? map['text'] ?? map['message'];
    if (answer != null && '$answer'.trim().isNotEmpty) {
      return '$answer'.trim();
    }
    return null;
  }

  @override
  Future<String?> generateDynamicMessage({
    required String purpose,
    AiRequestContext context = const AiRequestContext(),
  }) async {
    return _postEdgeFunction({
      'mode': 'dynamic_message',
      'purpose': purpose,
      'context': context.toJson(),
    });
  }

  @override
  Future<String?> answerAssistantQuery({
    required String query,
    AiRequestContext context = const AiRequestContext(),
    List<Map<String, dynamic>> searchResults = const [],
  }) async {
    final structured = await answerAssistantQueryStructured(
      query: query,
      context: context,
      searchResults: searchResults,
    );
    return structured.answer;
  }

  @override
  Future<AiAssistantResponse> answerAssistantQueryStructured({
    required String query,
    AiRequestContext context = const AiRequestContext(),
    List<Map<String, dynamic>> searchResults = const [],
  }) async {
    final map = await _postEdgeFunctionRaw({
      'mode': 'assistant_query',
      'query': query,
      'context': context.toJson(),
      if (searchResults.isNotEmpty) 'search_results': searchResults,
    });

    if (map == null) {
      return const AiAssistantResponse();
    }

    final answer = map['answer'] ?? map['text'] ?? map['message'];
    final structuredRaw = map['structured'];
    Map<String, dynamic>? structuredMap;
    if (structuredRaw is Map) {
      structuredMap = Map<String, dynamic>.from(structuredRaw);
    }

    return AiAssistantResponse(
      answer: answer != null && '$answer'.trim().isNotEmpty
          ? '$answer'.trim()
          : null,
      structured: AssistantStructuredIntent.fromJson(structuredMap),
      providerConfigured: map['provider_configured'] == true,
    );
  }
}
