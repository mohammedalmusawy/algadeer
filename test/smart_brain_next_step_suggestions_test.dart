import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/conversation/smart_brain_suggested_actions.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/search_modifiers.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

SmartSearchResult _doc(
  String id,
  String title, {
  String? phone,
  String? whatsapp,
  String? loc,
  String booking = 'available',
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: 'طب الأطفال',
    specialty: 'طب الأطفال',
    doctorId: id,
    phone: phone,
    whatsapp: whatsapp,
    clinicLocation: loc,
    bookingStatus: booking,
    score: 90,
  );
}

SmartSearchResult _lab(String id, String title, {String? loc, String? wa}) {
  return SmartSearchResult(
    type: SmartSearchResultType.lab,
    title: title,
    subtitle: 'مختبر',
    labId: id,
    clinicLocation: loc,
    whatsapp: wa,
    phone: wa,
    score: 88,
  );
}

void main() {
  group('Next-step suggestions — سياق', () {
    test('بحث أطباء متعدد → أسماء مرقّمة بحد 3 + lead', () {
      final ctx = ConversationContext();
      final docs = [
        _doc('a', 'د. أحمد أطفال'),
        _doc('b', 'د. صباح مجيد العمري'),
        _doc('c', 'د. مريم'),
        _doc('d', 'د. كريم'),
      ];
      ctx.rememberResults(
        docs,
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      final bundle = SmartBrainSuggestedActionsBuilder.suggest(
        context: ctx,
        presented: docs,
        lastIntent: AssistantIntent.specialtySearch,
        planKind: AssistantActionKind.runSpecialtySearch,
        lastQuery: 'أريد طبيب أطفال',
        maxActions: 3,
      );
      expect(bundle.leadText, contains('تفاصيل أي طبيب'));
      expect(bundle.actions.length, 3);
      expect(bundle.actions.first.label, startsWith('1.'));
      expect(bundle.actions[1].label, startsWith('2.'));
      expect(bundle.actions.every((a) => a.entityId != null), isTrue);
      expect(bundle.actions.every((a) => a.executionQuery != null), isTrue);
      expect(bundle.actions[1].executionQuery, 'افتح الثاني');
      expect(bundle.actions[1].entityId, 'b');
    });

    test('بعد اختيار طبيب → تفاصيل / دوام / حجز حسب الهدف', () {
      final ctx = ConversationContext();
      final d = _doc(
        'b',
        'د. صباح',
        phone: '0770',
        whatsapp: '0770',
        loc: 'الشطرة',
      );
      ctx.rememberResults([d], intent: AssistantIntent.specialtySearch);
      ctx.selectDoctor(d);
      final general = SmartBrainSuggestedActionsBuilder.suggest(
        context: ctx,
        presented: [d],
        lastIntent: AssistantIntent.selectResult,
        planKind: AssistantActionKind.selectEntity,
        lastQuery: 'الثاني',
      );
      expect(general.actions.length, lessThanOrEqualTo(3));
      expect(
        general.actions.map((a) => a.kind),
        contains(SmartBrainSuggestedActionKind.openDetails),
      );

      final bookingGoal = SmartBrainSuggestedActionsBuilder.suggest(
        context: ctx,
        presented: [d],
        lastIntent: AssistantIntent.bookAppointment,
        planKind: AssistantActionKind.showMessage,
        lastQuery: 'احجز عنده',
      );
      expect(bookingGoal.actions.first.kind,
          SmartBrainSuggestedActionKind.bookingGuidance);
    });

    test('بعد الدوام → حجز وموقع لا تكرار الدوام', () {
      final ctx = ConversationContext();
      final d = _doc('b', 'د. صباح', loc: 'الشطرة', whatsapp: '0770');
      ctx.selectDoctor(d);
      final bundle = SmartBrainSuggestedActionsBuilder.suggest(
        context: ctx,
        presented: [d],
        lastIntent: AssistantIntent.doctorAvailability,
        planKind: AssistantActionKind.selectEntity,
        lastQuery: 'شنو دوامه',
        alreadyShownInfo: {'availability'},
        justExecuted: SmartBrainSuggestedActionKind.showAvailability,
      );
      expect(
        bundle.actions.any(
          (a) => a.kind == SmartBrainSuggestedActionKind.showAvailability,
        ),
        isFalse,
      );
      expect(
        bundle.actions.map((a) => a.kind),
        contains(SmartBrainSuggestedActionKind.bookingGuidance),
      );
      expect(
        bundle.actions.map((a) => a.kind),
        contains(SmartBrainSuggestedActionKind.showLocation),
      );
    });

    test('واتساب يظهر فقط إن متاح', () {
      final ctx = ConversationContext();
      final noWa = _doc('a', 'د. أحمد', phone: '0770111', loc: 'أ');
      ctx.selectDoctor(noWa);
      final without = SmartBrainSuggestedActionsBuilder.suggest(
        context: ctx,
        presented: [noWa],
        lastIntent: AssistantIntent.selectResult,
        planKind: AssistantActionKind.selectEntity,
        lastQuery: 'الأول',
      );
      expect(
        without.actions.any((a) => a.kind == SmartBrainSuggestedActionKind.whatsapp),
        isFalse,
      );

      final withWa = _doc('a', 'د. أحمد', whatsapp: '0770111', loc: 'أ');
      ctx.selectDoctor(withWa);
      final wa = SmartBrainSuggestedActionsBuilder.suggest(
        context: ctx,
        presented: [withWa],
        lastIntent: AssistantIntent.selectResult,
        planKind: AssistantActionKind.selectEntity,
        lastQuery: 'الأول',
        maxActions: 5,
      );
      expect(
        wa.actions.any((a) => a.kind == SmartBrainSuggestedActionKind.whatsapp),
        isTrue,
      );
    });

    test('مختبر → باقات/تحاليل/موقع حسب المتاح', () {
      final ctx = ConversationContext();
      final lab = _lab('l1', 'مختبر النور', loc: 'بغداد', wa: '0770');
      ctx.rememberResults([lab], intent: AssistantIntent.findLab);
      ctx.selectLaboratory(lab);
      final bundle = SmartBrainSuggestedActionsBuilder.suggest(
        context: ctx,
        presented: [lab],
        lastIntent: AssistantIntent.findLab,
        planKind: AssistantActionKind.selectEntity,
        lastQuery: 'مختبر النور',
        maxActions: 4,
      );
      final kinds = bundle.actions.map((a) => a.kind).toSet();
      expect(kinds.contains(SmartBrainSuggestedActionKind.showPackages), isTrue);
      expect(kinds.contains(SmartBrainSuggestedActionKind.showAnalyses), isTrue);
      expect(kinds.contains(SmartBrainSuggestedActionKind.showLocation), isTrue);
    });

    test('لا نتائج + شرط متوفر → اقتراح تخفيف بلا تنفيذ تلقائي', () {
      final bundle = SmartBrainSuggestedActionsBuilder.suggest(
        presented: const [],
        lastIntent: AssistantIntent.specialtySearch,
        planKind: AssistantActionKind.showMessage,
        lastQuery: 'أريد طبيب أطفال متوفر',
        lastMessage: 'ما لقيت نتيجة',
        modifiers: const SearchModifiers(
          availableOnly: true,
          cleanedQuery: 'أريد طبيب أطفال',
        ),
      );
      expect(bundle.actions, isNotEmpty);
      expect(bundle.actions.first.kind, SmartBrainSuggestedActionKind.relaxFilter);
      expect(bundle.actions.first.executionQuery, 'أريد طبيب أطفال');
      expect(bundle.awaitsSingleYes, isTrue);
      expect(bundle.leadText, contains('شرط'));
    });

    test('شكرًا → بلا اقتراحات', () {
      final bundle = SmartBrainSuggestedActionsBuilder.suggest(
        presented: [_doc('a', 'د. أحمد')],
        lastQuery: 'شكرًا',
        lastIntent: AssistantIntent.unknown,
      );
      expect(bundle.actions, isEmpty);
    });

    test('ملف صحي بدون دخول → بوابة فقط بلا مشاركة', () {
      final bundle = SmartBrainSuggestedActionsBuilder.suggest(
        lastIntent: AssistantIntent.openPatientHealth,
        planKind: AssistantActionKind.openPatientHealth,
        lastQuery: 'ملفي الصحي',
        patientSignedIn: false,
      );
      expect(bundle.actions.length, 1);
      expect(
        bundle.actions.first.kind,
        SmartBrainSuggestedActionKind.openPatientHealth,
      );
      expect(bundle.leadText, contains('دخول'));
      expect(
        bundle.actions.any((a) => a.label.contains('مشارك')),
        isFalse,
      );
    });

    test('توضيح أسماء → خيارات مرقّمة بالمعرّف', () {
      final docs = [
        _doc('a', 'د. أحمد باطن'),
        _doc('b', 'د. أحمد أطفال'),
      ];
      final ctx = ConversationContext();
      ctx.rememberResults(docs, intent: AssistantIntent.doctorSearch);
      final bundle = SmartBrainSuggestedActionsBuilder.suggest(
        context: ctx,
        presented: docs,
        planKind: AssistantActionKind.showClarification,
        lastIntent: AssistantIntent.doctorSearch,
        lastQuery: 'دكتور أحمد',
      );
      expect(bundle.leadText, contains('أي واحد'));
      expect(bundle.actions.length, 2);
      expect(bundle.actions.map((a) => a.entityId).toList(), ['a', 'b']);
    });

    test('معرّفات السياق تُحفظ على الاقتراح', () {
      final ctx = ConversationContext();
      final docs = [_doc('a', 'د. أ'), _doc('b', 'د. ب')];
      ctx.rememberResults(docs, intent: AssistantIntent.specialtySearch);
      final turn = ctx.currentResultContext!.turnId;
      final gen = ctx.conversationGeneration;
      final bundle = SmartBrainSuggestedActionsBuilder.suggest(
        context: ctx,
        presented: docs,
        lastIntent: AssistantIntent.specialtySearch,
        planKind: AssistantActionKind.runSpecialtySearch,
        lastQuery: 'أطفال',
      );
      expect(bundle.actions.first.resultTurnId, turn);
      expect(bundle.actions.first.conversationGeneration, gen);
    });
  });

  group('forResults توافق', () {
    test('بدون رقم — لا اتصال ولا واتساب', () {
      final actions = SmartBrainSuggestedActionsBuilder.forResults([
        _doc('naji', 'د. ناجي'),
      ]);
      final kinds = actions.map((a) => a.kind).toSet();
      expect(kinds.contains(SmartBrainSuggestedActionKind.openDetails), isTrue);
      expect(kinds.contains(SmartBrainSuggestedActionKind.call), isFalse);
      expect(kinds.contains(SmartBrainSuggestedActionKind.whatsapp), isFalse);
    });
  });
}
