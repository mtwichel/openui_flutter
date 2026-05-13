// OpenUiActionLogEntry (chat_state part) uses experimental openui_core types.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:dartantic_ai/dartantic_ai.dart' show Agent, GoogleProvider;
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart'
    show ActionEvent, BuiltinActionType, Store;
import 'package:openui_flutter_example/chat/dartantic_chat_service.dart'
    show DartanticChatService, LlmChatEvent, LlmChatEventType, kGeminiProvider;

part 'chat_bloc.mapper.dart';
part 'chat_event.dart';
part 'chat_state.dart';

void _registerGeminiProvider(String apiKey) {
  Agent.providerFactories[kGeminiProvider] = () =>
      GoogleProvider(apiKey: apiKey);
}

void _unregisterGeminiProvider() {
  Agent.providerFactories.remove(kGeminiProvider);
}

ChatState _initialChatState({
  required bool skipGeminiAuth,
  required String dartDefineGeminiApiKey,
}) {
  if (skipGeminiAuth) {
    return const ChatState();
  }
  final trimmed = dartDefineGeminiApiKey.trim();
  if (trimmed.isNotEmpty) {
    _registerGeminiProvider(trimmed);
    return const ChatState();
  }
  return const ChatState(geminiConfigured: false);
}

/// Bloc that owns the live-chat transcript and drives the LLM service.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  /// Creates a [ChatBloc] over [service].
  ///
  /// [dartDefineGeminiApiKey] is normally `--dart-define=GEMINI_API_KEY=...`.
  /// When [skipGeminiAuth] is true (e.g. tests with a fake service), Gemini
  /// registration and the in-app key gate are skipped.
  ChatBloc({
    required DartanticChatService service,
    String dartDefineGeminiApiKey = const String.fromEnvironment(
      'GEMINI_API_KEY',
    ),
    bool skipGeminiAuth = false,
  }) : _service = service,
       _dartDefineGeminiApiKey = dartDefineGeminiApiKey,
       _skipGeminiAuth = skipGeminiAuth,
       super(
         _initialChatState(
           skipGeminiAuth: skipGeminiAuth,
           dartDefineGeminiApiKey: dartDefineGeminiApiKey,
         ),
       ) {
    on<MessageSubmitted>(_onMessageSubmitted);
    on<ChatCleared>(_onChatCleared);
    on<RenderStoreSnapshotUpdated>(_onRenderStoreSnapshotUpdated);
    on<OpenUiHostActionLogged>(_onOpenUiHostActionLogged);
    on<OpenUiActionLogCleared>(_onOpenUiActionLogCleared);
    on<LlmDebugPanelExpansionChanged>(_onLlmDebugPanelExpansionChanged);
    on<GeminiApiKeySubmitted>(_onGeminiApiKeySubmitted);
    on<GeminiSessionApiKeyCleared>(_onGeminiSessionApiKeyCleared);
    on<_StreamChunkReceived>(_onChunkReceived);
    on<_StreamCompleted>((_, emit) {
      _activeAssistantMessageId = null;
      emit(state.copyWith(status: ChatStatus.idle));
    });
    on<_StreamFailed>(_onFailed);
  }

  final DartanticChatService _service;
  final String _dartDefineGeminiApiKey;
  final bool _skipGeminiAuth;
  int _idCounter = 0;
  StreamSubscription<LlmChatEvent>? _streamSub;
  String? _activeAssistantMessageId;

  static const int _maxActionLogEntries = 500;

  String _nextId() => 'msg-${_idCounter++}';

  Future<void> _onMessageSubmitted(
    MessageSubmitted event,
    Emitter<ChatState> emit,
  ) async {
    if (!_skipGeminiAuth && !state.geminiConfigured) return;
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
        renderStoreSnapshot: const <String, Object?>{},
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
        renderStoreSnapshot: const <String, Object?>{},
        actionLog: const <OpenUiActionLogEntry>[],
      ),
    );
  }

  void _onOpenUiHostActionLogged(
    OpenUiHostActionLogged event,
    Emitter<ChatState> emit,
  ) {
    final merged = [...state.actionLog, event.entry];
    final trimmed = merged.length > _maxActionLogEntries
        ? merged.sublist(merged.length - _maxActionLogEntries)
        : merged;
    emit(state.copyWith(actionLog: trimmed));
  }

  void _onOpenUiActionLogCleared(
    OpenUiActionLogCleared event,
    Emitter<ChatState> emit,
  ) {
    if (state.actionLog.isEmpty) return;
    emit(state.copyWith(actionLog: const <OpenUiActionLogEntry>[]));
  }

  void _onLlmDebugPanelExpansionChanged(
    LlmDebugPanelExpansionChanged event,
    Emitter<ChatState> emit,
  ) {
    switch (event.panel) {
      case LlmDebugPanel.generatedOpenUiCode:
        emit(
          state.copyWith(
            isGeneratedOpenUiCodePanelExpanded: event.expanded,
          ),
        );
      case LlmDebugPanel.storeInspector:
        emit(state.copyWith(isStoreInspectorPanelExpanded: event.expanded));
      case LlmDebugPanel.actionLog:
        emit(state.copyWith(isActionLogPanelExpanded: event.expanded));
    }
  }

  void _onRenderStoreSnapshotUpdated(
    RenderStoreSnapshotUpdated event,
    Emitter<ChatState> emit,
  ) {
    emit(
      state.copyWith(
        renderStoreSnapshot: Map<String, Object?>.from(event.snapshot),
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
    emit(
      ChatState(
        geminiConfigured: state.geminiConfigured,
        sessionKeyActive: state.sessionKeyActive,
      ),
    );
  }

  void _onGeminiApiKeySubmitted(
    GeminiApiKeySubmitted event,
    Emitter<ChatState> emit,
  ) {
    if (_skipGeminiAuth) return;
    final key = event.apiKey.trim();
    if (key.isEmpty) return;
    _registerGeminiProvider(key);
    emit(state.copyWith(geminiConfigured: true, sessionKeyActive: true));
  }

  void _onGeminiSessionApiKeyCleared(
    GeminiSessionApiKeyCleared event,
    Emitter<ChatState> emit,
  ) {
    if (_skipGeminiAuth) return;
    final fromDefine = _dartDefineGeminiApiKey.trim();
    if (fromDefine.isNotEmpty) {
      _registerGeminiProvider(fromDefine);
      emit(state.copyWith(geminiConfigured: true, sessionKeyActive: false));
    } else {
      _unregisterGeminiProvider();
      emit(state.copyWith(geminiConfigured: false, sessionKeyActive: false));
    }
  }

  @override
  Future<void> close() async {
    await _streamSub?.cancel();
    return super.close();
  }
}
