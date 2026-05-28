// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: cascade_invocations, experimental_member_use

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openui/openui.dart';
import 'package:openui/src/query_manager.dart';
import 'package:openui_core/openui_core.dart';

import '../helpers/wiring.dart';

class _ToolTracker {
  _ToolTracker({
    required String name,
    required String description,
    required Future<ToolResult> Function(Map<String, Object?> args) handler,
  }) {
    spec = StubToolSpec(
      name: name,
      description: description,
      execute: (args) async {
        calls++;
        lastArgs = args;
        return handler(args);
      },
    );
  }

  late final StubToolSpec spec;
  int calls = 0;
  Map<String, Object?>? lastArgs;

  LibraryDefinition get library => LibraryDefinition(tools: [spec.definition]);

  ToolRegistry get toolRegistry => ToolRegistry(
    executors: {spec.definition.name: spec.execute},
  );
}

QueryManager _manager({
  required LibraryDefinition library,
  required ToolRegistry toolRegistry,
  required void Function(OpenUIError) onError,
}) {
  final manager = QueryManager(
    library: library,
    toolRegistry: toolRegistry,
    onError: onError,
  );
  addTearDown(manager.dispose);
  return manager;
}

QueryNode _node({
  String statementId = 'data',
  String toolName = 'stub',
  Object? args = const <String, Object?>{},
  Object? defaults = const <String, Object?>{'rows': <Object?>[]},
  Object? deps,
  double? refreshInterval,
  bool complete = true,
}) => QueryNode(
  statementId: statementId,
  toolName: toolName,
  args: args,
  defaults: defaults,
  deps: deps,
  refreshInterval: refreshInterval,
  complete: complete,
);

void main() {
  group('QueryManager.evaluateQueries', () {
    test('fires once per cache key and returns defaults then result', () async {
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (args) async => const ToolResult({
          'rows': [1],
        }),
      );
      final errors = <OpenUIError>[];
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        onError: errors.add,
      );

      final node = _node(defaults: const {'rows': <Object?>[]});
      manager.evaluateQueries([node]);
      expect(manager.getResult('data'), node.defaults);

      manager.evaluateQueries([node]);
      await Future<void>.delayed(Duration.zero);

      expect(tool.calls, 1);
      expect(manager.getResult('data'), const {
        'rows': [1],
      });
      expect(errors, isEmpty);
    });

    test('different args produce a new fetch', () async {
      var n = 0;
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (args) async => ToolResult('call-${++n}-${args['category']}'),
      );
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        onError: (_) {},
      );

      manager.evaluateQueries([
        _node(args: const {'category': 'shoes'}),
      ]);
      await Future<void>.delayed(Duration.zero);
      manager.evaluateQueries([
        _node(args: const {'category': 'hats'}),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(tool.calls, 2);
      expect(manager.getResult('data'), 'call-2-hats');
    });

    test('unknown tool routes to onError, getResult stays at defaults', () {
      final errors = <OpenUIError>[];
      final manager = _manager(
        library: const LibraryDefinition(),
        toolRegistry: const ToolRegistry(executors: {}),
        onError: errors.add,
      );
      const defaults = {'rows': <Object?>[]};
      manager.evaluateQueries([
        _node(toolName: 'missing', defaults: defaults),
      ]);

      expect(errors, hasLength(1));
      expect(errors.single, isA<EvaluationError>());
      expect(manager.getResult('data'), defaults);
    });

    test('incomplete nodes are not fetched', () async {
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (_) async => const ToolResult('ok'),
      );
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        onError: (_) {},
      );

      const defaults = {'label': 'Loading'};
      manager.evaluateQueries([
        _node(complete: false, defaults: defaults),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(tool.calls, 0);
      expect(manager.getResult('data'), defaults);
    });
  });

  group('QueryManager.invalidate', () {
    test('re-fetches with fresh args', () async {
      var n = 0;
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (_) async => ToolResult('call-${++n}'),
      );
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        onError: (_) {},
      );

      manager.evaluateQueries([_node()]);
      await Future<void>.delayed(Duration.zero);
      manager.invalidate(['data']);
      await Future<void>.delayed(Duration.zero);

      expect(tool.calls, 2);
      expect(manager.getResult('data'), 'call-2');
    });
  });

  group('QueryManager.fireMutation', () {
    test('returns the resolved value', () async {
      final tool = _ToolTracker(
        name: 'mut',
        description: 'mut',
        handler: (_) async => const ToolResult('ok'),
      );
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        onError: (_) {},
      );

      const args = [
        Argument(
          name: 'name',
          value: Literal('mut', offset: 0),
          offset: 0,
        ),
      ];
      final result = await manager.fireMutation('del', args);
      expect((result! as ToolResult).result, 'ok');
    });
  });

  group('QueryManager lifecycle', () {
    test('subscribe notifies when fetch completes', () async {
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (_) async => const ToolResult('ok'),
      );
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        onError: (_) {},
      );
      var notifications = 0;
      manager.subscribe(() => notifications++);

      manager.evaluateQueries([_node()]);
      await Future<void>.delayed(Duration.zero);

      expect(notifications, greaterThan(0));
      expect(manager.getResult('data'), 'ok');
    });

    test('returns last-good from prev cache key while refetching', () async {
      final completer = Completer<ToolResult>();
      var n = 0;
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (args) async {
          n++;
          if (n == 1) return const ToolResult('shoes');
          return completer.future;
        },
      );
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        onError: (_) {},
      );

      manager.evaluateQueries([
        _node(args: const {'category': 'shoes'}),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(manager.getResult('data'), 'shoes');

      manager.evaluateQueries([
        _node(args: const {'category': 'hats'}),
      ]);
      expect(manager.getResult('data'), 'shoes');

      completer.complete(const ToolResult('hats'));
      await Future<void>.delayed(Duration.zero);
      expect(manager.getResult('data'), 'hats');
    });

    test(
      'discards stale fetch when cache key changes before completion',
      () async {
        final shoesDone = Completer<ToolResult>();
        final hatsDone = Completer<ToolResult>();
        final tool = _ToolTracker(
          name: 'stub',
          description: 'stub',
          handler: (args) async {
            if (args['category'] == 'shoes') return shoesDone.future;
            return hatsDone.future;
          },
        );
        final manager = _manager(
          library: tool.library,
          toolRegistry: tool.toolRegistry,
          onError: (_) {},
        );

        manager.evaluateQueries([
          _node(args: const {'category': 'shoes'}),
        ]);
        manager.evaluateQueries([
          _node(args: const {'category': 'hats'}),
        ]);
        shoesDone.complete(const ToolResult('stale-shoes'));
        await Future<void>.delayed(Duration.zero);

        expect(tool.calls, 2);
        expect(manager.getResult('data'), isNot('stale-shoes'));
        hatsDone.complete(const ToolResult('hats'));
        await Future<void>.delayed(Duration.zero);
        expect(manager.getResult('data'), 'hats');
      },
    );

    test('refresh interval fires periodic refetch', () async {
      var n = 0;
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (_) async => ToolResult('call-${++n}'),
      );
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        onError: (_) {},
      );

      manager.evaluateQueries([
        _node(refreshInterval: 0.05),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(tool.calls, greaterThanOrEqualTo(2));
    });

    test(
      'terminal tool error does not refetch on repeated evaluateQueries',
      () async {
        final tool = _ToolTracker(
          name: 'stub',
          description: 'stub',
          handler: (_) async => const ToolResult('boom', isError: true),
        );
        final errors = <OpenUIError>[];
        final manager = _manager(
          library: tool.library,
          toolRegistry: tool.toolRegistry,
          onError: errors.add,
        );
        final node = _node(defaults: const {'label': 'Loading'});

        manager.evaluateQueries([node]);
        await Future<void>.delayed(Duration.zero);
        manager.evaluateQueries([node]);
        await Future<void>.delayed(Duration.zero);

        expect(tool.calls, 1);
        expect(errors, isNotEmpty);
        expect(manager.getResult('data'), node.defaults);
      },
    );

    test('dispose suppresses post-dispose fetch completion', () async {
      final completer = Completer<ToolResult>();
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (_) async => completer.future,
      );
      final manager = QueryManager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        onError: (_) {},
      );
      manager.evaluateQueries([_node()]);
      await Future<void>.delayed(Duration.zero);
      expect(tool.calls, 1);
      manager.dispose();
      completer.complete(const ToolResult('late'));
      await Future<void>.delayed(Duration.zero);
      expect(tool.calls, 1);
      expect(manager.getResult('data'), isNot('late'));
    });
  });

  group('QueryManager.dispose', () {
    test('subsequent evaluateQueries are no-ops', () async {
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (_) async => const ToolResult('ok'),
      );
      final manager = QueryManager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        onError: (_) {},
      )..dispose();
      manager.evaluateQueries([_node()]);
      await Future<void>.delayed(Duration.zero);
      expect(tool.calls, 0);
    });
  });
}
