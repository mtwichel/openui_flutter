// Tests cross openui_core experimental types — the entire openui_core
// surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use, cascade_invocations

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openui/openui.dart';
import 'package:openui_core/openui_core.dart';

import '../helpers/wiring.dart';

/// Wraps a [StubToolSpec] and tracks invocation counts and last args.
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
  required Store store,
  required void Function(OpenUIError) onError,
}) {
  final manager = QueryManager(
    library: library,
    toolRegistry: toolRegistry,
    store: store,
    onError: onError,
  );
  addTearDown(manager.dispose);
  return manager;
}

QueryDecl _decl({
  String statementId = r'$q',
  String toolName = 'stub',
  List<Argument> namedArgs = const <Argument>[],
}) => QueryDecl(
  statementId: statementId,
  toolName: toolName,
  namedArgs: namedArgs,
);

EvalContext _ctx(Store store) =>
    EvalContext(statements: const <Statement>[], store: store);

void main() {
  group('QueryManager.ensureFired', () {
    test('fires the tool once per (statementId, args) fingerprint', () async {
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (args) async => const ToolResult('ok'),
      );
      final store = Store();
      final errors = <OpenUIError>[];
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        store: store,
        onError: errors.add,
      );

      final decl = _decl();
      manager
        ..ensureFired(decl, _ctx(store))
        ..ensureFired(decl, _ctx(store));
      await Future<void>.delayed(Duration.zero);

      expect(tool.calls, 1);
      expect(store.get(r'$q'), 'ok');
      expect(errors, isEmpty);
    });

    test(
      'in-flight gate: two ensureFired in the same tick fire once',
      () async {
        final completer = Completer<ToolResult>();
        final tool = _ToolTracker(
          name: 'stub',
          description: 'stub',
          handler: (_) => completer.future,
        );
        final store = Store();
        final manager = _manager(
          library: tool.library,
          toolRegistry: tool.toolRegistry,
          store: store,
          onError: (_) {},
        );

        final decl = _decl();
        manager
          ..ensureFired(decl, _ctx(store))
          ..ensureFired(decl, _ctx(store));

        expect(tool.calls, 1);
        completer.complete(const ToolResult('done'));
        await Future<void>.delayed(Duration.zero);
      },
    );

    test('different evaluated args re-fire', () async {
      var n = 0;
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (args) async => ToolResult('call-${++n}-${args['category']}'),
      );
      final store = Store();
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        store: store,
        onError: (_) {},
      );

      QueryDecl declWith(String category) => _decl(
        namedArgs: [
          Argument(
            name: 'category',
            value: Literal(category, offset: 0),
            offset: 0,
          ),
        ],
      );

      manager.ensureFired(declWith('shoes'), _ctx(store));
      await Future<void>.delayed(Duration.zero);
      manager.ensureFired(declWith('hats'), _ctx(store));
      await Future<void>.delayed(Duration.zero);

      expect(tool.calls, 2);
      expect(store.get(r'$q'), 'call-2-hats');
    });

    test('unknown tool routes to onError, store untouched', () {
      final store = Store()..set(r'$q', 'prior');
      final errors = <OpenUIError>[];
      final manager = _manager(
        library: const LibraryDefinition(),
        toolRegistry: const ToolRegistry(executors: {}),
        store: store,
        onError: errors.add,
      );
      manager.ensureFired(_decl(toolName: 'missing'), _ctx(store));

      expect(errors, hasLength(1));
      expect(errors.single, isA<EvaluationError>());
      expect(errors.single.message, contains('Unknown tool: missing'));
      expect(store.get(r'$q'), 'prior');
    });

    test(
      'missing executor routes MissingToolExecutorError to onError',
      () async {
        final store = Store()..set(r'$q', 'prior');
        final errors = <OpenUIError>[];
        const library = LibraryDefinition(
          tools: [
            ToolDefinition(name: 'stub', description: 'stub'),
          ],
        );
        final manager = _manager(
          library: library,
          toolRegistry: const ToolRegistry(executors: {}),
          store: store,
          onError: errors.add,
        );
        manager.ensureFired(_decl(), _ctx(store));
        await Future<void>.delayed(Duration.zero);

        expect(errors, hasLength(1));
        expect(errors.single, isA<MissingToolExecutorError>());
        expect((errors.single as MissingToolExecutorError).toolName, 'stub');
        expect(store.get(r'$q'), 'prior');
      },
    );

    test(
      'tool future failure routes to onError, store retains prior value',
      () async {
        final store = Store()..set(r'$q', 'prior');
        final errors = <OpenUIError>[];
        final tool = _ToolTracker(
          name: 'stub',
          description: 'stub',
          handler: (_) async => throw const McpToolError(message: 'boom'),
        );
        final manager = _manager(
          library: tool.library,
          toolRegistry: tool.toolRegistry,
          store: store,
          onError: errors.add,
        );
        manager.ensureFired(_decl(), _ctx(store));
        await Future<void>.delayed(Duration.zero);

        expect(errors, hasLength(1));
        expect(errors.single, isA<McpToolError>());
        expect(store.get(r'$q'), 'prior');
      },
    );

    test(
      'ToolResult.isError routes to onError without writing store',
      () async {
        final store = Store()..set(r'$q', 'prior');
        final errors = <OpenUIError>[];
        final tool = _ToolTracker(
          name: 'stub',
          description: 'stub',
          handler: (_) async =>
              const ToolResult('permission denied', isError: true),
        );
        final manager = _manager(
          library: tool.library,
          toolRegistry: tool.toolRegistry,
          store: store,
          onError: errors.add,
        );
        manager.ensureFired(_decl(), _ctx(store));
        await Future<void>.delayed(Duration.zero);

        expect(errors, hasLength(1));
        expect(errors.single, isA<EvaluationError>());
        expect(store.get(r'$q'), 'prior');
      },
    );

    test('non-OpenUIError exceptions wrap as EvaluationError', () async {
      final store = Store();
      final errors = <OpenUIError>[];
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (_) async => throw StateError('nope'),
      );
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        store: store,
        onError: errors.add,
      );
      manager.ensureFired(_decl(), _ctx(store));
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, isA<EvaluationError>());
      expect(errors.single.statementId, r'$q');
    });
  });

  group('QueryManager.invalidate', () {
    test('clears the fingerprint and re-fires with fresh args', () async {
      var n = 0;
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (args) async => ToolResult('call-${++n}'),
      );
      final store = Store();
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        store: store,
        onError: (_) {},
      );
      manager.ensureFired(_decl(), _ctx(store));
      await Future<void>.delayed(Duration.zero);
      manager.invalidate(_decl(), _ctx(store));
      await Future<void>.delayed(Duration.zero);

      expect(tool.calls, 2);
      expect(store.get(r'$q'), 'call-2');
    });
  });

  group('QueryManager.fireMutation', () {
    test(
      'returns the resolved value and does not write to the store',
      () async {
        final tool = _ToolTracker(
          name: 'mut',
          description: 'mut',
          handler: (_) async => const ToolResult('ok'),
        );
        final store = Store();
        final manager = _manager(
          library: tool.library,
          toolRegistry: tool.toolRegistry,
          store: store,
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
        expect(store.get('del'), isNull);
      },
    );

    test('failures route through onError and rethrow', () async {
      final tool = _ToolTracker(
        name: 'mut',
        description: 'mut',
        handler: (_) async => throw const McpToolError(message: 'down'),
      );
      final store = Store();
      final errors = <OpenUIError>[];
      final manager = _manager(
        library: tool.library,
        toolRegistry: tool.toolRegistry,
        store: store,
        onError: errors.add,
      );

      const args = [
        Argument(
          name: 'name',
          value: Literal('mut', offset: 0),
          offset: 0,
        ),
      ];
      expect(
        () => manager.fireMutation('del', args),
        throwsA(isA<McpToolError>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(errors.single, isA<McpToolError>());
    });

    test(
      'missing executor routes MissingToolExecutorError through onError',
      () async {
        const library = LibraryDefinition(
          tools: [
            ToolDefinition(name: 'mut', description: 'mut'),
          ],
        );
        final store = Store();
        final errors = <OpenUIError>[];
        final manager = _manager(
          library: library,
          toolRegistry: const ToolRegistry(executors: {}),
          store: store,
          onError: errors.add,
        );

        const args = [
          Argument(
            name: 'name',
            value: Literal('mut', offset: 0),
            offset: 0,
          ),
        ];
        expect(
          () => manager.fireMutation('del', args),
          throwsA(isA<MissingToolExecutorError>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(errors.single, isA<MissingToolExecutorError>());
      },
    );
  });

  group('QueryManager.dispose', () {
    test('subsequent ensureFired and invalidate are no-ops', () {
      final tool = _ToolTracker(
        name: 'stub',
        description: 'stub',
        handler: (_) async => const ToolResult('ok'),
      );
      QueryManager(
          library: tool.library,
          toolRegistry: tool.toolRegistry,
          store: Store(),
          onError: (_) {},
        )
        ..dispose()
        ..ensureFired(_decl(), _ctx(Store()))
        ..invalidate(_decl(), _ctx(Store()));
      expect(tool.calls, 0);
    });
  });
}
