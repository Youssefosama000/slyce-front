/// Endpoint constants for the Slyce AI chat service.
///
/// ⚠ IMPORTANT: replace [baseUrl] with the actual base URL of your
/// Slyce AI FastAPI deployment (the one that serves /openapi.json).
class AiEndpoints {
  AiEndpoints._();

  // TODO: set your Slyce AI service URL here, e.g.:
  //   'https://slyce-ai.azurewebsites.net'
  static const String baseUrl =
      'https://slyce-ai-f6fjcvb5ekdhbxek.israelcentral-01.azurewebsites.net';

  /// POST /chat  →  send a message, get AI reply + session_id
  static const String chat = '/chat';

  /// POST /recommend  →  personalised meal recommendations for a user profile
  static const String recommend = '/recommend';

  /// GET  /chat/history/{session_id}
  /// DELETE /chat/history/{session_id}
  static String chatHistory(String sessionId) =>
      '/chat/history/$sessionId';
}
