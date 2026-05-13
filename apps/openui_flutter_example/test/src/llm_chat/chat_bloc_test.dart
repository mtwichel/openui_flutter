import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui_flutter_example/src/llm_chat/llm_chat.dart';
import 'package:openui_flutter_example/src/llm_chat/ui_message.dart';

class _FakeService implements DartanticChatService {
  final List<StreamController<LlmChatEvent>> controllers =
      <StreamController<LlmChatEvent>>[];
  int resetCount = 0;
  int closeCount = 0;

  @override
  Stream<LlmChatEvent> sendMessage(String text) {
    final controller = StreamController<LlmChatEvent>();
    controllers.add(controller);
    return controller.stream;
  }

  @override
  void reset() {
    resetCount++;
  }
}

// Yields the microtask queue twice so a chunk dispatched via `add()`
// reaches the bloc's event handler before the next assertion runs.
Future<void> _tick() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('ChatBloc', () {
    late _FakeService service;

    setUp(() {
      service = _FakeService();
    });

    blocTest<ChatBloc, ChatState>(
      'happy-path single turn streams chunks into the trailing message',
      build: () => ChatBloc(service: service),
      act: (bloc) async {
        bloc.add(const MessageSubmitted('hi'));
        await _tick();
        service.controllers.last.add(const LlmChatEvent.output('Hello'));
        await _tick();
        service.controllers.last.add(const LlmChatEvent.output(' world'));
        await _tick();
        await service.controllers.last.close();
      },
      expect: () => [
        predicate<ChatState>(
          (s) =>
              s.status == ChatStatus.streaming &&
              s.messages.length == 1 &&
              s.messages[0].role == UiMessageRole.user &&
              s.messages[0].text == 'hi',
          'streaming with user turn only',
        ),
        predicate<ChatState>(
          (s) =>
              s.status == ChatStatus.streaming &&
              s.messages.length == 2 &&
              s.messages.last.role == UiMessageRole.assistant &&
              s.messages.last.text == 'Hello',
          'assistant created on first output chunk',
        ),
        predicate<ChatState>(
          (s) =>
              s.status == ChatStatus.streaming &&
              s.messages.last.text == 'Hello world',
          'second chunk appended',
        ),
        predicate<ChatState>(
          (s) =>
              s.status == ChatStatus.idle &&
              s.messages.length == 2 &&
              s.messages.last.text == 'Hello world',
          'idle with full assistant turn',
        ),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'multi-turn grows the transcript and preserves prior turns',
      build: () => ChatBloc(service: service),
      act: (bloc) async {
        bloc.add(const MessageSubmitted('one'));
        await _tick();
        service.controllers.last.add(const LlmChatEvent.output('A'));
        await _tick();
        await service.controllers.last.close();
        await _tick();

        bloc.add(const MessageSubmitted('two'));
        await _tick();
        service.controllers.last.add(const LlmChatEvent.output('B'));
        await _tick();
        await service.controllers.last.close();
      },
      verify: (bloc) {
        expect(bloc.state.status, ChatStatus.idle);
        expect(bloc.state.messages.length, 4);
        expect(bloc.state.messages[0].text, 'one');
        expect(bloc.state.messages[1].text, 'A');
        expect(bloc.state.messages[2].text, 'two');
        expect(bloc.state.messages[3].text, 'B');
        expect(service.controllers.length, 2);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'thinking and tool events appear in transcript during streaming',
      build: () => ChatBloc(service: service),
      act: (bloc) async {
        bloc.add(const MessageSubmitted('search this'));
        await _tick();
        service.controllers.last.add(
          const LlmChatEvent.thinking('planning...'),
        );
        await _tick();
        service.controllers.last.add(
          const LlmChatEvent.tool('web_search: started'),
        );
        await _tick();
        service.controllers.last.add(const LlmChatEvent.output('Answer'));
        await _tick();
      },
      verify: (bloc) {
        expect(bloc.state.status, ChatStatus.streaming);
        expect(bloc.state.messages[0].role, UiMessageRole.user);
        expect(bloc.state.messages[1].role, UiMessageRole.thinking);
        expect(bloc.state.messages[2].role, UiMessageRole.tool);
        expect(bloc.state.messages[3].role, UiMessageRole.assistant);
        expect(bloc.state.messages[3].text, 'Answer');
        expect(
          bloc.state.messages.any(
            (m) =>
                m.role == UiMessageRole.thinking && m.text.contains('planning'),
          ),
          isTrue,
        );
        expect(
          bloc.state.messages.any(
            (m) =>
                m.role == UiMessageRole.tool && m.text.contains('web_search'),
          ),
          isTrue,
        );
      },
    );

    blocTest<ChatBloc, ChatState>(
      'mid-stream error drops the in-progress turn, preserves prior turns',
      build: () => ChatBloc(service: service),
      act: (bloc) async {
        bloc.add(const MessageSubmitted('one'));
        await _tick();
        service.controllers.last.add(const LlmChatEvent.output('A'));
        await _tick();
        await service.controllers.last.close();
        await _tick();

        bloc.add(const MessageSubmitted('two'));
        await _tick();
        service.controllers.last.add(const LlmChatEvent.output('Bp'));
        await _tick();
        service.controllers.last.addError(StateError('boom'));
        await _tick();
      },
      verify: (bloc) {
        expect(bloc.state.status, ChatStatus.error);
        expect(bloc.state.error, contains('boom'));
        // First turn preserved (user + assistant 'A'); second user kept,
        // second assistant placeholder removed.
        expect(bloc.state.messages.length, 3);
        expect(bloc.state.messages[0].text, 'one');
        expect(bloc.state.messages[1].text, 'A');
        expect(bloc.state.messages[2].text, 'two');
      },
    );

    blocTest<ChatBloc, ChatState>(
      'clear-while-streaming cancels the subscription and resets the service',
      build: () => ChatBloc(service: service),
      act: (bloc) async {
        bloc.add(const MessageSubmitted('hi'));
        await _tick();
        service.controllers.last.add(const LlmChatEvent.output('partial'));
        await _tick();
        bloc.add(const ChatCleared());
        await _tick();
      },
      verify: (bloc) {
        expect(bloc.state, const ChatState());
        expect(service.resetCount, 1);
        // The bloc cancelled its subscription, so the controller has no
        // listeners.
        expect(service.controllers.last.hasListener, isFalse);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'submitting after an error clears state.error',
      build: () => ChatBloc(service: service),
      seed: () => const ChatState(
        status: ChatStatus.error,
        messages: [
          UiMessage(id: 'a', role: UiMessageRole.user, text: 'old'),
        ],
        error: 'previous failure',
      ),
      act: (bloc) async {
        bloc.add(const MessageSubmitted('retry'));
        await _tick();
      },
      verify: (bloc) {
        expect(bloc.state.error, isNull);
        expect(bloc.state.status, ChatStatus.streaming);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'clear-while-idle empties the transcript and resets the service',
      build: () => ChatBloc(service: service),
      seed: () => const ChatState(
        messages: [
          UiMessage(id: 'a', role: UiMessageRole.user, text: 'old'),
        ],
      ),
      act: (bloc) async {
        bloc.add(const ChatCleared());
        await _tick();
      },
      expect: () => [const ChatState()],
      verify: (_) {
        expect(service.resetCount, 1);
      },
    );

    test(
      'bloc.close() invokes service.close() and cancels any subscription',
      () async {
        final bloc = ChatBloc(service: service)
          ..add(const MessageSubmitted('hi'));
        await _tick();
        expect(service.controllers.last.hasListener, isTrue);

        await bloc.close();

        expect(service.closeCount, 1);
        expect(service.controllers.last.hasListener, isFalse);
      },
    );
  });
}
