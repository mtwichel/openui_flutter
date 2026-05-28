// Evaluator contract tests.
//
// Each test seeds an EvalContext (often via parseProgram so the AST
// shapes are realistic), evaluates a single root expression, and
// asserts the returned Object? plus the side-channel `errors` list.
//
// Coverage targets every AstNode case in the dispatcher:
// - Literals (number, string, bool) and NullLiteral
// - Reference resolution (transitive, query/mutation, missing, cycle)
// - StateRef (store, iterationVars, cycle)
// - StateAssign (writes back into the store)
// - ArrayLit, ObjectLit
// - All binary operators (arithmetic, comparison, equality, logical)
//   on both well-typed and ill-typed operands
// - Unary `!` and `-`
// - Ternary (both branches)
// - MemberAccess on Map / List.length / String.length / null
// - IndexAccess on List (in-range, OOB, non-int) / Map / null
// - BuiltinCall via a registered handler and unregistered (error path)
// - CompCall / MutationCall in expression position emit errors
// - withIteration shares cycle state and errors
// - Truthiness rules across every primitive shape

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

EvalContext _ctxFor(String source, {Store? store}) {
  final program = parseProgram(source);
  return EvalContext(
    statements: program.statements,
    store: store ?? Store(),
  );
}

AstNode _rhsOf(String source, String name) {
  final program = parseProgram(source);
  return program.statements.firstWhere((s) => s.name == name).expression;
}

void main() {
  group('EvalContext', () {
    test('default iterationVars, builtins, errors', () {
      final ctx = EvalContext(statements: const [], store: Store());
      expect(ctx.iterationVars, isEmpty);
      expect(ctx.builtins, isEmpty);
      expect(ctx.errors, isEmpty);
      expect(ctx.statements, isEmpty);
    });

    test('builds the statement map with last-write-wins', () {
      final program = parseProgram('a = 1\na = 2\nb = 3');
      final ctx = EvalContext(
        statements: program.statements,
        store: Store(),
      );
      expect(ctx.statements.keys.toSet(), {'a', 'b'});
      // Resolves to the second assignment's expression.
      expect((ctx.statements['a']!.expression as Literal).value, 2);
    });

    test('withIteration layers vars on top of the existing scope', () {
      final ctx = EvalContext(
        statements: const [],
        store: Store(),
        iterationVars: const {r'$item': 'outer'},
      );
      final child = ctx.withIteration(const {r'$index': 4});
      expect(child.iterationVars[r'$item'], 'outer');
      expect(child.iterationVars[r'$index'], 4);
    });

    test('withIteration shares the errors list and cycle state', () {
      final ctx = EvalContext(statements: const [], store: Store());
      final child = ctx.withIteration(const {});
      child.errors.add(const EvaluationError(message: 'from child'));
      expect(ctx.errors, hasLength(1));
      // Inheriting context shares the cycle-detection set so a
      // `Reference` cycle that crosses an iteration boundary still
      // trips. Verified end-to-end by the cycle test below; here we
      // just confirm identity.
      expect(identical(ctx.errors, child.errors), isTrue);
    });
  });

  group('literals and null', () {
    test('integer Literal returns its value', () {
      final ctx = _ctxFor('');
      expect(evaluate(const Literal(42, offset: 0), ctx), 42);
    });

    test('string Literal returns its value', () {
      final ctx = _ctxFor('');
      expect(evaluate(const Literal('hi', offset: 0), ctx), 'hi');
    });

    test('boolean Literal returns its value', () {
      final ctx = _ctxFor('');
      expect(evaluate(const Literal(true, offset: 0), ctx), true);
    });

    test('NullLiteral returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(const NullLiteral(offset: 0), ctx), isNull);
    });
  });

  group('Reference', () {
    test('resolves a value statement', () {
      final ctx = _ctxFor('a = 7');
      expect(evaluate(const Reference('a', offset: 0), ctx), 7);
    });

    test('resolves transitively through chained references', () {
      final ctx = _ctxFor('a = b\nb = c\nc = "leaf"');
      expect(evaluate(const Reference('a', offset: 0), ctx), 'leaf');
    });

    test('returns null for an unknown name without recording an error', () {
      final ctx = _ctxFor('');
      expect(evaluate(const Reference('missing', offset: 0), ctx), isNull);
      expect(ctx.errors, isEmpty);
    });

    test('query reference uses resolveRef', () {
      final program = parseProgram(
        'data = Query("fetch", {}, {rows: []})',
      );
      final ctx = EvalContext(
        statements: program.statements,
        store: Store(),
        resolveRef: (name) => name == 'data'
            ? const {
                'rows': [1],
              }
            : null,
      );
      expect(
        evaluate(const Reference('data', offset: 0), ctx),
        const {
          'rows': [1],
        },
      );
    });

    test(
      'Mutation reference resolves to null (no value semantics)',
      () {
        final program = parseProgram('del = Mutation(name: "delete")');
        final ctx = EvalContext(
          statements: program.statements,
          store: Store(),
        );
        expect(
          evaluate(const Reference('del', offset: 0), ctx),
          isNull,
        );
      },
    );

    test('cycle emits CyclicStateError and returns null', () {
      final ctx = _ctxFor('a = b\nb = a');
      final result = evaluate(const Reference('a', offset: 0), ctx);
      expect(result, isNull);
      expect(ctx.errors, hasLength(1));
      final err = ctx.errors.single as CyclicStateError;
      // The cycle starts at whichever side we kicked off — `a` here.
      expect(err.cycle, contains('a'));
      expect(err.cycle, contains('b'));
    });
  });

  group('StateRef', () {
    test('reads a value from the store using the dollar-prefixed key', () {
      final store = Store()..set(r'$count', 5);
      final ctx = EvalContext(
        statements: const [],
        store: store,
      );
      expect(evaluate(const StateRef('count', offset: 0), ctx), 5);
    });

    test('returns null when the store has no binding for the var', () {
      final ctx = _ctxFor('');
      expect(evaluate(const StateRef('count', offset: 0), ctx), isNull);
    });

    test('iterationVars take precedence over the store', () {
      final store = Store()..set(r'$item', 'store-value');
      final ctx = EvalContext(
        statements: const [],
        store: store,
        iterationVars: const {r'$item': 'iter-value'},
      );
      expect(
        evaluate(const StateRef('item', offset: 0), ctx),
        'iter-value',
      );
    });
  });

  group('StateAssign', () {
    test('writes back into the store with the dollar-prefixed key', () {
      final store = Store();
      final ctx = EvalContext(statements: const [], store: store);
      final ast = _rhsOf(r'a = ($count = 9)', 'a');
      final v = evaluate(ast, ctx);
      expect(v, 9);
      expect(store.get(r'$count'), 9);
    });
  });

  group('ArrayLit and ObjectLit', () {
    test('ArrayLit evaluates each element via the surrounding context', () {
      // The RHS references `x`, so the context must contain `x = 2`.
      final ctx = _ctxFor('a = [1, x, 3]\nx = 2');
      final ast = _rhsOf('a = [1, x, 3]\nx = 2', 'a');
      expect(evaluate(ast, ctx), [1, 2, 3]);
    });

    test('ObjectLit evaluates each value, keys are literal', () {
      final ast = _rhsOf('o = {a: 1, b: "hi"}', 'o');
      expect(
        evaluate(ast, _ctxFor('')),
        equals({'a': 1, 'b': 'hi'}),
      );
    });
  });

  group('binary operators', () {
    test('+ on numbers', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = 2 + 3', 'a'), ctx), 5);
    });

    test('+ on strings concatenates', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = "hi " + "there"', 'a'), ctx), 'hi there');
    });

    test('+ on string and number stringifies the number', () {
      final ctx = _ctxFor(r'$count = 0', store: Store()..set(r'$count', 7));
      expect(
        evaluate(_rhsOf(r'a = "Count: " + $count', 'a'), ctx),
        'Count: 7',
      );
    });

    test('+ on number and string stringifies the number on the left', () {
      final ctx = _ctxFor('');
      expect(
        evaluate(_rhsOf('a = 7 + " items"', 'a'), ctx),
        '7 items',
      );
    });

    test('+ on null both sides resolves to null', () {
      final ctx = _ctxFor('');
      expect(
        evaluate(_rhsOf('a = missingA + missingB', 'a'), ctx),
        isNull,
      );
    });

    test('+ concatenates two lists', () {
      final ctx = _ctxFor('');
      expect(
        evaluate(_rhsOf('a = [1] + [2, 3]', 'a'), ctx),
        orderedEquals(<Object?>[1, 2, 3]),
      );
    });

    test('+ treats null lhs as empty list when rhs is a list', () {
      final ctx = _ctxFor(
        '',
        store: Store()..set(r'$inputText', 'hi'),
      );
      expect(
        evaluate(_rhsOf(r'a = $history + [$inputText]', 'a'), ctx),
        orderedEquals(<Object?>['hi']),
      );
    });

    test('+ treats null rhs as empty list when lhs is a list', () {
      final ctx = _ctxFor(
        '',
        store: Store()..set(r'$xs', <Object?>[1, 2]),
      );
      expect(
        evaluate(_rhsOf(r'a = $xs + $absent', 'a'), ctx),
        orderedEquals(<Object?>[1, 2]),
      );
    });

    test('- on numbers', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = 5 - 2', 'a'), ctx), 3);
    });

    test('- with a non-number returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = "x" - 1', 'a'), ctx), isNull);
    });

    test('* on numbers', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = 4 * 2', 'a'), ctx), 8);
    });

    test('* with a non-number returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = "x" * 2', 'a'), ctx), isNull);
    });

    test('/ on numbers', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = 10 / 4', 'a'), ctx), 2.5);
    });

    test('/ by zero returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = 10 / 0', 'a'), ctx), isNull);
    });

    test('/ with a non-number returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = "x" / 2', 'a'), ctx), isNull);
    });

    test('% on numbers', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = 10 % 3', 'a'), ctx), 1);
    });

    test('% by zero returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = 10 % 0', 'a'), ctx), isNull);
    });

    test('% with a non-number returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = "x" % 2', 'a'), ctx), isNull);
    });

    test('==, != with primitives', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = 1 == 1', 'a'), ctx), true);
      expect(evaluate(_rhsOf('a = 1 == 2', 'a'), ctx), false);
      expect(evaluate(_rhsOf('a = "x" != "y"', 'a'), ctx), true);
    });

    test('== with one null operand', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = null == 1', 'a'), ctx), false);
      expect(evaluate(_rhsOf('a = 1 == null', 'a'), ctx), false);
      expect(evaluate(_rhsOf('a = null == null', 'a'), ctx), true);
    });

    test('<, >, <=, >= on numbers', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = 1 < 2', 'a'), ctx), true);
      expect(evaluate(_rhsOf('a = 2 > 1', 'a'), ctx), true);
      expect(evaluate(_rhsOf('a = 1 <= 1', 'a'), ctx), true);
      expect(evaluate(_rhsOf('a = 1 >= 2', 'a'), ctx), false);
    });

    test('<, >, <=, >= on non-numbers return null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = "x" < 1', 'a'), ctx), isNull);
      expect(evaluate(_rhsOf('a = "x" > 1', 'a'), ctx), isNull);
      expect(evaluate(_rhsOf('a = "x" <= 1', 'a'), ctx), isNull);
      expect(evaluate(_rhsOf('a = "x" >= 1', 'a'), ctx), isNull);
    });

    test('&& short-circuits on a falsy left and returns the left', () {
      final ctx = _ctxFor('');
      // `false && <anything>` returns false without evaluating right.
      expect(evaluate(_rhsOf('a = false && true', 'a'), ctx), false);
    });

    test('&& with truthy left returns the right operand', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = true && "yes"', 'a'), ctx), 'yes');
    });

    test('|| short-circuits on a truthy left and returns the left', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = "x" || "y"', 'a'), ctx), 'x');
    });

    test('|| with falsy left returns the right operand', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = false || "fallback"', 'a'), ctx), 'fallback');
    });
  });

  group('UnaryOp', () {
    test('! flips truthiness', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = !true', 'a'), ctx), false);
      expect(evaluate(_rhsOf('a = !false', 'a'), ctx), true);
      // ! on null is true (null is falsy).
      expect(evaluate(_rhsOf('a = !missing', 'a'), ctx), true);
    });

    test('- negates a number', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = -7', 'a'), ctx), -7);
    });

    test('- on a non-number returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = -"hi"', 'a'), ctx), isNull);
    });
  });

  group('Ternary', () {
    test('truthy condition picks the then branch (lazy)', () {
      final ctx = _ctxFor('');
      expect(
        evaluate(_rhsOf('a = 1 == 1 ? "yes" : "no"', 'a'), ctx),
        'yes',
      );
    });

    test('falsy condition picks the otherwise branch', () {
      final ctx = _ctxFor('');
      expect(
        evaluate(_rhsOf('a = 1 == 2 ? "yes" : "no"', 'a'), ctx),
        'no',
      );
    });
  });

  group('MemberAccess', () {
    test('on an object returns the field value', () {
      final ctx = _ctxFor('o = {field: "hi"}');
      expect(
        evaluate(_rhsOf('a = o.field\no = {field: "hi"}', 'a'), ctx),
        'hi',
      );
    });

    test('.length on a list returns the length', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = [1, 2, 3].length', 'a'), ctx), 3);
    });

    test('.length on a string returns the character count', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = "hello".length', 'a'), ctx), 5);
    });

    test('on null returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = missing.field', 'a'), ctx), isNull);
    });

    test('on a list with non-length getter returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = [1].first', 'a'), ctx), isNull);
    });
  });

  group('IndexAccess', () {
    test('on a list with a valid integer index', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = [10, 20, 30][1]', 'a'), ctx), 20);
    });

    test('on a list with an out-of-range index returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = [1, 2][5]', 'a'), ctx), isNull);
    });

    test('on a list with a negative index returns null', () {
      // Construct manually since the parser does not allow negative
      // numeric literals as index expressions in v0.1 unary form ...
      // actually `-1` is UnaryOp(-, 1), which evaluates to -1. The
      // evaluator should clamp out-of-range to null.
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = [1, 2][-1]', 'a'), ctx), isNull);
    });

    test('on a list with a non-int index returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = [1, 2]["x"]', 'a'), ctx), isNull);
    });

    test('on a map with a string key', () {
      final ctx = _ctxFor('');
      expect(
        evaluate(_rhsOf('a = {k: "v"}["k"]', 'a'), ctx),
        'v',
      );
    });

    test('on a map with a non-string key returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = {k: 1}[0]', 'a'), ctx), isNull);
    });

    test('on a null target returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = missing[0]', 'a'), ctx), isNull);
    });
  });

  group('BuiltinCall dispatch', () {
    test('registered handler is invoked with the call and context', () {
      var receivedName = '';
      final ctx = EvalContext(
        statements: const [],
        store: Store(),
        builtins: {
          '@Echo': (call, ctx) {
            receivedName = call.name;
            return 42;
          },
        },
      );
      final ast = _rhsOf('a = @Echo()', 'a');
      expect(evaluate(ast, ctx), 42);
      expect(receivedName, '@Echo');
    });

    test('unregistered builtin emits an EvaluationError and returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = @Each()', 'a'), ctx), isNull);
      expect(ctx.errors, hasLength(1));
      expect(ctx.errors.single, isA<EvaluationError>());
      expect((ctx.errors.single as EvaluationError).message, contains('@Each'));
    });
  });

  group('Action expression', () {
    test('Action([@Set(...), @Run(...)]) evaluates to ActionPlan', () {
      final ctx = _ctxFor('load = Mutation(name: "x", args: {})\n');
      final plan = evaluate(
        _rhsOf(r'a = Action([@Set($count, 1), @Run(load)])', 'a'),
        ctx,
      );
      expect(plan, isA<ActionPlan>());
      final actionPlan = plan! as ActionPlan;
      expect(actionPlan.steps, hasLength(2));
      expect(actionPlan.steps[0], isA<SetStep>());
      expect(actionPlan.steps[1], isA<RunStep>());
    });

    test('bare array literal does not evaluate to ActionPlan', () {
      final ctx = _ctxFor('');
      expect(
        evaluate(_rhsOf(r'a = [@Set($count, 1)]', 'a'), ctx),
        isA<List<Object?>>(),
      );
    });

    test('submit = Action([...]) resolves through Reference', () {
      final ctx = _ctxFor(
        r'submit = Action([@Set($count, 1)])'
        '\n'
        'btn = submit\n',
      );
      final plan = evaluate(_rhsOf('x = btn', 'x'), ctx);
      expect(plan, isA<ActionPlan>());
    });
  });

  group('non-value AST nodes in expression position', () {
    test('CompCall emits an error and returns null', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = Stack()', 'a'), ctx), isNull);
      expect(ctx.errors.single, isA<EvaluationError>());
      expect(
        (ctx.errors.single as EvaluationError).message,
        contains('Stack'),
      );
    });

    test('MutationCall in expression position emits an error', () {
      final ctx = _ctxFor('');
      final ast = _rhsOf('a = [Mutation(name: "x")]', 'a');
      expect(evaluate(ast, ctx), [null]);
      expect(ctx.errors.single, isA<EvaluationError>());
    });
  });

  group('truthiness rules drive ! and short-circuiting', () {
    test('null, 0, empty string, empty list, empty map are falsy', () {
      final ctx = _ctxFor('');
      // Use ! to query truthiness.
      expect(evaluate(_rhsOf('a = !missing', 'a'), ctx), true);
      expect(evaluate(_rhsOf('a = !0', 'a'), ctx), true);
      expect(evaluate(_rhsOf('a = !""', 'a'), ctx), true);
      expect(evaluate(_rhsOf('a = ![]', 'a'), ctx), true);
      expect(evaluate(_rhsOf('a = !{}', 'a'), ctx), true);
    });

    test('non-zero number, non-empty string, list, map are truthy', () {
      final ctx = _ctxFor('');
      expect(evaluate(_rhsOf('a = !1', 'a'), ctx), false);
      expect(evaluate(_rhsOf('a = !"hi"', 'a'), ctx), false);
      expect(evaluate(_rhsOf('a = ![1]', 'a'), ctx), false);
      expect(evaluate(_rhsOf('a = !{k: 1}', 'a'), ctx), false);
    });

    test("an opaque truthy fallback (object that isn't one of the above)", () {
      // Construct a builtin that returns a custom Object? — exercises
      // the `_isTruthy` final fall-through branch.
      final ctx = EvalContext(
        statements: const [],
        store: Store(),
        builtins: {
          '@Opaque': (call, ctx) => Object(),
        },
      );
      // !@Opaque() should be false because the return value is truthy.
      expect(evaluate(_rhsOf('a = !@Opaque()', 'a'), ctx), false);
    });
  });
}
