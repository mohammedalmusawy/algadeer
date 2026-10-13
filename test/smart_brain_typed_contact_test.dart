import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

/// الأخطاء الثلاثة المعروفة قبل الإطلاق:
/// 1) «اتصل بالمختبر» بلا سياق كان يجاوب «تقصد أي طبيب؟».
/// 2) بعد الصيدلية، «اتصل بالمختبر» كان يختار الصيدلية.
/// 3) «مراكز الأشعة» كانت تعتبر «مراكز» اسم مركز.
const _lab = SmartSearchResult(
  type: SmartSearchResultType.lab,
  title: 'مختبر الحياة',
  subtitle: 'الشطرة',
  labId: 'lab-hayat',
  labName: 'مختبر الحياة',
  clinicLocation: 'الشطرة',
  phone: '07700000010',
  whatsapp: '07700000010',
);

const _pharmacy = SmartSearchResult(
  type: SmartSearchResultType.pharmacy,
  title: 'صيدلية الرحاب',
  subtitle: 'الشطرة',
  pharmacyId: 'ph-rehab',
  phone: '07700000020',
  whatsapp: '07700000020',
);

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;

  setUp(() {
    ctx = ConversationContext();
    planner = SmartBrainPlanner(
      doctorLookup: (_) async => const [],
      labLookup: (_) async => const [_lab],
    );
  });

  test('«اتصل بالمختبر» بلا سياق يسأل عن المختبر لا الطبيب', () async {
    final plan = await planner.plan(query: 'اتصل بالمختبر', context: ctx);
    expect(plan.intentResult.intent, AssistantIntent.callLab);
    expect(plan.message.contains('طبيب'), isFalse, reason: plan.message);
    expect(plan.message.contains('مختبر'), isTrue, reason: plan.message);
    expect(plan.kind, isNot(AssistantActionKind.prepareCall));
  });

  test('بعد الصيدلية «اتصل بالمختبر» ما يتصل بالصيدلية', () async {
    ctx.selectPharmacy(_pharmacy);
    final plan = await planner.plan(query: 'اتصل بالمختبر', context: ctx);
    expect(plan.target?.pharmacyId, isNull, reason: plan.message);
    expect(plan.kind, isNot(AssistantActionKind.prepareCall));
    expect(plan.message.contains('صيدلية'), isFalse, reason: plan.message);
    expect(plan.message.contains('مختبر'), isTrue, reason: plan.message);
  });

  test('مختبر ثم صيدلية ثم «اتصل بالمختبر» يتصل بالمختبر نفسه', () async {
    ctx.selectLaboratory(_lab);
    ctx.selectPharmacy(_pharmacy);
    final plan = await planner.plan(query: 'اتصل بالمختبر', context: ctx);
    expect(plan.kind, AssistantActionKind.prepareCall, reason: plan.message);
    expect(plan.target?.labId, 'lab-hayat');
  });

  test('«اتصل بيها» بعد الصيدلية يبقى على الصيدلية', () async {
    ctx.selectPharmacy(_pharmacy);
    final plan = await planner.plan(query: 'اتصل بيها', context: ctx);
    expect(plan.target?.labId, isNull, reason: plan.message);
  });

  group('«مراكز الأشعة» مو اسم', () {
    test('تجهيز الاسم يحذف الجمع والمفرد', () {
      expect(ArabicTextUtils.prepareRadiologyNameQuery('مراكز الأشعة'), '');
      expect(ArabicTextUtils.prepareRadiologyNameQuery('مراكز اشعة'), '');
      expect(ArabicTextUtils.prepareRadiologyNameQuery('مركز الأشعة'), '');
      expect(
        ArabicTextUtils.prepareRadiologyNameQuery('مركز أشعة الحياة'),
        contains('حيا'),
      );
    });

    test('المحلّل يعطي بحث أشعة بلا اسم', () {
      final r = RuleBasedIntentResolver().resolve('مراكز الأشعة');
      expect(r.entities.radiology, isNull);
      expect(r.intent, isNot(AssistantIntent.callRadiology));
    });
  });
}
