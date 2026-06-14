import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:slyce/core/constants/ai_endpoints.dart';
import 'package:slyce/features/ai_chat/models/chat_message_model.dart';

/// Repository for the Slyce AI chat API.
///
/// Uses its own Dio instance (separate base URL from the main API).
class AiChatRepository {
  late final Dio _dio;

  AiChatRepository() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        // AI responses can take a few seconds — allow extra receive time.
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  /// Send [message] to the AI and return its response.
  ///
  /// Pass [sessionId] to continue an existing conversation;
  /// omit it (or pass null) to start a new session.
  Future<ChatApiResponse> sendMessage({
    required String message,
    String? sessionId,
    String? userId,
    Map<String, dynamic>? profile,
  }) async {
    try {
      final body = <String, dynamic>{'message': message};
      if (sessionId != null && sessionId.isNotEmpty) {
        body['session_id'] = sessionId;
      }
      // Identify the customer so the AI can personalise answers
      // (e.g. "what should I eat today?").
      if (userId != null && userId.isNotEmpty) {
        body['user_id'] = userId;
      }
      // Attach the user's nutrition profile (weight/height/goal/diet/etc.) so
      // the AI can tailor meal advice, matching the /recommend payload.
      if (profile != null && profile.isNotEmpty) {
        body['profile'] = profile;
      }
      final response = await _dio.post(AiEndpoints.chat, data: body);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ChatApiResponse.fromJson(data);
      }
      throw Exception('Unexpected response format from Slyce AI');
    } on DioException catch (e) {
      final msg = e.response?.data?.toString();
      throw Exception(
          msg != null && msg.isNotEmpty ? msg : 'Could not reach Slyce AI.');
    }
  }

  /// Get the full conversation history for [sessionId].
  Future<ChatApiResponse?> getHistory(String sessionId) async {
    try {
      final response =
          await _dio.get(AiEndpoints.chatHistory(sessionId));
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ChatApiResponse.fromJson(data);
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  /// Delete the conversation history for [sessionId].
  Future<void> deleteHistory(String sessionId) async {
    try {
      await _dio.delete(AiEndpoints.chatHistory(sessionId));
    } on DioException catch (_) {
      // Silently ignore — clearing history is best-effort.
    }
  }
}
