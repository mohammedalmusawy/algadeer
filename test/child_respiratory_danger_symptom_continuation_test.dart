/// استمرارية جواب أعراض الخطر داخل جلسة تنفسية نشطة للطفل — Smart Brain V1.
///
/// العطل: سؤال الحزمة نفسه يقول «ضيق بالتنفس»، والجواب العراقي «ضيق بنفس»
/// لا يطابق `ضيق نفس` الحرفي. فلا يُستخرج ضيق النفس، و`isRespiratoryTurn`
/// يبقى كاذباً. عند غياب الجلسة يهرب الدور إلى بحث اسم طبيب فارغ
/// («ما لقيت نتيجة مطابقة حالياً.»). ومع جلسة قائمة يُستهلك الحمى فقط
/// ويُعاد توجيه عام كأن المعلومات الجديدة لم تُذكر.
///
/// الإصلاح في طبقة المرادفات (`RespiratoryAliasCatalog.looksLikeBreathlessness`)
/// لا في جمل ثابتة.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/clinical_knowledge.dart';
import 'package:ghadeer_clinic/companion/people/subject_binding/subject_binding_models.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

SmartSearchResult _doc(String id, String title, String specialty) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty,
    doctorId: id,
    specialty: specialty,
    phone: '07700000000',
    whatsapp: '07700000000',
    clinicLocation: 'الكرادة',
    score: 96,
  );
}

final _saeedi = _doc('saeedi', 'الدكتور علي ناصر السعيدي', 'طب الأطفال');

const _searchKinds = <AssistantActionKind>[
  AssistantActionKind.runDoctorSearch,
  AssistantActionKind.runSpecialtySearch,
  AssistantActionKind.runGeneralSearch,
];

/// التوجيه العام الذي كان يُعاد وكأن الحرارة/الضيق لم يُذكرا.
const _staleGenericWrap = 'إذا استمر السعال أو ظهرت حرارة عالية أو ضيق نفس';

class _Harness {
  _Harness() {
    context = ConversationContext();
    planner = SmartBrainPlanner(
      doctorLookup: (q) async {
        lookups.add(q);
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('السعيدي') || n.contains('اطفال')) return [_saeedi];
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
  final List<String> lookups = <String>[];

  Future<AssistantActionPlan> turn(String query) =>
      planner.plan(query: query, context: context);

  Future<void> warmUpExistingSession() async {
    await turn('علي ناصر السعدي');
    expect(
      context.resolvedConversationSubject.status,
      ConversationPersonResolutionStatus.resolved,
      reason: 'الشرط المسبق: رابط الشخص مستقر قبل الشكوى',
    );
  }

  /// نفس مسار المستخدم حتى سؤال الحرارة/ضيق التنفس.
  Future<void> reachDangerQuestion() async {
    await warmUpExistingSession();
    final cough = await turn('ابني عنده سعال من يومين');
    expect(context.respiratorySession.active, isTrue, reason: cough.message);
    expect(context.respiratorySession.population, RespiratoryPopulation.child);
    expect(context.respiratorySession.lastQuestionKey, 'childAge',
        reason: cough.message);

    final age = await turn('8 سنوات');
    expect(context.respiratorySession.lastQuestionKey, 'childAssociated',
        reason: 'غدير يسأل عن الحرارة/الضيق بعد العمر: ${age.message}');
    expect(age.message.contains('حرارة') || age.message.contains('ضيق'), isTrue,
        reason: age.message);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  void expectConsumedChildContinuation(
    _Harness h,
    AssistantActionPlan plan, {
    required String answer,
  }) {
    expect(h.context.respiratorySession.active, isTrue, reason: answer);
    expect(h.context.respiratorySession.population, RespiratoryPopulation.child,
        reason: 'مالك الشكوى يبقى الطفل: $answer');
    expect(h.context.respiratorySession.hasCoughContext, isTrue,
        reason: 'السعال محفوظ: $answer');
    expect(h.context.respiratorySession.durationBucket,
        RespiratoryDurationBucket.days,
        reason: 'مدة اليومين محفوظة: $answer');
    expect(h.context.respiratorySession.symptomKeys, contains('childAgeKnown'),
        reason: 'العمر محفوظ: $answer');
    expect(h.context.respiratorySession.fever, RespiratoryTriState.present,
        reason: 'الحرارة يجب أن تُستهلك: $answer / ${plan.message}');
    expect(h.context.respiratorySession.breathlessness,
        RespiratoryTriState.present,
        reason: 'ضيق التنفس يجب أن يُستهلك: $answer / ${plan.message}');
    expect(h.context.resolvedConversationSubject.isAccountOwner, isFalse,
        reason: 'ضمير «عنده» لا يبدّل موضوع الطفل: $answer');
    expect(plan.kind, isNot(isIn(_searchKinds)), reason: plan.message);
    expect(plan.message.contains('ما لقيت نتيجة مطابقة'), isFalse,
        reason: plan.message);
    expect(plan.message.contains(_staleGenericWrap), isFalse,
        reason: 'ممنوع إعادة توجيه عام يتجاهل الجواب: ${plan.message}');
    expect(plan.message.trim(), isNotEmpty);
    expect(h.lookups, isEmpty,
        reason: 'ممنوع بحث حرفي عن جواب العرض: ${h.lookups}');
    expect(
      h.context.unifiedBrainDiagnostics.selectedPrimaryAuthority,
      BrainAuthorityId.respiratory,
      reason: answer,
    );
  }

  group('أ — مرادفات ضيق التنفس تُستخرج', () {
    test('الصيغ العراقية والعربية لنفس العرض', () {
      const interp = RespiratoryInterpreter();
      for (final phrase in [
        'ضيق نفس',
        'ضيق بنفس',
        'ضيق بالتنفس',
        'ضيق بالنفس',
        'ضيق تنفس',
      ]) {
        final i = interp.interpret(phrase);
        expect(i.breathlessness, RespiratoryTriState.present, reason: phrase);
        expect(i.isRespiratoryTurn, isTrue, reason: phrase);
      }
    });
  });

  group('ب — جواب سؤال الخطر داخل جلسة الطفل', () {
    test('«عنده حرارة وضيق بنفس» يُستهلك ولا يبحث', () async {
      final h = _Harness();
      await h.reachDangerQuestion();
      h.lookups.clear();
      final plan = await h.turn('عنده حرارة وضيق بنفس');
      expectConsumedChildContinuation(h, plan, answer: 'عنده حرارة وضيق بنفس');
    });

    test('«حرارة وضيق بنفس» يُستهلك ولا يبحث', () async {
      final h = _Harness();
      await h.reachDangerQuestion();
      h.lookups.clear();
      final plan = await h.turn('حرارة وضيق بنفس');
      expectConsumedChildContinuation(h, plan, answer: 'حرارة وضيق بنفس');
    });

    test('«اي عنده حرارة وضيق بالتنفس» يُستهلك ولا يبحث', () async {
      final h = _Harness();
      await h.reachDangerQuestion();
      h.lookups.clear();
      final plan = await h.turn('اي عنده حرارة وضيق بالتنفس');
      expectConsumedChildContinuation(
        h,
        plan,
        answer: 'اي عنده حرارة وضيق بالتنفس',
      );
    });
  });

  group('ج — بلا جلسة سريرية لا يُختلق طفل', () {
    test('«حرارة وضيق بنفس» لا يرث موضوع ابن من العدم', () async {
      final h = _Harness();
      final plan = await h.turn('حرارة وضيق بنفس');

      expect(h.context.respiratorySession.population,
          isNot(RespiratoryPopulation.child),
          reason: 'ممنوع اختراع طفل بلا ذكر قرابة: ${plan.message}');
      expect(h.context.respiratorySession.lastQuestionKey,
          isNot(anyOf('childAge', 'childAssociated')),
          reason: plan.message);
      expect(plan.message.contains('سعال الطفل'), isFalse, reason: plan.message);
      expect(plan.message.contains('صار له يومين'), isFalse,
          reason: plan.message);
      expect(plan.message.contains('ما لقيت نتيجة مطابقة'), isFalse,
          reason: plan.message);
    });
  });

}
