import 'companion_onboarding_interpreter.dart';
import 'companion_onboarding_models.dart';
import 'companion_onboarding_preference.dart';
import 'personal_companion_profile.dart';
import 'personal_companion_profile_service.dart';

/// منسّق onboarding تدريجي — سؤال واحد، اختياري، لا يحجب Smart Brain.
class CompanionOnboardingCoordinator {
  CompanionOnboardingCoordinator({
    PersonalCompanionProfileService? profiles,
    CompanionOnboardingPreferenceStore? preferences,
    CompanionOnboardingInterpreter? interpreter,
  })  : _profiles = profiles ?? PersonalCompanionProfileService(),
        _prefs = preferences ?? CompanionOnboardingPreferenceStore(),
        _interpreter = interpreter ?? CompanionOnboardingInterpreter();

  final PersonalCompanionProfileService _profiles;
  final CompanionOnboardingPreferenceStore _prefs;
  final CompanionOnboardingInterpreter _interpreter;

  PersonalCompanionProfileService get profiles => _profiles;
  CompanionOnboardingPreferenceStore get preferenceStore => _prefs;

  static const offerPrompt =
      'حتى أخلي الغدير أنسب إلك، تحب أتعرف عليك شوي شوي؟';

  String promptFor(CompanionOnboardingStep step) {
    switch (step) {
      case CompanionOnboardingStep.offer:
        return offerPrompt;
      case CompanionOnboardingStep.preferredName:
        return 'شنو تحب أناديك؟';
      case CompanionOnboardingStep.birthYear:
        return 'إذا تحب، شنو سنة ميلادك؟ أستخدمها حتى أحسب عمرك بشكل صحيح.';
      case CompanionOnboardingStep.sexSelection:
        return 'حتى تكون الصيغة أنسب إلك: ذكر، أنثى، أو أفضل عدم التحديد؟';
      case CompanionOnboardingStep.userContext:
        return 'وأكثر شي شنو ينطبق عليك حالياً؟ طالب، موظف، عمل حر، أخرى، أو أفضل عدم التحديد.';
      case CompanionOnboardingStep.done:
        return 'تمام، شكراً. تكدر تعدّل أي معلومة لاحقاً.';
    }
  }

  Future<bool> mayAutoOffer({
    required bool laterThisSession,
  }) async {
    final pref = await _prefs.load();
    if (pref == CompanionOnboardingPreferenceKind.declined ||
        pref == CompanionOnboardingPreferenceKind.completed) {
      return false;
    }
    if (laterThisSession) return false;
    try {
      final profile = await _profiles.loadProfile();
      if (profile != null && !profile.profileEnabled) return false;
      final missing = await nextMissingStep(profile);
      return missing != CompanionOnboardingStep.done;
    } catch (_) {
      return false;
    }
  }

  Future<CompanionOnboardingStep> nextMissingStep(
    PersonalCompanionProfile? profile,
  ) async {
    return _firstEligibleMissing(profile, const {});
  }

  Future<CompanionOnboardingStep> _firstEligibleMissing(
    PersonalCompanionProfile? profile,
    Set<String> skipped,
  ) async {
    for (final step in [
      CompanionOnboardingStep.preferredName,
      CompanionOnboardingStep.birthYear,
      CompanionOnboardingStep.sexSelection,
      CompanionOnboardingStep.userContext,
    ]) {
      if (skipped.contains(step.name)) continue;
      if (!_isFilled(profile, step)) return step;
    }
    return CompanionOnboardingStep.done;
  }

  Future<CompanionOnboardingTurnResult> beginOffer(
    CompanionOnboardingState current, {
    bool laterThisSession = false,
  }) async {
    final pref = await _prefs.load();
    if (pref == CompanionOnboardingPreferenceKind.declined ||
        pref == CompanionOnboardingPreferenceKind.completed) {
      return CompanionOnboardingTurnResult.notHandled(current);
    }
    if (laterThisSession) {
      return CompanionOnboardingTurnResult.notHandled(current);
    }
    try {
      final profile = await _profiles.loadProfile();
      if (profile != null && !profile.profileEnabled) {
        return CompanionOnboardingTurnResult.notHandled(current);
      }
      final missing = await nextMissingStep(profile);
      if (missing == CompanionOnboardingStep.done) {
        await _prefs.save(CompanionOnboardingPreferenceKind.completed);
        return CompanionOnboardingTurnResult(
          handled: true,
          state: current.copyWith(
            status: CompanionOnboardingStatus.completed,
            currentStep: CompanionOnboardingStep.done,
            startedThisSession: true,
          ),
          message: 'يبدو إن المعلومات الأساسية موجودة. شكراً!',
        );
      }
    } catch (_) {
      return CompanionOnboardingTurnResult.notHandled(current);
    }
    final state = current.copyWith(
      status: CompanionOnboardingStatus.waitingForAnswer,
      currentStep: CompanionOnboardingStep.offer,
      startedThisSession: true,
    );
    return CompanionOnboardingTurnResult(
      handled: true,
      state: state,
      message: offerPrompt,
    );
  }

  Future<CompanionOnboardingTurnResult> startFirstQuestion(
    CompanionOnboardingState current,
  ) async {
    final profile = await _profiles.loadProfile();
    final step = await nextMissingStep(profile);
    if (step == CompanionOnboardingStep.done) {
      await _prefs.save(CompanionOnboardingPreferenceKind.completed);
      return CompanionOnboardingTurnResult(
        handled: true,
        state: current.copyWith(
          status: CompanionOnboardingStatus.completed,
          currentStep: CompanionOnboardingStep.done,
        ),
        message: 'يبدو إن المعلومات الأساسية موجودة. شكراً!',
      );
    }
    return CompanionOnboardingTurnResult(
      handled: true,
      state: current.copyWith(
        status: CompanionOnboardingStatus.waitingForAnswer,
        currentStep: step,
        startedThisSession: true,
        invalidAttempts: 0,
        clearProposedBirthYear: true,
        awaitingAgeYearConfirm: false,
      ),
      message: promptFor(step),
    );
  }

  CompanionOnboardingState pause(CompanionOnboardingState current) {
    return current.copyWith(status: CompanionOnboardingStatus.paused);
  }

  Future<CompanionOnboardingTurnResult> handleAnswer({
    required String text,
    required CompanionOnboardingState state,
  }) async {
    if (!state.isWaiting && state.status != CompanionOnboardingStatus.active) {
      return CompanionOnboardingTurnResult.notHandled(state);
    }

    final interp = _interpreter.interpret(
      raw: text,
      step: state.currentStep,
      state: state,
    );

    switch (interp.kind) {
      case CompanionOnboardingInterpretKind.topicChanged:
        return CompanionOnboardingTurnResult(
          handled: true,
          state: pause(state),
          pauseAndForward: true,
          forwardQuery: text,
          message: '',
        );
      case CompanionOnboardingInterpretKind.whyQuestion:
        return CompanionOnboardingTurnResult(
          handled: true,
          state: state,
          message:
              '${interp.explanation ?? ''}\n${promptFor(state.currentStep)}',
        );
      case CompanionOnboardingInterpretKind.pause:
      case CompanionOnboardingInterpretKind.laterOffer:
        return CompanionOnboardingTurnResult(
          handled: true,
          state: pause(state),
          message: 'تمام، نكمّل لاحقاً.',
        );
      case CompanionOnboardingInterpretKind.declineOffer:
        await _prefs.save(CompanionOnboardingPreferenceKind.declined);
        return CompanionOnboardingTurnResult(
          handled: true,
          state: state.copyWith(
            status: CompanionOnboardingStatus.notStarted,
            currentStep: CompanionOnboardingStep.offer,
          ),
          message: 'تمام، ما في مشكلة.',
        );
      case CompanionOnboardingInterpretKind.acceptOffer:
        return startFirstQuestion(state);
      case CompanionOnboardingInterpretKind.skip:
        return _afterSkip(state);
      case CompanionOnboardingInterpretKind.invalid:
        final attempts = state.invalidAttempts + 1;
        if (attempts >= 2) {
          return _afterSkip(
            state.copyWith(invalidAttempts: attempts),
            message: 'ما عليك، نتخطى هاي ونكمّل لاحقاً إذا تحب.',
          );
        }
        return CompanionOnboardingTurnResult(
          handled: true,
          state: state.copyWith(invalidAttempts: attempts),
          message: interp.message ?? promptFor(state.currentStep),
        );
      case CompanionOnboardingInterpretKind.ageNeedsConfirm:
        return CompanionOnboardingTurnResult(
          handled: true,
          state: state.copyWith(
            awaitingAgeYearConfirm: true,
            proposedBirthYear: interp.proposedBirthYear,
            invalidAttempts: 0,
          ),
          message: interp.message ?? '',
        );
      case CompanionOnboardingInterpretKind.resolved:
      case CompanionOnboardingInterpretKind.correction:
        return _persistAndAdvance(state, interp);
    }
  }

  Future<CompanionOnboardingTurnResult> _persistAndAdvance(
    CompanionOnboardingState state,
    CompanionOnboardingInterpretation interp,
  ) async {
    try {
      switch (state.currentStep) {
        case CompanionOnboardingStep.preferredName:
          if (interp.preferredName != null) {
            await _profiles.savePreferredName(interp.preferredName);
          }
        case CompanionOnboardingStep.birthYear:
          if (interp.birthDate != null) {
            await _profiles.setBirthDate(interp.birthDate);
          } else if (interp.birthYear != null) {
            await _profiles.setBirthYear(interp.birthYear);
          }
        case CompanionOnboardingStep.sexSelection:
          final sex = _mapSex(interp.sexSelectionName);
          if (sex != null) await _profiles.setSexSelection(sex);
        case CompanionOnboardingStep.userContext:
          final ctx = _mapContext(interp.userContextName);
          if (ctx != null) await _profiles.setUserContext(ctx);
        case CompanionOnboardingStep.offer:
        case CompanionOnboardingStep.done:
          break;
      }
    } catch (_) {
      return CompanionOnboardingTurnResult(
        handled: true,
        state: state,
        message: 'ما كدرت أحفظ الجواب. تكدر تعيد أو تتخطى.',
      );
    }

    final answered = {...state.answeredFields, state.currentStep.name};
    final advanced = state.copyWith(
      answeredFields: answered,
      awaitingAgeYearConfirm: false,
      clearProposedBirthYear: true,
      invalidAttempts: 0,
    );
    return _askNext(advanced);
  }

  Future<CompanionOnboardingTurnResult> _afterSkip(
    CompanionOnboardingState state, {
    String? message,
  }) async {
    final skipped = {...state.skippedFields, state.currentStep.name};
    final advanced = state.copyWith(
      skippedFields: skipped,
      awaitingAgeYearConfirm: false,
      clearProposedBirthYear: true,
      invalidAttempts: 0,
    );
    final next = await _askNext(advanced);
    if (message != null && message.isNotEmpty) {
      return CompanionOnboardingTurnResult(
        handled: true,
        state: next.state,
        message: next.state.currentStep == CompanionOnboardingStep.done
            ? message
            : '$message\n${next.message}',
      );
    }
    return next;
  }

  Future<CompanionOnboardingTurnResult> _askNext(
    CompanionOnboardingState state,
  ) async {
    final profile = await _profiles.loadProfile();
    final step = await _firstEligibleMissing(profile, state.skippedFields);

    if (step == CompanionOnboardingStep.done) {
      await _prefs.save(CompanionOnboardingPreferenceKind.completed);
      return CompanionOnboardingTurnResult(
        handled: true,
        state: state.copyWith(
          status: CompanionOnboardingStatus.completed,
          currentStep: CompanionOnboardingStep.done,
        ),
        message: 'تمام، شكراً. تكدر تعدّل أي معلومة لاحقاً.',
      );
    }

    return CompanionOnboardingTurnResult(
      handled: true,
      state: state.copyWith(
        status: CompanionOnboardingStatus.waitingForAnswer,
        currentStep: step,
      ),
      message: promptFor(step),
    );
  }

  bool _isFilled(PersonalCompanionProfile? p, CompanionOnboardingStep step) {
    if (p == null) return false;
    switch (step) {
      case CompanionOnboardingStep.preferredName:
        return (p.preferredName ?? '').trim().isNotEmpty;
      case CompanionOnboardingStep.birthYear:
        return p.birthDate != null || p.birthYear != null;
      case CompanionOnboardingStep.sexSelection:
        return p.sexSelection != null;
      case CompanionOnboardingStep.userContext:
        return p.userContext != null;
      default:
        return true;
    }
  }

  ProfileSexSelection? _mapSex(String? name) {
    for (final v in ProfileSexSelection.values) {
      if (v.name == name) return v;
    }
    return null;
  }

  ProfileUserContext? _mapContext(String? name) {
    for (final v in ProfileUserContext.values) {
      if (v.name == name) return v;
    }
    return null;
  }

  /// هل يجب مقاطعة onboarding لصالح نية كيان/صحة؟
  bool shouldInterruptForQuery({
    required String query,
    required bool looksLikeHealth,
    required bool isEntityIntent,
  }) {
    if (looksLikeHealth || isEntityIntent) return true;
    return false;
  }
}
