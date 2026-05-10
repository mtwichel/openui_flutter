import 'package:meta/meta.dart';

/// One assistant-stream event after adapter normalization.
///
/// Adapters consume a raw transport (SSE, an OpenAI streaming envelope,
/// etc.) and emit a sequence of [AssistantStreamEvent]s. The chat
/// controller threads these through the in-flight `AssistantMessage`,
/// appending each delta to its `response` field.
///
/// The four event shapes correspond to the JS reference's lifecycle:
///
/// - [AssistantTextDelta] — most common; an additional chunk of OpenUI
///   Lang from the LLM.
/// - [AssistantMessageStart] — turn boundary at the head of an
///   assistant message.
/// - [AssistantMessageEnd] — turn boundary at the tail; the controller
///   flips `isStreaming` to `false` and finalizes the message.
/// - [AssistantToolCall] — the LLM is requesting a tool. Reserved; v0.1
///   adapters do not emit these (tool calls round-trip through the
///   renderer's `ToolProvider`).
///
/// Marked `@experimental` per D12.
@experimental
@immutable
sealed class AssistantStreamEvent {
  /// Creates an [AssistantStreamEvent].
  const AssistantStreamEvent();
}

/// One delta of assistant text to append to the in-flight message.
///
/// Marked `@experimental` per D12.
@experimental
final class AssistantTextDelta extends AssistantStreamEvent {
  /// Creates an [AssistantTextDelta].
  const AssistantTextDelta(this.delta);

  /// The text to append to the in-flight `AssistantMessage.response`.
  final String delta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantTextDelta && other.delta == delta;

  @override
  int get hashCode => Object.hash(AssistantTextDelta, delta);
}

/// Turn-start marker. Carries an optional [messageId] if the upstream
/// transport assigns one; otherwise the controller mints a UUID v4.
///
/// Marked `@experimental` per D12.
@experimental
final class AssistantMessageStart extends AssistantStreamEvent {
  /// Creates an [AssistantMessageStart].
  const AssistantMessageStart({this.messageId});

  /// Optional id from the transport.
  final String? messageId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantMessageStart && other.messageId == messageId;

  @override
  int get hashCode => Object.hash(AssistantMessageStart, messageId);
}

/// Turn-end marker. The controller flips `isStreaming` to `false` and
/// finalizes the message.
///
/// Marked `@experimental` per D12.
@experimental
final class AssistantMessageEnd extends AssistantStreamEvent {
  /// Creates an [AssistantMessageEnd].
  const AssistantMessageEnd();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AssistantMessageEnd;

  @override
  int get hashCode => (AssistantMessageEnd).hashCode;
}

/// A tool-call request emitted by the assistant. Reserved for future
/// adapter versions; v0.1 adapters do not emit these.
///
/// Marked `@experimental` per D12.
@experimental
final class AssistantToolCall extends AssistantStreamEvent {
  /// Creates an [AssistantToolCall].
  const AssistantToolCall({
    required this.callId,
    required this.toolName,
    required this.args,
  });

  /// Unique id for this tool call.
  final String callId;

  /// The tool being requested.
  final String toolName;

  /// JSON-shaped arguments.
  final Map<String, Object?> args;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantToolCall &&
          other.callId == callId &&
          other.toolName == toolName;

  @override
  int get hashCode => Object.hash(AssistantToolCall, callId, toolName);
}

/// Adapter contract: byte stream → [AssistantStreamEvent]s.
///
/// Adapter selection is constructor-time on the controller — there is
/// no polymorphic dispatch, so a typedef captures the contract without
/// adding an abstract class.
///
/// Adapters MUST:
/// - Pass bytes through `Utf8Decoder(allowMalformed: true)` (most do
///   this via the shared SSE framing helper).
/// - Throw `AdapterMismatchError` (from `openui_core`) on the first
///   malformed payload so a misconfigured backend fails loudly rather
///   than silently producing no output.
///
/// Marked `@experimental` per D12.
@experimental
typedef StreamProtocolAdapter =
    Stream<AssistantStreamEvent> Function(Stream<List<int>> bytes);
