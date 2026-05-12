import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:openui_flutter_example/src/llm_chat/llm_chat_service.dart';

/// dartantic provider name registered by `main.dart` and consumed by
/// the default agent string below. Sharing the constant keeps the
/// registration and consumption in lockstep — change one and you change
/// both.
const String kGeminiProvider = 'google';

/// Default agent string used by the production service.
const String _kDefaultAgent = '$kGeminiProvider:gemini-flash-latest';

/// Live-LLM implementation of [LlmChatService] backed by a dartantic
/// [Chat] against the Gemini Developer API. The `google` provider
/// factory must be registered in `main.dart`
/// before instantiation.
class DartanticChatService implements LlmChatService {
  /// Creates a [DartanticChatService].
  ///
  /// [agentString] is the dartantic agent identifier; defaults to
  /// `google:gemini-flash-latest`.
  /// [systemPrompt] is the system prompt injected at the start of every
  /// chat session.
  DartanticChatService({
    required String systemPrompt,
    String agentString = _kDefaultAgent,
  }) : _agentString = agentString,
       _systemPrompt = systemPrompt,
       _chat = _makeChat(agentString, systemPrompt);

  final String _agentString;
  final String _systemPrompt;
  Chat _chat;

  static Chat _makeChat(String agentString, String systemPrompt) => Chat(
    Agent(agentString),
    history: [ChatMessage.system(systemPrompt)],
  );

  @override
  Stream<String> sendMessage(String text) async* {
    await for (final chunk in _chat.sendStream(text)) {
      yield chunk.output;
    }
  }

  @override
  void reset() {
    _chat = _makeChat(_agentString, _systemPrompt);
  }

  @override
  Future<void> close() async {
    // dartantic's Chat does not expose an explicit close hook today.
    // Dropping the reference is sufficient for GC.
  }
}
