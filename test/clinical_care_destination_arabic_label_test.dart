/// تسمية وجهة الرعاية بالعربية — منع تسرّب اسم القيمة الإنجليزي للمستخدم.
///
/// العطل: سطر «حسب الوجهة المناسبة: …» كان يطبع `destinationType?.name`، أي
/// المعرّف الإنجليزي الخام (`generalPractitioner`, `selfCare`, `physiotherapy`…)
/// داخل جملة عربية. الإصلاح: `ClinicalCareDestination.arabicLabel` كمصدر واحد.
///
/// الحارس الأهم هنا هو اختبار الشمول: أي قيمة جديدة تُضاف للتعداد بلا تسمية
/// عربية تُسقط الاختبار فوراً.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/clinical_knowledge.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// أي حرف لاتيني = تسرّب اسم إنجليزي.
final _asciiLetter = RegExp(r'[A-Za-z]');

/// أسماء القيم الخام — ممنوعة في أي نص يُعرض للمستخدم.
final _rawEnumNames =
    ClinicalCareDestination.values.map((d) => d.name).toList(growable: false);

void _expectNoRawEnumName(String message) {
  for (final raw in _rawEnumNames) {
    expect(
      message.contains(raw),
      isFalse,
      reason: 'تسرّب اسم التعداد «$raw» في نص المستخدم: $message',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('أ — التسميات العربية تغطي كل قيم التعداد', () {
    test('كل قيمة لها تسمية عربية غير فارغة وبلا حروف لاتينية', () {
      expect(ClinicalCareDestination.values, hasLength(12),
          reason: 'تغيّر التعداد — راجع التسميات');

      for (final destination in ClinicalCareDestination.values) {
        final label = destination.arabicLabel;
        expect(label.trim(), isNotEmpty, reason: destination.name);
        expect(
          _asciiLetter.hasMatch(label),
          isFalse,
          reason: 'تسمية ${destination.name} تحتوي حروفاً لاتينية: $label',
        );
        expect(label, isNot(equals(destination.name)), reason: destination.name);
      }
    });

    test('التسميات متوافقة مع النصوص القائمة بالحزم', () {
      // نفس صياغة `dental_response_builder` و`pregnancy_response_builder`.
      expect(ClinicalCareDestination.dentist.arabicLabel, 'طبيب أسنان');
      expect(
        ClinicalCareDestination.obstetricsGynecology.arabicLabel,
        'نسائية وتوليد',
      );
      // نفس نص السقوط القائم عند غياب الوجهة.
      expect(ClinicalCareDestination.other.arabicLabel, 'تقييم سريري عام');
    });
  });

  group('ب — جواب التوجيه التنفسي', () {
    late RespiratoryGuidanceCoordinator resp;
    late ConversationContext ctx;

    setUp(() {
      resp = RespiratoryGuidanceCoordinator();
      ctx = ConversationContext();
    });

    Future<RespiratoryTurnResult> run(String text) async {
      final r = await resp.handle(text: text, session: ctx.respiratorySession);
      ctx.setRespiratorySession(r.session);
      return r;
    }

    test('سطر الوجهة عربي بالكامل بلا اسم تعداد', () async {
      await run('عندي سعال من اسبوعين');
      await run('اي عندي بلغم');
      final r = await run('وين اروح');

      // هذا السياق يحسم الوجهة فعلاً — وإلا كان الحارس فارغاً.
      expect(ctx.respiratorySession.destinationType,
          ClinicalCareDestination.generalPractitioner);

      expect(r.message.contains('الوجهة المناسبة: طبيب عام.'), isTrue,
          reason: r.message);
      _expectNoRawEnumName(r.message);
    });

    test('غياب الوجهة يبقي السقوط «تقييم سريري عام»', () async {
      await run('عندي سعال');
      final r = await run('وين اروح');

      expect(ctx.respiratorySession.destinationType, isNull,
          reason: 'الشرط المسبق: بلا وجهة محسومة');
      expect(r.message.contains('تقييم سريري عام'), isTrue,
          reason: r.message);
      _expectNoRawEnumName(r.message);
    });
  });

  group('ج — جواب التوجيه العظمي', () {
    late MskGuidanceCoordinator msk;
    late ConversationContext ctx;

    setUp(() {
      msk = MskGuidanceCoordinator();
      ctx = ConversationContext();
    });

    Future<MskTurnResult> run(String text) async {
      final r = await msk.handle(text: text, session: ctx.mskSession);
      ctx.setMskSession(r.session);
      return r;
    }

    test('سطر الوجهة عربي بالكامل بلا اسم تعداد', () async {
      await run('عندي ألم بالظهر');
      await run('صار له اسبوعين');
      final r = await run('وين اروح');

      expect(ctx.mskSession.destinationType,
          ClinicalCareDestination.selfCare);

      expect(r.message.contains('الوجهة المناسبة: رعاية منزلية.'), isTrue,
          reason: r.message);
      _expectNoRawEnumName(r.message);
    });
  });

  group('د — المسار الحقيقي عبر SmartBrainPlanner', () {
    test('«وين توجهني» يرجع سطر وجهة عربياً بلا اسم تعداد', () async {
      SharedPreferences.setMockInitialValues({});
      final lookups = <String>[];
      final planner = SmartBrainPlanner(
        doctorLookup: (q) async {
          lookups.add(q);
          return const [];
        },
        labLookup: (_) async => const [],
        analysisLookup: (_) async => const [],
        packagesLookup: (_) async => const [],
        packagesForAnalysisLookup: (_) async => const [],
        activePackagesLookup: ({labId, nameQuery}) async => const [],
        discountedPackagesLookup: ({labId}) async => const [],
      );
      final context = ConversationContext();
      Future<AssistantActionPlan> turn(String q) =>
          planner.plan(query: q, context: context);

      // نفس تمهيد `contextual_care_direction_followup_test`.
      await turn('علي ناصر السعدي');
      await turn('اني عندي سعال من اسبوعين');
      await turn('اي عندي بلغم');
      expect(context.respiratorySession.active, isTrue);

      final plan = await turn('وين توجهني');
      expect(plan.message.contains('الوجهة المناسبة: طبيب عام.'), isTrue,
          reason: plan.message);
      _expectNoRawEnumName(plan.message);
      expect(plan.message.contains('ما لقيت نتيجة مطابقة'), isFalse);
    });
  });
}
