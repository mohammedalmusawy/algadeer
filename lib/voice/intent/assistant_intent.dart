/// نيات المساعد — Phase 1 يؤسّس المعمارية؛ الكتالوج الكامل في Phase 2+.
enum AssistantIntent {
  generalSearch,
  doctorSearch,
  specialtySearch,
  unknown,

  // محجوزة للتوسّع لاحقًا — لا تُفعَّل في Phase 1.
  findLab,
  findPackage,
  findOffer,
  findAnalysis,
  doctorAvailability,
  bookAppointment,
  callDoctor,
  messageDoctor,
  callLab,
  messageLab,
  showLocation,
  showProfile,
  showMore,
  selectResult,
  repeatResponse,
  stopSpeaking,
  help,
  symptomGuidance,
}
