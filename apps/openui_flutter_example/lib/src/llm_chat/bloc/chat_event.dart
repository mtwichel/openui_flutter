part of 'chat_bloc.dart';

/// Base type for [ChatBloc] events.
sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => const [];
}

/// User pressed send with [text].
class MessageSubmitted extends ChatEvent {
  /// Creates a [MessageSubmitted] event.
  const MessageSubmitted(this.text);

  /// The prompt the user entered.
  final String text;

  @override
  List<Object?> get props => [text];
}

/// User pressed clear.
class ChatCleared extends ChatEvent {
  /// Creates a [ChatCleared] event.
  const ChatCleared();
}

class _StreamChunkReceived extends ChatEvent {
  const _StreamChunkReceived(this.chunk);
  final LlmChatEvent chunk;
  @override
  List<Object?> get props => [chunk];
}

class _StreamCompleted extends ChatEvent {
  const _StreamCompleted();
}

class _StreamFailed extends ChatEvent {
  const _StreamFailed(this.error);
  final Object error;
  @override
  List<Object?> get props => [error];
}
