import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/centers/service_center_kind.dart';
import 'package:ghadeer_clinic/centers/service_center_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/intent/unified_entity_discovery.dart';
import 'package:ghadeer_clinic/voice/result_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// عقل الغدير يعرف التمريض المنزلي: كلمات القسم، الاسم، الاتصال والواتساب،
/// وكل ممرض يُضاف من الإدارة ينعرف تلقائياً من الدليل المشترك.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ali = ServiceCenter(
    id: 'sc_nurse_ali',
    kind: ServiceCenterKind.nursing,
    name: 'الممرض علي حسن',
    displayOrder: 0,
    phone: '07700000001',
    whatsapp: '07700000001',
    services: ['زرق إبر', 'تركيب مغذي'],
  );
  const zainab = ServiceCenter(
    id: 'sc_nurse_zainab',
    kind: ServiceCenterKind.nursing,
    name: 'الممرضة زينب كاظم',
    displayOrder: 1,
    phone: '07700000002',
    whatsapp: '07700000002',
    services: ['تضميد جروح'],
  );
  const hidden = ServiceCenter(
    id: 'sc_nurse_hidden',
    kind: ServiceCenterKind.nursing,
    name: 'الممرض المخفي',
    displayOrder: 2,
    isActive: false,
  );
  const optics = ServiceCenter(
    id: 'sc_optics_n',
    kind: ServiceCenterKind.optics,
    name: 'عوينات النور',
  );

  group('ServiceCenterQuery: كلمات التمريض', () {
    test('كلمة ممرض/تمريض أو خدمة + البيت → تمريض منزلي', () {
      for (final q in [
        'ممرض للبيت',
        'اريد ممرضة تجي للبيت',
        'التمريض المنزلي',
        'وين الممرض',
        'ممرضين',
        'زرق ابرة بالبيت',
        'اريد احد يركب مغذي بالبيت',
        'تضميد جرح بالبيت',
        'قياس ضغط بالبيت',
      ]) {
        expect(
          ServiceCenterQuery.kindFor(q),
          ServiceCenterKind.nursing,
          reason: q,
        );
      }
    });

    test('ما يخطف جمل ثانية', () {
      for (final q in [
        'اريد ابره',
        'صيدلية بيها ابر',
        'مختبر الازرق',
        'دكتور ابراهيم',
        'اريد طبيب يجي للبيت',
        'عندي جرح',
        'عندي ضغط',
        'نزيف شديد',
      ]) {
        expect(ServiceCenterQuery.kindFor(q), isNull, reason: q);
      }
      // الأقسام القديمة ما تغيّرت.
      expect(
        ServiceCenterQuery.kindFor('اريد عوينات'),
        ServiceCenterKind.optics,
      );
      expect(
        ServiceCenterQuery.kindFor('مركز تجميل'),
        ServiceCenterKind.beauty,
      );
      expect(ServiceCenterQuery.kindFor('دكتور عيون'), isNull);
      expect(ServiceCenterQuery.nameHint('اتصل بعوينات الشطرة'), 'الشطره');
    });

    test('الاسم يبقى (حتى «علي») وكلام الطلب ينحذف', () {
      expect(ServiceCenterQuery.nameHint('اتصل بالممرض علي'), 'علي');
      expect(ServiceCenterQuery.nameHint('الممرضة زينب'), 'زينب');
      expect(ServiceCenterQuery.nameHint('دز للممرضة زينب واتساب'), 'زينب');
      expect(ServiceCenterQuery.nameHint('اريد ممرض يجي للبيت'), isNull);
      expect(
        ServiceCenterQuery.nameHint('ممرضة تركب كانيولا لامي بالبيت'),
        isNull,
      );
      expect(ServiceCenterQuery.nameHint('زرق ابرة بالبيت'), isNull);
    });
  });

  group('محلّل النية', () {
    final resolver = RuleBasedIntentResolver();

    test('بحث / اتصال / واتساب ممرض', () {
      expect(
        resolver.resolve('اريد ممرض للبيت').intent,
        AssistantIntent.findNursing,
      );
      final call = resolver.resolve('اتصل بالممرض علي');
      expect(call.intent, AssistantIntent.callNursing);
      expect(call.entities.nursing, 'علي');
      expect(
        resolver.resolve('دز واتساب للممرضة زينب').intent,
        AssistantIntent.messageNursing,
      );
      // العوينات والتجميل على حالها.
      expect(resolver.resolve('العوينات').intent, AssistantIntent.findOptics);
      expect(
        resolver.resolve('مراكز التجميل').intent,
        AssistantIntent.findBeauty,
      );
    });
  });

  test('الممرض يصير نتيجة بحث من نوعه', () {
    final r = ali.toSearchResult();
    expect(r.type, SmartSearchResultType.nursing);
    expect(r.nursingId, 'sc_nurse_ali');
    expect(r.beautyId, isNull);
    expect(r.opticsId, isNull);
    expect(r.hasNavigableEntity, isTrue);
  });

  // حارس للمستقبل: أي قسم دليل جديد يُضاف لـ ServiceCenterKind لازم العقل
  // يفهم اسمه ويعرف نوع نتيجته، وإلا يفشل هذا الاختبار قبل الإطلاق.
  test('كل أقسام الدليل معروفة لعقل الغدير', () {
    for (final kind in ServiceCenterKind.values) {
      expect(
        ServiceCenterQuery.kindFor(kind.sectionTitle),
        kind,
        reason: kind.name,
      );
      final r = ServiceCenter(
        id: 'guard_${kind.name}',
        kind: kind,
        name: 'x',
      ).toSearchResult();
      expect(r.hasNavigableEntity, isTrue, reason: kind.name);
      final type = EntityActionCompatibility.fromResultType(r.type);
      expect(type, isNotNull, reason: kind.name);
      expect(
        EntityActionCompatibility.supportsCall(type!),
        isTrue,
        reason: kind.name,
      );
      expect(
        UnifiedEntityDiscovery.fromResult(r).entityType,
        type,
        reason: kind.name,
      );
    }
  });

  group('المخطِّط مع الدليل المشترك', () {
    late ConversationContext ctx;
    late SmartBrainPlanner planner;

    setUp(() {
      // بالاختبار ما في Supabase → المتجر يقرأ آخر نسخة محفوظة بالجهاز،
      // نفس ما يصير للزائر بلا إنترنت. ممرض جديد = صف جديد هنا فقط.
      SharedPreferences.setMockInitialValues({
        'service_centers_shared_cache_v1': jsonEncode(
          [ali, zainab, hidden, optics].map((e) => e.toMap()).toList(),
        ),
      });
      ctx = ConversationContext();
      planner = SmartBrainPlanner(
        doctorLookup: (_) async => const [],
        labLookup: (_) async => const [],
      );
    });

    test('«اريد ممرض للبيت» → قائمة الممرضين النشطين فقط', () async {
      final plan = await planner.plan(query: 'اريد ممرض للبيت', context: ctx);
      expect(plan.kind, AssistantActionKind.runGeneralSearch);
      expect(plan.message, contains('التمريض المنزلي'));
      expect(plan.candidates.map((c) => c.nursingId), [
        'sc_nurse_ali',
        'sc_nurse_zainab',
      ]);
      expect(
        plan.candidates.every((c) => c.type == SmartSearchResultType.nursing),
        isTrue,
      );
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.nursing,
      );
    });

    test('«اتصل بالممرض علي» → جاهز للاتصال بعلي', () async {
      final plan = await planner.plan(query: 'اتصل بالممرض علي', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.nursingId, 'sc_nurse_ali');
      expect(ctx.activeEntityType, ConversationEntityType.nursing);
    });

    test('«دز واتساب للممرضة زينب» → واتساب زينب', () async {
      final plan = await planner.plan(
        query: 'دز واتساب للممرضة زينب',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.nursingId, 'sc_nurse_zainab');
    });

    test('اسم غير موجود → ما يخترع ممرض', () async {
      final plan = await planner.plan(query: 'اتصل بالممرض كريم', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.target, isNull);
    });
  });
}
