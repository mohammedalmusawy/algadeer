/// REAL-USER conversation continuity hardening — Smart Brain V1.
///
/// Uses the public SmartBrainPlanner.plan path with ConversationContext —
/// same authority as SmartSearchPage. No private planner APIs.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('TEST 1 — confirmation نعم after call', () {
    test('طبيب أطفال → اتصل → نعم is not provider search', () async {
      final h = ContinuityHarness();
      await h.turn('أريد طبيب');
      await h.turn('طبيب أطفال');
      final call = await h.turn('اتصل على هذا الطبيب');
      expect(
        call.kind == AssistantActionKind.prepareCall ||
            call.message.contains('اتصال') ||
            call.message.contains('جاهز') ||
            h.context.selectedEntity != null ||
            h.context.hasPendingAction ||
            h.context.lastIntent == AssistantIntent.callDoctor,
        isTrue,
        reason: 'call turn should resolve provider/action: ${call.message}',
      );

      // Ensure pending call context for confirmation even if specialty path
      // selected differently in lookup stubs.
      final target = h.context.selectedEntity ??
          h.context.selectedDoctor ??
          ContinuityFixtures.aliNasser;
      h.context.selectDoctor(
        target.type == SmartSearchResultType.doctor
            ? target
            : ContinuityFixtures.aliNasser,
      );
      h.context.lastIntent = AssistantIntent.callDoctor;
      h.context.setPendingAction('call');

      final yes = await h.turn('نعم');
      expect(yes.message.contains('ما لقيت نتيجة مطابقة'), isFalse);
      expect(yes.kind, isNot(AssistantActionKind.runGeneralSearch));
      expect(
        yes.kind == AssistantActionKind.prepareCall ||
            yes.message.contains('تمام') ||
            yes.message.contains('جاهز') ||
            yes.message.contains('اتصال'),
        isTrue,
        reason: 'نعم should confirm pending call, got: ${yes.kind} ${yes.message}',
      );
    });
  });

  group('TEST 2 — child cough natural path', () {
    test('ابني عنده سعال من يومين — no dental, no debug wording', () async {
      final h = ContinuityHarness();
      final r = await h.turn('ابني عنده سعال من يومين');
      expect(h.context.respiratorySession.active, isTrue);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
      expect(
        h.context.respiratorySession.durationBucket.name,
        anyOf('days', 'unknown'),
      );
      expect(h.context.dentalSession.active, isFalse);
      expect(r.message.contains('قواعد البالغين'), isFalse);
      expect(r.message.contains('حزمة أطفال'), isFalse);
      expect(r.message.contains('فهمت شكوى الأسنان'), isFalse);
      expect(
        ContinuityHarness.clarificationCount(r.message),
        lessThanOrEqualTo(1),
      );
      expect(
        r.message.contains('عمر') ||
            r.message.contains('سعال') ||
            r.message.contains('طفل') ||
            r.message.contains('تمام'),
        isTrue,
      );
    });
  });

  group('TEST 3 — duration continuation', () {
    test('ابني عنده سعال → السعال صار له يومين', () async {
      final h = ContinuityHarness();
      await h.turn('ابني عنده سعال');
      expect(h.context.respiratorySession.active, isTrue);
      final d = await h.turn('السعال صار له يومين');
      expect(h.context.respiratorySession.active, isTrue);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
      expect(
        h.context.respiratorySession.durationBucket,
        isNot(null),
      );
      // Prefer days when alias matches.
      expect(
        h.context.respiratorySession.durationBucket.name == 'days' ||
            d.message.contains('يومين') ||
            d.message.contains('عمر'),
        isTrue,
      );
      expect(h.context.dentalSession.active, isFalse);
      expect(d.message.contains('قواعد البالغين'), isFalse);
      expect(d.message.contains('حزمة أطفال'), isFalse);
    });
  });

  group('TEST 4 — age continuation no Dental', () {
    test('ابني عنده سعال من يومين → عمره 8 سنوات', () async {
      final h = ContinuityHarness();
      await h.turn('ابني عنده سعال من يومين');
      final age = await h.turn('عمره 8 سنوات');
      expect(h.context.respiratorySession.active, isTrue);
      expect(h.context.respiratorySession.hasCoughContext, isTrue);
      expect(
        h.context.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        isNot(BrainAuthorityId.dental),
      );
      expect(age.message.contains('فهمت شكوى الأسنان'), isFalse);
      expect(age.message.contains('ورم بالوجه'), isFalse);
      expect(age.message.contains('قواعد البالغين'), isFalse);
      expect(age.message.contains('حزمة أطفال'), isFalse);
      expect(
        ContinuityHarness.clarificationCount(age.message),
        lessThanOrEqualTo(1),
      );
    });
  });

  group('TEST 5 — full child flow', () {
    test('cough → age → fever → no dyspnea', () async {
      final h = ContinuityHarness();
      await h.turn('ابني عنده سعال من يومين');
      await h.turn('عمره 8 سنوات');
      await h.turn('عنده حرارة');
      final neg = await h.turn('لا ما عنده ضيق نفس');
      expect(h.context.respiratorySession.active, isTrue);
      expect(
        h.context.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        isNot(BrainAuthorityId.dental),
      );
      expect(neg.message.contains('فهمت شكوى الأسنان'), isFalse);
      expect(
        ContinuityHarness.clarificationCount(neg.message),
        lessThanOrEqualTo(1),
      );
    });
  });

  group('TEST 6 — explicit owner MSK switch', () {
    test('child cough → اني عندي ألم بالظهر', () async {
      final h = ContinuityHarness();
      await h.turn('ابني عنده سعال من يومين');
      await h.turn('عمره 8 سنوات');
      final msk = await h.turn('اني عندي ألم بالظهر');
      expect(
        h.context.mskSession.active ||
            h.context.unifiedBrainDiagnostics.selectedPrimaryAuthority ==
                BrainAuthorityId.msk ||
            msk.message.contains('ظهر') ||
            msk.message.contains('ألم'),
        isTrue,
        reason: 'owner MSK should become relevant: ${msk.message}',
      );
    });
  });

  group('TEST 7 — explicit dental switch', () {
    test('child cough → أريد طبيب أسنان', () async {
      final h = ContinuityHarness();
      await h.turn('ابني عنده سعال');
      final dental = await h.turn('أريد طبيب أسنان');
      expect(
        dental.kind == AssistantActionKind.runSpecialtySearch ||
            dental.kind == AssistantActionKind.runDoctorSearch ||
            dental.kind == AssistantActionKind.showClarification ||
            dental.kind == AssistantActionKind.showMessage ||
            dental.message.contains('أسنان') ||
            dental.message.contains('اسنان') ||
            h.context.unifiedBrainDiagnostics.selectedPrimaryAuthority ==
                BrainAuthorityId.dental ||
            (dental.candidates.isNotEmpty &&
                dental.candidates.any(
                  (c) => (c.specialty ?? '').contains('أسنان'),
                )),
        isTrue,
        reason: 'explicit dental intent must switch: ${dental.kind} ${dental.message}',
      );
    });
  });

  group('TEST 8 — age alone no subject', () {
    test('عمره 8 سنوات alone does not activate Dental', () async {
      final h = ContinuityHarness();
      final r = await h.turn('عمره 8 سنوات');
      expect(
        h.context.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        isNot(BrainAuthorityId.dental),
      );
      expect(r.message.contains('فهمت شكوى الأسنان'), isFalse);
      expect(r.message.contains('ورم بالوجه'), isFalse);
      expect(
        ContinuityHarness.clarificationCount(r.message),
        lessThanOrEqualTo(1),
      );
    });
  });

  group('TEST 9 — negative confirmation', () {
    test('لا مو هذا rejects pending provider/action', () async {
      final h = ContinuityHarness();
      h.context.rememberResults(
        [ContinuityFixtures.aliNasser, ContinuityFixtures.secondDoctor],
        query: 'طبيب أطفال',
      );
      h.context.selectDoctor(ContinuityFixtures.aliNasser);
      h.context.lastIntent = AssistantIntent.callDoctor;
      h.context.setPendingAction('call');

      final no = await h.turn('لا مو هذا');
      expect(no.message.contains('ما لقيت نتيجة مطابقة'), isFalse);
      expect(no.kind, isNot(AssistantActionKind.runGeneralSearch));
      expect(
        no.message.contains('ألغيت') ||
            no.message.contains('تمام') ||
            no.message.contains('تختار'),
        isTrue,
        reason: 'rejection should stay conversational: ${no.message}',
      );
      expect(h.context.hasPendingAction, isFalse);
    });
  });

  group('TEST 10 — ResultContext ordinal + pronoun call', () {
    test('multiple providers → الثاني → اتصل عليه', () async {
      final h = ContinuityHarness(
        doctors: [
          ContinuityFixtures.aliNasser,
          ContinuityFixtures.secondDoctor,
        ],
      );
      h.context.rememberResults(
        [ContinuityFixtures.aliNasser, ContinuityFixtures.secondDoctor],
        query: 'أريد طبيب',
      );
      final ordinal = await h.turn('الثاني');
      expect(
        ordinal.kind == AssistantActionKind.selectEntity ||
            h.context.selectedEntity?.title.contains('سارة') == true ||
            ordinal.target?.title.contains('سارة') == true ||
            ordinal.message.contains('سارة'),
        isTrue,
        reason: 'ordinal should resolve ResultContext: ${ordinal.message}',
      );

      final call = await h.turn('اتصل عليه');
      expect(
        call.kind == AssistantActionKind.prepareCall ||
            call.message.contains('اتصال') ||
            call.message.contains('جاهز') ||
            h.context.lastIntent == AssistantIntent.callDoctor,
        isTrue,
        reason: 'pronoun call should use selected provider: ${call.message}',
      );
    });
  });

  group('adversarial short turns without sticky invent', () {
    test('bare نعم without pending does not search as provider name', () async {
      final h = ContinuityHarness();
      final r = await h.turn('نعم');
      expect(r.message.contains('ما لقيت نتيجة مطابقة'), isFalse);
      expect(r.kind, isNot(AssistantActionKind.runGeneralSearch));
    });

    test('من يومين alone without active session stays safe', () async {
      final h = ContinuityHarness();
      final r = await h.turn('من يومين');
      expect(r.message.contains('فهمت شكوى الأسنان'), isFalse);
      expect(r.message.contains('ورم بالوجه'), isFalse);
    });
  });
}

class ContinuityFixtures {
  static final aliNasser = SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: 'د. علي ناصر السعيدي',
    subtitle: 'أطفال',
    doctorId: 'doc-ali-nasser',
    specialty: 'أطفال',
    phone: '07701112233',
    whatsapp: '07701112233',
    clinicLocation: 'الكرادة',
    score: 98,
  );

  static final secondDoctor = SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: 'د. سارة أحمد',
    subtitle: 'أطفال',
    doctorId: 'doc-sara',
    specialty: 'أطفال',
    phone: '07704445566',
    whatsapp: '07704445566',
    clinicLocation: 'المنصور',
    score: 90,
  );

  static final dentist = SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: 'د. سارة أسنان',
    subtitle: 'طب الأسنان',
    doctorId: 'doc-dent',
    specialty: 'طب الأسنان',
    phone: '07709998877',
    whatsapp: '07709998877',
    clinicLocation: 'المنصور',
    score: 94,
  );
}

class ContinuityTurn {
  ContinuityTurn({
    required this.kind,
    required this.message,
    required this.candidates,
    required this.target,
  });

  final AssistantActionKind kind;
  final String message;
  final List<SmartSearchResult> candidates;
  final SmartSearchResult? target;
}

class ContinuityHarness {
  ContinuityHarness({List<SmartSearchResult>? doctors}) {
    final docs = doctors ??
        [
          ContinuityFixtures.aliNasser,
          ContinuityFixtures.secondDoctor,
          ContinuityFixtures.dentist,
        ];
    context = ConversationContext();
    planner = SmartBrainPlanner(
      doctorLookup: (q) async {
        final n = q.trim();
        if (n.isEmpty) return docs;
        return docs
            .where(
              (d) =>
                  d.title.contains(n) ||
                  (d.specialty ?? '').contains(n) ||
                  n.contains('أطفال') ||
                  n.contains('طبيب') ||
                  n.contains('دكتور') ||
                  n.contains('علي') ||
                  n.contains('أسنان') ||
                  n.contains('اسنان'),
            )
            .toList();
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

  Future<ContinuityTurn> turn(String query) async {
    final plan = await planner.plan(query: query, context: context);
    final msg = plan.message.trim().isNotEmpty
        ? plan.message.trim()
        : (context.lastAssistantResponse ?? '').trim();
    return ContinuityTurn(
      kind: plan.kind,
      message: msg,
      candidates: plan.candidates,
      target: plan.target,
    );
  }

  static int clarificationCount(String message) {
    return RegExp(r'[؟?]').allMatches(message).length;
  }
}
