// «نعم» الحرّة بلا حالة معلّقة تستهلكها يجب أن تنتهي كإقرار محادثة قصير،
// لا كبحث حرفي عن كلمة «نعم». الاختبارات تحرس أيضاً ألا يسرق هذا الإقرار
// تأكيداً يخص حالة معلّقة حقيقية (اقتراح تصحيح / فعل معلّق / توضيح).
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/doctor_name_matcher.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

const _noMatchReply = 'ما لقيت نتيجة مطابقة حالياً.';
const _yesAck = 'إذا تحب نكمّل، وضّح الطلب — مثلاً اسم الطبيب أو الشكوى.';

/// أطباء المنصة الحقيقيون — لا قوائم مخترعة.
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
final _fleih = _doc(
  'fleih',
  'الدكتور الأستشاري علي فليح جودة',
  specialty: 'الأنف والأذن والحنجرة',
);

const _searchKinds = <AssistantActionKind>[
  AssistantActionKind.runDoctorSearch,
  AssistantActionKind.runGeneralSearch,
  AssistantActionKind.runSpecialtySearch,
  AssistantActionKind.runLabSearch,
  AssistantActionKind.runAnalysisSearch,
];

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
        if (n.contains('السعيدي') || n.contains('اطفال')) return [_saeedi];
        if (n.contains('كسور') || n.contains('عظام')) {
          return [_doc('naji', 'الدكتور ناجي عبدالله الركابي',
              specialty: 'جراحة العظام والكسور')];
        }
        return const [];
      },
    );
  });

  /// يحاكي SmartSearchPage عند صفر نتائج مع اقتراح تصحيح وحيد واثق.
  Future<void> askTypo(String typoQuery) async {
    final plan = await planner.plan(query: typoQuery, context: ctx);
    ctx.rememberResults(
      const [],
      query: typoQuery,
      intent: plan.intentResult.intent,
      assistantResponse: _noMatchReply,
    );
    final suggestion = const DoctorNameMatcher().suggestCorrection(
      query: typoQuery,
      doctors: _index,
    );
    final id = (suggestion?.doctorId ?? '').trim();
    if (suggestion == null || id.isEmpty) return;
    ctx.setPendingDoctorSuggestion(
      PendingDoctorSuggestion(
        doctorId: id,
        doctorName: suggestion.doctorName,
      ),
    );
  }

  group('A — سياق نظيف و«نعم» حرّة', () {
    test('«نعم» بلا حالة معلّقة → إقرار محادثة بلا أي بحث', () async {
      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, _yesAck);
      expect(plan.message, isNot(_noMatchReply));
      expect(plan.canExecute, isFalse);
      expect(_searchKinds, isNot(contains(plan.kind)));
      expect(lookupQueries, isEmpty, reason: 'لا استعلام عن كلمة «نعم»');
      expect(ctx.selectedDoctor, isNull);
    });

    test('صيغ الإيجاب القائمة كلها تُعامَل بنفس الإقرار', () async {
      for (final w in ['اي', 'ايوه', 'اكيد', 'تمام', 'اوكي', 'هيه']) {
        final fresh = ConversationContext();
        final plan = await planner.plan(query: w, context: fresh);
        expect(plan.kind, AssistantActionKind.showMessage, reason: w);
        expect(plan.message, _yesAck, reason: w);
      }
      expect(lookupQueries, isEmpty);
    });

    test('«لا» الحرّة تحتفظ بردّها الطبيعي الموجود أصلاً', () async {
      final plan = await planner.plan(query: 'لا', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, 'تمام. إذا تحتاج شي ثاني گلي.');
    });
  });

  group('B — بعد نتيجة طبيب صحيحة', () {
    test('«أريد طبيب أطفال» ثم «نعم» → إقرار لا «ما لقيت نتيجة مطابقة»',
        () async {
      ctx.rememberResults(
        [_saeedi],
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
        assistantResponse: 'وجدت ${_saeedi.title}.',
      );
      expect(ctx.selectedDoctor?.doctorId, 'saeedi');
      lookupQueries.clear();

      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.message, isNot(_noMatchReply));
      expect(plan.message, _yesAck);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(_searchKinds, isNot(contains(plan.kind)));
      expect(lookupQueries, isEmpty);
    });
  });

  group('C — اقتراح التصحيح يبقى صاحب الأولوية على «نعم»', () {
    test('اقتراح ثم «نعم» → يختار الطبيب المقترح لا إقراراً عاماً', () async {
      await askTypo('علي ناصر السعدي');
      expect(ctx.hasPendingDoctorSuggestion, isTrue);

      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.doctorId, 'saeedi');
      expect(plan.message, isNot(_yesAck));
      expect(ctx.selectedDoctor?.doctorId, 'saeedi');
    });
  });

  group('D — الفعل المعلّق يبقى صاحب الأولوية على «نعم»', () {
    test('pendingAction اتصال ثم «نعم» → تأكيد الاتصال لا إقرار عام', () async {
      ctx.rememberResults([_saeedi], query: 'دكتور علي ناصر السعيدي');
      ctx.lastIntent = AssistantIntent.callDoctor;
      ctx.setPendingAction('call');

      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'saeedi');
      expect(plan.message, isNot(_yesAck));
    });

    test('pendingAction واتساب ثم «نعم» → تأكيد الواتساب', () async {
      ctx.rememberResults([_saeedi], query: 'دكتور علي ناصر السعيدي');
      ctx.lastIntent = AssistantIntent.messageDoctor;
      ctx.setPendingAction('whatsapp');

      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'saeedi');
    });
  });

  group('E — PendingClarification لم يتغيّر', () {
    test('توضيح بخيارين ثم «نعم» → يبقى توضيحاً لا إقراراً عاماً', () async {
      ctx.rememberResults(
        [_saeedi, _fleih],
        query: 'دكتور علي',
        intent: AssistantIntent.doctorSearch,
        clarificationReason: ClarificationReason.ambiguousName,
      );
      expect(ctx.hasPendingClarification, isTrue);

      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, AssistantActionKind.showClarification);
      expect(plan.message, isNot(_yesAck));
      expect(ctx.hasPendingClarification, isTrue);
      expect(ctx.selectedDoctor, isNull);
    });

    test('توضيح بخيارين ثم «الثاني» → يحل المرشّح الثاني كالمعتاد', () async {
      ctx.rememberResults(
        [_saeedi, _fleih],
        query: 'دكتور علي',
        intent: AssistantIntent.doctorSearch,
        clarificationReason: ClarificationReason.ambiguousName,
      );
      final plan = await planner.plan(query: 'الثاني', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(plan.target?.doctorId, 'fleih');
      expect(ctx.hasPendingClarification, isFalse);
    });

    test('توضيح بمرشّح واحد + pendingAction → «نعم» تنفّذ الفعل', () async {
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
      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, AssistantActionKind.prepareCall);
      expect(plan.target?.doctorId, 'saeedi');
    });
  });

  group('F — الطلب الصريح لا يُبتلع كإيجاب حرّ', () {
    test('«نعم اريد طبيب كسور» → بحث اختصاص لا إقرار', () async {
      final plan = await planner.plan(
        query: 'نعم اريد طبيب كسور',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.runSpecialtySearch);
      expect(plan.intentResult.intent, AssistantIntent.specialtySearch);
      expect(plan.message, isNot(_yesAck));
    });

    test('«تمام اريد طبيب أطفال» → بحث اختصاص لا إقرار', () async {
      final plan = await planner.plan(
        query: 'تمام اريد طبيب أطفال',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.runSpecialtySearch);
      expect(plan.message, isNot(_yesAck));
    });
  });

  group('G — استهلاك مرة واحدة ثم إقرار', () {
    test('اقتراح ثم «نعم» ثم «نعم» ثانية → إقرار بلا إعادة اختيار', () async {
      await askTypo('علي ناصر السعدي');
      final first = await planner.plan(query: 'نعم', context: ctx);
      expect(first.kind, AssistantActionKind.selectEntity);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);

      lookupQueries.clear();
      final second = await planner.plan(query: 'نعم', context: ctx);
      expect(second.kind, AssistantActionKind.showMessage);
      expect(second.message, _yesAck);
      expect(lookupQueries, isEmpty);
    });
  });

  group('H — جلسة جديدة', () {
    test('reset() ثم «نعم» → لا اختيار ولا فعل قديم', () async {
      await askTypo('علي ناصر السعدي');
      await planner.plan(query: 'نعم', context: ctx);
      ctx.reset();
      lookupQueries.clear();

      final plan = await planner.plan(query: 'نعم', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message, _yesAck);
      expect(ctx.selectedDoctor, isNull);
      expect(ctx.hasPendingDoctorSuggestion, isFalse);
      expect(lookupQueries, isEmpty);
    });
  });

  group('I — سياق الطبيب لا يُمسح بلا سبب', () {
    test('طبيب محدد ثم «نعم» → يبقى محدداً و«اتصل» بعدها تستهدفه', () async {
      ctx.rememberResults(
        [_saeedi],
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.specialtySearch,
      );
      expect(ctx.selectedDoctor?.doctorId, 'saeedi');

      await planner.plan(query: 'نعم', context: ctx);
      expect(ctx.selectedDoctor?.doctorId, 'saeedi');
      expect(ctx.activeEntityType, ConversationEntityType.doctor);

      lookupQueries.clear();
      final call = await planner.plan(query: 'اتصل', context: ctx);
      expect(call.kind, AssistantActionKind.prepareCall);
      expect(call.target?.doctorId, 'saeedi');
      expect(lookupQueries, isEmpty);
    });
  });
}
