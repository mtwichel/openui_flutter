// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openui_chat/openui_chat.dart';
import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }

  @override
  void close() {
    closed = true;
  }
}

http.StreamedResponse _response(List<int> body) {
  return http.StreamedResponse(Stream<List<int>>.fromIterable([body]), 200);
}

http.StreamedResponse _liveResponse(Stream<List<int>> body) {
  return http.StreamedResponse(body, 200);
}

RequestBuilder _stubBuilder() {
  return (formatted) {
    return http.Request('POST', Uri.parse('https://example.test/'))
      ..body = jsonEncode(formatted);
  };
}

void main() {
  group('OpenUiChatController', () {
    test('sendMessage appends user + assistant and streams deltas', () async {
      final client = _FakeClient((_) async {
        return _response(utf8.encode('data: root = Text(text: "x")\n\n'));
      });
      final controller = OpenUiChatController(
        requestBuilder: _stubBuilder(),
        adapter: plainSseAdapter(),
        clientFactory: () => client,
      );
      addTearDown(controller.dispose);

      final states = <ChatState>[];
      controller.stateStream.listen(states.add);

      await controller.sendMessage('hello');

      expect(controller.messages.length, 2);
      expect(controller.messages.first, isA<UserMessage>());
      expect(controller.messages.last, isA<AssistantMessage>());
      final assistant = controller.messages.last as AssistantMessage;
      expect(assistant.response, 'root = Text(text: "x")');
      expect(assistant.isStreaming, isFalse);
      expect(controller.isRunning, isFalse);
      expect(states, isNotEmpty);
    });

    test('cancelMessage closes only the active client', () async {
      final body = StreamController<List<int>>();
      addTearDown(() async => body.close());
      final client = _FakeClient((_) async {
        // Don't close the body — simulate an in-flight stream.
        return _liveResponse(body.stream);
      });
      final controller = OpenUiChatController(
        requestBuilder: _stubBuilder(),
        adapter: plainSseAdapter(),
        clientFactory: () => client,
      );
      addTearDown(controller.dispose);

      unawaited(controller.sendMessage('hi'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.isRunning, isTrue);

      controller.cancelMessage();
      await Future<void>.delayed(Duration.zero);

      expect(client.closed, isTrue);
      expect(controller.isRunning, isFalse);
      final assistant = controller.messages.whereType<AssistantMessage>().last;
      expect(assistant.isStreaming, isFalse);
    });

    test('concurrent sendMessage cancels the previous turn', () async {
      final firstBody = StreamController<List<int>>();
      addTearDown(() async => firstBody.close());
      var firstStarted = false;
      var ix = 0;
      final clients = <_FakeClient>[
        _FakeClient((_) async {
          firstStarted = true;
          return _liveResponse(firstBody.stream);
        }),
        _FakeClient((_) async {
          return _response(utf8.encode('data: SECOND\n\n'));
        }),
      ];

      final controller = OpenUiChatController(
        requestBuilder: _stubBuilder(),
        adapter: plainSseAdapter(),
        clientFactory: () => clients[ix++],
      );
      addTearDown(controller.dispose);

      unawaited(controller.sendMessage('first'));
      await Future<void>.delayed(Duration.zero);
      expect(firstStarted, isTrue);

      await controller.sendMessage('second');

      expect(clients[0].closed, isTrue, reason: 'first client cancelled');
      expect(clients[1].closed, isTrue);
      expect(
        controller.messages.whereType<AssistantMessage>().last.response,
        contains('SECOND'),
      );
    });

    test('error path lands on currentState.error', () async {
      final client = _FakeClient((_) {
        return Future<http.StreamedResponse>.error(StateError('network'));
      });
      final controller = OpenUiChatController(
        requestBuilder: _stubBuilder(),
        adapter: plainSseAdapter(),
        clientFactory: () => client,
      );
      addTearDown(controller.dispose);

      await controller.sendMessage('hi');

      expect(controller.currentState.error, isA<StateError>());
      expect(controller.isRunning, isFalse);
    });

    test(
      'handleAction forwards continueConversation through sendMessage',
      () async {
        var sentBody = '';
        final client = _FakeClient((request) async {
          sentBody = (request as http.Request).body;
          return _response(utf8.encode('data: ack\n\n'));
        });
        final controller = OpenUiChatController(
          requestBuilder: _stubBuilder(),
          adapter: plainSseAdapter(),
          clientFactory: () => client,
        );
        addTearDown(controller.dispose);

        await controller.handleAction(
          const ActionEvent(
            type: BuiltinActionType.continueConversation,
            humanFriendlyMessage: 'please retry',
          ),
        );

        expect(sentBody, contains('please retry'));
        expect(controller.messages.first, isA<UserMessage>());
        expect(
          (controller.messages.first as UserMessage).content,
          'please retry',
        );
      },
    );

    test('handleAction ignores non-continueConversation events', () async {
      final client = _FakeClient((_) async {
        fail('handleAction should not have fired a request for @OpenUrl');
      });
      final controller = OpenUiChatController(
        requestBuilder: _stubBuilder(),
        adapter: plainSseAdapter(),
        clientFactory: () => client,
      );
      addTearDown(controller.dispose);

      await controller.handleAction(
        const ActionEvent(
          type: BuiltinActionType.openUrl,
          params: <String, Object?>{'url': 'https://x'},
        ),
      );
      expect(controller.messages, isEmpty);
    });

    test(
      'handleAction skips continueConversation events with null or empty '
      'humanFriendlyMessage',
      () async {
        final client = _FakeClient((_) async {
          fail('handleAction should not send for empty messages');
        });
        final controller = OpenUiChatController(
          requestBuilder: _stubBuilder(),
          adapter: plainSseAdapter(),
          clientFactory: () => client,
        );
        addTearDown(controller.dispose);

        await controller.handleAction(
          const ActionEvent(
            type: BuiltinActionType.continueConversation,
          ),
        );
        await controller.handleAction(
          const ActionEvent(
            type: BuiltinActionType.continueConversation,
            humanFriendlyMessage: '',
          ),
        );
        expect(controller.messages, isEmpty);
      },
    );

    test('dispose closes the controller and rejects further sends', () async {
      final controller = OpenUiChatController(
        requestBuilder: _stubBuilder(),
        adapter: plainSseAdapter(),
        clientFactory: () => _FakeClient((_) => fail('no send expected')),
      )..dispose();
      expect(() => controller.sendMessage('x'), throwsStateError);
    });

    test('initialMessages seeds the transcript', () {
      final ts = DateTime(2026);
      final controller = OpenUiChatController(
        requestBuilder: _stubBuilder(),
        adapter: plainSseAdapter(),
        initialMessages: <Message>[
          SystemMessage(id: 's', createdAt: ts, content: 'be helpful'),
        ],
      );
      addTearDown(controller.dispose);
      expect(controller.messages.length, 1);
    });

    test('threadId is exposed in currentState', () {
      final controller = OpenUiChatController(
        requestBuilder: _stubBuilder(),
        adapter: plainSseAdapter(),
        threadId: 't-7',
      );
      addTearDown(controller.dispose);
      expect(controller.currentState.threadId, 't-7');
    });

    test('defaultRequestBuilder posts JSON to the configured endpoint', () {
      final builder = defaultRequestBuilder(Uri.parse('https://x.test/'));
      final req =
          builder([
                <String, Object?>{'role': 'user', 'content': 'hi'},
              ])
              as http.Request;
      expect(req.method, 'POST');
      expect(req.headers['Content-Type'], 'application/json');
      expect(jsonDecode(req.body), <String, Object?>{
        'messages': <Map<String, Object?>>[
          <String, Object?>{'role': 'user', 'content': 'hi'},
        ],
      });
    });
  });
}
