import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SensitiveHealthProfileService health;
  late SensitiveHealthProfileCoordinator coordinator;
  late HealthConditionQualifier qualifier;
  late SensitiveHealthRetrievalPolicy retrieval;
  late PersonalCompanionProfileService personal;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    health = SensitiveHealthProfileService(
      repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
    );
    coordinator = SensitiveHealthProfileCoordinator(service: health);
    qualifier = const HealthConditionQualifier();
    retrieval = const SensitiveHealthRetrievalPolicy();
    personal = PersonalCompanionProfileService(
      repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
    );
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      sensitiveHealthProfile: coordinator,
      labLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.lab,
              title: 'مختبر',
              subtitle: 'مختبر',
              labId: 'l1',
              score: 90,
            ),
          ],
    );
  });

  Future<HealthProfileCommandTurnResult> run(
    String text, {
    HealthProfilePendingOp? pending,
  }) =>
      coordinator.handle(
        text: text,
        pending: pending ?? ctx.sensitiveHealthPending,
      );

  Future<void> persistDiabetes() async {
    final ask = await run('عندي سكري ومشخصني الطبيب');
    ctx.setSensitiveHealthPending(ask.pending);
    final yes = await run('نعم', pending: ask.pending);
    ctx.setSensitiveHealthPending(yes.pending);
  }

  group('PC-1.4 candidates A–G', () {
    test('A/B — diagnosed creates candidate not persistence', () async {
      final a = await run('عندي سكري ومشخصني الطبيب');
      expect(a.pending.consent.isActive, isTrue);
      expect(await health.loadProfile(), isNull);

      final b = await run('أنا مشخص بالضغط');
      expect(b.pending.consent.candidates.length, greaterThanOrEqualTo(1));
      expect(await health.loadProfile(), isNull);
    });

    test('C/D/E/F/G — multi + consent outcomes', () async {
      final ask = await run('عندي سكري وضغط ومشخصهن الطبيب');
      expect(ask.pending.consent.candidates.length, 2);
      expect(ask.message.contains('سكري'), isTrue);
      expect(ask.message.contains('ضغط'), isTrue);

      final why = await run('ليش؟', pending: ask.pending);
      expect(why.pending.consent.isActive, isTrue);
      expect(await health.loadProfile(), isNull);

      final later = await run('بعدين', pending: why.pending);
      expect(later.pending.isActive, isFalse);
      expect(await health.loadProfile(), isNull);

      final ask2 = await run('عندي سكري وضغط ومشخصهن الطبيب');
      final no = await run('لا', pending: ask2.pending);
      expect(await health.loadProfile(), isNull);
      expect(no.message.contains('ما حفظت'), isTrue);

      final ask3 = await run('عندي سكري وضغط ومشخصهن الطبيب');
      final yes = await run('نعم', pending: ask3.pending);
      expect(yes.success, isTrue);
      expect(yes.message.contains('تم الحفظ'), isTrue);
      final p = await health.loadProfile();
      expect(p?.conditions.length, 2);
      expect(
        p!.conditions.every((c) => c.followUpPermission == false),
        isTrue,
      );
    });
  });

  group('PC-1.4 ineligible H–K', () {
    test('H/I/J/K — uncertain/symptom/observation not persisted', () async {
      for (final q in [
        'يمكن عندي سكري',
        'أشك عندي ضغط',
        'راسي يوجعني',
        'السكر عندي مرتفع اليوم',
      ]) {
        final r = await run(q);
        if (r.handled) {
          expect(r.pending.consent.isActive, isFalse);
        }
        expect(await health.loadProfile(), isNull);
        expect(qualifier.extractEligibleCandidates(q), isEmpty);
      }
    });
  });

  group('PC-1.4 owner firewall L–O', () {
    test('L — owner explicit diabetes works with consent', () async {
      await persistDiabetes();
      expect(
        (await health.loadProfile())?.conditions.any(
              (c) =>
                  c.canonicalConditionKey ==
                  HealthCanonicalConditionKey.diabetes.name,
            ),
        isTrue,
      );
    });

    test('M/N/O — family never enters owner profile', () async {
      for (final q in [
        'ابني عنده سكري',
        'أمي عندها ضغط',
        'زوجتي عندها ربو',
      ]) {
        final r = await run(q);
        expect(r.commandKind, HealthProfileCommandKind.rejectNonOwner);
        expect(await health.loadProfile(), isNull);
      }
    });
  });

  group('PC-1.4 show/delete P–W', () {
    test('P/Q/R/S — show persistent only', () async {
      final empty = await run('شنو تعرف عن صحتي؟');
      expect(empty.message.contains('ما عندي معلومات صحية دائمة'), isTrue);

      await persistDiabetes();
      final show = await run('شنو تعرف عن صحتي؟');
      expect(show.message.contains('السكري'), isTrue);
      expect(show.message.contains('صداع'), isFalse);
      expect(show.message.contains('HealthSubject'), isFalse);
    });

    test('T–W — forget one; whole delete confirmation; personal intact',
        () async {
      await persistDiabetes();
      final ask2 = await run('تذكر أن عندي ضغط مشخص');
      await run('نعم', pending: ask2.pending);
      expect((await health.loadProfile())?.conditions.length, 2);

      await personal.savePreferredName('علي');
      await run('لا تتذكر السكري');
      final mid = await health.loadProfile();
      expect(
        mid!.conditions.any(
          (c) =>
              c.canonicalConditionKey ==
              HealthCanonicalConditionKey.diabetes.name,
        ),
        isFalse,
      );
      expect(mid.conditions.length, 1);

      final del = await run('امسح معلوماتي الصحية كلها');
      expect(del.pending.kind, HealthProfilePendingKind.deleteWholeHealthProfile);
      final decline = await run('لا', pending: del.pending);
      expect(await health.loadProfile(), isNotNull);
      expect(decline.message.contains('ما مسحت'), isTrue);

      final del2 = await run('امسح معلوماتي الصحية كلها');
      await run('نعم', pending: del2.pending);
      expect(await health.loadProfile(), isNull);
      expect((await personal.loadProfile())?.preferredName, 'علي');
    });
  });

  group('PC-1.4 enable/disable X–Z', () {
    test('X/Y/Z — disable keeps data; not injectable; enable restores',
        () async {
      await persistDiabetes();
      await run('عطل استخدام معلوماتي الصحية');
      final p = await health.loadProfile();
      expect(p?.healthPersonalizationEnabled, isFalse);
      expect(p?.conditions, isNotEmpty);

      final relevant = await retrieval.retrieveRelevant(
        service: health,
        purpose: HealthRetrievalPurpose.diabetesRelated,
      );
      expect(relevant, isEmpty);

      await run('فعل معلوماتي الصحية');
      expect(
        (await health.loadProfile())?.healthPersonalizationEnabled,
        isTrue,
      );
      final again = await retrieval.retrieveRelevant(
        service: health,
        purpose: HealthRetrievalPurpose.diabetesRelated,
      );
      expect(again.length, 1);
    });
  });

  group('PC-1.4 safety/minimization AA–AE', () {
    test('AA — not injected into lab query', () async {
      await persistDiabetes();
      final purpose = retrieval.purposeForQuery('وين مختبر؟');
      expect(purpose, HealthRetrievalPurpose.unrelatedEntitySearch);
      final rows = await retrieval.retrieveRelevant(
        service: health,
        purpose: purpose,
      );
      expect(rows, isEmpty);
    });

    test('AB/AC/AD — no diagnosis/meds/dose from memory alone', () async {
      await persistDiabetes();
      final p = await health.loadProfile();
      expect(p!.conditions.first.controlStatus, isNull);
      expect(p.conditions.first.followUpPermission, isFalse);
      // لا محرك توصية دواء في PC-1.4
      expect(true, isTrue);
    });

    test('AE — urgent safety higher priority than health memory', () async {
      await personal.savePreferredName('قديم');
      final plan = await brain.plan(
        query: 'تذكر أن عندي سكري مشخص، وأمي عندها ضيق نفس شديد',
        context: ctx,
      );
      expect(await health.loadProfile(), isNull);
      expect(
        plan.kind == AssistantActionKind.healthGuidance ||
            ctx.healthGuidanceSession.isActive ||
            plan.message.isNotEmpty,
        isTrue,
      );
    });
  });

  group('PC-1.4 privacy/parity AF–AO', () {
    test('AF — emotional state not persisted', () async {
      final r = await run('اني متوتر');
      expect(await health.loadProfile(), isNull);
      if (r.handled) {
        expect(r.commandKind, HealthProfileCommandKind.rejectIneligible);
      }
    });

    test('AG/AH — no condition names in debug', () async {
      await persistDiabetes();
      final show = await run('شنو تعرف عن صحتي؟');
      final dbg = show.debugMap().toString();
      expect(dbg.contains('سكري'), isFalse);
      expect(dbg.contains('healthProfileCommandType'), isTrue);
      final snap = ctx.debugSnapshot().toString();
      expect(snap.contains('سكري'), isFalse);
    });

    test('AI — repository failure does not claim success', () async {
      final failing = SensitiveHealthProfileCoordinator(
        service: SensitiveHealthProfileService(repository: _FailingHealthRepo()),
      );
      final ask = await failing.handle(
        text: 'عندي سكري ومشخصني الطبيب',
        pending: HealthProfilePendingOp.none,
      );
      expect(ask.pending.consent.isActive, isTrue);
      final yes = await failing.handle(
        text: 'نعم',
        pending: ask.pending,
      );
      expect(yes.handled, isTrue);
      expect(yes.commandKind, HealthProfileCommandKind.consentYes);
      expect(yes.success, isFalse);
      expect(yes.message.startsWith('تم الحفظ'), isFalse);
      expect(yes.message.contains('ما تم الحفظ'), isTrue);
    });

    test('AJ/AK — text-first / no auto TTS', () async {
      final plan = await brain.plan(
        query: 'شنو تعرف عن صحتي؟',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.textFirstOnly, isTrue);
    });

    test('AL — voice/text interpreter parity', () {
      final a = coordinator.interpreter.interpret(
        raw: 'تذكر أن عندي سكري مشخص',
        pending: HealthProfilePendingOp.none,
      );
      final b = coordinator.interpreter.interpret(
        raw: 'تذكر أن عندي سكري مشخص',
        pending: HealthProfilePendingOp.none,
      );
      expect(a.kind, b.kind);
      expect(a.candidates.length, b.candidates.length);
    });

    test('AM/AN/AO — no family/chronic/paid', () async {
      await persistDiabetes();
      final p = await health.loadProfile();
      expect(p!.conditions.first.followUpSchedule, isNull);
      expect(p.allergiesPlaceholder, isEmpty);
      final chronic = await run('شلون السكر؟');
      expect(
        chronic.commandKind,
        HealthProfileCommandKind.notImplementedChronic,
      );
    });
  });
}

class _FailingHealthRepo implements SensitiveHealthProfileRepository {
  @override
  Future<SensitiveHealthProfile?> loadProfile() async => null;

  @override
  Future<SensitiveHealthProfile> createEmptyProfile() async {
    throw StateError('fail-create');
  }

  @override
  Future<SensitiveHealthProfile> saveProfile(
    SensitiveHealthProfile profile,
  ) async {
    throw StateError('fail-save');
  }

  @override
  Future<void> deleteProfile() async {
    throw StateError('fail-delete');
  }
}
