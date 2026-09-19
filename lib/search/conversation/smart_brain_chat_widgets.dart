import 'package:flutter/material.dart';

import '../../branding/ghadeer_brand_mark.dart';
import '../smart_search_models.dart';
import '../smart_search_result_cards.dart';
import 'smart_brain_chat_models.dart';

const Color _kTeal = Color(0xFF0FAFA3);
const Color _kNavy = Color(0xFF123B42);

/// اقتراحات ترحيب — اختصارات لنفس مسار الإرسال فقط.
const List<String> kSmartBrainSuggestionChips = [
  'أريد طبيب',
  'عندي أعراض',
  'أبحث عن مختبر',
  'أريد أشعة',
];

class SmartBrainUserBubble extends StatelessWidget {
  const SmartBrainUserBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        key: const Key('smart_brain_user_bubble'),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 10, left: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF123B42),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            height: 1.45,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class SmartBrainAssistantBubble extends StatelessWidget {
  const SmartBrainAssistantBubble({
    super.key,
    required this.turn,
    required this.onResultTap,
    this.onSpeak,
    this.isSpeaking = false,
    this.onStopSpeak,
  });

  final SmartBrainChatTurn turn;
  final void Function(SmartSearchResult result) onResultTap;
  final VoidCallback? onSpeak;
  final VoidCallback? onStopSpeak;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    if (turn.isThinking) {
      return const SmartBrainThinkingIndicator();
    }

    final urgent = turn.isUrgent;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('smart_brain_assistant_bubble'),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
        ),
        margin: const EdgeInsets.only(bottom: 12, right: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GhadeerBrandMark(size: 34),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: urgent
                          ? const Color(0xFFFFF1F2)
                          : const Color(0xFFE6F8F6),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: urgent
                          ? Border.all(color: const Color(0xFFFECACA))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الغدير',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _kTeal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          turn.text,
                          style: TextStyle(
                            height: 1.5,
                            fontSize: 15,
                            color: urgent
                                ? const Color(0xFF9F1239)
                                : _kNavy,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (onSpeak != null && turn.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: isSpeaking
                                ? TextButton.icon(
                                    onPressed: onStopSpeak,
                                    icon: const Icon(Icons.stop_rounded, size: 18),
                                    label: const Text('إيقاف'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _kNavy,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                : TextButton.icon(
                                    onPressed: onSpeak,
                                    icon: const Icon(
                                      Icons.volume_up_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('استمع'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _kTeal,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (turn.results.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...turn.results.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SmartSearchResultCard(
                          result: item,
                          onTap: () => onResultTap(item),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SmartBrainThinkingIndicator extends StatelessWidget {
  const SmartBrainThinkingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('smart_brain_thinking'),
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F8F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kTeal,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'الغدير يفكر…',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B6C70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SmartBrainSuggestionChips extends StatelessWidget {
  const SmartBrainSuggestionChips({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in kSmartBrainSuggestionChips)
            ActionChip(
              key: Key('smart_brain_suggestion_chip_$label'),
              label: Text(label),
              onPressed: () => onSelected(label),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFB6E5E0)),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _kNavy,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}

class SmartBrainComposerBar extends StatelessWidget {
  const SmartBrainComposerBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onToggleVoice,
    required this.loading,
    required this.voiceBusy,
    required this.listening,
    required this.voiceSessionActive,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onToggleVoice;
  final bool loading;
  final bool voiceBusy;
  final bool listening;
  final bool voiceSessionActive;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final micActive = listening || voiceSessionActive;
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        elevation: 6,
        shadowColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              IconButton.filled(
                key: const Key('smart_brain_mic'),
                tooltip: micActive ? 'إيقاف الصوت والإرسال' : 'تحدث',
                onPressed: voiceBusy
                    ? null
                    : (loading && !voiceSessionActive)
                        ? null
                        : onToggleVoice,
                style: IconButton.styleFrom(
                  backgroundColor:
                      micActive ? Colors.red : const Color(0xFF123B42),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                icon: Icon(
                  micActive ? Icons.stop_rounded : Icons.mic_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('smart_brain_composer_field'),
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: readOnly,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: micActive
                        ? 'تحدث الآن…'
                        : 'اكتب رسالتك للغدير…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF2F7F8),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  // يمنع unfocus الافتراضي لـ TextInputAction.send عند Enter،
                  // فتبقى لوحة المفاتيح جاهزة للرسالة التالية بلا إعادة فتح.
                  onEditingComplete: controller.clearComposing,
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('smart_brain_send'),
                tooltip: 'إرسال',
                onPressed: (loading && !voiceSessionActive) ? null : onSubmit,
                style: IconButton.styleFrom(
                  backgroundColor: _kTeal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
