/// رسالة واحدة لمسار الإدارة ومسار المالك عند تعارض النسخة.
const contentConflictMessage =
    'تعذر الحفظ لأن البيانات تغيّرت من جهة أخرى. ما كتبته ما زال في النموذج.';

class ContentConflictException implements Exception {
  const ContentConflictException();

  @override
  String toString() => contentConflictMessage;
}

/// يظهر نص التعارض كما هو، وأي خطأ آخر بالعبارة الاحتياطية.
String messageForSaveError(Object error, String fallback) {
  if (error is ContentConflictException ||
      '$error'.contains(contentConflictMessage)) {
    return contentConflictMessage;
  }
  return fallback;
}
