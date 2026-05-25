// Parser contract tests.
//
// Exercises the AST, the Pratt expression parser, the statement parser
// and classifier, the public `parseProgram`/`parseExpression` entry
// points, and the streaming-helper `autoClose`. These tests are the
// floor: every operator-precedence rule, every statement kind, every
// error path the parser raises, and every branch of `autoClose` is
// covered. The streaming parser, materializer, and evaluator add their
// own contract suites in subsequent tasks.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('AST equality and identity', () {
    test('Literal equality ignores offset', () {
      expect(
        const Literal('hi', offset: 0),
        equals(const Literal('hi', offset: 99)),
      );
      expect(
        const Literal(1, offset: 0),
        isNot(equals(const Literal(2, offset: 0))),
      );
      expect(
        const Literal(1, offset: 0).hashCode,
        equals(const Literal(1, offset: 7).hashCode),
      );
      // Reflexive.
      const lit = Literal('x', offset: 0);
      expect(lit, equals(lit));
      // Set membership exercises hashCode.
      expect({lit}, contains(const Literal('x', offset: 42)));
      expect(lit.toString(), 'Literal("x")');
      expect(const Literal(1, offset: 0).toString(), 'Literal(1)');
    });

    test('NullLiteral equality and toString', () {
      expect(
        const NullLiteral(offset: 0),
        equals(const NullLiteral(offset: 9)),
      );
      expect(
        const NullLiteral(offset: 0),
        isNot(equals(const Literal(null, offset: 0))),
      );
      expect(const NullLiteral(offset: 0).hashCode, isNot(0));
      expect(const NullLiteral(offset: 0).toString(), 'NullLiteral');
    });

    test('Reference / StateRef equality and toString', () {
      expect(
        const Reference('a', offset: 0),
        equals(const Reference('a', offset: 4)),
      );
      expect(
        const Reference('a', offset: 0),
        isNot(equals(const Reference('b', offset: 0))),
      );
      expect(
        const StateRef('x', offset: 0),
        equals(const StateRef('x', offset: 4)),
      );
      expect(
        const StateRef('x', offset: 0),
        isNot(equals(const Reference('x', offset: 0))),
      );
      expect(const Reference('a', offset: 0).toString(), 'Reference(a)');
      expect(const StateRef('x', offset: 0).toString(), r'StateRef($x)');
    });

    test('StateAssign / BinaryOp / UnaryOp / Ternary equality', () {
      const a = StateAssign('x', Literal(1, offset: 0), offset: 0);
      const b = StateAssign('x', Literal(1, offset: 99), offset: 99);
      expect(a, equals(b));
      expect(
        a,
        isNot(equals(const StateAssign('y', Literal(1, offset: 0), offset: 0))),
      );

      const left = Literal(1, offset: 0);
      const right = Literal(2, offset: 0);
      expect(
        const BinaryOp('+', left, right, offset: 0),
        equals(const BinaryOp('+', left, right, offset: 9)),
      );
      expect(
        const BinaryOp('+', left, right, offset: 0),
        isNot(equals(const BinaryOp('-', left, right, offset: 0))),
      );

      expect(
        const UnaryOp('-', left, offset: 0),
        equals(const UnaryOp('-', left, offset: 7)),
      );
      expect(
        const UnaryOp('-', left, offset: 0),
        isNot(equals(const UnaryOp('!', left, offset: 0))),
      );

      const t1 = Ternary(left, right, left, offset: 0);
      const t2 = Ternary(left, right, left, offset: 5);
      expect(t1, equals(t2));
      expect(
        t1,
        isNot(equals(const Ternary(left, right, right, offset: 0))),
      );
    });

    test('MemberAccess / IndexAccess equality', () {
      const base = Reference('foo', offset: 0);
      expect(
        const MemberAccess(base, 'bar', offset: 0),
        equals(const MemberAccess(base, 'bar', offset: 9)),
      );
      expect(
        const MemberAccess(base, 'bar', offset: 0),
        isNot(equals(const MemberAccess(base, 'baz', offset: 0))),
      );

      const idx = Literal(0, offset: 0);
      expect(
        const IndexAccess(base, idx, offset: 0),
        equals(const IndexAccess(base, idx, offset: 9)),
      );
      expect(
        const IndexAccess(base, idx, offset: 0),
        isNot(
          equals(const IndexAccess(base, Literal(1, offset: 0), offset: 0)),
        ),
      );
    });

    test('ArrayLit / ObjectLit / ObjectEntry equality', () {
      final entries = [
        const ObjectEntry('a', Literal(1, offset: 0), offset: 0),
      ];
      expect(
        ArrayLit(const [Literal(1, offset: 0)], offset: 0),
        equals(ArrayLit(const [Literal(1, offset: 9)], offset: 9)),
      );
      expect(
        ArrayLit(const [Literal(1, offset: 0)], offset: 0),
        isNot(equals(ArrayLit(const [Literal(2, offset: 0)], offset: 0))),
      );
      expect(
        ArrayLit(const [Literal(1, offset: 0)], offset: 0),
        isNot(equals(ArrayLit(const [], offset: 0))),
      );
      expect(
        ObjectLit(entries, offset: 0),
        equals(ObjectLit(entries, offset: 9)),
      );
      expect(
        ObjectLit(entries, offset: 0),
        isNot(equals(ObjectLit(const [], offset: 0))),
      );
      expect(entries.first, equals(entries.first));
      expect(
        entries.first,
        isNot(equals(const ObjectEntry('a', Literal(2, offset: 0), offset: 0))),
      );
      expect(entries.first.toString(), 'a: Literal(1)');

      // ArrayLit elements are unmodifiable.
      final lit = ArrayLit(const [Literal(1, offset: 0)], offset: 0);
      expect(
        () => lit.elements.add(const Literal(2, offset: 0)),
        throwsUnsupportedError,
      );
    });

    test('CompCall / BuiltinCall / MutationCall equality', () {
      final args = [
        const Argument(value: Literal(1, offset: 0), offset: 0),
      ];
      expect(
        CompCall('Stack', args, offset: 0),
        equals(CompCall('Stack', args, offset: 9)),
      );
      expect(
        CompCall('Stack', args, offset: 0),
        isNot(equals(CompCall('Card', args, offset: 0))),
      );
      expect(
        BuiltinCall('@Each', args, offset: 0),
        equals(BuiltinCall('@Each', args, offset: 9)),
      );
      expect(
        BuiltinCall('@Each', args, offset: 0),
        isNot(equals(BuiltinCall('@Set', args, offset: 0))),
      );
      expect(
        MutationCall(args, offset: 0),
        equals(MutationCall(args, offset: 9)),
      );
      expect(
        MutationCall(args, offset: 0),
        isNot(equals(MutationCall(const <Argument>[], offset: 0))),
      );
    });

    test('Argument named vs positional equality and toString', () {
      const value = Literal(1, offset: 0);
      const positional = Argument(value: value, offset: 0);
      const named = Argument(name: 'k', value: value, offset: 0);
      expect(positional, equals(const Argument(value: value, offset: 9)));
      expect(positional, isNot(equals(named)));
      expect(positional.toString(), 'Literal(1)');
      expect(named.toString(), 'k: Literal(1)');
    });

    test('Statement equality and toString carries kind', () {
      const lit = Literal(1, offset: 0);
      const s1 = Statement(
        name: 'x',
        kind: StatementKind.value,
        expression: lit,
        offset: 0,
      );
      const s2 = Statement(
        name: 'x',
        kind: StatementKind.value,
        expression: lit,
        offset: 99,
      );
      expect(s1, equals(s2));
      expect(
        s1,
        isNot(
          equals(
            const Statement(
              name: 'x',
              kind: StatementKind.state,
              expression: lit,
              offset: 0,
            ),
          ),
        ),
      );
      expect(
        s1,
        isNot(
          equals(
            const Statement(
              name: 'y',
              kind: StatementKind.value,
              expression: lit,
              offset: 0,
            ),
          ),
        ),
      );
      expect(s1.toString(), contains('value'));
    });

    test(
      'classifyStatement uses order-of-checks: Mutation > @Query > '
      'STATEVAR > value',
      () {
        // Mutation regardless of LHS shape.
        expect(
          classifyStatement(
            'x',
            MutationCall(const <Argument>[], offset: 0),
          ),
          StatementKind.mutation,
        );
        expect(
          classifyStatement(
            r'$x',
            MutationCall(const <Argument>[], offset: 0),
          ),
          StatementKind.mutation,
        );
        // @Query builtin classifies as query.
        expect(
          classifyStatement(
            r'$x',
            BuiltinCall('@Query', const <Argument>[], offset: 0),
          ),
          StatementKind.query,
        );
        // STATEVAR LHS with non-call RHS → state.
        expect(
          classifyStatement(r'$count', const Literal(0, offset: 0)),
          StatementKind.state,
        );
        // Default → value.
        expect(
          classifyStatement('greeting', const Literal('hi', offset: 0)),
          StatementKind.value,
        );
      },
    );

    test('AstNode subclasses preserve offset on the node', () {
      expect(const Literal(1, offset: 7).offset, 7);
      expect(const NullLiteral(offset: 9).offset, 9);
      expect(const Reference('a', offset: 5).offset, 5);
    });

    test(
      'hashCode + toString smoke: every AST class collapses in a Set '
      'and prints non-empty',
      () {
        final pairs = <List<AstNode>>[
          [const Literal(1, offset: 0), const Literal(1, offset: 9)],
          [const NullLiteral(offset: 0), const NullLiteral(offset: 9)],
          [const Reference('a', offset: 0), const Reference('a', offset: 9)],
          [const StateRef('x', offset: 0), const StateRef('x', offset: 9)],
          [
            const StateAssign('x', Literal(1, offset: 0), offset: 0),
            const StateAssign('x', Literal(1, offset: 0), offset: 9),
          ],
          [
            ArrayLit(const [Literal(1, offset: 0)], offset: 0),
            ArrayLit(const [Literal(1, offset: 0)], offset: 9),
          ],
          [
            ObjectLit(
              const [ObjectEntry('k', Literal(1, offset: 0), offset: 0)],
              offset: 0,
            ),
            ObjectLit(
              const [ObjectEntry('k', Literal(1, offset: 0), offset: 0)],
              offset: 9,
            ),
          ],
          [
            const BinaryOp(
              '+',
              Literal(1, offset: 0),
              Literal(2, offset: 0),
              offset: 0,
            ),
            const BinaryOp(
              '+',
              Literal(1, offset: 0),
              Literal(2, offset: 0),
              offset: 9,
            ),
          ],
          [
            const UnaryOp('-', Literal(1, offset: 0), offset: 0),
            const UnaryOp('-', Literal(1, offset: 0), offset: 9),
          ],
          [
            const Ternary(
              Literal(true, offset: 0),
              Literal(1, offset: 0),
              Literal(2, offset: 0),
              offset: 0,
            ),
            const Ternary(
              Literal(true, offset: 0),
              Literal(1, offset: 0),
              Literal(2, offset: 0),
              offset: 9,
            ),
          ],
          [
            const MemberAccess(
              Reference('foo', offset: 0),
              'bar',
              offset: 0,
            ),
            const MemberAccess(
              Reference('foo', offset: 0),
              'bar',
              offset: 9,
            ),
          ],
          [
            const IndexAccess(
              Reference('foo', offset: 0),
              Literal(0, offset: 0),
              offset: 0,
            ),
            const IndexAccess(
              Reference('foo', offset: 0),
              Literal(0, offset: 0),
              offset: 9,
            ),
          ],
          [
            CompCall('Stack', const [], offset: 0),
            CompCall('Stack', const [], offset: 9),
          ],
          [
            BuiltinCall('@Each', const [], offset: 0),
            BuiltinCall('@Each', const [], offset: 9),
          ],
          [
            MutationCall(const <Argument>[], offset: 0),
            MutationCall(const <Argument>[], offset: 9),
          ],
        ];
        for (final pair in pairs) {
          final reason = pair.first.runtimeType.toString();
          expect({pair[0], pair[1]}, hasLength(1), reason: reason);
          expect(pair[0].toString(), isNotEmpty, reason: reason);
        }

        // Argument, ObjectEntry, and Statement are not AstNodes but share
        // the same equality/hashCode/toString contract.
        const argA = Argument(value: Literal(1, offset: 0), offset: 0);
        const argB = Argument(value: Literal(1, offset: 0), offset: 9);
        expect({argA, argB}, hasLength(1));
        expect(argA.toString(), isNotEmpty);

        const entryA = ObjectEntry('k', Literal(1, offset: 0), offset: 0);
        const entryB = ObjectEntry('k', Literal(1, offset: 0), offset: 9);
        expect({entryA, entryB}, hasLength(1));
        expect(entryA.toString(), isNotEmpty);

        const stmtA = Statement(
          name: 'x',
          kind: StatementKind.value,
          expression: Literal(1, offset: 0),
          offset: 0,
        );
        const stmtB = Statement(
          name: 'x',
          kind: StatementKind.value,
          expression: Literal(1, offset: 0),
          offset: 9,
        );
        expect({stmtA, stmtB}, hasLength(1));
        expect(stmtA.toString(), isNotEmpty);
      },
    );
  });

  group('parseExpression', () {
    test('scalar literals', () {
      expect(parseExpression('42'), equals(const Literal(42, offset: 0)));
      expect(parseExpression('3.14'), equals(const Literal(3.14, offset: 0)));
      expect(parseExpression('"hi"'), equals(const Literal('hi', offset: 0)));
      expect(parseExpression('true'), equals(const Literal(true, offset: 0)));
      expect(parseExpression('false'), equals(const Literal(false, offset: 0)));
      expect(parseExpression('null'), equals(const NullLiteral(offset: 0)));
    });

    test('references and state refs', () {
      expect(parseExpression('foo'), equals(const Reference('foo', offset: 0)));
      expect(
        parseExpression(r'$count'),
        equals(const StateRef('count', offset: 0)),
      );
    });

    test('state-assign sub-expression', () {
      // Inside parens so the statement parser doesn't peel off the LHS.
      expect(
        parseExpression(r'($x = 1)'),
        equals(const StateAssign('x', Literal(1, offset: 5), offset: 1)),
      );
    });

    test('arithmetic precedence: 1 + 2 * 3', () {
      expect(
        parseExpression('1 + 2 * 3'),
        equals(
          const BinaryOp(
            '+',
            Literal(1, offset: 0),
            BinaryOp(
              '*',
              Literal(2, offset: 4),
              Literal(3, offset: 8),
              offset: 4,
            ),
            offset: 0,
          ),
        ),
      );
    });

    test('parens override precedence: (1 + 2) * 3', () {
      expect(
        parseExpression('(1 + 2) * 3'),
        equals(
          const BinaryOp(
            '*',
            BinaryOp(
              '+',
              Literal(1, offset: 1),
              Literal(2, offset: 5),
              offset: 1,
            ),
            Literal(3, offset: 10),
            offset: 1,
          ),
        ),
      );
    });

    test('left-associative subtraction: 1 - 2 - 3', () {
      final ast = parseExpression('1 - 2 - 3') as BinaryOp;
      expect(ast.op, '-');
      expect((ast.left as BinaryOp).op, '-');
      expect((ast.left as BinaryOp).left, equals(const Literal(1, offset: 0)));
    });

    test('right-associative ternary: a ? b : c ? d : e', () {
      final ast = parseExpression('a ? b : c ? d : e') as Ternary;
      expect(ast.condition, equals(const Reference('a', offset: 0)));
      expect(ast.then, equals(const Reference('b', offset: 4)));
      // The "otherwise" branch is itself a ternary.
      final inner = ast.otherwise as Ternary;
      expect(inner.condition, equals(const Reference('c', offset: 8)));
      expect(inner.then, equals(const Reference('d', offset: 12)));
      expect(inner.otherwise, equals(const Reference('e', offset: 16)));
    });

    test('logical && binds tighter than ||', () {
      final ast = parseExpression('a || b && c') as BinaryOp;
      expect(ast.op, '||');
      expect((ast.right as BinaryOp).op, '&&');
    });

    test('comparison binds tighter than equality', () {
      final ast = parseExpression('1 < 2 == 3 > 4') as BinaryOp;
      expect(ast.op, '==');
      expect((ast.left as BinaryOp).op, '<');
      expect((ast.right as BinaryOp).op, '>');
    });

    test('all comparison and equality operators round-trip', () {
      for (final op in ['<', '<=', '>', '>=', '==', '!=']) {
        final ast = parseExpression('1 $op 2') as BinaryOp;
        expect(ast.op, op);
      }
    });

    test('all multiplicative operators round-trip', () {
      for (final op in ['*', '/', '%']) {
        final ast = parseExpression('6 $op 2') as BinaryOp;
        expect(ast.op, op);
      }
    });

    test('unary minus binds tighter than addition: -x + y', () {
      final ast = parseExpression('-x + y') as BinaryOp;
      expect(ast.op, '+');
      expect((ast.left as UnaryOp).op, '-');
      expect(
        (ast.left as UnaryOp).operand,
        equals(const Reference('x', offset: 1)),
      );
    });

    test('unary not before logical: !x && y', () {
      final ast = parseExpression('!x && y') as BinaryOp;
      expect(ast.op, '&&');
      expect((ast.left as UnaryOp).op, '!');
    });

    test('postfix binds tighter than unary: -foo.bar', () {
      final ast = parseExpression('-foo.bar') as UnaryOp;
      expect(ast.op, '-');
      expect(ast.operand, isA<MemberAccess>());
      expect((ast.operand as MemberAccess).name, 'bar');
    });

    test('chained member access: foo.bar.baz', () {
      final ast = parseExpression('foo.bar.baz') as MemberAccess;
      expect(ast.name, 'baz');
      expect((ast.target as MemberAccess).name, 'bar');
    });

    test('member access accepts type-cased names: foo.Bar', () {
      final ast = parseExpression('foo.Bar') as MemberAccess;
      expect(ast.name, 'Bar');
    });

    test('index access', () {
      final ast = parseExpression('items[0]') as IndexAccess;
      expect(ast.target, equals(const Reference('items', offset: 0)));
      expect(ast.index, equals(const Literal(0, offset: 6)));
    });

    test('mixed postfix: rows[0].name', () {
      final ast = parseExpression('rows[0].name') as MemberAccess;
      expect(ast.name, 'name');
      expect(ast.target, isA<IndexAccess>());
    });

    test('comp call: Stack()', () {
      expect(
        parseExpression('Stack()'),
        equals(CompCall('Stack', const [], offset: 0)),
      );
    });

    test('comp call with positional args', () {
      final ast = parseExpression('Stack(child)') as CompCall;
      expect(ast.type, 'Stack');
      expect(ast.args, hasLength(1));
      expect(ast.args.first.name, isNull);
      expect(ast.args.first.value, equals(const Reference('child', offset: 6)));
    });

    test('comp call with named arg parses at expression level', () {
      final ast = parseExpression('Stack(child: foo)') as CompCall;
      expect(ast.args.single.name, 'child');
    });

    test(
      'comp call with mixed args + trailing comma parses at expression level',
      () {
        final ast = parseExpression('Stack(a, b: 1, c: 2,)') as CompCall;
        expect(ast.args.map((a) => a.name).toList(), [null, 'b', 'c']);
      },
    );

    test('builtin call: @Each(list, "name", template) parses with 3 args', () {
      final ast = parseExpression('@Each(items, "t", t.name)') as BuiltinCall;
      expect(ast.name, '@Each');
      expect(ast.args, hasLength(3));
      expect(ast.args[1].value, equals(const Literal('t', offset: 13)));
      final tmpl = ast.args[2].value as MemberAccess;
      expect(tmpl.target, equals(const Reference('t', offset: 18)));
      expect(tmpl.name, 'name');
    });

    test('Mutation parses as a MutationCall', () {
      expect(
        parseExpression('Mutation(name: "x")'),
        isA<MutationCall>(),
      );
    });

    test('legacy Query(...) raises a migration ParseException', () {
      expect(
        () => parseExpression('Query(name: "x")'),
        throwsA(
          isA<ParseException>().having(
            (e) => e.message,
            'message',
            contains('@Query'),
          ),
        ),
      );
    });

    test('array literal: empty, simple, trailing comma, newlines', () {
      expect(parseExpression('[]'), equals(ArrayLit(const [], offset: 0)));
      final simple = parseExpression('[1, 2, 3]') as ArrayLit;
      expect(simple.elements, hasLength(3));
      final trailing = parseExpression('[1,]') as ArrayLit;
      expect(trailing.elements, hasLength(1));
      // Newlines inside brackets are insignificant.
      final multiline = parseExpression('[\n  1,\n  2\n]') as ArrayLit;
      expect(multiline.elements, hasLength(2));
    });

    test('object literal: empty, ident keys, string keys, trailing comma', () {
      expect(parseExpression('{}'), equals(ObjectLit(const [], offset: 0)));
      final identKeys = parseExpression('{a: 1, b: 2}') as ObjectLit;
      expect(identKeys.entries.map((e) => e.key).toList(), ['a', 'b']);
      final stringKey = parseExpression('{"hello": 1}') as ObjectLit;
      expect(stringKey.entries.single.key, 'hello');
      final trailing = parseExpression('{a: 1,}') as ObjectLit;
      expect(trailing.entries, hasLength(1));
      final multiline = parseExpression('{\n  a: 1,\n  b: 2\n}') as ObjectLit;
      expect(multiline.entries, hasLength(2));
    });

    test('newlines inside parens and bracket subexpressions skip', () {
      final ast = parseExpression('(\n  1 + 2\n)') as BinaryOp;
      expect(ast.op, '+');
      final indexed = parseExpression('items[\n  0\n]') as IndexAccess;
      expect(indexed.index, equals(const Literal(0, offset: 9)));
    });

    test('trailing newlines after expression are tolerated', () {
      expect(
        parseExpression('1 + 2\n\n'),
        equals(
          const BinaryOp(
            '+',
            Literal(1, offset: 0),
            Literal(2, offset: 4),
            offset: 0,
          ),
        ),
      );
    });
  });

  group('parseExpression error paths', () {
    test('empty input', () {
      expect(
        () => parseExpression(''),
        throwsA(isA<ParseException>()),
      );
    });

    test('bare operator without operands', () {
      expect(() => parseExpression('+'), throwsA(isA<ParseException>()));
    });

    test('unary with no operand', () {
      expect(() => parseExpression('-'), throwsA(isA<ParseException>()));
    });

    test('binary with missing right operand', () {
      expect(() => parseExpression('1 +'), throwsA(isA<ParseException>()));
    });

    test('unbalanced paren', () {
      expect(() => parseExpression('(1 + 2'), throwsA(isA<ParseException>()));
    });

    test('unbalanced bracket', () {
      expect(() => parseExpression('[1, 2'), throwsA(isA<ParseException>()));
    });

    test('unbalanced brace', () {
      expect(() => parseExpression('{a: 1'), throwsA(isA<ParseException>()));
    });

    test('member access with missing name', () {
      expect(() => parseExpression('foo.'), throwsA(isA<ParseException>()));
    });

    test('member access with non-ident name', () {
      expect(() => parseExpression('foo.123'), throwsA(isA<ParseException>()));
    });

    test('unexpected punctuation as unit', () {
      expect(() => parseExpression(':'), throwsA(isA<ParseException>()));
    });

    test('unexpected operator as unit', () {
      expect(() => parseExpression('*'), throwsA(isA<ParseException>()));
    });

    test('object literal with non-ident, non-string key', () {
      expect(
        () => parseExpression('{1: 2}'),
        throwsA(isA<ParseException>()),
      );
    });

    test('array missing comma', () {
      expect(
        () => parseExpression('[1 2]'),
        throwsA(isA<ParseException>()),
      );
    });

    test('arg list missing comma', () {
      expect(
        () => parseExpression('Stack(a b)'),
        throwsA(isA<ParseException>()),
      );
    });

    test('object missing comma', () {
      expect(
        () => parseExpression('{a: 1 b: 2}'),
        throwsA(isA<ParseException>()),
      );
    });

    test('trailing tokens after expression', () {
      expect(
        () => parseExpression('1 + 2 foo'),
        throwsA(isA<ParseException>()),
      );
    });

    test('builtin without arg list', () {
      expect(
        () => parseExpression('@Each'),
        throwsA(isA<ParseException>()),
      );
    });

    test('comp call without arg list', () {
      expect(
        () => parseExpression('Stack'),
        throwsA(isA<ParseException>()),
      );
    });

    test('ParseException toString includes offset', () {
      try {
        parseExpression('  +');
        fail('expected throw');
      } on ParseException catch (e) {
        expect(e.toString(), contains('offset 2'));
        expect(e.message, isNotEmpty);
      }
    });
  });

  group('parseProgram', () {
    test('empty input returns empty program', () {
      final program = parseProgram('');
      expect(program.statements, isEmpty);
      expect(program.errors, isEmpty);
    });

    test('whitespace-only input returns empty program', () {
      final program = parseProgram('\n\n   \n');
      expect(program.statements, isEmpty);
      expect(program.errors, isEmpty);
    });

    test('single value statement', () {
      final program = parseProgram('greeting = "Hello"');
      expect(program.errors, isEmpty);
      expect(program.statements, hasLength(1));
      final s = program.statements.single;
      expect(s.name, 'greeting');
      expect(s.kind, StatementKind.value);
      expect(s.expression, equals(const Literal('Hello', offset: 11)));
    });

    test('multiple statements separated by newlines', () {
      final program = parseProgram('a = 1\nb = 2\nc = a + b');
      expect(program.errors, isEmpty);
      expect(program.statements, hasLength(3));
      expect(program.statements.map((s) => s.name).toList(), ['a', 'b', 'c']);
    });

    test('blank lines between statements are tolerated', () {
      final program = parseProgram('a = 1\n\n\nb = 2');
      expect(program.errors, isEmpty);
      expect(program.statements, hasLength(2));
    });

    test(r'classifies $ LHS as state', () {
      final program = parseProgram(r'$count = 0');
      expect(program.statements.single.kind, StatementKind.state);
      expect(program.statements.single.name, r'$count');
    });

    test(r'classifies $var = @Query(tool) RHS as query', () {
      final program = parseProgram(r'$users = @Query(list_users)');
      expect(program.errors, isEmpty);
      expect(program.statements.single.kind, StatementKind.query);
      final expr = program.statements.single.expression as BuiltinCall;
      expect(expr.name, '@Query');
      expect(expr.args.single.value, isA<Reference>());
    });

    test('legacy users = Query(name: "list") emits a migration error', () {
      final program = parseProgram('users = Query(name: "list")');
      expect(program.errors, hasLength(1));
      expect(program.errors.single.message, contains('@Query'));
    });

    test('@Query with named args yields a QueryDecl-shaped BuiltinCall', () {
      final program = parseProgram(
        r'$products = @Query(fetch_products, category: "shoes")',
      );
      expect(program.errors, isEmpty);
      final expr = program.statements.single.expression as BuiltinCall;
      expect(expr.args.first.value, isA<Reference>());
      expect(expr.args[1].name, 'category');
    });

    test('@Query without a tool name records a ParseException', () {
      final program = parseProgram(r'$x = @Query()');
      expect(program.errors, hasLength(1));
      expect(
        program.errors.single.message,
        contains('tool-name identifier'),
      );
    });

    test('@Query with a string-literal first arg records an error', () {
      final program = parseProgram(r'$x = @Query("not_a_ref")');
      expect(program.errors, hasLength(1));
      expect(
        program.errors.single.message,
        contains('tool-name identifier'),
      );
    });

    test('@Query with extra positional args records an error', () {
      final program = parseProgram(r'$x = @Query(tool, "positional")');
      expect(program.errors, hasLength(1));
      expect(
        program.errors.single.message,
        contains('only accepts named arguments'),
      );
    });

    test('@Query on a value LHS records an error', () {
      final program = parseProgram('data = @Query(tool)');
      expect(program.errors, hasLength(1));
      expect(
        program.errors.single.message,
        contains('must be the entire RHS'),
      );
    });

    test('@Query nested inside an array records an error', () {
      final program = parseProgram('root = Stack([@Query(tool)])');
      expect(program.errors, hasLength(1));
      expect(
        program.errors.single.message,
        contains('must be the entire RHS'),
      );
    });

    test('classifies Mutation RHS as mutation', () {
      final program = parseProgram('del = Mutation(name: "delete")');
      expect(program.statements.single.kind, StatementKind.mutation);
    });

    test('records ParseException and recovers at next newline', () {
      final program = parseProgram('a = 1\nb b\nc = 3');
      expect(program.errors, hasLength(1));
      // a and c parsed; b errored.
      expect(
        program.statements.map((s) => s.name).toList(),
        ['a', 'c'],
      );
    });

    test('error on the last line is captured', () {
      final program = parseProgram('a = 1\n=');
      expect(program.errors, isNotEmpty);
      expect(program.statements.map((s) => s.name).toList(), ['a']);
    });

    test('LHS must be ident, type, or statevar', () {
      final program = parseProgram('1 = 2');
      expect(program.errors, hasLength(1));
      expect(program.statements, isEmpty);
    });

    test('missing = after LHS errors', () {
      final program = parseProgram('a 1');
      expect(program.errors, hasLength(1));
    });

    test('two statements on one line errors', () {
      // The expression `1` parses, then `b = 2` is unexpected.
      final program = parseProgram('a = 1 b = 2');
      expect(program.errors, isNotEmpty);
    });

    test('Type-cased LHS is allowed', () {
      // Re-binding a Type-cased name is unusual but the grammar permits
      // it (TYPE is a valid identifier on the LHS).
      final program = parseProgram('Card = Stack()');
      expect(program.errors, isEmpty);
      expect(program.statements.single.name, 'Card');
    });

    test('named component args record ParseException', () {
      final program = parseProgram('root = Button(label: "x")');
      expect(program.errors, hasLength(1));
      expect(program.errors.single.message, contains('positional'));
    });

    test('mixed positional and named component args record ParseException', () {
      final program = parseProgram('root = Stack([], direction: "row")');
      expect(program.errors, hasLength(1));
      expect(program.errors.single.message, contains('positional'));
    });

    test('@Each shape: 3-arg form parses cleanly', () {
      final program = parseProgram('root = @Each(items, "t", t.name)');
      expect(program.errors, isEmpty);
      expect(program.statements, hasLength(1));
    });

    test('@Each shape: 2-arg form records ParseException', () {
      final program = parseProgram(r'root = @Each(items, $item)');
      expect(program.errors, hasLength(1));
      final msg = program.errors.single.message;
      expect(msg, contains('@Each'));
      expect(msg, contains('3 args'));
    });

    test('@Each shape: 4-arg form records ParseException', () {
      final program = parseProgram('root = @Each(items, "r", row, extra)');
      expect(program.errors, hasLength(1));
      expect(program.errors.single.message, contains('3 args'));
    });

    test('@Each shape: non-literal second arg records ParseException', () {
      final program = parseProgram('root = @Each(items, name, t.x)');
      expect(program.errors, hasLength(1));
      expect(
        program.errors.single.message,
        contains('string identifier'),
      );
    });

    test('@Each shape: reserved name "true" records ParseException', () {
      final program = parseProgram('root = @Each(items, "true", t.x)');
      expect(program.errors, hasLength(1));
      expect(
        program.errors.single.message,
        contains('string identifier'),
      );
    });

    test('@Each shape: empty-string name records ParseException', () {
      final program = parseProgram('root = @Each(items, "", t.x)');
      expect(program.errors, hasLength(1));
      expect(
        program.errors.single.message,
        contains('string identifier'),
      );
    });

    test(r'@Each shape: $-prefixed name records ParseException', () {
      final program = parseProgram(r'root = @Each(items, "$bad", t.x)');
      expect(program.errors, hasLength(1));
      expect(
        program.errors.single.message,
        contains('string identifier'),
      );
    });

    test('@Each shape: invalid IDENT (uppercase leading) records error', () {
      final program = parseProgram('root = @Each(items, "Foo", t.x)');
      expect(program.errors, hasLength(1));
      expect(
        program.errors.single.message,
        contains('string identifier'),
      );
    });

    test('@Each shape: nested invalid @Each inside outer is reported', () {
      // Outer valid; inner has 2 args. Only the inner shape is wrong.
      final program = parseProgram(
        'root = @Each(items, "outer", @Each(outer, outer))',
      );
      expect(program.errors, hasLength(1));
      expect(program.errors.single.message, contains('3 args'));
    });
  });

  group('autoClose', () {
    test('balanced input is returned unchanged (string identity)', () {
      const text = 'a = "hi"\nb = [1, 2]';
      expect(autoClose(text), same(text));
    });

    test('empty input is returned unchanged', () {
      expect(autoClose(''), '');
    });

    test('closes unterminated string', () {
      expect(autoClose('"hello'), '"hello"');
    });

    test('preserves quote escapes inside string', () {
      // The escape \\ ensures the next " does not close the string.
      expect(autoClose(r'"a\"b'), r'"a\"b"');
    });

    test('dangling backslash at EOI', () {
      // The lexer's recoverable mode swallows this; autoClose's job is
      // just to close the string so the lexer has a complete literal.
      expect(autoClose(r'"foo\'), r'"foo\"');
    });

    test('unmatched paren', () {
      expect(autoClose('Stack(a, b'), 'Stack(a, b)');
    });

    test('unmatched bracket', () {
      expect(autoClose('[1, 2'), '[1, 2]');
    });

    test('unmatched brace', () {
      expect(autoClose('{a: 1'), '{a: 1}');
    });

    test('nested unmatched brackets close in reverse order', () {
      expect(autoClose('[1, [2, 3'), '[1, [2, 3]]');
    });

    test('mixed: bracket containing unterminated string', () {
      expect(autoClose('[1, "foo'), '[1, "foo"]');
    });

    test('lone closer is left as-is', () {
      // No opener — autoClose ignores the spurious closer entirely.
      expect(autoClose(']'), ']');
    });

    test('mismatched closer (e.g. ]) does not pop wrong opener', () {
      // `(` is on the stack; encountering `]` does not pop it because
      // the top of the stack is `)`. autoClose appends the `)` later.
      expect(autoClose('(1]'), '(1])');
    });

    test('strings hide brackets from balancer', () {
      expect(autoClose('"[(({"'), '"[(({"');
    });
  });
}
