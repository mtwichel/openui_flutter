import 'package:meta/meta.dart';
import 'package:openui_core/src/errors/errors.dart';
import 'package:openui_core/src/parser/parser.dart';
import 'package:openui_core/src/state/store.dart';

/// Handler for one builtin name (e.g. `'@Each'`). Receives the
/// original [BuiltinCall] node — handlers typically need the raw arg
/// ASTs to control evaluation order (e.g. lazy iteration in `@Each`).
///
/// Marked `@experimental` per D12.
@experimental
typedef BuiltinHandler =
    Object? Function(BuiltinCall call, EvalContext context);

/// Inputs the evaluator needs to resolve every kind of [AstNode]:
/// the parsed statement map, the reactive store, cached query
/// results, an optional iteration scope (for `$item` / `$index`
/// inside `@Each`-like builtins), and a registry of builtin
/// handlers. The [errors] list is mutable — the evaluator pushes
/// [OpenUIError] entries for cycles and category errors instead of
/// throwing, per Decision D15 ("surface as data, not exception").
///
/// Marked `@experimental` per D12.
@experimental
class EvalContext {
  /// Creates an [EvalContext]. [statements] is a list because that's
  /// what callers usually have (`program.statements`); the constructor
  /// builds the last-write-wins map internally to match the
  /// materializer's semantics.
  EvalContext({
    required List<Statement> statements,
    required this.store,
    Map<String, Object?>? queryResults,
    Map<String, Object?>? iterationVars,
    Map<String, BuiltinHandler>? builtins,
    List<OpenUIError>? errors,
  }) : statements = _buildMap(statements),
       queryResults = queryResults ?? const <String, Object?>{},
       iterationVars = iterationVars ?? const <String, Object?>{},
       builtins = builtins ?? const <String, BuiltinHandler>{},
       errors = errors ?? <OpenUIError>[],
       _resolving = <String>{};

  EvalContext._inherit(EvalContext parent, Map<String, Object?> additional)
    : statements = parent.statements,
      store = parent.store,
      queryResults = parent.queryResults,
      iterationVars = <String, Object?>{
        ...parent.iterationVars,
        ...additional,
      },
      builtins = parent.builtins,
      errors = parent.errors,
      _resolving = parent._resolving;

  /// Statement map keyed by name. Last-write-wins on duplicates.
  final Map<String, Statement> statements;

  /// The reactive store that backs `$state` lookups.
  final Store store;

  /// Cached results for `Query` and `Mutation` statements, keyed by
  /// the statement id. Empty by default.
  final Map<String, Object?> queryResults;

  /// Iteration scope. `$item` and `$index` inside an `@Each` body are
  /// served from here, taking precedence over the [store].
  final Map<String, Object?> iterationVars;

  /// Registered handlers for `BuiltinCall` dispatch, keyed by the
  /// builtin name including the leading `@`. The base evaluator
  /// emits an [EvaluationError] when a builtin call has no handler.
  final Map<String, BuiltinHandler> builtins;

  /// Error sink. The evaluator appends here on cycle detection and on
  /// "cannot evaluate as a value" cases. Shared across child contexts
  /// produced by [withIteration] so iteration handlers participate in
  /// the same dedup pass.
  final List<OpenUIError> errors;

  final Set<String> _resolving;

  /// Returns a child context with [additionalVars] layered on top of
  /// [iterationVars]. The child shares the same [statements], [store],
  /// [queryResults], [builtins], [errors], and cycle-detection state
  /// as this context — only [iterationVars] is rebuilt.
  EvalContext withIteration(Map<String, Object?> additionalVars) =>
      EvalContext._inherit(this, additionalVars);

  static Map<String, Statement> _buildMap(List<Statement> stmts) {
    final m = <String, Statement>{};
    for (final s in stmts) {
      m[s.name] = s;
    }
    return m;
  }
}

/// Walks [node] against [context] and returns the resolved value.
///
/// Returns `null` whenever a path cannot produce a value — a missing
/// reference, an out-of-range index, a type-mismatched binary op, or
/// a node kind that has no value semantics (component, query, and
/// mutation calls in expression position). Cycle detection over the
/// statement-id graph emits a [CyclicStateError] into `context.errors`
/// and returns `null` instead of recursing forever.
///
/// Marked `@experimental` per D12.
@experimental
Object? evaluate(AstNode node, EvalContext context) {
  switch (node) {
    case Literal(:final value):
      return value;
    case NullLiteral():
      return null;
    case Reference(:final name):
      return _evalReference(name, context);
    case StateRef(:final name):
      return _evalStateRef(name, context);
    case StateAssign(:final target, :final value):
      final v = evaluate(value, context);
      context.store.set('\$$target', v);
      return v;
    case ArrayLit(:final elements):
      return [for (final e in elements) evaluate(e, context)];
    case ObjectLit(:final entries):
      return <String, Object?>{
        for (final e in entries) e.key: evaluate(e.value, context),
      };
    case BinaryOp(:final op, :final left, :final right):
      return _evalBinary(op, left, right, context);
    case UnaryOp(:final op, :final operand):
      return _evalUnary(op, evaluate(operand, context));
    case Ternary(:final condition, :final then, :final otherwise):
      return _isTruthy(evaluate(condition, context))
          ? evaluate(then, context)
          : evaluate(otherwise, context);
    case MemberAccess(:final target, :final name):
      return _evalMember(evaluate(target, context), name);
    case IndexAccess(:final target, :final index):
      return _evalIndex(
        evaluate(target, context),
        evaluate(index, context),
      );
    case final BuiltinCall b:
      final handler = context.builtins[b.name];
      if (handler != null) return handler(b, context);
      context.errors.add(
        EvaluationError(
          message: 'no handler registered for builtin ${b.name}',
        ),
      );
      return null;
    case CompCall(:final type):
      context.errors.add(
        EvaluationError(
          message: 'cannot evaluate component call $type as a value',
        ),
      );
      return null;
    case QueryCall():
      context.errors.add(
        const EvaluationError(
          message: 'cannot evaluate Query call as a value',
        ),
      );
      return null;
    case MutationCall():
      context.errors.add(
        const EvaluationError(
          message: 'cannot evaluate Mutation call as a value',
        ),
      );
      return null;
  }
}

Object? _evalReference(String name, EvalContext context) {
  // Named-loop binding from `@Each(list, "name", template)` lives in
  // iterationVars under the unprefixed key, so a bare `name.field`
  // reference inside the template resolves here before the statement
  // map. `$item` / `$index` continue to flow through `_evalStateRef`
  // since their keys are stored with the `$` prefix.
  if (context.iterationVars.containsKey(name)) {
    return context.iterationVars[name];
  }
  if (context._resolving.contains(name)) {
    context.errors.add(
      CyclicStateError(cycle: [...context._resolving, name]),
    );
    return null;
  }
  final stmt = context.statements[name];
  if (stmt == null) return null;
  if (stmt.kind == StatementKind.query || stmt.kind == StatementKind.mutation) {
    return context.queryResults[name];
  }
  context._resolving.add(name);
  final result = evaluate(stmt.expression, context);
  context._resolving.remove(name);
  return result;
}

Object? _evalStateRef(String name, EvalContext context) {
  // Store and iteration-var keys carry the `$` prefix (matching the
  // streaming parser's `StateDecl.name` convention); `StateRef.name`
  // is the lexer-stripped bare identifier.
  final fullName = '\$$name';
  if (context.iterationVars.containsKey(fullName)) {
    return context.iterationVars[fullName];
  }
  // D15 cycle-detection branch. Dormant in v0.1 because no current
  // path adds `$`-prefixed keys to `_resolving`; a later milestone
  // (state-default initializer) will recurse through state ASTs and
  // activate this guard.
  // coverage:ignore-start
  if (context._resolving.contains(fullName)) {
    context.errors.add(
      CyclicStateError(cycle: [...context._resolving, fullName]),
    );
    return null;
  }
  // coverage:ignore-end
  return context.store.get(fullName);
}

Object? _evalBinary(
  String op,
  AstNode left,
  AstNode right,
  EvalContext context,
) {
  // && and || short-circuit on the left operand.
  if (op == '&&') {
    final l = evaluate(left, context);
    if (!_isTruthy(l)) return l;
    return evaluate(right, context);
  }
  if (op == '||') {
    final l = evaluate(left, context);
    if (_isTruthy(l)) return l;
    return evaluate(right, context);
  }
  final l = evaluate(left, context);
  final r = evaluate(right, context);
  switch (op) {
    case '+':
      if (l is num && r is num) return l + r;
      if (l is String && r is String) return l + r;
      // Mixed string + non-null: stringify the other side. Matches the
      // common `"Count: " + $count` template idiom.
      if (l is String) return '$l${r ?? ''}';
      if (r is String) return '${l ?? ''}$r';
      return null;
    case '-':
      return (l is num && r is num) ? l - r : null;
    case '*':
      return (l is num && r is num) ? l * r : null;
    case '/':
      if (l is num && r is num && r != 0) return l / r;
      return null;
    case '%':
      if (l is num && r is num && r != 0) return l % r;
      return null;
    case '==':
      return _equals(l, r);
    case '!=':
      return !_equals(l, r);
    case '<':
      return (l is num && r is num) ? l < r : null;
    case '>':
      return (l is num && r is num) ? l > r : null;
    case '<=':
      return (l is num && r is num) ? l <= r : null;
    case '>=':
      return (l is num && r is num) ? l >= r : null;
  }
  // The parser only emits the operators above; this fallback is
  // defensive against future grammar additions.
  return null; // coverage:ignore-line
}

Object? _evalUnary(String op, Object? operand) {
  switch (op) {
    case '!':
      return !_isTruthy(operand);
    case '-':
      return operand is num ? -operand : null;
  }
  return null; // coverage:ignore-line
}

Object? _evalMember(Object? target, String name) {
  if (target is Map<String, Object?>) return target[name];
  if (target is List<Object?> && name == 'length') return target.length;
  if (target is String && name == 'length') return target.length;
  return null;
}

Object? _evalIndex(Object? target, Object? index) {
  if (target is List<Object?>) {
    if (index is! int) return null;
    if (index < 0 || index >= target.length) return null;
    return target[index];
  }
  if (target is Map<String, Object?> && index is String) {
    return target[index];
  }
  return null;
}

bool _isTruthy(Object? v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.isNotEmpty;
  if (v is List<Object?>) return v.isNotEmpty;
  if (v is Map<String, Object?>) return v.isNotEmpty;
  return true;
}

bool _equals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  return a == b;
}
