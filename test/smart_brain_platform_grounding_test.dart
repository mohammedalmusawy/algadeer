import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/conversation/smart_brain_suggested_actions.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/platform_grounding.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CRITICAL: بيانات الغدير فقط — lookup فارغ → NO_RESULT بلا اختراع.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  SmartBrainPlanner emptyPlatform() => SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
        packagesLookup: (_) async => const [],
        analysisLookup: (_) async => const [],
        activePackagesLookup: ({String? labId, String? nameQuery}) async =>
            const [],
        discountedPackagesLookup: ({String? labId}) async => const [],
      );

  void expectFailClosed(AssistantActionPlan plan, {required String reason}) {
    expect(
      plan.kind,
      anyOf(
        AssistantActionKind.showMessage,
        AssistantActionKind.showClarification,
        AssistantActionKind.none,
      ),
      reason: reason,
    );
    expect(plan.canExecute, isFalse, reason: '$reason · canExecute');
    expect(
      plan.kind,
      isNot(AssistantActionKind.prepareCall),
      reason: reason,
    );
    expect(
      plan.kind,
      isNot(AssistantActionKind.prepareWhatsApp),
      reason: reason,
    );
    expect(
      plan.kind,
      isNot(AssistantActionKind.openProfile),
      reason: reason,
    );
    expect(
      PlatformGrounding.looksLikeHallucinatedProvider(plan.message),
      isFalse,
      reason: '$reason · ${plan.message}',
    );
    expect(plan.message, isNot(contains(RegExp(r'07\d{8,}'))), reason: reason);
  }

  group('PlatformGrounding helpers', () {
    test('fromResults فارغ → noResults بلا أزرار', () {
      final g = PlatformGrounding.fromResults(text: '', results: const []);
      expect(g.outcome, PlatformGroundingOutcome.noResults);
      expect(g.sourceEntityIds, isEmpty);
      expect(g.suggestedActions, isEmpty);
      expect(g.text, PlatformGrounding.noResultsMessage);
    });

    test('fromResults مع كيان → sourceEntityIds + actions من البيانات', () {
      final doc = SmartSearchResult(
        type: SmartSearchResultType.doctor,
        title: 'د. ناجي',
        subtitle: 'عظام',
        doctorId: 'naji',
        phone: '07701234567',
      );
      final g = PlatformGrounding.fromResults(
        text: 'وجدت نتيجة.',
        results: [doc],
        resultType: PlatformGroundedResultType.doctor,
      );
      expect(g.outcome, PlatformGroundingOutcome.ok);
      expect(g.sourceEntityIds, ['naji']);
      expect(
        g.suggestedActions.any(
          (a) => a.kind == SmartBrainSuggestedActionKind.call,
        ),
        isTrue,
      );
    });

    test('بدون هاتف → لا زر واتساب/اتصال في builder', () {
      final doc = SmartSearchResult(
        type: SmartSearchResultType.doctor,
        title: 'د. ناجي',
        subtitle: 'عظام',
        doctorId: 'naji',
      );
      final actions = SmartBrainSuggestedActionsBuilder.forResults([doc]);
      expect(
        actions.any((a) => a.kind == SmartBrainSuggestedActionKind.call),
        isFalse,
      );
      expect(
        actions.any((a) => a.kind == SmartBrainSuggestedActionKind.whatsapp),
        isFalse,
      );
    });
  });

  group('empty lookups — لا اختراع مزودين', () {
    test('طبيب غير موجود بالمنصة', () async {
      final plan = await emptyPlatform().plan(
        query: 'اتصل بالدكتور فلان الوهمي',
        context: ConversationContext(),
      );
      expectFailClosed(plan, reason: 'doctor missing');
      expect(plan.target, isNull);
      expect(plan.message, contains('منصة الغدير'));
    });

    test('مختبر غير موجود', () async {
      final plan = await emptyPlatform().plan(
        query: 'واتساب مختبر السحاب الخيالي',
        context: ConversationContext(),
      );
      expectFailClosed(plan, reason: 'lab missing');
      expect(plan.target?.labId, isNull);
    });

    test('صيدلية غير موجودة', () async {
      final plan = await emptyPlatform().plan(
        query: 'اتصل بصيدلية القمر الخيالية',
        context: ConversationContext(),
      );
      expectFailClosed(plan, reason: 'pharmacy missing');
      expect(plan.target?.pharmacyId, isNull);
      expect(plan.message, contains('منصة الغدير'));
    });

    test('أشعة غير موجودة', () async {
      final plan = await emptyPlatform().plan(
        query: 'واتساب أشعة النجوم الوهمية',
        context: ConversationContext(),
      );
      expectFailClosed(plan, reason: 'radiology missing');
      expect(plan.target?.radiologyId, isNull);
    });

    test('بحث صيدلية عام مع كتالوج فارغ', () async {
      final plan = await emptyPlatform().plan(
        query: 'ابحثلي عن صيدلية',
        context: ConversationContext(),
      );
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.showMessage,
          AssistantActionKind.runGeneralSearch,
        ),
      );
      if (plan.kind == AssistantActionKind.runGeneralSearch) {
        expect(plan.candidates, isEmpty);
      }
      expect(
        PlatformGrounding.looksLikeHallucinatedProvider(plan.message),
        isFalse,
      );
    });

    test('باقة غير موجودة', () async {
      final plan = await emptyPlatform().plan(
        query: 'باقة الفحص الفضائي',
        context: ConversationContext(),
      );
      expect(
        plan.kind,
        anyOf(
          AssistantActionKind.showMessage,
          AssistantActionKind.showClarification,
          AssistantActionKind.runPackageSearch,
          AssistantActionKind.runGeneralSearch,
          AssistantActionKind.none,
        ),
      );
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(
        PlatformGrounding.looksLikeHallucinatedProvider(plan.message),
        isFalse,
      );
    });
  });

  group('field unavailable — لا تخمين رقم/موقع', () {
    test('صيدلية بلا رقم → لا prepareCall', () async {
      final mute = SmartSearchResult(
        type: SmartSearchResultType.pharmacy,
        title: 'صيدلية رحاب',
        subtitle: 'صيدلية',
        pharmacyId: 'rehab',
        // بلا phone / whatsapp
      );
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        pharmacyLookup: (_) async => [mute],
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
      );
      final plan = await planner.plan(
        query: 'اتصل بصيدلية رحاب',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.message, contains('غير متوفر'));
      expect(plan.message, isNot(contains(RegExp(r'07\d{8,}'))));
    });

    test('موقع فارغ → لا showLocation قابل للتنفيذ', () async {
      final noLoc = SmartSearchResult(
        type: SmartSearchResultType.doctor,
        title: 'د. ناجي',
        subtitle: 'عظام',
        doctorId: 'naji',
        phone: '07701111111',
      );
      final ctx = ConversationContext();
      ctx.selectDoctor(noLoc);
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        doctorLookup: (_) async => [noLoc],
        labLookup: (_) async => const [],
        radiologyLookup: (_) async => const [],
        pharmacyLookup: (_) async => const [],
      );
      final plan = await planner.plan(
        query: 'وين عيادته؟',
        context: ctx,
      );
      // إما رسالة عدم توفر أو showLocation مُبطَل بالـ enforce
      if (plan.kind == AssistantActionKind.showLocation) {
        fail('must not execute location without clinicLocation');
      }
      expect(plan.canExecute, isFalse);
      expect(
        PlatformGrounding.looksLikeHallucinatedProvider(plan.message),
        isFalse,
      );
    });
  });
}
