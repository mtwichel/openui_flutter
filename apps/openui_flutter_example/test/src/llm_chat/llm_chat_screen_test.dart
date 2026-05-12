import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:openui_flutter_example/src/llm_chat/chat_bloc.dart';
import 'package:openui_flutter_example/src/llm_chat/llm_chat_screen.dart';
import 'package:openui_flutter_example/src/llm_chat/llm_chat_service.dart';
import 'package:openui_flutter_example/src/llm_chat/ui_message.dart';

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

class _NoopService implements LlmChatService {
  @override
  Stream<LlmChatEvent> sendMessage(String text) =>
      const Stream<LlmChatEvent>.empty();
  @override
  void reset() {}
  @override
  Future<void> close() async {}
}

Widget _viewHarness(ChatBloc bloc) => MaterialApp(
  home: BlocProvider<ChatBloc>.value(
    value: bloc,
    child: const LlmChatView(systemPrompt: 'system prompt'),
  ),
);

void _setWideViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
}

void _setNarrowViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
}

void _stub(_MockChatBloc bloc, ChatState state) {
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, const Stream<ChatState>.empty(), initialState: state);
}

const _idleEmpty = ChatState();

const _streamingTwoMessages = ChatState(
  status: ChatStatus.streaming,
  messages: [
    UiMessage(id: 'u1', role: UiMessageRole.user, text: 'hi'),
    UiMessage(
      id: 'a1',
      role: UiMessageRole.assistant,
      text: 'root = Card(children: [])',
    ),
  ],
);

const _twoAssistantTurns = ChatState(
  messages: [
    UiMessage(id: 'u1', role: UiMessageRole.user, text: 'first'),
    UiMessage(id: 'a1', role: UiMessageRole.assistant, text: 'r=1'),
    UiMessage(id: 'u2', role: UiMessageRole.user, text: 'second'),
    UiMessage(id: 'a2', role: UiMessageRole.assistant, text: 'r=2'),
  ],
);

const _errorState = ChatState(
  status: ChatStatus.error,
  messages: [UiMessage(id: 'u1', role: UiMessageRole.user, text: 'hi')],
  error: 'Boom',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const MessageSubmitted(''));
  });

  group('LlmChatView', () {
    late _MockChatBloc bloc;

    setUp(() {
      bloc = _MockChatBloc();
      addTearDown(bloc.close);
    });

    testWidgets('input enabled when idle', (tester) async {
      _setWideViewport(tester);
      _stub(bloc, _idleEmpty);

      await tester.pumpWidget(_viewHarness(bloc));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isTrue);
      final send = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(send.onPressed, isNotNull);
    });

    testWidgets('input disabled while streaming', (tester) async {
      _setWideViewport(tester);
      _stub(bloc, _streamingTwoMessages);

      await tester.pumpWidget(_viewHarness(bloc));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);
      final send = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(send.onPressed, isNull);
    });

    testWidgets('error banner visible on error state', (tester) async {
      _setWideViewport(tester);
      _stub(bloc, _errorState);

      await tester.pumpWidget(_viewHarness(bloc));

      expect(find.text('Boom'), findsOneWidget);
    });

    testWidgets('transcript renders copyable user + assistant messages', (
      tester,
    ) async {
      _setWideViewport(tester);
      _stub(bloc, _streamingTwoMessages);

      await tester.pumpWidget(_viewHarness(bloc));

      expect(find.text('hi'), findsOneWidget);
      expect(find.text('root = Card(children: [])'), findsNWidgets(2));
    });

    testWidgets('shows generated OpenUI code viewer under renderer', (
      tester,
    ) async {
      _setWideViewport(tester);
      _stub(bloc, _streamingTwoMessages);

      await tester.pumpWidget(_viewHarness(bloc));

      expect(find.text('Generated OpenUI code'), findsOneWidget);
      expect(find.text('root = Card(children: [])'), findsOneWidget);
    });

    testWidgets('assistant transcript renders each assistant response text', (
      tester,
    ) async {
      _setWideViewport(tester);
      _stub(bloc, _twoAssistantTurns);

      await tester.pumpWidget(_viewHarness(bloc));

      expect(find.text('r=1'), findsNWidgets(2));
      expect(find.text('r=2'), findsNWidgets(2));
    });

    testWidgets('Clear icon dispatches ChatCleared', (tester) async {
      _setWideViewport(tester);
      _stub(bloc, _idleEmpty);

      await tester.pumpWidget(_viewHarness(bloc));

      await tester.tap(find.byTooltip('Clear chat'));
      await tester.pump();

      verify(() => bloc.add(const ChatCleared())).called(1);
    });

    testWidgets('Send dispatches MessageSubmitted with trimmed text', (
      tester,
    ) async {
      _setWideViewport(tester);
      _stub(bloc, _idleEmpty);

      await tester.pumpWidget(_viewHarness(bloc));

      await tester.enterText(find.byType(TextField), '  hello world  ');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      verify(
        () => bloc.add(const MessageSubmitted('hello world')),
      ).called(1);
    });

    testWidgets('whitespace-only input does NOT dispatch MessageSubmitted', (
      tester,
    ) async {
      _setWideViewport(tester);
      _stub(bloc, _idleEmpty);

      await tester.pumpWidget(_viewHarness(bloc));

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      verifyNever(() => bloc.add(any(that: isA<MessageSubmitted>())));
    });

    testWidgets('wide viewport: renderer left of transcript', (tester) async {
      _setWideViewport(tester);
      _stub(bloc, _idleEmpty);

      await tester.pumpWidget(_viewHarness(bloc));

      expect(find.byType(VerticalDivider), findsOneWidget);
      final rendererBox = tester.getRect(
        find.text('Ask the model to build something.'),
      );
      final inputBox = tester.getRect(find.byType(TextField));
      expect(rendererBox.right, lessThan(inputBox.left));
    });

    testWidgets('narrow viewport: renderer above transcript', (tester) async {
      _setNarrowViewport(tester);
      _stub(bloc, _idleEmpty);

      await tester.pumpWidget(_viewHarness(bloc));

      expect(find.byType(VerticalDivider), findsNothing);
      expect(find.byType(Divider), findsWidgets);
      final rendererBox = tester.getRect(
        find.text('Ask the model to build something.'),
      );
      final inputBox = tester.getRect(find.byType(TextField));
      expect(rendererBox.bottom, lessThan(inputBox.top));
    });
  });

  group('LlmChatScreen', () {
    testWidgets('constructs its own bloc via the injected service factory', (
      tester,
    ) async {
      _setWideViewport(tester);
      var factoryCalls = 0;
      LlmChatService factory() {
        factoryCalls++;
        return _NoopService();
      }

      await tester.pumpWidget(
        MaterialApp(home: LlmChatScreen(serviceFactory: factory)),
      );

      expect(factoryCalls, 1);
      // The wrapper provides a ChatBloc to the subtree.
      final view = tester.element(find.byType(LlmChatView));
      expect(BlocProvider.of<ChatBloc>(view), isA<ChatBloc>());
      // Default idle state — input enabled, no error banner.
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isTrue);
    });
  });
}
