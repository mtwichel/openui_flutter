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

Library<Widget> _testLibrary({List<Tool> tools = const <Tool>[]}) {
  return Library<Widget>(
    tools: tools,
    components: <Component<Widget>>[
      Component<Widget>(
        name: 'Text',
        schema: Schema.fromMap(const <String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'text': <String, Object?>{'type': 'string'},
          },
        }),
        render: (ctx, props, renderNode, id) {
          return Text(props['text'] as String? ?? '');
        },
      ),
      Component<Widget>(
        name: 'Column',
        schema: Schema.fromMap(const <String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'children': <String, Object?>{'type': 'array'},
          },
        }),
        render: (ctx, props, renderNode, id) {
          final children =
              (props['children'] as List<Object?>?)?.cast<Widget>() ??
              const <Widget>[];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        },
      ),
      Component<Widget>(
        name: 'Counter',
        schema: Schema.fromMap(const <String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'value': <String, Object?>{'type': 'integer'},
            'onIncrement': <String, Object?>{
              'type': 'object',
              'x-action': true,
            },
          },
        }),
        render: (ctx, props, renderNode, id) {
          final value = props['value'] as int? ?? 0;
          final hasAction = props.containsKey('onIncrement');
          final action = props['onIncrement'] as ActionPlan?;
          // Disabled when the prop was supplied but resolved to null
          // (streaming-incomplete AST); inert when the prop is absent.
          final disabled = hasAction && action == null;
          return Builder(
            builder: (context) {
              final scope = RendererScope.maybeFind(context);
              final onTap = (scope == null || disabled || action == null)
                  ? null
                  : () => scope.triggerAction('', action: action);
              return GestureDetector(
                onTap: onTap,
                child: Text('count=$value'),
              );
            },
          );
        },
      ),
      Component<Widget>(
        name: 'Input',
        schema: Schema.fromMap(<String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'name': const <String, Object?>{'type': 'string'},
            'value': <String, Object?>{
              'type': 'string',
              'x-reactive': true,
            },
          },
        }),
        render: (ctx, props, renderNode, id) {
          return Builder(
            builder: (context) {
              final binding = props['value'];
              final field = props['name'] as String? ?? id;
              final cache = RendererScope.of(context).formStateCache;
              final storeText = binding is ReactiveAssign
                  ? (binding.value as String? ?? '')
                  : '';
              final controller = cache.controllerFor(
                formName: 'form',
                fieldName: field,
                initialValue: storeText,
              );
              final store = RendererScope.of(context).store;
              if (store.lastNotifyOrigin == StoreChangeOrigin.mutation &&
                  controller.text != storeText) {
                controller.value = TextEditingValue(
                  text: storeText,
                  selection: TextSelection.collapsed(offset: storeText.length),
                );
              }
              return TextField(
                key: ValueKey<String>('input-$field'),
                controller: controller,
                onChanged: (text) {
                  if (binding is ReactiveAssign) {
                    ctx.store.set(binding.target, text);
                  }
                },
              );
            },
          );
        },
      ),
      Component<Widget>(
        name: 'Throwing',
        schema: Schema.fromMap(const <String, Object?>{'type': 'object'}),
        render: (ctx, props, renderNode, id) {
          throw StateError('boom from $id');
        },
      ),
    ],
  );
}

class _TestRoot extends StatelessWidget {
  const _TestRoot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      MaterialApp(home: Material(child: child));
}

void main() {
  group('Renderer', () {
    testWidgets('cold renders a static program', (tester) async {
      final library = _testLibrary();
      await tester.pumpWidget(
        _TestRoot(
          child: Renderer(
            response: 'root = Text(text: "hello")',
            library: library,
          ),
        ),
      );
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('renders nothing when response is null', (tester) async {
      await tester.pumpWidget(
        _TestRoot(
          child: Renderer(library: _testLibrary()),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets(
      'incrementally renders new statements appended mid-stream',
      (tester) async {
        final library = _testLibrary();
        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response: 'root = Text(text: "first")',
              library: library,
              isStreaming: true,
            ),
          ),
        );
        expect(find.text('first'), findsOneWidget);

        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response:
                  '\n'
                  'root = Column(children: [a, b])\n'
                  'a = Text(text: "first")\n'
                  'b = Text(text: "second")\n',
              library: library,
              isStreaming: true,
            ),
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
        _TestRoot(
          child: Renderer(
            response:
                '\n'
                r'$name = ""'
                '\n'
                r'root = Input(name: "field", value: $name)'
                '\n',
            library: _testLibrary(),
            onStateUpdate: updates.add,
          ),
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('input-field')), 'hi');
      await tester.pump();

      expect(updates.last[r'$name'], 'hi');
    });

    testWidgets(
      'TextEditingController persists across mid-stream rebuilds',
      (tester) async {
        Widget app(String response) => _TestRoot(
          child: Renderer(
            response: response,
            library: _testLibrary(),
            isStreaming: true,
          ),
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

        // Mid-stream: a new sibling appears (LLM appends).
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
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(),
              onAction: events.add,
            ),
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
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(),
              onAction: events.add,
            ),
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
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(),
            ),
          ),
        );

        // Tap the first Counter to decrement.
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        expect(find.text('count=6'), findsOneWidget);

        // Tap the reset Counter.
        await tester.tap(find.byType(GestureDetector).last);
        await tester.pump();
        expect(find.text('count=7'), findsOneWidget);
      },
    );

    testWidgets('Run step invalidates and re-fires the named query', (
      tester,
    ) async {
      var calls = 0;
      final tools = <Tool>[
        _StubTool(
          name: 'lookup',
          description: 'query tool',
          handler: (args) async {
            calls++;
            return const ToolResult('query');
          },
        ),
        _StubTool(
          name: 'refresh',
          description: 'mutation tool',
          handler: (args) async {
            calls++;
            return const ToolResult('mutation');
          },
        ),
      ];
      const program = '''\$data = @Query(lookup)
refresh = Mutation(name: "refresh")
root = Counter(value: \$tick, onIncrement: [@Run(\$data)])
''';
      await tester.pumpWidget(
        _TestRoot(
          child: Renderer(
            response: program,
            library: _testLibrary(tools: tools),
          ),
        ),
      );

      // `$data` (a `@Query`) auto-fires once streaming completes; the
      // mutation only fires on `@Run`.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(calls, 1);

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      await tester.pumpAndSettle();
      // `@Run($data)` invalidated and re-fired the query.
      expect(calls, 2);
    });

    testWidgets(
      '@Query does not fire while isStreaming is true',
      (tester) async {
        var calls = 0;
        final tools = <Tool>[
          _StubTool(
            name: 'fetch',
            description: 'fetch',
            handler: (_) async {
              calls++;
              return const ToolResult('value');
            },
          ),
        ];
        const program = '\$products = @Query(fetch)\nroot = Text(text: "x")\n';
        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response: program,
              isStreaming: true,
              library: _testLibrary(tools: tools),
            ),
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
        final tools = <Tool>[
          _StubTool(
            name: 'fetch',
            description: 'fetch',
            handler: (_) async {
              calls++;
              return const ToolResult(<Map<String, Object?>>[
                {'title': 'A'},
                {'title': 'B'},
              ]);
            },
          ),
        ];
        const program = '''\$products = @Query(fetch)
root = \$products == null ? Text(text: "Loading...") : Text(text: "loaded")
''';
        var snapshot = const <String, Object?>{};
        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(tools: tools),
              onStateUpdate: (s) => snapshot = s,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.text('loaded'), findsOneWidget);
        expect(snapshot[r'$products'], isA<ToolResult>());
      },
    );

    testWidgets(
      '@Query failure surfaces via onError and leaves the store untouched',
      (tester) async {
        final errors = <OpenUIError>[];
        final tools = <Tool>[
          _StubTool(
            name: 'fetch',
            description: 'fetch',
            handler: (_) async => throw const McpToolError(message: 'boom'),
          ),
        ];
        const program = '\$products = @Query(fetch)\nroot = Text(text: "x")\n';
        var snapshot = const <String, Object?>{};
        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(tools: tools),
              onError: errors.addAll,
              onStateUpdate: (s) => snapshot = s,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(errors.whereType<McpToolError>(), isNotEmpty);
        // Store slot stays at its prior value (null in this case — the
        // tool failed before it could write anything).
        expect(snapshot[r'$products'], isNull);
      },
    );

    testWidgets(
      'identical args across two parse passes fire the tool once',
      (tester) async {
        var calls = 0;
        final tools = <Tool>[
          _StubTool(
            name: 'fetch',
            description: 'fetch',
            handler: (_) async {
              calls++;
              return const ToolResult('value');
            },
          ),
        ];
        const program = '\$products = @Query(fetch)\nroot = Text(text: "x")\n';
        final notifier = ValueNotifier<String>(program);
        final library = _testLibrary(tools: tools);
        await tester.pumpWidget(
          _TestRoot(
            child: ValueListenableBuilder<String>(
              valueListenable: notifier,
              builder: (context, value, _) => Renderer(
                response: value,
                library: library,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        // Same response, second pump — the firing gate must short-circuit.
        notifier.value = '$program ';
        await tester.pumpAndSettle();
        expect(calls, 1);
      },
    );

    testWidgets(
      r'@Run($var) re-evaluates args against the post-@Set store',
      (tester) async {
        final categories = <Object?>[];
        final tools = <Tool>[
          _StubTool(
            name: 'fetch',
            description: 'fetch',
            handler: (args) async {
              categories.add(args['category']);
              return const ToolResult('value');
            },
          ),
        ];
        const program = '''\$category = "shoes"
\$products = @Query(fetch, category: \$category)
root = Counter(value: 0, onIncrement: [@Set(\$category, "hats"), @Run(\$products)])
''';
        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(tools: tools),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(categories, ['shoes']);

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();
        // The dispatcher evaluates `@Set` first, so `@Run($products)`
        // re-fires the query with the post-set category.
        expect(categories, ['shoes', 'hats']);
      },
    );

    testWidgets(
      r'@Reset on a query-backed $var skips and leaves the store unchanged',
      (tester) async {
        var calls = 0;
        final tools = <Tool>[
          _StubTool(
            name: 'fetch',
            description: 'fetch',
            handler: (_) async {
              calls++;
              return const ToolResult('value');
            },
          ),
        ];
        const program = '''\$products = @Query(fetch)
root = Counter(value: 0, onIncrement: [@Reset(\$products)])
''';
        final events = <ActionEvent>[];
        var snapshot = const <String, Object?>{};
        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(tools: tools),
              onAction: events.add,
              onStateUpdate: (s) => snapshot = s,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        final beforeValue = snapshot[r'$products'];

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();
        // `@Reset` falls through the "no declared default" branch — it
        // does not call the tool and leaves the store value untouched.
        expect(calls, 1);
        expect(snapshot[r'$products'], beforeValue);
        final resetEvent = events.singleWhere(
          (e) => e.type == BuiltinActionType.reset,
        );
        expect(resetEvent.params['success'], isFalse);
        expect(resetEvent.params['reason'], 'no declared default');
      },
    );

    testWidgets('Run step can invoke a tool directly by name', (tester) async {
      var calls = 0;
      Map<String, Object?>? lastArgs;
      final tools = <Tool>[
        _StubTool(
          name: 'snackbar',
          description: 'snackbar tool',
          handler: (args) async {
            calls++;
            lastArgs = args;
            return const ToolResult(null);
          },
        ),
      ];
      const program =
          'root = Counter(value: 0, onIncrement: [@Run(snackbar, message: "Hello")])';
      await tester.pumpWidget(
        _TestRoot(
          child: Renderer(
            response: program,
            library: _testLibrary(tools: tools),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(lastArgs, isNotNull);
      expect(lastArgs!['message'], 'Hello');
    });

    testWidgets('error boundary captures component throws', (tester) async {
      final errors = <OpenUIError>[];
      await tester.pumpWidget(
        _TestRoot(
          child: Renderer(
            response: 'root = Throwing()',
            library: _testLibrary(),
            onError: errors.addAll,
          ),
        ),
      );

      // Drain Flutter's caught error.
      tester.takeException();

      expect(errors, isNotEmpty);
      expect(errors.first, isA<OpenUIError>());
    });

    testWidgets('onParseResult fires after each parse', (tester) async {
      ParseResult? captured;
      await tester.pumpWidget(
        _TestRoot(
          child: Renderer(
            response: 'root = Text(text: "x")',
            library: _testLibrary(),
            onParseResult: (r) => captured = r,
          ),
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
        _TestRoot(
          child: Renderer(
            response: '\$count = 0\nroot = Text(text: "")',
            library: _testLibrary(),
            initialState: const <String, Object?>{r'$count': 42},
            onStateUpdate: snapshots.add,
          ),
        ),
      );

      // The store's initialize semantics treat persisted (initialState)
      // as winning over defaults.
      // Trigger a write so onStateUpdate fires once, capturing the
      // resulting snapshot.
      // We do this via a synthetic Counter action on the next pump.
      await tester.pumpWidget(
        _TestRoot(
          child: Renderer(
            response: '''\$count = 0
root = Counter(value: \$count, onIncrement: [@Set(\$count, \$count + 1)])
''',
            library: _testLibrary(),
            initialState: const <String, Object?>{r'$count': 42},
            onStateUpdate: snapshots.add,
          ),
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
          _TestRoot(
            child: Renderer(
              response: 'root = Mystery()',
              library: _testLibrary(),
              onError: errors.addAll,
            ),
          ),
        );
        await tester.pump();

        expect(errors, isNotEmpty);
        expect(errors.first, isA<UnknownComponentError>());
      },
    );

    testWidgets(
      'reference cycle surfaces as CyclicStateError, not stack overflow',
      (tester) async {
        final errors = <OpenUIError>[];
        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response: '\nroot = a\na = b\nb = a\n',
              library: _testLibrary(),
              onError: errors.addAll,
            ),
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
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(),
              onContinueConversation: messages.add,
            ),
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
        // $flag defaults to 0; @Set targets 999. A halted plan leaves
        // $flag at 0; a passing-by-coincidence value cannot arise —
        // @Set is the only writer.
        final tools = <Tool>[
          _StubTool(
            name: 'fail',
            description: 'failing mutation tool',
            handler: (args) async => throw StateError('mut-fail'),
          ),
        ];
        const program = '''refresh = Mutation(name: "fail")
\$flag = 0
root = Counter(value: \$flag, onIncrement: [@Run(refresh), @Set(\$flag, 999)])
''';
        final stateUpdates = <Map<String, Object?>>[];
        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(tools: tools),
              onStateUpdate: stateUpdates.add,
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
        await tester.pumpAndSettle();

        // @Set after the failed @Run did not run — $flag is still 0.
        final lastFlag = stateUpdates.isEmpty ? 0 : stateUpdates.last[r'$flag'];
        expect(lastFlag, 0);
      },
    );

    testWidgets(
      '@Run on a failing mutation surfaces a single OpenUIError through '
      'onError',
      (tester) async {
        final tools = <Tool>[
          _StubTool(
            name: 'fail',
            description: 'failing mutation tool',
            handler: (args) async => throw StateError('boom'),
          ),
        ];
        const program = '''refresh = Mutation(name: "fail")
root = Counter(value: 0, onIncrement: [@Run(refresh)])
''';
        var lastSnapshot = const <OpenUIError>[];
        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(tools: tools),
              onError: (errors) {
                lastSnapshot = errors;
              },
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
        await tester.pumpAndSettle();

        // The renderer's onError snapshot accumulates active errors,
        // so a regression that double-reports the mutation failure
        // would land two entries here, not one.
        final mutationErrors = lastSnapshot.whereType<EvaluationError>();
        expect(mutationErrors, hasLength(1));
      },
    );

    testWidgets(
      'last-good cache covers ticks where the parser produces no root',
      (tester) async {
        // The cache only activates when the new parse produces a null
        // root mid-stream — primarily before the LLM emits its first
        // `root = ...` token. Drive that case with a `$state` decl
        // before the root statement appears.
        Widget tree(String response) => _TestRoot(
          child: Renderer(
            response: response,
            library: _testLibrary(),
            isStreaming: true,
          ),
        );

        // 1. A complete program → cache retains this root.
        await tester.pumpWidget(
          tree('root = Text(text: "kept")\n'),
        );
        await tester.pumpAndSettle();
        expect(find.text('kept'), findsOneWidget);

        // 2. The stream "restarts" but starts with a $state decl —
        //    the buffer is now a non-prefix of the previous one, so
        //    the cache resets. The first chunk has no root, so the
        //    body collapses to an empty placeholder.
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
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(),
            ),
          ),
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
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(),
            ),
          ),
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
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(),
            ),
          ),
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
        // Column.children is an array prop; the @Each call's template
        // is a CompCall (Text), so the prop-branch in _resolvePropValue
        // must pre-render each item with the loop var in scope.
        const program = '''items = ["one", "two"]
root = Column(children: @Each(items, "row", Text(text: row)))
''';
        await tester.pumpWidget(
          _TestRoot(
            child: Renderer(
              response: program,
              library: _testLibrary(),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('one'), findsOneWidget);
        expect(find.text('two'), findsOneWidget);
      },
    );

    testWidgets(
      'cache resets when a new response is unrelated to the previous',
      (tester) async {
        Widget tree(String response, {bool streaming = true}) => _TestRoot(
          child: Renderer(
            response: response,
            library: _testLibrary(),
            isStreaming: streaming,
          ),
        );

        await tester.pumpWidget(tree('root = Text(text: "alpha")\n'));
        await tester.pumpAndSettle();
        expect(find.text('alpha'), findsOneWidget);

        // A shorter, non-prefix response — this is a fresh stream.
        // The cache from the alpha response must be discarded so a
        // null root produces an empty body, not the stale alpha tree.
        await tester.pumpWidget(tree(''));
        await tester.pumpAndSettle();
        expect(find.text('alpha'), findsNothing);
      },
    );
  });
}

class _StubTool extends Tool {
  _StubTool({
    required super.name,
    required super.description,
    required this.handler,
  });

  final Future<ToolResult> Function(Map<String, Object?> args) handler;

  @override
  Future<ToolResult> callTool(Map<String, Object?> args) => handler(args);
}
