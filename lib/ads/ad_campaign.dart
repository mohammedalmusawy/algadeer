class AdCampaign {
  const AdCampaign({
    required this.id,
    required this.title,
    this.body = '',
    this.mediaType = 'image',
    this.imageUrl = '',
    this.videoUrl = '',
    this.clickUrl = '',
    this.placement = 'home',
    this.isActive = false,
    this.startsAt,
    this.endsAt,
    this.displaySeconds = 0,
    this.maxTotalImpressions,
    this.maxPerUser = 3,
    this.maxPerUserPerDay = 1,
    this.impressionCount = 0,
    this.clickCount = 0,
    this.priority = 0,
  });

  final String id;
  final String title;
  final String body;
  final String mediaType;
  final String imageUrl;
  final String videoUrl;
  final String clickUrl;
  final String placement;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int displaySeconds;
  final int? maxTotalImpressions;
  final int maxPerUser;
  final int maxPerUserPerDay;
  final int impressionCount;
  final int clickCount;
  final int priority;

  bool get isVideo => mediaType.trim().toLowerCase() == 'video';
  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasVideo => videoUrl.trim().isNotEmpty;

  bool get isWithinSchedule {
    final now = DateTime.now().toUtc();
    if (startsAt != null && now.isBefore(startsAt!.toUtc())) return false;
    if (endsAt != null && now.isAfter(endsAt!.toUtc())) return false;
    return true;
  }

  bool get hasReachedGlobalCap {
    final max = maxTotalImpressions;
    if (max == null || max <= 0) return false;
    return impressionCount >= max;
  }

  factory AdCampaign.fromMap(Map<String, dynamic> data) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    int? parseNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    int parseInt(dynamic v, int fallback) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    return AdCampaign(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      mediaType: data['media_type']?.toString() ?? 'image',
      imageUrl: data['image_url']?.toString() ?? '',
      videoUrl: data['video_url']?.toString() ?? '',
      clickUrl: data['click_url']?.toString() ?? '',
      placement: data['placement']?.toString() ?? 'home',
      isActive: data['is_active'] == true,
      startsAt: parseTs(data['starts_at']),
      endsAt: parseTs(data['ends_at']),
      displaySeconds: parseInt(data['display_seconds'], 0),
      maxTotalImpressions: parseNullableInt(data['max_total_impressions']),
      maxPerUser: parseInt(data['max_per_user'], 3),
      maxPerUserPerDay: parseInt(data['max_per_user_per_day'], 1),
      impressionCount: parseInt(data['impression_count'], 0),
      clickCount: parseInt(data['click_count'], 0),
      priority: parseInt(data['priority'], 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'body': body.trim(),
      'media_type': isVideo ? 'video' : 'image',
      'image_url': imageUrl.trim(),
      'video_url': videoUrl.trim(),
      'click_url': clickUrl.trim(),
      'placement': placement.trim().isEmpty ? 'home' : placement.trim(),
      'is_active': isActive,
      'starts_at': startsAt?.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'display_seconds': displaySeconds < 0 ? 0 : displaySeconds,
      'max_total_impressions': maxTotalImpressions,
      'max_per_user': maxPerUser < 0 ? 0 : maxPerUser,
      'max_per_user_per_day': maxPerUserPerDay < 0 ? 0 : maxPerUserPerDay,
      'priority': priority,
    };
  }

  AdCampaign copyWith({
    String? id,
    String? title,
    String? body,
    String? mediaType,
    String? imageUrl,
    String? videoUrl,
    String? clickUrl,
    String? placement,
    bool? isActive,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearStartsAt = false,
    bool clearEndsAt = false,
    int? displaySeconds,
    int? maxTotalImpressions,
    bool clearMaxTotal = false,
    int? maxPerUser,
    int? maxPerUserPerDay,
    int? impressionCount,
    int? clickCount,
    int? priority,
  }) {
    return AdCampaign(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      mediaType: mediaType ?? this.mediaType,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      clickUrl: clickUrl ?? this.clickUrl,
      placement: placement ?? this.placement,
      isActive: isActive ?? this.isActive,
      startsAt: clearStartsAt ? null : (startsAt ?? this.startsAt),
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      displaySeconds: displaySeconds ?? this.displaySeconds,
      maxTotalImpressions: clearMaxTotal
          ? null
          : (maxTotalImpressions ?? this.maxTotalImpressions),
      maxPerUser: maxPerUser ?? this.maxPerUser,
      maxPerUserPerDay: maxPerUserPerDay ?? this.maxPerUserPerDay,
      impressionCount: impressionCount ?? this.impressionCount,
      clickCount: clickCount ?? this.clickCount,
      priority: priority ?? this.priority,
    );
  }
}
