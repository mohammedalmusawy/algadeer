import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/ads/ad_campaign.dart';
import 'package:ghadeer_clinic/ads/ads_eligibility.dart';

void main() {
  group('AdsEligibility — جدولة الحملة', () {
    final now = DateTime.utc(2026, 10, 4, 12);

    test('بلا تواريخ = مؤهلة طالما مفعّلة', () {
      expect(
        AdsEligibility.isWithinSchedule(nowUtc: now),
        isTrue,
      );
    });

    test('قبل البداية = غير مؤهلة', () {
      expect(
        AdsEligibility.isWithinSchedule(
          nowUtc: now,
          startsAt: DateTime.utc(2026, 10, 5),
        ),
        isFalse,
      );
    });

    test('بعد النهاية = منتهية تلقائيًا', () {
      expect(
        AdsEligibility.isWithinSchedule(
          nowUtc: now,
          endsAt: DateTime.utc(2026, 10, 4, 11),
        ),
        isFalse,
      );
    });

    test('بلا نهاية تبقى بعد البداية', () {
      expect(
        AdsEligibility.isWithinSchedule(
          nowUtc: now,
          startsAt: DateTime.utc(2026, 10, 1),
        ),
        isTrue,
      );
    });

    test('توقيت بغداد المحفوظ كـ UTC يُقارن صح', () {
      // 15:00 بغداد (+3) = 12:00 UTC
      final baghdadLocalAsUtcStored = DateTime.utc(2026, 10, 4, 12);
      expect(
        AdsEligibility.isWithinSchedule(
          nowUtc: DateTime.utc(2026, 10, 4, 11, 59),
          endsAt: baghdadLocalAsUtcStored,
        ),
        isTrue,
      );
      expect(
        AdsEligibility.isWithinSchedule(
          nowUtc: DateTime.utc(2026, 10, 4, 12, 0, 1),
          endsAt: baghdadLocalAsUtcStored,
        ),
        isFalse,
      );
    });
  });

  group('AdsEligibility — ترتيب وأولوية وهمية', () {
    AdCampaign campaign({
      required String id,
      bool active = true,
      String placement = 'home',
      int priority = 0,
      DateTime? startsAt,
      DateTime? endsAt,
      String imageUrl = 'https://example.com/a.jpg',
      int? maxTotal,
      int impressions = 0,
      int displaySeconds = 0,
    }) {
      return AdCampaign(
        id: id,
        title: 'وهمي $id',
        isActive: active,
        placement: placement,
        priority: priority,
        startsAt: startsAt,
        endsAt: endsAt,
        imageUrl: imageUrl,
        maxTotalImpressions: maxTotal,
        impressionCount: impressions,
        displaySeconds: displaySeconds,
      );
    }

    test('يعطل / موضع خاطئ / بلا صورة / سقف عالمي', () {
      final now = DateTime.utc(2026, 10, 4, 12);
      final list = AdsEligibility.catalogEligible(
        nowUtc: now,
        placement: 'home',
        campaigns: [
          campaign(id: 'off', active: false, priority: 99),
          campaign(id: 'labs', placement: 'labs', priority: 99),
          campaign(id: 'nomedia', imageUrl: '', priority: 50),
          campaign(id: 'capped', maxTotal: 10, impressions: 10, priority: 40),
          campaign(id: 'ok', priority: 1),
        ],
      );
      expect(list.map((c) => c.id), ['ok']);
    });

    test('الأولوية الأعلى تفوز بين نشطين داخل النافذة', () {
      final now = DateTime.utc(2026, 10, 4, 12);
      final list = AdsEligibility.catalogEligible(
        nowUtc: now,
        placement: 'home',
        campaigns: [
          campaign(id: 'low', priority: 1),
          campaign(id: 'high', priority: 10),
          campaign(id: 'mid', priority: 5),
        ],
      );
      expect(list.map((c) => c.id).toList(), ['high', 'mid', 'low']);
    });

    test('displaySeconds لا يؤثر على أهلية الحملة', () {
      final now = DateTime.utc(2026, 10, 4, 12);
      final list = AdsEligibility.catalogEligible(
        nowUtc: now,
        placement: 'home',
        campaigns: [
          campaign(id: 'slide8', displaySeconds: 8, priority: 2),
          campaign(id: 'slide0', displaySeconds: 0, priority: 1),
        ],
      );
      expect(list.length, 2);
      expect(list.first.id, 'slide8');
    });

    test('منتهية لا تدخل الكتالوج حتى لو أولويتها أعلى', () {
      final now = DateTime.utc(2026, 10, 4, 12);
      final list = AdsEligibility.catalogEligible(
        nowUtc: now,
        placement: 'home',
        campaigns: [
          campaign(
            id: 'expired',
            priority: 100,
            endsAt: DateTime.utc(2026, 10, 3),
          ),
          campaign(id: 'live', priority: 1),
        ],
      );
      expect(list.map((c) => c.id), ['live']);
    });
  });
}
