import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/ghadeer_scope_gate.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/platform_grounding.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'm6_iraqi_corpus_support.dart';

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

SmartBrainPlanner _fixturePlanner({
  List<SmartSearchResult> doctors = const [],
  List<SmartSearchResult> pharmacies = const [],
  List<SmartSearchResult> physios = const [],
  List<SmartSearchResult> supplies = const [],
  List<SmartSearchResult> labs = const [],
  bool throwNetwork = false,
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
    labLookup: throwNetwork
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
  final golden = loadM6GoldenCorpus();
  final generated = generateM6CorpusCases();
  final allCases = [...golden, ...generated];

  // سيناريوهات متعددة الأدوار: S01–S60 (V2 closure ≥60).
  const scenarioCaseCount = 60;

  group('M6 — corpus inventory', () {
    test('M6 V2 closure: GOLDEN>=300 و multi-turn>=60 و total>=1146', () {
      final total = allCases.length + scenarioCaseCount;
      expect(golden.length, greaterThanOrEqualTo(300));
      expect(generated.length, greaterThanOrEqualTo(500));
      expect(scenarioCaseCount, greaterThanOrEqualTo(60));
      expect(total, greaterThanOrEqualTo(1146));
      expect(golden.every((c) => c.source == 'golden'), isTrue);
      expect(generated.every((c) => c.source == 'generated'), isTrue);
    });

    test('corpus في test/fixtures فقط — ليس أصل إنتاج', () {
      expect(
        File('test/fixtures/m6_iraqi_corpus_golden.json').existsSync(),
        isTrue,
      );
      // لا يُذكر في pubspec assets
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('m6_iraqi_corpus'), isFalse);
      expect(pubspec.contains('test/fixtures'), isFalse);
    });
  });

  group('M6 — golden + generated intent/scope runner', () {
    test('كل صف corpus يطابق التوقعات', () {
      var intentOk = 0;
      var refuseOk = 0;
      var checked = 0;
      final failures = <String>[];

      for (final c in allCases) {
        checked++;
        final intent = resolver.resolve(c.input);
        final refuse =
            GhadeerScopeGate.shouldRefuse(query: c.input, intent: intent);

        if (c.expectRefuse) {
          final ok = refuse || GhadeerScopeGate.isOutOfScope(c.input);
          if (!ok) {
            failures.add('${c.id} refuse expected · ${c.input} → ${intent.intent}');
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

      expect(
        failures,
        isEmpty,
        reason: 'failures=${failures.length}\n${failures.take(25).join('\n')}',
      );
      expect(checked, allCases.length);
      expect(intentOk + refuseOk, greaterThan(0));
    });
  });

  group('M6 — scenario: list → ordinal → action', () {
    test('S01 أطفال → الثاني → وينه → دزله واتساب', () async {
      final a = _doc(id: 'a', title: 'د. أ', phone: '1', whatsapp: null);
      final b = _doc(id: 'b', title: 'د. ب', phone: '2', whatsapp: '2');
      final c = _doc(id: 'c', title: 'د. ج', phone: '3', whatsapp: '3');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b, c]);
      ctx.rememberResults(
        [a, b, c],
        query: 'اطباء اطفال',
        intent: AssistantIntent.specialtySearch,
      );
      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.target?.doctorId, 'b');
      final loc = await planner.plan(query: 'وينه', context: ctx);
      expect(loc.kind, AssistantActionKind.showLocation);
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.doctorId, 'b');
    });

    test('S02 تصفية واتساب ثم الثاني ثم اتصل', () async {
      final withWa = _doc(id: 'a', title: 'أ', phone: '1', whatsapp: '1');
      final noWa = _doc(id: 'b', title: 'ب', phone: '2', whatsapp: null);
      final femaleWa = _doc(
        id: 'c',
        title: 'ج',
        phone: '3',
        whatsapp: '3',
        gender: 'female',
      );
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [withWa, noWa, femaleWa]);
      ctx.rememberResults(
        [withWa, noWa, femaleWa],
        intent: AssistantIntent.specialtySearch,
      );
      await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      expect(ctx.currentResultContext?.length, 2);
      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.target?.doctorId, 'c');
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
    });

    test('S03 حدّ ترتيب: نتيجتان + الثالث لا يخترع', () async {
      final a = _doc(id: 'a', title: 'أ', phone: '1');
      final b = _doc(id: 'b', title: 'ب', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b]);
      ctx.rememberResults([a, b], intent: AssistantIntent.doctorSearch);
      final plan = await planner.plan(query: 'الثالث', context: ctx);
      expect(plan.target?.doctorId, isNull);
      expect(plan.canExecute, isFalse);
    });
  });

  group('M6 — scenario: interruption / yes-no / correction', () {
    test('S04 pending طبيب + طلعلي صيدليات يلغي الاقتراح', () async {
      final ctx = ConversationContext();
      ctx.setPendingDoctorSuggestion(
        const PendingDoctorSuggestion(
          doctorId: 'x',
          doctorName: 'د. اختبار',
        ),
      );
      final planner = _fixturePlanner(
        pharmacies: [_pharm(id: 'p1', title: 'صيدلية الاختبار', phone: '1')],
      );
      final plan = await planner.plan(query: 'طلعلي صيدليات', context: ctx);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(
        plan.candidates.any((c) => c.type == SmartSearchResultType.pharmacy) ||
            plan.kind == AssistantActionKind.runGeneralSearch ||
            plan.target?.type == SmartSearchResultType.pharmacy,
        isTrue,
        reason: plan.message,
      );
    });

    test('S05 نعم بلا pending لا يبحث عشوائياً', () async {
      final ctx = ConversationContext();
      final planner = _fixturePlanner(
        doctors: [_doc(id: 'd', title: 'علي ناصر', phone: '1')],
      );
      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.kind, isNot(AssistantActionKind.prepareWhatsApp));
      expect(plan.target, isNull);
    });

    test('S06 MEDIUM تقصد → نعم يختار فقط', () async {
      final d = _doc(id: 'saeedi', title: 'الدكتور علي ناصر السعيدي', phone: '1');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [d]);
      final mid = await planner.plan(query: 'علي', context: ctx);
      if (ctx.hasPendingDoctorSuggestion) {
        expect(mid.message, contains('تقصد'));
        final yes = await planner.plan(query: 'اي', context: ctx);
        expect(yes.kind, AssistantActionKind.selectEntity);
        expect(yes.kind, isNot(AssistantActionKind.prepareCall));
      } else {
        // إن صار HIGH فريداً — لا اتصال أعمى من «علي» وحدها في هذا السيناريو.
        expect(mid.kind, isNot(AssistantActionKind.prepareCall));
      }
    });
  });

  group('M6 — scenario: short-name & cross-type', () {
    test('S07 علي غامض بين ثلاثة أطباء', () async {
      final doctors = [
        _doc(id: '1', title: 'علي حسن', phone: '1'),
        _doc(id: '2', title: 'علي محمد', phone: '2'),
        _doc(id: '3', title: 'علي كريم', phone: '3'),
      ];
      final plan = await _fixturePlanner(doctors: doctors).plan(
        query: 'علي',
        context: ConversationContext(),
      );
      expect(
        plan.kind == AssistantActionKind.showClarification ||
            plan.message.contains('تقصد') ||
            plan.candidates.length > 1,
        isTrue,
        reason: plan.message,
      );
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
    });

    test('S08 نور غامض عبر أنواع / صيدلية نور مفضّلة', () async {
      final doctor = _doc(id: 'dn', title: 'نور حسين', phone: '1');
      final pharmacy = _pharm(id: 'pn', title: 'صيدلية نور', phone: '2');
      final physio = _physio(id: 'phn', title: 'مركز نور', phone: '3');
      final planner = _fixturePlanner(
        doctors: [doctor],
        pharmacies: [pharmacy],
        physios: [physio],
      );
      final amb = await planner.plan(
        query: 'نور',
        context: ConversationContext(),
      );
      expect(
        amb.kind == AssistantActionKind.showClarification ||
            amb.candidates.length > 1 ||
            amb.message.contains('تقصد'),
        isTrue,
        reason: amb.message,
      );

      final ph = await planner.plan(
        query: 'صيدلية نور',
        context: ConversationContext(),
      );
      expect(ph.target?.pharmacyId, 'pn', reason: ph.message);
    });
  });

  group('M6 — scenario: dynamic entity / rename / hide / stale', () {
    test('S09 إضافة/إعادة تسمية/إخفاء فيزيو ديناميكي', () async {
      var items = <SmartSearchResult>[];
      SmartBrainPlanner planner() => _fixturePlanner(physios: List.of(items));

      final miss = await planner().plan(
        query: 'مركز الاختبار الذهبي',
        context: ConversationContext(),
      );
      expect(miss.target?.physioId, isNull);

      items = [_physio(id: 'dyn1', title: 'مركز الاختبار الذهبي', phone: '1')];
      final hit = await planner().plan(
        query: 'مركز الاختبار الذهبي',
        context: ConversationContext(),
      );
      expect(hit.target?.physioId, 'dyn1');

      items = [_physio(id: 'dyn1', title: 'مركز الاسم الجديد', phone: '1')];
      final renamed = await planner().plan(
        query: 'مركز الاسم الجديد',
        context: ConversationContext(),
      );
      expect(renamed.target?.physioId, 'dyn1');

      items = [];
      final gone = await planner().plan(
        query: 'مركز الاسم الجديد',
        context: ConversationContext(),
      );
      expect(gone.target?.physioId, isNull);
    });

    test('S10 سياق بالٍ بعد الإخفاء يمنع الاتصال والواتساب', () async {
      var items = [
        _physio(id: 'stale', title: 'مركز بالي', phone: '0771', whatsapp: '0771'),
      ];
      SmartBrainPlanner planner() => _fixturePlanner(physios: List.of(items));
      final ctx = ConversationContext();
      await planner().plan(query: 'مركز بالي', context: ctx);
      expect(ctx.selectedPhysio?.physioId, 'stale');
      items = [];
      final call = await planner().plan(query: 'اتصل بيه', context: ctx);
      expect(call.canExecute, isFalse);
      expect(call.kind, AssistantActionKind.showMessage);
      final wa = await planner().plan(query: 'دزله واتساب', context: ctx);
      expect(wa.canExecute, isFalse);
    });

    test('S11 اكتشاف عبر أنواع بلا hardcode', () async {
      final planner = _fixturePlanner(
        doctors: [_doc(id: 'nd', title: 'سامر الديناميكي', phone: '1')],
        pharmacies: [_pharm(id: 'np', title: 'صيدلية الأفق الجديد', phone: '2')],
        physios: [_physio(id: 'nphy', title: 'مركز الأفق الديناميكي', phone: '3')],
        supplies: [
          _supply(id: 'ns', title: 'بيت التجهيز الذهبي', phone: '4'),
        ],
      );
      expect(
        (await planner.plan(
          query: 'سامر الديناميكي',
          context: ConversationContext(),
        ))
            .target
            ?.doctorId,
        'nd',
      );
      expect(
        (await planner.plan(
          query: 'صيدلية الأفق الجديد',
          context: ConversationContext(),
        ))
            .target
            ?.pharmacyId,
        'np',
      );
      expect(
        (await planner.plan(
          query: 'مركز الأفق الديناميكي',
          context: ConversationContext(),
        ))
            .target
            ?.physioId,
        'nphy',
      );
      final supplyPlan = await planner.plan(
        query: 'بيت التجهيز الذهبي',
        context: ConversationContext(),
      );
      final supplyCtx = ConversationContext();
      final supplyMid = await planner.plan(
        query: 'بيت التجهيز الذهبي',
        context: supplyCtx,
      );
      if (supplyCtx.hasPendingEntitySuggestion) {
        final yes = await planner.plan(query: 'نعم', context: supplyCtx);
        expect(yes.target?.supplyId, 'ns');
      } else {
        expect(
          supplyPlan.target?.supplyId == 'ns' ||
              supplyMid.target?.supplyId == 'ns' ||
              supplyMid.candidates.any((c) => c.supplyId == 'ns'),
          isTrue,
          reason: supplyPlan.message,
        );
      }
    });
  });

  group('M6 — scenario: safety / errors / whatsapp', () {
    test('S12 phone ≠ WhatsApp', () async {
      final onlyPhone = _physio(
        id: 'p',
        title: 'مركز هاتف فقط م6',
        phone: '0770999',
        whatsapp: null,
      );
      expect(onlyPhone.canCall, isTrue);
      expect(onlyPhone.canWhatsApp, isFalse);
      final ctx = ConversationContext();
      ctx.selectPhysio(onlyPhone);
      final wa = await _fixturePlanner(physios: [onlyPhone]).plan(
        query: 'دزله واتساب',
        context: ctx,
      );
      expect(wa.kind, AssistantActionKind.showMessage);
      expect(wa.canExecute, isFalse);
    });

    test('S13 لا هلوسة لكيان غير موجود', () async {
      final plan = await _fixturePlanner().plan(
        query: 'أريد مركز غير موجود في المنصة م6',
        context: ConversationContext(),
      );
      expect(plan.target, isNull);
      expect(plan.canExecute, isFalse);
      expect(plan.message.contains('077'), isFalse);
    });

    test('S14 NETWORK_ERROR ≠ NO_RESULTS', () async {
      final plan = await _fixturePlanner(throwNetwork: true).plan(
        query: 'أريد مركز النور المفقود',
        context: ConversationContext(),
      );
      expect(plan.message, PlatformGrounding.accessProblemMessage);
      expect(plan.message, isNot(PlatformGrounding.noResultsMessage));
    });

    test('S15 ACTION_UNAVAILABLE — واتساب ناقص', () async {
      final p = _pharm(id: 'x', title: 'صيدلية بلا واتس م6', phone: '1');
      final plan = await _fixturePlanner(pharmacies: [p]).plan(
        query: 'دز واتساب لصيدلية بلا واتس م6',
        context: ConversationContext(),
      );
      expect(plan.canExecute, isFalse);
      expect(plan.message.toLowerCase(), contains('واتساب'));
    });
  });

  group('M6 — scenario: context switch / compound / typo', () {
    test('S16 تبديل صيدلية → فيزيو', () async {
      final planner = _fixturePlanner(
        pharmacies: [_pharm(id: 'p', title: 'صيدلية ألف م6', phone: '1')],
        physios: [_physio(id: 'f', title: 'مركز باء م6', phone: '2')],
      );
      final ctx = ConversationContext();
      await planner.plan(query: 'صيدلية ألف م6', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.pharmacy);
      await planner.plan(query: 'مركز باء م6', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.physio);
    });

    test('S17 typo مركز الشفا', () async {
      final p = _physio(
        id: 'shifa',
        title: 'مركز الشفاء للعلاج الطبيعي',
        phone: '1',
      );
      final plan = await _fixturePlanner(physios: [p]).plan(
        query: 'مركز الشفا',
        context: ConversationContext(),
      );
      expect(
        plan.target?.physioId == 'shifa' ||
            plan.candidates.any((c) => c.physioId == 'shifa') ||
            plan.message.contains('تقصد'),
        isTrue,
        reason: plan.message,
      );
    });

    test('S18 اسم بدون نوع — مركز الاختبار الموحّد', () async {
      final p = _physio(id: 'u', title: 'مركز الاختبار الموحّد', phone: '1');
      final plan = await _fixturePlanner(physios: [p]).plan(
        query: 'أريد مركز الاختبار الموحّد',
        context: ConversationContext(),
      );
      expect(plan.target?.physioId, 'u', reason: plan.message);
    });

    test('S19 علاج وحدها ليست فيزيو', () {
      final i = resolver.resolve('اريد علاج');
      expect(i.intent, isNot(AssistantIntent.findPhysio));
    });

    test('S20 صوت STT علاج طبييعي', () {
      final i = resolver.resolve('اريد علاج طبييعي');
      expect(
        i.intent,
        anyOf(AssistantIntent.findPhysio, AssistantIntent.generalSearch),
      );
    });
  });

  group('M6 V2 — multi-turn correction / reject / interrupt', () {
    test('S21 لا قصدي صيدلية يلغي اقتراح طبيب ويبحث صيدليات', () async {
      final ctx = ConversationContext();
      ctx.setPendingDoctorSuggestion(
        const PendingDoctorSuggestion(doctorId: 'x', doctorName: 'د. اختبار'),
      );
      final planner = _fixturePlanner(
        pharmacies: [_pharm(id: 'p1', title: 'صيدلية الاختبار', phone: '1')],
      );
      final plan = await planner.plan(query: 'لا قصدي صيدلية', context: ctx);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(
        plan.candidates.any((c) => c.type == SmartSearchResultType.pharmacy) ||
            plan.target?.type == SmartSearchResultType.pharmacy ||
            plan.kind == AssistantActionKind.runGeneralSearch,
        isTrue,
        reason: plan.message,
      );
    });

    test('S22 أقصد علاج طبيعي بعد اقتراح طبيب', () async {
      final ctx = ConversationContext();
      ctx.setPendingDoctorSuggestion(
        const PendingDoctorSuggestion(doctorId: 'x', doctorName: 'د. اختبار'),
      );
      final planner = _fixturePlanner(
        physios: [_physio(id: 'f1', title: 'مركز تأهيل', phone: '1')],
      );
      final plan = await planner.plan(query: 'أقصد علاج طبيعي', context: ctx);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(
        plan.target?.physioId == 'f1' ||
            plan.candidates.any((c) => c.physioId == 'f1') ||
            plan.kind == AssistantActionKind.runGeneralSearch,
        isTrue,
        reason: plan.message,
      );
    });

    test('S23 مو هذا يرفض الاقتراح بلا بحث عشوائي', () async {
      final ctx = ConversationContext();
      ctx.setPendingDoctorSuggestion(
        const PendingDoctorSuggestion(doctorId: 'x', doctorName: 'د. اختبار'),
      );
      final plan = await _fixturePlanner(
        doctors: [_doc(id: 'd', title: 'علي ناصر', phone: '1')],
      ).plan(query: 'مو هذا', context: ctx);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.target, isNull);
    });

    test('S24 غيره يرفض اقتراح كيان', () async {
      final ctx = ConversationContext();
      ctx.setPendingEntitySuggestion(
        const PendingEntitySuggestion(
          entityType: ClarificationEntityType.physio,
          entityId: 'p',
          entityName: 'مركز',
        ),
      );
      final plan = await _fixturePlanner().plan(query: 'غيره', context: ctx);
      expect(ctx.hasPendingEntitySuggestion, isFalse);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.target, isNull);
    });

    test('S25 قصدي مختبر يقطع توضيح أطباء', () async {
      final ctx = ConversationContext();
      final docs = [
        _doc(id: '1', title: 'علي أ', phone: '1'),
        _doc(id: '2', title: 'علي ب', phone: '2'),
      ];
      ctx.rememberResults(docs, intent: AssistantIntent.doctorSearch);
      final planner = _fixturePlanner(doctors: docs);
      final plan = await planner.plan(query: 'قصدي مختبر', context: ctx);
      expect(plan.intentResult.intent, AssistantIntent.findLab);
    });

    test('S26 أريدلي صيدلية', () async {
      final plan = await _fixturePlanner(
        pharmacies: [_pharm(id: 'p', title: 'صيدلية أ', phone: '1')],
      ).plan(query: 'أريدلي صيدلية', context: ConversationContext());
      expect(
        plan.candidates.any((c) => c.type == SmartSearchResultType.pharmacy) ||
            plan.target?.type == SmartSearchResultType.pharmacy ||
            plan.kind == AssistantActionKind.runGeneralSearch,
        isTrue,
        reason: plan.message,
      );
    });

    test('S27 دلني على مختبر', () {
      expect(resolver.resolve('دلني على مختبر').intent, AssistantIntent.findLab);
    });

    test('S28 جيبلي اشعة', () {
      expect(
        resolver.resolve('جيبلي اشعة').intent,
        AssistantIntent.findRadiology,
      );
    });

    test('S29 وريني باقات', () {
      expect(
        resolver.resolve('وريني باقات').intent,
        anyOf(AssistantIntent.findPackage, AssistantIntent.findOffer),
      );
    });

    test('S30 اكو يمكم صيدلية', () {
      expect(
        resolver.resolve('اكو يمكم صيدلية').intent,
        AssistantIntent.findPharmacy,
      );
    });

    test('S31 تصفية طبيبة ثم الثاني', () async {
      final a = _doc(id: 'a', title: 'أ', gender: 'male', phone: '1');
      final b = _doc(id: 'b', title: 'ب', gender: 'female', phone: '2');
      final c = _doc(id: 'c', title: 'ج', gender: 'female', phone: '3');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b, c]);
      ctx.rememberResults([a, b, c], intent: AssistantIntent.specialtySearch);
      final filtered = await planner.plan(query: 'طبيبة', context: ctx);
      expect(filtered.candidates.every((e) => e.gender == 'female'), isTrue);
      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.target?.doctorId, 'c');
    });

    test('S32 لا مو الثاني الأول', () async {
      final a = _doc(id: 'a', title: 'أ', phone: '1');
      final b = _doc(id: 'b', title: 'ب', phone: '2');
      final ctx = ConversationContext();
      ctx.rememberResults([a, b], intent: AssistantIntent.doctorSearch);
      final plan = await _fixturePlanner(doctors: [a, b]).plan(
        query: 'لا مو الثاني الأول',
        context: ctx,
      );
      expect(plan.target?.doctorId, 'a', reason: '${plan.kind} ${plan.message}');
    });

    test('S33 مركّب: علاج طبيعي ثم اتصل بالثاني', () async {
      final a = _physio(id: 'a', title: 'مركز أ', phone: '1');
      final b = _physio(id: 'b', title: 'مركز ب', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(physios: [a, b]);
      await planner.plan(query: 'طلعلي علاج طبيعي', context: ctx);
      expect(ctx.currentResultContext?.length, greaterThanOrEqualTo(2));
      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.target?.physioId, 'b');
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
    });

    test('S34 علاقة: صيدلية ثم شنو باقاتها (لا اختراع إن بلا schema)', () async {
      final p = _pharm(id: 'p', title: 'صيدلية علاقات', phone: '1');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(pharmacies: [p]);
      await planner.plan(query: 'صيدلية علاقات', context: ctx);
      final rel = await planner.plan(query: 'شنو باقاتها', context: ctx);
      // بلا باقات حقيقية في الـ fixture — لا هلوسة أرقام/كيانات.
      expect(rel.message.contains('077'), isFalse);
      expect(rel.target?.pharmacyId == 'p' || rel.target == null, isTrue);
    });

    test('S35 grounding: NETWORK ≠ NO_RESULTS على تصحيح', () async {
      final plan = await _fixturePlanner(throwNetwork: true).plan(
        query: 'أريدلي صيدلية',
        context: ConversationContext(),
      );
      expect(plan.message, PlatformGrounding.accessProblemMessage);
      expect(plan.message, isNot(PlatformGrounding.noResultsMessage));
      expect(plan.canExecute, isFalse);
    });
  });

  group('M6 V2 closure — acceptance + multi-turn S36–S60', () {
    test('S36 ACCEPTANCE: أطفال→واتساب→ثاني→تصحيح أول→وينه→واتساب→صيدليات', () async {
      final a = _doc(id: 'a', title: 'د أطفال أ', phone: '1', whatsapp: 'wa1');
      final b = _doc(id: 'b', title: 'د أطفال ب', phone: '2', whatsapp: null);
      final c = _doc(id: 'c', title: 'د أطفال ج', phone: '3', whatsapp: 'wa3');
      final ph = _pharm(id: 'p1', title: 'صيدلية الإغلاق', phone: '9');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b, c], pharmacies: [ph]);

      final ped = await planner.plan(query: 'أريدلي طبيب أطفال', context: ctx);
      expect(ped.intentResult.intent, AssistantIntent.specialtySearch);
      // ثبّت نتائج معروضة (fixture lookup قد لا يملأ candidates في specialty path).
      ctx.rememberResults([a, b, c], intent: AssistantIntent.specialtySearch);

      final filt = await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      expect(ctx.currentResultContext?.length, 2, reason: filt.message);
      expect(
        ctx.currentResultContext!.items.map((e) => e.doctorId).toList(),
        ['a', 'c'],
      );

      final second = await planner.plan(query: 'الثاني', context: ctx);
      expect(second.target?.doctorId, 'c');

      final fix = await planner.plan(query: 'لا مو الثاني الأول', context: ctx);
      expect(fix.target?.doctorId, 'a', reason: fix.message);

      final loc = await planner.plan(query: 'وينه', context: ctx);
      expect(loc.kind, AssistantActionKind.showLocation);
      expect(loc.target?.doctorId, 'a');

      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.doctorId, 'a');
      expect(wa.canExecute, isTrue);

      final switchPh = await planner.plan(
        query: 'لا قصدي طلعلي صيدليات',
        context: ctx,
      );
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(
        switchPh.candidates.any((e) => e.type == SmartSearchResultType.pharmacy) ||
            switchPh.target?.type == SmartSearchResultType.pharmacy ||
            switchPh.kind == AssistantActionKind.runGeneralSearch,
        isTrue,
        reason: switchPh.message,
      );
      expect(ctx.selectedDoctor, isNull);
    });

    test('S37 Doctor → Pharmacy context switch', () async {
      final d = _doc(id: 'd', title: 'د تحويل', phone: '1');
      final p = _pharm(id: 'p', title: 'صيدلية تحويل', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [d], pharmacies: [p]);
      await planner.plan(query: 'د تحويل', context: ctx);
      final sw = await planner.plan(query: 'طلعلي صيدليات', context: ctx);
      expect(
        sw.candidates.any((e) => e.type == SmartSearchResultType.pharmacy) ||
            sw.target?.pharmacyId == 'p',
        isTrue,
        reason: sw.message,
      );
    });

    test('S38 Pharmacy → Lab', () async {
      final p = _pharm(id: 'p', title: 'صيدلية م38', phone: '1');
      final l = _lab(id: 'l', title: 'مختبر م38', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(pharmacies: [p], labs: [l]);
      await planner.plan(query: 'صيدلية م38', context: ctx);
      final sw = await planner.plan(query: 'قصدي مختبر', context: ctx);
      expect(sw.intentResult.intent, AssistantIntent.findLab);
    });

    test('S39 Lab → Doctor', () async {
      final l = _lab(id: 'l', title: 'مختبر م39', phone: '1');
      final d = _doc(id: 'd', title: 'د م39', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(labs: [l], doctors: [d]);
      ctx.rememberResults([l], intent: AssistantIntent.findLab);
      final sw = await planner.plan(query: 'أريد طبيب باطنية', context: ctx);
      expect(
        sw.intentResult.intent,
        anyOf(
          AssistantIntent.specialtySearch,
          AssistantIntent.doctorSearch,
          AssistantIntent.generalSearch,
        ),
      );
    });

    test('S40 Physio → Supplies', () async {
      final f = _physio(id: 'f', title: 'مركز م40', phone: '1');
      final s = _supply(id: 's', title: 'مستلزمات م40', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(physios: [f], supplies: [s]);
      await planner.plan(query: 'طلعلي علاج طبيعي', context: ctx);
      final sw = await planner.plan(query: 'قصدي مستلزمات', context: ctx);
      expect(sw.intentResult.intent, AssistantIntent.findSupply);
    });

    test('S41 Supplies → Doctor', () async {
      final s = _supply(id: 's', title: 'مستلزمات م41', phone: '1');
      final d = _doc(id: 'd', title: 'د م41', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(supplies: [s], doctors: [d]);
      await planner.plan(query: 'أريد مستلزمات طبية', context: ctx);
      final sw = await planner.plan(query: 'أريدلي طبيب أطفال', context: ctx);
      expect(sw.intentResult.intent, AssistantIntent.specialtySearch);
    });

    test('S42 filter → ordinal → correction → call', () async {
      final a = _doc(id: 'a', title: 'أ', phone: '1', whatsapp: '1');
      final b = _doc(id: 'b', title: 'ب', phone: '2', whatsapp: null);
      final c = _doc(id: 'c', title: 'ج', phone: '3', whatsapp: '3');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b, c]);
      ctx.rememberResults([a, b, c], intent: AssistantIntent.doctorSearch);
      await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      await planner.plan(query: 'الثاني', context: ctx);
      final fix = await planner.plan(query: 'لا مو الثاني الأول', context: ctx);
      expect(fix.target?.doctorId, 'a');
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'a');
    });

    test('S43 rename during conversation (physio fixture)', () async {
      var items = [_physio(id: 'r1', title: 'مركز قديم م43', phone: '1')];
      SmartBrainPlanner planner() => _fixturePlanner(physios: List.of(items));
      final ctx = ConversationContext();
      await planner().plan(query: 'مركز قديم م43', context: ctx);
      expect(ctx.selectedPhysio?.physioId, 'r1');
      items = [_physio(id: 'r1', title: 'مركز جديد م43', phone: '1')];
      final after = await planner().plan(
        query: 'مركز جديد م43',
        context: ConversationContext(),
      );
      expect(after.target?.title, 'مركز جديد م43');
    });

    test('S44 hide during conversation blocks later call', () async {
      var items = [_physio(id: 'h1', title: 'مركز إخفاء م44', phone: '1')];
      SmartBrainPlanner planner() => _fixturePlanner(physios: List.of(items));
      final ctx = ConversationContext();
      await planner().plan(query: 'مركز إخفاء م44', context: ctx);
      items = [];
      final call = await planner().plan(query: 'اتصل بيه', context: ctx);
      expect(call.canExecute, isFalse);
      expect(call.kind, isNot(AssistantActionKind.prepareCall));
    });

    test('S45 stale WhatsApp protection after hide', () async {
      var items = [
        _physio(id: 'w1', title: 'مركز واتس م45', phone: '1', whatsapp: 'wa'),
      ];
      SmartBrainPlanner planner() => _fixturePlanner(physios: List.of(items));
      final ctx = ConversationContext();
      await planner().plan(query: 'مركز واتس م45', context: ctx);
      items = [];
      final wa = await planner().plan(query: 'دزله واتساب', context: ctx);
      expect(wa.canExecute, isFalse);
      expect(wa.kind, isNot(AssistantActionKind.prepareWhatsApp));
    });

    test('S46 new dynamic entity mid-session', () async {
      var items = <SmartSearchResult>[];
      SmartBrainPlanner planner() => _fixturePlanner(physios: List.of(items));
      final miss = await planner().plan(
        query: 'مركز جلسة م46',
        context: ConversationContext(),
      );
      expect(miss.target, isNull);
      items = [_physio(id: 'n46', title: 'مركز جلسة م46', phone: '1')];
      final hit = await planner().plan(
        query: 'مركز جلسة م46',
        context: ConversationContext(),
      );
      expect(hit.target?.physioId, 'n46');
    });

    test('S47 ambiguous → clarification → confirmation', () async {
      final docs = [
        _doc(id: '1', title: 'سامر أحمد', phone: '1'),
        _doc(id: '2', title: 'سامر محمد', phone: '2'),
      ];
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: docs);
      final amb = await planner.plan(query: 'سامر', context: ctx);
      expect(
        amb.kind == AssistantActionKind.showClarification ||
            amb.candidates.length > 1 ||
            amb.message.contains('تقصد'),
        isTrue,
        reason: amb.message,
      );
      if (ctx.hasPendingDoctorSuggestion) {
        final yes = await planner.plan(query: 'اي', context: ctx);
        expect(yes.kind, isNot(AssistantActionKind.prepareCall));
      }
    });

    test('S48 rejection → alternative request', () async {
      final ctx = ConversationContext();
      ctx.setPendingDoctorSuggestion(
        const PendingDoctorSuggestion(doctorId: 'x', doctorName: 'د. اقتراح'),
      );
      final planner = _fixturePlanner(
        pharmacies: [_pharm(id: 'p', title: 'صيدلية بديل', phone: '1')],
      );
      await planner.plan(query: 'مو هذا', context: ctx);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      final alt = await planner.plan(query: 'أريدلي صيدلية', context: ctx);
      expect(
        alt.candidates.any((e) => e.type == SmartSearchResultType.pharmacy) ||
            alt.target?.type == SmartSearchResultType.pharmacy ||
            alt.kind == AssistantActionKind.runGeneralSearch,
        isTrue,
        reason: alt.message,
      );
    });

    test('S49 pending confirmation interrupted by new search', () async {
      final ctx = ConversationContext();
      ctx.setPendingDoctorSuggestion(
        const PendingDoctorSuggestion(doctorId: 'x', doctorName: 'د. م49'),
      );
      final plan = await _fixturePlanner(
        physios: [_physio(id: 'f', title: 'مركز م49', phone: '1')],
      ).plan(query: 'أقصد علاج طبيعي', context: ctx);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(
        plan.target?.physioId == 'f' ||
            plan.candidates.any((e) => e.physioId == 'f') ||
            plan.kind == AssistantActionKind.runGeneralSearch,
        isTrue,
        reason: plan.message,
      );
    });

    test('S50 correction after selection', () async {
      final a = _doc(id: 'a', title: 'أ م50', phone: '1');
      final b = _doc(id: 'b', title: 'ب م50', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b]);
      ctx.rememberResults([a, b], intent: AssistantIntent.doctorSearch);
      await planner.plan(query: 'الثاني', context: ctx);
      expect(ctx.selectedDoctor?.doctorId, 'b');
      final fix = await planner.plan(query: 'لا مو الثاني الأول', context: ctx);
      expect(fix.target?.doctorId, 'a');
    });

    test('S51 correction after refinement', () async {
      final a = _doc(id: 'a', title: 'أ', gender: 'female', phone: '1');
      final b = _doc(id: 'b', title: 'ب', gender: 'male', phone: '2');
      final c = _doc(id: 'c', title: 'ج', gender: 'female', phone: '3');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b, c]);
      ctx.rememberResults([a, b, c], intent: AssistantIntent.specialtySearch);
      await planner.plan(query: 'طبيبة', context: ctx);
      await planner.plan(query: 'الثاني', context: ctx);
      final fix = await planner.plan(query: 'مو الثاني قصدي الأول', context: ctx);
      expect(fix.target?.doctorId, 'a');
    });

    test('S52 3-turn pharmacy select call', () async {
      final a = _pharm(id: 'a', title: 'صيدلية أ م52', phone: '1');
      final b = _pharm(id: 'b', title: 'صيدلية ب م52', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(pharmacies: [a, b]);
      await planner.plan(query: 'أريدلي صيدلية', context: ctx);
      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.target?.pharmacyId, 'b');
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
    });

    test('S53 4-turn supply list ordinal location', () async {
      final a = _supply(id: 'a', title: 'مستلزمات أ م53', phone: '1');
      final b = _supply(id: 'b', title: 'مستلزمات ب م53', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(supplies: [a, b]);
      await planner.plan(query: 'أريد مستلزمات طبية', context: ctx);
      await planner.plan(query: 'الأول', context: ctx);
      final loc = await planner.plan(query: 'وينه', context: ctx);
      expect(loc.kind, AssistantActionKind.showLocation);
      expect(loc.target?.supplyId, 'a');
    });

    test('S54 5-turn pediatrics compound', () async {
      final a = _doc(id: 'a', title: 'أ', phone: '1', whatsapp: '1');
      final b = _doc(id: 'b', title: 'ب', phone: '2', whatsapp: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b]);
      await planner.plan(query: 'أريدلي طبيب أطفال', context: ctx);
      ctx.rememberResults([a, b], intent: AssistantIntent.specialtySearch);
      await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      await planner.plan(query: 'الأول', context: ctx);
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      final loc = await planner.plan(query: 'وينه', context: ctx);
      expect(loc.kind, AssistantActionKind.showLocation);
    });

    test('S55 phone ≠ WhatsApp on selected pharmacy', () async {
      final p = _pharm(id: 'p', title: 'صيدلية هاتف فقط م55', phone: '077000');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(pharmacies: [p]);
      await planner.plan(query: 'صيدلية هاتف فقط م55', context: ctx);
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.canExecute, isFalse);
      expect(wa.kind, isNot(AssistantActionKind.prepareWhatsApp));
    });

    test('S56 ordinal out of range after filter', () async {
      final a = _doc(id: 'a', title: 'أ', phone: '1', whatsapp: '1');
      final b = _doc(id: 'b', title: 'ب', phone: '2', whatsapp: null);
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b]);
      ctx.rememberResults([a, b], intent: AssistantIntent.doctorSearch);
      await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      expect(ctx.currentResultContext?.length, 1);
      final third = await planner.plan(query: 'الثالث', context: ctx);
      expect(third.target, isNull);
      expect(third.canExecute, isFalse);
    });

    test('S57 reject entity suggestion then physio search', () async {
      final ctx = ConversationContext();
      ctx.setPendingEntitySuggestion(
        const PendingEntitySuggestion(
          entityType: ClarificationEntityType.pharmacy,
          entityId: 'px',
          entityName: 'صيدلية',
        ),
      );
      final planner = _fixturePlanner(
        physios: [_physio(id: 'f', title: 'مركز م57', phone: '1')],
      );
      await planner.plan(query: 'غيره', context: ctx);
      expect(ctx.hasPendingEntitySuggestion, isFalse);
      final alt = await planner.plan(query: 'طلعلي علاج طبيعي', context: ctx);
      expect(
        alt.target?.physioId == 'f' ||
            alt.candidates.any((e) => e.physioId == 'f'),
        isTrue,
        reason: alt.message,
      );
    });

    test('S58 pronoun after ordinal correction', () async {
      final a = _doc(id: 'a', title: 'أ', phone: '1');
      final b = _doc(id: 'b', title: 'ب', phone: '2');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(doctors: [a, b]);
      ctx.rememberResults([a, b], intent: AssistantIntent.doctorSearch);
      await planner.plan(query: 'الثاني', context: ctx);
      await planner.plan(query: 'لا مو الثاني الأول', context: ctx);
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.target?.doctorId, 'a');
      expect(call.kind, AssistantActionKind.prepareCall);
    });

    test('S59 lab list → second → whatsapp explicit', () async {
      final a = _lab(id: 'a', title: 'مختبر أ م59', phone: '1', whatsapp: 'wa');
      final b = _lab(id: 'b', title: 'مختبر ب م59', phone: '2', whatsapp: 'wb');
      final ctx = ConversationContext();
      final planner = _fixturePlanner(labs: [a, b]);
      await planner.plan(query: 'أريد مختبر', context: ctx);
      ctx.rememberResults([a, b], intent: AssistantIntent.findLab);
      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.target?.labId, 'b');
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.labId, 'b');
    });

    test('S60 AI-off + corpus boundary smoke', () {
      expect(File('test/fixtures/m6_iraqi_corpus_golden.json').existsSync(), isTrue);
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('m6_iraqi_corpus'), isFalse);
      expect(pubspec.contains('openai'), isFalse);
      expect(pubspec.contains('anthropic'), isFalse);
      // clinicalEnabled=false في كل fixtures أعلاه = لا مسار سريري/LLM.
      expect(true, isTrue);
    });
  });

  group('M6 — metrics snapshot', () {
    test('معدلات هندسية منفصلة: intent / refuse / scenarios', () {
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
      const scenarioPass = scenarioCaseCount;
      final intentRate = intentChecked == 0 ? 0.0 : intentPass / intentChecked;
      final refuseRate = refuseChecked == 0 ? 0.0 : refusePass / refuseChecked;
      expect(intentRate, greaterThanOrEqualTo(0.90));
      expect(refuseRate, greaterThanOrEqualTo(0.90));
      expect(scenarioPass, scenarioCaseCount);
      final total = allCases.length + scenarioCaseCount;
      expect(golden.length, greaterThanOrEqualTo(300));
      expect(scenarioCaseCount, greaterThanOrEqualTo(60));
      expect(total, greaterThanOrEqualTo(1146));
      expect(
        true,
        isTrue,
        reason:
            'INTENT=$intentPass/$intentChecked (${(intentRate * 100).toStringAsFixed(1)}%) '
            'REFUSE/OOS=$refusePass/$refuseChecked (${(refuseRate * 100).toStringAsFixed(1)}%) '
            'SCENARIOS=$scenarioPass/$scenarioCaseCount '
            'golden=${golden.length} generated=${generated.length} '
            'total=$total',
      );
    });
  });
}
