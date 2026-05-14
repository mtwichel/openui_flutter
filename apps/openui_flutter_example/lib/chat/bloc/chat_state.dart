part of 'chat_bloc.dart';

/// Lifecycle state of the live-chat surface.
@MappableEnum()
enum ChatStatus {
  /// No turn in flight. Send button enabled.
  idle,

  /// A model response is currently streaming.
  streaming,

  /// The most recent turn errored. Send is enabled; an error banner is
  /// visible until the next [MessageSubmitted].
  error,
}

/// Which collapsible debug strip in the live renderer pane.
@MappableEnum()
enum LlmDebugPanel {
  /// Generated OpenUI source from the latest assistant turn.
  generatedOpenUiCode,

  /// Latest OpenUI store snapshot.
  storeInspector,

  /// Host-visible OpenUI action log.
  actionLog,
}

/// Immutable state of [ChatBloc].
///
/// When [status] is [ChatStatus.streaming], [messages] contains the
/// in-progress assistant turn plus optional thinking/tool activity entries.
@MappableClass()
class ChatState with ChatStateMappable {
  /// Creates a [ChatState].
  const ChatState({
    this.status = ChatStatus.idle,
    this.messages = const [],
    this.error,
    this.renderStoreSnapshot = const <String, Object?>{},
    this.actionLog = const <OpenUiActionLogEntry>[],
    this.isGeneratedOpenUiCodePanelExpanded = false,
    this.isStoreInspectorPanelExpanded = false,
    this.isActionLogPanelExpanded = false,
    this.geminiConfigured = true,
    this.sessionKeyActive = false,
  });

  /// Current lifecycle status.
  final ChatStatus status;

  /// Transcript, oldest first. During streaming this may include assistant
  /// deltas plus thinking/tool activity messages.
  final List<UiMessage> messages;

  /// Last error message, or null. Cleared on the next successful submit.
  final String? error;

  /// Latest OpenUI [Store] snapshot from the live [Renderer], for the store
  /// inspector. Keys use the leading `$` form (e.g. `'\$count'`).
  final Map<String, Object?> renderStoreSnapshot;

  /// Host-visible OpenUI actions (and continue-conversation), oldest first.
  final List<OpenUiActionLogEntry> actionLog;

  /// Whether the "Generated OpenUI code" debug panel body is visible.
  final bool isGeneratedOpenUiCodePanelExpanded;

  /// Whether the "Store inspector" debug panel body is visible.
  final bool isStoreInspectorPanelExpanded;

  /// Whether the "Action log" debug panel body is visible.
  final bool isActionLogPanelExpanded;

  /// Whether a Gemini API key is available (dart-define and/or session key).
  ///
  /// When false, the chat surface shows the in-app Gemini key gate instead of
  /// the transcript and renderer.
  final bool geminiConfigured;

  /// True when the active key came from this session (not only dart-define).
  ///
  /// Used to offer "change API key" without affecting compile-time defines.
  final bool sessionKeyActive;
}

/// Sender role of a [UiMessage].
@MappableEnum()
enum UiMessageRole {
  /// Submitted by the human via the input field.
  user,

  /// Streamed back from the LLM. Carries OpenUI Lang source.
  assistant,

  /// Incremental model reasoning text.
  thinking,

  /// Tool-usage activity from provider metadata.
  tool,
}

/// A single entry in the live chat transcript.
///
/// Distinct from `dartantic_ai`'s `ChatMessage`, which is the on-the-wire
/// representation owned by [DartanticChatService](dartantic_chat_service.dart).
/// [UiMessage] is the UI projection consumed by `ChatBloc` and rendered by
/// `ChatView`.
@MappableClass()
class UiMessage with UiMessageMappable {
  /// Creates a [UiMessage].
  const UiMessage({
    required this.id,
    required this.role,
    required this.text,
  });

  /// Stable identifier for the message. Used as a widget key in the
  /// transcript so streaming chunk updates don't replace the whole tile.
  final String id;

  /// Sender of the message.
  final UiMessageRole role;

  /// Plain text for user messages; OpenUI Lang source for assistant
  /// messages. Empty for an in-progress assistant turn before the first
  /// chunk arrives.
  final String text;
}

/// One row in the Live chat OpenUI action log (backed by
/// [ChatState.actionLog]).
///
/// Built from [ActionEvent] for host-routed steps, or from
/// continue-conversation callbacks which do not surface through
/// [ActionEvent].
@MappableClass()
class OpenUiActionLogEntry with OpenUiActionLogEntryMappable {
  /// Creates an [OpenUiActionLogEntry].
  const OpenUiActionLogEntry({
    required this.loggedAt,
    required this.type,
    this.humanFriendlyMessage,
    this.params = const <String, Object?>{},
  });

  /// Wraps a renderer [ActionEvent] (already host-visible).
  factory OpenUiActionLogEntry.fromActionEvent(
    ActionEvent event, {
    required DateTime loggedAt,
  }) {
    return OpenUiActionLogEntry(
      loggedAt: loggedAt,
      type: event.type,
      humanFriendlyMessage: event.humanFriendlyMessage,
      params: Map<String, Object?>.from(event.params),
    );
  }

  /// Continue-conversation path (implicit button / `@ToAssistant`); not sent to
  /// [Renderer.onAction].
  factory OpenUiActionLogEntry.continueConversation(
    String message, {
    required DateTime loggedAt,
  }) {
    return OpenUiActionLogEntry(
      loggedAt: loggedAt,
      type: BuiltinActionType.continueConversation,
      humanFriendlyMessage: message,
    );
  }

  /// Wall-clock time the host observed the action.
  final DateTime loggedAt;

  /// [ActionEvent.type] or [BuiltinActionType.continueConversation].
  final String type;

  /// Optional user-facing label or message.
  final String? humanFriendlyMessage;

  /// [ActionEvent.params] when applicable.
  final Map<String, Object?> params;
}
