/// PC-0.4 — تصنيف فئات الذاكرة المستقبلية.
///
/// لا تخزين دائم في هذه الخطوة.
/// SYMPTOM ≠ DIAGNOSIS
/// SESSION STATE ≠ PERSISTENT MEMORY

/// فئات الذاكرة — سياسة المنتج، وليست جداول قاعدة بيانات.
enum MemoryCategory {
  /// سياق المحادثة الحالي — جلسة فقط دائماً.
  sessionConversation,

  /// ملف شخصي للحساب (اسم مفضّل، إلخ) — مستقبلي بموافقة.
  personalProfile,

  /// تفضيل شخصي منخفض المخاطر — مستقبلي.
  personalPreference,

  /// اهتمامات — مستقبلي.
  interest,

  /// أهداف — مستقبلي.
  goal,

  /// التزام متابعة (اسأل لاحقاً) — منفصل عن الحقائق.
  followUpCommitment,

  /// ملف صحي حسّاس — موافقة صريحة إلزامية دائماً.
  sensitiveHealthProfile,

  /// ملف فرد عائلة دائم — موافقة/إنشاء صريح، لا من temporarySubject.
  familyPersonProfile,

  /// تفضيلات واجهة محلية (صوت TTS، إلخ) — ليست ذاكرة صحية.
  uiPreference,
}

/// مستوى الحساسية.
enum MemorySensitivity {
  standard,
  personal,
  sensitiveHealth,
}

/// نوع المصدر الذي أنتج المرشّح.
enum MemorySourceType {
  userExplicitCommand,
  userExplicitStatement,
  symptomConversation,
  clinicianAttributedStatement,
  inferredUnsafe,
  systemProposed,
}

/// مفاتيح حقائق صحية مستقبلية — مرشّحات فقط، بلا تشخيص تلقائي من أعراض.
enum HealthMemoryStructuredKey {
  diagnosedCondition,
  allergy,
  currentMedication,
  importantProcedure,
}

extension MemoryCategoryPolicy on MemoryCategory {
  MemorySensitivity get defaultSensitivity {
    switch (this) {
      case MemoryCategory.sensitiveHealthProfile:
        return MemorySensitivity.sensitiveHealth;
      case MemoryCategory.personalProfile:
      case MemoryCategory.familyPersonProfile:
      case MemoryCategory.followUpCommitment:
      case MemoryCategory.interest:
      case MemoryCategory.goal:
        return MemorySensitivity.personal;
      case MemoryCategory.personalPreference:
      case MemoryCategory.uiPreference:
      case MemoryCategory.sessionConversation:
        return MemorySensitivity.standard;
    }
  }

  /// الصحة الحساسة تتطلب موافقة صريحة دائماً قبل أي تخزين مستقبلي.
  bool get alwaysRequiresExplicitConsent =>
      this == MemoryCategory.sensitiveHealthProfile ||
      this == MemoryCategory.familyPersonProfile;

  bool get isSessionOnlyByPolicy =>
      this == MemoryCategory.sessionConversation;
}
