import 'package:meta/meta.dart';

import 'package:openui_chat/src/message.dart';

/// Snapshot of a chat controller's state.
///
/// Immutable. Each controller transition produces a new instance and
/// publishes it on the controller's broadcast stream. Equality is
/// structural so consumers can short-circuit redundant rebuilds via
/// `distinct()`.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ChatState {
  /// Creates a [ChatState].
  ChatState({
    List<Message> messages = const <Message>[],
    this.isRunning = false,
    this.error,
    this.threadId,
  }) : messages = List.unmodifiable(messages);

  /// Convenience initial state — no messages, idle.
  static final ChatState initial = ChatState();

  /// Transcript in send order. The most recently appended message is
  /// last.
  final List<Message> messages;

  /// `true` while a `sendMessage` is in flight (or being queued).
  final bool isRunning;

  /// Most recent failure surfaced from a transport or adapter, or
  /// `null` after a successful turn.
  final Object? error;

  /// Optional thread id — opaque to the controller; consumers may use
  /// it to disambiguate parallel threads in storage.
  final String? threadId;

  /// Returns a copy with the given fields overridden. Passing `null`
  /// for [error] does not clear it — pass [clearError] to do that.
  ChatState copyWith({
    List<Message>? messages,
    bool? isRunning,
    Object? error,
    String? threadId,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isRunning: isRunning ?? this.isRunning,
      error: clearError ? null : (error ?? this.error),
      threadId: threadId ?? this.threadId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatState &&
          other.isRunning == isRunning &&
          other.error == error &&
          other.threadId == threadId &&
          _messageListsEqual(other.messages, messages);

  @override
  int get hashCode => Object.hash(
    ChatState,
    isRunning,
    error,
    threadId,
    Object.hashAll(messages),
  );
}

bool _messageListsEqual(List<Message> a, List<Message> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
