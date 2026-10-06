import 'dart:async';

import 'package:flutter/material.dart';

import '../../branding/ghadeer_brand_mark.dart';
import '../../utils/contact_launch.dart';
import '../ad_campaign.dart';
import '../ads_catalog_refresh.dart';
import '../ads_local_preview.dart';
import '../ads_service.dart';

/// فتحة إعلان خفيفة — إن لا توجد حملة مؤهلة لا ترسم شيئًا.
/// تُعاد الجلب عند [AdsCatalogRefresh] (تعديل/إيقاف من الإدارة أو سحب للتحديث).
class HomeAdSlot extends StatefulWidget {
  const HomeAdSlot({super.key, this.placement = 'home'});

  final String placement;

  @override
  State<HomeAdSlot> createState() => _HomeAdSlotState();
}

class _HomeAdSlotState extends State<HomeAdSlot> {
  final _service = AdsService();
  final _freq = AdsFrequencyStore();
  AdCampaign? _campaign;
  bool _loading = true;
  bool _hidden = false;
  Timer? _autoHide;
  String? _impressionCountedId;

  @override
  void initState() {
    super.initState();
    AdsCatalogRefresh.tick.addListener(_onCatalogRefresh);
    _load();
  }

  @override
  void dispose() {
    AdsCatalogRefresh.tick.removeListener(_onCatalogRefresh);
    _autoHide?.cancel();
    super.dispose();
  }

  void _onCatalogRefresh() {
    _load();
  }

  Future<void> _load() async {
    try {
      AdCampaign? campaign;
      final local = AdsLocalPreview.eligibleFor(widget.placement);
      if (local != null) {
        campaign = local;
      } else if (AdsLocalPreview.enabled) {
        campaign = null;
      } else {
        final has = await _service.hasTable();
        if (!has) {
          if (mounted) {
            setState(() {
              _campaign = null;
              _loading = false;
              _hidden = false;
            });
          }
          return;
        }
        campaign = await _service.fetchEligibleForPlacement(widget.placement);
      }
      if (!mounted) return;
      if (campaign == null) {
        _autoHide?.cancel();
        setState(() {
          _campaign = null;
          _loading = false;
          _hidden = false;
          _impressionCountedId = null;
        });
        return;
      }

      final previousId = _campaign?.id;
      final same = previousId == campaign.id;
      final localPreview = AdsLocalPreview.isLocalCampaignId(campaign.id);
      setState(() {
        _campaign = campaign;
        _loading = false;
        // حملة جديدة، أو معاينة محلية بعد إعادة التأهيل، تظهر من جديد.
        if (!same || localPreview) _hidden = false;
      });

      final shouldCount = !localPreview &&
          (!same || _impressionCountedId != campaign.id);
      if (shouldCount) {
        await _freq.markShown(campaign);
        await _service.recordImpression(campaign.id);
        _impressionCountedId = campaign.id;
      } else if (localPreview) {
        _impressionCountedId = campaign.id;
      }

      _autoHide?.cancel();
      _autoHide = null;
      final seconds = campaign.displaySeconds;
      if (seconds > 0) {
        _autoHide = Timer(Duration(seconds: seconds), () {
          if (mounted) setState(() => _hidden = true);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss() async {
    final c = _campaign;
    if (c != null && !AdsLocalPreview.isLocalCampaignId(c.id)) {
      await _freq.markDismissedToday(c);
    }
    if (mounted) setState(() => _hidden = true);
  }

  Future<void> _open() async {
    final c = _campaign;
    if (c == null) return;
    final raw = c.clickUrl.trim().isNotEmpty
        ? c.clickUrl.trim()
        : (c.isVideo ? c.videoUrl.trim() : '');
    if (raw.isEmpty) return;
    if (!AdsLocalPreview.isLocalCampaignId(c.id)) {
      await _service.recordClick(c.id);
    }
    await launchExternalHttpUrl(raw);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _hidden || _campaign == null) {
      return const SizedBox.shrink();
    }
    final c = _campaign!;
    final image = c.imageUrl.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Semantics(
        button: true,
        label: c.title.trim().isEmpty ? 'إعلان' : 'إعلان ${c.title.trim()}',
        child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4EEEE)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 118,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image.isNotEmpty)
                        GhadeerResolvedImage(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFEAF4F3),
                            child: Icon(
                              Icons.campaign_outlined,
                              color: Color(0xFF0FAFA3),
                            ),
                          ),
                        )
                      else
                        const ColoredBox(
                          color: Color(0xFFEAF4F3),
                          child: Icon(
                            Icons.campaign_outlined,
                            color: Color(0xFF0FAFA3),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            c.isVideo ? 'إعلان · فيديو قريبًا' : 'إعلان',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _dismiss,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded, size: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (c.title.trim().isNotEmpty || c.body.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.title.trim().isNotEmpty)
                          Text(
                            c.title.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Color(0xFF123B42),
                            ),
                          ),
                        if (c.body.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            c.body.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: Color(0xFF5B6C70),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
