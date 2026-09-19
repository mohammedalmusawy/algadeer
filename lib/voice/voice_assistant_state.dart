/// حالات مساعد الصوت — مصدر واحد بدل أعلام منطقية متضاربة.
enum VoiceAssistantState {
  idle,
  listening,
  processing,
  result,
  speaking,
  waitingForConfirmation,
  error,
}

extension VoiceAssistantStateX on VoiceAssistantState {
  bool get isListeningSession =>
      this == VoiceAssistantState.listening ||
      this == VoiceAssistantState.waitingForConfirmation;

  bool get blocksTypedSearch =>
      this == VoiceAssistantState.listening ||
      this == VoiceAssistantState.processing;

  bool get showsMicActive => this == VoiceAssistantState.listening;
}
