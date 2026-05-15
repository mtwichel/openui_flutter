// Functional-builtin contract tests.
//
// Each builtin (@Count, @Filter, @Each, @Map) is exercised through a
// realistic AST built via parseProgram, with EvalContext.builtins
// pointing at `functionalBuiltins`. Tests cover:
// - Happy path with literal arguments.
// - $item / $index substitution inside the iteration scope.
// - Predicates / templates referenced via a separate statement
//   (Reference resolution layered with iteration scope).
// - Null and non-list inputs (returns the documented fallback;
//   non-list also pushes an EvaluationError).
// - Argument arity errors.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

EvalContext _ctx(String source, {Map<String, Object?>? state}) {
  final program = parseProgram(source);
  final store = Store();
  if (state != null) state.forEach(store.set);
  return EvalContext(
    statements: program.statements,
    store: store,
    builtins: functionalBuiltins,
  );
}

AstNode _rhsOf(String source, String name) {
  final program = parseProgram(source);
  return program.statements.firstWhere((s) => s.name == name).expression;
}

void main() {
  group('functionalBuiltins registry', () {
    test('exports exactly the four functional builtins', () {
      expect(
        functionalBuiltins.keys.toSet(),
        {'@Count', '@Filter', '@Each', '@Map'},
      );
    });

    test('the registry is unmodifiable', () {
      expect(
        () => functionalBuiltins['@New'] = (call, ctx) => null,
        throwsUnsupportedError,
      );
    });
  });

  group('@Count', () {
    test('returns the length of a literal list', () {
      final ctx = _ctx('a = @Count([1, 2, 3])');
      expect(evaluate(_rhsOf('a = @Count([1, 2, 3])', 'a'), ctx), 3);
    });

    test('returns 0 on null', () {
      final ctx = _ctx('a = @Count(missing)');
      expect(evaluate(_rhsOf('a = @Count(missing)', 'a'), ctx), 0);
      expect(ctx.errors, isEmpty);
    });

    test('returns 0 on a non-list and pushes an EvaluationError', () {
      final ctx = _ctx('a = @Count("hi")');
      expect(evaluate(_rhsOf('a = @Count("hi")', 'a'), ctx), 0);
      expect(ctx.errors, hasLength(1));
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('@Count expects a list'),
      );
    });

    test('zero arguments pushes an arity error and returns 0', () {
      final ctx = _ctx('a = @Count()');
      expect(evaluate(_rhsOf('a = @Count()', 'a'), ctx), 0);
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('@Count requires 1 argument'),
      );
    });
  });

  group('@Filter', () {
    test('keeps items where the predicate is truthy', () {
      // Predicate uses $item directly.
      final ctx = _ctx(r'a = @Filter([1, 2, 3, 4], $item > 2)');
      expect(
        evaluate(_rhsOf(r'a = @Filter([1, 2, 3, 4], $item > 2)', 'a'), ctx),
        [3, 4],
      );
    });

    test(r'exposes $index inside the predicate', () {
      // Keep only even-indexed items.
      final ctx = _ctx(r'a = @Filter([10, 20, 30, 40], $index % 2 == 0)');
      expect(
        evaluate(
          _rhsOf(r'a = @Filter([10, 20, 30, 40], $index % 2 == 0)', 'a'),
          ctx,
        ),
        [10, 30],
      );
    });

    test('predicate via a Reference resolves with iteration vars in scope', () {
      // `keep` is a value statement; @Filter calls it as a Reference,
      // which the evaluator resolves to its RHS, which uses $item.
      const source =
          'result = @Filter([1, 2, 3], keep)\n'
          r'keep = $item > 1';
      final ctx = _ctx(source);
      expect(evaluate(_rhsOf(source, 'result'), ctx), [2, 3]);
    });

    test('returns an empty list when the input is null', () {
      final ctx = _ctx(r'a = @Filter(missing, $item > 0)');
      expect(
        evaluate(_rhsOf(r'a = @Filter(missing, $item > 0)', 'a'), ctx),
        isEmpty,
      );
      expect(ctx.errors, isEmpty);
    });

    test('non-list input returns empty and pushes an error', () {
      final ctx = _ctx(r'a = @Filter("hi", $item == "h")');
      expect(
        evaluate(_rhsOf(r'a = @Filter("hi", $item == "h")', 'a'), ctx),
        isEmpty,
      );
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('@Filter expects a list'),
      );
    });

    test('arity error on missing predicate', () {
      final ctx = _ctx('a = @Filter([1, 2, 3])');
      expect(evaluate(_rhsOf('a = @Filter([1, 2, 3])', 'a'), ctx), isEmpty);
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('@Filter requires (list, predicate)'),
      );
    });

    test('predicate truthiness covers each falsy and truthy shape', () {
      // Predicate returns the item itself; @Filter then keeps truthy ones.
      // Build a list with one of each "falsy" value and a couple truthy.
      const source =
          'a = @Filter([1, 0, "x", "", [1], [], {k: 1}, {}, missing],'
          r' $item)';
      final ctx = _ctx(source);
      expect(
        evaluate(_rhsOf(source, 'a'), ctx),
        [
          1,
          'x',
          [1],
          {'k': 1},
        ],
      );
    });

    test(
      'predicate returning a non-bool/non-primitive is treated as truthy',
      () {
        // Build a builtins map that adds a custom @Opaque returning a
        // raw Object, then chain it through @Filter.
        final extended = <String, BuiltinHandler>{
          ...functionalBuiltins,
          '@Opaque': (call, ctx) => Object(),
        };
        final program = parseProgram('a = @Filter([1, 2], @Opaque())');
        final ctx = EvalContext(
          statements: program.statements,
          store: Store(),
          builtins: extended,
        );
        expect(evaluate(program.statements.single.expression, ctx), [1, 2]);
      },
    );
  });

  group('@Each', () {
    test('binds the named loop var into the template', () {
      const source = 'a = @Each([1, 2, 3], "n", n + 10)';
      final ctx = _ctx(source);
      expect(evaluate(_rhsOf(source, 'a'), ctx), [11, 12, 13]);
    });

    test(r'$index is bound alongside the named loop var', () {
      const source = r'a = @Each(["a", "b"], "n", $index)';
      final ctx = _ctx(source);
      expect(evaluate(_rhsOf(source, 'a'), ctx), [0, 1]);
    });

    test('empty list yields an empty result', () {
      const source = 'a = @Each([], "n", n)';
      final ctx = _ctx(source);
      expect(evaluate(_rhsOf(source, 'a'), ctx), isEmpty);
    });

    test('null list yields an empty result without an error', () {
      const source = 'a = @Each(missing, "n", n)';
      final ctx = _ctx(source);
      expect(evaluate(_rhsOf(source, 'a'), ctx), isEmpty);
      expect(ctx.errors, isEmpty);
    });

    test('non-list input pushes an error', () {
      const source = 'a = @Each("hi", "n", n)';
      final ctx = _ctx(source);
      expect(evaluate(_rhsOf(source, 'a'), ctx), isEmpty);
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('@Each expects a list'),
      );
    });

    test('2-arg call surfaces an arity error pointing at the new shape', () {
      // Direct AST construction — the parser would reject this shape,
      // but the evaluator backstop must still fire (programmatic
      // callers, hand-built ASTs in tests).
      final call = BuiltinCall(
        '@Each',
        [
          Argument(value: ArrayLit(const [], offset: 0), offset: 0),
          const Argument(value: Reference('item', offset: 0), offset: 0),
        ],
        offset: 0,
      );
      final ctx = EvalContext(
        statements: const [],
        store: Store(),
        builtins: functionalBuiltins,
      );
      expect(evaluate(call, ctx), isEmpty);
      final msg = (ctx.errors.single as EvaluationError).message;
      expect(msg, contains('3 args'));
      expect(msg, contains('(list, "name", template)'));
    });

    test('wrong-arity (4 args) surfaces an error', () {
      final call = BuiltinCall(
        '@Each',
        [
          Argument(value: ArrayLit(const [], offset: 0), offset: 0),
          const Argument(value: Literal('n', offset: 0), offset: 0),
          const Argument(value: Reference('n', offset: 0), offset: 0),
          const Argument(value: Literal(1, offset: 0), offset: 0),
        ],
        offset: 0,
      );
      final ctx = EvalContext(
        statements: const [],
        store: Store(),
        builtins: functionalBuiltins,
      );
      expect(evaluate(call, ctx), isEmpty);
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('3 args'),
      );
    });

    test('non-string-literal name surfaces an error', () {
      // Built directly: second arg is a Reference, not a Literal.
      final call = BuiltinCall(
        '@Each',
        [
          Argument(value: ArrayLit(const [], offset: 0), offset: 0),
          const Argument(value: Reference('name', offset: 0), offset: 0),
          const Argument(value: Reference('name', offset: 0), offset: 0),
        ],
        offset: 0,
      );
      final ctx = EvalContext(
        statements: const [],
        store: Store(),
        builtins: functionalBuiltins,
      );
      expect(evaluate(call, ctx), isEmpty);
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('string identifier literal'),
      );
    });

    test('empty-string name is rejected', () {
      final call = BuiltinCall(
        '@Each',
        [
          Argument(value: ArrayLit(const [], offset: 0), offset: 0),
          const Argument(value: Literal('', offset: 0), offset: 0),
          const Argument(value: Literal(1, offset: 0), offset: 0),
        ],
        offset: 0,
      );
      final ctx = EvalContext(
        statements: const [],
        store: Store(),
        builtins: functionalBuiltins,
      );
      expect(evaluate(call, ctx), isEmpty);
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('string identifier literal'),
      );
    });

    test(r'$-prefixed name is rejected', () {
      final call = BuiltinCall(
        '@Each',
        [
          Argument(value: ArrayLit(const [], offset: 0), offset: 0),
          const Argument(value: Literal(r'$item', offset: 0), offset: 0),
          const Argument(value: Reference('x', offset: 0), offset: 0),
        ],
        offset: 0,
      );
      final ctx = EvalContext(
        statements: const [],
        store: Store(),
        builtins: functionalBuiltins,
      );
      expect(evaluate(call, ctx), isEmpty);
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('string identifier literal'),
      );
    });

    test('reserved keyword name is rejected', () {
      final call = BuiltinCall(
        '@Each',
        [
          Argument(value: ArrayLit(const [], offset: 0), offset: 0),
          const Argument(value: Literal('true', offset: 0), offset: 0),
          const Argument(value: Reference('x', offset: 0), offset: 0),
        ],
        offset: 0,
      );
      final ctx = EvalContext(
        statements: const [],
        store: Store(),
        builtins: functionalBuiltins,
      );
      expect(evaluate(call, ctx), isEmpty);
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('string identifier literal'),
      );
    });

    test('template via Reference is re-evaluated per item', () {
      const source = 'result = @Each([1, 2, 3], "n", tpl)\ntpl = n * 10';
      final ctx = _ctx(source);
      expect(evaluate(_rhsOf(source, 'result'), ctx), [10, 20, 30]);
    });

    test('nested @Each binds distinct names without leaking the outer', () {
      const source =
          'a = @Each([[1, 2], [3]], "outer", '
          '@Each(outer, "inner", outer))';
      final ctx = _ctx(source);
      expect(evaluate(_rhsOf(source, 'a'), ctx), [
        [
          [1, 2],
          [1, 2],
        ],
        [
          [3],
        ],
      ]);
    });

    test('nested @Each member access on objects', () {
      // Each row is {children: [...]}; iterate outer first, then inner.
      const source =
          'a = @Each([ '
          '{id: 1, children: [{id: 10}, {id: 11}]}, '
          '{id: 2, children: [{id: 20}]} '
          '], "o", @Each(o.children, "c", c.id))';
      final ctx = _ctx(source);
      expect(evaluate(_rhsOf(source, 'a'), ctx), [
        [10, 11],
        [20],
      ]);
    });
  });

  group('@Map', () {
    test('produces the transformed list', () {
      final ctx = _ctx(r'a = @Map([1, 2, 3], $item * 2)');
      expect(
        evaluate(_rhsOf(r'a = @Map([1, 2, 3], $item * 2)', 'a'), ctx),
        [2, 4, 6],
      );
    });

    test('null list yields an empty list', () {
      final ctx = _ctx(r'a = @Map(missing, $item)');
      expect(
        evaluate(_rhsOf(r'a = @Map(missing, $item)', 'a'), ctx),
        isEmpty,
      );
      expect(ctx.errors, isEmpty);
    });

    test('non-list input pushes an error', () {
      final ctx = _ctx(r'a = @Map("hi", $item)');
      expect(
        evaluate(_rhsOf(r'a = @Map("hi", $item)', 'a'), ctx),
        isEmpty,
      );
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('@Map expects a list'),
      );
    });

    test('arity error on missing transform', () {
      final ctx = _ctx('a = @Map([1])');
      expect(evaluate(_rhsOf('a = @Map([1])', 'a'), ctx), isEmpty);
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('@Map requires (list, template)'),
      );
    });
  });
}
