// Internal references to openui_core experimental types — the entire
// openui_core surface is marked @experimental in v0.1.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:openui/src/tool_registry.dart';
import 'package:openui_core/openui_core.dart';

/// Evaluated query node passed to [QueryManager.evaluateQueries].
@experimental
class QueryNode {
  /// Creates a [QueryNode].
  const QueryNode({
    required this.statementId,
    required this.toolName,
    required this.args,
    required this.defaults,
    this.deps,
    this.refreshInterval,
    this.complete = true,
  });

  /// Statement name without `$`, e.g. `data`.
  final String statementId;

  /// Resolved tool name string.
  final String toolName;

  /// Resolved arguments record for the tool call.
  final Object? args;

  /// Resolved defaults returned before fetch completes.
  final Object? defaults;

  /// Evaluated dependency slice used in the cache key.
  final Object? deps;

  /// Auto-refresh interval in seconds, if any.
  final double? refreshInterval;

  /// False while the query call is still being streamed.
  final bool complete;
}

/// Reactive data fetching for canonical `Query(...)` declarations.
///
/// Owns query results; does not write to [Store]. The renderer wires
/// [EvalContext.resolveRef] to [getResult].
///
/// Marked `@experimental` per D12.
@experimental
class QueryManager {
  /// Creates a [QueryManager].
  QueryManager({
    required this.library,
    required this.toolRegistry,
    required void Function(OpenUIError) onError,
  }) : _onError = onError;

  /// Component and tool definitions used for dispatch lookup.
  final LibraryDefinition library;

  /// Tool executors keyed by tool name.
  final ToolRegistry toolRegistry;

  final void Function(OpenUIError) _onError;

  final Map<String, _QueryEntry> _queries = <String, _QueryEntry>{};
  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};
  final Set<void Function()> _listeners = <void Function()>{};
  bool _disposed = false;

  /// Registers listeners for query result changes. Returns unsubscribe.
  void Function() subscribe(void Function() listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void _notify() {
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  /// Updates active queries and fires fetches when needed.
  void evaluateQueries(List<QueryNode> nodes) {
    if (_disposed) return;

    final activeIds = nodes.map((n) => n.statementId).toSet();

    for (final sid in _queries.keys.toList()) {
      if (!activeIds.contains(sid)) {
        final q = _queries.remove(sid)!;
        q.timer?.cancel();
        _cleanupCacheEntry(q.cacheKey);
        if (q.prevCacheKey != null) {
          _cleanupCacheEntry(q.prevCacheKey!);
        }
      }
    }

    for (final node in nodes) {
      if (!node.complete) {
        _queries[node.statementId] = _QueryEntry(
          toolName: node.toolName,
          args: node.args,
          defaults: node.defaults,
          cacheKey: '__incomplete__:${node.statementId}',
        );
        continue;
      }

      final cacheKey = _buildCacheKey(
        node.toolName,
        node.args,
        node.deps,
      );
      final existing = _queries[node.statementId];

      if (existing != null) {
        if (existing.cacheKey != cacheKey) {
          existing.prevCacheKey = existing.cacheKey;
        }
        existing
          ..toolName = node.toolName
          ..args = node.args
          ..defaults = node.defaults
          ..cacheKey = cacheKey;
      } else {
        _queries[node.statementId] = _QueryEntry(
          toolName: node.toolName,
          args: node.args,
          defaults: node.defaults,
          cacheKey: cacheKey,
        );
      }

      final q = _queries[node.statementId]!;
      final entry = _cache[cacheKey];
      final hasSettledData = entry != null && entry.settled && !entry.inFlight;
      if (!hasSettledData && !(entry?.inFlight ?? false)) {
        unawaited(_executeFetch(cacheKey, node.statementId));
      }

      final newInterval = node.refreshInterval ?? 0;
      if (newInterval != q.refreshInterval) {
        q.timer?.cancel();
        q.timer = null;
        if (newInterval > 0) {
          q.timer = Timer.periodic(
            Duration(milliseconds: (newInterval * 1000).round()),
            (_) {
              if (_disposed) return;
              final current = _cache[q.cacheKey];
              if (current?.inFlight ?? false) return;
              unawaited(_executeFetch(q.cacheKey, node.statementId));
            },
          );
        }
        q.refreshInterval = newInterval;
      }
    }

    _notify();
  }

  /// Returns the current value for [statementId] (defaults, live, or
  /// last-good while refetching).
  Object? getResult(String statementId) {
    final q = _queries[statementId];
    if (q == null) return null;
    final entry = _cache[q.cacheKey];
    if (entry != null && entry.data != null) return entry.data;
    if (q.prevCacheKey != null) {
      final prev = _cache[q.prevCacheKey!];
      if (prev != null && prev.data != null) return prev.data;
    }
    return q.defaults;
  }

  /// Re-fetches [statementIds], or all queries when omitted.
  void invalidate([List<String>? statementIds]) {
    if (_disposed) return;
    final targets = statementIds != null && statementIds.isNotEmpty
        ? statementIds.where(_queries.containsKey).toList()
        : _queries.keys.toList();
    for (final sid in targets) {
      final q = _queries[sid];
      if (q == null) continue;
      final entry = _cache[q.cacheKey];
      if (entry?.inFlight ?? false) {
        q.needsRefetch = true;
      } else {
        unawaited(_executeFetch(q.cacheKey, sid));
      }
    }
  }

  /// Fires a mutation by [statementId]. Returns the resolved value on
  /// success. Errors are wrapped as [OpenUIError] and rethrown.
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

  /// Releases the manager and cancels refresh timers.
  void dispose() {
    _disposed = true;
    for (final q in _queries.values) {
      q.timer?.cancel();
    }
    _listeners.clear();
  }

  Future<void> _executeFetch(String cacheKey, String statementId) async {
    final q = _queries[statementId];
    if (q == null) return;

    final fetchKey = cacheKey;
    final toolName = q.toolName;
    final args = q.args;

    var entry = _cache[fetchKey];
    if (entry == null) {
      entry = _CacheEntry(inFlight: true);
      _cache[fetchKey] = entry;
    } else {
      entry.inFlight = true;
    }
    _notify();

    final toolDef = library.tool(toolName);
    if (toolDef == null) {
      _finishFetchError(
        statementId: statementId,
        fetchKey: fetchKey,
        message: 'Unknown tool: $toolName',
      );
      return;
    }
    final executor = toolRegistry[toolName];
    if (executor == null) {
      _finishFetchError(
        statementId: statementId,
        fetchKey: fetchKey,
        message: 'Missing executor for tool: $toolName',
        toolName: toolName,
      );
      return;
    }

    try {
      final recordArgs = args is Map<String, Object?>
          ? args
          : args is Map
          ? Map<String, Object?>.from(args)
          : const <String, Object?>{};
      final value = await executor(recordArgs);
      if (_disposed) return;
      final current = _queries[statementId];
      if (current == null || current.cacheKey != fetchKey) {
        entry.inFlight = false;
        return;
      }
      if (value.isError) {
        entry.settled = true;
        _onError(
          EvaluationError(
            message: value.result?.toString() ?? 'Tool call failed',
            statementId: statementId,
          ),
        );
      } else {
        entry
          ..data = value.result
          ..settled = true;
        if (current.prevCacheKey != null && current.prevCacheKey != fetchKey) {
          final prevKey = current.prevCacheKey!;
          current.prevCacheKey = null;
          _cleanupCacheEntry(prevKey);
        }
      }
    } on Object catch (error) {
      if (_disposed) return;
      final current = _queries[statementId];
      if (current != null && current.cacheKey == fetchKey) {
        _onError(
          error is OpenUIError
              ? error
              : EvaluationError(
                  message: error.toString(),
                  statementId: statementId,
                ),
        );
      }
    } finally {
      entry.inFlight = false;
      final current = _queries[statementId];
      if (current != null && current.cacheKey == fetchKey) {
        entry.settled = true;
        if (current.needsRefetch) {
          current.needsRefetch = false;
          unawaited(_executeFetch(current.cacheKey, statementId));
        }
      }
      _notify();
    }
  }

  void _finishFetchError({
    required String statementId,
    required String fetchKey,
    required String message,
    String? toolName,
  }) {
    final entry = _cache[fetchKey];
    entry?.inFlight = false;
    entry?.settled = true;
    _onError(
      toolName != null
          ? MissingToolExecutorError(
              toolName: toolName,
              statementId: statementId,
            )
          : EvaluationError(message: message, statementId: statementId),
    );
    _notify();
  }

  void _cleanupCacheEntry(String cacheKey) {
    for (final q in _queries.values) {
      if (q.cacheKey == cacheKey || q.prevCacheKey == cacheKey) return;
    }
    _cache.remove(cacheKey);
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

class _QueryEntry {
  _QueryEntry({
    required this.toolName,
    required this.args,
    required this.defaults,
    required this.cacheKey,
  });

  String toolName;
  Object? args;
  Object? defaults;
  String cacheKey;
  String? prevCacheKey;
  double refreshInterval = 0;
  Timer? timer;
  bool needsRefetch = false;
}

class _CacheEntry {
  _CacheEntry({this.inFlight = false});

  Object? data;
  bool inFlight;
  bool settled = false;
}

String _buildCacheKey(String toolName, Object? args, Object? deps) {
  final depsKey = deps != null ? '::${_stableStringify(deps)}' : '';
  return '$toolName::${_stableStringify(args)}$depsKey';
}

String _stableStringify(Object? value) {
  return jsonEncode(
    value,
    toEncodable: (val) {
      if (val is Map) {
        final sorted = <String, Object?>{};
        for (final key in val.keys.map((k) => k.toString()).toList()..sort()) {
          sorted[key] = val[key];
        }
        return sorted;
      }
      if (val == null) return '__undefined__';
      return val;
    },
  );
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
