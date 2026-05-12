/// Event kinds emitted by [LlmChatService.sendMessage].
enum LlmChatEventType { output, thinking, tool }

/// Stream event emitted by the backing LLM service.
class LlmChatEvent {
  /// Creates an [LlmChatEvent].
  const LlmChatEvent({
    required this.type,
    required this.text,
  });

  /// Creates an assistant output event.
  const LlmChatEvent.output(String text)
    : this(type: LlmChatEventType.output, text: text);

  /// Creates a thinking event.
  const LlmChatEvent.thinking(String text)
    : this(type: LlmChatEventType.thinking, text: text);

  /// Creates a tool-activity event.
  const LlmChatEvent.tool(String text)
    : this(type: LlmChatEventType.tool, text: text);

  /// Event category.
  final LlmChatEventType type;

  /// Event text payload.
  final String text;
}

/// Headless chat service that streams events from a backing LLM.
///
/// The bloc layer talks to this interface, not to `dartantic_ai` directly.
/// Tests fake this interface; the production implementation is
/// [DartanticChatService](dartantic_chat_service.dart).
abstract class LlmChatService {
  /// Sends [text] to the model as the next turn of the conversation and
  /// returns a stream of output/thinking/tool events. The stream completes when
  /// the model
  /// finishes; it errors if the model or transport fails.
  Stream<LlmChatEvent> sendMessage(String text);

  /// Discards in-memory history so the next [sendMessage] starts a fresh
  /// conversation.
  void reset();

  /// Releases resources. Called by the owning bloc when it is closed.
  Future<void> close();
}
