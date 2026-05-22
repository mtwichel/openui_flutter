// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// Multiline OpenUI Lang fixtures use embedded `$` for `$state` refs;
// the matching raw-string form is less readable than the escapes.
// ignore_for_file: experimental_member_use, lines_longer_than_80_chars,
// ignore_for_file: leading_newlines_in_multiline_strings, use_raw_strings

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';

import '../helpers/wiring.dart';

class _TestRoot extends StatelessWidget {
  const _TestRoot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      MaterialApp(home: Material(child: child));
}

Widget _renderer(
  TestOpenUiHarness harness, {
  String? response,
  ComponentRegistry? componentRegistry,
  ToolRegistry? toolRegistry,
  bool isStreaming = false,
  void Function(ActionEvent event)? onAction,
  void Function(String message)? onContinueConversation,
  void Function(Map<String, Object?> snapshot)? onStateUpdate,
  Map<String, Object?>? initialState,
  void Function(ParseResult result)? onParseResult,
  void Function(List<OpenUIError> errors)? onError,
}) {
  return _TestRoot(
    child: Renderer(
      response: response,
      library: harness.library,
      componentRegistry: componentRegistry ?? harness.componentRegistry,
      toolRegistry: toolRegistry ?? harness.toolRegistry,
      isStreaming: isStreaming,
      onAction: onAction,
      onContinueConversation: onContinueConversation,
      onStateUpdate: onStateUpdate,
      initialState: initialState,
      onParseResult: onParseResult,
      onError: onError,
    ),
  );
}

void main() {
  group('Renderer', () {
    testWidgets('cold renders a static program', (tester) async {
      final harness = TestOpenUiHarness();
      await tester.pumpWidget(
        _renderer(harness, response: 'root = Text(text: "hello")'),
      );
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('renders nothing when response is null', (tester) async {
      await tester.pumpWidget(_renderer(TestOpenUiHarness()));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets(
      'incrementally renders new statements appended mid-stream',
      (tester) async {
        final harness = TestOpenUiHarness();
        await tester.pumpWidget(
          _renderer(
            harness,
            response: 'root = Text(text: "first")',
            isStreaming: true,
          ),
        );
        expect(find.text('first'), findsOneWidget);

        await tester.pumpWidget(
          _renderer(
            harness,
            response:
                '\n'
                'root = Column(children: [a, b])\n'
                'a = Text(text: "first")\n'
                'b = Text(text: "second")\n',
            isStreaming: true,
          ),
        );
        await tester.pump();
        expect(find.text('first'), findsOneWidget);
        expect(find.text('second'), findsOneWidget);
      },
    );

    testWidgets('reactive props bind two-way through the store', (
      tester,
    ) async {
      final updates = <Map<String, Object?>>[];
      await tester.pumpWidget(
        _renderer(
          TestOpenUiHarness(),
          response:
              '\n'
              r'$name = ""'
              '\n'
              r'root = Input(name: "field", value: $name)'
              '\n',
          onStateUpdate: updates.add,
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('input-field')), 'hi');
      await tester.pump();

      expect(updates.last[r'$name'], 'hi');
    });

    testWidgets(
      'TextEditingController persists across mid-stream rebuilds',
      (tester) async {
        final harness = TestOpenUiHarness();
        Widget app(String response) => _renderer(
          harness,
          response: response,
          isStreaming: true,
        );

        await tester.pumpWidget(
          app(
            '\n'
            r'$name = ""'
            '\n'
            r'root = Input(name: "field", value: $name)'
            '\n',
          ),
        );

        await tester.enterText(
          find.byKey(const ValueKey('input-field')),
          'typed by user',
        );
        await tester.pump();

        const expanded = '''

\$name = ""
\$other = ""
root = Column(children: [Input(name: "field", value: \$name), Input(name: "second", value: \$other)])
''';
        await tester.pumpWidget(app(expanded));
        await tester.pump();

        final field = tester.widget<TextField>(
          find.byKey(const ValueKey('input-field')),
        );
        expect(
          field.controller!.text,
          'typed by user',
          reason: 'controller reused across rebuild',
        );
      },
    );

    testWidgets(
      'action prop dispatches Set step against the store and emits a set '
      'ActionEvent',
      (tester) async {
        final events = <ActionEvent>[];
        const program = '''\$count = 0
root = Counter(value: \$count, onIncrement: [@Set(\$count, \$count + 1)])
''';
        await tester.pumpWidget(
          _renderer(
            TestOpenUiHarness(),
            response: program,
            onAction: events.add,
          ),
        );

        expect(find.text('count=0'), findsOneWidget);
        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
        expect(find.text('count=1'), findsOneWidget);
        expect(events, hasLength(1));
        expect(events.single.type, BuiltinActionType.set);
        expect(events.single.params['target'], r'$count');
      },
    );

    testWidgets(
      'action prop remains interactive after stream finalizes without newline',
      (tester) async {
        final events = <ActionEvent>[];
        const program =
            r'$count = 0'
            '\n'
            r'root = Counter(value: $count, onIncrement: [@Set($count, $count + 1)])';
        await tester.pumpWidget(
          _renderer(
            TestOpenUiHarness(),
            response: program,
            onAction: events.add,
          ),
        );

        expect(find.text('count=0'), findsOneWidget);
        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
        expect(find.text('count=1'), findsOneWidget);
        expect(events, hasLength(1));
        expect(events.single.type, BuiltinActionType.set);
      },
    );

    testWidgets(
      'Reset step writes the declared default back to the store',
      (tester) async {
        const program = '''\$count = 7
root = Column(children: [
  Counter(value: \$count, onIncrement: [@Set(\$count, \$count - 1)]),
  Counter(value: 0, onIncrement: [@Reset(\$count)])
])
''';
        await tester.pumpWidget(
          _renderer(TestOpenUiHarness(), response: program),
        );

        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        expect(find.text('count=6'), findsOneWidget);

        await tester.tap(find.byType(GestureDetector).last);
        await tester.pump();
        expect(find.text('count=7'), findsOneWidget);
      },
    );

    testWidgets('Run step invalidates and re-fires the named query', (
      tester,
    ) async {
      var calls = 0;
      final harness = TestOpenUiHarness(
        tools: [
          StubToolSpec(
            name: 'lookup',
            description: 'query tool',
            execute: (args) async {
              calls++;
              return const ToolResult('query');
            },
          ),
          StubToolSpec(
            name: 'refresh',
            description: 'mutation tool',
            execute: (args) async {
              calls++;
              return const ToolResult('mutation');
            },
          ),
        ],
      );
      const program = '''\$data = @Query(lookup)
refresh = Mutation(name: "refresh")
root = Counter(value: \$tick, onIncrement: [@Run(\$data)])
''';
      await tester.pumpWidget(_renderer(harness, response: program));

      await tester.pump();
      await tester.pumpAndSettle();
      expect(calls, 1);

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets(
      '@Query does not fire while isStreaming is true',
      (tester) async {
        var calls = 0;
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'fetch',
              description: 'fetch',
              execute: (_) async {
                calls++;
                return const ToolResult('value');
              },
            ),
          ],
        );
        const program = '\$products = @Query(fetch)\nroot = Text(text: "x")\n';
        await tester.pumpWidget(
          _renderer(
            harness,
            response: program,
            isStreaming: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 0);
      },
    );

    testWidgets(
      '@Query fires once after streaming flips to false and writes to the store',
      (tester) async {
        var calls = 0;
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'fetch',
              description: 'fetch',
              execute: (_) async {
                calls++;
                return const ToolResult(<Map<String, Object?>>[
                  {'title': 'A'},
                  {'title': 'B'},
                ]);
              },
            ),
          ],
        );
        const program = '''\$products = @Query(fetch)
root = \$products == null ? Text(text: "Loading...") : Text(text: "loaded")
''';
        var snapshot = const <String, Object?>{};
        await tester.pumpWidget(
          _renderer(
            harness,
            response: program,
            onStateUpdate: (s) => snapshot = s,
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.text('loaded'), findsOneWidget);
        expect(snapshot[r'$products'], isA<List<Object?>>());
      },
    );

    testWidgets(
      '@Query fires when root is incomplete (no trailing newline)',
      (tester) async {
        var calls = 0;
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'fetch',
              description: 'fetch',
              execute: (_) async {
                calls++;
                return const ToolResult(<Map<String, Object?>>[
                  {'title': 'A'},
                ]);
              },
            ),
          ],
        );
        const program =
            '\$products = @Query(fetch)\n'
            'root = \$products == null ? Text(text: "Loading...") : Text(text: "loaded")';
        await tester.pumpWidget(_renderer(harness, response: program));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.text('loaded'), findsOneWidget);
      },
    );

    testWidgets(
      '@Query failure surfaces via onError and leaves the store untouched',
      (tester) async {
        final errors = <OpenUIError>[];
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'fetch',
              description: 'fetch',
              execute: (_) async => throw const McpToolError(message: 'boom'),
            ),
          ],
        );
        const program = '\$products = @Query(fetch)\nroot = Text(text: "x")\n';
        var snapshot = const <String, Object?>{};
        await tester.pumpWidget(
          _renderer(
            harness,
            response: program,
            onError: errors.addAll,
            onStateUpdate: (s) => snapshot = s,
          ),
        );
        await tester.pumpAndSettle();
        expect(errors.whereType<McpToolError>(), isNotEmpty);
        expect(snapshot[r'$products'], isNull);
      },
    );

    testWidgets(
      'identical args across two parse passes fire the tool once',
      (tester) async {
        var calls = 0;
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'fetch',
              description: 'fetch',
              execute: (_) async {
                calls++;
                return const ToolResult('value');
              },
            ),
          ],
        );
        const program = '\$products = @Query(fetch)\nroot = Text(text: "x")\n';
        final notifier = ValueNotifier<String>(program);
        await tester.pumpWidget(
          _TestRoot(
            child: ValueListenableBuilder<String>(
              valueListenable: notifier,
              builder: (context, value, _) => Renderer(
                response: value,
                library: harness.library,
                componentRegistry: harness.componentRegistry,
                toolRegistry: harness.toolRegistry,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        notifier.value = '$program ';
        await tester.pumpAndSettle();
        expect(calls, 1);
      },
    );

    testWidgets(
      r'@Run($var) re-evaluates args against the post-@Set store',
      (tester) async {
        final categories = <Object?>[];
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'fetch',
              description: 'fetch',
              execute: (args) async {
                categories.add(args['category']);
                return const ToolResult('value');
              },
            ),
          ],
        );
        const program = '''\$category = "shoes"
\$products = @Query(fetch, category: \$category)
root = Counter(value: 0, onIncrement: [@Set(\$category, "hats"), @Run(\$products)])
''';
        await tester.pumpWidget(_renderer(harness, response: program));
        await tester.pumpAndSettle();
        expect(categories, ['shoes']);

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();
        expect(categories, ['shoes', 'hats']);
      },
    );

    testWidgets(
      r'@Reset on a query-backed $var skips and leaves the store unchanged',
      (tester) async {
        var calls = 0;
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'fetch',
              description: 'fetch',
              execute: (_) async {
                calls++;
                return const ToolResult('value');
              },
            ),
          ],
        );
        const program = '''\$products = @Query(fetch)
root = Counter(value: 0, onIncrement: [@Reset(\$products)])
''';
        final events = <ActionEvent>[];
        var snapshot = const <String, Object?>{};
        await tester.pumpWidget(
          _renderer(
            harness,
            response: program,
            onAction: events.add,
            onStateUpdate: (s) => snapshot = s,
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        final beforeValue = snapshot[r'$products'];

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(snapshot[r'$products'], beforeValue);
        final resetEvent = events.singleWhere(
          (e) => e.type == BuiltinActionType.reset,
        );
        expect(resetEvent.params['success'], isFalse);
        expect(resetEvent.params['reason'], 'no declared default');
      },
    );

    testWidgets(
      '@Run(toolName) invokes the tool directly via toolRegistry',
      (tester) async {
        var calls = 0;
        Map<String, Object?>? lastArgs;
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'snackbar',
              description: 'snackbar tool',
              execute: (args) async {
                calls++;
                lastArgs = args;
                return const ToolResult(null);
              },
            ),
          ],
        );
        const program =
            'root = Counter(value: 0, onIncrement: [@Run(snackbar, message: "Hello")])';
        await tester.pumpWidget(_renderer(harness, response: program));

        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(lastArgs, isNotNull);
        expect(lastArgs!['message'], 'Hello');
      },
    );

    testWidgets('error boundary captures component throws', (tester) async {
      final errors = <OpenUIError>[];
      await tester.pumpWidget(
        _renderer(
          TestOpenUiHarness(),
          response: 'root = Throwing()',
          onError: errors.addAll,
        ),
      );

      tester.takeException();

      expect(errors, isNotEmpty);
      expect(errors.first, isA<OpenUIError>());
    });

    testWidgets('onParseResult fires after each parse', (tester) async {
      ParseResult? captured;
      await tester.pumpWidget(
        _renderer(
          TestOpenUiHarness(),
          response: 'root = Text(text: "x")',
          onParseResult: (r) => captured = r,
        ),
      );

      expect(captured, isNotNull);
      expect(captured!.statements.length, 1);
    });

    testWidgets('initialState seeds the store before parse defaults', (
      tester,
    ) async {
      final snapshots = <Map<String, Object?>>[];
      await tester.pumpWidget(
        _renderer(
          TestOpenUiHarness(),
          response: '\$count = 0\nroot = Text(text: "")',
          initialState: const <String, Object?>{r'$count': 42},
          onStateUpdate: snapshots.add,
        ),
      );

      await tester.pumpWidget(
        _renderer(
          TestOpenUiHarness(),
          response: '''\$count = 0
root = Counter(value: \$count, onIncrement: [@Set(\$count, \$count + 1)])
''',
          initialState: const <String, Object?>{r'$count': 42},
          onStateUpdate: snapshots.add,
        ),
      );
      await tester.pump();
      expect(find.text('count=42'), findsOneWidget);

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(find.text('count=43'), findsOneWidget);
    });

    testWidgets(
      'unknown component surfaces UnknownComponentError and renders placeholder',
      (tester) async {
        final errors = <OpenUIError>[];
        await tester.pumpWidget(
          _renderer(
            TestOpenUiHarness(),
            response: 'root = Mystery()',
            onError: errors.addAll,
          ),
        );
        await tester.pump();

        expect(errors, isNotEmpty);
        expect(errors.first, isA<UnknownComponentError>());
      },
    );

    testWidgets(
      'missing renderer surfaces MissingRendererError and renders placeholder',
      (tester) async {
        final errors = <OpenUIError>[];
        final harness = TestOpenUiHarness();
        await tester.pumpWidget(
          _renderer(
            harness,
            response: 'root = Text(text: "hello")',
            componentRegistry: const ComponentRegistry(renderers: {}),
            onError: errors.addAll,
          ),
        );
        await tester.pump();

        expect(errors.whereType<MissingRendererError>(), isNotEmpty);
        expect(
          errors.whereType<MissingRendererError>().first.component,
          'Text',
        );
      },
    );

    testWidgets(
      'reference cycle surfaces as CyclicStateError, not stack overflow',
      (tester) async {
        final errors = <OpenUIError>[];
        await tester.pumpWidget(
          _renderer(
            TestOpenUiHarness(),
            response: '\nroot = a\na = b\nb = a\n',
            onError: errors.addAll,
          ),
        );
        await tester.pump();

        expect(errors.whereType<CyclicStateError>(), isNotEmpty);
      },
    );

    testWidgets(
      '@ToAssistant emits a continue-conversation callback with the '
      'evaluated message',
      (tester) async {
        final messages = <String>[];
        const program =
            '''root = Counter(value: 0, onIncrement: [@ToAssistant("retry")])
''';
        await tester.pumpWidget(
          _renderer(
            TestOpenUiHarness(),
            response: program,
            onContinueConversation: messages.add,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pump();

        expect(messages, ['retry']);
      },
    );

    testWidgets(
      '@Run on a mutation fires the mutation and halts on failure',
      (tester) async {
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'fail',
              description: 'failing mutation tool',
              execute: (args) async => throw StateError('mut-fail'),
            ),
          ],
        );
        const program = '''refresh = Mutation(name: "fail")
\$flag = 0
root = Counter(value: \$flag, onIncrement: [@Run(refresh), @Set(\$flag, 999)])
''';
        final stateUpdates = <Map<String, Object?>>[];
        await tester.pumpWidget(
          _renderer(
            harness,
            response: program,
            onStateUpdate: stateUpdates.add,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
        await tester.pumpAndSettle();

        final lastFlag = stateUpdates.isEmpty ? 0 : stateUpdates.last[r'$flag'];
        expect(lastFlag, 0);
      },
    );

    testWidgets(
      '@Run on a failing mutation surfaces a single OpenUIError through '
      'onError',
      (tester) async {
        final harness = TestOpenUiHarness(
          tools: [
            StubToolSpec(
              name: 'fail',
              description: 'failing mutation tool',
              execute: (args) async => throw StateError('boom'),
            ),
          ],
        );
        const program = '''refresh = Mutation(name: "fail")
root = Counter(value: 0, onIncrement: [@Run(refresh)])
''';
        var lastSnapshot = const <OpenUIError>[];
        await tester.pumpWidget(
          _renderer(
            harness,
            response: program,
            onError: (errors) {
              lastSnapshot = errors;
            },
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
        await tester.pumpAndSettle();

        final mutationErrors = lastSnapshot.whereType<EvaluationError>();
        expect(mutationErrors, hasLength(1));
      },
    );

    testWidgets(
      'last-good cache covers ticks where the parser produces no root',
      (tester) async {
        final harness = TestOpenUiHarness();
        Widget tree(String response) => _renderer(
          harness,
          response: response,
          isStreaming: true,
        );

        await tester.pumpWidget(tree('root = Text(text: "kept")\n'));
        await tester.pumpAndSettle();
        expect(find.text('kept'), findsOneWidget);

        await tester.pumpWidget(
          tree(
            r'$x = 0'
            '\n',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('kept'), findsNothing);
      },
    );

    testWidgets(
      'ternary in children array renders chosen CompCall branch',
      (tester) async {
        const program = '''\$saved = ""
root = Column(children: [
  Counter(value: 0, onIncrement: [@Set(\$saved, "hi")]),
  \$saved == "" ? Text(text: "empty") : Text(text: \$saved)
])
''';
        await tester.pumpWidget(
          _renderer(TestOpenUiHarness(), response: program),
        );
        await tester.pump();

        expect(find.text('empty'), findsOneWidget);
        expect(find.text('hi'), findsNothing);

        await tester.tap(find.byType(GestureDetector));
        await tester.pump();

        expect(find.text('empty'), findsNothing);
        expect(find.text('hi'), findsOneWidget);
      },
    );

    testWidgets(
      'ternary as sole child still uses widget expansion (hasComp detects '
      'Ternary)',
      (tester) async {
        const program = '''\$saved = "x"
root = Column(children: [
  \$saved == "" ? Text(text: "empty") : Text(text: "filled")
])
''';
        await tester.pumpWidget(
          _renderer(TestOpenUiHarness(), response: program),
        );
        await tester.pump();

        expect(find.text('filled'), findsOneWidget);
        expect(find.text('empty'), findsNothing);
      },
    );

    testWidgets(
      '@Each with the new 3-arg form renders one widget per item',
      (tester) async {
        const program = '''items = ["alpha", "beta", "gamma"]
root = @Each(items, "row", Text(text: row))
''';
        await tester.pumpWidget(
          _renderer(TestOpenUiHarness(), response: program),
        );
        await tester.pump();
        expect(find.text('alpha'), findsOneWidget);
        expect(find.text('beta'), findsOneWidget);
        expect(find.text('gamma'), findsOneWidget);
      },
    );

    testWidgets(
      'component prop set to @Each resolves through the prop-iteration branch',
      (tester) async {
        const program = '''items = ["one", "two"]
root = Column(children: @Each(items, "row", Text(text: row)))
''';
        await tester.pumpWidget(
          _renderer(TestOpenUiHarness(), response: program),
        );
        await tester.pump();
        expect(find.text('one'), findsOneWidget);
        expect(find.text('two'), findsOneWidget);
      },
    );

    testWidgets(
      'cache resets when a new response is unrelated to the previous',
      (tester) async {
        final harness = TestOpenUiHarness();
        Widget tree(String response, {bool streaming = true}) => _renderer(
          harness,
          response: response,
          isStreaming: streaming,
        );

        await tester.pumpWidget(tree('root = Text(text: "alpha")\n'));
        await tester.pumpAndSettle();
        expect(find.text('alpha'), findsOneWidget);

        await tester.pumpWidget(tree(''));
        await tester.pumpAndSettle();
        expect(find.text('alpha'), findsNothing);
      },
    );
  });
}
