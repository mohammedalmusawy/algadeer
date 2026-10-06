import 'ad_campaign.dart';

/// قواعد أهلية الحملة — نقية وقابلة للاختبار بلا شبكة.
class AdsEligibility {
  AdsEligibility._();

  /// نافذة الحملة (starts_at / ends_at) مقارنةً بـ UTC.
  /// بلا نهاية (`endsAt == null`) تبقى مؤهلة بعد البداية.
  static bool isWithinSchedule({
    required DateTime nowUtc,
    DateTime? startsAt,
    DateTime? endsAt,
  }) {
    final now = nowUtc.toUtc();
    if (startsAt != null && now.isBefore(startsAt.toUtc())) return false;
    if (endsAt != null && now.isAfter(endsAt.toUtc())) return false;
    return true;
  }

  static bool hasRenderableMedia(AdCampaign campaign) {
    return campaign.hasImage || (campaign.isVideo && campaign.hasVideo);
  }

  /// حملات جاهزة للعرض في موضع معيّن، مرتّبة بالأولوية تنازليًا.
  /// لا يطبّق حدود الجهاز المحلية (AdsFrequencyStore).
  static List<AdCampaign> catalogEligible({
    required List<AdCampaign> campaigns,
    required String placement,
    required DateTime nowUtc,
  }) {
    final place = placement.trim().isEmpty ? 'home' : placement.trim();
    final filtered = campaigns.where((c) {
      if (!c.isActive) return false;
      if (c.placement.trim() != place) return false;
      if (!isWithinSchedule(
        nowUtc: nowUtc,
        startsAt: c.startsAt,
        endsAt: c.endsAt,
      )) {
        return false;
      }
      if (c.hasReachedGlobalCap) return false;
      if (!hasRenderableMedia(c)) return false;
      return true;
    }).toList();
    filtered.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      return b.id.compareTo(a.id);
    });
    return filtered;
  }
}
