import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openui_flutter_example/src/llm_chat/dartantic_chat_service.dart';
import 'package:openui_flutter_example/src/llm_chat/ui_message.dart';

part 'chat_event.dart';
part 'chat_state.dart';

/// Bloc that owns the live-chat transcript and drives the LLM service.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  /// Creates a [ChatBloc] over [service].
  ChatBloc({required DartanticChatService service})
    : _service = service,
      super(const ChatState()) {
    on<MessageSubmitted>(_onMessageSubmitted);
    on<ChatCleared>(_onChatCleared);
    on<_StreamChunkReceived>(_onChunkReceived);
    on<_StreamCompleted>((_, emit) {
      _activeAssistantMessageId = null;
      emit(state.copyWith(status: ChatStatus.idle));
    });
    on<_StreamFailed>(_onFailed);
  }

  final DartanticChatService _service;
  int _idCounter = 0;
  StreamSubscription<LlmChatEvent>? _streamSub;
  String? _activeAssistantMessageId;

  String _nextId() => 'msg-${_idCounter++}';

  Future<void> _onMessageSubmitted(
    MessageSubmitted event,
    Emitter<ChatState> emit,
  ) async {
    // Defensive: should not happen because the UI disables send while
    // streaming, but we cancel any active subscription anyway.
    await _streamSub?.cancel();
    _streamSub = null;
    _activeAssistantMessageId = null;

    final userMsg = UiMessage(
      id: _nextId(),
      role: UiMessageRole.user,
      text: event.text,
    );
    emit(
      state.copyWith(
        status: ChatStatus.streaming,
        messages: [...state.messages, userMsg],
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
    switch (event.chunk.type) {
      case LlmChatEventType.output:
        final activeAssistantId = _activeAssistantMessageId;
        final assistantIndex = activeAssistantId == null
            ? -1
            : messages.lastIndexWhere((m) => m.id == activeAssistantId);
        if (assistantIndex < 0) {
          final assistant = UiMessage(
            id: _nextId(),
            role: UiMessageRole.assistant,
            text: event.chunk.text,
          );
          _activeAssistantMessageId = assistant.id;
          messages.add(assistant);
          emit(state.copyWith(messages: messages));
          return;
        }
        final assistant = messages[assistantIndex];
        messages[assistantIndex] = assistant.copyWith(
          text: assistant.text + event.chunk.text,
        );
      case LlmChatEventType.thinking:
        final thinkingIndex = messages.lastIndexWhere(
          (m) => m.role == UiMessageRole.thinking,
        );
        if (thinkingIndex < 0) {
          messages.add(
            UiMessage(
              id: _nextId(),
              role: UiMessageRole.thinking,
              text: event.chunk.text,
            ),
          );
        } else {
          final thinking = messages[thinkingIndex];
          messages[thinkingIndex] = thinking.copyWith(
            text: '${thinking.text}${event.chunk.text}',
          );
        }
      case LlmChatEventType.tool:
        messages.add(
          UiMessage(
            id: _nextId(),
            role: UiMessageRole.tool,
            text: event.chunk.text,
          ),
        );
    }
    emit(state.copyWith(messages: messages));
  }

  void _onFailed(_StreamFailed event, Emitter<ChatState> emit) {
    final messages = [...state.messages];
    while (messages.isNotEmpty && messages.last.role != UiMessageRole.user) {
      messages.removeLast();
    }
    _activeAssistantMessageId = null;
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
    _activeAssistantMessageId = null;
    _service.reset();
    emit(const ChatState());
  }

  @override
  Future<void> close() async {
    await _streamSub?.cancel();
    return super.close();
  }
}
