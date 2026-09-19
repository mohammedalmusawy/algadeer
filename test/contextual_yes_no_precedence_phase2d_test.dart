/// Phase 2D — أولوية نعم/لا حسب التوقع الحي في ConversationContext.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('A — السريري يغلب فعلاً قديماً', () {
    test('نعم تجيب سؤال الحرارة ولا تنفّذ اتصال معلّق', () async {
      final h = _Harness();
      await h.prepareCallOnDoctor(_ali);
      expect(h.context.pendingAction, 'call');
      await h.reachChildAssociatedQuestion();
      expect(h.context.respiratorySession.lastQuestionKey, 'childAssociated');
      expect(h.context.pendingAction, isNull);

      final plan = await h.turn('نعم');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.kind, isNot(AssistantActionKind.prepareWhatsApp));
      expect(h.context.pendingAction, isNull);
      expect(h.context.respiratorySession.lastQuestionKey, isNot('childAssociated'));
    });
  });

  group('B — النفي السريري', () {
    test('لا يستهلكها السؤال السريري القائم', () async {
      final h = _Harness();
      await h.reachChildAssociatedQuestion();
      final plan = await h.turn('لا');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(
        h.context.respiratorySession.breathlessness.name,
        anyOf('absent', 'unknown'),
      );
      expect(
        h.context.respiratorySession.fever.name,
        anyOf('absent', 'unknown'),
      );
      expect(h.context.respiratorySession.lastQuestionKey, isNot('childAssociated'));
    });
  });

  group('C — تأكيد اتصال', () {
    test('نعم بعد اتصال معلّق صالح تؤكد المسار القائم', () async {
      final h = _Harness();
      await h.prepareCallOnDoctor(_ali);
      final plan = await h.turn('نعم');
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'ali');
      expect(plan.canExecute, isTrue);
    });
  });

  group('D — رفض اتصال', () {
    test('لا تلغي الاتصال المعلّق فقط', () async {
      final h = _Harness();
      await h.prepareCallOnDoctor(_ali);
      final plan = await h.turn('لا');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.canExecute, isFalse);
      expect(h.context.pendingAction, isNull);
    });
  });

  group('E — تأكيد واتساب', () {
    test('نعم بعد واتساب معلّق تستهدف الطبيب نفسه', () async {
      final h = _Harness();
      await h.prepareWhatsAppOnDoctor(_ali);
      final plan = await h.turn('نعم');
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'ali');
    });
  });

  group('F — رفض واتساب', () {
    test('لا تلغي واتساب المعلّق فقط', () async {
      final h = _Harness();
      await h.prepareWhatsAppOnDoctor(_ali);
      final plan = await h.turn('لا');
      expect(plan.kind, isNot(AssistantActionKind.prepareWhatsApp));
      expect(h.context.pendingAction, isNull);
    });
  });

  group('G — هدف مفقود', () {
    test('نعم مع pendingAction بلا هدف صالح لا تنفّذ', () async {
      final h = _Harness();
      h.context.setPendingAction('call');
      h.context.selectedDoctor = null;
      h.context.activeEntityType = ConversationEntityType.none;
      final plan = await h.turn('نعم');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.canExecute, isNot(true));
      expect(plan.target, isNull);
    });
  });

  group('H — بلا توقع نشط', () {
    test('نعم تصبح إقراراً بلا فعل اعتباطي', () async {
      final h = _Harness();
      final plan = await h.turn('نعم');
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.target, isNull);
      expect(h.context.pendingAction, isNull);
    });
  });

  group('I — حفظ Phase 2C', () {
    test('الثاني ثم اتصال ثم نعم تستهدف الطبيب B', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'طبيب أ'), _ali, _doc('c', 'طبيب ج')],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('الثاني');
      expect(h.context.selectedDoctor?.doctorId, 'ali');
      await h.turn('اتصل');
      expect(h.context.pendingAction, 'call');
      final plan = await h.turn('نعم');
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'ali');
    });
  });

  group('J — حفظ Phase 2B', () {
    test('نعم السريرية لا تمسح عمر الطفل', () async {
      final h = _Harness();
      await h.reachChildAssociatedQuestion();
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.healthSubject.ageYears, 8);
      await h.turn('نعم');
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.healthSubject.ageYears, 8);
      expect(h.context.respiratorySession.active, isTrue);
    });
  });

  group('K — عزل البحث', () {
    test('نعم بلا فعل معلّق لا تختار أول نتيجة', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'أ'), _ali, _doc('c', 'ج')],
        intent: AssistantIntent.specialtySearch,
      );
      final before = h.context.selectedDoctor?.doctorId;
      final plan = await h.turn('نعم');
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(h.context.selectedDoctor?.doctorId, before);
    });
  });

  group('L — حماية الفعل القديم', () {
    test('اتصال ثم شكوى سريرية ثم نعم لا تتصل', () async {
      final h = _Harness();
      await h.prepareCallOnDoctor(_ali);
      await h.reachChildAssociatedQuestion();
      final plan = await h.turn('نعم');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(h.context.pendingAction, isNull);
    });
  });

  group('M — النفي لا يصفّر الجلسة', () {
    test('لا تلغي الفعل وتُبقي ResultContext', () async {
      final h = _Harness();
      h.context.rememberResults(
        [_doc('a', 'أ'), _ali, _doc('c', 'ج')],
        intent: AssistantIntent.specialtySearch,
      );
      await h.turn('الثاني');
      await h.turn('اتصل');
      expect(h.context.currentResultContext?.length, 3);
      await h.turn('لا');
      expect(h.context.pendingAction, isNull);
      expect(h.context.currentResultContext?.entityType,
          ConversationEntityType.doctor);
      expect(h.context.currentResultContext?.length, 3);
      expect(h.context.selectedDoctor?.doctorId, 'ali');
    });
  });
}

final _ali = _doc('ali', 'د. علي ناصر السعيدي');

SmartSearchResult _doc(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: 'طب الأطفال',
      doctorId: id,
      specialty: 'طب الأطفال',
      phone: '0700$id',
      whatsapp: '0700$id',
      score: 90,
    );

class _Harness {
  _Harness() {
    context = ConversationContext();
    planner = SmartBrainPlanner(
      nluClient: NluClient.disabled,
      doctorLookup: (q) async {
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('علي') || n.contains('اطفال')) return [_ali];
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

  Future<AssistantActionPlan> turn(String query) =>
      planner.plan(query: query, context: context);

  Future<void> prepareCallOnDoctor(SmartSearchResult doctor) async {
    context.rememberResults([doctor], intent: AssistantIntent.doctorSearch);
    await turn('اتصل');
    expect(context.pendingAction, 'call');
    expect(context.selectedDoctor?.doctorId, doctor.doctorId);
  }

  Future<void> prepareWhatsAppOnDoctor(SmartSearchResult doctor) async {
    context.rememberResults([doctor], intent: AssistantIntent.doctorSearch);
    await turn('أرسل واتساب');
    expect(context.pendingAction, 'whatsapp');
  }

  Future<void> reachChildAssociatedQuestion() async {
    await turn('ابني عنده سعال من يومين');
    if (context.respiratorySession.lastQuestionKey != 'childAssociated') {
      await turn('8 سنوات');
    }
    expect(context.respiratorySession.lastQuestionKey, 'childAssociated');
  }
}
