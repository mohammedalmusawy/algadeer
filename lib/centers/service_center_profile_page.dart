import 'package:flutter/material.dart';

import '../doctors/doctor_card_gate.dart';
import '../doctors/doctor_card_tap.dart';
import '../models/entity_social_links.dart';
import '../utils/contact_launch.dart';
import '../widgets/entity_contact_actions.dart';
import '../theme/ghadeer_tokens.dart';
import '../widgets/entity_optional_logo.dart';
import '../widgets/ghadeer_identity_card.dart';
import 'service_center_models.dart';
import 'service_center_style.dart';
import 'service_center_owner_editor_page.dart';
import '../widgets/owner_access_link.dart';
import '../utils/ghadeer_card_link.dart';
import '../widgets/ghadeer_net_image.dart';
import '../settings/whatsapp_templates.dart';
import '../settings/whatsapp_contact_flow.dart';

/// بطاقة المركز بهوية قريبة من بطاقة الطبيب: صورة، اسم، وتفاصيل بلا حجز.
class ServiceCenterProfilePage extends StatelessWidget {
  const ServiceCenterProfilePage({super.key, required this.center});

  final ServiceCenter center;

  Future<void> _openOwner(BuildContext context) async {
    final session = await showEntityOwnerSession(
      context,
      entityType: center.kind.dbValue,
      entityId: center.id,
      title: center.name,
    );
    if (session == null || !context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ServiceCenterOwnerEditorPage(center: center, session: session),
      ),
    );
  }

  Future<void> _share() async {
    await GhadeerCardLink.share(
      kind: GhadeerCardKind.center,
      id: center.id,
      name: center.name,
      subtitle: [
        center.kind.sectionTitle,
        if (center.address.trim().isNotEmpty) center.address.trim(),
      ].join(' · '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = center.displayImage;
    final hasImage = image.startsWith('http');
    // نفس هوية الطبيب والمختبر: الصورة يمين، الكتابة يسار، الرجوع أعلى اليمين.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: GhadeerTokens.mist,
        body: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            GhadeerIdentityCard(
              photo: KeyedSubtree(
                key: const Key('service_center_image'),
                child: hasImage
                    ? GhadeerNetImage(
                        image,
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                        errorBuilder: (_, _, _) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              onPhotoTap: hasImage
                  ? () => showGhadeerPhotoViewer(
                      context,
                      GhadeerNetImage(
                        image,
                        fit: BoxFit.contain,
                        cacheWidth: 1400,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    )
                  : null,
              name: center.name,
              // النوع القصير (بصريات / تمريض منزلي …) — جان عنوان الشريط العلوي.
              subtitle: center.kind.shortLabel,
              logo: center.logoUrl.trim().isNotEmpty
                  ? EntityOptionalLogo(url: center.logoUrl)
                  : null,
              // ٥ ضغطات على الاسم = دخول صاحب المركز (مثل قبل).
              wrapName: (name) => DoctorCardTripleTap(
                tapCount: 5,
                onTripleTap: () => _openOwner(context),
                child: name,
              ),
              onShare: _share,
              onBack: () => Navigator.maybePop(context),
              ownerAccess: OwnerAccess.faint(onTap: () => _openOwner(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EntityContactActionsRow(
                    phone: center.phone,
                    whatsapp: center.whatsapp,
                    social: EntitySocialLinks.empty,
                    socialTitle: center.name,
                    onCall: center.phone.trim().isEmpty
                        ? null
                        : () => launchClinicCall(center.phone),
                    onWhatsapp: center.whatsapp.trim().isEmpty
                        ? null
                        : () => WhatsAppContactFlow.open(
                            context,
                            whatsapp: center.whatsapp,
                            section: WhatsAppSection.fromServiceCenterKind(
                              center.kind,
                            ),
                            providerTitle: center.name,
                          ),
                    showLocation: center.locationText.isNotEmpty,
                    onLocation: center.locationText.isEmpty
                        ? null
                        : () => launchClinicMap(center.locationText),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'نبذة',
                    body: center.bio.trim().isEmpty
                        ? 'لم تُضف نبذة لهذا المركز بعد.'
                        : center.bio.trim(),
                  ),
                  _Section(
                    title: 'الخدمات',
                    body: center.actualServices.isEmpty
                        ? 'لم تُضف خدمات لهذا المركز بعد.'
                        : center.actualServices.join('\n'),
                  ),
                  _Section(
                    title: 'الدوام',
                    body: center.hours.trim().isEmpty
                        ? 'الدوام غير مضاف.'
                        : center.hours.trim(),
                  ),
                  _Section(
                    title: 'العنوان',
                    body: center.address.trim().isEmpty
                        ? 'العنوان غير مضاف.'
                        : center.address.trim(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: GhadeerTokens.tealWash,
      child: Center(
        child: Icon(center.kind.icon, size: 56, color: center.kind.accent),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: GhadeerTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
          side: const BorderSide(color: GhadeerTokens.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GhadeerTokens.heading),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: GhadeerTokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
