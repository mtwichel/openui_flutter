// Materializer contract tests.
//
// Drives `materialize()` through every shape its reachability walker
// has to traverse, plus the unresolved/orphaned/partial cases the
// renderer relies on. ElementNode's value-type contract (==, hashCode,
// toString, typeName) is also exercised here.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('ElementNode', () {
    test('equality is structural and ignores field-order accidents', () {
      const a = ElementNode(
        expression: Literal(1, offset: 0),
        statementId: 'x',
        partial: false,
      );
      const b = ElementNode(
        expression: Literal(1, offset: 9),
        statementId: 'x',
        partial: false,
      );
      expect(a, equals(b));
      expect({a, b}, hasLength(1));
      // Differs by partial.
      expect(
        a,
        isNot(
          equals(
            const ElementNode(
              expression: Literal(1, offset: 0),
              statementId: 'x',
              partial: true,
            ),
          ),
        ),
      );
      // Differs by statementId.
      expect(
        a,
        isNot(
          equals(
            const ElementNode(
              expression: Literal(1, offset: 0),
              statementId: 'y',
              partial: false,
            ),
          ),
        ),
      );
      // Differs by expression.
      expect(
        a,
        isNot(
          equals(
            const ElementNode(
              expression: Literal(2, offset: 0),
              statementId: 'x',
              partial: false,
            ),
          ),
        ),
      );
    });

    test('toString includes statementId and partial marker', () {
      const live = ElementNode(
        expression: Literal('hi', offset: 0),
        statementId: 'msg',
        partial: false,
      );
      const stale = ElementNode(
        expression: Literal('hi', offset: 0),
        statementId: 'msg',
        partial: true,
      );
      expect(live.toString(), contains('msg'));
      expect(live.toString(), isNot(contains('partial')));
      expect(stale.toString(), contains('partial'));
    });

    test('typeName resolves CompCall, BuiltinCall, Query, Mutation', () {
      ElementNode wrap(AstNode expr) => ElementNode(
        expression: expr,
        statementId: 'x',
        partial: false,
      );

      expect(wrap(CompCall('Stack', const [], offset: 0)).typeName, 'Stack');
      expect(
        wrap(BuiltinCall('@Each', const [], offset: 0)).typeName,
        '@Each',
      );
      expect(wrap(QueryCall(const [], offset: 0)).typeName, 'Query');
      expect(wrap(MutationCall(const [], offset: 0)).typeName, 'Mutation');
      expect(wrap(const Literal('hi', offset: 0)).typeName, isNull);
      expect(wrap(const Reference('foo', offset: 0)).typeName, isNull);
    });
  });

  group('materialize', () {
    test('empty statements: rootName goes to unresolved, no orphans', () {
      final result = materialize(rootName: 'root', statements: const []);
      expect(result.root, isNull);
      expect(result.unresolved, ['root']);
      expect(result.orphaned, isEmpty);
    });

    test('single root statement: reachable, no unresolved, no orphans', () {
      final program = parseProgram('root = "hi"');
      final result = materialize(
        rootName: 'root',
        statements: program.statements,
      );
      expect(result.root, isNotNull);
      expect(result.root!.statementId, 'root');
      expect(result.unresolved, isEmpty);
      expect(result.orphaned, isEmpty);
    });

    test(
      'forward reference hoists: root references chart defined later',
      () {
        final program = parseProgram(
          'root = Stack([chart])\nchart = "data"',
        );
        final result = materialize(
          rootName: 'root',
          statements: program.statements,
        );
        expect(result.unresolved, isEmpty);
        expect(result.orphaned, isEmpty);
      },
    );

    test('unresolved reference inside a reachable statement', () {
      final program = parseProgram('root = Stack([missing])');
      final result = materialize(
        rootName: 'root',
        statements: program.statements,
      );
      expect(result.unresolved, ['missing']);
      expect(result.orphaned, isEmpty);
    });

    test('orphaned value statement: defined but unreachable', () {
      final program = parseProgram(
        'root = "hi"\norphan = "unused"',
      );
      final result = materialize(
        rootName: 'root',
        statements: program.statements,
      );
      expect(result.unresolved, isEmpty);
      expect(result.orphaned, ['orphan']);
    });

    test('cyclic refs do not loop forever and both nodes are reachable', () {
      final program = parseProgram('root = a\na = b\nb = a');
      final result = materialize(
        rootName: 'root',
        statements: program.statements,
      );
      expect(result.unresolved, isEmpty);
      expect(result.orphaned, isEmpty);
    });

    test('rootName not in statements: missing goes to unresolved', () {
      final program = parseProgram('chart = "data"');
      final result = materialize(
        rootName: 'main',
        statements: program.statements,
      );
      expect(result.root, isNull);
      expect(result.unresolved, ['main']);
      // chart is a value statement but isn't reachable from the
      // missing root, so it lands in orphans.
      expect(result.orphaned, ['chart']);
    });

    test('state, query, and mutation decls are excluded from orphans', () {
      final program = parseProgram(
        'root = "hi"\n'
        r'$count = 0'
        '\n'
        'users = Query(name: "list")\n'
        'del = Mutation(name: "delete")\n',
      );
      final result = materialize(
        rootName: 'root',
        statements: program.statements,
      );
      // None of the meta statements show up as orphans even though
      // they are not reachable from `root`.
      expect(result.orphaned, isEmpty);
    });

    test('partial flag: rootName in incomplete bubbles into the root', () {
      final program = parseProgram('root = Stack()');
      final result = materialize(
        rootName: 'root',
        statements: program.statements,
        incomplete: const {'root'},
      );
      expect(result.root!.partial, isTrue);
    });

    test(
      'partial flag is false when rootName is not in the incomplete set',
      () {
        final program = parseProgram('root = Stack()');
        final result = materialize(
          rootName: 'root',
          statements: program.statements,
          incomplete: const {'somethingElse'},
        );
        expect(result.root!.partial, isFalse);
      },
    );

    test('re-assignment is last-write-wins (handled via the map)', () {
      final program = parseProgram('root = "first"\nroot = "second"');
      final result = materialize(
        rootName: 'root',
        statements: program.statements,
      );
      // The root carries the last definition's expression.
      expect(
        (result.root!.expression as Literal).value,
        'second',
      );
      // Neither occurrence of `root` is orphaned since the last write
      // is the reachable one.
      expect(result.orphaned, isEmpty);
    });
  });

  group('reachability walker covers every AST shape', () {
    // Every test in this group constructs a reachable statement whose
    // expression embeds a Reference to "target", then asserts that
    // target was visited (no unresolved, no orphans). The expression
    // is the "RHS" half of `_collectReferences` — the goal is to walk
    // every case in the switch.
    //
    // A separate test confirms that Reference does *not* recurse
    // through StateRef (state lookups are runtime, not statement-id
    // edges).

    void expectTargetReachable(String rhs) {
      final program = parseProgram('root = $rhs\ntarget = "value"');
      final result = materialize(
        rootName: 'root',
        statements: program.statements,
      );
      // `target` is the canary; other free identifiers in the RHS
      // (e.g. `row` in `@Each(target, row)`) are allowed to land in
      // unresolved without failing the case.
      expect(
        result.unresolved,
        isNot(contains('target')),
        reason: 'expected `target` reachable through RHS: $rhs',
      );
      expect(result.orphaned, isNot(contains('target')), reason: rhs);
    }

    test('BinaryOp', () => expectTargetReachable('1 + target'));
    test('UnaryOp', () => expectTargetReachable('!target'));
    test(
      'Ternary',
      () => expectTargetReachable('1 == 1 ? target : "fallback"'),
    );
    test('MemberAccess', () => expectTargetReachable('target.name'));
    test('IndexAccess', () => expectTargetReachable('target[0]'));
    test('ArrayLit', () => expectTargetReachable('[1, target, 3]'));
    test('ObjectLit', () => expectTargetReachable('{key: target}'));
    test('CompCall args', () => expectTargetReachable('Stack([target])'));
    test(
      'BuiltinCall args',
      () => expectTargetReachable('@Each(target, "r", row)'),
    );
    test(
      'QueryCall args',
      () => expectTargetReachable('Query(args: target)'),
    );
    test(
      'MutationCall args',
      () => expectTargetReachable('Mutation(args: target)'),
    );

    test(r'StateAssign value: ($x = target)', () {
      // StateAssign as a sub-expression is rare but legal; the value
      // side may carry a reference.
      expectTargetReachable(r'($x = target)');
    });

    test('Literal RHS does not produce any references', () {
      final program = parseProgram('root = 42');
      final result = materialize(
        rootName: 'root',
        statements: program.statements,
      );
      expect(result.unresolved, isEmpty);
    });

    test('NullLiteral RHS does not produce any references', () {
      final program = parseProgram('root = null');
      final result = materialize(
        rootName: 'root',
        statements: program.statements,
      );
      expect(result.unresolved, isEmpty);
    });

    test(
      'StateRef does NOT bind through the statement-id graph',
      () {
        // `target` is *not* defined; the only reference inside the RHS
        // is `$count`, which is a state lookup, so the materializer
        // must not produce any unresolved entries.
        final program = parseProgram(r'root = $count + 1');
        final result = materialize(
          rootName: 'root',
          statements: program.statements,
        );
        expect(result.unresolved, isEmpty);
      },
    );
  });

  group('ParseResult integration', () {
    test('streaming parser populates root, unresolved, and orphaned', () {
      final parser = createStreamingParser();
      final result = parser.push(
        'root = Stack([chart])\nunused = "x"\n',
      );
      // root is reachable.
      expect(result.root, isNotNull);
      expect(result.root!.statementId, 'root');
      // chart is not yet defined.
      expect(result.meta.unresolved, ['chart']);
      // unused is a value statement not reachable from root.
      expect(result.meta.orphaned, ['unused']);
    });

    test('custom rootName is honored through the streaming parser', () {
      final parser = createStreamingParser(rootName: 'main');
      final result = parser.push('main = "ok"\n');
      expect(result.root!.statementId, 'main');
      expect(result.meta.unresolved, isEmpty);
    });

    test(
      'streaming parser propagates incomplete into the root partial flag',
      () {
        final parser = createStreamingParser();
        // No trailing newline → root is in the tail, flagged incomplete.
        final result = parser.push('root = Stack()');
        expect(result.root!.partial, isTrue);
      },
    );
  });
}
