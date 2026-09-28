import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home/ghadeer_home_colors.dart';
import '../voice/entity_profile_speech.dart';
import '../voice/voice_response_controller.dart';
import '../widgets/entity_contact_actions.dart';
import '../widgets/entity_speak_button.dart';
import 'physio_models.dart';

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
    final uri = Uri(scheme: 'tel', path: _v.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final digits = _v.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _maps() async {
    final q = Uri.encodeComponent(_v.address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: '${_v.name}\n${_v.address}\nهاتف: ${_v.phone}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openColor =
        _v.isOpenNow ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FBF7),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    GhadeerBackButton(
                      onPressed: () => Navigator.pop(context),
                      color: GhadeerHomeColors.physioAccent,
                    ),
                    const Expanded(
                      child: Text(
                        'تفاصيل المركز',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: _share,
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _v.imageUrl.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFE8F8F0),
                          child: Icon(
                            Icons.accessibility_new_rounded,
                            size: 56,
                            color: GhadeerHomeColors.physioAccent,
                          ),
                        )
                      : Image.network(
                          _v.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFE8F8F0),
                            child: Icon(
                              Icons.accessibility_new_rounded,
                              size: 56,
                              color: GhadeerHomeColors.physioAccent,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _v.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: GhadeerHomeColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _voice,
                    builder: (context, _) {
                      return EntitySpeakButton(
                        speaking: _voice.isSpeaking,
                        label: 'اسمع النبذة',
                        enabled: _speechText.isNotEmpty,
                        onTap: () => unawaited(_toggleSpeech()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _v.slogan,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GhadeerHomeColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    _v.isOpenNow ? 'مفتوح الآن' : 'مغلق الآن',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: openColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'من ${_v.openFrom} إلى ${_v.openTo}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: GhadeerHomeColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _v.address,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              if (_v.description.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _v.description,
                  style: const TextStyle(
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF53636D),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _v.services)
                    Chip(
                      label: Text(
                        c,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      backgroundColor: const Color(0xFFE8F8F0),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              EntityContactActionsRow(
                phone: _v.phone,
                whatsapp: _v.whatsapp,
                social: _v.social,
                socialTitle: 'مواقع تواصل ${_v.name}',
                onCall: _call,
                onWhatsapp: _whatsapp,
                onLocation: _maps,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
