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
    test(r'substitutes $item into the template', () {
      final ctx = _ctx(r'a = @Each([1, 2, 3], $item + 10)');
      expect(
        evaluate(_rhsOf(r'a = @Each([1, 2, 3], $item + 10)', 'a'), ctx),
        [11, 12, 13],
      );
    });

    test(r'substitutes $index alongside $item', () {
      final ctx = _ctx(r'a = @Each(["a", "b"], $index)');
      expect(
        evaluate(_rhsOf(r'a = @Each(["a", "b"], $index)', 'a'), ctx),
        [0, 1],
      );
    });

    test('empty list yields an empty result', () {
      final ctx = _ctx(r'a = @Each([], $item)');
      expect(
        evaluate(_rhsOf(r'a = @Each([], $item)', 'a'), ctx),
        isEmpty,
      );
    });

    test('null list yields an empty result without an error', () {
      final ctx = _ctx(r'a = @Each(missing, $item)');
      expect(
        evaluate(_rhsOf(r'a = @Each(missing, $item)', 'a'), ctx),
        isEmpty,
      );
      expect(ctx.errors, isEmpty);
    });

    test('non-list input pushes an error', () {
      final ctx = _ctx(r'a = @Each("hi", $item)');
      expect(
        evaluate(_rhsOf(r'a = @Each("hi", $item)', 'a'), ctx),
        isEmpty,
      );
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('@Each expects a list'),
      );
    });

    test('arity error on missing template', () {
      final ctx = _ctx('a = @Each([1, 2])');
      expect(evaluate(_rhsOf('a = @Each([1, 2])', 'a'), ctx), isEmpty);
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('@Each requires (list, template)'),
      );
    });

    test('template via Reference is re-evaluated per item', () {
      // `tpl` references $item; @Each calls it once per element.
      const source =
          'result = @Each([1, 2, 3], tpl)\n'
          r'tpl = $item * 10';
      final ctx = _ctx(source);
      expect(
        evaluate(_rhsOf(source, 'result'), ctx),
        [10, 20, 30],
      );
    });
  });

  group('@Map (currently identical to @Each)', () {
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

  group('iteration scope is layered, not flat', () {
    test(r'nested @Each does not leak $item across the inner scope', () {
      // Outer template invokes @Each inside; inside, $item is the
      // inner element, not the outer.
      final ctx = _ctx(
        r'a = @Each([[1, 2], [3]], @Each($item, $item))',
      );
      expect(
        evaluate(
          _rhsOf(r'a = @Each([[1, 2], [3]], @Each($item, $item))', 'a'),
          ctx,
        ),
        [
          [1, 2],
          [3],
        ],
      );
    });
  });
}
