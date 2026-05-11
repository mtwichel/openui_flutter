/// Headless chat service that streams plain text from a backing LLM.
///
/// The bloc layer talks to this interface, not to `dartantic_ai` directly.
/// Tests fake this interface; the production implementation is
/// [DartanticChatService](dartantic_chat_service.dart).
abstract class LlmChatService {
  /// Sends [text] to the model as the next turn of the conversation and
  /// returns a stream of text deltas. The stream completes when the model
  /// finishes; it errors if the model or transport fails.
  Stream<String> sendMessage(String text);

  /// Discards in-memory history so the next [sendMessage] starts a fresh
  /// conversation.
  void reset();

  /// Releases resources. Called by the owning bloc when it is closed.
  Future<void> close();
}
