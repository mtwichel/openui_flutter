// Internal references to openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:openui/src/tool_registry.dart';
import 'package:openui_core/openui_core.dart';

/// Per-renderer gate that turns `@Query` declarations into one-shot
/// tool calls.
///
/// The manager has no result storage of its own. Results are written
/// straight to the [Store] via `store.set(decl.statementId, value.result)`,
/// which the renderer already subscribes to for reactive rebuilds.
/// Failures are routed to [_onError] (the renderer's existing error
/// sink). The only state the manager keeps is `_fired`: the most
/// recently dispatched evaluated-args map per `statementId`, which
/// gates re-fires.
///
/// `@Run($var)` invalidates a query by clearing its `_fired` entry and
/// calling [ensureFired] again. Args are re-evaluated at fire time
/// against the live [EvalContext], so a `@Set` ahead of `@Run` is
/// reflected in the new call.
///
/// Mutations keep their pre-`@Query` dispatcher path via [fireMutation]
/// — they're explicitly out of scope for this iteration.
///
/// Marked `@experimental` per D12.
@experimental
class QueryManager {
  /// Creates a [QueryManager].
  QueryManager({
    required this.library,
    required this.toolRegistry,
    required this.store,
    required void Function(OpenUIError) onError,
  }) : _onError = onError;

  /// Component and tool definitions used for dispatch lookup.
  final LibraryDefinition library;

  /// Tool executors keyed by tool name.
  final ToolRegistry toolRegistry;

  /// The reactive store that receives resolved query values.
  final Store store;

  final void Function(OpenUIError) _onError;

  final Map<String, Map<String, Object?>> _fired =
      <String, Map<String, Object?>>{};
  bool _disposed = false;

  /// Fires the query identified by [decl] when its
  /// `(statementId, evaluated-args)` fingerprint differs from the
  /// last fire. Subsequent calls with the same args are no-ops.
  ///
  /// Args are evaluated against [ctx] before the fingerprint compare,
  /// so a `@Run` that re-runs `ensureFired` after a `@Set` re-issues
  /// the call with fresh values.
  void ensureFired(QueryDecl decl, EvalContext ctx) {
    if (_disposed) return;
    final evaluatedArgs = <String, Object?>{
      for (final arg in decl.namedArgs)
        if (arg.name != null) arg.name!: evaluate(arg.value, ctx),
    };
    final last = _fired[decl.statementId];
    if (last != null && _mapEquals(last, evaluatedArgs)) return;
    // Set the in-flight gate synchronously so a second `ensureFired`
    // landing in the same micro-task tick short-circuits before
    // dispatching a duplicate tool call.
    _fired[decl.statementId] = evaluatedArgs;

    final toolDef = library.tool(decl.toolName);
    if (toolDef == null) {
      _onError(
        EvaluationError(
          message: 'Unknown tool: ${decl.toolName}',
          statementId: decl.statementId,
        ),
      );
      return;
    }
    final executor = toolRegistry[decl.toolName];
    if (executor == null) {
      _onError(
        MissingToolExecutorError(
          toolName: decl.toolName,
          statementId: decl.statementId,
        ),
      );
      return;
    }
    unawaited(
      executor(evaluatedArgs)
          .then((value) {
            if (_disposed) return;
            if (value.isError) {
              _onError(
                EvaluationError(
                  message: value.result?.toString() ?? 'Tool call failed',
                  statementId: decl.statementId,
                ),
              );
              return;
            }
            store.set(decl.statementId, value.result);
          })
          .catchError((Object error, StackTrace _) {
            if (_disposed) return;
            _onError(
              error is OpenUIError
                  ? error
                  : EvaluationError(
                      message: error.toString(),
                      statementId: decl.statementId,
                    ),
            );
          }),
    );
  }

  /// Drops the fingerprint for [decl] and re-runs [ensureFired]
  /// against [ctx]. Used by the renderer's `@Run($var)` path and by
  /// tests covering re-fire semantics.
  void invalidate(QueryDecl decl, EvalContext ctx) {
    if (_disposed) return;
    _fired.remove(decl.statementId);
    ensureFired(decl, ctx);
  }

  /// Fires a mutation by [statementId]. Returns the resolved value on
  /// success (mutations are not cached). Errors are wrapped as
  /// [OpenUIError] and rethrown so the dispatcher can halt the plan.
  Future<Object?> fireMutation(
    String statementId,
    List<Argument> args,
  ) async {
    if (_disposed) return null;
    try {
      return await _invokeMutation(statementId, args);
    } on Object catch (error) {
      if (_disposed) rethrow;
      final wrapped = error is OpenUIError
          ? error
          : EvaluationError(
              message: error.toString(),
              statementId: statementId,
            );
      _onError(wrapped);
      throw wrapped;
    }
  }

  /// Releases the manager. In-flight futures still complete; their
  /// results are discarded.
  void dispose() {
    _disposed = true;
  }

  Future<Object?> _invokeMutation(String statementId, List<Argument> args) {
    final toolName = _stringArg(args, 'name');
    if (toolName == null) {
      return Future<Object?>.error(
        EvaluationError(
          message: 'Mutation is missing required string arg "name"',
          statementId: statementId,
        ),
      );
    }
    final toolArgs = _mapArg(args, 'args') ?? const <String, Object?>{};
    final toolDef = library.tool(toolName);
    if (toolDef == null) {
      return Future<Object?>.error(
        ToolNotFoundError(toolName: toolName, statementId: statementId),
      );
    }
    final executor = toolRegistry[toolName];
    if (executor == null) {
      return Future<Object?>.error(
        MissingToolExecutorError(toolName: toolName, statementId: statementId),
      );
    }
    return executor(toolArgs);
  }
}

String? _stringArg(List<Argument> args, String name) {
  for (final a in args) {
    if (a.name != name) continue;
    final v = a.value;
    if (v is Literal && v.value is String) return v.value! as String;
    return null;
  }
  return null;
}

Map<String, Object?>? _mapArg(List<Argument> args, String name) {
  for (final a in args) {
    if (a.name != name) continue;
    final v = a.value;
    if (v is! ObjectLit) return null;
    final out = <String, Object?>{};
    for (final entry in v.entries) {
      out[entry.key] = _literalValue(entry.value);
    }
    return out;
  }
  return null;
}

Object? _literalValue(AstNode node) {
  if (node is Literal) return node.value;
  if (node is NullLiteral) return null;
  return null;
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
