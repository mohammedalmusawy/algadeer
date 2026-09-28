import 'package:flutter/material.dart';

import 'entity_contact_actions.dart';

/// زر قراءة صوتية موحّد (نفس أسلوب المختبر: اسمع الباقات / النبذة).
class EntitySpeakButton extends StatelessWidget {
  const EntitySpeakButton({
    super.key,
    required this.speaking,
    required this.onTap,
    this.label = 'اسمع النبذة',
    this.enabled = true,
  });

  final bool speaking;
  final VoidCallback? onTap;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canSpeak = enabled && onTap != null;
    return Material(
      color: speaking ? const Color(0xFFE6F8F6) : Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: canSpeak ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(
                color: canSpeak
                    ? kEntityActionTeal.withValues(alpha: 0.35)
                    : const Color(0xFFE8EEF2),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                size: 18,
                color: canSpeak ? kEntityActionTeal : const Color(0xFF8A9A9E),
              ),
              const SizedBox(width: 6),
              Text(
                speaking ? 'إيقاف' : label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: canSpeak
                      ? const Color(0xFF123B42)
                      : const Color(0xFF8A9A9E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
