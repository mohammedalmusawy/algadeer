/// HYBRID NLU Phase 1 — استمرار تنفسي فقط.
///
/// المبدأ: الذكاء يفهم اللغة، وغدير يتخذ كل قرار طبي/تطبيقي.
/// الاختبارات تعمل بـ [FakeNluClient] بلا مفتاح ولا شبكة.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory.dart';
import 'package:ghadeer_clinic/core/app_config.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

SmartSearchResult _doc(String id, String title, String specialty) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty,
    doctorId: id,
    specialty: specialty,
    phone: '07700000000',
    whatsapp: '07700000000',
    clinicLocation: 'الكرادة',
    score: 96,
  );
}

final _saeedi = _doc('saeedi', 'الدكتور علي ناصر السعيدي', 'طب الأطفال');

const _ambiguousIraqiContinuation = 'عنده حرارة ويا السعال وما ياخذ هوا';

Map<String, Object?> _nluJson({
  String fever = 'present',
  String breathlessness = 'present',
  String cough = 'unknown',
  String sputum = 'unknown',
  String hemoptysis = 'unknown',
  String population = 'unknown',
  Object? ageYears,
  String durationBucket = 'unknown',
  double overall = 0.92,
  String subject = 'inherit',
  bool continuation = true,
  Map<String, Object?> extra = const {},
}) {
  return {
    'schema_version': 1,
    'intent': 'clinical_continuation',
    'continuation': continuation,
    'subject': subject,
    'population': population,
    'age_years': ageYears,
    'duration': {'bucket': durationBucket},
    'slots': {
      'cough': cough,
      'fever': fever,
      'breathlessness': breathlessness,
      'sputum': sputum,
      'hemoptysis': hemoptysis,
    },
    'requested_action': 'none',
    'confidence': {
      'overall': overall,
      'slots': {
        'fever': 0.91,
        'breathlessness': 0.9,
      },
    },
    ...extra,
  };
}

NluParse _nluParse({
  RespiratoryTriState fever = RespiratoryTriState.present,
  RespiratoryTriState breathlessness = RespiratoryTriState.present,
  RespiratoryTriState cough = RespiratoryTriState.unknown,
  RespiratoryPopulation population = RespiratoryPopulation.unknown,
  int? ageYears,
  RespiratoryDurationBucket durationBucket = RespiratoryDurationBucket.unknown,
  double overall = 0.92,
  Map<String, double> slotConfidence = const {
    'fever': 0.91,
    'breathlessness': 0.9,
  },
}) {
  return NluParse(
    intent: NluIntent.clinicalContinuation,
    continuation: true,
    subject: NluSubject.inherit,
    population: population,
    ageYears: ageYears,
    durationBucket: durationBucket,
    cough: cough,
    fever: fever,
    breathlessness: breathlessness,
    requestedAction: NluRequestedAction.none,
    overallConfidence: overall,
    slotConfidence: slotConfidence,
  );
}

RespiratoryInterpretation _emptyInterp() => const RespiratoryInterpretation(
      isRespiratoryTurn: true,
    );

RespiratorySession _childCoughSession({
  RespiratoryTriState fever = RespiratoryTriState.unknown,
  RespiratoryTriState breathlessness = RespiratoryTriState.unknown,
  String lastQuestionKey = 'childAssociated',
}) {
  return RespiratorySession(
    active: true,
    topic: RespiratoryTopic.acuteCough,
    population: RespiratoryPopulation.child,
    durationBucket: RespiratoryDurationBucket.days,
    lastQuestionKey: lastQuestionKey,
    symptomKeys: const ['cough', 'childAgeKnown'],
    askedQuestionKeys: const ['childAge', 'childAssociated'],
    fever: fever,
    breathlessness: breathlessness,
  );
}

class _Harness {
  _Harness({NluClient? nluClient}) {
    fake = nluClient is FakeNluClient ? nluClient : null;
    context = ConversationContext();
    planner = SmartBrainPlanner(
      nluClient: nluClient ?? NluClient.disabled,
      doctorLookup: (q) async {
        lookups.add(q);
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('السعيدي') || n.contains('اطفال')) return [_saeedi];
        return const [];
      },
      labLookup: (_) async => const [],
      analysisLookup: (_) async => const [],
      packagesLookup: (_) async => const [],
      packagesForAnalysisLookup: (_) async => const [],
      activePackagesLookup: ({labId, nameQuery}) async => const [],
      discountedPackagesLookup: ({labId}) async => const [],
    );
  }

  FakeNluClient? fake;
  late final ConversationContext context;
  late final SmartBrainPlanner planner;
  final List<String> lookups = <String>[];

  Future<AssistantActionPlan> turn(String query) =>
      planner.plan(query: query, context: context);

  Future<void> reachDangerQuestion() async {
    await turn('علي ناصر السعدي');
    final cough = await turn('ابني عنده سعال من يومين');
    expect(context.respiratorySession.active, isTrue, reason: cough.message);
    expect(context.respiratorySession.population, RespiratoryPopulation.child);
    expect(context.respiratorySession.lastQuestionKey, 'childAge',
        reason: cough.message);
    final age = await turn('8 سنوات');
    expect(context.respiratorySession.lastQuestionKey, 'childAssociated',
        reason: age.message);
  }

  void expectTrustedChildFacts(String reason) {
    expect(context.respiratorySession.population, RespiratoryPopulation.child,
        reason: reason);
    expect(context.respiratorySession.hasCoughContext, isTrue, reason: reason);
    expect(context.respiratorySession.durationBucket,
        RespiratoryDurationBucket.days,
        reason: reason);
    expect(context.respiratorySession.symptomKeys, contains('childAgeKnown'),
        reason: reason);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('عقد NLU — المدقّق', () {
    const parser = NluParser();

    test('I — حقل طبي غير مدعوم يُرفض', () {
      final r = parser.parse(_nluJson(extra: const {
        'diagnosis': 'pneumonia',
      }));
      expect(r.rejected, isTrue);
      expect(r.reason, NluSkipReason.unsupportedFields);
      expect(r.parse, isNull);
    });

    test('C — JSON فاسد يُرفض', () {
      expect(parser.parse('<<<').reason, NluSkipReason.invalidJson);
      expect(parser.parse(null).reason, NluSkipReason.invalidJson);
      expect(parser.parse(['x']).reason, NluSkipReason.invalidJson);
    });

    test('نسخة مخطط خاطئة تُرفض', () {
      final bad = _nluJson()..['schema_version'] = 2;
      expect(parser.parse(bad).reason, NluSkipReason.schemaRejected);
    });

    test('الخانات التنفسية الخمس تُقبل مع inherit/continuation', () {
      final r = parser.parse(_nluJson());
      expect(r.rejected, isFalse);
      expect(r.parse!.continuation, isTrue);
      expect(r.parse!.subject, NluSubject.inherit);
      expect(r.parse!.fever, RespiratoryTriState.present);
      expect(r.parse!.breathlessness, RespiratoryTriState.present);
      expect(r.parse!.meetsOverallConfidence, isTrue);
    });
  });

  group('علامات التشخيص الآمنة', () {
    test('لا تغيّر الحالات الست ولا تسرب محتوى', () {
      const skipped = NluDebugTrace(
        called: false,
        skipReason: NluSkipReason.deterministicComplete,
      );
      const calledApplied = NluDebugTrace(
        called: true,
        acceptedSlots: ['breathlessness'],
      );
      const calledEmpty = NluDebugTrace(
        called: true,
        fallbackReason: NluSkipReason.overlayEmpty,
      );
      const calledTimeout = NluDebugTrace(
        called: true,
        fallbackReason: NluSkipReason.timeout,
      );
      const calledLow = NluDebugTrace(
        called: true,
        fallbackReason: NluSkipReason.lowConfidence,
      );
      const disabled = NluDebugTrace(
        called: false,
        skipReason: NluSkipReason.notConfigured,
      );
      expect(nluDebugMarkers(skipped), ['[NLU] skipped: deterministic']);
      expect(nluDebugMarkers(calledApplied), [
        '[NLU] OpenAI called',
        '[NLU] OpenAI success',
        '[NLU] overlay applied',
      ]);
      expect(nluDebugMarkers(calledEmpty), [
        '[NLU] OpenAI called',
        '[NLU] OpenAI success',
        '[NLU] overlay empty',
      ]);
      expect(nluDebugMarkers(calledTimeout), [
        '[NLU] OpenAI called',
        '[NLU] fallback: timeout',
      ]);
      expect(nluDebugMarkers(calledLow), [
        '[NLU] OpenAI called',
        '[NLU] OpenAI success',
        '[NLU] fallback: low_confidence',
      ]);
      expect(nluDebugMarkers(disabled), ['[NLU] fallback: disabled']);
      for (final lines in [
        nluDebugMarkers(skipped),
        nluDebugMarkers(calledApplied),
        nluDebugMarkers(calledEmpty),
        nluDebugMarkers(calledTimeout),
        nluDebugMarkers(calledLow),
        nluDebugMarkers(disabled),
      ]) {
        final blob = lines.join(' ');
        expect(blob.contains('sk-'), isFalse);
        expect(blob.contains('Authorization'), isFalse);
        expect(blob.contains('fever'), isFalse);
        expect(blob.contains('child'), isFalse);
      }
    });
  });

  group('بوابة الاستدعاء', () {
    const gate = RespiratoryNluGate();

    test('F — بلا جلسة نشطة لا يُستدعى', () {
      final d = gate.evaluate(
        query: 'حرارة وضيق بنفس',
        session: RespiratorySession.inactive,
        deterministic: const RespiratoryInterpreter()
            .interpret('حرارة وضيق بنفس'),
        intent: AssistantIntent.unknown,
      );
      expect(d.shouldCall, isFalse);
      expect(d.skipReason, NluSkipReason.noActiveRespiratorySession);
    });

    test('A — الاستخراج الحتمي الكامل يتخطى AI', () {
      final interp = const RespiratoryInterpreter()
          .interpret('عنده حرارة وضيق بنفس');
      expect(interp.fever, RespiratoryTriState.present);
      expect(interp.breathlessness, RespiratoryTriState.present);
      final d = gate.evaluate(
        query: 'عنده حرارة وضيق بنفس',
        session: _childCoughSession(),
        deterministic: interp,
        intent: AssistantIntent.unknown,
      );
      expect(d.shouldCall, isFalse);
      expect(d.skipReason, NluSkipReason.deterministicComplete);
    });

    test('H — مسار طبيب/اتصال/واتساب يتخطى AI', () {
      for (final item in [
        (
          'الدكتور علي ناصر السعيدي',
          AssistantIntent.doctorSearch,
        ),
        (
          'اتصل بالدكتور علي ناصر السعيدي',
          AssistantIntent.callDoctor,
        ),
        (
          'ارسل واتساب',
          AssistantIntent.messageDoctor,
        ),
      ]) {
        final d = gate.evaluate(
          query: item.$1,
          session: _childCoughSession(),
          deterministic: const RespiratoryInterpretation(),
          intent: item.$2,
        );
        expect(d.shouldCall, isFalse, reason: item.$1);
        expect(d.skipReason, NluSkipReason.appAction, reason: item.$1);
      }
    });

    test('B — استمرار عراقي ناقص يُسمح باستدعاء AI', () {
      final interp =
          const RespiratoryInterpreter().interpret(_ambiguousIraqiContinuation);
      expect(interp.fever, RespiratoryTriState.present);
      expect(interp.breathlessness, RespiratoryTriState.unknown);
      final d = gate.evaluate(
        query: _ambiguousIraqiContinuation,
        session: _childCoughSession(),
        deterministic: interp,
        intent: AssistantIntent.unknown,
      );
      expect(d.shouldCall, isTrue);
    });

    test('جملة التحقق الحية تصل للبوابة وليست حتمية مكتملة', () {
      const live = 'عنده حرارة ويا السعال ويحس نفسه ما يكفيه';
      const interp = RespiratoryInterpreter();
      const gate = RespiratoryNluGate();
      final original = interp.interpret(_ambiguousIraqiContinuation);
      final candidate = interp.interpret(live);
      expect(original.fever, RespiratoryTriState.present);
      expect(original.breathlessness, RespiratoryTriState.unknown);
      expect(candidate.fever, RespiratoryTriState.present);
      expect(candidate.breathlessness, RespiratoryTriState.unknown,
          reason: 'نفسه ما يكفيه ليست في مرادفات ضيق النفس الحتمية');
      expect(
        gate
            .evaluate(
              query: live,
              session: _childCoughSession(),
              deterministic: candidate,
              intent: AssistantIntent.unknown,
            )
            .shouldCall,
        isTrue,
      );
      expect(
        nluDebugMarkers(
          const NluDebugTrace(
            called: false,
            skipReason: NluSkipReason.deterministicAge,
          ),
        ),
        ['[NLU] skipped: deterministic'],
      );
      expect(
        nluDebugMarkers(
          const NluDebugTrace(
            called: false,
            skipReason: NluSkipReason.notConfigured,
          ),
        ),
        ['[NLU] fallback: disabled'],
      );
    });
  });

  group('دمج آمن', () {
    const overlay = RespiratoryNluOverlay();

    test('B — يملأ الحمى وضيق النفس المجهولين فقط', () {
      final applied = overlay.apply(
        interp: _emptyInterp(),
        session: _childCoughSession(),
        parse: _nluParse(),
      );
      expect(applied.fallbackReason, isNull);
      expect(applied.acceptedSlots, containsAll(['fever', 'breathlessness']));
      expect(applied.interp.fever, RespiratoryTriState.present);
      expect(applied.interp.breathlessness, RespiratoryTriState.present);
      expect(applied.interp.population, RespiratoryPopulation.unknown);
      expect(applied.interp.durationBucket, RespiratoryDurationBucket.unknown);
    });

    test('E — ثقة منخفضة ترفض الدفعة', () {
      final applied = overlay.apply(
        interp: _emptyInterp(),
        session: _childCoughSession(),
        parse: _nluParse(overall: 0.2),
      );
      expect(applied.fallbackReason, NluSkipReason.lowConfidence);
      expect(applied.interp.fever, RespiratoryTriState.unknown);
      expect(applied.interp.breathlessness, RespiratoryTriState.unknown);
    });

    test('G — لا يُستبدل absent/حقيقة موثوقة بصمت', () {
      final applied = overlay.apply(
        interp: const RespiratoryInterpretation(
          isRespiratoryTurn: true,
          fever: RespiratoryTriState.absent,
        ),
        session: _childCoughSession(fever: RespiratoryTriState.absent),
        parse: _nluParse(
          fever: RespiratoryTriState.present,
          cough: RespiratoryTriState.absent,
          population: RespiratoryPopulation.adult,
          ageYears: 99,
          durationBucket: RespiratoryDurationBucket.months,
        ),
      );
      expect(applied.rejectedSlots, contains('fever'));
      expect(applied.rejectedSlots, contains('cough'));
      expect(applied.interp.fever, RespiratoryTriState.absent);
      expect(applied.interp.symptomKeys.contains('cough'), isFalse);
    });
  });

  group('عميل HTTP — بلا مفتاح OpenAI', () {
    test('يستدعي mode=nlu_parse فقط ويعيد parse مصدَّقاً', () async {
      final httpClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], isNot(contains('sk-')));
        final body = jsonDecode(request.body) as Map;
        expect(body['mode'], 'nlu_parse');
        expect(body.containsKey('messages'), isFalse);
        final req = body['request'] as Map;
        expect(req.containsKey('doctors'), isFalse);
        expect(req.containsKey('labs'), isFalse);
        return http.Response(
          jsonEncode({'ok': true, 'parse': _nluJson()}),
          200,
        );
      });
      final client = HttpNluClient(
        endpoint: Uri.parse('https://example.test/functions/v1/ai-assistant'),
        anonKey: 'anon-not-openai',
        httpClient: httpClient,
      );
      final result = await client.parse(
        const NluRequest(
          userMessage: _ambiguousIraqiContinuation,
          session: NluSessionSnapshot(
            activePack: 'respiratory',
            continuationExpected: true,
            lastQuestionKey: 'childAssociated',
          ),
        ),
      );
      expect(result.failed, isFalse);
      expect(result.parse!.fever, RespiratoryTriState.present);
    });

    test('D — المهلة تُترجم إلى fallback', () async {
      final client = HttpNluClient(
        endpoint: Uri.parse('https://example.test/functions/v1/ai-assistant'),
        anonKey: 'anon-not-openai',
        httpClient: _HangingClient(),
        timeout: const Duration(milliseconds: 40),
      );
      final result = await client.parse(
        const NluRequest(
          userMessage: 'x',
          session: NluSessionSnapshot(
            activePack: 'respiratory',
            continuationExpected: true,
          ),
        ),
      );
      expect(result.failed, isTrue);
      expect(result.reason, NluSkipReason.timeout);
    });

    test('استثناء النقل يُترجم إلى httpFailure بلا رد Edge', () async {
      final client = HttpNluClient(
        endpoint: Uri.parse('https://example.test/functions/v1/ai-assistant'),
        anonKey: 'anon-not-openai',
        httpClient: _ThrowingClient(),
      );
      final result = await client.parse(
        const NluRequest(
          userMessage: 'x',
          session: NluSessionSnapshot(
            activePack: 'respiratory',
            continuationExpected: true,
          ),
        ),
      );
      expect(result.failed, isTrue);
      expect(result.reason, NluSkipReason.httpFailure);
    });

    test('مضيف dart-define الخاطئ يُستبدل بمضيف supabaseUrl', () {
      final resolved = resolveNluEdgeEndpoint(
        configuredUrl:
            'https://ployefjobsnqqahdwnkh.supabase.co/functions/v1/ai-assistant',
        supabaseUrl: 'https://ployefiobsnqqahdwnkh.supabase.co',
      );
      expect(resolved.scheme, 'https');
      expect(resolved.host, 'ployefiobsnqqahdwnkh.supabase.co');
      expect(resolved.path, '/functions/v1/ai-assistant');
    });

    test('نفس مضيف المشروع يُحفظ كما هو', () {
      const url =
          'https://ployefiobsnqqahdwnkh.supabase.co/functions/v1/ai-assistant';
      final resolved = resolveNluEdgeEndpoint(
        configuredUrl: url,
        supabaseUrl: 'https://ployefiobsnqqahdwnkh.supabase.co',
      );
      expect(resolved.toString(), url);
    });

    test('HTTP 401 من البوابة يُترجم إلى httpFailure', () async {
      final httpClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'UNAUTHORIZED_INVALID_JWT_FORMAT',
            'message': 'Invalid JWT',
          }),
          401,
        );
      });
      final client = HttpNluClient(
        endpoint: Uri.parse('https://example.test/functions/v1/ai-assistant'),
        anonKey: 'anon-not-openai',
        httpClient: httpClient,
      );
      final result = await client.parse(
        const NluRequest(
          userMessage: 'x',
          session: NluSessionSnapshot(
            activePack: 'respiratory',
            continuationExpected: true,
          ),
        ),
      );
      expect(result.failed, isTrue);
      expect(result.reason, NluSkipReason.httpFailure);
    });
  });

  group('المخطِّط — تجربة الاستمرار التنفسي', () {
    test('الافتراضي بلا إعداد AI لا يستدعي أحداً', () {
      expect(AppConfig.aiEdgeFunctionUrl, isEmpty);
      expect(AppConfig.isAiBackendConfigured, isFalse);
      expect(NluClient.fromAppConfig(), isA<DisabledNluClient>());
    });

    test('A — نجاح حتمي: «عنده حرارة وضيق بنفس» لا يستدعي AI', () async {
      final fake = FakeNluClient(response: _nluParse());
      final h = _Harness(nluClient: fake);
      await h.reachDangerQuestion();
      expect(fake.callCount, 0);
      final plan = await h.turn('عنده حرارة وضيق بنفس');
      expect(fake.callCount, 0, reason: plan.message);
      final trace = h.planner.lastNluTraceForTest;
      expect(trace, isNotNull);
      expect(trace!.called, isFalse);
      expect(trace.skipReason, NluSkipReason.deterministicComplete);
      expect(nluDebugMarkers(trace), ['[NLU] skipped: deterministic']);
      expect(h.context.respiratorySession.fever, RespiratoryTriState.present);
      expect(h.context.respiratorySession.breathlessness,
          RespiratoryTriState.present);
      h.expectTrustedChildFacts(plan.message);
    });

    test('B — استمرار عراقي غامض يملأ الحمى وضيق النفس عبر overlay', () async {
      final fake = FakeNluClient(response: _nluParse());
      final h = _Harness(nluClient: fake);
      await h.reachDangerQuestion();
      final plan = await h.turn(_ambiguousIraqiContinuation);
      expect(fake.callCount, 1, reason: plan.message);
      final req = fake.lastRequest!;
      expect(req.userMessage, _ambiguousIraqiContinuation);
      expect(req.session.activePack, 'respiratory');
      expect(req.session.continuationExpected, isTrue);
      expect(req.session.lastQuestionKey, 'childAssociated');
      expect(req.session.population, 'child');
      expect(req.session.ageKnown, isTrue);
      expect(req.toJson().containsKey('doctors'), isFalse);
      expect(req.session.toJson().containsKey('last_guidance'), isFalse);

      final trace = h.planner.lastNluTraceForTest!;
      expect(trace.called, isTrue);
      expect(trace.fallbackReason, isNull);
      expect(nluDebugMarkers(trace), [
        '[NLU] OpenAI called',
        '[NLU] OpenAI success',
        '[NLU] overlay applied',
      ]);
      expect(trace.deterministicFever, RespiratoryTriState.present);
      expect(trace.deterministicBreathlessness, RespiratoryTriState.unknown);
      expect(trace.acceptedSlots, contains('breathlessness'));
      expect(trace.mergedFever, RespiratoryTriState.present);
      expect(trace.mergedBreathlessness, RespiratoryTriState.present);
      h.expectTrustedChildFacts(plan.message);
      expect(h.context.respiratorySession.fever, RespiratoryTriState.present);
      expect(h.context.respiratorySession.breathlessness,
          RespiratoryTriState.present);
    });

    test('جملة التحقق الحية تستدعي NLU عبر المخطّط', () async {
      const live = 'عنده حرارة ويا السعال ويحس نفسه ما يكفيه';
      final fake = FakeNluClient(response: _nluParse());
      final h = _Harness(nluClient: fake);
      await h.reachDangerQuestion();
      final plan = await h.turn(live);
      expect(fake.callCount, 1, reason: plan.message);
      final trace = h.planner.lastNluTraceForTest!;
      expect(trace.called, isTrue);
      expect(trace.skipReason, isNot(NluSkipReason.deterministicComplete));
      expect(nluDebugMarkers(trace), [
        '[NLU] OpenAI called',
        '[NLU] OpenAI success',
        '[NLU] overlay applied',
      ]);
      expect(trace.deterministicBreathlessness, RespiratoryTriState.unknown);
      expect(trace.acceptedSlots, contains('breathlessness'));
      h.expectTrustedChildFacts(plan.message);
    });

    test('C — JSON فاسد → مسار حتمي', () async {
      final fake = FakeNluClient(rawJson: '<<<not-json>>>');
      final h = _Harness(nluClient: fake);
      await h.reachDangerQuestion();
      final plan = await h.turn(_ambiguousIraqiContinuation);
      expect(fake.callCount, 1);
      final trace = h.planner.lastNluTraceForTest!;
      expect(trace.called, isTrue);
      expect(trace.fallbackReason, NluSkipReason.invalidJson);
      expect(nluDebugMarkers(trace), [
        '[NLU] OpenAI called',
        '[NLU] fallback: invalid_json',
      ]);
      expect(trace.mergedBreathlessness, isNot(RespiratoryTriState.present),
          reason: plan.message);
      h.expectTrustedChildFacts(plan.message);
      expect(plan.message.trim(), isNotEmpty);
    });

    test('D — مهلة → مسار حتمي', () async {
      final fake = FakeNluClient(hangForever: true);
      final h = _Harness(nluClient: fake);
      await h.reachDangerQuestion();
      final plan = await h.turn(_ambiguousIraqiContinuation);
      expect(fake.callCount, 1);
      final trace = h.planner.lastNluTraceForTest!;
      expect(trace.called, isTrue);
      expect(trace.fallbackReason, NluSkipReason.timeout);
      expect(nluDebugMarkers(trace), [
        '[NLU] OpenAI called',
        '[NLU] fallback: timeout',
      ]);
      h.expectTrustedChildFacts(plan.message);
      expect(plan.message.trim(), isNotEmpty);
    });

    test('E — ثقة منخفضة ترفض overlay', () async {
      final fake = FakeNluClient(response: _nluParse(overall: 0.12));
      final h = _Harness(nluClient: fake);
      await h.reachDangerQuestion();
      final plan = await h.turn(_ambiguousIraqiContinuation);
      final trace = h.planner.lastNluTraceForTest!;
      expect(trace.called, isTrue);
      expect(trace.fallbackReason, NluSkipReason.lowConfidence);
      expect(nluDebugMarkers(trace), [
        '[NLU] OpenAI called',
        '[NLU] OpenAI success',
        '[NLU] fallback: low_confidence',
      ]);
      expect(trace.rejectedSlots, contains('overall'));
      expect(h.context.respiratorySession.breathlessness,
          isNot(RespiratoryTriState.present),
          reason: plan.message);
      h.expectTrustedChildFacts(plan.message);
    });

    test('F — جملة مستقلة لا تختلق طفلاً/جلسة سابقة', () async {
      final fake = FakeNluClient(response: _nluParse(
        population: RespiratoryPopulation.child,
        ageYears: 8,
        durationBucket: RespiratoryDurationBucket.days,
        cough: RespiratoryTriState.present,
      ));
      final h = _Harness(nluClient: fake);
      final plan = await h.turn('حرارة وضيق بنفس');
      expect(fake.callCount, 0, reason: 'لا جلسة استمرار تنفسي: ${plan.message}');
      final trace = h.planner.lastNluTraceForTest;
      if (trace != null) {
        expect(trace.called, isFalse);
        expect(
          trace.skipReason,
          anyOf(
            NluSkipReason.noActiveRespiratorySession,
            NluSkipReason.noPendingQuestion,
            NluSkipReason.deterministicComplete,
          ),
        );
        expect(nluDebugMarkers(trace), isNot(contains('[NLU] OpenAI called')));
      }
      expect(h.context.respiratorySession.population,
          isNot(RespiratoryPopulation.child),
          reason: plan.message);
      expect(h.context.respiratorySession.symptomKeys.contains('childAgeKnown'),
          isFalse,
          reason: plan.message);
      expect(h.context.respiratorySession.durationBucket,
          isNot(RespiratoryDurationBucket.days),
          reason: 'ممنوع اختراع مدة يومين: ${plan.message}');
      expect(plan.message.contains('سعال الطفل'), isFalse, reason: plan.message);
    });

    test('G — الحالة التنفسية القائمة لا تُستبدل بصمت', () async {
      final fake = FakeNluClient(
        response: _nluParse(
          fever: RespiratoryTriState.present,
          cough: RespiratoryTriState.absent,
          population: RespiratoryPopulation.adult,
          ageYears: 99,
          durationBucket: RespiratoryDurationBucket.months,
        ),
      );
      final h = _Harness(nluClient: fake);
      await h.reachDangerQuestion();
      final plan = await h.turn(_ambiguousIraqiContinuation);
      expect(fake.callCount, 1, reason: plan.message);
      final trace = h.planner.lastNluTraceForTest!;
      expect(trace.called, isTrue);
      expect(trace.rejectedSlots, contains('cough'));
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
      h.expectTrustedChildFacts(
        'AI حاول قلب السعال/العمر/المدة/الشعب: ${plan.message}',
      );
      expect(trace.finalPopulation, RespiratoryPopulation.child);
      expect(trace.finalDuration, RespiratoryDurationBucket.days);
      expect(trace.finalHasCough, isTrue);
      expect(trace.mergedFever, RespiratoryTriState.present);
      expect(trace.mergedBreathlessness, RespiratoryTriState.present);
    });

    test('H — طبيب/اتصال/واتساب لا يستدعي AI داخل الجلسة', () async {
      final fake = FakeNluClient(response: _nluParse());
      final h = _Harness(nluClient: fake);
      await h.reachDangerQuestion();
      fake.callCount = 0;
      await h.turn('الدكتور علي ناصر السعيدي');
      expect(fake.callCount, 0);
      await h.turn('اتصل بالدكتور علي ناصر السعيدي');
      expect(fake.callCount, 0);
      await h.turn('ارسل واتساب');
      expect(fake.callCount, 0);
    });

    test('I — حقول طبية غير مدعومة تُرفض ويُكمَل حتمياً', () async {
      final fake = FakeNluClient(
        rawJson: _nluJson(extra: const {
          'destination': 'pediatric_er',
          'medication': 'antibiotic',
        }),
      );
      final h = _Harness(nluClient: fake);
      await h.reachDangerQuestion();
      final plan = await h.turn(_ambiguousIraqiContinuation);
      expect(fake.callCount, 1);
      final trace = h.planner.lastNluTraceForTest!;
      expect(trace.called, isTrue);
      expect(trace.fallbackReason, NluSkipReason.unsupportedFields);
      expect(h.context.respiratorySession.breathlessness,
          isNot(RespiratoryTriState.present),
          reason: plan.message);
      h.expectTrustedChildFacts(plan.message);
    });

    test('J — الرد النهائي من مخطِّط غدير لا من النموذج', () async {
      final fake = FakeNluClient(response: _nluParse());
      final h = _Harness(nluClient: fake);
      await h.reachDangerQuestion();
      final plan = await h.turn(_ambiguousIraqiContinuation);
      final trace = h.planner.lastNluTraceForTest!;
      expect(trace.responseCameFromPlanner, isTrue);
      expect(plan.message.trim(), isNotEmpty);
      expect(
        plan.message.contains('يومين') || plan.message.contains('سعال الطفل'),
        isTrue,
        reason: plan.message,
      );
      expect(plan.message.contains('التهاب رئوي'), isFalse);
      expect(plan.message.contains('ابدأ مضاد'), isFalse);
      expect(
        h.context.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.respiratory,
      );
      expect(
        h.context.respiratorySession.lastQuestionKey == 'function' ||
            h.context.respiratorySession.lastRuleId != null ||
            plan.message.contains('ضيق'),
        isTrue,
        reason: 'الخطوة التالية من قواعد غدير: ${plan.message}',
      );
    });
  });
}

class _HangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }
}

class _ThrowingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException('synthetic_transport_failure');
  }
}
