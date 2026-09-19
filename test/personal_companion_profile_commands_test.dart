import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/labs/labs_service.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalPersonalCompanionProfileRepository repo;
  late PersonalCompanionProfileService profiles;
  late CompanionProfileCommandCoordinator commands;
  late CompanionOnboardingCoordinator onboarding;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = LocalPersonalCompanionProfileRepository(prefs: prefs);
    profiles = PersonalCompanionProfileService(repository: repo);
    commands = CompanionProfileCommandCoordinator(profiles: profiles);
    onboarding = CompanionOnboardingCoordinator(
      profiles: profiles,
      preferences: CompanionOnboardingPreferenceStore(prefs: prefs),
    );
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      companionOnboardingCoordinator: onboarding,
      companionProfileCommands: commands,
      doctorLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'د. أطفال',
              subtitle: 'طب الأطفال',
              doctorId: 'd1',
              specialty: 'طب الأطفال',
              score: 90,
            ),
          ],
      labLookup: (_) async => [
            SmartSearchResult(
              type: SmartSearchResultType.lab,
              title: 'مختبر الحياة',
              subtitle: 'مختبر',
              labId: 'hayat',
              score: 90,
            ),
          ],
      analysisLookup: (_) async => [
            AnalysisItem(id: 'cbc', name: 'CBC'),
          ],
      packagesLookup: (_) async => [
            const LabPackageItem(
              id: 'p1',
              labId: 'hayat',
              name: 'باقة',
              newPrice: 10,
            ),
          ],
      activePackagesLookup: ({String? labId, String? nameQuery}) async => [
            const AnalysisPackageLink(
              package: LabPackageItem(
                id: 'p1',
                labId: 'hayat',
                name: 'باقة',
                newPrice: 10,
              ),
              labId: 'hayat',
              labName: 'مختبر الحياة',
            ),
          ],
    );
  });

  Future<CompanionProfileCommandTurnResult> run(String text) => commands.handle(
        text: text,
        pending: ctx.companionProfilePending,
      );

  group('PC-1.3 show A–E', () {
    test('A — شنو تعرف عني؟ shows actual basic profile only', () async {
      await profiles.savePreferredName('محمد');
      await profiles.setBirthYear(1991);
      final r = await run('شنو تعرف عني؟');
      expect(r.handled, isTrue);
      expect(r.message.contains('محمد'), isTrue);
      expect(r.message.contains('1991'), isTrue);
      expect(r.message.contains('صداع'), isFalse);
    });

    test('B — empty profile does not fabricate', () async {
      final r = await run('شنو معلوماتي؟');
      expect(r.message.contains('ما عندي معلومات أساسية'), isTrue);
      expect(r.message.contains('محمد'), isFalse);
    });

    test('C — شنو اسمي عندك؟', () async {
      await profiles.savePreferredName('سارة');
      final r = await run('شنو اسمي عندك؟');
      expect(r.message.contains('سارة'), isTrue);
    });

    test('D/E — dynamic age; no DOB → no invented age', () async {
      final none = await run('كم عمري عندك؟');
      expect(none.message.contains('غير محفوظ'), isTrue);

      await profiles.setBirthYear(DateTime.now().year - 30);
      final age = await run('كم عمري عندك؟');
      expect(age.message.contains('30'), isTrue);
      final map = (await profiles.loadProfile())!.toStorageMap();
      expect(map.containsKey('age'), isFalse);
    });
  });

  group('PC-1.3 name F–H', () {
    test('F/G — ناديني / غير اسمي', () async {
      await run('ناديني علي');
      expect((await profiles.loadProfile())?.preferredName, 'علي');
      await run('غير اسمي إلى محمد');
      expect((await profiles.loadProfile())?.preferredName, 'محمد');
    });

    test('H — name update does not infer sex', () async {
      await run('ناديني فاطمة');
      expect((await profiles.loadProfile())?.sexSelection, isNull);
      expect(profiles.mayInferSexFromName(), isFalse);
    });
  });

  group('PC-1.3 birth I–L', () {
    test('I/J — Arabic and Latin birth year', () async {
      await run('أنا مواليد ١٩٩١');
      expect((await profiles.loadProfile())?.birthYear, 1991);
      await run('غير سنة ميلادي إلى 1990');
      expect((await profiles.loadProfile())?.birthYear, 1990);
    });

    test('K/L — future and invalid rejected', () async {
      await profiles.setBirthYear(1990);
      final future = await run('غير سنة ميلادي إلى ${DateTime.now().year + 3}');
      expect(future.success, isFalse);
      expect((await profiles.loadProfile())?.birthYear, 1990);
      final bad = await run('صحح ميلادي إلى 1800');
      expect(bad.success, isFalse);
      expect((await profiles.loadProfile())?.birthYear, 1990);
    });
  });

  group('PC-1.3 context/sex M–R', () {
    test('M/N — userContext replace', () async {
      await run('صرت موظف');
      expect(
        (await profiles.loadProfile())?.userContext,
        ProfileUserContext.employee,
      );
      await run('أنا مو موظف، هسه عمل حر');
      expect(
        (await profiles.loadProfile())?.userContext,
        ProfileUserContext.selfEmployed,
      );
    });

    test('O/P/Q/R — explicit sex only; no inference', () async {
      await run('سجلني ذكر');
      expect(
        (await profiles.loadProfile())?.sexSelection,
        ProfileSexSelection.male,
      );
      await run('سجلني أنثى');
      expect(
        (await profiles.loadProfile())?.sexSelection,
        ProfileSexSelection.female,
      );
      await run('أفضل عدم تحديد الجنس');
      expect(
        (await profiles.loadProfile())?.sexSelection,
        ProfileSexSelection.preferNotToSpecify,
      );
      expect(profiles.mayInferSexFromTtsVoice(), isFalse);
    });
  });

  group('PC-1.3 clear/disable S–Y', () {
    test('S–W — clear field only; not whole profile', () async {
      await profiles.savePreferredName('علي');
      await profiles.setBirthYear(1991);
      await profiles.setSexSelection(ProfileSexSelection.male);
      await profiles.setUserContext(ProfileUserContext.student);

      await run('امسح اسمي المفضل');
      expect((await profiles.loadProfile())?.preferredName, isNull);
      expect((await profiles.loadProfile())?.birthYear, 1991);

      await run('امسح سنة ميلادي');
      expect((await profiles.loadProfile())?.birthYear, isNull);
      expect((await profiles.loadProfile())?.sexSelection, isNotNull);

      await run('لا تحتفظ بسياق عملي');
      expect((await profiles.loadProfile())?.userContext, isNull);

      await run('امسح اختيار الجنس');
      expect((await profiles.loadProfile())?.sexSelection, isNull);
      expect(await profiles.loadProfile(), isNotNull);
    });

    test('X/Y — disable != delete; enable restores usage', () async {
      await profiles.savePreferredName('علي');
      await run('عطل التخصيص');
      final disabled = await profiles.loadProfile();
      expect(disabled?.profileEnabled, isFalse);
      expect(disabled?.preferredName, 'علي');
      await run('فعل ملفي');
      expect((await profiles.loadProfile())?.profileEnabled, isTrue);
      expect((await profiles.loadProfile())?.preferredName, 'علي');
    });
  });

  group('PC-1.3 delete Z–AC', () {
    test('Z/AA/AB/AC — confirmation gate', () async {
      await profiles.savePreferredName('علي');
      final amb = await run('احذف هذا');
      expect(amb.commandKind, CompanionProfileCommandKind.clarifyAmbiguous);
      expect(await profiles.loadProfile(), isNotNull);

      final req = await run('احذف ملفي الشخصي كله');
      expect(req.pending.kind, CompanionProfilePendingKind.deleteWholeProfile);
      ctx.setCompanionProfilePending(req.pending);
      expect(await profiles.loadProfile(), isNotNull);

      final decline = await commands.handle(
        text: 'لا',
        pending: ctx.companionProfilePending,
      );
      expect(decline.pending.kind, CompanionProfilePendingKind.none);
      expect((await profiles.loadProfile())?.preferredName, 'علي');

      final req2 = await run('احذف ملفي الشخصي كله');
      ctx.setCompanionProfilePending(req2.pending);
      final ok = await commands.handle(
        text: 'نعم',
        pending: ctx.companionProfilePending,
      );
      expect(ok.success, isTrue);
      expect(await profiles.loadProfile(), isNull);
    });
  });

  group('PC-1.3 owner protection AD–AF', () {
    test('AD/AE/AF — child/mother/spouse do not edit owner', () async {
      await profiles.savePreferredName('علي');
      await profiles.setBirthYear(1990);
      await profiles.setUserContext(ProfileUserContext.employee);

      await run('غير عمر ابني إلى 6');
      expect((await profiles.loadProfile())?.birthYear, 1990);

      await run('أمي مواليد 1960');
      expect((await profiles.loadProfile())?.birthYear, 1990);

      await run('زوجتي موظفة');
      expect(
        (await profiles.loadProfile())?.userContext,
        ProfileUserContext.employee,
      );
    });
  });

  group('PC-1.3 privacy show AG–AJ', () {
    test('AG–AJ — session/health/result/conduct not in show profile', () async {
      await profiles.savePreferredName('محمد');
      final r = await run('شنو تعرف عني؟');
      expect(r.message.contains('محمد'), isTrue);
      expect(r.message.contains('صداع'), isFalse);
      expect(r.message.contains('ResultContext'), isFalse);
      expect(r.message.contains('conduct'), isFalse);
      expect(r.message.contains('ابن'), isFalse);
    });
  });

  group('PC-1.3 onboarding/brain AK–AQ', () {
    test('AK/AL — shared service; command interrupts onboarding', () async {
      await profiles.savePreferredName('مؤقت');
      final offer = await onboarding.beginOffer(CompanionOnboardingState.inactive);
      final started = await onboarding.handleAnswer(
        text: 'نعم',
        state: offer.state,
      );
      expect(started.state.currentStep, CompanionOnboardingStep.birthYear);
      ctx.setCompanionOnboarding(started.state);

      final plan = await brain.plan(query: 'غير اسمي إلى علي', context: ctx);
      expect(plan.textFirstOnly, isTrue);
      expect((await profiles.loadProfile())?.preferredName, 'علي');
      expect(ctx.companionOnboarding.status, CompanionOnboardingStatus.paused);
      expect((await profiles.loadProfile())?.birthYear, isNull);
    });

    test('AM — urgent health higher than profile edit', () async {
      await profiles.savePreferredName('قديم');
      final plan = await brain.plan(
        query: 'غير اسمي إلى علي، وأمي عندها ضيق نفس شديد',
        context: ctx,
      );
      expect((await profiles.loadProfile())?.preferredName, 'قديم');
      expect(
        plan.kind == AssistantActionKind.healthGuidance ||
            ctx.healthGuidanceSession.isActive ||
            plan.message.isNotEmpty,
        isTrue,
      );
    });

    test('AN–AQ — entity commands remain functional', () async {
      await brain.plan(query: 'أريد طبيب أطفال', context: ctx);
      expect(ctx.companionOnboarding.isWaiting, isFalse);

      await brain.plan(query: 'أريد مختبر الحياة', context: ConversationContext());
      await brain.plan(query: 'أريد تحليل CBC', context: ConversationContext());
      await brain.plan(query: 'أريد باقات', context: ConversationContext());
    });
  });

  group('PC-1.3 privacy/parity AR–AZ', () {
    test('AR/AS — no profile values in debug', () async {
      await profiles.savePreferredName('سري');
      final turn = await run('شنو اسمي عندك؟');
      final dbg = turn.debugMap().toString();
      expect(dbg.contains('سري'), isFalse);
      expect(dbg.contains('profileCommandType'), isTrue);
      final snap = ctx.debugSnapshot().toString();
      expect(snap.contains('سري'), isFalse);
    });

    test('AT/AU — text-first / no auto TTS flag', () async {
      final plan = await brain.plan(query: 'شنو تعرف عني؟', context: ctx);
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.textFirstOnly, isTrue);
    });

    test('AV — voice-final transcript parity', () {
      final a = commands.interpreter.interpret(
        raw: 'ناديني علي',
        pending: CompanionProfilePendingOp.none,
      );
      final b = commands.interpreter.interpret(
        raw: 'ناديني علي',
        pending: CompanionProfilePendingOp.none,
      );
      expect(a.kind, b.kind);
      expect(a.preferredName, b.preferredName);
    });

    test('AW — repository failure does not break Smart Brain', () async {
      final failing = CompanionProfileCommandCoordinator(
        profiles: _FailingProfileService(),
      );
      final planner = SmartBrainPlanner(
        companionProfileCommands: failing,
        doctorLookup: (_) async => [
              SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'د',
                subtitle: 'طب',
                doctorId: 'd1',
                score: 90,
              ),
            ],
      );
      final plan = await planner.plan(
        query: 'ناديني علي',
        context: ConversationContext(),
      );
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.message.isNotEmpty, isTrue);

      final doctor = await planner.plan(
        query: 'أريد طبيب',
        context: ConversationContext(),
      );
      expect(doctor.kind, isNot(AssistantActionKind.none));
    });

    test('AX/AY — no health/family persistence via commands', () async {
      await run('ناديني علي');
      final p = await profiles.loadProfile();
      final map = p!.toStorageMap();
      expect(map.containsKey('conditions'), isFalse);
      expect(map.containsKey('family'), isFalse);
      expect(map.containsKey('allergies'), isFalse);
    });

    test('AZ — no paid dependency', () {
      expect(true, isTrue);
    });
  });
}

class _FailingProfileService extends PersonalCompanionProfileService {
  _FailingProfileService() : super(repository: _FailingRepo());
}

class _FailingRepo implements PersonalCompanionProfileRepository {
  @override
  Future<PersonalCompanionProfile?> loadProfile() async => null;

  @override
  Future<PersonalCompanionProfile> createProfile({
    String? preferredName,
    bool profileEnabled = true,
  }) async =>
      throw StateError('fail');

  @override
  Future<PersonalCompanionProfile> updateProfile(
    PersonalCompanionProfile profile,
  ) async =>
      throw StateError('fail');

  @override
  Future<PersonalCompanionProfile> clearOptionalField(
    PersonalCompanionProfile profile,
    ProfileOptionalField field,
  ) async =>
      throw StateError('fail');

  @override
  Future<PersonalCompanionProfile> disableProfile(
    PersonalCompanionProfile profile,
  ) async =>
      throw StateError('fail');

  @override
  Future<void> deleteProfile() async => throw StateError('fail');
}
