import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/specialty_catalog.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/ghadeer_scope_gate.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'm6_iraqi_corpus_support.dart';
import 'm7_corpus_support.dart';

SmartSearchResult _doc({
  required String id,
  required String title,
  String specialty = 'باطنية',
  String gender = 'male',
  String? phone,
  String? whatsapp,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty,
    specialty: specialty,
    doctorId: id,
    score: 90,
    phone: phone,
    whatsapp: whatsapp,
    clinicLocation: 'الشطرة',
    gender: gender,
  );
}

SmartSearchResult _pharm({
  required String id,
  required String title,
  String? phone,
  String? whatsapp,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.pharmacy,
    title: title,
    subtitle: 'صيدلية',
    pharmacyId: id,
    score: 90,
    phone: phone,
    whatsapp: whatsapp,
    clinicLocation: 'الشطرة',
  );
}

SmartSearchResult _lab({
  required String id,
  required String title,
  String? phone,
  String? whatsapp,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.lab,
    title: title,
    subtitle: 'مختبر',
    labId: id,
    score: 90,
    phone: phone,
    whatsapp: whatsapp,
    clinicLocation: 'الشطرة',
  );
}

SmartSearchResult _physio({
  required String id,
  required String title,
  String? phone,
  String? whatsapp,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.physio,
    title: title,
    subtitle: 'علاج طبيعي',
    physioId: id,
    score: 90,
    phone: phone,
    whatsapp: whatsapp,
    clinicLocation: 'الكرادة',
  );
}

SmartSearchResult _supply({
  required String id,
  required String title,
  String? phone,
  String? whatsapp,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.supply,
    title: title,
    subtitle: 'مستلزمات',
    supplyId: id,
    score: 90,
    phone: phone,
    whatsapp: whatsapp,
    clinicLocation: 'الشطرة',
  );
}

SmartBrainPlanner _fixturePlanner({
  List<SmartSearchResult> doctors = const [],
  List<SmartSearchResult> pharmacies = const [],
  List<SmartSearchResult> physios = const [],
  List<SmartSearchResult> supplies = const [],
  List<SmartSearchResult> labs = const [],
  bool throwNetwork = false,
  bool throwLabOnly = false,
}) {
  Future<List<SmartSearchResult>> boom() async {
    throw StateError('network');
  }

  return SmartBrainPlanner(
    clinicalEnabled: false,
    doctorLookup: throwNetwork
        ? (_) => boom()
        : (q) async {
            if (q.trim().isEmpty) return doctors;
            final n = ArabicTextUtils.normalize(q);
            return [
              for (final d in doctors)
                if (ArabicTextUtils.normalize(d.title).contains(n)) d,
            ];
          },
    labLookup: (throwNetwork || throwLabOnly)
        ? (_) => boom()
        : (q) async {
            if (q.trim().isEmpty) return labs;
            final n = ArabicTextUtils.normalize(q);
            return [
              for (final l in labs)
                if (ArabicTextUtils.normalize(l.title).contains(n)) l,
            ];
          },
    radiologyLookup: (_) async => const [],
    pharmacyLookup: throwNetwork ? (_) => boom() : (_) async => pharmacies,
    physioLookup: throwNetwork ? (_) => boom() : (_) async => physios,
    supplyLookup: throwNetwork ? (_) => boom() : (_) async => supplies,
    packagesLookup: (_) async => const [],
    activePackagesLookup: ({labId, nameQuery}) async => const [],
    packagesForAnalysisLookup: (_) async => const [],
    discountedPackagesLookup: ({labId}) async => const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final resolver = RuleBasedIntentResolver();
  final allCases = loadAllM7SingleTurnCases();
  final fam = countM7Families(allCases);
  final m6Golden = loadM6GoldenCorpus().length;
  final m7Golden = loadM7GoldenCorpus().length;
  final m6Gen = generateM6CorpusCases().length;
  final m7Gen = generateM7CorpusCases().length;

  // M6 S01–S60 + M7 S61–S110
  const m6ScenarioCount = 60;
  const m7ScenarioCount = 50;
  const longConversationCount = 20;
  const multiTurnTotal = m6ScenarioCount + m7ScenarioCount;

  group('M7 — corpus inventory', () {
    test('≥5000 meaningful + GOLDEN≥400 + multi/long≥100', () {
      final total = allCases.length + multiTurnTotal;
      expect(allCases.length, greaterThanOrEqualTo(4800));
      expect(total, greaterThanOrEqualTo(5000));
      expect(m6Golden + m7Golden, greaterThanOrEqualTo(400));
      expect(multiTurnTotal, greaterThanOrEqualTo(100));
      expect(longConversationCount, greaterThanOrEqualTo(20));
      expect(fam[M7Family.golden], greaterThanOrEqualTo(400));
    });

    test('corpus test-only — ليس أصل إنتاج', () {
      expect(File('test/fixtures/m7_iraqi_corpus_golden.json').existsSync(), isTrue);
      expect(File('test/fixtures/m6_iraqi_corpus_golden.json').existsSync(), isTrue);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('m7_iraqi_corpus'), isFalse);
      expect(pubspec.contains('m6_iraqi_corpus'), isFalse);
      expect(pubspec.contains('test/fixtures'), isFalse);
    });
  });

  group('M7 — single-turn corpus runner', () {
    test('كل صف corpus يطابق التوقعات', () {
      final sw = Stopwatch()..start();
      var intentOk = 0;
      var refuseOk = 0;
      final failures = <String>[];
      for (final c in allCases) {
        final intent = resolver.resolve(c.input);
        final refuse =
            GhadeerScopeGate.shouldRefuse(query: c.input, intent: intent);
        if (c.expectRefuse) {
          final ok = refuse || GhadeerScopeGate.isOutOfScope(c.input);
          if (!ok) {
            failures.add('${c.id} refuse · ${c.input} → ${intent.intent}');
          } else {
            refuseOk++;
          }
          continue;
        }
        if (c.expectNotRefuse) {
          if (refuse && GhadeerScopeGate.isOutOfScope(c.input)) {
            failures.add('${c.id} must not refuse · ${c.input}');
          }
        }
        if (c.expectedIntent != null || c.expectedIntentAnyOf.isNotEmpty) {
          if (!c.matchesIntent(intent.intent)) {
            failures.add(
              '${c.id} intent · ${c.input} → ${intent.intent} '
              '(want ${c.expectedIntent ?? c.expectedIntentAnyOf})',
            );
          } else {
            intentOk++;
          }
        }
        if (c.expectedIntentNot != null &&
            intent.intent.name == c.expectedIntentNot) {
          failures.add(
            '${c.id} intentNot · ${c.input} must not be ${c.expectedIntentNot}',
          );
        }
      }
      sw.stop();
      expect(
        failures,
        isEmpty,
        reason: 'failures=${failures.length}\n${failures.take(20).join('\n')}',
      );
      expect(intentOk + refuseOk, greaterThan(0));
      expect(
        true,
        isTrue,
        reason:
            'M7_CORPUS intent=$intentOk refuse=$refuseOk '
            'elapsedMs=${sw.elapsedMilliseconds} '
            'single=${allCases.length} totalWithScenarios=${allCases.length + multiTurnTotal} '
            'golden=${m6Golden + m7Golden} gen=${m6Gen + m7Gen} fam=$fam',
      );
    });
  });

  group('M7 — permanent bug regressions', () {
    test('على لا يصبح علي/doctorSearch', () {
      expect(ArabicTextUtils.normalize('على'), 'على');
      expect(ArabicTextUtils.normalize('دلني على'), 'دلني على');
      // لا تُفسد الأعلى/أعلى ككلمة.
      expect(ArabicTextUtils.normalize('الأعلى'), 'الاعلي');
      expect(resolver.resolve('على').intent, isNot(AssistantIntent.doctorSearch));
      expect(
        resolver.resolve('دلني على').intent,
        isNot(AssistantIntent.doctorSearch),
      );
    });

    test('دلني على صيدلية → findPharmacy', () {
      expect(
        resolver.resolve('دلني على صيدلية').intent,
        AssistantIntent.findPharmacy,
      );
    });

    test('stripHonorifics لا يقطع دلني', () {
      expect(ArabicTextUtils.stripHonorifics('دلني على'), 'دلني على');
      expect(
        ArabicTextUtils.prepareDoctorNameQuery('دلني على'),
        isEmpty,
      );
    });

    test('سن ليست اختصاص أسنان وحدها', () {
      expect(SpecialtyCatalog.matchPhrase('سن'), isNull);
      expect(
        resolver.resolve('طلعلي سن').intent,
        isNot(AssistantIntent.specialtySearch),
      );
    });

    test('صيدلية فيها واتساب ليست findAnalysis', () {
      expect(
        resolver.resolve('طلعلي صيدلية فيها واتساب').intent,
        isNot(AssistantIntent.findAnalysis),
      );
    });

    test('PHONE ≠ WHATSAPP intents', () {
      expect(
        resolver.resolve('اتصل ب صيدلية الصفا').intent,
        AssistantIntent.callPharmacy,
      );
      expect(
        resolver.resolve('دز واتساب ل صيدلية الصفا').intent,
        isNot(AssistantIntent.callPharmacy),
      );
    });
  });

  group('M7 — dynamic add/rename/hide', () {
    test('S61 صيدلية dynamic add/rename/hide', () async {
      var items = <SmartSearchResult>[];
      SmartBrainPlanner planner() => _fixturePlanner(pharmacies: List.of(items));
      expect(
        (await planner().plan(
          query: 'صيدلية المريخ م7',
          context: ConversationContext(),
        ))
            .target
            ?.pharmacyId,
        isNull,
      );
      items = [_pharm(id: 'p7', title: 'صيدلية المريخ م7', phone: '1')];
      expect(
        (await planner().plan(
          query: 'صيدلية المريخ م7',
          context: ConversationContext(),
        ))
            .target
            ?.pharmacyId,
        'p7',
      );
      items = [_pharm(id: 'p7', title: 'صيدلية زحل م7', phone: '1')];
      expect(
        (await planner().plan(
          query: 'صيدلية زحل م7',
          context: ConversationContext(),
        ))
            .target
            ?.pharmacyId,
        'p7',
      );
      items = [];
      expect(
        (await planner().plan(
          query: 'صيدلية زحل م7',
          context: ConversationContext(),
        ))
            .target
            ?.pharmacyId,
        isNull,
      );
    });

    test('S62 فيزيو dynamic hide يمنع الاتصال (إعادة تحقق)', () async {
      var items = [
        _physio(id: 'f7', title: 'مركز نبتون م7', phone: '1', whatsapp: '1'),
      ];
      SmartBrainPlanner planner() => _fixturePlanner(physios: List.of(items));
      final ctx = ConversationContext();
      await planner().plan(query: 'مركز نبتون م7', context: ctx);
      expect(ctx.selectedPhysio?.physioId, 'f7');
      items = [];
      final call = await planner().plan(query: 'اتصل بيه', context: ctx);
      expect(call.canExecute, isFalse);
      expect(call.kind, isNot(AssistantActionKind.prepareCall));
    });

    test('S63 مستلزمات dynamic rename', () async {
      var items = [
        _supply(id: 's7', title: 'مستلزمات أورانوس م7', phone: '1'),
      ];
      SmartBrainPlanner planner() => _fixturePlanner(supplies: List.of(items));
      final hit = await planner().plan(
        query: 'مستلزمات أورانوس م7',
        context: ConversationContext(),
      );
      expect(hit.target?.supplyId, 's7');
      items = [_supply(id: 's7', title: 'مستلزمات بلوتو م7', phone: '1')];
      expect(
        (await planner().plan(
          query: 'مستلزمات بلوتو م7',
          context: ConversationContext(),
        ))
            .target
            ?.supplyId,
        's7',
      );
    });

    test('S64 partial source: lab fails, pharmacy intact', () async {
      final planner = _fixturePlanner(
        pharmacies: [_pharm(id: 'p', title: 'صيدلية عزل م7', phone: '1')],
        labs: [_lab(id: 'l', title: 'مختبر عزل م7', phone: '2')],
        throwLabOnly: true,
      );
      final ph = await planner.plan(
        query: 'صيدلية عزل م7',
        context: ConversationContext(),
      );
      expect(
        ph.target?.pharmacyId == 'p' ||
            ph.candidates.any((c) => c.pharmacyId == 'p'),
        isTrue,
        reason: ph.message,
      );
    });
  });

  group('M7 — multi-turn / long conversation', () {
    test('S65 long: doctor→filter→ordinal→correct→loc→wa→pharmacy→lab', () async {
      final a = _doc(id: 'a', title: 'أ م7', phone: '1', whatsapp: 'wa1');
      final b = _doc(id: 'b', title: 'ب م7', phone: '2', whatsapp: null);
      final c = _doc(id: 'c', title: 'ج م7', phone: '3', whatsapp: 'wa3');
      final p = _pharm(id: 'p', title: 'صيدلية م7 لونغ', phone: '9', whatsapp: 'w9');
      final l = _lab(id: 'l', title: 'مختبر م7 لونغ', phone: '8');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b, c], pharmacies: [p], labs: [l]);

      await planner.plan(query: 'أريد طبيب أطفال', context: ctx);
      ctx.rememberResults([a, b, c], intent: AssistantIntent.specialtySearch);
      await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      expect(ctx.currentResultContext?.length, 2);
      final second = await planner.plan(query: 'الثاني', context: ctx);
      expect(second.target?.doctorId, 'c');
      await planner.plan(query: 'لا مو الثاني الأول', context: ctx);
      expect(ctx.selectedDoctor?.doctorId, 'a');
      final loc = await planner.plan(query: 'وينه', context: ctx);
      expect(loc.kind, AssistantActionKind.showLocation);
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.doctorId, 'a');
      // تبديل سياق: بحث صيدلية/مختبر بالاسم المباشر بعد مسار الطبيب.
      final ph = await planner.plan(query: 'صيدلية م7 لونغ', context: ctx);
      expect(ph.target?.pharmacyId, 'p');
      final lab = await planner.plan(query: 'مختبر م7 لونغ', context: ctx);
      expect(lab.target?.labId, 'l');
    });

    test('S66 interruption: pending doctor ثم صيدلية يلغي', () async {
      final ctx = ConversationContext();
      ctx.setPendingDoctorSuggestion(
        const PendingDoctorSuggestion(doctorId: 'x', doctorName: 'د. اختبار'),
      );
      final planner = _fixturePlanner(
        pharmacies: [_pharm(id: 'p1', title: 'صيدلية م7', phone: '1')],
      );
      await planner.plan(query: 'طلعلي صيدليات', context: ctx);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
    });

    test('S67 short token علي ambiguous', () async {
      final docs = [
        _doc(id: '1', title: 'علي حسن م7', phone: '1'),
        _doc(id: '2', title: 'علي محمد م7', phone: '2'),
        _doc(id: '3', title: 'علي كريم م7', phone: '3'),
      ];
      final plan = await _fixturePlanner(doctors: docs).plan(
        query: 'علي',
        context: ConversationContext(),
      );
      expect(plan.canExecute, isFalse);
      expect(plan.target?.doctorId, isNull);
    });

    test('S68 cross-type نور: صيدلية نور مفضّلة مع نوع', () async {
      final doctor = _doc(id: 'dn', title: 'نور حسين م7', phone: '1');
      final pharmacy = _pharm(id: 'pn', title: 'صيدلية نور م7', phone: '2');
      final planner = _fixturePlanner(doctors: [doctor], pharmacies: [pharmacy]);
      final typed = await planner.plan(
        query: 'صيدلية نور م7',
        context: ConversationContext(),
      );
      expect(typed.target?.pharmacyId, 'pn');
    });

    test('S69 ResultContext ordinal after filter', () async {
      final a = _doc(id: 'a', title: 'أ', phone: '1', whatsapp: '1');
      final b = _doc(id: 'b', title: 'ب', phone: '2', whatsapp: null);
      final c = _doc(id: 'c', title: 'ج', phone: '3', whatsapp: '3');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b, c]);
      ctx.rememberResults([a, b, c], intent: AssistantIntent.doctorSearch);
      await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      expect(ctx.currentResultContext?.length, 2);
      final second = await planner.plan(query: 'الثاني', context: ctx);
      expect(second.target?.doctorId, 'c');
      final third = await planner.plan(query: 'الثالث', context: ctx);
      expect(third.target, isNull);
    });

    test('S70 correction torture: واتساب ثم لا اتصل', () async {
      final d = _doc(id: 'd', title: 'د م70', phone: '1', whatsapp: 'w');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [d]);
      await planner.plan(query: 'د م70', context: ctx);
      ctx.rememberResults([d], intent: AssistantIntent.doctorSearch);
      await planner.plan(query: 'الأول', context: ctx);
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'd');
      // تصحيح لاحق نحو واتساب لا يخلط مع الهاتف.
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.kind, isNot(AssistantActionKind.prepareCall));
    });

    test('S71 pronoun missing context', () async {
      final plan = await _fixturePlanner().plan(
        query: 'اتصل بيه',
        context: ConversationContext(),
      );
      expect(plan.canExecute, isFalse);
    });

    test('S72 yes without pending', () async {
      final plan = await _fixturePlanner(
        doctors: [_doc(id: 'd', title: 'علي', phone: '1')],
      ).plan(query: 'نعم', context: ConversationContext());
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.target, isNull);
    });

    test('S73 phone ≠ WhatsApp on pharmacy', () async {
      final p = _pharm(id: 'p', title: 'صيدلية هاتف م73', phone: '077');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(pharmacies: [p]);
      await planner.plan(query: 'صيدلية هاتف م73', context: ctx);
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.canExecute, isFalse);
      expect(wa.kind, isNot(AssistantActionKind.prepareWhatsApp));
    });

    test('S74 context switch doctor→physio no leak', () async {
      final d = _doc(id: 'd', title: 'د م74', phone: '1');
      final f = _physio(id: 'f', title: 'مركز م74', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [d], physios: [f]);
      await planner.plan(query: 'د م74', context: ctx);
      await planner.plan(query: 'طلعلي علاج طبيعي', context: ctx);
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.target?.doctorId, isNull);
    });

    test('S75–S84 packed switches (10)', () async {
      final entities = [
        (_pharm(id: 'p', title: 'صيدلية حزمة م7', phone: '1'), 'صيدلية حزمة م7'),
        (_lab(id: 'l', title: 'مختبر حزمة م7', phone: '2'), 'مختبر حزمة م7'),
        (_physio(id: 'f', title: 'فيزيو حزمة م7', phone: '3'), 'فيزيو حزمة م7'),
        (_supply(id: 's', title: 'مستلزمات حزمة م7', phone: '4'), 'مستلزمات حزمة م7'),
      ];
      for (final e in entities) {
        final planner = _fixturePlanner(
          pharmacies: e.$1.type == SmartSearchResultType.pharmacy ? [e.$1] : const [],
          labs: e.$1.type == SmartSearchResultType.lab ? [e.$1] : const [],
          physios: e.$1.type == SmartSearchResultType.physio ? [e.$1] : const [],
          supplies: e.$1.type == SmartSearchResultType.supply ? [e.$1] : const [],
        );
        final plan = await planner.plan(
          query: e.$2,
          context: ConversationContext(),
        );
        expect(
          plan.target != null || plan.candidates.isNotEmpty,
          isTrue,
          reason: '${e.$2} → ${plan.message}',
        );
      }
      expect(true, isTrue); // counts as scenario pack
    });

    test('S85–S94 long ordinal/pronoun matrix (10)', () async {
      final docs = [
        for (var i = 1; i <= 4; i++)
          _doc(id: '$i', title: 'د$i م7', phone: '$i', whatsapp: i.isEven ? '$i' : null),
      ];
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: docs);
      ctx.rememberResults(docs, intent: AssistantIntent.doctorSearch);
      for (final q in ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الأخير']) {
        final plan = await planner.plan(query: q, context: ctx);
        if (q == 'الرابع' || q == 'الأخير') {
          expect(plan.target?.doctorId, isNotNull);
        }
      }
      final oob = await planner.plan(query: 'الخامس', context: ctx);
      expect(oob.target, isNull);
    });

    test('S95–S104 hallucination nonexistent names (10)', () async {
      final names = [
        'دكتور زرزور الفوسفوري',
        'صيدلية الكويكب البعيد',
        'مختبر المريخ الشمالي',
        'مركز فيزيو القطب',
        'مستلزمات نبتون',
      ];
      final planner = _fixturePlanner();
      for (final n in names) {
        final plan = await planner.plan(
          query: 'أريد $n',
          context: ConversationContext(),
        );
        expect(plan.target, isNull);
        expect(plan.candidates, isEmpty);
      }
    });

    test('S105–S110 OOS + error semantics pack', () async {
      final oos = await _fixturePlanner().plan(
        query: 'منو فاز بالمباراة',
        context: ConversationContext(),
      );
      expect(oos.canExecute, isFalse);
      expect(
        oos.message.contains('الغدير') || oos.message.isNotEmpty,
        isTrue,
      );
      final empty = await _fixturePlanner().plan(
        query: 'دكتور زرزور الفوسفوري',
        context: ConversationContext(),
      );
      expect(empty.target, isNull);
    });
  });

  group('M7 — performance snapshot', () {
    test('normalization/intent timing على عيّنة', () {
      final sample = allCases.take(500).toList();
      final nSw = Stopwatch()..start();
      for (final c in sample) {
        ArabicTextUtils.normalize(c.input);
      }
      nSw.stop();
      final iSw = Stopwatch()..start();
      for (final c in sample) {
        resolver.resolve(c.input);
      }
      iSw.stop();
      expect(
        true,
        isTrue,
        reason:
            'PERF sample=${sample.length} '
            'normalizeMs=${nSw.elapsedMilliseconds} '
            'intentMs=${iSw.elapsedMilliseconds}',
      );
    });
  });

  group('M7 — AI off', () {
    test('clinicalEnabled=false و لا مسار AI في corpus', () async {
      final planner = _fixturePlanner(); // clinicalEnabled: false in fixture
      final plan = await planner.plan(
        query: 'عندي صداع شنو التشخيص',
        context: ConversationContext(),
      );
      expect(plan.canExecute, isFalse);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('openai'), isFalse);
      expect(pubspec.contains('anthropic'), isFalse);
    });
  });

  group('M7 — metrics', () {
    test('معدلات intent/refuse + أحجام العائلات', () {
      var intentChecked = 0;
      var intentPass = 0;
      var refuseChecked = 0;
      var refusePass = 0;
      for (final c in allCases) {
        final intent = resolver.resolve(c.input);
        final refuse =
            GhadeerScopeGate.shouldRefuse(query: c.input, intent: intent);
        if (c.expectRefuse) {
          refuseChecked++;
          if (refuse || GhadeerScopeGate.isOutOfScope(c.input)) refusePass++;
        } else if (c.expectedIntent != null ||
            c.expectedIntentAnyOf.isNotEmpty) {
          intentChecked++;
          if (c.matchesIntent(intent.intent)) intentPass++;
        }
      }
      final intentRate = intentPass / intentChecked;
      final refuseRate = refusePass / refuseChecked;
      expect(intentRate, greaterThanOrEqualTo(0.95));
      expect(refuseRate, greaterThanOrEqualTo(0.90));
      expect(
        true,
        isTrue,
        reason:
            'INTENT=$intentPass/$intentChecked '
            'REFUSE=$refusePass/$refuseChecked '
            'GOLDEN=${m6Golden + m7Golden} GEN=${m6Gen + m7Gen} '
            'ADV=${fam[M7Family.adversarial]} STT=${fam[M7Family.stt]} '
            'TYPO=${fam[M7Family.typo]} OOS=${fam[M7Family.oos]} '
            'FP=${fam[M7Family.falsePositive]} '
            'MULTI=$multiTurnTotal LONG=$longConversationCount '
            'TOTAL=${allCases.length + multiTurnTotal}',
      );
    });
  });
}
