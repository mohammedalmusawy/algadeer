import 'companion_command_domain.dart';
import 'companion_profile_command_interpreter.dart';
import 'companion_profile_command_models.dart';
import 'personal_companion_profile.dart';
import 'personal_companion_profile_repository.dart';
import 'personal_companion_profile_service.dart';

/// منسّق أوامر الملف — ينفّذ عبر PersonalCompanionProfileService فقط.
class CompanionProfileCommandCoordinator {
  CompanionProfileCommandCoordinator({
    PersonalCompanionProfileService? profiles,
    CompanionProfileCommandInterpreter? interpreter,
    CompanionCommandRouter? router,
  })  : _profiles = profiles ?? PersonalCompanionProfileService(),
        _interpreter = interpreter ?? CompanionProfileCommandInterpreter(),
        _router = router ?? const CompanionCommandRouter();

  final PersonalCompanionProfileService _profiles;
  final CompanionProfileCommandInterpreter _interpreter;
  final CompanionCommandRouter _router;

  PersonalCompanionProfileService get profiles => _profiles;
  CompanionProfileCommandInterpreter get interpreter => _interpreter;

  bool mayHandle({
    required String query,
    required CompanionProfilePendingOp pending,
  }) {
    if (pending.isActive) return true;
    final n = query.trim();
    if (n.isEmpty) return false;
    final route = _router.routeProfileSurface(
      // التطبيع داخل المفسّر؛ هنا فحص خفيف عبر نفس المفسّر
      n,
    );
    if (route != null && route.matched) return true;
    return _interpreter.looksLikeProfileCommand(n);
  }

  Future<CompanionProfileCommandTurnResult> handle({
    required String text,
    required CompanionProfilePendingOp pending,
    bool doctorEntityActive = false,
    bool preferHealthPriority = false,
  }) async {
    if (preferHealthPriority) {
      return const CompanionProfileCommandTurnResult(
        handled: false,
        message: '',
        deferToHealth: true,
        textFirstOnly: true,
      );
    }

    final interp = _interpreter.interpret(
      raw: text,
      pending: pending,
      doctorEntityActive: doctorEntityActive,
    );
    if (!interp.isProfileCommand) {
      return CompanionProfileCommandTurnResult.notHandled();
    }

    try {
      return await _execute(interp, pending);
    } catch (_) {
      // فشل المستودع لا يكسر Smart Brain.
      return CompanionProfileCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما كدرت أكمّل طلب الملف هسه. تكدر تعيد لاحقاً.',
        commandKind: interp.kind,
        fieldType: interp.field?.name ?? interp.clearField?.name,
        pauseOnboarding: true,
        textFirstOnly: true,
      );
    }
  }

  Future<CompanionProfileCommandTurnResult> _execute(
    CompanionProfileCommandInterpretation interp,
    CompanionProfilePendingOp pending,
  ) async {
    final fieldType = interp.field?.name ?? interp.clearField?.name;

    switch (interp.kind) {
      case CompanionProfileCommandKind.showProfile:
        return CompanionProfileCommandTurnResult(
          handled: true,
          message: await _formatShowProfile(),
          commandKind: interp.kind,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.showSpecificField:
        return CompanionProfileCommandTurnResult(
          handled: true,
          message: await _formatSpecificField(interp.field!),
          commandKind: interp.kind,
          fieldType: fieldType,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.updatePreferredName:
        await _profiles.savePreferredName(interp.preferredName);
        return CompanionProfileCommandTurnResult(
          handled: true,
          message: 'تمام، من هسه أناديك بالاسم اللي اخترته.',
          commandKind: interp.kind,
          fieldType: fieldType,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.updateBirth:
        if (interp.message == 'invalid_birth' ||
            (interp.birthYear == null && interp.birthDate == null)) {
          return CompanionProfileCommandTurnResult(
            handled: true,
            success: false,
            message:
                'سنة الميلاد غير مقبولة. استخدم سنة معقولة (مو مستقبلية)، أو تخلّيها.',
            commandKind: interp.kind,
            fieldType: fieldType,
            pauseOnboarding: true,
          );
        }
        if (interp.birthDate != null) {
          await _profiles.setBirthDate(interp.birthDate);
        } else {
          await _profiles.setBirthYear(interp.birthYear);
        }
        return CompanionProfileCommandTurnResult(
          handled: true,
          message: 'تم تحديث سنة/تاريخ الميلاد.',
          commandKind: interp.kind,
          fieldType: fieldType,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.updateSexSelection:
        final sex = _mapSex(interp.sexSelectionName);
        if (sex == null) {
          return CompanionProfileCommandTurnResult(
            handled: true,
            success: false,
            message: 'اختيار الجنس غير واضح. قل: ذكر، أنثى، أو أفضل عدم التحديد.',
            commandKind: interp.kind,
            fieldType: fieldType,
            pauseOnboarding: true,
          );
        }
        await _profiles.setSexSelection(sex);
        return CompanionProfileCommandTurnResult(
          handled: true,
          message: 'تم تحديث اختيار الجنس.',
          commandKind: interp.kind,
          fieldType: fieldType,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.updateUserContext:
        final ctx = _mapContext(interp.userContextName);
        if (ctx == null) {
          return CompanionProfileCommandTurnResult(
            handled: true,
            success: false,
            message: 'ما فهمت سياق العمل. مثال: طالب، موظف، عمل حر.',
            commandKind: interp.kind,
            fieldType: fieldType,
            pauseOnboarding: true,
          );
        }
        await _profiles.setUserContext(ctx);
        return CompanionProfileCommandTurnResult(
          handled: true,
          message: 'تم تحديث سياق العمل.',
          commandKind: interp.kind,
          fieldType: fieldType,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.clearField:
        final f = interp.clearField!;
        if (f == ProfileOptionalField.birthYear ||
            f == ProfileOptionalField.birthDate) {
          await _profiles.clearField(ProfileOptionalField.birthYear);
          await _profiles.clearField(ProfileOptionalField.birthDate);
        } else {
          await _profiles.clearField(f);
        }
        return CompanionProfileCommandTurnResult(
          handled: true,
          message: 'تم مسح الحقل المطلوب فقط. باقي الملف موجود.',
          commandKind: interp.kind,
          fieldType: fieldType,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.disableProfile:
        await _profiles.disable();
        return CompanionProfileCommandTurnResult(
          handled: true,
          message:
              'تم تعطيل استخدام الملف بالتخصيص. القيم محفوظة وما انمسحت.',
          commandKind: interp.kind,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.enableProfile:
        await _profiles.enable();
        return CompanionProfileCommandTurnResult(
          handled: true,
          message: 'تم تفعيل الملف الشخصي للتخصيص.',
          commandKind: interp.kind,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.deleteProfileRequest:
        if (interp.message == 'confirm_delete' &&
            pending.kind == CompanionProfilePendingKind.deleteWholeProfile) {
          await _profiles.deleteProfileExplicitly();
          return const CompanionProfileCommandTurnResult(
            handled: true,
            message: 'تم حذف الملف الشخصي.',
            pending: CompanionProfilePendingOp.none,
            commandKind: CompanionProfileCommandKind.deleteProfileRequest,
            pauseOnboarding: true,
          );
        }
        return const CompanionProfileCommandTurnResult(
          handled: true,
          message:
              'متأكد تريد حذف ملفك الشخصي كله؟ هذا يمسح المعلومات الأساسية المحفوظة. قل نعم للتأكيد أو لا للإلغاء.',
          pending: CompanionProfilePendingOp(
            kind: CompanionProfilePendingKind.deleteWholeProfile,
          ),
          commandKind: CompanionProfileCommandKind.deleteProfileRequest,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.cancelProfileOperation:
        return const CompanionProfileCommandTurnResult(
          handled: true,
          message: 'تمام، ما حذفت الملف.',
          pending: CompanionProfilePendingOp.none,
          commandKind: CompanionProfileCommandKind.cancelProfileOperation,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.rejectNonOwner:
      case CompanionProfileCommandKind.clarifyAmbiguous:
      case CompanionProfileCommandKind.notPersistentMemory:
      case CompanionProfileCommandKind.unknownProfileCommand:
        return CompanionProfileCommandTurnResult(
          handled: true,
          success: interp.kind != CompanionProfileCommandKind.unknownProfileCommand,
          message: interp.message,
          commandKind: interp.kind,
          fieldType: fieldType,
          pauseOnboarding: true,
        );
      case CompanionProfileCommandKind.none:
        return CompanionProfileCommandTurnResult.notHandled();
    }
  }

  Future<String> _formatShowProfile() async {
    final p = await _profiles.loadProfile();
    if (p == null || !_hasAnyBasic(p)) {
      return 'حالياً ما عندي معلومات أساسية محفوظة عنك بملفك الشخصي.';
    }
    final lines = <String>['المعلومات الأساسية اللي عندي عنك:'];
    final name = p.preferredName?.trim();
    if (name != null && name.isNotEmpty) {
      lines.add('الاسم المفضل: $name');
    }
    if (p.birthDate != null) {
      final d = p.birthDate!;
      lines.add(
        'تاريخ الميلاد: ${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}',
      );
    } else if (p.birthYear != null) {
      lines.add('سنة الميلاد: ${p.birthYear}');
    }
    if (p.sexSelection != null) {
      lines.add('اختيار الجنس: ${_sexLabel(p.sexSelection!)}');
    }
    if (p.userContext != null) {
      lines.add('السياق: ${_contextLabel(p.userContext!)}');
    }
    lines.add(p.profileEnabled
        ? 'حالة التخصيص: مفعّل'
        : 'حالة التخصيص: معطّل (البيانات محفوظة)');
    lines.add('وتكدر تعدل أو تمسح أي وحدة منها.');
    return lines.join('\n');
  }

  Future<String> _formatSpecificField(CompanionProfileFieldKind field) async {
    final p = await _profiles.loadProfile();
    switch (field) {
      case CompanionProfileFieldKind.preferredName:
        final n = p?.preferredName?.trim();
        if (n == null || n.isEmpty) {
          return 'ما محفوظ عندي اسم مفضل حالياً.';
        }
        return 'اسمك المفضل عندي: $n';
      case CompanionProfileFieldKind.age:
        final age = p?.currentAge();
        if (age == null) {
          return 'ما أكدر أحسب عمرك لأن سنة/تاريخ الميلاد غير محفوظ.';
        }
        return 'حسب الميلاد المحفوظ، عمرك تقريباً $age سنة.';
      case CompanionProfileFieldKind.birth:
        if (p?.birthDate != null) {
          final d = p!.birthDate!;
          return 'تاريخ الميلاد عندي: ${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
        }
        if (p?.birthYear != null) {
          return 'سنة الميلاد عندي: ${p!.birthYear}';
        }
        return 'ما محفوظ عندي سنة أو تاريخ ميلاد.';
      case CompanionProfileFieldKind.sexSelection:
        if (p?.sexSelection == null) {
          return 'ما محفوظ اختيار جنس حالياً.';
        }
        return 'اختيار الجنس المسجّل: ${_sexLabel(p!.sexSelection!)}';
      case CompanionProfileFieldKind.userContext:
        if (p?.userContext == null) {
          return 'ما محفوظ سياق عمل حالياً.';
        }
        return 'سياق العمل المسجّل: ${_contextLabel(p!.userContext!)}';
      case CompanionProfileFieldKind.profileEnabled:
        final on = p?.profileEnabled ?? false;
        return on ? 'التخصيص مفعّل.' : 'التخصيص معطّل.';
    }
  }

  bool _hasAnyBasic(PersonalCompanionProfile p) {
    return (p.preferredName ?? '').trim().isNotEmpty ||
        p.birthDate != null ||
        p.birthYear != null ||
        p.sexSelection != null ||
        p.userContext != null;
  }

  String _sexLabel(ProfileSexSelection s) {
    switch (s) {
      case ProfileSexSelection.male:
        return 'ذكر';
      case ProfileSexSelection.female:
        return 'أنثى';
      case ProfileSexSelection.preferNotToSpecify:
        return 'أفضل عدم التحديد';
    }
  }

  String _contextLabel(ProfileUserContext c) {
    switch (c) {
      case ProfileUserContext.student:
        return 'طالب';
      case ProfileUserContext.employee:
        return 'موظف';
      case ProfileUserContext.selfEmployed:
        return 'عمل حر';
      case ProfileUserContext.other:
        return 'أخرى';
      case ProfileUserContext.preferNotToSpecify:
        return 'أفضل عدم التحديد';
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
}
