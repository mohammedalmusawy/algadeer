import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/ghadeer_tokens.dart';
import '../voice/entity_profile_speech.dart';
import '../voice/voice_response_controller.dart';
import '../widgets/entity_speak_button.dart';
import 'supply_models.dart';
import '../utils/contact_launch.dart';
import '../utils/ghadeer_card_link.dart';
import '../doctors/doctor_card_gate.dart';
import '../widgets/directory_owner_editor_page.dart';
import '../widgets/owner_access_link.dart';
import 'supplies_store.dart';
import '../widgets/ghadeer_place_profile.dart';
import '../settings/whatsapp_templates.dart';
import '../settings/whatsapp_contact_flow.dart';

/// تفاصيل محل مستلزمات وتجهيزات طبية.
class SupplyProfilePage extends StatefulWidget {
  const SupplyProfilePage({super.key, required this.vendor});

  final SupplyVendor vendor;

  @override
  State<SupplyProfilePage> createState() => _SupplyProfilePageState();
}

class _SupplyProfilePageState extends State<SupplyProfilePage> {
  late SupplyVendor _v;
  final _voice = VoiceResponseController();
  bool _speechBusy = false;

  @override
  void initState() {
    super.initState();
    _v = widget.vendor;
  }

  @override
  void dispose() {
    unawaited(_voice.stop());
    _voice.dispose();
    super.dispose();
  }

  String get _speechText => EntityProfileSpeech.placeProfile(
    name: _v.name,
    kindLabel: 'معرض',
    slogan: _v.slogan,
    description: _v.description,
    address: _v.address,
    openFrom: _v.openFrom,
    openTo: _v.openTo,
    isOpenNow: _v.isOpenNow,
    tags: _v.categories,
  );

  /// قفل صاحب البطاقة (3 نقرات): يعدّل حقوله فقط عبر Edge Function.
  Future<void> _openOwner() async {
    final session = await showEntityOwnerSession(
      context,
      entityType: 'supply',
      entityId: _v.id,
      title: _v.name,
    );
    if (session == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DirectoryOwnerEditorPage(
          session: session,
          card: OwnerCardData(
            id: _v.id,
            name: _v.name,
            contentRevision: _v.contentRevision,
            logoFolder: 'supplies',
            bio: _v.description,
            services: _v.categories,
            servicesLabel: 'الأقسام والمنتجات، سطر لكل وحدة',
            openFrom: _v.openFrom,
            openTo: _v.openTo,
            splitHours: true,
            phone: _v.phone,
            whatsapp: _v.whatsapp,
            address: _v.address,
            supportsMapUrl: false,
            logoUrl: _v.logoUrl,
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await SuppliesStore.instance.reload();
    final fresh = SuppliesStore.instance.byId(_v.id);
    if (fresh != null && mounted) setState(() => _v = fresh);
  }

  Future<void> _toggleSpeech() async {
    if (_voice.isSpeaking || _speechBusy) {
      await _voice.stop();
      _speechBusy = false;
      return;
    }
    final text = _speechText;
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد نبذة صوتية حالياً.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _speechBusy = true;
    try {
      await _voice.speak(text);
    } finally {
      _speechBusy = false;
    }
  }

  Future<void> _call() async {
    final uri = clinicTelUri(_v.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    await WhatsAppContactFlow.open(
      context,
      whatsapp: _v.whatsapp,
      section: WhatsAppSection.supplies,
      providerTitle: _v.name,
    );
  }

  Future<void> _maps() async {
    final q = Uri.encodeComponent(_v.address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _share() async {
    await GhadeerCardLink.share(
      kind: GhadeerCardKind.supply,
      id: _v.id,
      name: _v.name,
      subtitle: [
        'تجهيزات طبية',
        if (_v.address.trim().isNotEmpty) _v.address.trim(),
      ].join(' · '),
    );
  }

  @override
  Widget build(BuildContext context) {
    // نفس هوية الطبيب والمختبر: الصورة يمين، الكتابة يسار، الرجوع أعلى اليمين.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: GhadeerTokens.mist,
        body: GhadeerPlaceProfile(
          imageUrl: _v.imageUrl,
          fallbackIcon: Icons.wheelchair_pickup_rounded,
          name: _v.name,
          slogan: _v.slogan,
          isOpenNow: _v.isOpenNow,
          openFrom: _v.openFrom,
          openTo: _v.openTo,
          address: _v.address,
          description: _v.description,
          tags: _v.categories,
          tagsTitle: 'الأقسام والمنتجات',
          logoUrl: _v.logoUrl,
          phone: _v.phone,
          whatsapp: _v.whatsapp,
          social: _v.social,
          onCall: _call,
          onWhatsapp: _whatsapp,
          onMaps: _maps,
          onShare: _share,
          onBack: () => Navigator.pop(context),
          ownerAccess: OwnerAccess.faint(onTap: _openOwner),
          speakButton: AnimatedBuilder(
            animation: _voice,
            builder: (context, _) => EntitySpeakButton(
              speaking: _voice.isSpeaking,
              label: 'اسمع النبذة',
              enabled: _speechText.isNotEmpty,
              onTap: () => unawaited(_toggleSpeech()),
            ),
          ),
        ),
      ),
    );
  }
}
