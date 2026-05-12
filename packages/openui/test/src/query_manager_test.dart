// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';

class _StubToolProvider implements ToolProvider {
  _StubToolProvider(this.handler);

  final Future<Object?> Function(String name, Map<String, Object?> args)
  handler;

  int callCount = 0;

  @override
  Future<Object?> callTool(String name, Map<String, Object?> args) {
    callCount++;
    return handler(name, args);
  }
}

void main() {
  group('QueryManager', () {
    test('rejects construction without a transport', () {
      expect(QueryManager.new, throwsA(isA<AssertionError>()));
    });

    test(
      'ensureFired triggers the loader once and caches the value',
      () async {
        var calls = 0;
        final manager = QueryManager(
          loader: (id, args) async {
            calls++;
            return 'value-$id';
          },
        );
        addTearDown(manager.dispose);

        manager
          ..ensureFired('q1', const [])
          ..ensureFired('q1', const []);
        expect(manager.entryFor('q1').loading, isTrue);

        await Future<void>.delayed(Duration.zero);
        expect(calls, 1);
        expect(manager.entryFor('q1').value, 'value-q1');
        expect(manager.entryFor('q1').loading, isFalse);

        // A second ensureFired after resolution is still a no-op.
        manager.ensureFired('q1', const []);
        await Future<void>.delayed(Duration.zero);
        expect(calls, 1);
      },
    );

    test('invalidate re-fires the query', () async {
      var calls = 0;
      final manager = QueryManager(
        loader: (id, args) async => ++calls,
      );
      addTearDown(manager.dispose);

      manager.ensureFired('q', const []);
      await Future<void>.delayed(Duration.zero);
      expect(manager.entryFor('q').value, 1);

      manager.invalidate('q', const []);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(manager.entryFor('q').value, 2);
    });

    test('captures error and surfaces it in entryFor', () async {
      final manager = QueryManager(
        loader: (id, args) async => throw StateError('boom'),
      );
      addTearDown(manager.dispose);

      manager.ensureFired('q', const []);
      await Future<void>.delayed(Duration.zero);

      final entry = manager.entryFor('q');
      expect(entry.error, isA<EvaluationError>());
      expect(entry.value, isNull);
    });

    test('preserves OpenUIError subclass when thrown', () async {
      final manager = QueryManager(
        loader: (id, args) async => throw const McpToolError(message: 'denied'),
      );
      addTearDown(manager.dispose);

      manager.ensureFired('q', const []);
      await Future<void>.delayed(Duration.zero);

      expect(manager.entryFor('q').error, isA<McpToolError>());
    });

    test(
      'extracts name and args from a Query AST when using ToolProvider',
      () async {
        final tool = _StubToolProvider(
          (name, args) async => <String, Object?>{'name': name, 'args': args},
        );
        final manager = QueryManager(toolProvider: tool);
        addTearDown(manager.dispose);

        final args = <Argument>[
          const Argument(
            name: 'name',
            value: Literal('weather', offset: 0),
            offset: 0,
          ),
          Argument(
            name: 'args',
            value: ObjectLit(
              const <ObjectEntry>[
                ObjectEntry('city', Literal('Berlin', offset: 0), offset: 0),
              ],
              offset: 0,
            ),
            offset: 0,
          ),
        ];

        manager.ensureFired('q', args);
        await Future<void>.delayed(Duration.zero);

        expect(tool.callCount, 1);
        expect(
          manager.entryFor('q').value,
          <String, Object?>{
            'name': 'weather',
            'args': <String, Object?>{'city': 'Berlin'},
          },
        );
      },
    );

    test('errors when Query is missing required name arg', () async {
      final tool = _StubToolProvider((name, args) async => 'unused');
      final manager = QueryManager(toolProvider: tool);
      addTearDown(manager.dispose);

      manager.ensureFired('q', const <Argument>[]);
      await Future<void>.delayed(Duration.zero);

      expect(tool.callCount, 0);
      expect(manager.entryFor('q').error, isA<EvaluationError>());
    });

    test('snapshotValues returns the cached values only', () async {
      final manager = QueryManager(
        loader: (id, args) async => 'value-$id',
      );
      addTearDown(manager.dispose);

      manager
        ..ensureFired('q1', const [])
        ..ensureFired('q2', const []);
      await Future<void>.delayed(Duration.zero);

      final snapshot = manager.snapshotValues();
      expect(snapshot, <String, Object?>{'q1': 'value-q1', 'q2': 'value-q2'});
    });

    test('errors() yields every captured OpenUIError', () async {
      final manager = QueryManager(
        loader: (id, args) async => throw StateError(id),
      );
      addTearDown(manager.dispose);

      manager
        ..ensureFired('q1', const [])
        ..ensureFired('q2', const []);
      await Future<void>.delayed(Duration.zero);

      expect(manager.errors().length, 2);
    });

    test(
      'onChange fires on loading start and on resolution',
      () async {
        final manager = QueryManager(
          loader: (id, args) async => 'value',
        );
        addTearDown(manager.dispose);

        var notifications = 0;
        manager
          ..onChange = (() => notifications++)
          ..ensureFired('q', const []);
        expect(notifications, 1, reason: 'loading start');

        await Future<void>.delayed(Duration.zero);
        expect(notifications, 2, reason: 'resolution');
      },
    );

    test('onChange setter replaces the previous listener', () async {
      final manager = QueryManager(loader: (id, args) async => 'value');
      addTearDown(manager.dispose);

      var firstCalls = 0;
      var secondCalls = 0;
      manager
        ..onChange = (() => firstCalls++)
        ..onChange = (() => secondCalls++)
        ..ensureFired('q', const []);
      await Future<void>.delayed(Duration.zero);

      expect(firstCalls, 0, reason: 'first listener replaced');
      expect(secondCalls, greaterThanOrEqualTo(1));
    });

    group('fireMutation', () {
      test('returns the resolved value and does not cache it', () async {
        final manager = QueryManager(
          loader: (id, args) async => 'ok-$id',
        );
        addTearDown(manager.dispose);

        final result = await manager.fireMutation('m', const []);
        expect(result, 'ok-m');
        // Mutations are not cached — the entry has no value.
        expect(manager.entryFor('m').value, isNull);
      });

      test('populates the entry error and rethrows on failure', () async {
        final manager = QueryManager(
          loader: (id, args) async => throw StateError('mut-fail'),
        );
        addTearDown(manager.dispose);

        await expectLater(
          manager.fireMutation('m', const []),
          throwsStateError,
        );
        expect(manager.entryFor('m').error, isA<EvaluationError>());
      });

      test(
        'thrown OpenUIError preserves its subclass through errors()',
        () async {
          final manager = QueryManager(
            loader: (id, args) async => throw const McpToolError(message: 'no'),
          );
          addTearDown(manager.dispose);

          await expectLater(
            manager.fireMutation('m', const []),
            throwsA(isA<McpToolError>()),
          );
          expect(
            manager.errors().whereType<McpToolError>(),
            isNotEmpty,
          );
        },
      );

      test('notifies onChange exactly once on failure', () async {
        var notifications = 0;
        final manager = QueryManager(
          loader: (id, args) async => throw StateError('boom'),
        )..onChange = () => notifications++;
        addTearDown(manager.dispose);

        await expectLater(
          manager.fireMutation('m', const []),
          throwsStateError,
        );
        expect(notifications, 1);
      });
    });

    test('dispose suppresses post-completion notifications', () async {
      var notifications = 0;
      final completer = Completer<Object?>();
      final manager = QueryManager(loader: (id, args) => completer.future)
        ..onChange = (() => notifications++)
        ..ensureFired('q', const []);
      expect(notifications, 1);

      manager.dispose();
      completer.complete('done');
      await Future<void>.delayed(Duration.zero);
      expect(
        notifications,
        1,
        reason: 'no further notifications after dispose',
      );
    });
  });
}
