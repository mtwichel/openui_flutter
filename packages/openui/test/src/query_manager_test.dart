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

  Future<ToolResult> callTool(Map<String, Object?> args) {
    calls++;
    lastArgs = args;
    return handler(args);
  }
}

RenderLibrary<Widget> _lib(_StubTool tool) => RenderLibrary<Widget>(
      spec: Library(components: const [], tools: [tool]),
      renderers: const {},
      toolHandlers: {tool.name: tool.callTool},
    );

const _emptyLib = RenderLibrary<Widget>(
  spec: Library(components: [], tools: []),
  renderers: {},
  toolHandlers: {},
);

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
      final tool = _StubTool(
        name: 'stub',
        description: 'stub',
        handler: (args) async => const ToolResult('ok'),
      );
      final store = Store();
      final errors = <OpenUIError>[];
      final manager = QueryManager(
        library: _lib(tool),
        store: store,
        onError: errors.add,
      );
      addTearDown(manager.dispose);

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
        final tool = _StubTool(
          name: 'stub',
          description: 'stub',
          handler: (_) => completer.future,
        );
        final store = Store();
        final manager = QueryManager(
          library: _lib(tool),
          store: store,
          onError: (_) {},
        );
        addTearDown(manager.dispose);

        final decl = _decl();
        manager
          ..ensureFired(decl, _ctx(store))
          ..ensureFired(decl, _ctx(store));

        // Tool only called once even though the future is still pending.
        expect(tool.calls, 1);
        completer.complete(const ToolResult('done'));
        await Future<void>.delayed(Duration.zero);
      },
    );

    test('different evaluated args re-fire', () async {
      var n = 0;
      final tool = _StubTool(
        name: 'stub',
        description: 'stub',
        handler: (args) async => ToolResult('call-${++n}-${args['category']}'),
      );
      final store = Store();
      final manager = QueryManager(
        library: _lib(tool),
        store: store,
        onError: (_) {},
      );
      addTearDown(manager.dispose);

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
      final manager = QueryManager(
        library: _emptyLib,
        store: store,
        onError: errors.add,
      );
      addTearDown(manager.dispose);

      manager.ensureFired(_decl(toolName: 'missing'), _ctx(store));

      expect(errors, hasLength(1));
      expect(errors.single, isA<EvaluationError>());
      expect(errors.single.message, contains('Unknown tool: missing'));
      expect(store.get(r'$q'), 'prior');
    });

    test(
      'tool future failure routes to onError, store retains prior value',
      () async {
        final store = Store()..set(r'$q', 'prior');
        final errors = <OpenUIError>[];
        final tool = _StubTool(
          name: 'stub',
          description: 'stub',
          handler: (_) async => throw const McpToolError(message: 'boom'),
        );
        final manager = QueryManager(
          library: _lib(tool),
          store: store,
          onError: errors.add,
        );
        addTearDown(manager.dispose);

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
        final tool = _StubTool(
          name: 'stub',
          description: 'stub',
          handler: (_) async =>
              const ToolResult('permission denied', isError: true),
        );
        final manager = QueryManager(
          library: _lib(tool),
          store: store,
          onError: errors.add,
        );
        addTearDown(manager.dispose);

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
      final tool = _StubTool(
        name: 'stub',
        description: 'stub',
        handler: (_) async => throw StateError('nope'),
      );
      final manager = QueryManager(
        library: _lib(tool),
        store: store,
        onError: errors.add,
      );
      addTearDown(manager.dispose);

      manager.ensureFired(_decl(), _ctx(store));
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, isA<EvaluationError>());
      expect(errors.single.statementId, r'$q');
    });
  });

  group('QueryManager.invalidate', () {
    test('clears the fingerprint and re-fires with fresh args', () async {
      var n = 0;
      final tool = _StubTool(
        name: 'stub',
        description: 'stub',
        handler: (args) async => ToolResult('call-${++n}'),
      );
      final store = Store();
      final manager = QueryManager(
        library: _lib(tool),
        store: store,
        onError: (_) {},
      );
      addTearDown(manager.dispose);

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
        final tool = _StubTool(
          name: 'mut',
          description: 'mut',
          handler: (_) async => const ToolResult('ok'),
        );
        final store = Store();
        final manager = QueryManager(
          library: _lib(tool),
          store: store,
          onError: (_) {},
        );
        addTearDown(manager.dispose);

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
      final tool = _StubTool(
        name: 'mut',
        description: 'mut',
        handler: (_) async => throw const McpToolError(message: 'down'),
      );
      final store = Store();
      final errors = <OpenUIError>[];
      final manager = QueryManager(
        library: _lib(tool),
        store: store,
        onError: errors.add,
      );
      addTearDown(manager.dispose);

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
  });

  group('QueryManager.dispose', () {
    test('subsequent ensureFired and invalidate are no-ops', () {
      final tool = _StubTool(
        name: 'stub',
        description: 'stub',
        handler: (_) async => const ToolResult('ok'),
      );
      QueryManager(
          library: _lib(tool),
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
