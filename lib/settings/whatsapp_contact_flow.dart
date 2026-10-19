import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../companion/personal_companion_profile_service.dart';
import '../theme/ghadeer_tokens.dart';
import '../utils/contact_launch.dart';
import '../voice/speech_recognition_service.dart';
import '../voice/startup_greeting.dart';
import 'whatsapp_message_settings.dart';
import 'whatsapp_templates.dart';

/// فتح واتساب أي قسم برسالة الإدارة الجاهزة (حجز أو استفسار) + اسم المراجع.
///
/// أول مرة وما عنده اسم محفوظ: نسأله «اذكر اسمك الثلاثي» (كتابة أو مايك)
/// مع «تخطي». نسأل مرة وحدة بس، والاسم ينحفظ بنفس ملفه الشخصي.
abstract final class WhatsAppContactFlow {
  static Future<void> open(
    BuildContext context, {
    required String whatsapp,
    required WhatsAppSection section,
    required String providerTitle,
    PersonalCompanionProfileService? profileService,
  }) async {
    if (whatsapp.trim().isEmpty) return;
    final profiles = profileService ?? PersonalCompanionProfileService();
    await WhatsAppNamePrompt.maybeAsk(context, profileService: profiles);
    final message = await WhatsAppMessageSettingsService().buildPrefill(
      providerTitle: providerTitle,
      providerIsDoctor: section.providerIsDoctor,
      profileService: profiles,
      section: section,
    );
    await launchClinicWhatsApp(whatsapp, message: message);
  }
}

/// سؤال الاسم الثلاثي قبل أول رسالة واتساب.
abstract final class WhatsAppNamePrompt {
  static const String askedKey = 'whatsapp_name_prompt_asked_v1';

  /// يُستبدل بالاختبارات.
  static SpeechRecognitionService Function() speechFactory =
      DeviceSpeechRecognitionService.new;

  /// يسأل إذا ما أكو اسم وما سألناه قبل. يرجع الاسم المحفوظ (أو null).
  static Future<String?> maybeAsk(
    BuildContext context, {
    PersonalCompanionProfileService? profileService,
  }) async {
    final profiles = profileService ?? PersonalCompanionProfileService();
    String? existing;
    try {
      existing = sanitizeGreetingName(
        await profiles.preferredNameForPersonalization(),
      );
    } catch (_) {
      existing = null;
    }
    if (existing != null) return existing;

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(askedKey) ?? false) return null;
    } catch (_) {
      return null;
    }
    if (!context.mounted) return null;

    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NameSheet(),
    );
    try {
      await prefs.setBool(askedKey, true);
    } catch (_) {}

    final clean = sanitizeGreetingName(name);
    if (clean == null) return null;
    try {
      await profiles.savePreferredName(clean);
    } catch (_) {}
    return clean;
  }
}

class _NameSheet extends StatefulWidget {
  const _NameSheet();

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  final _controller = TextEditingController();
  SpeechRecognitionService? _stt;
  bool _listening = false;
  String? _hint;

  @override
  void dispose() {
    final stt = _stt;
    if (stt != null) unawaited(stt.cancel());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt?.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() {
      _hint = null;
      _listening = true;
    });
    try {
      final stt = _stt ??= WhatsAppNamePrompt.speechFactory();
      final ok = await stt.initialize();
      if (!ok) throw StateError('mic');
      await stt.startListening(
        onResult: (text, {bool isFinal = false}) {
          if (!mounted) return;
          _controller.text = text.trim();
          if (isFinal) setState(() => _listening = false);
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _hint = 'المايك ما اشتغل، اكتب اسمك بالحقل.';
          });
        },
        onSessionEnd: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _hint = 'المايك ما اشتغل، اكتب اسمك بالحقل.';
      });
    }
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _hint = 'اكتب اسمك أو دوس «تخطي».');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('اذكر اسمك الثلاثي', style: GhadeerTokens.title),
            const SizedBox(height: 6),
            const Text(
              'حتى يعرفك الطبيب أو المكان من أول رسالة. ينحفظ بجهازك بس، '
              'وتكدر تغيّره من الإعدادات.',
              style: GhadeerTokens.caption,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('whatsapp_name_field'),
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      hintText: 'مثال: محمد علي حسين',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: _listening ? 'وقف المايك' : 'كول اسمك بالمايك',
                  child: Material(
                    color: _listening
                        ? GhadeerTokens.danger
                        : GhadeerTokens.tealWash,
                    borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
                    child: InkWell(
                      key: const Key('whatsapp_name_mic'),
                      borderRadius: BorderRadius.circular(
                        GhadeerTokens.radiusMd,
                      ),
                      onTap: _toggleMic,
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(
                          _listening ? Icons.stop_rounded : Icons.mic_rounded,
                          color: _listening
                              ? Colors.white
                              : GhadeerTokens.tealDeep,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_hint != null) ...[
              const SizedBox(height: 8),
              Text(
                _hint!,
                style: GhadeerTokens.caption.copyWith(
                  color: GhadeerTokens.danger,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('whatsapp_name_save'),
              onPressed: _save,
              child: const Text('حفظ ومتابعة'),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const Key('whatsapp_name_skip'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('تخطي'),
            ),
          ],
        ),
      ),
    );
  }
}
