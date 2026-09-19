import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'nlu_models.dart';
import 'nlu_parser.dart';

/// علامات تشخيصية آمنة — بلا نص المستخدم وبلا أسرار وبلا قيم سريرية.
List<String> nluDebugMarkers(NluDebugTrace trace) {
  if (!trace.called) {
    switch (trace.skipReason) {
      case NluSkipReason.deterministicComplete:
      case NluSkipReason.deterministicAge:
        return const ['[NLU] skipped: deterministic'];
      case NluSkipReason.notConfigured:
        return const ['[NLU] fallback: disabled'];
      default:
        return const [];
    }
  }

  final lines = <String>['[NLU] OpenAI called'];
  switch (trace.fallbackReason) {
    case NluSkipReason.timeout:
      lines.add('[NLU] fallback: timeout');
      return lines;
    case NluSkipReason.httpFailure:
      lines.add('[NLU] fallback: http');
      return lines;
    case NluSkipReason.invalidJson:
      lines.add('[NLU] fallback: invalid_json');
      return lines;
    case NluSkipReason.schemaRejected:
    case NluSkipReason.unsupportedFields:
      lines.add('[NLU] fallback: invalid_schema');
      return lines;
    case NluSkipReason.notConfigured:
      lines.add('[NLU] fallback: disabled');
      return lines;
    case NluSkipReason.lowConfidence:
      lines.add('[NLU] OpenAI success');
      lines.add('[NLU] fallback: low_confidence');
      return lines;
    case NluSkipReason.overlayEmpty:
      lines.add('[NLU] OpenAI success');
      lines.add('[NLU] overlay empty');
      return lines;
    case NluSkipReason.deterministicComplete:
    case NluSkipReason.deterministicAge:
    case NluSkipReason.noActiveRespiratorySession:
    case NluSkipReason.noPendingQuestion:
    case NluSkipReason.appAction:
    case NluSkipReason.notPhase1Question:
    case null:
      break;
  }
  lines.add('[NLU] OpenAI success');
  lines.add(
    trace.acceptedSlots.isEmpty
        ? '[NLU] overlay empty'
        : '[NLU] overlay applied',
  );
  return lines;
}

/// أثر تشخيصي محلي فقط — بلا رسالة المستخدم وبلا أسرار.
void logNluDebugTrace(NluDebugTrace trace) {
  if (!kDebugMode) return;
  for (final line in nluDebugMarkers(trace)) {
    debugPrint(line);
  }
}

void _nluTime(String message) {
  if (!kDebugMode) return;
  debugPrint('[NLU-TIME] $message');
}

void _nluHttp(String message) {
  if (!kDebugMode) return;
  debugPrint('[NLU-HTTP] $message');
}

void _nluHttpEndpoint(Uri endpoint) {
  _nluHttp('edge url: ${endpoint.scheme}://${endpoint.host}${endpoint.path}');
}

void _nluHttpSanitizedBody(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _nluHttp('edge body: non_object');
      return;
    }
    final ok = decoded['ok'];
    final fallback = decoded['fallback'];
    final reason = decoded['reason'];
    final code = decoded['code'];
    final message = _safePublicErrorText(
      decoded['message'] ?? decoded['msg'] ?? decoded['error'],
    );
    _nluHttp(
      'edge body: ok=$ok fallback=$fallback reason=${reason ?? "none"} '
      'code=${code ?? "none"} message=${message ?? "none"}',
    );
  } catch (_) {
    _nluHttp('edge body: unreadable');
  }
}

String? _safePublicErrorText(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'empty';
  final lower = trimmed.toLowerCase();
  if (lower.contains('eyj') ||
      lower.contains('bearer ') ||
      lower.contains('sk-') ||
      lower.contains('sb_publishable') ||
      lower.contains('sb_secret') ||
      lower.contains('api_key') ||
      lower.contains('authorization')) {
    return 'redacted';
  }
  return trimmed.length > 180 ? '${trimmed.substring(0, 180)}…' : trimmed;
}

String _nluTransportKind(Object error) {
  if (error is http.ClientException) {
    final message = error.message.toLowerCase();
    if (message.contains('host lookup') ||
        message.contains('failed host lookup') ||
        message.contains('nodename') ||
        message.contains('not known')) {
      return 'dns';
    }
    if (message.contains('failed to fetch')) return 'failed_to_fetch';
    if (message.contains('connection refused')) return 'connection_refused';
    if (message.contains('connection reset')) return 'connection_reset';
    if (message.contains('certificate') || message.contains('handshake')) {
      return 'tls';
    }
    return 'client_exception';
  }
  return 'other';
}

bool _looksLikeJwt(String value) {
  if (!value.startsWith('eyJ')) return false;
  return value.split('.').length == 3;
}

/// رابط NLU النهائي: نفس مشروع [supabaseUrl] إذا كان dart-define على مضيف مختلف.
Uri resolveNluEdgeEndpoint({
  required String configuredUrl,
  required String supabaseUrl,
}) {
  final supabase = Uri.tryParse(supabaseUrl.trim());
  final configured = Uri.tryParse(configuredUrl.trim());
  if (configured != null &&
      configured.hasScheme &&
      configured.host.isNotEmpty &&
      supabase != null &&
      configured.host == supabase.host) {
    return configured;
  }
  if (supabase == null || supabase.host.isEmpty) {
    return configured ?? Uri();
  }
  return Uri(
    scheme: supabase.scheme.isEmpty ? 'https' : supabase.scheme,
    host: supabase.host,
    path: '/functions/v1/ai-assistant',
  );
}

/// مهلة Flutter الوحيدة المعتمدة لطلب NLU — أطول من إجهاض OpenAI في Edge.
const Duration kNluTimeout = Duration(milliseconds: 8000);

abstract class NluClient {
  bool get isEnabled;

  Future<NluClientResult> parse(NluRequest request);

  static NluClient get disabled => const DisabledNluClient();

  static NluClient fromAppConfig() {
    if (!AppConfig.isAiBackendConfigured) return const DisabledNluClient();
    return HttpNluClient(
      endpoint: resolveNluEdgeEndpoint(
        configuredUrl: AppConfig.aiEdgeFunctionUrl,
        supabaseUrl: AppConfig.supabaseUrl,
      ),
      anonKey: AppConfig.supabaseAnonKey,
    );
  }
}

class NluClientResult {
  const NluClientResult.ok(this.parse)
      : failed = false,
        reason = null;

  const NluClientResult.failed(this.reason)
      : parse = null,
        failed = true;

  final NluParse? parse;
  final bool failed;
  final NluSkipReason? reason;
}

class DisabledNluClient implements NluClient {
  const DisabledNluClient();

  @override
  bool get isEnabled => false;

  @override
  Future<NluClientResult> parse(NluRequest request) async {
    return const NluClientResult.failed(NluSkipReason.notConfigured);
  }
}

/// عميل اختبارات — بلا شبكة وبلا مفتاح.
class FakeNluClient implements NluClient {
  FakeNluClient({
    this.response,
    this.failure,
    this.delay,
    this.rawJson,
    this.hangForever = false,
  });

  NluParse? response;
  NluSkipReason? failure;
  Duration? delay;
  Object? rawJson;
  bool hangForever;
  int callCount = 0;
  NluRequest? lastRequest;

  @override
  bool get isEnabled => true;

  @override
  Future<NluClientResult> parse(NluRequest request) async {
    callCount += 1;
    lastRequest = request;
    if (hangForever) {
      await Completer<void>().future;
    }
    final wait = delay;
    if (wait != null) await Future<void>.delayed(wait);
    if (failure != null) {
      return NluClientResult.failed(failure!);
    }
    if (rawJson != null) {
      final parsed = const NluParser().parse(rawJson);
      if (parsed.rejected) {
        return NluClientResult.failed(
          parsed.reason ?? NluSkipReason.invalidJson,
        );
      }
      return NluClientResult.ok(parsed.parse!);
    }
    final parse = response;
    if (parse == null) {
      return const NluClientResult.failed(NluSkipReason.httpFailure);
    }
    return NluClientResult.ok(parse);
  }
}

/// استدعاء Edge Function فقط — المفتاح لا يغادر السيرفر.
class HttpNluClient implements NluClient {
  HttpNluClient({
    required this.endpoint,
    required this.anonKey,
    http.Client? httpClient,
    this.timeout = kNluTimeout,
  }) : _http = httpClient ?? http.Client();

  final Uri endpoint;
  final String anonKey;
  final http.Client _http;
  final Duration timeout;

  @override
  bool get isEnabled => endpoint.toString().trim().isNotEmpty;

  @override
  Future<NluClientResult> parse(NluRequest request) async {
    if (!isEnabled) {
      return const NluClientResult.failed(NluSkipReason.notConfigured);
    }
    final started = DateTime.now();
    int elapsedMs() => DateTime.now().difference(started).inMilliseconds;
    _nluTime('request started');
    _nluHttpEndpoint(endpoint);
    final configured = Uri.tryParse(AppConfig.aiEdgeFunctionUrl.trim());
    if (configured != null &&
        configured.host.isNotEmpty &&
        configured.host != endpoint.host) {
      _nluHttp('dart-define host mismatch: using supabase host');
    }
    _nluHttp('auth jwt_format: ${_looksLikeJwt(anonKey) ? "yes" : "no"}');
    try {
      final res = await _http
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $anonKey',
              'apikey': anonKey,
            },
            body: jsonEncode({
              'mode': 'nlu_parse',
              'request': request.toJson(),
            }),
          )
          .timeout(timeout);
      _nluTime('edge request completed: ${elapsedMs()}');
      _nluHttp('edge status: ${res.statusCode}');
      _nluHttpSanitizedBody(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        _nluTime('total NLU completed: ${elapsedMs()}');
        return const NluClientResult.failed(NluSkipReason.httpFailure);
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        _nluTime('total NLU completed: ${elapsedMs()}');
        return const NluClientResult.failed(NluSkipReason.invalidJson);
      }
      final body = Map<String, dynamic>.from(decoded);
      if (body['fallback'] == true || body['ok'] == false) {
        _nluTime('total NLU completed: ${elapsedMs()}');
        return const NluClientResult.failed(NluSkipReason.httpFailure);
      }
      final parseNode = body['parse'] ?? body;
      final parsed = const NluParser().parse(parseNode);
      if (parsed.rejected) {
        _nluTime('total NLU completed: ${elapsedMs()}');
        return NluClientResult.failed(
          parsed.reason ?? NluSkipReason.schemaRejected,
        );
      }
      _nluTime('total NLU completed: ${elapsedMs()}');
      return NluClientResult.ok(parsed.parse!);
    } on TimeoutException {
      _nluTime('flutter timeout: ${elapsedMs()}');
      return const NluClientResult.failed(NluSkipReason.timeout);
    } catch (e) {
      _nluHttp('edge status: none');
      _nluHttp('transport: ${e.runtimeType}');
      _nluHttp('transport kind: ${_nluTransportKind(e)}');
      _nluTime('total NLU completed: ${elapsedMs()}');
      return const NluClientResult.failed(NluSkipReason.httpFailure);
    }
  }
}
