import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// One entry in the chat transcript.
///
/// Sealed: the five concrete shapes correspond to the JS reference's
/// `Message` union plus a `SystemMessage` for prompts. Every subclass
/// carries a unique [id] (UUID v4) and the [createdAt] timestamp.
///
/// Equality is structural over every field. The [id] participates so a
/// regenerated message (e.g. after stream re-fire) compares unequal —
/// downstream lists that key on `id` will replace the entry rather than
/// merge updates over it.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
sealed class Message {
  /// Creates a [Message] with an auto-generated [id] when one is not
  /// supplied.
  Message({String? id, DateTime? createdAt})
    : id = id ?? _uuid.v4(),
      createdAt = createdAt ?? DateTime.now();

  /// Stable identifier. UUID v4 by default; consumers may pass a
  /// caller-owned value (e.g. from a persistence layer).
  final String id;

  /// Wall-clock time the message was created. Used for sort and display
  /// only — no logic depends on its precision.
  final DateTime createdAt;
}

/// A message from the user.
///
/// Marked `@experimental` per D12.
@experimental
final class UserMessage extends Message {
  /// Creates a [UserMessage].
  UserMessage({
    required this.content,
    super.id,
    super.createdAt,
  });

  /// Plain-text user input. Multi-part / attachment messages are
  /// deferred to a later milestone.
  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserMessage &&
          other.id == id &&
          other.createdAt == createdAt &&
          other.content == content;

  @override
  int get hashCode => Object.hash(UserMessage, id, createdAt, content);
}

/// A message from the assistant.
///
/// The [response] field is the cumulative OpenUI Lang source that the
/// renderer parses. While streaming, the controller updates this in
/// place; downstream consumers should treat the message as a value
/// type and rebuild on each delta.
///
/// Marked `@experimental` per D12.
@experimental
final class AssistantMessage extends Message {
  /// Creates an [AssistantMessage].
  AssistantMessage({
    required this.response,
    this.isStreaming = false,
    super.id,
    super.createdAt,
  });

  /// Cumulative OpenUI Lang source emitted by the LLM so far.
  final String response;

  /// `true` while the upstream stream is still appending to [response].
  final bool isStreaming;

  /// Returns a copy with the given fields overridden. Used by the
  /// controller to append deltas without mutating the value.
  AssistantMessage copyWith({String? response, bool? isStreaming}) {
    return AssistantMessage(
      id: id,
      createdAt: createdAt,
      response: response ?? this.response,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantMessage &&
          other.id == id &&
          other.createdAt == createdAt &&
          other.response == response &&
          other.isStreaming == isStreaming;

  @override
  int get hashCode =>
      Object.hash(AssistantMessage, id, createdAt, response, isStreaming);
}

/// A request to invoke a tool — emitted by the assistant during a
/// streaming turn.
///
/// Marked `@experimental` per D12.
@experimental
final class ToolCallMessage extends Message {
  /// Creates a [ToolCallMessage].
  ToolCallMessage({
    required this.toolName,
    required this.args,
    super.id,
    super.createdAt,
  });

  /// The tool name being requested.
  final String toolName;

  /// JSON-shaped arguments.
  final Map<String, Object?> args;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolCallMessage &&
          other.id == id &&
          other.createdAt == createdAt &&
          other.toolName == toolName &&
          _mapEquals(other.args, args);

  @override
  int get hashCode =>
      Object.hash(ToolCallMessage, id, createdAt, toolName, _mapHash(args));
}

/// The resolved result of a tool call.
///
/// Marked `@experimental` per D12.
@experimental
final class ToolResultMessage extends Message {
  /// Creates a [ToolResultMessage].
  ToolResultMessage({
    required this.toolCallId,
    required this.result,
    this.isError = false,
    super.id,
    super.createdAt,
  });

  /// The [ToolCallMessage.id] this result resolves.
  final String toolCallId;

  /// The resolved value (typically a JSON-shaped map / string / list).
  final Object? result;

  /// `true` when the upstream tool reported an error.
  final bool isError;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolResultMessage &&
          other.id == id &&
          other.createdAt == createdAt &&
          other.toolCallId == toolCallId &&
          other.result == result &&
          other.isError == isError;

  @override
  int get hashCode => Object.hash(
    ToolResultMessage,
    id,
    createdAt,
    toolCallId,
    result,
    isError,
  );
}

/// A system / instruction prompt.
///
/// Marked `@experimental` per D12.
@experimental
final class SystemMessage extends Message {
  /// Creates a [SystemMessage].
  SystemMessage({
    required this.content,
    super.id,
    super.createdAt,
  });

  /// Plain-text instructions.
  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemMessage &&
          other.id == id &&
          other.createdAt == createdAt &&
          other.content == content;

  @override
  int get hashCode => Object.hash(SystemMessage, id, createdAt, content);
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (!b.containsKey(k)) return false;
    if (a[k] != b[k]) return false;
  }
  return true;
}

int _mapHash(Map<String, Object?> m) {
  var h = 0;
  for (final e in m.entries) {
    h ^= Object.hash(e.key, e.value);
  }
  return h;
}
