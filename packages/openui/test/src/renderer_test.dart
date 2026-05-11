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

Library<Widget> _testLibrary() {
  return Library<Widget>(<Component<Widget>>[
    defineComponent<Widget>(
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
    defineComponent<Widget>(
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
    defineComponent<Widget>(
      name: 'Counter',
      schema: Schema.fromMap(const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'value': <String, Object?>{'type': 'integer'},
          'onIncrement': <String, Object?>{'type': 'object'},
        },
      }),
      render: (ctx, props, renderNode, id) {
        final value = props['value'] as int? ?? 0;
        final onTap = props['onIncrement'] as void Function()?;
        return GestureDetector(
          onTap: onTap,
          child: Text('count=$value'),
        );
      },
    ),
    defineComponent<Widget>(
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
            final controller = cache.controllerFor(
              formName: 'form',
              fieldName: field,
              initialValue: binding is ReactiveAssign
                  ? (binding.value as String? ?? '')
                  : '',
            );
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
    defineComponent<Widget>(
      name: 'Throwing',
      schema: Schema.fromMap(const <String, Object?>{'type': 'object'}),
      render: (ctx, props, renderNode, id) {
        throw StateError('boom from $id');
      },
    ),
  ]);
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

    testWidgets('action prop dispatches Set step against the store', (
      tester,
    ) async {
      final events = <ActionEvent>[];
      const program = '''\$count = 0
root = Counter(value: \$count, onIncrement: @Set(\$count, \$count + 1))
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
      expect(events.length, 1);
      expect(events.first.plan.steps.first, isA<SetStep>());
    });

    testWidgets(
      'Reset step writes the declared default back to the store',
      (tester) async {
        const program = '''\$count = 7
root = Column(children: [
  Counter(value: \$count, onIncrement: @Set(\$count, \$count - 1)),
  Counter(value: 0, onIncrement: @Reset(\$count))
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
      const program = '''data = Query(name: "lookup")
refresh = Mutation(name: "refresh")
root = Counter(value: \$tick, onIncrement: @Run(refresh))
''';
      await tester.pumpWidget(
        _TestRoot(
          child: Renderer(
            response: program,
            library: _testLibrary(),
            queryLoader: (id, args) async => ++calls,
          ),
        ),
      );

      // Only `data` (a Query) auto-fires; `refresh` (a Mutation) waits
      // for its @Run.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(calls, 1);

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      await tester.pumpAndSettle();
      // `refresh` invalidated and fired.
      expect(calls, 2);
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
root = Counter(value: \$count, onIncrement: @Set(\$count, \$count + 1))
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
      '@ToAssistant emits an ActionEvent with ContinueConversationStep',
      (tester) async {
        final events = <ActionEvent>[];
        const program =
            '''root = Counter(value: 0, onIncrement: @ToAssistant("retry"))
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

        await tester.tap(find.byType(GestureDetector));
        await tester.pump();

        expect(events, isNotEmpty);
        expect(events.first.plan.steps.first, isA<ContinueConversationStep>());
      },
    );

    testWidgets('@OpenUrl emits an ActionEvent with OpenUrlStep', (
      tester,
    ) async {
      final events = <ActionEvent>[];
      const program =
          '''root = Counter(value: 0, onIncrement: @OpenUrl("https://example.com"))
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

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(events, isNotEmpty);
      expect(events.first.plan.steps.first, isA<OpenUrlStep>());
    });

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
