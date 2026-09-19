import '../../doctors/specialty_catalog.dart';
import '../../search/arabic_text_utils.dart';
import '../../search/smart_search_models.dart';
import '../../search/smart_search_service.dart';
import '../../voice/conversation_context.dart';
import 'health_guidance_handoff.dart';
import 'health_guidance_models.dart';

typedef GuidanceDoctorLookup = Future<List<SmartSearchResult>> Function(
  String query,
);
typedef GuidanceLabLookup = Future<List<SmartSearchResult>> Function(
  String query,
);

/// يحوّل GuidanceDestination إلى اكتشاف مزوّدين عبر البنية القائمة فقط.
///
/// لا يخلق أسماء أطباء/مختبرات. لا يرتّب طبياً. لا يحجز مواعيد.
class GuidanceProviderDiscoveryService {
  GuidanceProviderDiscoveryService({
    SmartSearchService? search,
    GuidanceDoctorLookup? doctorLookup,
    GuidanceLabLookup? labLookup,
  })  : _search = search,
        _doctorLookup = doctorLookup,
        _labLookup = labLookup;

  final SmartSearchService? _search;
  final GuidanceDoctorLookup? _doctorLookup;
  final GuidanceLabLookup? _labLookup;

  Future<ProviderDiscoveryResult> discover(GuidanceDestination destination) {
    switch (destination.type) {
      case GuidanceDestinationType.specialty:
        return _discoverSpecialtyDoctors(destination);
      case GuidanceDestinationType.generalMedicalEvaluation:
        return _discoverSpecialtyDoctors(
          GuidanceDestination.specialtyFromCatalog('internal'),
        );
      case GuidanceDestinationType.laboratory:
        return discoverLaboratories(destination: destination);
      case GuidanceDestinationType.urgentEvaluation:
      case GuidanceDestinationType.diagnosticService:
      case GuidanceDestinationType.radiologyReserved:
      case GuidanceDestinationType.ultrasoundReserved:
      case GuidanceDestinationType.ctReserved:
      case GuidanceDestinationType.mriReserved:
        // جدار عاجل / تصوير / خدمات تشخيصية غير مكتملة — بلا بيانات وهمية.
        return Future.value(
          ProviderDiscoveryResult.unsupported(destination),
        );
    }
  }

  /// اكتشاف مختبر صريح فقط عند وجهة مختبر مستقبلية — عبر مسار المختبرات القائم.
  Future<ProviderDiscoveryResult> discoverLaboratories({
    required GuidanceDestination destination,
    String query = 'مختبر',
  }) async {
    final items = await _lookupLabs(query);
    if (items.isEmpty) {
      return ProviderDiscoveryResult.empty(
        destination,
        entityType: ConversationEntityType.laboratory,
        message: 'حالياً ما ظهر عندي مختبر مطابق ضمن بيانات الغدير.',
      );
    }
    return ProviderDiscoveryResult(
      destination: destination,
      entityType: ConversationEntityType.laboratory,
      status: ProviderDiscoveryStatus.found,
      items: items,
      message: 'هؤلاء المختبرات الموجودون ضمن بيانات الغدير.',
    );
  }

  Future<ProviderDiscoveryResult> _discoverSpecialtyDoctors(
    GuidanceDestination destination,
  ) async {
    final catalogId = destination.specialtyCatalogId ?? destination.key;
    SpecialtyDefinition? def;
    for (final s in SpecialtyCatalog.all) {
      if (s.id == catalogId) {
        def = s;
        break;
      }
    }
    final needle = def?.nameAr ?? destination.displayNameAr;
    if (needle.trim().isEmpty) {
      return ProviderDiscoveryResult.empty(
        destination,
        entityType: ConversationEntityType.doctor,
        message:
            'حالياً ما ظهر عندي طبيب بهذا الاختصاص ضمن بيانات الغدير.',
      );
    }

    final raw = await _lookupDoctors(needle);
    final doctors = filterDoctorsForSpecialty(
      raw,
      specialtyQuery: needle,
      resolvedName: needle,
      catalogId: catalogId,
    );

    if (doctors.isEmpty) {
      return ProviderDiscoveryResult.empty(
        destination,
        entityType: ConversationEntityType.doctor,
        message:
            'حالياً ما ظهر عندي طبيب بهذا الاختصاص ضمن بيانات الغدير.',
      );
    }

    return ProviderDiscoveryResult(
      destination: destination,
      entityType: ConversationEntityType.doctor,
      status: ProviderDiscoveryStatus.found,
      items: doctors,
      message:
          'هؤلاء الأطباء الموجودون ضمن الاختصاص في بيانات الغدير.',
    );
  }

  /// نفس منطق smart_search_page._doctorsForSpecialty تقريباً — بلا UI.
  static List<SmartSearchResult> filterDoctorsForSpecialty(
    List<SmartSearchResult> results, {
    required String specialtyQuery,
    required String resolvedName,
    String? catalogId,
  }) {
    final qNorm = ArabicTextUtils.normalize(specialtyQuery);
    final resolvedNorm = ArabicTextUtils.normalize(resolvedName);

    final doctors = results.where((r) {
      if (r.type != SmartSearchResultType.doctor) return false;
      final specialty = (r.specialty ?? '').trim();
      if (specialty.isEmpty) return false;
      final matched = SpecialtyCatalog.match(specialty);
      if (catalogId != null &&
          matched != null &&
          matched.id == catalogId) {
        return true;
      }
      final canon = ArabicTextUtils.normalize(matched?.nameAr ?? specialty);
      final raw = ArabicTextUtils.normalize(specialty);
      return canon.contains(resolvedNorm) ||
          resolvedNorm.contains(canon) ||
          raw.contains(qNorm) ||
          qNorm.contains(raw) ||
          canon.contains(qNorm) ||
          ArabicTextUtils.scoreMatch(specialty, specialtyQuery) >= 55 ||
          ArabicTextUtils.scoreMatch(specialty, resolvedName) >= 55;
    }).toList();

    doctors.sort((a, b) => b.score.compareTo(a.score));
    return doctors;
  }

  Future<List<SmartSearchResult>> _lookupDoctors(String query) async {
    final lookup = _doctorLookup;
    if (lookup != null) return lookup(query);
    final search = _search ?? SmartSearchService();
    return search.search(query, limit: 24);
  }

  Future<List<SmartSearchResult>> _lookupLabs(String query) async {
    final lookup = _labLookup;
    if (lookup != null) return lookup(query);
    final search = _search ?? SmartSearchService();
    return search.search(query.trim().isEmpty ? 'مختبر' : query, limit: 24);
  }
}
