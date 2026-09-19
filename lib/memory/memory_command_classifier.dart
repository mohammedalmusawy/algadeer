import '../search/arabic_text_utils.dart';
import 'memory_candidate.dart';

/// تصنيف أوامر تذكّر/نسيان/عرض مستقبلية — بلا تنفيذ تخزين.
enum MemoryCommandKind {
  none,
  remember,
  forget,
  delete,
  listWhatYouKnow,
  disableUse,
}

class MemoryCommandClassification {
  const MemoryCommandClassification({
    required this.kind,
    required this.operation,
    this.requiresConfirmationEvenIfExplicit = false,
    this.notes = '',
  });

  final MemoryCommandKind kind;
  final PersonalMemoryOperation? operation;
  final bool requiresConfirmationEvenIfExplicit;
  final String notes;

  static const none = MemoryCommandClassification(
    kind: MemoryCommandKind.none,
    operation: null,
  );

  /// PC-0.4: لا مستودع → لا ادّعاء حذف/حفظ.
  bool get performsPersistence => false;
  bool get claimsDeletionCompleted => false;
  bool get returnsStoredMemories => false;
}

class MemoryCommandClassifier {
  const MemoryCommandClassifier();

  MemoryCommandClassification classify(String text) {
    final n = ArabicTextUtils.normalize(text);
    if (n.isEmpty) return MemoryCommandClassification.none;

    if (RegExp(
      r'(?:شنو|ماذا|ايش)\s*(?:تعرف|تعرفه)\s*(?:عني|علي)|'
      r'وش\s*تعرف\s*عني',
    ).hasMatch(n)) {
      return const MemoryCommandClassification(
        kind: MemoryCommandKind.listWhatYouKnow,
        operation: PersonalMemoryOperation.list,
        notes: 'future_list_no_fake_memory',
      );
    }

    if (RegExp(
      r'(?:احذف|امسح)\s*(?:هذه|هذي|هاي)?\s*(?:المعلومه|المعلومة|الذاكره|الذاكرة)|'
      r'لا\s*تتذكر\s*(?:هذا|هذ)|'
      r'انس[ىي]?\s*(?:هذا|هذ|المعلوم)',
    ).hasMatch(n)) {
      return const MemoryCommandClassification(
        kind: MemoryCommandKind.delete,
        operation: PersonalMemoryOperation.delete,
        notes: 'future_delete_requires_repository',
      );
    }

    if (RegExp(
      r'(?:تذكر|تذكّر|خلي\s*ببالك|احفظ|لا\s*تنسى)(?:\s|$)|'
      r'(?:تذكر|احفظ)\s*.+',
    ).hasMatch(n)) {
      return const MemoryCommandClassification(
        kind: MemoryCommandKind.remember,
        operation: PersonalMemoryOperation.add,
        requiresConfirmationEvenIfExplicit: true,
        notes:
            'future_explicit_save_still_needs_consent_for_sensitive_health',
      );
    }

    return MemoryCommandClassification.none;
  }
}
