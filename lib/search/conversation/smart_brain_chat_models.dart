import '../smart_search_models.dart';

/// دور رسالة جلسة المحادثة (عرض فقط — ليست سلطة سياق الدماغ).
enum SmartBrainChatRole {
  user,
  assistant,
}

/// دورة عرض في واجهة المحادثة — جلسة فقط، بلا تخزين دائم.
class SmartBrainChatTurn {
  const SmartBrainChatTurn({
    required this.id,
    required this.role,
    required this.text,
    this.results = const [],
    this.isUrgent = false,
    this.isThinking = false,
    this.isWelcome = false,
  });

  final String id;
  final SmartBrainChatRole role;
  final String text;
  final List<SmartSearchResult> results;
  final bool isUrgent;
  final bool isThinking;
  final bool isWelcome;

  factory SmartBrainChatTurn.user(String text, {required String id}) {
    return SmartBrainChatTurn(
      id: id,
      role: SmartBrainChatRole.user,
      text: text.trim(),
    );
  }

  factory SmartBrainChatTurn.assistant({
    required String id,
    required String text,
    List<SmartSearchResult> results = const [],
    bool isUrgent = false,
    bool isWelcome = false,
  }) {
    return SmartBrainChatTurn(
      id: id,
      role: SmartBrainChatRole.assistant,
      text: text.trim(),
      results: List<SmartSearchResult>.unmodifiable(results),
      isUrgent: isUrgent,
      isWelcome: isWelcome,
    );
  }

  factory SmartBrainChatTurn.thinking({required String id}) {
    return SmartBrainChatTurn(
      id: id,
      role: SmartBrainChatRole.assistant,
      text: 'الغدير يفكر…',
      isThinking: true,
    );
  }

  SmartBrainChatTurn copyWith({
    String? text,
    List<SmartSearchResult>? results,
    bool? isUrgent,
    bool? isThinking,
    bool? isWelcome,
  }) {
    return SmartBrainChatTurn(
      id: id,
      role: role,
      text: text ?? this.text,
      results: results ?? this.results,
      isUrgent: isUrgent ?? this.isUrgent,
      isThinking: isThinking ?? this.isThinking,
      isWelcome: isWelcome ?? this.isWelcome,
    );
  }
}
