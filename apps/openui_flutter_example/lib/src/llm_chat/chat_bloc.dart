import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:openui_flutter_example/src/llm_chat/llm_chat_service.dart';
import 'package:openui_flutter_example/src/llm_chat/ui_message.dart';

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
/// When [status] is [ChatStatus.streaming] the last entry of [messages]
/// is the in-progress assistant turn — its text grows on every chunk.
class ChatState extends Equatable {
  /// Creates a [ChatState].
  const ChatState({
    this.status = ChatStatus.idle,
    this.messages = const [],
    this.error,
  });

  /// Current lifecycle status.
  final ChatStatus status;

  /// Transcript, oldest first. May contain an in-progress trailing
  /// assistant message during streaming.
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
  final String chunk;
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

/// Bloc that owns the live-chat transcript and drives the LLM service.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  /// Creates a [ChatBloc] over [service].
  ChatBloc({required LlmChatService service})
    : _service = service,
      super(const ChatState()) {
    on<MessageSubmitted>(_onMessageSubmitted);
    on<ChatCleared>(_onChatCleared);
    on<_StreamChunkReceived>(_onChunkReceived);
    on<_StreamCompleted>(
      (_, emit) => emit(state.copyWith(status: ChatStatus.idle)),
    );
    on<_StreamFailed>(_onFailed);
  }

  final LlmChatService _service;
  int _idCounter = 0;
  StreamSubscription<String>? _streamSub;

  String _nextId() => 'msg-${_idCounter++}';

  Future<void> _onMessageSubmitted(
    MessageSubmitted event,
    Emitter<ChatState> emit,
  ) async {
    // Defensive: should not happen because the UI disables send while
    // streaming, but we cancel any active subscription anyway.
    await _streamSub?.cancel();
    _streamSub = null;

    final userMsg = UiMessage(
      id: _nextId(),
      role: UiMessageRole.user,
      text: event.text,
    );
    final assistantPlaceholder = UiMessage(
      id: _nextId(),
      role: UiMessageRole.assistant,
      text: '',
    );
    emit(
      state.copyWith(
        status: ChatStatus.streaming,
        messages: [...state.messages, userMsg, assistantPlaceholder],
        error: null,
      ),
    );

    _streamSub = _service
        .sendMessage(event.text)
        .listen(
          (chunk) {
            if (!isClosed) add(_StreamChunkReceived(chunk));
          },
          onError: (Object error) {
            if (!isClosed) add(_StreamFailed(error));
          },
          onDone: () {
            if (!isClosed) add(const _StreamCompleted());
          },
          cancelOnError: true,
        );
  }

  void _onChunkReceived(
    _StreamChunkReceived event,
    Emitter<ChatState> emit,
  ) {
    final messages = [...state.messages];
    if (messages.isEmpty || messages.last.role != UiMessageRole.assistant) {
      return;
    }
    final last = messages.last;
    messages[messages.length - 1] = last.copyWith(
      text: last.text + event.chunk,
    );
    emit(state.copyWith(messages: messages));
  }

  void _onFailed(_StreamFailed event, Emitter<ChatState> emit) {
    final messages = [...state.messages];
    if (messages.isNotEmpty && messages.last.role == UiMessageRole.assistant) {
      messages.removeLast();
    }
    emit(
      state.copyWith(
        status: ChatStatus.error,
        messages: messages,
        error: event.error.toString(),
      ),
    );
  }

  Future<void> _onChatCleared(
    ChatCleared event,
    Emitter<ChatState> emit,
  ) async {
    await _streamSub?.cancel();
    _streamSub = null;
    _service.reset();
    emit(const ChatState());
  }

  @override
  Future<void> close() async {
    await _streamSub?.cancel();
    await _service.close();
    return super.close();
  }
}
