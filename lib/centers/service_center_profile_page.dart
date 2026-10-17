import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../doctors/doctor_card_gate.dart';
import '../doctors/doctor_card_tap.dart';
import '../models/entity_social_links.dart';
import '../utils/contact_launch.dart';
import '../widgets/clinic_app_bar.dart';
import '../widgets/entity_contact_actions.dart';
import '../widgets/entity_optional_logo.dart';
import 'service_center_style.dart';
import 'service_center_models.dart';
import 'service_center_owner_editor_page.dart';
import '../widgets/owner_access_link.dart';
import '../utils/ghadeer_card_link.dart';
import '../widgets/ghadeer_net_image.dart';

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
        builder: (_) => ServiceCenterOwnerEditorPage(
          center: center,
          session: session,
        ),
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
    final accent = center.kind.accent;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FA),
        appBar: ClinicAppBar(
          title: Text(center.kind.shortLabel),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF123B42),
          actions: [
            IconButton(
              tooltip: 'مشاركة',
              onPressed: _share,
              icon: const Icon(Icons.ios_share_rounded),
            ),
            OwnerAccess.faint(onTap: () => _openOwner(context)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _Hero(
              center: center,
              accent: accent,
              onOwnerTap: () => _openOwner(context),
            ),
            const SizedBox(height: 14),
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
                  : () => launchClinicWhatsApp(center.whatsapp),
              showLocation: center.locationText.isNotEmpty,
              onLocation: center.locationText.isEmpty
                  ? null
                  : () => launchClinicMap(center.locationText),
            ),
            const SizedBox(height: 14),
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
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.center,
    required this.accent,
    required this.onOwnerTap,
  });

  final ServiceCenter center;
  final Color accent;
  final VoidCallback onOwnerTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 400;
        final height = narrow ? 230.0 : 260.0;
        final image = center.displayImage;
        return SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Row(
                children: [
                  Expanded(
                    flex: 11,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const GhadeerBrandHeaderRow(),
                          const Spacer(),
                          if (center.logoUrl.trim().isNotEmpty) ...[
                            EntityOptionalLogo(url: center.logoUrl),
                            const SizedBox(height: 6),
                          ],
                          DoctorCardTripleTap(
                            tapCount: 5,
                            onTripleTap: onOwnerTap,
                            child: Text(
                              center.name,
                              key: const Key('service_center_name'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF123B42),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            center.kind.sectionTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    key: const Key('service_center_image'),
                    flex: 9,
                    child: image.startsWith('http')
                        ? GhadeerNetImage(
                            image,
                            fit: BoxFit.cover,
                            height: height,
                            cacheWidth: 1200,
                            errorBuilder: (_, _, _) => _placeholder(accent),
                          )
                        : _placeholder(accent),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder(Color accent) {
    return ColoredBox(
      color: const Color(0xFFE8F4FC),
      child: Center(
        child: Icon(
          center.kind.icon,
          size: 56,
          color: accent,
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF123B42),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
