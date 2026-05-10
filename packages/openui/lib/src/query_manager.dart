// Internal references to openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:openui_core/openui_core.dart';

/// Test-friendly alternative to a [ToolProvider].
///
/// Receives the statement id and the raw arg list from the
/// `Query`/`Mutation` call and returns the resolved value. The
/// production path uses a [ToolProvider]; [QueryLoader] is the seam
/// tests and the example app use to inject canned results without a
/// running tool transport.
///
/// Marked `@experimental` per D12.
@experimental
typedef QueryLoader =
    Future<Object?> Function(
      String statementId,
      List<Argument> args,
    );

/// One entry in the query cache. The renderer reads [value] when it
/// builds an [EvalContext] and [loading] / [error] when it decides how
/// to apply the loading overlay or surface an error placeholder.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class QueryEntry {
  /// Creates a [QueryEntry].
  const QueryEntry({
    this.value,
    this.loading = false,
    this.error,
  });

  /// Most recent resolved value, or `null` while loading / on error.
  final Object? value;

  /// `true` while the underlying future is in flight.
  final bool loading;

  /// Most recent error from the underlying call, or `null` if the last
  /// call succeeded.
  final OpenUIError? error;
}

/// Per-renderer cache of in-flight and resolved query results.
///
/// Queries fire lazily: the renderer calls [ensureFired] for every
/// query the parser surfaces in a given pass, and the manager either
/// kicks off a new call (first time, or after [invalidate]) or returns
/// the cached entry. `@Run` invalidates one query by id; the next
/// `ensureFired` re-fires it.
///
/// The manager is owned by the renderer and disposed alongside it. A
/// single change listener is supported via [onChange]; the renderer
/// installs itself once and never expects multiple observers.
///
/// Marked `@experimental` per D12.
@experimental
class QueryManager {
  /// Creates a [QueryManager].
  QueryManager({this.toolProvider, this.loader})
    : assert(
        toolProvider != null || loader != null,
        'A QueryManager needs at least one of toolProvider or loader to '
        'execute queries; both are null.',
      );

  /// Tool transport for production. The manager extracts the `name`
  /// and `args` from the query's [Argument] list and calls
  /// [ToolProvider.callTool].
  final ToolProvider? toolProvider;

  /// Test seam — bypasses [toolProvider] and resolves directly.
  final QueryLoader? loader;

  final Map<String, QueryEntry> _entries = <String, QueryEntry>{};
  bool _disposed = false;

  /// The renderer's one-shot listener. Called every time an entry's
  /// loading / value / error transitions. Setting a new value replaces
  /// the previous listener; set to `null` to remove.
  void Function()? onChange;

  /// Returns the current entry for [statementId], or an empty entry
  /// when no call has fired.
  QueryEntry entryFor(String statementId) =>
      _entries[statementId] ?? const QueryEntry();

  /// Returns an immutable view of every cached value, suitable for
  /// passing as `EvalContext.queryResults`.
  Map<String, Object?> snapshotValues() {
    return <String, Object?>{
      for (final entry in _entries.entries) entry.key: entry.value.value,
    };
  }

  /// Returns the OpenUIErrors collected across every cached entry.
  Iterable<OpenUIError> errors() =>
      _entries.values.map((e) => e.error).whereType<OpenUIError>();

  /// Ensures the query identified by [statementId] has fired at least
  /// once. Subsequent calls during the same `(statementId, fingerprint)`
  /// cycle are no-ops; [invalidate] forces a re-fire.
  void ensureFired(String statementId, List<Argument> args) {
    if (_disposed) return;
    final existing = _entries[statementId];
    if (existing != null) return;
    _fire(statementId, args);
  }

  /// Drops the cached entry for [statementId] and re-fires the call.
  /// Used by `@Run`.
  void invalidate(String statementId, List<Argument> args) {
    if (_disposed) return;
    _entries.remove(statementId);
    _fire(statementId, args);
  }

  /// Releases listener and marks the manager unusable. In-flight
  /// futures still complete; their results are discarded.
  void dispose() {
    _disposed = true;
    onChange = null;
  }

  void _fire(String statementId, List<Argument> args) {
    _entries[statementId] = const QueryEntry(loading: true);
    final future = _invoke(statementId, args);
    unawaited(
      future
          .then((value) {
            if (_disposed) return;
            _entries[statementId] = QueryEntry(value: value);
            onChange?.call();
          })
          .catchError((Object error, StackTrace _) {
            if (_disposed) return;
            _entries[statementId] = QueryEntry(
              error: error is OpenUIError
                  ? error
                  : EvaluationError(
                      message: error.toString(),
                      statementId: statementId,
                    ),
            );
            onChange?.call();
          }),
    );
    // Listener fires for the loading transition too so the renderer
    // can drive the loading overlay.
    onChange?.call();
  }

  Future<Object?> _invoke(String statementId, List<Argument> args) {
    final loader = this.loader;
    if (loader != null) return loader(statementId, args);
    final toolName = _stringArg(args, 'name');
    if (toolName == null) {
      return Future<Object?>.error(
        EvaluationError(
          message: 'Query is missing required string arg "name"',
          statementId: statementId,
        ),
      );
    }
    final toolArgs = _mapArg(args, 'args') ?? const <String, Object?>{};
    return toolProvider!.callTool(toolName, toolArgs);
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
