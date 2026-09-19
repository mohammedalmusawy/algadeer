import '../../companion/people/family_person_profile.dart';
import '../sensitive_profile/sensitive_health_profile_models.dart';
import 'family_sensitive_health_models.dart';
import 'family_sensitive_health_service.dart';

enum FamilyHealthRetrievalPurpose {
  unrelatedEntitySearch,
  generalChat,
  greeting,
  doctorBrowsing,
  labBrowsing,
  offersPackages,
  healthConversation,
  showFamilyHealth,
  diabetesRelated,
  hypertensionRelated,
  asthmaRelated,
}

/// استرجاع محدود الغرض — فقط عندما الشخص النشط صحيّاً.
class FamilySensitiveHealthRetrievalPolicy {
  const FamilySensitiveHealthRetrievalPolicy();

  Future<List<FamilyHealthConditionRecord>> retrieveRelevant({
    required FamilySensitiveHealthService service,
    required FamilyHealthRetrievalPurpose purpose,
    required String? activePersistentPersonId,
    FamilyPersonProfile? personProfile,
    String? queryHint,
  }) async {
    if (purpose == FamilyHealthRetrievalPurpose.unrelatedEntitySearch ||
        purpose == FamilyHealthRetrievalPurpose.generalChat ||
        purpose == FamilyHealthRetrievalPurpose.greeting ||
        purpose == FamilyHealthRetrievalPurpose.doctorBrowsing ||
        purpose == FamilyHealthRetrievalPurpose.labBrowsing ||
        purpose == FamilyHealthRetrievalPurpose.offersPackages) {
      return const [];
    }

    final personId = activePersistentPersonId;
    if (personId == null || personId.isEmpty) return const [];
    if (personProfile != null && !personProfile.profileEnabled) {
      return const [];
    }

    try {
      final profile = await service.loadForPerson(personId);
      if (profile == null || profile.conditions.isEmpty) return const [];

      if (purpose == FamilyHealthRetrievalPurpose.showFamilyHealth) {
        return List.unmodifiable(
          profile.conditions
              .where((c) => c.consentState == HealthConsentState.granted)
              .toList(),
        );
      }

      final keys = <String>{};
      switch (purpose) {
        case FamilyHealthRetrievalPurpose.diabetesRelated:
          keys.add(HealthCanonicalConditionKey.diabetes.name);
        case FamilyHealthRetrievalPurpose.hypertensionRelated:
          keys.add(HealthCanonicalConditionKey.hypertension.name);
        case FamilyHealthRetrievalPurpose.asthmaRelated:
          keys.add(HealthCanonicalConditionKey.asthma.name);
        case FamilyHealthRetrievalPurpose.healthConversation:
          final q = (queryHint ?? '').toLowerCase();
          if (q.contains('سكر')) {
            keys.add(HealthCanonicalConditionKey.diabetes.name);
          }
          if (q.contains('ضغط')) {
            keys.add(HealthCanonicalConditionKey.hypertension.name);
          }
          if (q.contains('ربو')) {
            keys.add(HealthCanonicalConditionKey.asthma.name);
          }
          if (keys.isEmpty) return const [];
        default:
          return const [];
      }

      return profile.conditions
          .where(
            (c) =>
                keys.contains(c.canonicalConditionKey) &&
                c.consentState == HealthConsentState.granted,
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  FamilyHealthRetrievalPurpose purposeForQuery(String query) {
    final q = query.trim();
    if (q.isEmpty) return FamilyHealthRetrievalPurpose.generalChat;
    if (RegExp(r'(?:مرحبا|السلام|صباح|مساء)').hasMatch(q)) {
      return FamilyHealthRetrievalPurpose.greeting;
    }
    if (RegExp(r'(?:باقه|باقة|عرض)').hasMatch(q) &&
        !RegExp(r'(?:سكر|ضغط|ربو|صحت)').hasMatch(q)) {
      return FamilyHealthRetrievalPurpose.offersPackages;
    }
    if (RegExp(r'(?:مختبر|تحليل)').hasMatch(q) &&
        !RegExp(r'(?:سكر|ضغط|ربو|صحت)').hasMatch(q)) {
      return FamilyHealthRetrievalPurpose.labBrowsing;
    }
    if (RegExp(r'(?:طبيب|دكتور)').hasMatch(q) &&
        !RegExp(r'(?:سكر|ضغط|ربو|صحت)').hasMatch(q)) {
      return FamilyHealthRetrievalPurpose.doctorBrowsing;
    }
    if (RegExp(r'سكر').hasMatch(q)) {
      return FamilyHealthRetrievalPurpose.diabetesRelated;
    }
    if (RegExp(r'ضغط').hasMatch(q)) {
      return FamilyHealthRetrievalPurpose.hypertensionRelated;
    }
    if (RegExp(r'ربو').hasMatch(q)) {
      return FamilyHealthRetrievalPurpose.asthmaRelated;
    }
    if (RegExp(r'(?:صحت|عرض|الم|ألم)').hasMatch(q)) {
      return FamilyHealthRetrievalPurpose.healthConversation;
    }
    return FamilyHealthRetrievalPurpose.generalChat;
  }
}
