part of 'chat_bloc.dart';

/// Base type for [ChatBloc] events.
sealed class ChatEvent {
  const ChatEvent();
}

/// User pressed send with [text].
@MappableClass()
class MessageSubmitted extends ChatEvent with MessageSubmittedMappable {
  /// Creates a [MessageSubmitted] event.
  const MessageSubmitted(this.text);

  /// The prompt the user entered.
  final String text;
}

/// User pressed clear.
@MappableClass()
class ChatCleared extends ChatEvent with ChatClearedMappable {
  /// Creates a [ChatCleared] event.
  const ChatCleared();
}

/// OpenUI renderer pushed a new store snapshot (after any [Store] write).
@MappableClass()
class RenderStoreSnapshotUpdated extends ChatEvent
    with RenderStoreSnapshotUpdatedMappable {
  /// Creates a [RenderStoreSnapshotUpdated] event.
  const RenderStoreSnapshotUpdated(this.snapshot);

  /// Full post-write store map (same shape as [Renderer.onStateUpdate]).
  final Map<String, Object?> snapshot;
}

/// A host-visible OpenUI action was dispatched (or continue-conversation).
@MappableClass()
class OpenUiHostActionLogged extends ChatEvent
    with OpenUiHostActionLoggedMappable {
  /// Creates an [OpenUiHostActionLogged] event.
  const OpenUiHostActionLogged(this.entry);

  /// Log line to append.
  final OpenUiActionLogEntry entry;
}

/// Clears [ChatState.actionLog] (e.g. when the renderer has no active program).
@MappableClass()
class OpenUiActionLogCleared extends ChatEvent
    with OpenUiActionLogClearedMappable {
  /// Creates an [OpenUiActionLogCleared] event.
  const OpenUiActionLogCleared();
}

/// User submitted a Gemini API key from the in-app gate.
@MappableClass()
class GeminiApiKeySubmitted extends ChatEvent
    with GeminiApiKeySubmittedMappable {
  /// Creates a [GeminiApiKeySubmitted] event.
  const GeminiApiKeySubmitted(this.apiKey);

  /// Raw key text (trimmed in the bloc).
  final String apiKey;
}

/// Clears the in-memory session key and falls back to dart-define if present.
@MappableClass()
class GeminiSessionApiKeyCleared extends ChatEvent
    with GeminiSessionApiKeyClearedMappable {
  /// Creates a [GeminiSessionApiKeyCleared] event.
  const GeminiSessionApiKeyCleared();
}

/// Toggles which Live renderer debug panels are expanded.
@MappableClass()
class LlmDebugPanelExpansionChanged extends ChatEvent
    with LlmDebugPanelExpansionChangedMappable {
  /// Creates a [LlmDebugPanelExpansionChanged] event.
  const LlmDebugPanelExpansionChanged({
    required this.panel,
    required this.expanded,
  });

  /// Which panel changed.
  final LlmDebugPanel panel;

  /// New expanded value for [panel].
  final bool expanded;
}

class _StreamChunkReceived extends ChatEvent {
  const _StreamChunkReceived(this.chunk);
  final LlmChatEvent chunk;
}

class _StreamCompleted extends ChatEvent {
  const _StreamCompleted();
}

class _StreamFailed extends ChatEvent {
  const _StreamFailed(this.error);
  final Object error;
}
