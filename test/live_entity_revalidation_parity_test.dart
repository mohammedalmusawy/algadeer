import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/platform_grounding.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M7.1 — تكافؤ إعادة التحقق الحية قبل الاتصال/واتساب.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('M7.1 — Pharmacy live revalidation', () {
    test('A/B active call + WhatsApp', () async {
      final p = _pharm('p', 'صيدلية حية م71', phone: '1', whatsapp: 'w');
      final items = [p];
      final planner = _planner(pharmacies: () => items);
      final ctx = ConversationContext();
      await planner.plan(query: 'صيدلية حية م71', context: ctx);
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.canExecute, isTrue);
      expect(call.target?.pharmacyId, 'p');
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.kind, AssistantActionKind.prepareWhatsApp);
      expect(wa.canExecute, isTrue);
      expect(wa.kind, isNot(AssistantActionKind.prepareCall));
    });

    test('C/D/E/F hidden blocks call + WhatsApp', () async {
      var items = [
        _pharm('p', 'صيدلية إخفاء م71', phone: '1', whatsapp: 'w'),
      ];
      final planner = _planner(pharmacies: () => items);
      final ctx = ConversationContext();
      await planner.plan(query: 'صيدلية إخفاء م71', context: ctx);
      items = [];
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.canExecute, isFalse);
      expect(call.kind, isNot(AssistantActionKind.prepareCall));
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.canExecute, isFalse);
      expect(wa.kind, isNot(AssistantActionKind.prepareWhatsApp));
    });

    test('G rename same canonical ID keeps call', () async {
      var items = [
        _pharm('p', 'صيدلية قديمة م71', phone: '1', whatsapp: 'w'),
      ];
      final planner = _planner(pharmacies: () => items);
      final ctx = ConversationContext();
      await planner.plan(query: 'صيدلية قديمة م71', context: ctx);
      items = [_pharm('p', 'صيدلية جديدة م71', phone: '1', whatsapp: 'w')];
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.canExecute, isTrue);
      expect(call.target?.pharmacyId, 'p');
      expect(call.target?.title, 'صيدلية جديدة م71');
    });

    test('H/I capability removal', () async {
      var items = [
        _pharm('p', 'صيدلية قدرة م71', phone: '1', whatsapp: 'w'),
      ];
      final planner = _planner(pharmacies: () => items);
      final ctx = ConversationContext();
      await planner.plan(query: 'صيدلية قدرة م71', context: ctx);
      items = [_pharm('p', 'صيدلية قدرة م71', phone: null, whatsapp: 'w')];
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.canExecute, isFalse);
      expect(call.kind, isNot(AssistantActionKind.prepareCall));
      items = [_pharm('p', 'صيدلية قدرة م71', phone: '1', whatsapp: null)];
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.canExecute, isFalse);
      expect(wa.kind, isNot(AssistantActionKind.prepareWhatsApp));
    });

    test('J pharmacy network failure fails closed', () async {
      final p = _pharm('p', 'صيدلية شبكة م71', phone: '1', whatsapp: 'w');
      var boom = false;
      final planner = _planner(
        pharmacies: () => boom ? throw StateError('network') : [p],
      );
      final ctx = ConversationContext();
      await planner.plan(query: 'صيدلية شبكة م71', context: ctx);
      boom = true;
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.canExecute, isFalse);
      expect(call.kind, isNot(AssistantActionKind.prepareCall));
      expect(call.message, PlatformGrounding.accessProblemMessage);
    });
  });

  group('M7.1 — Laboratory live revalidation', () {
    test('active + hidden + rename + capability + network', () async {
      var items = [
        _lab('l', 'مختبر حية م71', phone: '1', whatsapp: 'w'),
      ];
      var boom = false;
      final planner = _planner(
        labs: () => boom ? throw StateError('network') : items,
      );
      final ctx = ConversationContext();
      await planner.plan(query: 'مختبر حية م71', context: ctx);

      final callOk = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(callOk.kind, AssistantActionKind.prepareCall);
      expect(callOk.canExecute, isTrue);

      items = [_lab('l', 'مختبر مسمى م71', phone: '1', whatsapp: 'w')];
      final renamed = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(renamed.canExecute, isTrue);
      expect(renamed.target?.labId, 'l');
      expect(renamed.target?.title, 'مختبر مسمى م71');

      items = [_lab('l', 'مختبر مسمى م71', phone: '1', whatsapp: null)];
      final waGone = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(waGone.canExecute, isFalse);
      expect(waGone.kind, isNot(AssistantActionKind.prepareWhatsApp));

      items = [];
      final hidden = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(hidden.canExecute, isFalse);
      expect(hidden.kind, isNot(AssistantActionKind.prepareCall));

      items = [_lab('l', 'مختبر مسمى م71', phone: '1', whatsapp: 'w')];
      await planner.plan(query: 'مختبر مسمى م71', context: ctx);
      boom = true;
      final net = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(net.message, PlatformGrounding.accessProblemMessage);
      expect(net.canExecute, isFalse);
    });
  });

  group('M7.1 — Doctor live revalidation', () {
    test('parity: hide / rename / phone-wa / network', () async {
      var items = [
        _doc('d', 'دكتور حية م71', phone: '1', whatsapp: 'w'),
      ];
      var boom = false;
      final planner = _planner(
        doctors: () => boom ? throw StateError('network') : items,
      );
      final ctx = ConversationContext();
      await planner.plan(query: 'دكتور حية م71', context: ctx);

      expect(
        (await planner.plan(query: 'اتصل بيه', context: ctx)).canExecute,
        isTrue,
      );

      items = [_doc('d', 'دكتور مسمى م71', phone: '1', whatsapp: 'w')];
      final renamed = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(renamed.canExecute, isTrue);
      expect(renamed.target?.doctorId, 'd');

      items = [_doc('d', 'دكتور مسمى م71', phone: null, whatsapp: 'w')];
      expect(
        (await planner.plan(query: 'اتصل بيه', context: ctx)).canExecute,
        isFalse,
      );

      items = [_doc('d', 'دكتور مسمى م71', phone: '1', whatsapp: null)];
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.canExecute, isFalse);
      expect(wa.kind, isNot(AssistantActionKind.prepareWhatsApp));

      items = [];
      expect(
        (await planner.plan(query: 'اتصل بيه', context: ctx)).canExecute,
        isFalse,
      );

      items = [_doc('d', 'دكتور مسمى م71', phone: '1', whatsapp: 'w')];
      await planner.plan(query: 'دكتور مسمى م71', context: ctx);
      boom = true;
      final net = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(net.message, PlatformGrounding.accessProblemMessage);
    });
  });

  group('M7.1 — Physio preserved', () {
    test('hide still blocks; rename still works', () async {
      var items = [
        _physio('f', 'مركز فيزيو م71', phone: '1', whatsapp: 'w'),
      ];
      final planner = _planner(physios: () => items);
      final ctx = ConversationContext();
      await planner.plan(query: 'مركز فيزيو م71', context: ctx);
      items = [_physio('f', 'مركز فيزيو جديد م71', phone: '1', whatsapp: 'w')];
      expect(
        (await planner.plan(query: 'اتصل بيه', context: ctx)).target?.physioId,
        'f',
      );
      items = [];
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.canExecute, isFalse);
      expect(call.kind, isNot(AssistantActionKind.prepareCall));
    });
  });

  group('M7.1 — Supplies parity', () {
    test('hide + capability + rename', () async {
      var items = [
        _supply('s', 'مستلزمات م71', phone: '1', whatsapp: 'w'),
      ];
      final planner = _planner(supplies: () => items);
      final ctx = ConversationContext();
      await planner.plan(query: 'مستلزمات م71', context: ctx);
      items = [_supply('s', 'مستلزمات جديد م71', phone: '1', whatsapp: 'w')];
      expect(
        (await planner.plan(query: 'اتصل بيه', context: ctx)).target?.supplyId,
        's',
      );
      items = [_supply('s', 'مستلزمات جديد م71', phone: '1', whatsapp: null)];
      expect(
        (await planner.plan(query: 'دزله واتساب', context: ctx)).canExecute,
        isFalse,
      );
      items = [];
      expect(
        (await planner.plan(query: 'اتصل بيه', context: ctx)).canExecute,
        isFalse,
      );
    });
  });

  group('M7.1 — context switch + isolation + ResultContext', () {
    test('doctor→pharmacy hide revalidates pharmacy only', () async {
      final d = _doc('d', 'د م71 تبديل', phone: '9', whatsapp: '9');
      var pharmacies = [
        _pharm('p', 'صيدلية تبديل م71', phone: '1', whatsapp: 'w'),
      ];
      final planner = _planner(
        doctors: () => [d],
        pharmacies: () => pharmacies,
      );
      final ctx = ConversationContext();
      await planner.plan(query: 'د م71 تبديل', context: ctx);
      await planner.plan(query: 'صيدلية تبديل م71', context: ctx);
      pharmacies = [];
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.canExecute, isFalse);
      expect(call.target?.doctorId, isNull);
      expect(call.kind, isNot(AssistantActionKind.prepareCall));
    });

    test('pharmacy call does not fail when physio source throws', () async {
      final p = _pharm('p', 'صيدلية عزل م71', phone: '1', whatsapp: 'w');
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => [p],
        physioLookup: (_) async => throw StateError('physio down'),
        supplyLookup: (_) async => const [],
        packagesLookup: (_) async => const [],
        activePackagesLookup: ({labId, nameQuery}) async => const [],
        packagesForAnalysisLookup: (_) async => const [],
        discountedPackagesLookup: ({labId}) async => const [],
      );
      final ctx = ConversationContext();
      await planner.plan(query: 'صيدلية عزل م71', context: ctx);
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.canExecute, isTrue);
      expect(call.target?.pharmacyId, 'p');
    });

    test('ResultContext ordinal after filter still works', () async {
      final a = _doc('a', 'أ م71', phone: '1', whatsapp: '1');
      final b = _doc('b', 'ب م71', phone: '2', whatsapp: null);
      final c = _doc('c', 'ج م71', phone: '3', whatsapp: '3');
      final planner = _planner(doctors: () => [a, b, c]);
      final ctx = ConversationContext();
      ctx.rememberResults([a, b, c], intent: AssistantIntent.doctorSearch);
      await planner.plan(query: 'اللي عنده واتساب', context: ctx);
      expect(ctx.currentResultContext?.length, 2);
      final second = await planner.plan(query: 'الثاني', context: ctx);
      expect(second.target?.doctorId, 'c');
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.target?.doctorId, 'c');
      expect(call.kind, AssistantActionKind.prepareCall);
    });

    test('phone != WhatsApp after live refresh', () async {
      final p = _pharm('p', 'صيدلية هاتف م71', phone: '077', whatsapp: null);
      final planner = _planner(pharmacies: () => [p]);
      final ctx = ConversationContext();
      await planner.plan(query: 'صيدلية هاتف م71', context: ctx);
      final wa = await planner.plan(query: 'دزله واتساب', context: ctx);
      expect(wa.canExecute, isFalse);
      expect(wa.kind, isNot(AssistantActionKind.prepareWhatsApp));
      final call = await planner.plan(query: 'اتصل بيه', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
    });
  });
}

SmartSearchResult _doc(
  String id,
  String title, {
  String? phone,
  String? whatsapp,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: 'باطنية',
    specialty: 'باطنية',
    doctorId: id,
    score: 90,
    phone: phone,
    whatsapp: whatsapp,
    clinicLocation: 'الشطرة',
  );
}

SmartSearchResult _pharm(
  String id,
  String title, {
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

SmartSearchResult _lab(
  String id,
  String title, {
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

SmartSearchResult _physio(
  String id,
  String title, {
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

SmartSearchResult _supply(
  String id,
  String title, {
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

List<SmartSearchResult> _filter(
  List<SmartSearchResult> items,
  String q,
  String Function(SmartSearchResult) titleOf,
) {
  if (q.trim().isEmpty) return List.of(items);
  final n = ArabicTextUtils.normalize(q);
  return [
    for (final e in items)
      if (ArabicTextUtils.normalize(titleOf(e)).contains(n)) e,
  ];
}

SmartBrainPlanner _planner({
  List<SmartSearchResult> Function()? doctors,
  List<SmartSearchResult> Function()? pharmacies,
  List<SmartSearchResult> Function()? labs,
  List<SmartSearchResult> Function()? physios,
  List<SmartSearchResult> Function()? supplies,
}) {
  return SmartBrainPlanner(
    clinicalEnabled: false,
    doctorLookup: (q) async =>
        _filter(doctors?.call() ?? const [], q, (e) => e.title),
    labLookup: (q) async =>
        _filter(labs?.call() ?? const [], q, (e) => e.title),
    radiologyLookup: (_) async => const [],
    pharmacyLookup: (q) async =>
        _filter(pharmacies?.call() ?? const [], q, (e) => e.title),
    physioLookup: (q) async =>
        _filter(physios?.call() ?? const [], q, (e) => e.title),
    supplyLookup: (q) async =>
        _filter(supplies?.call() ?? const [], q, (e) => e.title),
    packagesLookup: (_) async => const [],
    activePackagesLookup: ({labId, nameQuery}) async => const [],
    packagesForAnalysisLookup: (_) async => const [],
    discountedPackagesLookup: ({labId}) async => const [],
  );
}
