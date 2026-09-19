import '../../health/family_sensitive/family_sensitive_health_service.dart';
import '../../search/arabic_text_utils.dart';
import '../companion_command_domain.dart';
import 'family_person_profile.dart';
import 'family_person_profile_service.dart';
import 'family_profile_command_interpreter.dart';
import 'family_profile_command_models.dart';
import 'person_reference_resolver.dart';

/// منسّق ملفات الأشخاص — PC-1.8.
class FamilyProfileCommandCoordinator {
  FamilyProfileCommandCoordinator({
    FamilyPersonProfileService? people,
    FamilyProfileCommandInterpreter? interpreter,
    PersonReferenceResolver? resolver,
    CompanionCommandRouter? router,
    FamilySensitiveHealthService? familyHealth,
  })  : _people = people ?? FamilyPersonProfileService(),
        _interpreter = interpreter ?? const FamilyProfileCommandInterpreter(),
        _resolver = resolver ?? const PersonReferenceResolver(),
        _router = router ?? const CompanionCommandRouter(),
        _familyHealth = familyHealth ?? FamilySensitiveHealthService();

  final FamilyPersonProfileService _people;
  final FamilyProfileCommandInterpreter _interpreter;
  final PersonReferenceResolver _resolver;
  final CompanionCommandRouter _router;
  final FamilySensitiveHealthService _familyHealth;

  FamilyPersonProfileService get people => _people;
  PersonReferenceResolver get resolver => _resolver;
  FamilySensitiveHealthService get familyHealth => _familyHealth;

  bool mayHandle({
    required String query,
    required FamilyProfilePendingOp pending,
  }) {
    if (pending.isActive) return true;
    final route = _router.routeFamilyPeople(query);
    if (route != null && route.matched) return true;
    return _interpreter.looksLikeFamilyProfileCommand(query);
  }

  /// طلبات طبيب/مختبر — لا تحجب discovery.
  bool shouldEscapeToProvider(String query) {
    final n = ArabicTextUtils.normalize(query);
    return RegExp(
      r'(?:أريد|اريد|ابي|دور)\s*(?:طبيب|دكتور|مختبر)',
    ).hasMatch(n);
  }

  Future<FamilyProfileCommandTurnResult> handle({
    required String text,
    required FamilyProfilePendingOp pending,
  }) async {
    if (shouldEscapeToProvider(text)) {
      return FamilyProfileCommandTurnResult.notHandled();
    }

    final interp = _interpreter.interpret(raw: text, pending: pending);
    if (interp.kind == FamilyProfileCommandKind.rejectHealthOnly) {
      return FamilyProfileCommandTurnResult.notHandled();
    }
    if (!interp.isCommand) {
      return FamilyProfileCommandTurnResult.notHandled();
    }

    try {
      return await _execute(interp, pending);
    } catch (_) {
      return const FamilyProfileCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما كدرت أكمّل طلب الشخص هسه. جرّب لاحقاً.',
        operationType: 'repository_failure',
      );
    }
  }

  Future<FamilyProfileCommandTurnResult> _execute(
    FamilyProfileCommandInterpretation interp,
    FamilyProfilePendingOp pending,
  ) async {
    switch (interp.kind) {
      case FamilyProfileCommandKind.rememberPerson:
        return _rememberPerson(interp);
      case FamilyProfileCommandKind.showAllPeople:
        return _showAll();
      case FamilyProfileCommandKind.showPerson:
        return _showPerson(interp);
      case FamilyProfileCommandKind.updateName:
        return _updateName(interp);
      case FamilyProfileCommandKind.updateBirthYear:
        return _updateBirth(interp);
      case FamilyProfileCommandKind.disablePerson:
        return _disablePerson(interp);
      case FamilyProfileCommandKind.deletePersonRequest:
        return _requestDelete(interp);
      case FamilyProfileCommandKind.confirmDelete:
        return _confirmDelete(pending);
      case FamilyProfileCommandKind.cancelOperation:
        return const FamilyProfileCommandTurnResult(
          handled: true,
          message: 'تمام، ما مسحت أي ملف.',
          pending: FamilyProfilePendingOp.none,
          operationType: 'cancel',
        );
      case FamilyProfileCommandKind.progressiveAskBirthYear:
        return FamilyProfileCommandTurnResult(
          handled: true,
          message: interp.message,
          operationType: 'progressive_birth',
        );
      case FamilyProfileCommandKind.clarifyAmbiguous:
        return FamilyProfileCommandTurnResult(
          handled: true,
          message: interp.message,
          resolutionStatus: PersonResolutionStatus.ambiguous,
          operationType: 'clarify',
        );
      default:
        return FamilyProfileCommandTurnResult.notHandled();
    }
  }

  Future<FamilyProfileCommandTurnResult> _rememberPerson(
    FamilyProfileCommandInterpretation interp,
  ) async {
    final all = await _people.loadAllProfiles();
    if (interp.preferredName != null) {
      final dup = _resolver.resolve(
        query: '${interp.relationship?.name} ${interp.preferredName}',
        profiles: all,
        relationshipHint: interp.relationship,
        nameHint: interp.preferredName,
        includeDisabled: true,
      );
      if (dup.isResolved && dup.profile != null) {
        var p = dup.profile!;
        if (interp.birthYear != null) {
          p = await _people.updateProfile(
            p.copyWith(birthYear: interp.birthYear, profileEnabled: true),
          );
        }
        return FamilyProfileCommandTurnResult(
          handled: true,
          message:
              'تمام، ${p.effectiveName ?? "الشخص"} موجود بالملف. ${_birthNote(p)}',
          linkedPersonId: p.personId,
          resolutionStatus: PersonResolutionStatus.resolved,
          operationType: 'remember_update',
        );
      }
    }

    final year = interp.birthYear;
    if (year != null &&
        (year > DateTime.now().year || year < 1900)) {
      return const FamilyProfileCommandTurnResult(
        handled: true,
        success: false,
        message: 'سنة الميلاد ما تبدو صحيحة.',
        operationType: 'remember_birth_invalid',
      );
    }

    final created = await _people.createProfile(
      relationship: interp.relationship ?? PersonRelationship.child,
      preferredName: interp.preferredName,
      birthYear: year,
    );

    var msg = 'تمام، حفظت ${_relationshipLabel(created.relationship)}';
    if (created.effectiveName != null) {
      msg = '$msg ${created.effectiveName}';
    }
    msg = '$msg بالملف.';
    if (created.birthYear == null && interp.preferredName != null) {
      msg =
          '$msg إذا تحب لاحقاً، تكدر تضيف سنة الميلاد.';
    }

    return FamilyProfileCommandTurnResult(
      handled: true,
      message: msg,
      linkedPersonId: created.personId,
      resolutionStatus: PersonResolutionStatus.resolved,
      operationType: 'remember_create',
    );
  }

  Future<FamilyProfileCommandTurnResult> _showAll() async {
    final all = await _people.loadEnabledProfiles();
    if (all.isEmpty) {
      return const FamilyProfileCommandTurnResult(
        handled: true,
        message: 'ما عندي أشخاص محفوظين بالعائلة حالياً.',
        operationType: 'show_all_empty',
      );
    }
    final lines = all
        .map(
          (p) =>
              '• ${_relationshipLabel(p.relationship)}${p.effectiveName != null ? ': ${p.effectiveName}' : ''}${p.currentAge() != null ? ' (عمر تقريبي ${p.currentAge()})' : ''}',
        )
        .join('\n');
    return FamilyProfileCommandTurnResult(
      handled: true,
      message: 'هذول الأشخاص المحفوظين:\n$lines',
      operationType: 'show_all',
    );
  }

  Future<FamilyProfileCommandTurnResult> _showPerson(
    FamilyProfileCommandInterpretation interp,
  ) async {
    final all = await _people.loadAllProfiles();
    final res = _resolver.resolve(
      query: interp.targetName ?? '',
      profiles: all,
      relationshipHint: interp.relationship,
      nameHint: interp.targetName,
    );
    if (res.isAmbiguous) {
      return FamilyProfileCommandTurnResult(
        handled: true,
        message: res.message,
        resolutionStatus: PersonResolutionStatus.ambiguous,
        operationType: 'show_clarify',
      );
    }
    if (!res.isResolved || res.profile == null) {
      return FamilyProfileCommandTurnResult(
        handled: true,
        message: res.message,
        resolutionStatus: PersonResolutionStatus.notFound,
        operationType: 'show_not_found',
      );
    }
    final p = res.profile!;
    return FamilyProfileCommandTurnResult(
      handled: true,
      message: _formatPersonBasic(p),
      linkedPersonId: p.personId,
      resolutionStatus: PersonResolutionStatus.resolved,
      operationType: 'show_person',
    );
  }

  Future<FamilyProfileCommandTurnResult> _updateName(
    FamilyProfileCommandInterpretation interp,
  ) async {
    final all = await _people.loadAllProfiles();
    final res = _resolver.resolve(
      query: '${interp.relationship?.name} ${interp.targetName}',
      profiles: all,
      relationshipHint: interp.relationship,
      nameHint: interp.targetName,
    );
    if (!res.isResolved || res.profile == null) {
      return FamilyProfileCommandTurnResult(
        handled: true,
        message: res.isAmbiguous
            ? res.message
            : 'ما قدرت أحدد الشخص للتعديل.',
        resolutionStatus: res.status,
        operationType: 'edit_ambiguous',
      );
    }
    final updated = await _people.updateProfile(
      res.profile!.copyWith(preferredName: interp.newName),
    );
    return FamilyProfileCommandTurnResult(
      handled: true,
      message: 'تمام، صار الاسم المفضل: ${updated.effectiveName}.',
      linkedPersonId: updated.personId,
      operationType: 'edit_name',
    );
  }

  Future<FamilyProfileCommandTurnResult> _updateBirth(
    FamilyProfileCommandInterpretation interp,
  ) async {
    final year = interp.birthYear;
    if (year == null || year > DateTime.now().year || year < 1900) {
      return const FamilyProfileCommandTurnResult(
        handled: true,
        success: false,
        message: 'سنة الميلاد ما تبدو صحيحة.',
        operationType: 'edit_birth_invalid',
      );
    }
    final all = await _people.loadAllProfiles();
    final res = _resolver.resolve(
      query: '${interp.relationship?.name} ${interp.targetName}',
      profiles: all,
      relationshipHint: interp.relationship,
      nameHint: interp.targetName,
    );
    if (!res.isResolved || res.profile == null) {
      return FamilyProfileCommandTurnResult(
        handled: true,
        message: res.isAmbiguous ? res.message : 'ما قدرت أحدد الشخص.',
        resolutionStatus: res.status,
        operationType: 'edit_birth_ambiguous',
      );
    }
    final updated = await _people.updateProfile(
      res.profile!.copyWith(birthYear: year),
    );
    return FamilyProfileCommandTurnResult(
      handled: true,
      message: 'تم تصحيح سنة الميلاد لـ ${updated.effectiveName ?? "الشخص"}.',
      linkedPersonId: updated.personId,
      operationType: 'edit_birth',
    );
  }

  Future<FamilyProfileCommandTurnResult> _disablePerson(
    FamilyProfileCommandInterpretation interp,
  ) async {
    final all = await _people.loadAllProfiles();
    final res = _resolver.resolve(
      query: '${interp.relationship?.name} ${interp.targetName}',
      profiles: all,
      relationshipHint: interp.relationship,
      nameHint: interp.targetName,
      includeDisabled: true,
    );
    if (!res.isResolved || res.profile == null) {
      return FamilyProfileCommandTurnResult(
        handled: true,
        message: res.isAmbiguous ? res.message : 'ما قدرت أحدد الشخص.',
        resolutionStatus: res.status,
        operationType: 'disable_ambiguous',
      );
    }
    await _people.disableProfile(res.profile!.personId);
    return FamilyProfileCommandTurnResult(
      handled: true,
      message:
          'تم تعطيل ملف ${res.profile!.effectiveName ?? _relationshipLabel(res.profile!.relationship)}. ما راح يُستخدم تلقائياً.',
      operationType: 'disable',
    );
  }

  Future<FamilyProfileCommandTurnResult> _requestDelete(
    FamilyProfileCommandInterpretation interp,
  ) async {
    final all = await _people.loadAllProfiles();
    final res = _resolver.resolve(
      query: '${interp.relationship?.name} ${interp.targetName}',
      profiles: all,
      relationshipHint: interp.relationship,
      nameHint: interp.targetName,
      includeDisabled: true,
    );
    if (!res.isResolved || res.profile == null) {
      return FamilyProfileCommandTurnResult(
        handled: true,
        message: res.isAmbiguous ? res.message : 'ما قدرت أحدد الشخص للحذف.',
        resolutionStatus: res.status,
        operationType: 'delete_ambiguous',
      );
    }
    final hasHealth = await _familyHealth.hasHealthForPerson(
      res.profile!.personId,
    );
    if (hasHealth) {
      return FamilyProfileCommandTurnResult(
        handled: true,
        message:
            'تأكيد حذف نهائي: ملف ${res.profile!.effectiveName ?? _relationshipLabel(res.profile!.relationship)} '
            'وفيه معلومات صحية محفوظة. الحذف سيمسح الهوية والمعلومات الصحية معاً. '
            'ما راح ينحذف شيء بدون تأكيدك. قل نعم للتأكيد أو لا للإلغاء.',
        pending: FamilyProfilePendingOp(
          kind: FamilyProfilePendingKind.deletePerson,
          targetPersonId: res.profile!.personId,
          alsoDeletesFamilyHealth: true,
        ),
        operationType: 'delete_confirm_request_with_health',
      );
    }
    return FamilyProfileCommandTurnResult(
      handled: true,
      message:
          'تأكيد: تريد تماماً حذف ملف ${res.profile!.effectiveName ?? _relationshipLabel(res.profile!.relationship)}؟ (نعم/لا)',
      pending: FamilyProfilePendingOp(
        kind: FamilyProfilePendingKind.deletePerson,
        targetPersonId: res.profile!.personId,
      ),
      operationType: 'delete_confirm_request',
    );
  }

  Future<FamilyProfileCommandTurnResult> _confirmDelete(
    FamilyProfilePendingOp pending,
  ) async {
    final id = pending.targetPersonId;
    if (id == null || id.isEmpty) {
      return const FamilyProfileCommandTurnResult(
        handled: true,
        success: false,
        message: 'ما عندي شخص محدد للحذف.',
        operationType: 'delete_no_target',
      );
    }
    // لا نترك سجلات صحة يتيمة — فقط بعد تأكيد يغطي الصحة عند وجودها.
    if (pending.alsoDeletesFamilyHealth ||
        await _familyHealth.hasHealthForPerson(id)) {
      if (!pending.alsoDeletesFamilyHealth) {
        // سلامة: لا حذف صامت للصحة بدون تأكيد مزدوج.
        return FamilyProfileCommandTurnResult(
          handled: true,
          message:
              'هذا الشخص عنده معلومات صحية محفوظة. '
              'للتأكيد النهائي على مسح الهوية والصحة معاً، قل نعم مرة ثانية.',
          pending: FamilyProfilePendingOp(
            kind: FamilyProfilePendingKind.deletePerson,
            targetPersonId: id,
            alsoDeletesFamilyHealth: true,
          ),
          operationType: 'delete_health_guard',
        );
      }
      await _familyHealth.cascadeDeleteForPerson(id);
    }
    await _people.deleteProfile(id);
    return FamilyProfileCommandTurnResult(
      handled: true,
      message: pending.alsoDeletesFamilyHealth
          ? 'تم حذف ملف الشخص والمعلومات الصحية المرتبطة به.'
          : 'تم حذف ملف الشخص المطلوب فقط.',
      pending: FamilyProfilePendingOp.none,
      operationType: 'delete_confirmed',
    );
  }

  String _formatPersonBasic(FamilyPersonProfile p) {
    final parts = <String>[
      'العلاقة: ${_relationshipLabel(p.relationship)}',
      if (p.effectiveName != null) 'الاسم: ${p.effectiveName}',
      if (p.birthYear != null) 'سنة الميلاد: ${p.birthYear}',
      if (p.currentAge() != null) 'العمر التقريبي: ${p.currentAge()}',
      if (p.sexSelection != null) 'الجنس (اختياري): ${p.sexSelection!.name}',
      'الملف: ${p.profileEnabled ? "مفعّل" : "معطّل"}',
    ];
    return parts.join('\n');
  }

  String _birthNote(FamilyPersonProfile p) {
    if (p.birthYear != null) return 'سنة الميلاد: ${p.birthYear}.';
    return '';
  }

  String _relationshipLabel(PersonRelationship r) {
    switch (r) {
      case PersonRelationship.son:
        return 'ابنك';
      case PersonRelationship.daughter:
        return 'بنتك';
      case PersonRelationship.child:
        return 'طفلك';
      case PersonRelationship.mother:
        return 'أمك';
      case PersonRelationship.father:
        return 'أبوك';
      case PersonRelationship.wife:
        return 'زوجتك';
      case PersonRelationship.husband:
        return 'زوجك';
      case PersonRelationship.spouse:
        return 'زوج/ة';
      default:
        return 'شخص العائلة';
    }
  }
}
