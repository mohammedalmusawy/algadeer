/// Phase 3D STEP 4 — Short Context & Follow-up Understanding.
///
/// Structured session ResultContext + deterministic ordinal/pronoun resolution.
/// Does not invent targets. Does not depend on OpenAI.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/ghadeer_followup_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('31 — Doctor ordinal selection', () {
    test('الثاني selects Doctor B by stable id', () async {
      final h = _Harness();
      h.seedDoctors();
      final plan = await h.turn('الثاني');
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.doctorId, 'b');
      expect(h.context.selectedDoctor?.doctorId, 'b');
      expect(h.context.selectedDoctor?.doctorId, isNot('a'));
      expect(h.context.selectedDoctor?.doctorId, isNot('c'));
      expect(
        h.context.currentResultContext?.entityType,
        ConversationEntityType.doctor,
      );
    });

    test('اول واحد / ثاني واحد normalize to ordinals', () async {
      final h = _Harness();
      h.seedDoctors();
      await h.turn('اول واحد');
      expect(h.context.selectedDoctor?.doctorId, 'a');
      h.seedDoctors();
      await h.turn('ثاني واحد');
      expect(h.context.selectedDoctor?.doctorId, 'b');
    });
  });

  group('32 — Call after selection', () {
    test('اتصل بيه targets Doctor B via prepareCall', () async {
      final h = _Harness();
      h.seedDoctors();
      await h.turn('الثاني');
      final plan = await h.turn('اتصل بيه');
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'b');
      expect(plan.canExecute, isTrue);
      expect(h.lookupQueries, isEmpty);
    });
  });

  group('33 — WhatsApp after selection', () {
    test('اريد واتساب targets selected doctor', () async {
      final h = _Harness();
      h.seedDoctors();
      await h.turn('الثاني');
      final plan = await h.turn('اريد واتساب');
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'b');
      expect(plan.canExecute, isTrue);
    });

    test('دزله واتساب equivalent also targets B', () async {
      final h = _Harness();
      h.seedDoctors();
      await h.turn('الثاني');
      final plan = await h.turn('دزله واتساب');
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'b');
    });
  });

  group('34 — Booking after selection', () {
    test('احجز عنده keeps Doctor B and does not auto-book', () async {
      final h = _Harness();
      h.seedDoctors();
      await h.turn('الثاني');
      final plan = await h.turn('احجز عنده');
      expect(plan.target?.doctorId, 'b');
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.message, contains('ما أحجز موعداً تلقائياً'));
      expect(plan.message, contains('B'));
      expect(h.context.selectedDoctor?.doctorId, 'b');
    });
  });

  group('35 — Social interruption preserves results', () {
    test('شلونك then الثاني still selects Doctor B', () async {
      final h = _Harness();
      h.seedDoctors();
      final before = h.context.currentResultContext!.items
          .map((e) => e.doctorId)
          .toList();
      final social = await h.turn('شلونك');
      expect(social.kind, AssistantActionKind.showMessage);
      expect(social.message.trim(), isNotEmpty);
      expect(
        h.context.currentResultContext!.items.map((e) => e.doctorId).toList(),
        before,
      );
      final plan = await h.turn('الثاني');
      expect(plan.target?.doctorId, 'b');
      expect(h.context.selectedDoctor?.doctorId, 'b');
    });
  });

  group('36 — Thanks interruption preserves results', () {
    test('شكرا then الثاني still selects Doctor B', () async {
      final h = _Harness();
      h.seedDoctors();
      final beforeTurn = h.context.currentResultContext!.turnId;
      final thanks = await h.turn('شكرا');
      expect(thanks.kind, AssistantActionKind.showMessage);
      expect(h.context.currentResultContext?.turnId, beforeTurn);
      expect(h.context.currentResultContext?.length, 3);
      final plan = await h.turn('الثاني');
      expect(plan.target?.doctorId, 'b');
    });
  });

  group('37 — New search replaces selectable context', () {
    test('lab search replaces doctor ordinal authority', () async {
      final h = _Harness();
      h.seedDoctors();
      await h.turn('الثاني');
      expect(h.context.selectedDoctor?.doctorId, 'b');

      h.context.rememberResults(
        [_lab('l1', 'م1'), _lab('l2', 'م2'), _lab('l3', 'م3')],
        intent: AssistantIntent.findLab,
      );
      expect(
        h.context.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );

      final plan = await h.turn('الثاني');
      expect(plan.target?.labId, 'l2');
      expect(plan.target?.doctorId, isNull);
      expect(h.context.selectedLaboratory?.labId, 'l2');
    });
  });

  group('38 — Out of range', () {
    test('الثالث with two results clarifies without mutating selection',
        () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'A'), _doc('b', 'B')],
        intent: AssistantIntent.specialtySearch,
      );
      expect(h.context.selectedDoctor, isNull);
      final plan = await h.turn('الثالث');
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(plan.target, isNull);
      expect(h.context.selectedDoctor, isNull);
      expect(
        plan.message,
        GhadeerFollowUpContext.outOfRangeMessage(
          requestedOrdinal: 3,
          availableCount: 2,
        ),
      );
      expect(plan.message, contains('خيار ثالث'));
    });
  });

  group('39 — No result context', () {
    test('الثاني without results clarifies', () async {
      final h = _Harness();
      final plan = await h.turn('الثاني');
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(plan.target, isNull);
      expect(h.context.selectedDoctor, isNull);
      expect(
        plan.message,
        GhadeerFollowUpContext.noSelectableResultsMessage(requestedOrdinal: 2),
      );
    });
  });

  group('40 — No pronoun target', () {
    test('اتصل بيه without selection clarifies and does not call', () async {
      final h = _Harness();
      final plan = await h.turn('اتصل بيه');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.canExecute, isFalse);
      expect(plan.target, isNull);
      expect(h.lookupQueries, isEmpty);
      expect(plan.message, contains('طبيب'));
    });
  });

  group('41 — Explicit target overrides contextual', () {
    test('selected A then explicit Doctor B wins', () async {
      final h = _Harness();
      h.context.rememberResults(
        [
          _doc('a', 'د. أحمد كاظم'),
          _doc('ali_nasser', 'د. علي ناصر السعيدي'),
          _doc('c', 'د. كريم جاسم'),
        ],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('الأول');
      expect(h.context.selectedDoctor?.doctorId, 'a');
      final plan = await h.turn('اتصل بالدكتور علي ناصر');
      expect(plan.target?.doctorId, 'ali_nasser');
      expect(h.context.selectedDoctor?.doctorId, 'ali_nasser');
      expect(plan.target?.doctorId, isNot('a'));
    });
  });

  group('42 — Clinical regression', () {
    test('clinical age answer is not stolen as ordinal', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      final plan = await h.turn('8 سنوات');
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.healthSubject.ageYears, 8);
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(plan.target?.doctorId, isNull);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
    });
  });

  group('43 — Clinical + social resume', () {
    test('شلونك does not destroy clinical continuation', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      if (h.context.respiratorySession.lastQuestionKey != 'childAssociated') {
        await h.turn('8 سنوات');
      }
      final clinicalKey = h.context.respiratorySession.lastQuestionKey;
      expect(clinicalKey, isNotNull);

      final social = await h.turn('شلونك');
      expect(social.kind, AssistantActionKind.showMessage);
      expect(h.context.respiratorySession.lastQuestionKey, clinicalKey);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);

      final resume = await h.turn('وياها حرارة');
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(
        h.context.respiratorySession.fever,
        anyOf(RespiratoryTriState.present, RespiratoryTriState.unknown),
      );
      expect(resume.kind, isNot(AssistantActionKind.prepareCall));
    });
  });

  group('Open / follow-up extras', () {
    test('افتحه opens selected doctor profile', () async {
      final h = _Harness();
      h.seedDoctors();
      await h.turn('الثاني');
      final plan = await h.turn('افتحه');
      expect(plan.kind, AssistantActionKind.openProfile);
      expect(plan.target?.doctorId, 'b');
      expect(plan.canExecute, isTrue);
    });
  });
}

SmartSearchResult _doc(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: 'طب الأطفال',
      doctorId: id,
      specialty: 'طب الأطفال',
      phone: '0700$id',
      whatsapp: '0700$id',
      clinicLocation: 'الكرادة',
      score: 90,
    );

SmartSearchResult _lab(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: 'مختبر',
      labId: id,
      labName: title,
      phone: '0770$id',
      whatsapp: '0770$id',
      score: 90,
    );

class _Harness {
  _Harness() {
    context = ConversationContext();
    lookupQueries = <String>[];
    planner = SmartBrainPlanner(
      nluClient: NluClient.disabled,
      doctorLookup: (q) async {
        lookupQueries.add(q);
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('علي') && n.contains('ناصر')) {
          return [_doc('ali_nasser', 'د. علي ناصر السعيدي')];
        }
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

  late final ConversationContext context;
  late final SmartBrainPlanner planner;
  late final List<String> lookupQueries;

  void seedDoctors() {
    context.rememberResults(
      [_doc('a', 'A'), _doc('b', 'B'), _doc('c', 'C')],
      intent: AssistantIntent.specialtySearch,
    );
  }

  Future<AssistantActionPlan> turn(String query) =>
      planner.plan(query: query, context: context);
}
