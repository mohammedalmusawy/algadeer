/// حالات موافقة الذاكرة — عقد فقط، بلا تخزين دائم في PC-0.4.

enum MemoryConsentState {
  notRequired,
  required,
  pending,
  granted,
  declined,
  revoked,
}

/// سياسة موافقة — حتمية.
class MemoryConsentPolicy {
  const MemoryConsentPolicy();

  /// هل يجوز لطبقة تخزين مستقبلية الكتابة؟
  bool mayPersist(MemoryConsentState state) {
    return state == MemoryConsentState.granted;
  }

  /// هل يجوز استخدام الذاكرة المسترجَعة في المحادثة؟
  bool mayUse(MemoryConsentState state) {
    return state == MemoryConsentState.granted;
  }

  MemoryConsentState afterDecline(MemoryConsentState _) =>
      MemoryConsentState.declined;

  MemoryConsentState afterRevoke(MemoryConsentState _) =>
      MemoryConsentState.revoked;

  MemoryConsentState afterGrant(MemoryConsentState current) {
    if (current == MemoryConsentState.declined ||
        current == MemoryConsentState.revoked) {
      // منح جديد يتطلّب تدفقاً صريحاً مستقبلياً — لا إعادة تفعيل صامتة هنا.
      return MemoryConsentState.pending;
    }
    return MemoryConsentState.granted;
  }
}
