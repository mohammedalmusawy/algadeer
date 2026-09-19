import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/doctor_name_matcher.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/context_resolver.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

/// أطباء المنصة الحقيقيون (نفس صفوف Supabase) — لا قوائم مخترعة.
const _index = <({String id, String name})>[
  (id: 'aswar', name: 'الدكتورة اساور زين العابدين المصور'),
  (id: 'miaad', name: 'الدكتورة ميعاد جاسم محمد'),
  (id: 'haidar', name: 'الدكتور حيدر حسن الشمخاوي'),
  (id: 'naji', name: 'الدكتور ناجي عبدالله الركابي'),
  (id: 'fleih', name: 'الدكتور الأستشاري علي فليح جودة'),
  (id: 'saeedi', name: 'الدكتور علي ناصر السعيدي'),
];

SmartSearchResult _doc(String id, String title, {String? specialty}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: specialty ?? 'اختصاص',
    doctorId: id,
    score: 96,
    specialty: specialty,
    clinicLocation: 'الكرادة',
    phone: '07700000000',
    whatsapp: '07700000000',
  );
}

final _saeedi = _doc(
  'saeedi',
  'الدكتور علي ناصر السعيدي',
  specialty: 'طب الأطفال',
);
final _naji = _doc(
  'naji',
  'الدكتور ناجي عبدالله الركابي',
  specialty: 'جراحة العظام والمفاصل والكسور',
);

void main() {
  late ConversationContext ctx;
  late SmartBrainPlanner planner;
  late List<String> lookupQueries;

  setUp(() {
    ctx = ConversationContext();
    lookupQueries = <String>[];
    planner = SmartBrainPlanner(
      doctorLookup: (q) async {
        lookupQueries.add(q);
        final n = ArabicTextUtils.normalize(q);
        if (n.contains('السعيدي')) return [_saeedi];
        if (n.contains('كسور') || n.contains('عظام')) return [_naji];
        return const [];
      },
    );
  });

  /// يحاكي ما تفعله SmartSearchPage بعد صفر نتائج: يثبّت نتائج الدور الفارغة
  /// ثم يخزّن اقتراحاً معلّقاً فقط إن كان المرشّح وحيداً وواثقاً.
  Future<String?> askTypo(
    String typoQuery, {
    List<({String id, String name})> doctors = _index,
  }) async {
    final plan = await planner.plan(query: typoQuery, context: ctx);
    ctx.rememberResults(
      const [],
      query: typoQuery,
      intent: plan.intentResult.intent,
      assistantResponse: 'ما لقيت نتيجة مطابقة حالياً.',
    );
    final suggestion = const DoctorNameMatcher().suggestCorrection(
      query: typoQuery,
      doctors: doctors,
    );
    final id = (suggestion?.doctorId ?? '').trim();
    if (suggestion == null || id.isEmpty) return null;
    ctx.setPendingDoctorSuggestion(
      PendingDoctorSuggestion(
        doctorId: id,
        doctorName: suggestion.doctorName,
      ),
    );
    return ArabicTextUtils.stripHonorifics(suggestion.doctorName).trim();
  }

  group('A — تأكيد اقتراح التصحيح بـ«نعم»', () {
    test('«علي ناصر السعدي» ثم «نعم» → يحل د. علي ناصر السعيدي', () async {
      final label = await askTypo('علي ناصر السعدي');
      expect(label, 'علي ناصر السعيدي');
      expect(ctx.hasPendingDoctorSuggestion, isTrue);
      expect(ctx.pendingDoctorSuggestion!.doctorId, 'saeedi');
      // الاقتراح عرض فقط — لا طبيب مختار قبل التأكيد.
      expect(ctx.selectedDoctor, isNull);

      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.doctorId, 'saeedi');
      expect(ctx.selectedDoctor?.doctorId, 'saeedi');
      expect(ctx.activeEntityType, ConversationEntityType.doctor);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
    });

    test('«نعم» لا تفتح اتصالاً ولا واتساب — اختيار فقط', () async {
      await askTypo('علي ناصر السعدي');
      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.prepareCall));
      expect(plan.kind, isNot(AssistantActionKind.prepareWhatsApp));
      expect(
        plan.contextResolution?.status,
        ContextResolutionStatus.selectResult,
      );
    });
  });

  group('B — صيغ الإيجاب الموجودة أصلاً', () {
    test('«اي» بعد الاقتراح تحل نفس الطبيب', () async {
      await askTypo('علي ناصر السعدي');
      final plan = await planner.plan(query: 'اي', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedDoctor?.doctorId, 'saeedi');
    });

    test('«اكيد» بعد الاقتراح تحل نفس الطبيب', () async {
      await askTypo('علي ناصر السعدي');
      final plan = await planner.plan(query: 'اكيد', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedDoctor?.doctorId, 'saeedi');
    });
  });

  group('C — «لا» تلغي الاقتراح', () {
    test('اقتراح ثم «لا» → لا اختيار ويُمسح الاقتراح', () async {
      await askTypo('علي ناصر السعدي');
      final plan = await planner.plan(query: 'لا', context: ctx);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(ctx.selectedDoctor, isNull);
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(plan.message, isNotEmpty);
    });
  });

  group('D — بحث جديد صريح يتغلّب على الاقتراح', () {
    test('اقتراح ثم «اريد طبيب كسور» → بحث اختصاص جديد بلا خطف', () async {
      await askTypo('علي ناصر السعدي');
      final plan = await planner.plan(query: 'اريد طبيب كسور', context: ctx);
      expect(plan.kind, AssistantActionKind.runSpecialtySearch);
      expect(plan.intentResult.intent, AssistantIntent.specialtySearch);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(ctx.selectedDoctor, isNull);
    });
  });

  group('E/F — المتابعات القائمة بعد التأكيد', () {
    test('اقتراح ثم «نعم» ثم «ارسل واتساب» → الهدف هو نفس الطبيب', () async {
      await askTypo('علي ناصر السعدي');
      await planner.plan(query: 'نعم', context: ctx);
      final plan = await planner.plan(query: 'ارسل واتساب', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'saeedi');
    });

    test('اقتراح ثم «نعم» ثم «اتصل» → الاتصال بنفس الطبيب', () async {
      await askTypo('علي ناصر السعدي');
      await planner.plan(query: 'نعم', context: ctx);
      final plan = await planner.plan(query: 'اتصل', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'saeedi');
    });
  });

  group('G — لا تأكيد قديم في جلسة جديدة', () {
    test('سياق نظيف + «نعم» → لا يختار أي طبيب سابق', () async {
      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(ctx.selectedDoctor, isNull);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
    });

    test('reset() بعد الاقتراح يمسحه فلا يتسرّب لجلسة أخرى', () async {
      await askTypo('علي ناصر السعدي');
      expect(ctx.hasPendingDoctorSuggestion, isTrue);
      ctx.reset();
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(ctx.selectedDoctor, isNull);
    });
  });

  group('H — استهلاك مرة واحدة', () {
    test('«نعم» ثانية بعد القبول لا تعيد استهلاك الاقتراح', () async {
      await askTypo('علي ناصر السعدي');
      await planner.plan(query: 'نعم', context: ctx);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);

      lookupQueries.clear();
      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(
        lookupQueries.where((q) => q.contains('السعيدي')),
        isEmpty,
        reason: 'لا إعادة حل لاقتراح مستهلك',
      );
    });

    test('«لا» ثم «نعم» لا تعيد إحياء الاقتراح', () async {
      await askTypo('علي ناصر السعدي');
      await planner.plan(query: 'لا', context: ctx);
      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(ctx.selectedDoctor, isNull);
    });
  });

  group('I — لا حالة معلّقة عند غياب مرشّح وحيد واثق', () {
    test('تشابه مع طبيبين → لا اقتراح ولا حالة معلّقة', () async {
      const twins = <({String id, String name})>[
        (id: 'a', name: 'علي ناصر السعيدي'),
        (id: 'b', name: 'علي ناصر السعودي'),
      ];
      final label = await askTypo('علي ناصر السعدي', doctors: twins);
      expect(label, isNull);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);

      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, isNot(AssistantActionKind.selectEntity));
      expect(ctx.selectedDoctor, isNull);
    });

    test('اسم مفرد أو فهرس فارغ → لا حالة معلّقة', () async {
      expect(await askTypo('السعدي'), isNull);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(await askTypo('علي ناصر السعدي', doctors: const []), isNull);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
    });
  });

  group('J — pendingAction التنفيذي يبقى مستقلاً', () {
    test('توضيح بمرشّح واحد + pendingAction اتصال → «نعم» تنفّذ الاتصال',
        () async {
      ctx.setPendingClarification(
        PendingClarification(
          entityType: ClarificationEntityType.doctor,
          reason: ClarificationReason.incompleteReference,
          pendingAction: AssistantIntent.callDoctor,
          candidates: [
            ClarificationCandidate(
              id: 'saeedi',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: _saeedi.title,
              secondaryLabel: _saeedi.specialty,
              payload: _saeedi,
            ),
          ],
        ),
      );
      expect(ctx.hasPendingDoctorSuggestion, isFalse);

      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'saeedi');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('اقتراح تصحيح معلّق لا يغيّر pendingAction ولا يلمس التوضيح', () async {
      await askTypo('علي ناصر السعدي');
      expect(ctx.hasPendingClarification, isFalse);
      expect(ctx.pendingAction, isNull);
      expect(ctx.lastResults, isEmpty);
    });
  });
}
