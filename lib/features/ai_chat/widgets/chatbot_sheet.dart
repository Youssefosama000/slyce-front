import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/storage/secure_storage.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/features/ai_chat/models/chat_message_model.dart';
import 'package:slyce/features/ai_chat/repositories/ai_chat_repository.dart';
import 'package:slyce/features/profile/repositories/profile_repository.dart';

/// Full-featured Slyce AI chat bottom sheet.
///
/// Manages its own message list, session state, and API calls.
/// Open it with:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: kBgColor,
///   shape: const RoundedRectangleBorder(
///     borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
///   ),
///   builder: (_) => const ChatbotSheet(),
/// );
/// ```
class ChatbotSheet extends StatefulWidget {
  const ChatbotSheet({super.key});

  @override
  State<ChatbotSheet> createState() => _ChatbotSheetState();
}

class _ChatbotSheetState extends State<ChatbotSheet> {
  final _repo = AiChatRepository();
  final _profileRepo = ProfileRepository();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<ChatMessage> _messages = [
    ChatMessage.assistant(
      "Hi! I'm Slyce AI \u{1F916}\nI can help you find meals that fit "
      'your plan, track your orders and more. Ask me anything!',
    ),
  ];

  // Session ID = the logged-in customer's ID so each user has their own
  // persistent conversation on the backend.
  String? _sessionId;
  // The signed-in customer's id, sent as `user_id` so the AI can personalise
  // answers (e.g. "what should I eat today?"). Kept separate from [_sessionId],
  // which the server may replace with its own session token.
  String? _userId;
  // The customer's nutrition profile, built once and sent with each message so
  // the AI can personalise its advice (same payload shape as /recommend).
  Map<String, dynamic>? _profile;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadSessionId();
  }

  /// Load the customer ID from secure storage, use it as the session ID,
  /// then fetch any existing conversation history from the server.
  Future<void> _loadSessionId() async {
    final id = await SecureStorage.instance.getCustomerId();
    if (id == null || id.isEmpty) return;

    _userId = id;
    setState(() => _sessionId = id);

    // Restore the locally-cached conversation first so it survives closing the
    // sheet — only "New Chat" clears it. The server history below refines it.
    final cached = await _readLocalMessages(id);
    if (cached.isNotEmpty) {
      setState(() {
        _messages
          ..clear()
          ..addAll(cached);
      });
      _scrollToBottom();
    }

    // Build the nutrition profile once (best-effort) so messages can carry it.
    try {
      _profile = await _profileRepo.buildAiProfile();
    } catch (_) {
      // Profile is optional — chat still works without it.
    }

    // Try to restore previous conversation from the server.
    final history = await _repo.getHistory(id);
    if (history != null && history.messages.isNotEmpty) {
      setState(() {
        _messages
          ..clear()
          ..addAll(history.messages);
      });
      await _saveLocalMessages(id);
      _scrollToBottom();
    }
  }

  // ── Local conversation cache ────────────────────────────────────────

  /// Read the locally-cached conversation for [userId]. Empty when there is no
  /// cache, it belongs to a different customer, or it is corrupt.
  Future<List<ChatMessage>> _readLocalMessages(String userId) async {
    try {
      final raw = await SecureStorage.instance.getChatCache();
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      if (decoded['userId'] != userId) return const [];
      final list = decoded['messages'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((m) {
            final roleStr = (m['role'] ?? '').toString();
            final content = (m['content'] ?? '').toString();
            return roleStr == 'user'
                ? ChatMessage.user(content)
                : ChatMessage.assistant(content);
          })
          .where((m) => m.content.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Persist the current conversation for [userId] so it survives closing the
  /// sheet. Best-effort; failures are ignored.
  Future<void> _saveLocalMessages(String userId) async {
    try {
      final payload = {
        'userId': userId,
        'messages': _messages
            .map((m) => {
                  'role': m.role == ChatRole.user ? 'user' : 'assistant',
                  'content': m.content,
                })
            .toList(),
      };
      await SecureStorage.instance.setChatCache(jsonEncode(payload));
    } catch (_) {
      // Best-effort cache.
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── API call ────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    _textCtrl.clear();
    setState(() {
      _messages.add(ChatMessage.user(text));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final response = await _repo.sendMessage(
        message: text,
        sessionId: _sessionId,
        userId: _userId,
        profile: _profile,
      );

      // Persist the session so follow-up messages continue the conversation.
      if (response.sessionId.isNotEmpty) {
        _sessionId = response.sessionId;
      }

      final reply = response.lastAssistantMessage;
      setState(() {
        _messages.add(
          reply ?? ChatMessage.assistant('Sorry, I had trouble answering that. Please try again.'),
        );
        _isSending = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage.assistant(
          'Something went wrong. Please check your connection and try again.',
        ));
        _isSending = false;
      });
    }
    // Persist after each exchange so the conversation survives closing the sheet.
    if (_userId != null && _userId!.isNotEmpty) {
      await _saveLocalMessages(_userId!);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(context),
          const Divider(height: 1, color: kLightGrey),
          Expanded(child: _buildMessageList()),
          if (_isSending) _buildTypingIndicator(),
          _buildInputBar(bottom),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: kLightGrey,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kWhite,
              shape: BoxShape.circle,
              border: Border.all(color: kLightGrey),
            ),
            padding: const EdgeInsets.all(7),
            child: Image.asset(
              'assets/icons/chat_bot_black.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Slyce AI',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kDarkColor,
              ),
            ),
          ),
          // Start a new conversation
          TextButton.icon(
            onPressed: _clearChat,
            icon: const Icon(Icons.add, size: 16, color: kPrimaryGreen),
            label: Text(
              'New Chat',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kPrimaryGreen,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: kPrimaryGreen),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: kGreyColor),
          ),
        ],
      ),
    );
  }

  /// Deletes history on the server (if a session exists) and resets locally.
  Future<void> _clearChat() async {
    if (_sessionId != null && _sessionId!.isNotEmpty) {
      await _repo.deleteHistory(_sessionId!);
      _sessionId = null;
    }
    // Wipe the local cache too so the cleared conversation doesn't come back.
    await SecureStorage.instance.clearChatCache();
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage.assistant(
          "Hi! I'm Slyce AI \u{1F916}\nI can help you find meals that fit "
          'your plan, track your orders and more. Ask me anything!',
        ));
    });
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        return msg.role == ChatRole.user
            ? _userBubble(msg.content)
            : _botBubble(msg.content);
      },
    );
  }

  Widget _botBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: kLightGrey),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
              fontSize: 14, color: kDarkColor, height: 1.4),
        ),
      ),
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: const BoxDecoration(
          color: kPrimaryGreen,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
              fontSize: 14, color: kWhite, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 0, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLightGrey),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0),
            const SizedBox(width: 4),
            _dot(150),
            const SizedBox(width: 4),
            _dot(300),
          ],
        ),
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Opacity(
        opacity: v,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: kGreyColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(double bottomInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: kBgColor,
        border: Border(top: BorderSide(color: kLightGrey)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kLightGrey),
              ),
              child: TextField(
                controller: _textCtrl,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.inter(
                    fontSize: 14, color: kDarkColor),
                decoration: InputDecoration(
                  hintText: 'Ask Slyce AI\u2026',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 14, color: kGreyColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSending ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _isSending ? kGreyColor : kPrimaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: kWhite, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
