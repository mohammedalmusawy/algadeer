import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/platform_grounding.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/intent/unified_entity_discovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

SmartSearchResult _doc({
  required String id,
  required String title,
  String specialty = 'باطنية',
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

typedef _Catalog = ({
  List<SmartSearchResult> doctors,
  List<SmartSearchResult> pharmacies,
  List<SmartSearchResult> physios,
  List<SmartSearchResult> supplies,
});

SmartBrainPlanner _planner(_Catalog cat) {
  return SmartBrainPlanner(
    clinicalEnabled: false,
    doctorLookup: (q) async {
      if (q.trim().isEmpty) return cat.doctors;
      final n = ArabicTextUtils.normalize(q);
      return [
        for (final d in cat.doctors)
          if (ArabicTextUtils.normalize(d.title).contains(n) ||
              n.contains(
                ArabicTextUtils.normalize(d.title).split(' ').last,
              ))
            d,
      ];
    },
    labLookup: (_) async => const [],
    radiologyLookup: (_) async => const [],
    pharmacyLookup: (_) async => cat.pharmacies,
    physioLookup: (_) async => cat.physios,
    supplyLookup: (_) async => cat.supplies,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('M5 — UnifiedEntityDiscovery unit', () {
    test('extractNamePhrase يزيل فعل الطلب ويبقي مركز النور', () {
      expect(
        UnifiedEntityDiscovery.extractNamePhrase('أريد مركز النور'),
        'مركز النور',
      );
      expect(
        UnifiedEntityDiscovery.extractNamePhrase('اتصل بمركز النور'),
        contains('النور'),
      );
    });

    test('exact match بدون تلميح نوع', () {
      final noor = _physio(id: 'p1', title: 'مركز النور');
      final discovery = const UnifiedEntityDiscovery().resolve(
        nameQuery: 'مركز النور',
        catalog: [UnifiedEntityDiscovery.fromResult(noor)],
      );
      expect(discovery.isAmbiguous, isFalse);
      expect(discovery.best?.canonicalId, 'p1');
      expect(discovery.best?.score, greaterThanOrEqualTo(90));
    });
  });

  group('M5 — name without type', () {
    test('1. فيزيو بالاسم فقط — مركز النور', () async {
      final noor = _physio(
        id: 'noor',
        title: 'مركز النور',
        phone: '0770',
        whatsapp: '0770',
      );
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: [noor],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'أريد مركز النور',
        context: ConversationContext(),
      );
      expect(plan.target?.physioId, 'noor', reason: plan.message);
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.openProfile,
          AssistantActionKind.selectEntity,
        ),
      );
    });

    test('2. طبيب بدون كلمة دكتور', () async {
      final ali = _doc(id: 'd1', title: 'علي ناصر', phone: '1');
      final planner = _planner((
        doctors: [ali],
        pharmacies: const [],
        physios: const [],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'علي ناصر',
        context: ConversationContext(),
      );
      expect(plan.target?.doctorId, 'd1', reason: plan.message);
    });

    test('3. صيدلية بدون كلمة صيدلية', () async {
      final p = _pharm(id: 'ph1', title: 'نور الشفاء', phone: '1');
      final planner = _planner((
        doctors: const [],
        pharmacies: [p],
        physios: const [],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'أريد نور الشفاء',
        context: ConversationContext(),
      );
      expect(plan.target?.pharmacyId, 'ph1', reason: plan.message);
    });

    test('4. فيزيو بدون علاج طبيعي', () async {
      final p = _physio(id: 'px', title: 'مركز الأمل', phone: '1');
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: [p],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'وين مركز الأمل',
        context: ConversationContext(),
      );
      expect(plan.target?.physioId, 'px');
      expect(plan.kind, AssistantActionKind.showLocation);
    });

    test('5. مستلزمات بدون كلمة مستلزمات', () async {
      final s = _supply(id: 's1', title: 'بيت الأجهزة الطبية', phone: '1');
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: const [],
        supplies: [s],
      ));
      final ctx = ConversationContext();
      final plan = await planner.plan(
        query: 'افتح بيت الأجهزة الطبية',
        context: ctx,
      );
      expect(
        plan.target?.supplyId == 's1' ||
            ctx.hasPendingEntitySuggestion ||
            plan.message.contains('تقصد'),
        isTrue,
        reason: plan.message,
      );
      if (ctx.hasPendingEntitySuggestion) {
        final yes = await planner.plan(query: 'نعم', context: ctx);
        expect(yes.target?.supplyId, 's1');
      }
    });

    test('6. exact match', () async {
      final p = _physio(id: 'e', title: 'مركز الاختبار الدقيق');
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: [p],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'مركز الاختبار الدقيق',
        context: ConversationContext(),
      );
      expect(plan.target?.physioId, 'e');
    });

    test('7. typo حذر — مركز الشفا', () async {
      final p = _physio(
        id: 'shifa',
        title: 'مركز الشفاء للعلاج الطبيعي',
        phone: '1',
      );
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: [p],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'مركز الشفا',
        context: ConversationContext(),
      );
      expect(
        plan.target?.physioId == 'shifa' ||
            plan.candidates.any((c) => c.physioId == 'shifa') ||
            plan.message.contains('تقصد'),
        isTrue,
        reason: '${plan.kind} ${plan.message}',
      );
    });

    test('8. اسم قصير غامض — لا تخمين', () async {
      final a = _physio(id: 'a', title: 'مركز النور');
      final b = _pharm(id: 'b', title: 'صيدلية النور');
      final planner = _planner((
        doctors: const [],
        pharmacies: [b],
        physios: [a],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'النور',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(plan.candidates.length, greaterThanOrEqualTo(2));
      expect(plan.canExecute, isFalse);
    });

    test('9. أسماء متشابهة عبر الأنواع', () async {
      final a = _physio(id: 'a', title: 'مؤسسة النور');
      final b = _pharm(id: 'b', title: 'صيدلية النور');
      final c = _supply(id: 'c', title: 'مستودع النور');
      final planner = _planner((
        doctors: const [],
        pharmacies: [b],
        physios: [a],
        supplies: [c],
      ));
      final plan = await planner.plan(
        query: 'النور',
        context: ConversationContext(),
      );
      expect(
        plan.kind,
        AssistantActionKind.showClarification,
        reason: plan.message,
      );
      expect(plan.candidates.length, greaterThanOrEqualTo(2));
    });
  });

  group('M5 — confidence / confirmation', () {
    test('10–12. MEDIUM → تقصد؟ → نعم / لا', () async {
      // درجة متوسطة عبر اسم جزئي طويل بما يكفي للمطابقة دون exact.
      final p = _physio(
        id: 'mid',
        title: 'مركز الشفاء الحديث للعلاج الطبيعي',
        phone: '1',
      );
      var catalog = (
        doctors: const <SmartSearchResult>[],
        pharmacies: const <SmartSearchResult>[],
        physios: [p],
        supplies: const <SmartSearchResult>[],
      );
      final planner = _planner(catalog);
      final ctx = ConversationContext();

      // استخدم مطابقة تحتوي لكن ليست exact كاملة إن أمكن.
      final mid = await planner.plan(
        query: 'الشفاء الحديث',
        context: ctx,
      );
      if (ctx.hasPendingEntitySuggestion) {
        expect(mid.message, contains('تقصد'));
        final yes = await planner.plan(query: 'نعم', context: ctx);
        expect(yes.target?.physioId, 'mid');

        final ctx2 = ConversationContext();
        await planner.plan(query: 'الشفاء الحديث', context: ctx2);
        expect(ctx2.hasPendingEntitySuggestion, isTrue);
        final no = await planner.plan(query: 'لا', context: ctx2);
        expect(ctx2.hasPendingEntitySuggestion, isFalse);
        expect(no.target?.physioId, isNull);
      } else {
        // إن صارت HIGH مباشرة — لا يزال الاكتشاف صحيحاً.
        expect(mid.target?.physioId, 'mid');
      }
    });
  });

  group('M5 — actions by name', () {
    test('13. اتصال مباشر بالاسم', () async {
      final p = _physio(id: 'c', title: 'مركز الاتصال', phone: '0771');
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: [p],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'اتصل بمركز الاتصال',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.physioId, 'c');
      expect(plan.canExecute, isTrue);
    });

    test('14. واتساب مباشر بالاسم', () async {
      final p = _pharm(
        id: 'w',
        title: 'صيدلية الورد',
        phone: '1',
        whatsapp: '0772',
      );
      final planner = _planner((
        doctors: const [],
        pharmacies: [p],
        physios: const [],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'دز واتساب لصيدلية الورد',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.pharmacyId, 'w');
    });

    test('15. واتساب ناقص — phone لا يكفي', () async {
      final p = _physio(
        id: 'nw',
        title: 'مركز بلا واتساب',
        phone: '0770999',
        whatsapp: null,
      );
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: [p],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'دز واتساب لمركز بلا واتساب',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.message, contains('واتساب'));
    });

    test('16. موقع بالاسم', () async {
      final p = _physio(
        id: 'loc',
        title: 'مركز الموقع',
        address: 'الكرادة',
      );
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: [p],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'وين مركز الموقع',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.showLocation);
      expect(plan.message, contains('الكرادة'));
    });
  });

  group('M5 — context', () {
    test('17. ضمير بعد الحل', () async {
      final p = _physio(id: 'ctx', title: 'مركز السياق', phone: '1');
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: [p],
        supplies: const [],
      ));
      final ctx = ConversationContext();
      await planner.plan(query: 'أريد مركز السياق', context: ctx);
      expect(ctx.selectedPhysio?.physioId, 'ctx');
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.physioId, 'ctx');
    });

    test('18. تبديل كيان', () async {
      final a = _physio(id: 'a', title: 'مركز ألف', phone: '1');
      final b = _pharm(id: 'b', title: 'صيدلية باء', phone: '2');
      final planner = _planner((
        doctors: const [],
        pharmacies: [b],
        physios: [a],
        supplies: const [],
      ));
      final ctx = ConversationContext();
      await planner.plan(query: 'مركز ألف', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.physio);
      await planner.plan(query: 'صيدلية باء', context: ctx);
      expect(ctx.activeEntityType, ConversationEntityType.pharmacy);
      expect(ctx.selectedPharmacy?.pharmacyId, 'b');
    });
  });

  group('M5 — dynamic add/rename/hide', () {
    test('19. إضافة ديناميكية بعد refresh', () async {
      final list = <SmartSearchResult>[];
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        physioLookup: (_) async => List.of(list),
        supplyLookup: (_) async => const [],
      );

      final miss = await planner.plan(
        query: 'مركز الاختبار الجديد',
        context: ConversationContext(),
      );
      expect(miss.target?.physioId, isNull);
      expect(miss.kind, AssistantActionKind.showMessage);

      list.add(
        _physio(id: 'new1', title: 'مركز الاختبار الجديد', phone: '1'),
      );

      final hit = await planner.plan(
        query: 'مركز الاختبار الجديد',
        context: ConversationContext(),
      );
      expect(hit.target?.physioId, 'new1', reason: hit.message);
    });

    test('20. إعادة تسمية بنفس الـ ID', () async {
      var name = 'مركز أ';
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        physioLookup: (_) async => [
          _physio(id: 'physio-123', title: name, phone: '1'),
        ],
        supplyLookup: (_) async => const [],
      );
      final first = await planner.plan(
        query: 'مركز أ',
        context: ConversationContext(),
      );
      expect(first.target?.physioId, 'physio-123');

      name = 'مركز ب';
      final second = await planner.plan(
        query: 'مركز ب',
        context: ConversationContext(),
      );
      expect(second.target?.physioId, 'physio-123');

      final old = await planner.plan(
        query: 'مركز أ',
        context: ConversationContext(),
      );
      expect(old.target?.physioId, isNull);
    });

    test('21. إخفاء/حذف يزيل الاكتشاف', () async {
      var items = [_physio(id: 'h', title: 'مركز مخفي مؤقتاً', phone: '1')];
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        physioLookup: (_) async => List.of(items),
        supplyLookup: (_) async => const [],
      );
      final ok = await planner.plan(
        query: 'مركز مخفي مؤقتاً',
        context: ConversationContext(),
      );
      expect(ok.target?.physioId, 'h');

      items = [];
      final gone = await planner.plan(
        query: 'مركز مخفي مؤقتاً',
        context: ConversationContext(),
      );
      expect(gone.target?.physioId, isNull);
      expect(gone.kind, AssistantActionKind.showMessage);
    });

    test('22. سياق قديم بعد الإخفاء لا ينفّذ اتصالاً', () async {
      var items = [_physio(id: 'stale', title: 'مركز قديم', phone: '0771')];
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        physioLookup: (_) async => List.of(items),
        supplyLookup: (_) async => const [],
      );
      final ctx = ConversationContext();
      await planner.plan(query: 'مركز قديم', context: ctx);
      expect(ctx.selectedPhysio?.physioId, 'stale');

      items = [];
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.showMessage);
      expect(call.canExecute, isFalse);
      expect(call.message, contains('مو متوفر'));
    });

    test('23. إضافات عبر أنواع متعددة', () async {
      final doctors = <SmartSearchResult>[];
      final pharmacies = <SmartSearchResult>[];
      final physios = <SmartSearchResult>[];
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (q) async {
          if (q.trim().isEmpty) return doctors;
          final n = ArabicTextUtils.normalize(q);
          return [
            for (final d in doctors)
              if (ArabicTextUtils.normalize(d.title).contains(n)) d,
          ];
        },
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => pharmacies,
        physioLookup: (_) async => physios,
        supplyLookup: (_) async => const [],
      );

      doctors.add(_doc(id: 'nd', title: 'سامر الجديد', phone: '1'));
      pharmacies.add(_pharm(id: 'np', title: 'صيدلية الأفق', phone: '2'));
      physios.add(_physio(id: 'nphy', title: 'مركز الأفق للعلاج', phone: '3'));

      final d = await planner.plan(
        query: 'سامر الجديد',
        context: ConversationContext(),
      );
      expect(d.target?.doctorId, 'nd');

      final p = await planner.plan(
        query: 'صيدلية الأفق',
        context: ConversationContext(),
      );
      expect(p.target?.pharmacyId, 'np');

      final phy = await planner.plan(
        query: 'مركز الأفق للعلاج',
        context: ConversationContext(),
      );
      expect(phy.target?.physioId, 'nphy');
    });
  });

  group('M5 — fail closed', () {
    test('24. لا هلوسة لكيان غير موجود', () async {
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: const [],
        supplies: const [],
      ));
      final plan = await planner.plan(
        query: 'أريد مركز غير موجود إطلاقاً',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.target, isNull);
      expect(plan.canExecute, isFalse);
      expect(plan.message.contains('077'), isFalse);
      expect(plan.message.toLowerCase().contains('whatsapp'), isFalse);
    });

    test('25. فشل بيانات ≠ ما لكيت نتيجة', () async {
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => throw StateError('network'),
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => throw StateError('network'),
        physioLookup: (_) async => throw StateError('network'),
        supplyLookup: (_) async => throw StateError('network'),
      );
      final plan = await planner.plan(
        query: 'أريد مركز النور',
        context: ConversationContext(),
      );
      expect(plan.message, PlatformGrounding.accessProblemMessage);
      expect(plan.message, isNot(PlatformGrounding.noResultsMessage));
    });
  });

  group('M5 — voice-like STT variations', () {
    test('تنويعات صوتية لنفس الاسم', () async {
      final p = _physio(
        id: 'v',
        title: 'مركز الشفاء للعلاج الطبيعي',
        phone: '1',
      );
      final planner = _planner((
        doctors: const [],
        pharmacies: const [],
        physios: [p],
        supplies: const [],
      ));
      for (final q in [
        'مركز الشفاء',
        'الشفاء للعلاج الطبيعي',
        'اريد مركز الشفاء',
      ]) {
        final plan = await planner.plan(
          query: q,
          context: ConversationContext(),
        );
        expect(
          plan.target?.physioId == 'v' ||
              plan.candidates.any((c) => c.physioId == 'v'),
          isTrue,
          reason: '$q → ${plan.message}',
        );
      }
    });
  });
}
