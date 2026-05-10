import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:openui_chat/src/adapters/adapter.dart';
import 'package:openui_chat/src/chat_state.dart';
import 'package:openui_chat/src/formats/message_format.dart';
import 'package:openui_chat/src/message.dart';
import 'package:openui_core/openui_core.dart';

/// Builds the [http.BaseRequest] for one `sendMessage` turn.
///
/// Receives the current conversation (already formatted via the
/// controller's [MessageFormat]) and returns the request the
/// controller will fire. The default implementation posts JSON to a
/// fixed URL; consumers can override to add headers, swap transports,
/// etc.
///
/// Marked `@experimental` per D12.
@experimental
typedef RequestBuilder =
    http.BaseRequest Function(List<Map<String, Object?>> formatted);

/// Default [RequestBuilder]: `POST <endpoint>` with `Content-Type:
/// application/json`. The body is `{ "messages": [...] }`.
@experimental
RequestBuilder defaultRequestBuilder(Uri endpoint) {
  return (formatted) {
    final request = http.Request('POST', endpoint)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(<String, Object?>{'messages': formatted});
    return request;
  };
}

/// Headless chat controller for OpenUI Flutter.
///
/// Owns the message list, drives the SSE adapter, and exposes
/// [stateStream] for consumers to wire into their state-management
/// system of choice. Does not depend on Flutter — works equally well
/// from `setState`, `flutter_bloc`, `riverpod`, or a Dart-only server
/// integration.
///
/// Cancellation semantics: each `sendMessage` allocates its own
/// `http.Client`; [cancelMessage] closes only the in-flight client.
/// Sibling sends (started from a different controller instance) are
/// unaffected.
///
/// Concurrent sends are queue-and-replace per Decision D8 — calling
/// [sendMessage] while a previous send is in flight cancels the
/// previous one and starts the new one in its place.
///
/// Marked `@experimental` per D12.
@experimental
class OpenUiChatController {
  /// Creates an [OpenUiChatController].
  OpenUiChatController({
    required this.requestBuilder,
    required this.adapter,
    MessageFormat? messageFormat,
    http.Client Function()? clientFactory,
    String? threadId,
    List<Message> initialMessages = const <Message>[],
  }) : _messageFormat = messageFormat ?? openAiFormat,
       _clientFactory = clientFactory ?? http.Client.new,
       _state = ChatState(messages: initialMessages, threadId: threadId);

  /// Builds the HTTP request for each turn.
  final RequestBuilder requestBuilder;

  /// The adapter that converts the streaming bytes into
  /// [AssistantStreamEvent]s.
  final StreamProtocolAdapter adapter;

  final MessageFormat _messageFormat;
  final http.Client Function() _clientFactory;
  final StreamController<ChatState> _stateController =
      StreamController<ChatState>.broadcast();
  ChatState _state;
  http.Client? _activeClient;
  StreamSubscription<AssistantStreamEvent>? _activeSub;
  bool _disposed = false;

  /// Broadcast of every [ChatState] transition. Late subscribers
  /// receive the *next* transition only; call [currentState] for the
  /// snapshot at subscription time.
  Stream<ChatState> get stateStream => _stateController.stream;

  /// Current state snapshot.
  ChatState get currentState => _state;

  /// Message list — a view into [currentState].
  List<Message> get messages => _state.messages;

  /// `true` while a turn is in flight.
  bool get isRunning => _state.isRunning;

  /// Appends a user message and fires a new assistant turn. Queues
  /// and replaces any in-flight send (the previous turn is cancelled).
  ///
  /// Returns when the assistant turn completes (success or error).
  /// Errors land on `currentState.error`; the future resolves
  /// normally so consumers can chain without try/catch.
  Future<void> sendMessage(String text) async {
    _ensureNotDisposed();
    if (_activeClient != null) cancelMessage();
    final user = UserMessage(content: text);
    final assistant = AssistantMessage(response: '', isStreaming: true);
    _setState(
      _state.copyWith(
        messages: <Message>[..._state.messages, user, assistant],
        isRunning: true,
        clearError: true,
      ),
    );
    await _runTurn(assistant);
  }

  /// Cancels the in-flight turn, if any. The cancelled `http.Client`
  /// is closed; sibling controllers are unaffected.
  void cancelMessage() {
    final client = _activeClient;
    if (client == null) return;
    _activeClient = null;
    unawaited(_activeSub?.cancel());
    _activeSub = null;
    client.close();
    _markStreamingComplete();
  }

  /// Hook the renderer's action emission back through the chat
  /// controller. v0.1 handles only `ContinueConversationStep` —
  /// the other step types are dispatched locally by the renderer.
  ///
  /// Other step kinds are no-ops here.
  Future<void> handleAction(ActionEvent event) async {
    for (final step in event.plan.steps) {
      if (step is ContinueConversationStep) {
        final ast = step.messageAst;
        final message = ast is Literal && ast.value is String
            ? ast.value! as String
            : null;
        if (message != null) await sendMessage(message);
      }
    }
  }

  /// Closes the broadcast stream, cancels any in-flight turn, and
  /// marks the controller unusable.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelMessage();
    unawaited(_stateController.close());
  }

  Future<void> _runTurn(AssistantMessage initial) async {
    final client = _clientFactory();
    _activeClient = client;
    final request = requestBuilder(_messageFormat(_state.messages));
    try {
      final response = await client.send(request);
      var current = initial;
      _activeSub = adapter(response.stream).listen((event) {
        if (event is AssistantTextDelta) {
          current = current.copyWith(response: current.response + event.delta);
          _replaceLastAssistant(current);
        } else if (event is AssistantMessageEnd) {
          current = current.copyWith(isStreaming: false);
          _replaceLastAssistant(current);
        }
      });
      await _activeSub!.asFuture<void>();
      if (identical(_activeClient, client)) {
        _activeClient = null;
        _activeSub = null;
        _markStreamingComplete();
      }
    } on Object catch (error) {
      if (!identical(_activeClient, client)) {
        // We were cancelled mid-flight; cancelMessage already cleaned up.
        return;
      }
      _activeClient = null;
      _activeSub = null;
      _setState(
        _state.copyWith(
          isRunning: false,
          error: error,
        ),
      );
    } finally {
      client.close();
    }
  }

  void _replaceLastAssistant(AssistantMessage updated) {
    final messages = _state.messages.toList();
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i] is AssistantMessage) {
        messages[i] = updated;
        break;
      }
    }
    _setState(_state.copyWith(messages: messages));
  }

  void _markStreamingComplete() {
    final messages = _state.messages.toList();
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m is AssistantMessage && m.isStreaming) {
        messages[i] = m.copyWith(isStreaming: false);
        break;
      }
    }
    _setState(_state.copyWith(messages: messages, isRunning: false));
  }

  void _setState(ChatState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('OpenUiChatController has been disposed');
    }
  }
}

/// Lightweight action-event payload from the renderer side, mirroring
/// the renderer's `ActionEvent` shape. Defined here so `openui_chat`
/// doesn't depend on the Flutter `openui` package.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ActionEvent {
  /// Creates an [ActionEvent].
  const ActionEvent({
    required this.plan,
    required this.statementId,
    this.payload,
  });

  /// The action plan that fired.
  final ActionPlan plan;

  /// Statement id of the component that produced the event.
  final String statementId;

  /// Optional payload (form submit values, etc.).
  final Object? payload;
}
