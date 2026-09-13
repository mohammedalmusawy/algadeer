import '../doctors/notifications_admin_service.dart';
import 'ad_campaign.dart';

/// إشعار داخلي عند تفعيل حملة إعلانية (صندوق الإشعارات — بدون Push خارجي).
class AdsNotify {
  AdsNotify._();

  static Future<void> notifyCampaignActivated(AdCampaign campaign) async {
    if (!campaign.isActive || campaign.id.isEmpty) return;
    final title = 'إعلان في منصة الغدير';
    final body = campaign.title.trim().isEmpty
        ? 'يوجد إعلان جديد في منصة الغدير.'
        : campaign.title.trim();
    final key =
        'ad_campaign_${campaign.id}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final service = NotificationsAdminService();
      await service.upsert(
        title: title,
        body: body,
        type: NotificationTypes.adCampaign,
        status: NotificationStatus.sent,
        origin: 'auto',
        audience: 'all',
        destinationKind: 'home',
        idempotencyKey: key,
        templateKey: NotificationTypes.adCampaign,
        sendPushSuggested: false,
      );
    } catch (_) {
      // فشل صامت — الحملة تبقى محفوظة حتى لو الإشعار لم يُنشأ
    }
  }
}
