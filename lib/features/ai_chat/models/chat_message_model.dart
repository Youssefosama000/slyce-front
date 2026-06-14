/// Message roles in the AI conversation.
enum ChatRole { user, assistant }

/// A single chat message (user or AI).
class ChatMessage {
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.user(String content) => ChatMessage(
        role: ChatRole.user,
        content: content,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.assistant(String content) => ChatMessage(
        role: ChatRole.assistant,
        content: content,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] ?? json['sender'] ?? '').toString();
    final role = roleStr == 'user' ? ChatRole.user : ChatRole.assistant;
    final content = (json['content'] ??
            json['message'] ??
            json['text'] ??
            '')
        .toString();
    return ChatMessage(
      role: role,
      content: content,
      timestamp: DateTime.now(),
    );
  }
}

/// Parsed response from POST /chat.
class ChatApiResponse {
  final String sessionId;
  final List<ChatMessage> messages;

  const ChatApiResponse({
    required this.sessionId,
    required this.messages,
  });

  factory ChatApiResponse.fromJson(Map<String, dynamic> json) {
    // Support both response shapes:
    //   Shape A (single reply): {"reply": "...", "session_id": "..."}
    //     (the reply may also arrive as response/answer/message/text/output)
    //   Shape B (history):      {"session_id": "...", "messages": [...], "count": 0}
    List<ChatMessage> msgs;

    final rawMsgs = json['messages'];
    if (rawMsgs is List && rawMsgs.isNotEmpty) {
      // Shape B — a full conversation (e.g. GET /chat/history).
      msgs = rawMsgs
          .whereType<Map>()
          .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } else {
      // Shape A — a single assistant reply. Accept the common key names so a
      // valid answer is never dropped just because the backend renamed it.
      final reply = (json['reply'] ??
              json['response'] ??
              json['answer'] ??
              json['message'] ??
              json['text'] ??
              json['output'] ??
              '')
          .toString();
      msgs = reply.isNotEmpty
          ? [ChatMessage.assistant(reply)]
          : <ChatMessage>[];
    }

    final sid = json['session_id'] ?? json['sessionId'];
    return ChatApiResponse(
      sessionId: sid != null ? sid.toString() : '',
      messages: msgs,
    );
  }

  /// The last assistant reply, or null when the server returned none.
  ChatMessage? get lastAssistantMessage {
    for (final m in messages.reversed) {
      if (m.role == ChatRole.assistant) return m;
    }
    return null;
  }
}
