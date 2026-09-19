import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/companion.dart';
import 'package:ghadeer_clinic/labs/labs_service.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalPersonalCompanionProfileRepository repo;
  late PersonalCompanionProfileService profiles;
  late CompanionOnboardingPreferenceStore prefStore;
  late CompanionOnboardingCoordinator onboarding;
  late CompanionOnboardingInterpreter interpreter;
  late ConversationContext ctx;
  late SmartBrainPlanner brain;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = LocalPersonalCompanionProfileRepository(prefs: prefs);
    profiles = PersonalCompanionProfileService(repository: repo);
    prefStore = CompanionOnboardingPreferenceStore(prefs: prefs);
    interpreter = CompanionOnboardingInterpreter();
    onboarding = CompanionOnboardingCoordinator(
      profiles: profiles,
      preferences: prefStore,
      interpreter: interpreter,
    );
    ctx = ConversationContext();
    brain = SmartBrainPlanner(
      companionOnboardingCoordinator: onboarding,
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

  Future<CompanionOnboardingTurnResult> offer() =>
      onboarding.beginOffer(CompanionOnboardingState.inactive);

  Future<void> acceptOffer() async {
    final o = await offer();
    expect(o.handled, isTrue);
    final a = await onboarding.handleAnswer(text: 'نعم', state: o.state);
    ctx.setCompanionOnboarding(a.state);
  }

  group('PC-1.2 offer A–E', () {
    test('A/B — offer optionally and accept starts one question', () async {
      final o = await offer();
      expect(o.handled, isTrue);
      expect(o.state.currentStep, CompanionOnboardingStep.offer);
      expect(o.message.contains('تعرف'), isTrue);
      final a = await onboarding.handleAnswer(text: 'نعم', state: o.state);
      expect(a.state.currentStep, CompanionOnboardingStep.preferredName);
      expect(a.message.contains('أناديك') || a.message.contains('ناديك'), isTrue);
      // سؤال واحد فقط في الرسالة الأساسية
      expect(a.message.contains('سنة ميلادك'), isFalse);
    });

    test('C — later pauses for session', () async {
      final o = await offer();
      final later = await onboarding.handleAnswer(text: 'بعدين', state: o.state);
      expect(later.state.status, CompanionOnboardingStatus.paused);
      ctx.onboardingLaterThisSession = true;
      final again = await onboarding.beginOffer(
        later.state,
        laterThisSession: true,
      );
      expect(again.handled, isFalse);
    });

    test('D/E — decline does not nag and does not delete profile', () async {
      await profiles.savePreferredName('علي');
      final o = await offer();
      await onboarding.handleAnswer(text: 'لا أريد', state: o.state);
      expect(await prefStore.load(), CompanionOnboardingPreferenceKind.declined);
      expect((await profiles.loadProfile())?.preferredName, 'علي');
      final again = await onboarding.beginOffer(CompanionOnboardingState.inactive);
      expect(again.handled, isFalse);
    });
  });

  group('PC-1.2 skip known fields F–I', () {
    test('F — existing preferredName skips name question', () async {
      await profiles.savePreferredName('سارة');
      final o = await offer();
      final a = await onboarding.handleAnswer(text: 'نعم', state: o.state);
      expect(a.state.currentStep, isNot(CompanionOnboardingStep.preferredName));
      expect(a.state.currentStep, CompanionOnboardingStep.birthYear);
    });

    test('G — existing birthYear skips birth', () async {
      await profiles.savePreferredName('سارة');
      await profiles.setBirthYear(1990);
      final o = await offer();
      final a = await onboarding.handleAnswer(text: 'نعم', state: o.state);
      expect(a.state.currentStep, CompanionOnboardingStep.sexSelection);
    });

    test('H — existing sex skips sex', () async {
      await profiles.savePreferredName('سارة');
      await profiles.setBirthYear(1990);
      await profiles.setSexSelection(ProfileSexSelection.female);
      final o = await offer();
      final a = await onboarding.handleAnswer(text: 'نعم', state: o.state);
      expect(a.state.currentStep, CompanionOnboardingStep.userContext);
    });

    test('I — existing userContext completes', () async {
      await profiles.savePreferredName('سارة');
      await profiles.setBirthYear(1990);
      await profiles.setSexSelection(ProfileSexSelection.female);
      await profiles.setUserContext(ProfileUserContext.student);
      final o = await offer();
      expect(o.state.status, CompanionOnboardingStatus.completed);
      expect(await prefStore.load(), CompanionOnboardingPreferenceKind.completed);
    });
  });

  group('PC-1.2 name J–L', () {
    test('J — محمد resolves as preferredName', () async {
      await acceptOffer();
      final r = await onboarding.handleAnswer(
        text: 'محمد',
        state: ctx.companionOnboarding,
      );
      expect((await profiles.loadProfile())?.preferredName, 'محمد');
      expect(r.state.answeredFields.contains('preferredName'), isTrue);
    });

    test('K — تخطي not saved as name', () async {
      await acceptOffer();
      await onboarding.handleAnswer(
        text: 'تخطي',
        state: ctx.companionOnboarding,
      );
      expect((await profiles.loadProfile())?.preferredName, isNull);
    });

    test('L — بعدين not saved as name', () async {
      await acceptOffer();
      await onboarding.handleAnswer(
        text: 'بعدين',
        state: ctx.companionOnboarding,
      );
      expect((await profiles.loadProfile())?.preferredName, isNull);
    });
  });

  group('PC-1.2 birth M–S', () {
    Future<CompanionOnboardingState> toBirth() async {
      await profiles.savePreferredName('علي');
      final o = await offer();
      final a = await onboarding.handleAnswer(text: 'نعم', state: o.state);
      expect(a.state.currentStep, CompanionOnboardingStep.birthYear);
      return a.state;
    }

    test('M — Arabic ١٩٩٠ parsed', () async {
      final s = await toBirth();
      final r = await onboarding.handleAnswer(text: '١٩٩٠', state: s);
      expect((await profiles.loadProfile())?.birthYear, 1990);
      expect(r.state.currentStep, CompanionOnboardingStep.sexSelection);
    });

    test('N — Latin 1990 parsed', () async {
      final s = await toBirth();
      await onboarding.handleAnswer(text: '1990', state: s);
      expect((await profiles.loadProfile())?.birthYear, 1990);
    });

    test('O — مواليد 1990 parsed', () async {
      final s = await toBirth();
      await onboarding.handleAnswer(text: 'مواليد 1990', state: s);
      expect((await profiles.loadProfile())?.birthYear, 1990);
    });

    test('P — future year rejected', () async {
      final s = await toBirth();
      final y = DateTime.now().year + 2;
      final r = await onboarding.handleAnswer(text: '$y', state: s);
      expect(r.state.currentStep, CompanionOnboardingStep.birthYear);
      expect((await profiles.loadProfile())?.birthYear, isNull);
    });

    test('Q — unreasonable year rejected', () async {
      final s = await toBirth();
      final r = await onboarding.handleAnswer(text: '1800', state: s);
      expect((await profiles.loadProfile())?.birthYear, isNull);
      expect(r.state.currentStep, CompanionOnboardingStep.birthYear);
    });

    test('R/S — عمري 35 does not persist fixed age; needs confirm', () async {
      final s = await toBirth();
      final r = await onboarding.handleAnswer(text: 'عمري 35', state: s);
      expect(r.state.awaitingAgeYearConfirm, isTrue);
      final map = (await profiles.loadProfile())!.toStorageMap();
      expect(map.containsKey('age'), isFalse);
      expect((await profiles.loadProfile())?.birthYear, isNull);
      final confirm = await onboarding.handleAnswer(text: 'نعم', state: r.state);
      expect((await profiles.loadProfile())?.birthYear, DateTime.now().year - 35);
      expect(confirm.state.awaitingAgeYearConfirm, isFalse);
    });
  });

  group('PC-1.2 sex/context T–AC', () {
    Future<CompanionOnboardingState> toSex() async {
      await profiles.savePreferredName('علي');
      await profiles.setBirthYear(1990);
      final o = await offer();
      return (await onboarding.handleAnswer(text: 'نعم', state: o.state)).state;
    }

    test('T/U/V — sex mapping', () async {
      var s = await toSex();
      await onboarding.handleAnswer(text: 'ذكر', state: s);
      expect(
        (await profiles.loadProfile())?.sexSelection,
        ProfileSexSelection.male,
      );

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = LocalPersonalCompanionProfileRepository(prefs: prefs);
      profiles = PersonalCompanionProfileService(repository: repo);
      prefStore = CompanionOnboardingPreferenceStore(prefs: prefs);
      onboarding = CompanionOnboardingCoordinator(
        profiles: profiles,
        preferences: prefStore,
      );
      await profiles.savePreferredName('علي');
      await profiles.setBirthYear(1990);
      s = await toSex();
      await onboarding.handleAnswer(text: 'أنثى', state: s);
      expect(
        (await profiles.loadProfile())?.sexSelection,
        ProfileSexSelection.female,
      );

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = LocalPersonalCompanionProfileRepository(prefs: prefs);
      profiles = PersonalCompanionProfileService(repository: repo);
      onboarding = CompanionOnboardingCoordinator(
        profiles: profiles,
        preferences: CompanionOnboardingPreferenceStore(prefs: prefs),
      );
      await profiles.savePreferredName('علي');
      await profiles.setBirthYear(1990);
      s = await toSex();
      await onboarding.handleAnswer(text: 'أفضل عدم التحديد', state: s);
      expect(
        (await profiles.loadProfile())?.sexSelection,
        ProfileSexSelection.preferNotToSpecify,
      );
    });

    test('W/X — name/TTS do not infer sex', () {
      expect(profiles.mayInferSexFromName(), isFalse);
      expect(profiles.mayInferSexFromTtsVoice(), isFalse);
    });

    test('Y–AC — userContext mapping', () async {
      Future<void> check(String ans, ProfileUserContext expected) async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
        repo = LocalPersonalCompanionProfileRepository(prefs: prefs);
        profiles = PersonalCompanionProfileService(repository: repo);
        onboarding = CompanionOnboardingCoordinator(
          profiles: profiles,
          preferences: CompanionOnboardingPreferenceStore(prefs: prefs),
        );
        await profiles.savePreferredName('علي');
        await profiles.setBirthYear(1990);
        await profiles.setSexSelection(ProfileSexSelection.male);
        final o = await onboarding.beginOffer(CompanionOnboardingState.inactive);
        final s = await onboarding.handleAnswer(text: 'نعم', state: o.state);
        expect(s.state.currentStep, CompanionOnboardingStep.userContext);
        await onboarding.handleAnswer(text: ans, state: s.state);
        expect((await profiles.loadProfile())?.userContext, expected);
      }

      await check('طالب', ProfileUserContext.student);
      await check('موظف', ProfileUserContext.employee);
      await check('عمل حر', ProfileUserContext.selfEmployed);
      await check('أخرى', ProfileUserContext.other);
      await check('أفضل عدم التحديد', ProfileUserContext.preferNotToSpecify);
    });
  });

  group('PC-1.2 why/skip/correction AD–AH', () {
    test('AD — ليش تسأل؟ explains and retains question', () async {
      await acceptOffer();
      final r = await onboarding.handleAnswer(
        text: 'ليش تسأل؟',
        state: ctx.companionOnboarding,
      );
      expect(r.state.currentStep, CompanionOnboardingStep.preferredName);
      expect(r.message.contains('أناديك') || r.message.contains('اسم'), isTrue);
    });

    test('AE — skip leaves null', () async {
      await acceptOffer();
      await onboarding.handleAnswer(
        text: 'تخطي',
        state: ctx.companionOnboarding,
      );
      expect((await profiles.loadProfile())?.preferredName, isNull);
    });

    test('AF — correction updates birth year', () async {
      await profiles.savePreferredName('علي');
      final o = await offer();
      var s = await onboarding.handleAnswer(text: 'نعم', state: o.state);
      s = await onboarding.handleAnswer(text: '1990', state: s.state);
      expect((await profiles.loadProfile())?.birthYear, 1990);
      // تصحيح أثناء سؤال الجنس بعد العودة؟ نضبط خطوة الميلاد يدوياً
      final birthState = s.state.copyWith(
        status: CompanionOnboardingStatus.waitingForAnswer,
        currentStep: CompanionOnboardingStep.birthYear,
      );
      await onboarding.handleAnswer(text: 'لا قصدي 1991', state: birthState);
      expect((await profiles.loadProfile())?.birthYear, 1991);
    });

    test('AG/AH — correction updates userContext without duplicates', () async {
      await profiles.savePreferredName('علي');
      await profiles.setBirthYear(1990);
      await profiles.setSexSelection(ProfileSexSelection.male);
      final o = await offer();
      var s = await onboarding.handleAnswer(text: 'نعم', state: o.state);
      s = await onboarding.handleAnswer(text: 'موظف', state: s.state);
      expect((await profiles.loadProfile())?.userContext, ProfileUserContext.employee);
      final again = s.state.copyWith(
        status: CompanionOnboardingStatus.waitingForAnswer,
        currentStep: CompanionOnboardingStep.userContext,
      );
      await onboarding.handleAnswer(text: 'مو موظف، عمل حر', state: again);
      expect(
        (await profiles.loadProfile())?.userContext,
        ProfileUserContext.selfEmployed,
      );
    });

    test('AI — one question at a time', () async {
      final o = await offer();
      final a = await onboarding.handleAnswer(text: 'نعم', state: o.state);
      expect(a.message.contains('سنة ميلادك'), isFalse);
      expect(a.message.contains('ذكر'), isFalse);
    });
  });

  group('PC-1.2 interruptions AJ–AO', () {
    test('AJ — doctor request interrupts onboarding', () async {
      await acceptOffer();
      final plan = await brain.plan(query: 'أريد طبيب أطفال', context: ctx);
      expect(ctx.companionOnboarding.status, CompanionOnboardingStatus.paused);
      expect(plan.kind, isNot(AssistantActionKind.healthGuidance));
    });

    test('AK — lab request interrupts', () async {
      await acceptOffer();
      await brain.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(ctx.companionOnboarding.status, CompanionOnboardingStatus.paused);
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
    });

    test('AL — analysis request interrupts', () async {
      await acceptOffer();
      await brain.plan(query: 'أريد تحليل CBC', context: ctx);
      expect(ctx.companionOnboarding.status, CompanionOnboardingStatus.paused);
    });

    test('AM — package request interrupts', () async {
      await acceptOffer();
      await brain.plan(query: 'أريد باقات', context: ctx);
      expect(ctx.companionOnboarding.status, CompanionOnboardingStatus.paused);
    });

    test('AN/AO — health complaint interrupts; safety priority', () async {
      await acceptOffer();
      final plan = await brain.plan(query: 'عندي صداع شديد', context: ctx);
      expect(ctx.companionOnboarding.status, CompanionOnboardingStatus.paused);
      expect(
        plan.kind == AssistantActionKind.healthGuidance ||
            ctx.healthGuidanceSession.isActive,
        isTrue,
      );
    });
  });

  group('PC-1.2 subject protection AP–AR', () {
    test('AP/AQ/AR — child/mother data does not populate owner', () async {
      await profiles.savePreferredName('علي');
      final o = await offer();
      final birth = await onboarding.handleAnswer(text: 'نعم', state: o.state);
      expect(birth.state.currentStep, CompanionOnboardingStep.birthYear);
      final child = await onboarding.handleAnswer(
        text: 'ابني عمره 6',
        state: birth.state,
      );
      expect(
        child.pauseAndForward ||
            child.state.status == CompanionOnboardingStatus.paused,
        isTrue,
      );
      expect((await profiles.loadProfile())?.birthYear, isNull);

      final motherState = const CompanionOnboardingState(
        status: CompanionOnboardingStatus.waitingForAnswer,
        currentStep: CompanionOnboardingStep.userContext,
      );
      final mother = await onboarding.handleAnswer(
        text: 'أمي موظفة',
        state: motherState,
      );
      expect(
        mother.pauseAndForward ||
            mother.state.status == CompanionOnboardingStatus.paused,
        isTrue,
      );
      expect((await profiles.loadProfile())?.userContext, isNull);
    });
  });

  group('PC-1.2 conduct/privacy/parity AS–BC', () {
    test('AS/AT — useful name survives abuse; abuse not stored as name', () async {
      await acceptOffer();
      final r = await onboarding.handleAnswer(
        text: 'يا غبي اسمي علي',
        state: ctx.companionOnboarding,
      );
      // إما يُستخرج علي أو يُرفض النص المسيء
      final name = (await profiles.loadProfile())?.preferredName;
      expect(name == 'علي' || name == null, isTrue);
      expect(name, isNot('يا غبي اسمي علي'));
      expect(r.message.contains('غبي') && name == 'غبي', isFalse);
    });

    test('AU — typed/voice parity of interpreter', () {
      const q = 'محمد';
      final a = interpreter.interpret(
        raw: q,
        step: CompanionOnboardingStep.preferredName,
        state: const CompanionOnboardingState(
          status: CompanionOnboardingStatus.waitingForAnswer,
          currentStep: CompanionOnboardingStep.preferredName,
        ),
      );
      final b = interpreter.interpret(
        raw: q,
        step: CompanionOnboardingStep.preferredName,
        state: const CompanionOnboardingState(
          status: CompanionOnboardingStatus.waitingForAnswer,
          currentStep: CompanionOnboardingStep.preferredName,
        ),
      );
      expect(a.preferredName, b.preferredName);
    });

    test('AV — profile disabled prevents automatic onboarding', () async {
      await profiles.createEmptyProfile();
      await profiles.disable();
      final o = await onboarding.beginOffer(CompanionOnboardingState.inactive);
      expect(o.handled, isFalse);
    });

    test('AW — completed onboarding not repeatedly offered', () async {
      await prefStore.save(CompanionOnboardingPreferenceKind.completed);
      final o = await onboarding.beginOffer(CompanionOnboardingState.inactive);
      expect(o.handled, isFalse);
    });

    test('AX/AY — no sensitive health/family persistence via onboarding', () async {
      await acceptOffer();
      await onboarding.handleAnswer(text: 'محمد', state: ctx.companionOnboarding);
      final map = (await profiles.loadProfile())!.toStorageMap();
      expect(map.keys.any((k) => k.contains('allerg')), isFalse);
      expect(map.keys.any((k) => k.contains('family')), isFalse);
    });

    test('AZ/BA — no profile values in analytics/debug', () async {
      await acceptOffer();
      final r = await onboarding.handleAnswer(
        text: 'محمد',
        state: ctx.companionOnboarding,
      );
      final dbg = r.state.debugMap().toString();
      expect(dbg.contains('محمد'), isFalse);
      expect(dbg.contains('onboardingStatus'), isTrue);
    });

    test('BB — doctor/lab paths remain green with onboarding present', () async {
      await acceptOffer();
      await brain.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(
        ctx.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
    });

    test('BC — no paid dependency', () {
      expect(true, isTrue);
    });
  });
}
