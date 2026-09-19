import '../search/smart_search_models.dart';
import 'conversation_context.dart';
import 'result_context.dart';

/// علاقات معروفة في بيانات الغدير فقط — بدون استدلال طبي.
enum EntityRelationKind {
  analysisToPackages,
  analysisToLabsViaPackages,
  packageToLaboratory,
  packageToAnalyses,
  laboratoryToPackages,
  laboratoryToAnalysesViaPackages,
  doctorToClinic,
}

class EntityRelationshipResolution {
  const EntityRelationshipResolution({
    required this.kind,
    required this.fromType,
    required this.toType,
    this.from,
    this.related = const [],
    this.message = '',
    this.unavailable = false,
  });

  final EntityRelationKind kind;
  final ConversationEntityType fromType;
  final ConversationEntityType toType;
  final SmartSearchResult? from;
  final List<SmartSearchResult> related;
  final String message;
  final bool unavailable;

  bool get hasRelated => related.isNotEmpty;
}

/// يجتاز علاقات التطبيق/قاعدة البيانات المعروفة فقط.
class EntityRelationshipResolver {
  const EntityRelationshipResolver();

  /// مختبر أب لباقة محفوظة — من الحقول المخزّنة أو مرجع حديث.
  EntityRelationshipResolution packageParentLaboratory(
    ConversationContext context, {
    SmartSearchResult? package,
  }) {
    final pkg = package ?? context.selectedPackage;
    if (pkg == null) {
      return const EntityRelationshipResolution(
        kind: EntityRelationKind.packageToLaboratory,
        fromType: ConversationEntityType.package,
        toType: ConversationEntityType.laboratory,
        message: 'ما عندي باقة محددة لاستخراج المختبر.',
        unavailable: true,
      );
    }

    final labId = (pkg.labId ?? '').trim();
    if (labId.isEmpty) {
      return EntityRelationshipResolution(
        kind: EntityRelationKind.packageToLaboratory,
        fromType: ConversationEntityType.package,
        toType: ConversationEntityType.laboratory,
        from: pkg,
        message:
            'المختبر المرتبط بهذه الباقة غير متوفر حالياً في بيانات الغدير.',
        unavailable: true,
      );
    }

    // فضّل selectedLaboratory إن طابق نفس المعرّف.
    final selected = context.selectedLaboratory;
    if (selected != null && (selected.labId ?? '') == labId) {
      return EntityRelationshipResolution(
        kind: EntityRelationKind.packageToLaboratory,
        fromType: ConversationEntityType.package,
        toType: ConversationEntityType.laboratory,
        from: pkg,
        related: [selected],
      );
    }

    // ابحث في المراجع الحديثة.
    for (final ref in context.recentReferences) {
      if (ref.entityType == ConversationEntityType.laboratory &&
          ref.entityId == labId) {
        return EntityRelationshipResolution(
          kind: EntityRelationKind.packageToLaboratory,
          fromType: ConversationEntityType.package,
          toType: ConversationEntityType.laboratory,
          from: pkg,
          related: [ref.payload],
        );
      }
    }

    final labName = (pkg.labName ?? pkg.subtitle).trim();
    final synthetic = SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: labName.isNotEmpty ? labName : 'مختبر',
      subtitle: pkg.clinicLocation ?? 'مختبر',
      labId: labId,
      labName: labName.isNotEmpty ? labName : null,
      clinicLocation: pkg.clinicLocation,
      phone: pkg.phone,
      whatsapp: pkg.whatsapp,
    );
    return EntityRelationshipResolution(
      kind: EntityRelationKind.packageToLaboratory,
      fromType: ConversationEntityType.package,
      toType: ConversationEntityType.laboratory,
      from: pkg,
      related: [synthetic],
    );
  }

  /// هل الفعل متوافق مع نوع الكيان؟
  bool isActionCompatible({
    required ConversationEntityType entityType,
    required String actionFamily,
  }) {
    switch (actionFamily) {
      case 'call':
      case 'whatsapp':
        return EntityActionCompatibility.supportsCall(entityType);
      case 'location':
        return EntityActionCompatibility.supportsLocation(entityType);
      case 'price':
        return EntityActionCompatibility.supportsPrice(entityType);
      case 'analyses':
        return EntityActionCompatibility.supportsAnalysesList(entityType);
      case 'packages':
        return EntityActionCompatibility.supportsPackagesList(entityType);
      default:
        return true;
    }
  }
}
