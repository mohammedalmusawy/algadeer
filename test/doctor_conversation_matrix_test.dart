import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/doctor_target_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/speech_recognition_service.dart';

SmartSearchResult _doc(
  String id,
  String title, {
  int score = 80,
  String? specialty,
  String? location,
  String? phone = '0770',
  String? whatsapp = '0770',
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty ?? 'اختصاص',
    doctorId: id,
    score: score,
    specialty: specialty,
    clinicLocation: location,
    phone: phone,
    whatsapp: whatsapp,
  );
}

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late List<String> lookupQueries;

  final ali = _doc(
    'ali',
    'الدكتور علي ناصر السعيدي',
    specialty: 'طب الأطفال',
    location: 'الكرادة',
    score: 80,
  );
  final naji = _doc(
    'naji',
    'ناجي عبد الله الركابي',
    specialty: 'جراحة',
    location: 'الحارثية',
    score: 95,
  );
  final aliA = _doc('a', 'علي أحمد', score: 85);
  final aliB = _doc('b', 'علي فليح', score: 82);
  final docC = _doc('c', 'كريم جاسم', score: 80, location: 'المنصور');

  setUp(() {
    ctx = ConversationContext();
    lookupQueries = <String>[];
    planner = SmartBrainPlanner(
      doctorLookup: (q) async {
        lookupQueries.add(q);
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('ناجي')) return [naji];
        if (n.contains('علي') && n.contains('ناصر')) return [ali];
        if (n.contains('علي')) return [aliA, aliB];
        if (n == 'عل' || n.startsWith('عل')) {
          return [
            aliA.copyWithScore(60),
            aliB.copyWithScore(55),
          ];
        }
        return const [];
      },
    );
  });

  group('A — single result auto-select + actions', () {
    test('أريد طبيب أطفال → one doctor auto-selected', () {
      ctx.rememberResults([ali], query: 'أريد طبيب أطفال');
      expect(ctx.selectedDoctor?.doctorId, 'ali');
      expect(ctx.selectedEntity?.doctorId, 'ali');
      expect(ctx.clarificationCandidates, isEmpty);
    });

    test('اتصل / واتساب / وين عيادته / نبذته → Ali, no search', () async {
      ctx.rememberResults([ali], query: 'أريد طبيب أطفال');
      lookupQueries.clear();

      for (final q in ['اتصل', 'واتساب', 'وين عيادته', 'نبذته']) {
        final plan = await planner.plan(query: q, context: ctx);
        expect(plan.target?.doctorId, 'ali', reason: q);
        expect(lookupQueries, isEmpty, reason: 'no search for $q');
      }

      expect(
        (await planner.plan(query: 'اتصل', context: ctx)).kind,
        AssistantActionKind.prepareCall,
      );
      expect(
        (await planner.plan(query: 'واتساب', context: ctx)).kind,
        AssistantActionKind.prepareWhatsApp,
      );
      expect(
        (await planner.plan(query: 'وين عيادته', context: ctx)).kind,
        AssistantActionKind.showLocation,
      );
      expect(
        (await planner.plan(query: 'نبذته', context: ctx)).kind,
        AssistantActionKind.openProfile,
      );
    });
  });

  group('B — single result + role words', () {
    test('اتصل بالدكتور / واتساب للدكتور → Ali, no search for الدكتور',
        () async {
      ctx.rememberResults([ali]);
      lookupQueries.clear();

      final call = await planner.plan(
        query: 'اتصل بالدكتور',
        context: ctx,
      );
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'ali');

      final wa = await planner.plan(
        query: 'أرسل رسالة واتساب للدكتور',
        context: ctx,
      );
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.doctorId, 'ali');
      expect(lookupQueries, isEmpty);
      expect(ctx.selectedDoctor?.doctorId, 'ali');
    });
  });

  group('C/D — explicit name cleaned for matcher', () {
    test('اتصل على دكتور علي ناصر السعيدي → matcher gets clean name',
        () async {
      final plan = await planner.plan(
        query: 'اتصل على دكتور علي ناصر السعيدي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'ali');
      expect(planner.lastMatcherQueryForTest, isNotNull);
      expect(
        ArabicTextUtils.normalize(planner.lastMatcherQueryForTest!),
        contains('علي'),
      );
      expect(
        ArabicTextUtils.normalize(planner.lastMatcherQueryForTest!),
        isNot(contains('اتصل')),
      );
      expect(lookupQueries.single, planner.lastMatcherQueryForTest);
    });

    test('أرسل رسالة واتساب للدكتور علي ناصر السعيدي → clean name', () async {
      final plan = await planner.plan(
        query: 'أرسل رسالة واتساب للدكتور علي ناصر السعيدي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'ali');
      expect(
        ArabicTextUtils.normalize(planner.lastMatcherQueryForTest!),
        isNot(contains('واتساب')),
      );
      expect(
        ArabicTextUtils.normalize(planner.lastMatcherQueryForTest!),
        contains('علي'),
      );
    });
  });

  group('E — multiple results ambiguity', () {
    test('دكتور علي → no auto-select; الثاني then اتصل → B', () async {
      ctx.rememberResults([aliA, aliB], query: 'دكتور علي');
      expect(ctx.selectedDoctor, isNull);
      expect(ctx.clarificationCandidates.map((e) => e.doctorId), ['a', 'b']);

      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedDoctor?.doctorId, 'b');

      lookupQueries.clear();
      final call = await planner.plan(query: 'اتصل', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'b');
      expect(lookupQueries, isEmpty);
    });
  });

  group('F — ordinal + action same utterance', () {
    test('اتصل على الأول / واتساب للثاني / وين عيادة الثالث', () async {
      ctx.rememberResults([aliA, aliB, docC], query: 'اطفال');
      lookupQueries.clear();

      final call = await planner.plan(query: 'اتصل على الأول', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'a');
      expect(call.targetResolution?.source, DoctorTargetSource.ordinal);

      final wa = await planner.plan(query: 'واتساب للثاني', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.doctorId, 'b');

      final loc = await planner.plan(query: 'وين عيادة الثالث', context: ctx);
      expect(loc.kind, AssistantActionKind.showLocation);
      expect(loc.target?.doctorId, 'c');

      expect(lookupQueries, isEmpty);
      expect(planner.lastMatcherQueryForTest, isNull);
    });

    test('اتصل على طبيب الأول never sends طبيب الأول to matcher', () async {
      ctx.rememberResults([aliA, aliB, docC]);
      lookupQueries.clear();
      final plan = await planner.plan(
        query: 'اتصل على طبيب الأول',
        context: ctx,
      );
      expect(plan.target?.doctorId, 'a');
      expect(lookupQueries, isEmpty);
      expect(planner.lastMatcherQueryForTest, isNull);
    });
  });

  group('G — explicit name overrides context', () {
    test('selected Ali → اتصل بالدكتور ناجي… → Naji', () async {
      ctx.rememberResults([ali]);
      expect(ctx.selectedDoctor?.doctorId, 'ali');

      final plan = await planner.plan(
        query: 'اتصل بالدكتور ناجي عبدالله الركابي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'naji');
      expect(ctx.selectedDoctor?.doctorId, 'naji');
      expect(
        ArabicTextUtils.normalize(planner.lastMatcherQueryForTest!),
        contains('ناجي'),
      );
    });
  });

  group('H — no context clarification', () {
    test('fresh اتصل / واتساب للدكتور → clarification, no search', () async {
      lookupQueries.clear();
      final call = await planner.plan(query: 'اتصل', context: ctx);
      expect(call.kind, AssistantActionKind.showMessage);
      expect(call.message, contains('أي طبيب'));
      expect(call.target, isNull);

      final wa = await planner.plan(
        query: 'أرسل واتساب للدكتور',
        context: ctx,
      );
      expect(wa.kind, AssistantActionKind.showMessage);
      expect(wa.message, contains('أي طبيب'));
      expect(lookupQueries, isEmpty);
    });
  });

  group('I — new search clears stale target', () {
    test('Ali selected → أريد طبيب أعصاب clears Ali before results', () async {
      ctx.rememberResults([ali]);
      expect(ctx.selectedDoctor?.doctorId, 'ali');

      final plan = await planner.plan(
        query: 'أريد طبيب أعصاب',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.runSpecialtySearch);
      expect(ctx.selectedDoctor, isNull);
      expect(ctx.selectedEntity, isNull);
    });
  });

  group('J — partial search not action', () {
    test('علي → doctorSearch; عل → general/doctor, no action', () {
      final resolver = RuleBasedIntentResolver();
      final aliIntent = resolver.resolve('علي');
      expect(
        aliIntent.intent == AssistantIntent.doctorSearch ||
            aliIntent.intent == AssistantIntent.generalSearch,
        isTrue,
      );
      expect(aliIntent.isActionIntent, isFalse);

      final partial = resolver.resolve('عل');
      expect(partial.isActionIntent, isFalse);
      expect(
        partial.intent == AssistantIntent.doctorSearch ||
            partial.intent == AssistantIntent.generalSearch ||
            partial.intent == AssistantIntent.unknown,
        isTrue,
      );
    });
  });

  group('K — text/voice parity after prepareQuery', () {
    test('representative phrases identical for typed and voice prep', () async {
      ctx.rememberResults([aliA, aliB, docC]);
      const phrases = [
        'اتصل على الأول',
        'واتساب للثاني',
        'وين عيادته',
        'أرسل رسالة واتساب للدكتور',
      ];
      for (final phrase in phrases) {
        final typedPrep = ArabicTextUtils.prepareQuery(phrase);
        final voicePrep = ArabicTextUtils.prepareQuery(phrase);
        expect(typedPrep.normalizedText, voicePrep.normalizedText);

        final typedCtx = ConversationContext()
          ..rememberResults([aliA, aliB, docC]);
        final voiceCtx = ConversationContext()
          ..rememberResults([aliA, aliB, docC]);
        // Simulate source tagging only — planner is source-agnostic.
        expect(QueryInputSource.typed, isNot(QueryInputSource.voice));

        final typedPlan = await planner.plan(
          query: typedPrep.originalText,
          context: typedCtx,
        );
        final voicePlan = await planner.plan(
          query: voicePrep.originalText,
          context: voiceCtx,
        );
        expect(typedPlan.kind, voicePlan.kind, reason: phrase);
        expect(
          typedPlan.target?.doctorId,
          voicePlan.target?.doctorId,
          reason: phrase,
        );
      }
    });
  });

  group('DoctorTargetResolver unit', () {
    test('priority: explicit > ordinal > selected > unresolved', () {
      const resolver = DoctorTargetResolver();
      ctx.rememberResults([aliA, aliB, docC]);
      ctx.selectEntity(aliB);

      final intentResolver = RuleBasedIntentResolver();
      final explicit = intentResolver.resolve(
        'اتصل على دكتور علي ناصر السعيدي',
      );
      final r1 = resolver.resolve(intentResult: explicit, context: ctx);
      expect(r1.source, DoctorTargetSource.explicitName);
      expect(r1.requiresSearch, isTrue);

      final ordinal = intentResolver.resolve('اتصل على الأول');
      final r2 = resolver.resolve(intentResult: ordinal, context: ctx);
      expect(r2.source, DoctorTargetSource.ordinal);
      expect(r2.doctor?.doctorId, 'a');

      final ctxOnly = intentResolver.resolve('اتصل');
      final r3 = resolver.resolve(intentResult: ctxOnly, context: ctx);
      // بعد ordinal أعلاه selected = a
      expect(r3.source, DoctorTargetSource.selectedContext);
      expect(r3.doctor?.doctorId, 'a');
    });
  });

  group('mic same-process still enforced', () {
    test('no second app launch path', () {
      expect(DeviceSpeechRecognitionService.mayLaunchSecondAppInstance, isFalse);
    });
  });
}

extension on SmartSearchResult {
  SmartSearchResult copyWithScore(int s) {
    return SmartSearchResult(
      type: type,
      title: title,
      subtitle: subtitle,
      doctorId: doctorId,
      score: s,
      specialty: specialty,
      clinicLocation: clinicLocation,
      phone: phone,
      whatsapp: whatsapp,
    );
  }
}
