// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';

class _StubTool extends Tool {
  _StubTool({
    required super.name,
    required super.description,
    required this.handler,
  });

  final Future<ToolResult> Function(Map<String, Object?> args) handler;
  Map<String, Object?>? lastArgs;
  int calls = 0;

  @override
  Future<ToolResult> callTool(Map<String, Object?> args) {
    calls++;
    lastArgs = args;
    return handler(args);
  }
}

void main() {
  group('QueryManager', () {
    Argument nameArg(String value) => Argument(
      name: 'name',
      value: Literal(value, offset: 0),
      offset: 0,
    );

    Argument argsArg(List<ObjectEntry> entries) => Argument(
      name: 'args',
      value: ObjectLit(entries, offset: 0),
      offset: 0,
    );

    test(
      'ensureFired fires once and caches ToolResult for statement id',
      () async {
        final tool = _StubTool(
          name: 'stub',
          description: 'stub',
          handler: (args) async => ToolResult('value-${args['tag']}'),
        );
        final manager = QueryManager(
          library: Library<Widget>(components: const [], tools: [tool]),
        );
        addTearDown(manager.dispose);

        final args = <Argument>[
          nameArg('stub'),
          argsArg(const [
            ObjectEntry('tag', Literal('q1', offset: 0), offset: 0),
          ]),
        ];
        manager
          ..ensureFired('q1', args)
          ..ensureFired('q1', args);

        expect(manager.entryFor('q1').loading, isTrue);
        await Future<void>.delayed(Duration.zero);

        expect(tool.calls, 1);
        final entry = manager.entryFor('q1');
        expect(entry.loading, isFalse);
        expect(entry.error, isNull);
        expect(entry.value, isA<ToolResult>());
        expect((entry.value! as ToolResult).result, 'value-q1');
      },
    );

    test('invalidate drops cached entry and re-fires', () async {
      final tool = _StubTool(
        name: 'stub',
        description: 'stub',
        handler: (args) async => ToolResult('call-${args['n']}'),
      );
      final manager = QueryManager(
        library: Library<Widget>(components: const [], tools: [tool]),
      );
      addTearDown(manager.dispose);

      final firstArgs = <Argument>[
        nameArg('stub'),
        argsArg(const [ObjectEntry('n', Literal(1, offset: 0), offset: 0)]),
      ];
      manager.ensureFired('q', firstArgs);
      await Future<void>.delayed(Duration.zero);
      expect((manager.entryFor('q').value! as ToolResult).result, 'call-1');

      final secondArgs = <Argument>[
        nameArg('stub'),
        argsArg(const [ObjectEntry('n', Literal(2, offset: 0), offset: 0)]),
      ];
      manager.invalidate('q', secondArgs);
      await Future<void>.delayed(Duration.zero);
      expect(tool.calls, 2);
      expect((manager.entryFor('q').value! as ToolResult).result, 'call-2');
    });

    test(
      'extracts name and args from Query AST and passes literal map',
      () async {
        final tool = _StubTool(
          name: 'weather',
          description: 'Weather lookup',
          handler: (args) async => const ToolResult('ok'),
        );
        final manager = QueryManager(
          library: Library<Widget>(components: const [], tools: [tool]),
        );
        addTearDown(manager.dispose);

        manager.ensureFired('q', <Argument>[
          nameArg('weather'),
          argsArg([
            const ObjectEntry('city', Literal('Berlin', offset: 0), offset: 0),
            const ObjectEntry('count', Literal(2, offset: 0), offset: 0),
            const ObjectEntry('none', NullLiteral(offset: 0), offset: 0),
            ObjectEntry(
              'complex',
              ArrayLit(const [Literal(1, offset: 0)], offset: 0),
              offset: 0,
            ),
          ]),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(tool.lastArgs, <String, Object?>{
          'city': 'Berlin',
          'count': 2,
          'none': null,
          'complex': null,
        });
      },
    );

    test('missing required string name captures EvaluationError', () async {
      final tool = _StubTool(
        name: 'stub',
        description: 'stub',
        handler: (args) async => const ToolResult('unused'),
      );
      final manager = QueryManager(
        library: Library<Widget>(components: const [], tools: [tool]),
      );
      addTearDown(manager.dispose);

      manager.ensureFired(
        'q',
        <Argument>[
          const Argument(
            name: 'name',
            value: Literal(42, offset: 0),
            offset: 0,
          ),
        ],
      );
      await Future<void>.delayed(Duration.zero);

      final error = manager.entryFor('q').error;
      expect(error, isA<EvaluationError>());
      expect(error!.message, contains('missing required string arg "name"'));
    });

    test('snapshotValues returns cached entry values', () async {
      final tool = _StubTool(
        name: 'stub',
        description: 'stub',
        handler: (args) async => ToolResult(args['id']),
      );
      final manager = QueryManager(
        library: Library<Widget>(components: const [], tools: [tool]),
      );
      addTearDown(manager.dispose);

      manager
        ..ensureFired(
          'q1',
          <Argument>[
            nameArg('stub'),
            argsArg(const [
              ObjectEntry('id', Literal('a', offset: 0), offset: 0),
            ]),
          ],
        )
        ..ensureFired(
          'q2',
          <Argument>[
            nameArg('stub'),
            argsArg(const [
              ObjectEntry('id', Literal('b', offset: 0), offset: 0),
            ]),
          ],
        );
      await Future<void>.delayed(Duration.zero);

      final snapshot = manager.snapshotValues();
      expect(snapshot.keys.toSet(), {'q1', 'q2'});
      expect((snapshot['q1']! as ToolResult).result, 'a');
      expect((snapshot['q2']! as ToolResult).result, 'b');
    });

    test('errors() yields collected OpenUIError values', () async {
      final manager = QueryManager(
        library: const Library<Widget>(components: [], tools: []),
      );
      addTearDown(manager.dispose);

      manager
        ..ensureFired('q1', const <Argument>[])
        ..ensureFired('q2', const <Argument>[]);
      await Future<void>.delayed(Duration.zero);

      expect(manager.errors(), hasLength(2));
      expect(manager.errors().every((e) => e is EvaluationError), isTrue);
    });

    test('onChange fires at loading and completion transitions', () async {
      final tool = _StubTool(
        name: 'stub',
        description: 'stub',
        handler: (args) async => const ToolResult('done'),
      );
      final manager = QueryManager(
        library: Library<Widget>(components: const [], tools: [tool]),
      );
      addTearDown(manager.dispose);

      var notifications = 0;
      manager
        ..onChange = () {
          notifications++;
        }
        ..ensureFired('q', <Argument>[nameArg('stub')]);
      expect(notifications, 1, reason: 'loading transition');

      await Future<void>.delayed(Duration.zero);
      expect(notifications, 2, reason: 'resolution transition');
    });

    test('dispose suppresses post-completion notifications', () async {
      final completer = Completer<ToolResult>();
      final tool = _StubTool(
        name: 'stub',
        description: 'stub',
        handler: (args) => completer.future,
      );
      final manager = QueryManager(
        library: Library<Widget>(components: const [], tools: [tool]),
      );

      var notifications = 0;
      manager
        ..onChange = () {
          notifications++;
        }
        ..ensureFired('q', <Argument>[nameArg('stub')]);
      expect(notifications, 1);

      manager.dispose();
      completer.complete(const ToolResult('done'));
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
    });

    group('fireMutation', () {
      test(
        'returns ToolResult and does not cache successful mutation value',
        () async {
          final tool = _StubTool(
            name: 'mut',
            description: 'mutation tool',
            handler: (args) async => const ToolResult('ok-mut'),
          );
          final manager = QueryManager(
            library: Library<Widget>(components: const [], tools: [tool]),
          );
          addTearDown(manager.dispose);

          final result = await manager.fireMutation('m', <Argument>[
            nameArg('mut'),
          ]);
          expect(result, isA<ToolResult>());
          expect((result! as ToolResult).result, 'ok-mut');
          expect(manager.entryFor('m').value, isNull);
          expect(manager.entryFor('m').error, isNull);
        },
      );

      test(
        'writes EvaluationError on non-OpenUI failures and rethrows',
        () async {
          final tool = _StubTool(
            name: 'mut',
            description: 'mutation tool',
            handler: (args) async => throw StateError('mut-fail'),
          );
          final manager = QueryManager(
            library: Library<Widget>(components: const [], tools: [tool]),
          );
          addTearDown(manager.dispose);

          await expectLater(
            manager.fireMutation('m', <Argument>[nameArg('mut')]),
            throwsStateError,
          );
          expect(manager.entryFor('m').error, isA<EvaluationError>());
        },
      );

      test(
        'preserves thrown OpenUIError subtype on mutation failure',
        () async {
          final tool = _StubTool(
            name: 'mut',
            description: 'mutation tool',
            handler: (args) async =>
                throw const McpToolError(message: 'denied'),
          );
          final manager = QueryManager(
            library: Library<Widget>(components: const [], tools: [tool]),
          );
          addTearDown(manager.dispose);

          await expectLater(
            manager.fireMutation('m', <Argument>[nameArg('mut')]),
            throwsA(isA<McpToolError>()),
          );
          expect(manager.entryFor('m').error, isA<McpToolError>());
        },
      );
    });
  });
}
