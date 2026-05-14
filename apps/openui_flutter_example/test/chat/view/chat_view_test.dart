import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openui_components/openui_components.dart';
import 'package:openui_core/openui_core.dart';
import 'package:openui_flutter_example/chat/chat.dart';
import 'package:openui_flutter_example/chat/snackbar_tool.dart';

class _MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

class _NoopService implements DartanticChatService {
  @override
  Stream<LlmChatEvent> sendMessage(String text) =>
      const Stream<LlmChatEvent>.empty();
  @override
  void reset() {}
}

final Library<Widget> _testChatLibrary = standardLibrary().extend(
  tools: [SnackbarTool()],
);

Widget _viewHarness(ChatBloc bloc) => MaterialApp(
  home: BlocProvider<ChatBloc>.value(
    value: bloc,
    child: ChatView(
      library: _testChatLibrary,
      systemPrompt: 'system prompt',
    ),
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

const _streamingPartialRender = ChatState(
  status: ChatStatus.streaming,
  messages: [
    UiMessage(id: 'u1', role: UiMessageRole.user, text: 'build ui'),
    UiMessage(
      id: 'a1',
      role: UiMessageRole.assistant,
      text: 'root = Stack(children: [TextContent(text: "Partial")])',
    ),
  ],
);

const _idleFinalRender = ChatState(
  messages: [
    UiMessage(id: 'u1', role: UiMessageRole.user, text: 'build ui'),
    UiMessage(
      id: 'a1',
      role: UiMessageRole.assistant,
      text: 'root = Stack(children: [TextContent(text: "Final")])',
    ),
  ],
);

const _errorState = ChatState(
  status: ChatStatus.error,
  messages: [UiMessage(id: 'u1', role: UiMessageRole.user, text: 'hi')],
  error: 'Boom',
);

/// Keys must match collapsible panel header keys in `chat_view.dart`.
const _kGeneratedOpenUICodePanelHeaderKey = ValueKey<String>(
  'generated-openui-code-panel-header',
);
const _kStoreInspectorPanelHeaderKey = ValueKey<String>(
  'store-inspector-panel-header',
);
const _kActionLogPanelHeaderKey = ValueKey<String>(
  'action-log-panel-header',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const MessageSubmitted(''));
    registerFallbackValue(
      const RenderStoreSnapshotUpdated(<String, Object?>{}),
    );
    registerFallbackValue(
      OpenUiHostActionLogged(
        OpenUiActionLogEntry(
          loggedAt: DateTime(2000),
          type: 'fallback',
        ),
      ),
    );
    registerFallbackValue(const OpenUiActionLogCleared());
    registerFallbackValue(const GeminiApiKeySubmitted(''));
    registerFallbackValue(const GeminiSessionApiKeyCleared());
    registerFallbackValue(
      const LlmDebugPanelExpansionChanged(
        panel: LlmDebugPanel.generatedOpenUiCode,
        expanded: true,
      ),
    );
  });

  group('ChatView', () {
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
      expect(find.text('root = Card(children: [])'), findsOneWidget);
    });

    testWidgets('shows collapsible generated code, store, and action panels', (
      tester,
    ) async {
      _setWideViewport(tester);
      _stub(bloc, _streamingTwoMessages);

      await tester.pumpWidget(_viewHarness(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Generated OpenUI code'), findsOneWidget);
      expect(find.text('Store inspector'), findsOneWidget);
      expect(find.text('Action log'), findsOneWidget);
      // Collapsed by default: code body is not built.
      expect(
        find.text('// Generated OpenUI code will appear here.'),
        findsNothing,
      );
      expect(find.text('// No store keys yet.'), findsNothing);
      expect(find.text('// No actions logged yet.'), findsNothing);

      await tester.tap(find.byKey(_kGeneratedOpenUICodePanelHeaderKey));
      await tester.pump();
      verify(
        () => bloc.add(
          const LlmDebugPanelExpansionChanged(
            panel: LlmDebugPanel.generatedOpenUiCode,
            expanded: true,
          ),
        ),
      ).called(1);

      await tester.tap(find.byKey(_kStoreInspectorPanelHeaderKey));
      await tester.pump();
      verify(
        () => bloc.add(
          const LlmDebugPanelExpansionChanged(
            panel: LlmDebugPanel.storeInspector,
            expanded: true,
          ),
        ),
      ).called(1);

      await tester.tap(find.byKey(_kActionLogPanelHeaderKey));
      await tester.pump();
      verify(
        () => bloc.add(
          const LlmDebugPanelExpansionChanged(
            panel: LlmDebugPanel.actionLog,
            expanded: true,
          ),
        ),
      ).called(1);
    });

    testWidgets('store inspector shows renderStoreSnapshot from ChatState', (
      tester,
    ) async {
      _setWideViewport(tester);
      _stub(
        bloc,
        const ChatState(
          messages: [
            UiMessage(id: 'u1', role: UiMessageRole.user, text: 'x'),
            UiMessage(
              id: 'a1',
              role: UiMessageRole.assistant,
              text: 'root = Text(text: "hi")',
            ),
          ],
          renderStoreSnapshot: <String, Object?>{r'$count': 3},
          isStoreInspectorPanelExpanded: true,
        ),
      );

      await tester.pumpWidget(_viewHarness(bloc));
      await tester.pumpAndSettle();

      expect(find.textContaining(r'$count'), findsWidgets);
      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('action log shows actionLog from ChatState', (tester) async {
      _setWideViewport(tester);
      _stub(
        bloc,
        ChatState(
          messages: const [
            UiMessage(id: 'u1', role: UiMessageRole.user, text: 'x'),
            UiMessage(
              id: 'a1',
              role: UiMessageRole.assistant,
              text: 'root = Text(text: "hi")',
            ),
          ],
          actionLog: [
            OpenUiActionLogEntry(
              loggedAt: DateTime(2024, 6, 15, 14, 30, 5),
              type: 'Snack',
              humanFriendlyMessage: 'Popped',
            ),
          ],
          isActionLogPanelExpanded: true,
        ),
      );

      await tester.pumpWidget(_viewHarness(bloc));
      await tester.pumpAndSettle();

      expect(find.textContaining('Snack'), findsWidgets);
      expect(find.textContaining('Popped'), findsWidgets);
      expect(find.textContaining('14:30:05'), findsWidgets);
    });

    testWidgets('assistant transcript renders each assistant response text', (
      tester,
    ) async {
      _setWideViewport(tester);
      _stub(bloc, _twoAssistantTurns);

      await tester.pumpWidget(_viewHarness(bloc));

      // r=1 appears once (transcript bubble); r=2 appears once (latest
      // assistant bubble only — generated code panel is collapsed by default).
      expect(find.text('r=1'), findsOneWidget);
      expect(find.text('r=2'), findsOneWidget);
    });

    testWidgets('renderer uses final assistant response after streaming ends', (
      tester,
    ) async {
      _setWideViewport(tester);
      when(() => bloc.state).thenReturn(_idleFinalRender);
      whenListen(
        bloc,
        Stream<ChatState>.fromIterable([
          _streamingPartialRender,
          _idleFinalRender,
        ]),
        initialState: _streamingPartialRender,
      );

      await tester.pumpWidget(_viewHarness(bloc));
      await tester.pump();

      expect(find.text('Final'), findsOneWidget);
      expect(find.text('Partial'), findsNothing);
    });

    testWidgets('clear state removes stale renderer fallback', (tester) async {
      _setWideViewport(tester);
      when(() => bloc.state).thenReturn(_idleEmpty);
      whenListen(
        bloc,
        Stream<ChatState>.fromIterable([_idleEmpty]),
        initialState: _idleFinalRender,
      );

      await tester.pumpWidget(_viewHarness(bloc));
      expect(find.text('Final'), findsOneWidget);

      await tester.pump();
      expect(find.text('Final'), findsNothing);
      expect(find.text('Ask the model to build something.'), findsOneWidget);
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

  group('ChatPage', () {
    testWidgets('constructs its own bloc via the injected service factory', (
      tester,
    ) async {
      _setWideViewport(tester);
      var factoryCalls = 0;
      DartanticChatService factory() {
        factoryCalls++;
        return _NoopService();
      }

      await tester.pumpWidget(
        MaterialApp(home: ChatPage(chatServiceFactory: factory)),
      );

      expect(factoryCalls, 1);
      final view = tester.element(find.byType(ChatView));
      expect(BlocProvider.of<ChatBloc>(view), isA<ChatBloc>());
      // Default idle state — input enabled, no error banner.
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isTrue);
    });
  });
}
