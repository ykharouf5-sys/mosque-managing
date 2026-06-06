class ActiveConversationTracker {
  static final ActiveConversationTracker _instance = ActiveConversationTracker._internal();
  factory ActiveConversationTracker() => _instance;
  ActiveConversationTracker._internal();

  String? _activeConversationId;

  /// Set the currently active conversation
  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
    if (conversationId != null) {
      print('👁️ Active conversation set: $conversationId');
    } else {
      print('👁️ Active conversation cleared');
    }
  }

  /// Check if a conversation is currently active
  bool isConversationActive(String conversationId) {
    final isActive = _activeConversationId == conversationId;
    if (isActive) {
      print('✅ Conversation $conversationId is ACTIVE (no notification needed)');
    } else {
      print('📬 Conversation $conversationId is NOT active (notification will be shown)');
    }
    return isActive;
  }

  /// Clear the active conversation
  void clearActiveConversation() {
    _activeConversationId = null;
    print('👁️ Active conversation cleared');
  }

  /// Get the current active conversation ID
  String? get activeConversationId => _activeConversationId;
}
