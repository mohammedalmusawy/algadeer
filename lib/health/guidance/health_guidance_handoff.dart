import '../../search/smart_search_models.dart';
import '../../voice/conversation_context.dart';
import 'health_guidance_models.dart';

/// حالة تسليم التوجيه الصحي إلى مزوّدين حقيقيين — جلسة فقط.
enum HealthGuidanceHandoffStatus {
  inactive,
  awaitingAcceptance,
  accepted,
  declined,
  providersDisplayed,
  completed,
  unsupported,
  empty,
}

/// تسليم آمن من وجهة توجيه إلى بيانات الغدير الحقيقية.
class HealthGuidanceHandoff {
  const HealthGuidanceHandoff({
    this.status = HealthGuidanceHandoffStatus.inactive,
    this.destination,
    this.providerResultCount = 0,
    this.providerResultEntityType = ConversationEntityType.none,
    this.subjectTypeName,
  });

  final HealthGuidanceHandoffStatus status;
  final GuidanceDestination? destination;
  final int providerResultCount;
  final ConversationEntityType providerResultEntityType;

  /// نوع الموضوع الصحي عند التسليم (ميتاداتا فقط — بلا أعراض).
  final String? subjectTypeName;

  static const inactive = HealthGuidanceHandoff();

  bool get isAwaitingAcceptance =>
      status == HealthGuidanceHandoffStatus.awaitingAcceptance;

  bool get blocksFurtherHealthQuestions =>
      status == HealthGuidanceHandoffStatus.accepted ||
      status == HealthGuidanceHandoffStatus.providersDisplayed ||
      status == HealthGuidanceHandoffStatus.completed ||
      status == HealthGuidanceHandoffStatus.declined;

  HealthGuidanceHandoff copyWith({
    HealthGuidanceHandoffStatus? status,
    GuidanceDestination? destination,
    int? providerResultCount,
    ConversationEntityType? providerResultEntityType,
    String? subjectTypeName,
    bool clearDestination = false,
  }) {
    return HealthGuidanceHandoff(
      status: status ?? this.status,
      destination:
          clearDestination ? null : (destination ?? this.destination),
      providerResultCount: providerResultCount ?? this.providerResultCount,
      providerResultEntityType:
          providerResultEntityType ?? this.providerResultEntityType,
      subjectTypeName: subjectTypeName ?? this.subjectTypeName,
    );
  }

  Map<String, Object?> debugMap() => {
        'handoffStatus': status.name,
        'handoffDestinationType': destination?.type.name,
        'handoffDestinationKey': destination?.key,
        'providerResultEntityType': providerResultEntityType.name,
        'providerResultCount': providerResultCount,
        'handoffSubjectType': subjectTypeName,
      };
}

enum ProviderDiscoveryStatus {
  found,
  empty,
  unsupported,
}

/// نتيجة اكتشاف مزوّدين — كيانات موجودة فقط، بلا اختراع.
class ProviderDiscoveryResult {
  const ProviderDiscoveryResult({
    required this.destination,
    required this.entityType,
    required this.status,
    this.items = const [],
    this.message = '',
  });

  final GuidanceDestination destination;
  final ConversationEntityType entityType;
  final ProviderDiscoveryStatus status;
  final List<SmartSearchResult> items;
  final String message;

  static ProviderDiscoveryResult unsupported(GuidanceDestination d) =>
      ProviderDiscoveryResult(
        destination: d,
        entityType: ConversationEntityType.none,
        status: ProviderDiscoveryStatus.unsupported,
        message: 'هذا النوع من الخدمات غير متاح للاكتشاف حالياً ضمن بيانات الغدير.',
      );

  static ProviderDiscoveryResult empty(
    GuidanceDestination d, {
    required ConversationEntityType entityType,
    required String message,
  }) =>
      ProviderDiscoveryResult(
        destination: d,
        entityType: entityType,
        status: ProviderDiscoveryStatus.empty,
        message: message,
      );
}
