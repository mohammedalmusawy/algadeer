import '../health/subject/health_subject_models.dart';

/// مالك منطقي لمرشّح الذاكرة — يفصل صاحب الحساب عن موضوع الصحة.
enum MemoryOwnerKind {
  /// صاحب حساب الغدير.
  accountOwner,

  /// ملف عائلة دائم مستقبلي (لم يُنشأ بعد).
  persistentFamilyProfile,

  /// موضوع جلسة مؤقت (PC-0.3) — لا يتحول صامتاً إلى ملف عائلة.
  temporarySubject,
}

/// مرجع موضوع — بلا اسم خام في الـ debug.
class MemorySubjectRef {
  const MemorySubjectRef({
    required this.ownerKind,
    required this.subjectType,
    this.sessionSubjectKey,
    this.persistentProfileId,
  });

  final MemoryOwnerKind ownerKind;
  final HealthSubjectType subjectType;

  /// مفتاح جلسة مؤقت — إن وُجد.
  final String? sessionSubjectKey;

  /// معرّف ملف دائم مستقبلي — دائماً null في PC-0.4.
  final String? persistentProfileId;

  static MemorySubjectRef accountSelf() => const MemorySubjectRef(
        ownerKind: MemoryOwnerKind.accountOwner,
        subjectType: HealthSubjectType.self,
      );

  static MemorySubjectRef temporary(HealthSubjectType type, {String? key}) =>
      MemorySubjectRef(
        ownerKind: MemoryOwnerKind.temporarySubject,
        subjectType: type,
        sessionSubjectKey: key,
      );

  /// temporarySubject لا يُرقّى تلقائياً إلى ملف عائلة دائم.
  bool get mayAutoCreateFamilyProfile => false;

  bool get belongsToAccountOwner =>
      ownerKind == MemoryOwnerKind.accountOwner &&
      subjectType == HealthSubjectType.self;

  Map<String, Object?> debugMap() => {
        'ownerKind': ownerKind.name,
        'subjectType': subjectType.name,
        'hasSessionSubjectKey': sessionSubjectKey != null,
        'hasPersistentProfileId': persistentProfileId != null,
      };
}
