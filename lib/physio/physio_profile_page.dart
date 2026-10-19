import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/ghadeer_tokens.dart';
import '../voice/entity_profile_speech.dart';
import '../voice/voice_response_controller.dart';
import '../widgets/entity_speak_button.dart';
import 'physio_models.dart';
import '../utils/contact_launch.dart';
import '../utils/ghadeer_card_link.dart';
import '../doctors/doctor_card_gate.dart';
import '../widgets/directory_owner_editor_page.dart';
import '../widgets/owner_access_link.dart';
import 'physio_store.dart';
import '../widgets/ghadeer_place_profile.dart';
import '../settings/whatsapp_templates.dart';
import '../settings/whatsapp_contact_flow.dart';

/// تفاصيل مركز علاج طبيعي.
class PhysioProfilePage extends StatefulWidget {
  const PhysioProfilePage({super.key, required this.center});

  final PhysioCenter center;

  @override
  State<PhysioProfilePage> createState() => _PhysioProfilePageState();
}

class _PhysioProfilePageState extends State<PhysioProfilePage> {
  late PhysioCenter _v;
  final _voice = VoiceResponseController();
  bool _speechBusy = false;

  @override
  void initState() {
    super.initState();
    _v = widget.center;
  }

  @override
  void dispose() {
    unawaited(_voice.stop());
    _voice.dispose();
    super.dispose();
  }

  String get _speechText => EntityProfileSpeech.placeProfile(
    name: _v.name,
    kindLabel: 'مركز',
    slogan: _v.slogan,
    description: _v.description,
    address: _v.address,
    openFrom: _v.openFrom,
    openTo: _v.openTo,
    isOpenNow: _v.isOpenNow,
    tags: _v.services,
  );

  /// قفل صاحب البطاقة (3 نقرات): يعدّل حقوله فقط عبر Edge Function.
  Future<void> _openOwner() async {
    final session = await showEntityOwnerSession(
      context,
      entityType: 'physio',
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
            logoFolder: 'physio',
            bio: _v.description,
            services: _v.services,
            servicesLabel: 'الخدمات، سطر لكل خدمة',
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
    await PhysioStore.instance.reload();
    final fresh = PhysioStore.instance.byId(_v.id);
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
      section: WhatsAppSection.physio,
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
      kind: GhadeerCardKind.physio,
      id: _v.id,
      name: _v.name,
      subtitle: [
        'علاج طبيعي',
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
          fallbackIcon: Icons.accessibility_new_rounded,
          name: _v.name,
          slogan: _v.slogan,
          isOpenNow: _v.isOpenNow,
          openFrom: _v.openFrom,
          openTo: _v.openTo,
          address: _v.address,
          description: _v.description,
          tags: _v.services,
          tagsTitle: 'الخدمات',
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
