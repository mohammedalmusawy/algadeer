import 'personal_memory_models.dart';
import 'personal_memory_service.dart';

enum PersonalMemoryRetrievalPurpose {
  unrelatedEntitySearch,
  generalChat,
  doctorQuery,
  learningAdvice,
  contentCreationHelp,
  showPersonalMemory,
  aboutMeSummary,
}

/// استرجاع محدود الغرض — بلا حقن غير ذي صلة.
class PersonalMemoryRetrievalPolicy {
  const PersonalMemoryRetrievalPolicy();

  Future<List<CompanionPersonalMemoryRecord>> retrieveRelevant({
    required PersonalMemoryService service,
    required PersonalMemoryRetrievalPurpose purpose,
    String? queryHint,
  }) async {
    if (purpose == PersonalMemoryRetrievalPurpose.unrelatedEntitySearch ||
        purpose == PersonalMemoryRetrievalPurpose.doctorQuery ||
        purpose == PersonalMemoryRetrievalPurpose.generalChat) {
      return const [];
    }

    try {
      final all = await service.listAll();
      final active = all
          .where((r) => r.status == PersonalMemoryStatus.active)
          .toList();

      switch (purpose) {
        case PersonalMemoryRetrievalPurpose.showPersonalMemory:
        case PersonalMemoryRetrievalPurpose.aboutMeSummary:
          return active;
        case PersonalMemoryRetrievalPurpose.learningAdvice:
          return active
              .where(
                (r) =>
                    r.memoryType == PersonalMemoryType.goal &&
                    (r.category.contains('learn') ||
                        r.category == PersonalGoalCategory.technology.name ||
                        r.category ==
                            PersonalGoalCategory.languageLearning.name ||
                        r.category == PersonalGoalCategory.education.name ||
                        r.canonicalKey.contains('learn')),
              )
              .toList(growable: false);
        case PersonalMemoryRetrievalPurpose.contentCreationHelp:
          return active
              .where(
                (r) =>
                    r.category ==
                        PersonalInterestCategory.contentCreation.name ||
                    r.category == PersonalGoalCategory.contentCreation.name ||
                    r.canonicalKey.contains('content'),
              )
              .toList(growable: false);
        default:
          return const [];
      }
    } catch (_) {
      return const [];
    }
  }

  PersonalMemoryRetrievalPurpose purposeForQuery(String query) {
    final q = query.trim().replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
    if (RegExp(r'(?:طبيب|دكتور|مختبر|قلب)').hasMatch(q)) {
      return PersonalMemoryRetrievalPurpose.doctorQuery;
    }
    if (RegExp(r'(?:اتعلم|شنو\s*تنصحني\s*اتعلم)').hasMatch(q)) {
      return PersonalMemoryRetrievalPurpose.learningAdvice;
    }
    if (RegExp(r'(?:محتوي|محتوى|مونتاج|تصوير)').hasMatch(q)) {
      return PersonalMemoryRetrievalPurpose.contentCreationHelp;
    }
    return PersonalMemoryRetrievalPurpose.generalChat;
  }
}
