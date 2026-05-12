import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:openui_flutter_example/src/llm_chat/chat_bloc.dart';
import 'package:openui_flutter_example/src/llm_chat/llm_chat_screen.dart';
import 'package:openui_flutter_example/src/llm_chat/ui_message.dart';

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

Widget _harness(ChatBloc bloc) => MaterialApp(
  home: BlocProvider<ChatBloc>.value(value: bloc, child: const LlmChatView()),
);

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

const _errorState = ChatState(
  status: ChatStatus.error,
  messages: [UiMessage(id: 'u1', role: UiMessageRole.user, text: 'hi')],
  error: 'Boom',
);

void main() {
  group('LlmChatView', () {
    late _MockChatBloc bloc;

    setUp(() {
      bloc = _MockChatBloc();
      addTearDown(bloc.close);
    });

    testWidgets('input enabled when idle', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => bloc.state).thenReturn(_idleEmpty);
      whenListen(
        bloc,
        const Stream<ChatState>.empty(),
        initialState: _idleEmpty,
      );

      await tester.pumpWidget(_harness(bloc));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isTrue);
      final send = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(send.onPressed, isNotNull);
    });

    testWidgets('input disabled while streaming', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => bloc.state).thenReturn(_streamingTwoMessages);
      whenListen(
        bloc,
        const Stream<ChatState>.empty(),
        initialState: _streamingTwoMessages,
      );

      await tester.pumpWidget(_harness(bloc));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);
      final send = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(send.onPressed, isNull);
    });

    testWidgets('error banner visible on error state', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => bloc.state).thenReturn(_errorState);
      whenListen(
        bloc,
        const Stream<ChatState>.empty(),
        initialState: _errorState,
      );

      await tester.pumpWidget(_harness(bloc));

      expect(find.text('Boom'), findsOneWidget);
    });

    testWidgets('transcript renders user bubble + assistant placeholder', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => bloc.state).thenReturn(_streamingTwoMessages);
      whenListen(
        bloc,
        const Stream<ChatState>.empty(),
        initialState: _streamingTwoMessages,
      );

      await tester.pumpWidget(_harness(bloc));

      expect(find.text('hi'), findsOneWidget);
      expect(find.text('Generated UI #1'), findsOneWidget);
    });

    testWidgets('Clear icon dispatches ChatCleared', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => bloc.state).thenReturn(_idleEmpty);
      whenListen(
        bloc,
        const Stream<ChatState>.empty(),
        initialState: _idleEmpty,
      );

      await tester.pumpWidget(_harness(bloc));

      await tester.tap(find.byTooltip('Clear chat'));
      await tester.pump();

      verify(() => bloc.add(const ChatCleared())).called(1);
    });

    testWidgets('Send dispatches MessageSubmitted with trimmed text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => bloc.state).thenReturn(_idleEmpty);
      whenListen(
        bloc,
        const Stream<ChatState>.empty(),
        initialState: _idleEmpty,
      );

      await tester.pumpWidget(_harness(bloc));

      await tester.enterText(find.byType(TextField), '  hello world  ');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      verify(
        () => bloc.add(const MessageSubmitted('hello world')),
      ).called(1);
    });

    testWidgets('wide viewport: renderer left of transcript', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => bloc.state).thenReturn(_idleEmpty);
      whenListen(
        bloc,
        const Stream<ChatState>.empty(),
        initialState: _idleEmpty,
      );

      await tester.pumpWidget(_harness(bloc));

      expect(find.byType(VerticalDivider), findsOneWidget);
      // A Row exists for the wide-mode split.
      final rendererBox = tester.getRect(
        find.text('Ask the model to build something.'),
      );
      final inputBox = tester.getRect(find.byType(TextField));
      expect(rendererBox.right, lessThan(inputBox.left));
    });

    testWidgets('narrow viewport: renderer above transcript', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      when(() => bloc.state).thenReturn(_idleEmpty);
      whenListen(
        bloc,
        const Stream<ChatState>.empty(),
        initialState: _idleEmpty,
      );

      await tester.pumpWidget(_harness(bloc));

      expect(find.byType(VerticalDivider), findsNothing);
      final dividers = find.byType(Divider);
      expect(dividers, findsWidgets);
      final rendererBox = tester.getRect(
        find.text('Ask the model to build something.'),
      );
      final inputBox = tester.getRect(find.byType(TextField));
      expect(rendererBox.bottom, lessThan(inputBox.top));
    });
  });
}
