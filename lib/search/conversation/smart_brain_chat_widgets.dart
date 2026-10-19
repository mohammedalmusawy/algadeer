import 'package:flutter/material.dart';

import '../../branding/ghadeer_brand_mark.dart';
import '../../theme/ghadeer_tokens.dart';
import '../smart_search_models.dart';
import '../smart_search_result_cards.dart';
import 'smart_brain_chat_models.dart';
import 'smart_brain_suggested_actions.dart';

// ألوان «الماي الصافي» — نفس هوية باقي الصفحات.
const Color _kTeal = GhadeerTokens.tealDeep;
const Color _kNavy = GhadeerTokens.ink;

/// اقتراحات بحث سريعة — نفس مسار الإرسال (اختصاص → الأكثر طلباً داخل المجموعة).
const List<String> kSmartBrainSuggestionChips = [
  'أريد طبيب أطفال',
  'أريد طبيب كسور',
  'أريد طبيب أسنان',
  'أبحث عن مختبر',
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: const BoxDecoration(
          color: GhadeerTokens.deepWater,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            height: 1.45,
            fontSize: 15,
            fontWeight: FontWeight.w500,
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
    this.onSuggestedAction,
    this.onSpeak,
    this.isSpeaking = false,
    this.onStopSpeak,
    this.onCancelThinking,
  });

  final SmartBrainChatTurn turn;
  final void Function(SmartSearchResult result) onResultTap;
  final void Function(SmartBrainSuggestedAction action)? onSuggestedAction;
  final VoidCallback? onSpeak;
  final VoidCallback? onStopSpeak;
  final bool isSpeaking;

  /// إلغاء «الغدير يفكر» — يوقف الطلب الجاري.
  final VoidCallback? onCancelThinking;

  @override
  Widget build(BuildContext context) {
    if (turn.isThinking) {
      return SmartBrainThinkingIndicator(onCancel: onCancelThinking);
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
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: urgent
                          ? const Color(0xFFFFF1F2)
                          : GhadeerTokens.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: urgent
                            ? const Color(0xFFFECACA)
                            : GhadeerTokens.line,
                      ),
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
                            color: urgent ? const Color(0xFF9F1239) : _kNavy,
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
                                    icon: const Icon(
                                      Icons.stop_rounded,
                                      size: 18,
                                    ),
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
                  if (turn.suggestedActions.isNotEmpty &&
                      onSuggestedAction != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final action in turn.suggestedActions)
                          ActionChip(
                            key: Key(
                              'smart_brain_suggested_action_${action.id}',
                            ),
                            label: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: Text(
                                action.label,
                                softWrap: true,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            onPressed: () => onSuggestedAction!(action),
                            backgroundColor: GhadeerTokens.surface,
                            side: const BorderSide(color: GhadeerTokens.line),
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _kNavy,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                      ],
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
  const SmartBrainThinkingIndicator({super.key, this.onCancel});

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('smart_brain_thinking'),
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: GhadeerTokens.surface,
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
          border: Border.all(color: GhadeerTokens.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kTeal),
            ),
            const SizedBox(width: 10),
            const Text(
              'الغدير يفكر…',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: GhadeerTokens.inkMuted,
              ),
            ),
            if (onCancel != null) ...[
              const SizedBox(width: 4),
              TextButton(
                key: const Key('smart_brain_thinking_cancel'),
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: _kNavy,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('إيقاف'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SmartBrainSuggestionChips extends StatelessWidget {
  const SmartBrainSuggestionChips({super.key, required this.onSelected});

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
              backgroundColor: GhadeerTokens.tealWash,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: GhadeerTokens.tealDeep,
                fontSize: 13.5,
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
      child: Container(
        decoration: const BoxDecoration(
          color: GhadeerTokens.surface,
          border: Border(top: BorderSide(color: GhadeerTokens.line)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              IconButton.filled(
                key: const Key('smart_brain_mic'),
                tooltip: loading && !micActive
                    ? 'إيقاف الطلب'
                    : (micActive ? 'إيقاف الصوت والإرسال' : 'تحدث'),
                onPressed: voiceBusy ? null : onToggleVoice,
                style: IconButton.styleFrom(
                  backgroundColor: (micActive || loading)
                      ? Colors.red
                      : GhadeerTokens.deepWater,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                icon: Icon(
                  (micActive || loading)
                      ? Icons.stop_rounded
                      : Icons.mic_rounded,
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
                    hintText: micActive ? 'تحدث الآن…' : 'اكتب رسالتك للغدير…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: GhadeerTokens.teal,
                        width: 1.2,
                      ),
                    ),
                    filled: true,
                    fillColor: GhadeerTokens.mist,
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
                  backgroundColor: GhadeerTokens.teal,
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
