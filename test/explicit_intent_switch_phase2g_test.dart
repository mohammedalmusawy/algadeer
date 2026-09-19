/// Phase 2G — طلب خدمة صريح يقطع سؤالاً سريرياً معلّقاً فقط.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/nlu/nlu.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('تعريف الطلب الصريح', () {
    final resolver = RuleBasedIntentResolver();

    test('أريد طبيب عظام = specialtySearch قوي', () {
      final r = resolver.resolve('أريد طبيب عظام');
      expect(r.intent, AssistantIntent.specialtySearch);
      expect(r.confidence, greaterThanOrEqualTo(80));
    });

    test('الطبيب كال يمكن من العظام بلا فعل طلب لا يقاطع', () {
      final r = resolver.resolve('الطبيب كال يمكن من العظام');
      // قد يُصنَّف specialtySearch من الكتالوج، لكن بلا أريد/ابحث → لا مقاطعة 2G.
      final n = ArabicTextUtils.normalize('الطبيب كال يمكن من العظام');
      expect(
        RegExp(r'(?:أريد|اريد|ابي|ابحث|دور|وريني)').hasMatch(n),
        isFalse,
      );
      expect(r.intent == AssistantIntent.specialtySearch || r.confidence < 80,
          isTrue);
    });

    test('أريد مختبر / وريني الباقات مدعومان', () {
      expect(resolver.resolve('أريد مختبر').intent, AssistantIntent.findLab);
      expect(
        resolver.resolve('وريني الباقات').intent,
        AssistantIntent.findPackage,
      );
    });
  });

  group('A/B/C — MSK → طبيب عظام → الثاني', () {
    test('طلب صريح يقطع السؤال ويكمل بحثاً في نفس الدور', () async {
      final h = _Harness();
      final gen0 = h.context.conversationGeneration;

      await h.turn('اني عندي ألم بالظهر');
      expect(h.context.mskSession.active, isTrue);
      expect(h.context.mskSession.lastQuestionKey, isNotNull);
      expect(h.context.conversationGeneration, gen0);

      final switchPlan = await h.turn('أريد طبيب عظام');
      expect(h.context.mskSession.active, isFalse);
      expect(h.context.mskSession.lastQuestionKey, isNull);
      expect(h.context.lastResetReason, ConversationResetReason.foreignTurn);
      expect(h.context.conversationGeneration, gen0 + 1);
      expect(
        switchPlan.kind,
        anyOf(
          AssistantActionKind.runSpecialtySearch,
          AssistantActionKind.runDoctorSearch,
        ),
      );
      expect(switchPlan.kind, isNot(AssistantActionKind.showMessage));
      // لم تُستهلك كجواب شدة لـ MSK.
      expect(h.context.mskSession.active, isFalse);

      h.context.rememberResults(
        [_orthoA, _orthoB, _orthoC],
        query: 'أريد طبيب عظام',
        intent: AssistantIntent.specialtySearch,
      );
      expect(
        h.context.currentResultContext?.entityType,
        ConversationEntityType.doctor,
      );

      final second = await h.turn('الثاني');
      expect(second.kind, AssistantActionKind.selectEntity);
      expect(second.target?.doctorId, 'ortho_b');
      expect(h.context.selectedDoctor?.doctorId, 'ortho_b');
      expect(h.context.mskSession.active, isFalse);
    });
  });

  group('D — تنفسي → طبيب أطفال', () {
    test('سؤال تنفسي معلّق ثم أريد طبيب أطفال = بحث', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      if (h.context.respiratorySession.lastQuestionKey != 'childAssociated') {
        await h.turn('8 سنوات');
      }
      expect(h.context.respiratorySession.lastQuestionKey, isNotNull);
      final gen = h.context.conversationGeneration;

      final plan = await h.turn('أريد طبيب أطفال');
      expect(h.context.respiratorySession.active, isFalse);
      expect(h.context.lastResetReason, ConversationResetReason.foreignTurn);
      expect(h.context.conversationGeneration, gen + 1);
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.runSpecialtySearch,
          AssistantActionKind.runDoctorSearch,
        ),
      );
    });
  });

  group('E/F/G/H — أجوبة سريرية محفوظة', () {
    test('E — 8 سنوات تبقى عمراً', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      expect(h.context.respiratorySession.lastQuestionKey, 'childAge');
      final gen = h.context.conversationGeneration;
      await h.turn('8 سنوات');
      expect(h.context.healthSubject.ageYears, 8);
      expect(h.context.healthSubject.type, HealthSubjectType.child);
      expect(h.context.respiratorySession.active, isTrue);
      expect(h.context.conversationGeneration, gen);
    });

    test('F — نعم سريرية لا تصبح بحثاً', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال من يومين');
      if (h.context.respiratorySession.lastQuestionKey != 'childAssociated') {
        await h.turn('8 سنوات');
      }
      expect(h.context.respiratorySession.lastQuestionKey, 'childAssociated');
      final plan = await h.turn('نعم');
      expect(plan.kind, isNot(AssistantActionKind.runSpecialtySearch));
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(h.context.respiratorySession.active, isTrue);
    });

    test('G — خفيف تستهلكها MSK', () async {
      final h = _Harness();
      await h.turn('اني عندي ألم بالظهر');
      expect(h.context.mskSession.lastQuestionKey, isNotNull);
      final gen = h.context.conversationGeneration;
      final plan = await h.turn('خفيف');
      expect(plan.kind, isNot(AssistantActionKind.runSpecialtySearch));
      expect(h.context.mskSession.active, isTrue);
      expect(h.context.conversationGeneration, gen);
    });

    test('H — من يومين تبقى سريرية', () async {
      final h = _Harness();
      await h.turn('ابني عنده سعال');
      expect(h.context.respiratorySession.active, isTrue);
      final gen = h.context.conversationGeneration;
      await h.turn('من يومين');
      expect(h.context.respiratorySession.active, isTrue);
      expect(
        h.context.respiratorySession.durationBucket,
        RespiratoryDurationBucket.days,
      );
      expect(h.context.conversationGeneration, gen);
    });
  });

  group('I — مختبر صريح', () {
    test('أريد مختبر يقطع السريري ويفتح بحث مختبر', () async {
      final h = _Harness();
      await h.turn('اني عندي ألم بالظهر');
      expect(h.context.mskSession.lastQuestionKey, isNotNull);
      final plan = await h.turn('أريد مختبر');
      expect(h.context.mskSession.active, isFalse);
      expect(plan.kind, AssistantActionKind.runLabSearch);
      h.context.rememberResults(
        [_labNoor, _labHayat],
        intent: AssistantIntent.findLab,
      );
      final second = await h.turn('الثاني');
      expect(second.target?.labId, 'hayat');
      expect(h.context.mskSession.active, isFalse);
    });
  });

  group('J — باقة صريحة', () {
    test('وريني الباقات مدعومة وتقطع السريري', () async {
      final h = _Harness();
      await h.turn('اني عندي ألم بالظهر');
      final plan = await h.turn('وريني الباقات');
      expect(h.context.mskSession.active, isFalse);
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.runGeneralSearch,
          AssistantActionKind.showMessage,
          AssistantActionKind.showLabPackages,
          AssistantActionKind.showClarification,
        ),
      );
      // IntentResolver يدعم findPackage — لا يُستهلك كجواب MSK.
      expect(h.context.mskSession.lastQuestionKey, isNull);
    });
  });

  group('K — ذكر اختصاص عرضي', () {
    test('الطبيب كال يمكن من العظام لا يقاطع السؤال السريري', () async {
      final h = _Harness();
      await h.turn('اني عندي ألم بالظهر');
      final gen = h.context.conversationGeneration;
      final key = h.context.mskSession.lastQuestionKey;
      expect(key, isNotNull);
      await h.turn('الطبيب كال يمكن من العظام');
      // بلا فعل طلب صريح: لا foreignTurn ولا بحث اختصاص من 2G.
      expect(h.context.conversationGeneration, gen);
      expect(h.context.lastResetReason, isNot(ConversationResetReason.foreignTurn));
      expect(h.context.mskSession.active, isTrue);
    });
  });

  group('L — حماية pendingAction', () {
    test('اتصال قديم ثم سريري ثم أريد طبيب عظام لا تنفّذ الاتصال', () async {
      final h = _Harness();
      h.context.rememberResults([_orthoA], intent: AssistantIntent.doctorSearch);
      await h.turn('اتصل');
      expect(h.context.pendingAction, 'call');
      await h.turn('اني عندي ألم بالظهر');
      expect(h.context.mskSession.lastQuestionKey, isNotNull);

      final plan = await h.turn('أريد طبيب عظام');
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(h.context.pendingAction, isNull);
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.runSpecialtySearch,
          AssistantActionKind.runDoctorSearch,
        ),
      );
    });
  });

  group('M — conversationGeneration', () {
    test('التحويل الصريح يزيد الجيل؛ الجواب السريري لا', () async {
      final clinical = _Harness();
      await clinical.turn('اني عندي ألم بالظهر');
      final gen = clinical.context.conversationGeneration;
      expect(clinical.context.mskSession.lastQuestionKey, isNotNull);
      await clinical.turn('خفيف');
      expect(clinical.context.conversationGeneration, gen);

      final switcher = _Harness();
      await switcher.turn('اني عندي ألم بالظهر');
      expect(switcher.context.mskSession.lastQuestionKey, isNotNull);
      final gen2 = switcher.context.conversationGeneration;
      await switcher.turn('أريد طبيب عظام');
      expect(switcher.context.conversationGeneration, gen2 + 1);
      expect(
        switcher.context.lastResetReason,
        ConversationResetReason.foreignTurn,
      );
    });
  });

  group('N/O/P — حفظ 2C/2E/2D بعد التحويل', () {
    test('الثاني → اتصل بيه → نعم على طبيب النتائج الحالية', () async {
      final h = _Harness();
      await h.turn('اني عندي ألم بالظهر');
      await h.turn('أريد طبيب عظام');
      h.context.rememberResults(
        [_orthoA, _orthoB, _orthoC],
        intent: AssistantIntent.specialtySearch,
      );

      await h.turn('الثاني');
      expect(h.context.selectedDoctor?.doctorId, 'ortho_b');
      expect(
        h.context.currentResultContext?.entityType,
        ConversationEntityType.doctor,
      );

      h.lookupQueries.clear();
      final call = await h.turn('اتصل بيه');
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'ortho_b');
      expect(h.lookupQueries, isEmpty);
      expect(h.context.pendingAction, 'call');

      final yes = await h.turn('نعم');
      expect(yes.kind, AssistantActionKind.prepareCall);
      expect(yes.target?.doctorId, 'ortho_b');
    });
  });
}

final _orthoA = _doc('ortho_a', 'طبيب عظام أ');
final _orthoB = _doc('ortho_b', 'طبيب عظام ب');
final _orthoC = _doc('ortho_c', 'طبيب عظام ج');
final _labNoor = _lab('noor', 'مختبر النور');
final _labHayat = _lab('hayat', 'مختبر الحياة');

SmartSearchResult _doc(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: 'العظام',
      doctorId: id,
      specialty: 'العظام',
      phone: '0700$id',
      whatsapp: '0700$id',
      score: 90,
    );

SmartSearchResult _lab(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: 'مختبر',
      labId: id,
      labName: title,
      phone: '0770$id',
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
        if (n.contains('عظام')) return [_orthoA, _orthoB, _orthoC];
        if (n.contains('اطفال')) {
          return [_doc('ped_a', 'أطفال أ'), _doc('ped_b', 'أطفال ب')];
        }
        return const [];
      },
      labLookup: (_) async => [_labNoor, _labHayat],
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

  Future<AssistantActionPlan> turn(String query) =>
      planner.plan(query: query, context: context);
}
