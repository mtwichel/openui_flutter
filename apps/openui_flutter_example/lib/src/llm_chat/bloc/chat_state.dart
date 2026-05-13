part of 'chat_bloc.dart';

/// Lifecycle state of the live-chat surface.
enum ChatStatus {
  /// No turn in flight. Send button enabled.
  idle,

  /// A model response is currently streaming.
  streaming,

  /// The most recent turn errored. Send is enabled; an error banner is
  /// visible until the next [MessageSubmitted].
  error,
}

/// Immutable state of [ChatBloc].
///
/// When [status] is [ChatStatus.streaming], [messages] contains the
/// in-progress assistant turn plus optional thinking/tool activity entries.
class ChatState extends Equatable {
  /// Creates a [ChatState].
  const ChatState({
    this.status = ChatStatus.idle,
    this.messages = const [],
    this.error,
  });

  /// Current lifecycle status.
  final ChatStatus status;

  /// Transcript, oldest first. During streaming this may include assistant
  /// deltas plus thinking/tool activity messages.
  final List<UiMessage> messages;

  /// Last error message, or null. Cleared on the next successful submit.
  final String? error;

  /// Returns a copy with the given fields replaced. Pass [error] as
  /// `null` explicitly to clear it; omit the argument to preserve the
  /// current value.
  ChatState copyWith({
    ChatStatus? status,
    List<UiMessage>? messages,
    Object? error = _sentinel,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const Object _sentinel = Object();

  @override
  List<Object?> get props => [status, messages, error];
}
