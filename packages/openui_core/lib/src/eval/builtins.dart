import 'package:meta/meta.dart';
import 'package:openui_core/src/errors/errors.dart';
import 'package:openui_core/src/eval/evaluator.dart';
import 'package:openui_core/src/parser/parser.dart';

/// The four functional builtins from the OpenUI Lang spec, ready to
/// drop into [EvalContext.builtins]:
///
/// - `@Count(list)` — returns `list.length`, or `0` if the input is
///   null. Anything else is a category error and yields `0`.
/// - `@Filter(list, predicate)` — keeps each item for which
///   `predicate` evaluates truthy with `$item` and `$index` in scope.
/// - `@Each(list, "name", template)` — evaluates `template` once per
///   item with the named loop var (bound under its bare key) and
///   `$index` in scope; returns the list of results. The renderer's
///   iteration source.
/// - `@Map(list, transform)` — `@Filter`-shaped: `$item` / `$index`
///   in scope. Spec calls the second arg a "transform ref", but at
///   the evaluator layer the semantics match `@Filter`.
///
/// Action-step builtins (`@Set`, `@Reset`, `@Run`, `@ToAssistant`)
/// are in a separate dispatcher and not part of this
/// registry — they are not value-producing.
///
/// Marked `@experimental` per D12.
@experimental
final Map<String, BuiltinHandler> functionalBuiltins =
    Map<String, BuiltinHandler>.unmodifiable(<String, BuiltinHandler>{
      '@Count': _evalCount,
      '@Filter': _evalFilter,
      '@Each': _evalEach,
      '@Map': _evalMap,
      '@Query': _evalQueryNoop,
    });

// `@Query` is fired by the renderer's `QueryManager`, not by the
// evaluator. Registering a no-op here keeps an accidental render-time
// traversal of an unfired `@Query` AST from raising
// `no handler registered for builtin @Query`. The result slot lives in
// the store under the statement id (e.g. `$products`).
Object? _evalQueryNoop(BuiltinCall call, EvalContext context) => null;

Object? _evalCount(BuiltinCall call, EvalContext context) {
  if (call.args.isEmpty) {
    context.errors.add(
      const EvaluationError(message: '@Count requires 1 argument'),
    );
    return 0;
  }
  final v = evaluate(call.args.first.value, context);
  if (v == null) return 0;
  if (v is List<Object?>) return v.length;
  context.errors.add(
    EvaluationError(
      message: '@Count expects a list, got ${v.runtimeType}',
    ),
  );
  return 0;
}

Object? _evalFilter(BuiltinCall call, EvalContext context) {
  if (call.args.length < 2) {
    context.errors.add(
      EvaluationError(
        message:
            '@Filter requires (list, predicate) — got ${call.args.length} args',
      ),
    );
    return <Object?>[];
  }
  final listVal = evaluate(call.args[0].value, context);
  if (listVal == null) return <Object?>[];
  if (listVal is! List<Object?>) {
    context.errors.add(
      EvaluationError(
        message:
            '@Filter expects a list as first arg, got ${listVal.runtimeType}',
      ),
    );
    return <Object?>[];
  }
  final predicate = call.args[1].value;
  final result = <Object?>[];
  for (var i = 0; i < listVal.length; i++) {
    final p = evaluate(
      predicate,
      context.withIteration(<String, Object?>{
        r'$item': listVal[i],
        r'$index': i,
      }),
    );
    if (_truthy(p)) result.add(listVal[i]);
  }
  return result;
}

Object? _evalEach(BuiltinCall call, EvalContext context) {
  if (call.args.length != 3) {
    context.errors.add(
      EvaluationError(
        message:
            '@Each requires (list, "name", template) — 3 args, '
            'got ${call.args.length}',
      ),
    );
    return <Object?>[];
  }
  final nameArg = call.args[1].value;
  if (nameArg is! Literal ||
      nameArg.value is! String ||
      !isValidLoopVarName(nameArg.value! as String)) {
    context.errors.add(
      const EvaluationError(
        message:
            '@Each requires (list, "name", template) — second arg must '
            'be a string identifier literal',
      ),
    );
    return <Object?>[];
  }
  final loopVar = nameArg.value! as String;
  final listVal = evaluate(call.args[0].value, context);
  if (listVal == null) return <Object?>[];
  if (listVal is! List<Object?>) {
    context.errors.add(
      EvaluationError(
        message:
            '@Each expects a list as first arg, got ${listVal.runtimeType}',
      ),
    );
    return <Object?>[];
  }
  final template = call.args[2].value;
  return <Object?>[
    for (var i = 0; i < listVal.length; i++)
      evaluate(
        template,
        context.withIteration(<String, Object?>{
          loopVar: listVal[i],
          r'$index': i,
        }),
      ),
  ];
}

Object? _evalMap(BuiltinCall call, EvalContext context) =>
    _iterate(call, context, '@Map');

List<Object?> _iterate(BuiltinCall call, EvalContext context, String name) {
  if (call.args.length < 2) {
    context.errors.add(
      EvaluationError(
        message:
            '$name requires (list, template) — got ${call.args.length} args',
      ),
    );
    return <Object?>[];
  }
  final listVal = evaluate(call.args[0].value, context);
  if (listVal == null) return <Object?>[];
  if (listVal is! List<Object?>) {
    context.errors.add(
      EvaluationError(
        message:
            '$name expects a list as first arg, got ${listVal.runtimeType}',
      ),
    );
    return <Object?>[];
  }
  final template = call.args[1].value;
  return <Object?>[
    for (var i = 0; i < listVal.length; i++)
      evaluate(
        template,
        context.withIteration(<String, Object?>{
          r'$item': listVal[i],
          r'$index': i,
        }),
      ),
  ];
}

bool _truthy(Object? v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.isNotEmpty;
  if (v is List<Object?>) return v.isNotEmpty;
  if (v is Map<String, Object?>) return v.isNotEmpty;
  return true;
}
