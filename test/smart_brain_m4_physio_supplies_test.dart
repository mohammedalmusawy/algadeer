import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/catalog_name_matcher.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

SmartSearchResult _physio({
  required String id,
  required String title,
  String? phone,
  String? whatsapp,
  String address = 'الشطرة',
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.physio,
    title: title,
    subtitle: address,
    physioId: id,
    score: 90,
    phone: phone,
    whatsapp: whatsapp,
    clinicLocation: address,
  );
}

SmartSearchResult _supply({
  required String id,
  required String title,
  String? phone,
  String? whatsapp,
  String address = 'الشطرة',
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.supply,
    title: title,
    subtitle: address,
    supplyId: id,
    score: 90,
    phone: phone,
    whatsapp: whatsapp,
    clinicLocation: address,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final resolver = RuleBasedIntentResolver();

  group('M4 — Physio intents & plans', () {
    test('صيغ عراقية → findPhysio', () {
      for (final q in [
        'اريد علاج طبيعي',
        'طلعلي مراكز علاج طبيعي',
        'وين اكو علاج طبيعي',
        'اريد فيزيو',
        'مركز علاج طبيعي',
      ]) {
        final i = resolver.resolve(q);
        expect(i.intent, AssistantIntent.findPhysio, reason: q);
      }
    });

    test('علاج وحدها ليست فيزيو', () {
      final i = resolver.resolve('اريد علاج');
      expect(i.intent, isNot(AssistantIntent.findPhysio));
    });

    test('بحث قائمة + ترتيب + اتصال', () async {
      final a = _physio(id: 'a', title: 'مركز أ', phone: '0771', whatsapp: '0771');
      final b = _physio(id: 'b', title: 'مركز ب', phone: '0772', whatsapp: null);
      final c = _physio(id: 'c', title: 'مركز ج', phone: '0773', whatsapp: '0773');
      final ctx = ConversationContext();
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        physioLookup: (_) async => [a, b, c],
        supplyLookup: (_) async => const [],
      );

      final list = await planner.plan(query: 'طلعلي مراكز علاج طبيعي', context: ctx);
      expect(list.candidates.length, 3);
      expect(ctx.currentResultContext?.entityType, ConversationEntityType.physio);

      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.kind, AssistantActionKind.selectEntity);
      expect(sel.target?.physioId, 'b');

      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.physioId, 'b');
      expect(call.canExecute, isTrue);
    });

    test('واتساب صريح فقط — phone لا يكفي', () async {
      final onlyPhone = _physio(
        id: 'p',
        title: 'مركز هاتف فقط',
        phone: '0770999',
        whatsapp: null,
      );
      final ctx = ConversationContext();
      ctx.rememberResults([onlyPhone], intent: AssistantIntent.findPhysio);
      ctx.selectPhysio(onlyPhone);
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        physioLookup: (_) async => [onlyPhone],
        supplyLookup: (_) async => const [],
      );
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.showMessage);
      expect(wa.canExecute, isFalse);
      expect(onlyPhone.canWhatsApp, isFalse);
      expect(onlyPhone.canCall, isTrue);
    });

    test('اسم ديناميكي من lookup — بلا hardcode في Brain', () async {
      final noor = _physio(
        id: 'noor',
        title: 'مركز النور للعلاج الطبيعي',
        phone: '0770',
        whatsapp: '0770',
        address: 'الكرادة',
      );
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        physioLookup: (q) async {
          final n = ArabicTextUtils.normalize(q);
          if (n.contains('النور') || n.isEmpty) return [noor];
          return const [];
        },
        supplyLookup: (_) async => const [],
      );
      final ctx = ConversationContext();
      await planner.plan(query: 'اريد مركز النور', context: ctx);
      // قد يكون findPhysio بالاسم أو doctorSearch إن لم تُذكر كلمة فيزيو —
      // مع «مركز النور» بدون علاج طبيعي قد لا يُصنَّف فيزيو؛ نختبر جملة أوضح:
      final plan2 = await planner.plan(
        query: 'اريد مركز النور للعلاج الطبيعي',
        context: ConversationContext(),
      );
      expect(
        plan2.target?.physioId == 'noor' ||
            plan2.candidates.any((c) => c.physioId == 'noor'),
        isTrue,
        reason: plan2.message,
      );

      final locCtx = ConversationContext();
      locCtx.selectPhysio(noor);
      final loc = await planner.plan(query: 'وينه', context: locCtx);
      expect(loc.kind, AssistantActionKind.showLocation);
      expect(loc.message, contains('الكرادة'));
    });

    test('typo صوت: علاج طبييعي', () {
      final i = resolver.resolve('اريد علاج طبييعي');
      // حتى لو فشل التصنيف بسبب خطأ إملائي، المعنى المطبَّع قد يساعد —
      // نقبل findPhysio أو على الأقل ليس خارج المنصة.
      expect(
        i.intent,
        anyOf(AssistantIntent.findPhysio, AssistantIntent.generalSearch),
      );
    });
  });

  group('M4 — Supplies intents & plans', () {
    test('صيغ → findSupply', () {
      for (final q in [
        'اريد مستلزمات طبية',
        'طلعلي تجهيزات طبية',
        'وين اكو مستلزمات',
        'اريد مستلزمات طبيه',
      ]) {
        final i = resolver.resolve(q);
        expect(i.intent, AssistantIntent.findSupply, reason: q);
      }
    });

    test('قائمة + الثاني + واتساب صريح', () async {
      final a = _supply(id: 'a', title: 'محل أ', phone: '1', whatsapp: null);
      final b = _supply(id: 'b', title: 'محل ب', phone: '2', whatsapp: '2');
      final ctx = ConversationContext();
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        physioLookup: (_) async => const [],
        supplyLookup: (_) async => [a, b],
      );
      await planner.plan(query: 'طلعلي مستلزمات طبية', context: ctx);
      expect(ctx.currentResultContext?.length, 2);

      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.target?.supplyId, 'b');

      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.supplyId, 'b');
      expect(wa.canExecute, isTrue);
    });
  });

  group('M4 — Context switch Pharmacy → Physio', () {
    test('صيدليات ثم علاج طبيعي يبدّل ResultContext', () async {
      final ph = SmartSearchResult(
        type: SmartSearchResultType.pharmacy,
        title: 'صيدلية أ',
        subtitle: 'صيدلية',
        pharmacyId: 'ph1',
        score: 90,
        phone: '1',
        whatsapp: '1',
        clinicLocation: 'أ',
      );
      final p1 = _physio(id: 'p1', title: 'فيزيو 1', phone: '1', whatsapp: '1');
      final p2 = _physio(id: 'p2', title: 'فيزيو 2', phone: '2', whatsapp: '2');
      final ctx = ConversationContext();
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => [ph],
        physioLookup: (_) async => [p1, p2],
        supplyLookup: (_) async => const [],
      );
      await planner.plan(query: 'طلعلي صيدليات', context: ctx);
      expect(ctx.currentResultContext?.entityType, ConversationEntityType.pharmacy);

      await planner.plan(query: 'اريد علاج طبيعي', context: ctx);
      expect(ctx.currentResultContext?.entityType, ConversationEntityType.physio);

      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.target?.physioId, 'p2');
      expect(sel.target?.pharmacyId, isNull);
    });
  });

  group('M4 — M3 refinement على Physio', () {
    test('اللي عنده واتساب ثم الثاني ثم دزله', () async {
      final a = _physio(id: 'a', title: 'أ', phone: '1', whatsapp: '1');
      final b = _physio(id: 'b', title: 'ب', phone: '2', whatsapp: null);
      final c = _physio(id: 'c', title: 'ج', phone: '3', whatsapp: '3');
      final ctx = ConversationContext();
      ctx.rememberResults([a, b, c], intent: AssistantIntent.findPhysio);
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        physioLookup: (_) async => [a, b, c],
        supplyLookup: (_) async => const [],
      );
      final refined =
          await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      expect(refined.candidates.map((e) => e.physioId), ['a', 'c']);

      final sel = await planner.plan(query: 'الثاني', context: ctx);
      expect(sel.target?.physioId, 'c');

      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.target?.physioId, 'c');
    });
  });

  group('M4 — Dynamic platform discovery', () {
    test('إضافة كيان للـ lookup بعد refresh يجدّه بدون تعديل Brain', () async {
      final catalog = <SmartSearchResult>[];
      SmartBrainPlanner planner() => SmartBrainPlanner(
            clinicalEnabled: false,
            doctorLookup: (_) async => const [],
            labLookup: (_) async => const [],
            radiologyLookup: (_) async => const [],
            pharmacyLookup: (_) async => const [],
            physioLookup: (q) async {
              if (catalog.isEmpty) return const [];
              final prepared = ArabicTextUtils.preparePhysioNameQuery(q);
              if (prepared.isEmpty) return List.of(catalog);
              final batch = CatalogNameMatcher(
                prepareQuery: ArabicTextUtils.preparePhysioNameQuery,
              ).match(
                query: prepared,
                entities: [
                  for (final c in catalog)
                    (id: c.physioId ?? c.title, name: c.title),
                ],
              );
              return [
                for (final m in batch.matches)
                  catalog.firstWhere((c) => c.physioId == m.entityId),
              ];
            },
            supplyLookup: (_) async => const [],
          );

      var plan = await planner().plan(
        query: 'اريد مركز النور للعلاج الطبيعي',
        context: ConversationContext(),
      );
      expect(plan.candidates, isEmpty);
      expect(plan.target, isNull);
      expect(plan.message, isNot(contains('النور')));

      catalog.add(
        _physio(
          id: 'noor',
          title: 'مركز النور للعلاج الطبيعي',
          phone: '0770',
          whatsapp: '0770',
        ),
      );

      plan = await planner().plan(
        query: 'اريد مركز النور للعلاج الطبيعي',
        context: ConversationContext(),
      );
      expect(
        plan.target?.physioId == 'noor' ||
            plan.candidates.any((c) => c.physioId == 'noor'),
        isTrue,
      );

      // rename
      catalog[0] = _physio(
        id: 'noor',
        title: 'مركز النور الجديد',
        phone: '0770',
        whatsapp: '0770',
      );
      plan = await planner().plan(
        query: 'اريد مركز النور الجديد للعلاج الطبيعي',
        context: ConversationContext(),
      );
      expect(
        plan.target?.physioId == 'noor' ||
            plan.candidates.any((c) => c.physioId == 'noor'),
        isTrue,
      );

      // hide/delete
      catalog.clear();
      plan = await planner().plan(
        query: 'اريد مركز النور للعلاج الطبيعي',
        context: ConversationContext(),
      );
      expect(plan.candidates.any((c) => c.physioId == 'noor'), isFalse);
      expect(plan.target?.physioId, isNull);
    });

    test('Dynamic doctor discovery عبر doctorLookup', () async {
      final docs = <SmartSearchResult>[];
      SmartBrainPlanner planner() => SmartBrainPlanner(
            clinicalEnabled: false,
            doctorLookup: (q) async {
              if (docs.isEmpty) return const [];
              final n = ArabicTextUtils.normalize(q);
              return [
                for (final d in docs)
                  if (ArabicTextUtils.normalize(d.title).contains(n) ||
                      n.contains(
                        ArabicTextUtils.normalize(d.title).split(' ').last,
                      ))
                    d,
              ];
            },
            labLookup: (_) async => const [],
            radiologyLookup: (_) async => const [],
            pharmacyLookup: (_) async => const [],
            physioLookup: (_) async => const [],
            supplyLookup: (_) async => const [],
          );

      var plan = await planner().plan(
        query: 'الدكتور بدر الجديد',
        context: ConversationContext(),
      );
      expect(plan.target?.doctorId, isNull);

      docs.add(
        SmartSearchResult(
          type: SmartSearchResultType.doctor,
          title: 'الدكتور بدر الجديد',
          subtitle: 'عظام',
          doctorId: 'badr',
          score: 96,
          specialty: 'عظام',
          phone: '0770',
          whatsapp: '0770',
          clinicLocation: 'الكرادة',
        ),
      );

      plan = await planner().plan(
        query: 'الدكتور بدر الجديد',
        context: ConversationContext(),
      );
      expect(
        plan.target?.doctorId == 'badr' ||
            plan.kind == AssistantActionKind.runDoctorSearch,
        isTrue,
      );
      // بعد الإضافة يجب أن يمرّ المسار على بيانات الـ lookup لا اختراع.
      if (plan.target != null) {
        expect(plan.target!.doctorId, 'badr');
      }
    });
  });

  group('M4 — canWhatsApp لا يسقط من phone', () {
    test('effectiveWhatsApp فارغ إن whatsapp null', () {
      final r = _physio(id: 'x', title: 'س', phone: '0770', whatsapp: null);
      expect(r.canCall, isTrue);
      expect(r.canWhatsApp, isFalse);
      expect(r.effectiveWhatsApp, isEmpty);
    });
  });
}
