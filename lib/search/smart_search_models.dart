/// أنواع نتائج البحث الذكي — العروض = باقات عليها خصم حقيقي من lab_packages.
enum SmartSearchResultType {
  doctor,
  specialty,
  lab,
  package,
  offer,
  analysis,
}

/// نتيجة بحث غنية بما يكفي لعرض Card حقيقية والتنقل المباشر.
class SmartSearchResult {
  const SmartSearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    this.doctorId,
    this.labId,
    this.packageId,
    this.analysisId,
    this.score = 0,
    this.imageUrl,
    this.specialty,
    this.labName,
    this.oldPrice,
    this.newPrice,
    this.discountPercent,
    this.absenceBadge,
    this.availabilityLabel,
    this.bioSnippet,
    this.isOnLeave = false,
    this.relatedAnalysisId,
    this.relatedAnalysisTitle,
    this.phone,
    this.whatsapp,
    this.clinicLocation,
    this.bookingStatus,
    this.workingDays,
    this.workingHours,
    this.absenceFrom,
    this.absenceTo,
    this.gender,
    this.demandScore = 0,
  });

  final SmartSearchResultType type;
  final String title;
  final String subtitle;
  final String? doctorId;
  final String? labId;
  final String? packageId;
  final String? analysisId;
  final int score;

  /// حقول اختيارية لبطاقات البحث الغنية.
  final String? imageUrl;
  final String? specialty;
  final String? labName;
  final int? oldPrice;
  final int? newPrice;
  final int? discountPercent;
  final String? absenceBadge;
  final String? availabilityLabel;
  final String? bioSnippet;
  final bool isOnLeave;

  /// عند البحث عن تحليل: ربط الباقة بالتحليل الأصلي.
  final String? relatedAnalysisId;
  final String? relatedAnalysisTitle;

  /// للتواصل المباشر من أوامر الصوت/النص.
  final String? phone;
  final String? whatsapp;

  /// موقع العيادة الحقيقي من clinic_location — بدون اختراع.
  final String? clinicLocation;

  /// حقول تواجد الطبيب الخام من Supabase (للجواب عن «متواجد اليوم» والترتيب).
  final String? bookingStatus;
  final String? workingDays;
  final String? workingHours;
  final String? absenceFrom;
  final String? absenceTo;
  final String? gender;

  /// مؤشر الطلب الحقيقي (مشاهدات + اتصال + واتساب) — للترتيب «الأكثر طلبًا» فقط.
  final int demandScore;

  String get effectivePhone => phone?.trim() ?? '';
  String get effectiveWhatsApp {
    final w = whatsapp?.trim() ?? '';
    if (w.isNotEmpty) return w;
    return effectivePhone;
  }

  bool get canCall => effectivePhone.isNotEmpty;
  bool get canWhatsApp => effectiveWhatsApp.isNotEmpty;

  bool get isOffer =>
      type == SmartSearchResultType.offer ||
      (discountPercent != null && discountPercent! > 0);

  bool get hasNavigableEntity {
    switch (type) {
      case SmartSearchResultType.doctor:
        return doctorId != null && doctorId!.isNotEmpty;
      case SmartSearchResultType.lab:
        return labId != null && labId!.isNotEmpty;
      case SmartSearchResultType.package:
      case SmartSearchResultType.offer:
        return packageId != null &&
            packageId!.isNotEmpty &&
            labId != null &&
            labId!.isNotEmpty;
      case SmartSearchResultType.analysis:
        return analysisId != null && analysisId!.isNotEmpty;
      case SmartSearchResultType.specialty:
        return title.trim().isNotEmpty;
    }
  }

  /// النتائج الدلالية للعدّ والرسالة.
  ///
  /// بطاقة الاختصاص تُولَّد مع كل طبيب كمساعدة تنقّل، فلا تُحتسب كياناً
  /// مستقلاً — وإلا صار «طبيب واحد + بطاقة اختصاصه» = «وجدت 2 نتائج».
  static List<SmartSearchResult> semanticPrimary(
    List<SmartSearchResult> results,
  ) {
    final primary = results
        .where((r) => r.type != SmartSearchResultType.specialty)
        .toList();
    return primary.isNotEmpty ? primary : results;
  }

  Map<String, dynamic> toAiContext() => {
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        if (doctorId != null) 'doctor_id': doctorId,
        if (labId != null) 'lab_id': labId,
        if (packageId != null) 'package_id': packageId,
        if (analysisId != null) 'analysis_id': analysisId,
        if (discountPercent != null) 'discount_percent': discountPercent,
        if (newPrice != null) 'price': newPrice,
      };
}

/// Intent منظم من AI أو من المحلّل المحلي — لا يخترع بيانات تجارية.
class AssistantStructuredIntent {
  const AssistantStructuredIntent({
    this.intent = 'search',
    this.entityType,
    this.searchTerms = const [],
    this.filters = const {},
    this.directIfSingleConfidentMatch = true,
    this.urgency = 'low',
    this.recommendedSpecialties = const [],
    this.reason,
  });

  final String intent;
  final String? entityType;
  final List<String> searchTerms;
  final Map<String, dynamic> filters;
  final bool directIfSingleConfidentMatch;
  final String urgency;
  final List<String> recommendedSpecialties;
  final String? reason;

  bool get isUrgent =>
      urgency == 'high' || urgency == 'emergency' || urgency == 'urgent';

  factory AssistantStructuredIntent.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AssistantStructuredIntent();

    final termsRaw = json['search_terms'];
    final terms = <String>[];
    if (termsRaw is List) {
      for (final t in termsRaw) {
        final s = '$t'.trim();
        if (s.isNotEmpty) terms.add(s);
      }
    }

    final specsRaw = json['recommended_specialties'] ?? json['priority'];
    final specs = <String>[];
    if (specsRaw is List) {
      for (final s in specsRaw) {
        if (s is String && s.trim().isNotEmpty) {
          specs.add(s.trim());
        } else if (s is Map) {
          final name = (s['specialty'] ?? s['name'] ?? '').toString().trim();
          if (name.isNotEmpty) specs.add(name);
        }
      }
    }

    final filtersRaw = json['filters'];
    final filters = <String, dynamic>{};
    if (filtersRaw is Map) {
      filters.addAll(Map<String, dynamic>.from(filtersRaw));
    }

    final nav = json['navigation'];
    var direct = true;
    if (nav is Map && nav['direct_if_single_confident_match'] is bool) {
      direct = nav['direct_if_single_confident_match'] as bool;
    }

    return AssistantStructuredIntent(
      intent: (json['intent'] ?? 'search').toString(),
      entityType: json['entity_type']?.toString(),
      searchTerms: terms,
      filters: filters,
      directIfSingleConfidentMatch: direct,
      urgency: (json['urgency'] ?? 'low').toString(),
      recommendedSpecialties: specs,
      reason: json['reason']?.toString(),
    );
  }
}

/// قرار التنقل الذكي بعد Entity Resolution.
enum SmartNavAction {
  openDoctor,
  openLab,
  openPackage,
  openOffer,
  showResults,
  showSpecialtyDoctors,
  showAnalysisPackages,
  urgentCare,
  none,
}

class SmartNavigationDecision {
  const SmartNavigationDecision({
    required this.action,
    required this.message,
    this.target,
    this.confidence = 0,
    this.ambiguous = false,
  });

  final SmartNavAction action;
  final String message;
  final SmartSearchResult? target;
  final int confidence;
  final bool ambiguous;

  bool get shouldNavigateDirectly =>
      !ambiguous &&
      target != null &&
      confidence >= 80 &&
      (action == SmartNavAction.openDoctor ||
          action == SmartNavAction.openLab ||
          action == SmartNavAction.openPackage ||
          action == SmartNavAction.openOffer);
}
