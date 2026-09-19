/// دورة حياة جلسة ConversationContext — وصف للأسباب القائمة، بلا سلوك طبي جديد.
///
/// العدّاد [kInitialConversationGeneration] يتغيّر فقط عند انتقال موضوع
/// الجلسة السريرية/الكاملة. بحث النتائج وإبطال ResultContext لا يحرّكانه.
library;

/// الجيل الابتدائي لكائن ConversationContext جديد.
const int kInitialConversationGeneration = 0;

/// لماذا أُعيد تعيين حالة الجلسة (أو جُزء منها في الوثائق).
///
/// القيم المستخدمة لتغيير [ConversationContext.conversationGeneration]:
/// [explicitUserReset]، [pageDisposed]، [foreignTurn]، [subjectChanged].
///
/// مسارات قائمة لا تغيّر الجيل: beginNew*Search،
/// invalidateAuthoritativeResultContext، invalidateSiblingClinicalSessions،
/// rememberQuery / الدور العادي.
enum ConversationResetReason {
  /// بعد الإنشاء، قبل أي إعادة تعيين تحرّك الجيل.
  none,

  /// [ConversationContext.reset] لاستئناف جلسة كاملة.
  explicitUserReset,

  /// نفس أثر reset الكامل عند التخلص من صفحة البحث لاحقاً.
  pageDisposed,

  /// [ConversationContext.clearClinicalPackSessionsForForeignTurn]
  /// (بحث خدمة / تحية / إلغاء حسب التحكيم القائم).
  foreignTurn,

  /// [ConversationContext.clearClinicalPackSessionsForSubjectSwitch]
  /// عند تبديل موضوع الشخص.
  subjectChanged,
}
