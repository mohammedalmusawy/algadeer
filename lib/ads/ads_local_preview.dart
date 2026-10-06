import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import 'ad_campaign.dart';
import 'ads_catalog_refresh.dart';
import 'ads_eligibility.dart';

/// معاينة محلية فقط عبر `--dart-define=ADS_LOCAL_PREVIEW=true`.
/// لا تقرأ ولا تكتب `ad_campaigns` في Supabase.
class AdsLocalPreview {
  AdsLocalPreview._();

  static const bool enabled = bool.fromEnvironment(
    'ADS_LOCAL_PREVIEW',
    defaultValue: false,
  );

  static const String campaignId = 'local-preview-home';

  static AdCampaign? _override;

  static AdCampaign get baseCampaign => AdCampaign(
        id: campaignId,
        title: 'إعلان تجريبي محلي',
        body: 'معاينة فقط — بلا حفظ في الإنتاج',
        imageUrl: GhadeerBranding.officialLogoAsset,
        clickUrl: 'https://example.com/',
        placement: 'home',
        isActive: true,
        displaySeconds: 0,
        priority: 100,
        maxPerUser: 0,
        maxPerUserPerDay: 0,
      );

  static AdCampaign get campaign => _override ?? baseCampaign;

  static bool get isLocalId => true;

  static bool isLocalCampaignId(String? id) =>
      (id ?? '').trim() == campaignId;

  static AdCampaign? eligibleFor(String placement) {
    if (!enabled) return null;
    final list = AdsEligibility.catalogEligible(
      campaigns: [campaign],
      placement: placement,
      nowUtc: DateTime.now().toUtc(),
    );
    return list.isEmpty ? null : list.first;
  }

  static void deactivate() {
    _override = campaign.copyWith(isActive: false);
    AdsCatalogRefresh.bump();
  }

  static void expireCampaign() {
    _override = campaign.copyWith(
      endsAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );
    AdsCatalogRefresh.bump();
  }

  /// مدة عرض الشريحة قصيرة — تختفي من الواجهة بعد ثوانٍ دون لمس الإنتاج.
  static void shortSlideDuration({int seconds = 2}) {
    _override = campaign.copyWith(
      isActive: true,
      clearEndsAt: true,
      displaySeconds: seconds < 1 ? 2 : seconds,
    );
    AdsCatalogRefresh.bump();
  }

  static void resetEligible() {
    _override = null;
    AdsCatalogRefresh.bump();
  }
}

/// شريط تحكم للمعاينة — يبقى ظاهرًا حتى بعد إخفاء الإعلان.
class AdsLocalPreviewBar extends StatelessWidget {
  const AdsLocalPreviewBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdsLocalPreview.enabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'معاينة إعلان محلي (بلا Supabase)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  color: Color(0xFF7A4E00),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip('إعادة مؤهّل', AdsLocalPreview.resetEligible),
                  _chip('إيقاف', AdsLocalPreview.deactivate),
                  _chip('إنهاء الحملة', AdsLocalPreview.expireCampaign),
                  _chip('شريحة 2ث', AdsLocalPreview.shortSlideDuration),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }
}
