import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/doctor_target_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

SmartSearchResult _doc(
  String id,
  String title, {
  String specialty = 'طب الأطفال',
  String? phone = '0770',
  String? whatsapp = '0770',
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty,
    doctorId: id,
    score: 80,
    specialty: specialty,
    phone: phone,
    whatsapp: whatsapp,
  );
}

SmartSearchResult _lab(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: 'بغداد',
      labId: id,
      labName: title,
      clinicLocation: 'بغداد',
      phone: '0770',
      whatsapp: '0770',
    );

SmartSearchResult _pkg({
  required String id,
  required String labId,
  required String labName,
  required String title,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.package,
    title: title,
    subtitle: labName,
    packageId: id,
    labId: labId,
    labName: labName,
    newPrice: 40000,
  );
}

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late RuleBasedIntentResolver resolver;

  final pedA = _doc('a', 'د. أحمد كاظم');
  final pedB = _doc('b', 'د. علي ناصر');
  final pedC = _doc('c', 'د. كريم جاسم');

  setUp(() {
    ctx = ConversationContext();
    resolver = RuleBasedIntentResolver();
    planner = SmartBrainPlanner(
      doctorLookup: (_) async => const [],
      labLookup: (q) async {
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('حيا')) {
          return [_lab('hayat', 'مختبر الحياة')];
        }
        return [_lab('hayat', 'مختبر الحياة')];
      },
    );
  });

  group('Bare اتصل على قائمة أطباء', () {
    test('اتصل → توضيح + pendingAction=callDoctor → الأول → prepareCall',
        () async {
      ctx.rememberResults(
        [pedA, pedB, pedC],
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      expect(ctx.selectedDoctor, isNull);
      expect(ctx.hasPendingClarification, isTrue);
      expect(ctx.pendingClarification?.pendingAction, isNull);

      final ask = await planner.plan(query: 'اتصل', context: ctx);
      expect(ask.kind, AssistantActionKind.showClarification);
      expect(ask.canExecute, isFalse);
      expect(
        ctx.pendingClarification?.pendingAction,
        AssistantIntent.callDoctor,
      );
      expect(ask.message, contains('الاتصال'));
      expect(ctx.selectedDoctor, isNull);

      final call = await planner.plan(query: 'الأول', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'a');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('اتصل على الأول → prepareCall مباشرة', () async {
      ctx.rememberResults(
        [pedA, pedB, pedC],
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );

      final call = await planner.plan(query: 'اتصل على الأول', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'a');
      expect(
        call.targetResolution?.source,
        DoctorTargetSource.ordinal,
      );
    });
  });

  group('باقة محددة → اتصل بمختبر الأب', () {
    test('باقة محددة ثم اتصل → prepareCall على المختبر', () async {
      ctx.selectPackage(
        _pkg(
          id: 'pkg1',
          labId: 'hayat',
          labName: 'مختبر الحياة',
          title: 'باقة الدم',
        ),
      );
      expect(ctx.activeEntityType, ConversationEntityType.package);

      final plan = await planner.plan(query: 'اتصل', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.type, SmartSearchResultType.lab);
      expect(plan.target?.labId, 'hayat');
      expect(plan.message, contains('مختبر'));
    });
  });

  group('اختارلي باقة / وريني باقة', () {
    test('اختارلي باقة → findPackage', () {
      final intent = resolver.resolve('اختارلي باقة');
      expect(intent.intent, AssistantIntent.findPackage);
    });

    test('وريني باقة → findPackage', () {
      final intent = resolver.resolve('وريني باقة');
      expect(intent.intent, AssistantIntent.findPackage);
    });

    test('جيبلي باقة → findPackage', () {
      final intent = resolver.resolve('جيبلي باقة');
      expect(intent.intent, AssistantIntent.findPackage);
    });

    test('أريد باقة → قائمة عامة بلا اسم باقة', () {
      final intent = resolver.resolve('أريد باقة');
      expect(intent.intent, AssistantIntent.findPackage);
      expect(intent.entities.packageName, isNull);
    });

    test('أريد باقة تحليل → ليست بحث اسم «تحليل»', () {
      final intent = resolver.resolve('أريد باقة تحليل');
      expect(intent.intent, AssistantIntent.findPackage);
      expect(intent.entities.packageName, isNull);
    });

    test('باقة تحليلات / بحثلي عن باقة تحليلات → قائمة عامة بلا اسم', () {
      for (final q in [
        'باقة تحليلات',
        'أريد باقة تحليلات',
        'بحثلي عن باقة تحليلات',
        'ابحثلي عن باقة تحاليل',
      ]) {
        final intent = resolver.resolve(q);
        expect(intent.intent, AssistantIntent.findPackage, reason: q);
        expect(intent.entities.packageName, isNull, reason: q);
      }
    });

    test('أريد باقة الفحص الشامل → يبقى الاسم', () {
      final intent = resolver.resolve('أريد باقة الفحص الشامل');
      expect(intent.intent, AssistantIntent.findPackage);
      expect(intent.entities.packageName, contains('الفحص الشامل'));
    });
  });
}
