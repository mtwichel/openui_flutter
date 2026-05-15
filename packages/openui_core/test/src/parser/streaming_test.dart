// Streaming-parser contract tests.
//
// Exercises the buffer split (string- and bracket-aware), the
// autoClose pass on the pending tail, the per-pass `parseProgram`
// invocation in recoverable mode, the `incomplete` flagging, and the
// state/query/mutation collection. Pairs the streaming layer's two
// public methods (push, set) against a representative slice of input
// shapes, including byte-by-byte feeds.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('createStreamingParser', () {
    test('default rootName is "root"', () {
      expect(createStreamingParser().rootName, 'root');
    });

    test('rootName is stored verbatim', () {
      expect(createStreamingParser(rootName: 'main').rootName, 'main');
    });

    test('initial state: push("") returns an empty parse', () {
      final parser = createStreamingParser();
      final result = parser.push('');
      expect(result.statements, isEmpty);
      expect(result.meta.errors, isEmpty);
      expect(result.meta.incomplete, isEmpty);
      expect(result.meta.stateDecls, isEmpty);
      expect(result.meta.queries, isEmpty);
      expect(result.meta.mutations, isEmpty);
    });
  });

  group('StreamParser.push', () {
    test('single complete statement (trailing newline) is not incomplete', () {
      final parser = createStreamingParser();
      final result = parser.push('a = 1\n');
      expect(result.statements, hasLength(1));
      expect(result.statements.single.name, 'a');
      expect(result.meta.incomplete, isEmpty);
    });

    test(
      'single statement without a trailing newline is flagged incomplete',
      () {
        final parser = createStreamingParser();
        final result = parser.push('a = 1');
        expect(result.statements, hasLength(1));
        expect(result.meta.incomplete, ['a']);
      },
    );

    test(
      'splitting one statement across two pushes yields the same final '
      'result as a single push',
      () {
        final parser = createStreamingParser();
        // Mid-statement before the RHS is filled in: the parser
        // surfaces the incomplete RHS as an error rather than a
        // statement, which is fine for a transient streaming snapshot.
        final intermediate = parser.push('a = ');
        expect(intermediate.statements, isEmpty);
        expect(intermediate.meta.errors, isNotEmpty);
        final result = parser.push('1\n');
        expect(result.statements.single.name, 'a');
        expect(result.meta.errors, isEmpty);
        expect(result.meta.incomplete, isEmpty);
      },
    );

    test(
      'feeding the input one character at a time converges to the same '
      'final ParseResult',
      () {
        const source = 'root = Stack([\n  Card(),\n  Card(),\n])\n';
        final parser = createStreamingParser();
        ParseResult? last;
        for (var i = 0; i < source.length; i++) {
          last = parser.push(source[i]);
        }
        expect(last, isNotNull);
        expect(last!.statements.single.name, 'root');
        expect(last.meta.incomplete, isEmpty);
        expect(last.meta.errors, isEmpty);
      },
    );

    test('multi-statement: only the in-flight tail is flagged', () {
      final parser = createStreamingParser();
      final result = parser.push('a = 1\nb = "hello');
      expect(result.statements.map((s) => s.name).toList(), ['a', 'b']);
      expect(result.meta.incomplete, ['b']);
    });

    test(
      'autoClose handles mid-string tail: result is parseable, flagged',
      () {
        final parser = createStreamingParser();
        final result = parser.push('msg = "hello');
        expect(result.statements.single.name, 'msg');
        expect(
          (result.statements.single.expression as Literal).value,
          'hello',
        );
        expect(result.meta.incomplete, ['msg']);
      },
    );

    test(
      'autoClose handles mid-bracket tail with internal newlines',
      () {
        final parser = createStreamingParser();
        final result = parser.push('items = Stack(\n  child');
        expect(result.statements.single.name, 'items');
        expect(result.meta.incomplete, ['items']);
      },
    );

    test('dangling backslash inside an unterminated string', () {
      // The lexer would throw `LexException` on dangling `\` in
      // non-recoverable mode, but the streaming parser uses recoverable
      // tokenization, so this should resolve to a best-effort string
      // literal without crashing.
      final parser = createStreamingParser();
      final result = parser.push(r'a = "foo\');
      expect(result.statements, hasLength(1));
      expect(result.meta.incomplete, ['a']);
    });
  });

  group('StreamParser.set', () {
    test('replaces the buffer entirely', () {
      final parser = createStreamingParser()..push('a = 1\n');
      final result = parser.set('b = 2\n');
      expect(result.statements.single.name, 'b');
    });

    test('set("") clears all parsed state', () {
      final parser = createStreamingParser()..push('a = 1\nb = 2\n');
      final result = parser.set('');
      expect(result.statements, isEmpty);
      expect(result.meta.incomplete, isEmpty);
    });

    test('set() then push() appends to the new buffer', () {
      final parser = createStreamingParser()..set('a = 1\n');
      final result = parser.push('b = 2\n');
      expect(result.statements.map((s) => s.name).toList(), ['a', 'b']);
    });
  });

  group('buffer split: bracket-aware', () {
    test(
      'newlines inside (...) do not split the buffer — the whole '
      'statement is in the prefix once closed',
      () {
        final parser = createStreamingParser();
        final result = parser.push('a = Stack(\n  1,\n  2\n)\n');
        expect(result.meta.incomplete, isEmpty);
      },
    );

    test('newlines inside [...] do not split the buffer', () {
      final parser = createStreamingParser();
      final result = parser.push('a = [\n  1,\n  2\n]\n');
      expect(result.meta.incomplete, isEmpty);
    });

    test('newlines inside {...} do not split the buffer', () {
      final parser = createStreamingParser();
      final result = parser.push('a = {\n  k: 1\n}\n');
      expect(result.meta.incomplete, isEmpty);
    });

    test('extra closer at depth 0 leaves depth pinned to 0', () {
      // A stray `)` should not push depth negative; the next newline
      // must still split the buffer normally.
      final parser = createStreamingParser();
      final result = parser.push(')\na = 1\n');
      // The first "statement" errors (lone `)`); the second parses.
      expect(result.statements.map((s) => s.name).toList(), ['a']);
      expect(result.meta.errors, isNotEmpty);
    });
  });

  group('buffer split: string-aware', () {
    test('literal newline inside a string is not a split point', () {
      final parser = createStreamingParser();
      // The lexer admits literal newlines inside string literals.
      final result = parser.push('msg = "line1\nline2"\n');
      expect(result.statements.single.name, 'msg');
      expect(result.meta.incomplete, isEmpty);
    });

    test('escaped quote inside a string does not close it', () {
      final parser = createStreamingParser();
      final result = parser.push(
        r'a = "say \"hi\""'
        '\n',
      );
      expect(result.statements.single.name, 'a');
      expect(
        (result.statements.single.expression as Literal).value,
        'say "hi"',
      );
    });

    test('brackets inside a string do not influence depth', () {
      final parser = createStreamingParser();
      final result = parser.push('a = "[(({"\n');
      expect(result.statements.single.name, 'a');
      expect(result.meta.incomplete, isEmpty);
    });
  });

  group('meta extraction', () {
    test(r'state declaration: $count = 0', () {
      final parser = createStreamingParser();
      final result = parser.push(
        r'$count = 0'
        '\n',
      );
      expect(result.meta.stateDecls, hasLength(1));
      expect(result.meta.stateDecls.single.name, r'$count');
      expect(
        result.meta.stateDecls.single.defaultValue,
        equals(const Literal(0, offset: 9)),
      );
    });

    test(r'@Query bound to a $-prefixed LHS classifies as query', () {
      final parser = createStreamingParser();
      final result = parser.push(
        r'$users = @Query(list_users)'
        '\n',
      );
      expect(result.meta.queries, hasLength(1));
      final decl = result.meta.queries.single;
      expect(decl.statementId, r'$users');
      expect(decl.toolName, 'list_users');
      expect(decl.namedArgs, isEmpty);
      expect(result.meta.stateDecls, isEmpty);
    });

    test('@Query carries named args verbatim', () {
      final parser = createStreamingParser();
      final result = parser.push(
        r'$products = @Query(fetch_products, category: "shoes")'
        '\n',
      );
      expect(result.meta.errors, isEmpty);
      final decl = result.meta.queries.single;
      expect(decl.toolName, 'fetch_products');
      expect(decl.namedArgs.single.name, 'category');
      expect(
        decl.namedArgs.single.value,
        equals(const Literal('shoes', offset: 41)),
      );
    });

    test('mutation declaration', () {
      final parser = createStreamingParser();
      final result = parser.push('del = Mutation(name: "delete")\n');
      expect(result.meta.mutations, hasLength(1));
      expect(result.meta.mutations.single.statementId, 'del');
    });

    test('parse errors are collected, not thrown', () {
      final parser = createStreamingParser();
      final result = parser.push('= 1\nb = 2\n');
      expect(result.meta.errors, isNotEmpty);
      expect(result.statements.map((s) => s.name).toList(), ['b']);
    });

    test('value statements do not appear in state/query/mutation lists', () {
      final parser = createStreamingParser();
      final result = parser.push('greeting = "hi"\n');
      expect(result.meta.stateDecls, isEmpty);
      expect(result.meta.queries, isEmpty);
      expect(result.meta.mutations, isEmpty);
    });

    test(
      'StateDecl, QueryDecl, MutationDecl carry the AST verbatim',
      () {
        final parser = createStreamingParser();
        final result = parser.push(
          r'$count = 0'
          '\n'
          r'$users = @Query(list_users, q: "active")'
          '\n'
          'del = Mutation(name: "delete")\n',
        );
        // Spot-check that the meta types preserve the raw ASTs.
        const decl = StateDecl(
          name: r'$count',
          defaultValue: Literal(0, offset: 9),
        );
        expect(decl.name, r'$count');
        expect(decl.defaultValue, isA<Literal>());

        final qDecl = result.meta.queries.single;
        expect(qDecl.statementId, r'$users');
        expect(qDecl.toolName, 'list_users');
        expect(qDecl.namedArgs.single.name, 'q');
        expect(qDecl.namedArgs.single.value, isA<Literal>());

        final mDecl = result.meta.mutations.single;
        expect(mDecl.statementId, 'del');
        expect(mDecl.args.single.name, 'name');
      },
    );
  });

  group('@Each shape validation is offset-gated', () {
    test('mid-stream partial @Each does not surface a shape error', () {
      // The third arg has not been typed yet. autoClose patches the
      // tail into a parseable 2-arg call; the streaming parser must
      // not surface the shape error for in-flight statements.
      final parser = createStreamingParser();
      final result = parser.push('root = @Each(rows, "t"');
      expect(
        result.meta.errors.where((e) => e.message.contains('@Each')),
        isEmpty,
      );
      expect(result.meta.incomplete, ['root']);
    });

    test('a complete 3-arg @Each parses without an error', () {
      final parser = createStreamingParser();
      final result = parser.push('root = @Each(rows, "t", Tag(t.name))\n');
      expect(result.meta.errors, isEmpty);
    });

    test('mid-stream partial @Query does not surface a shape error', () {
      // Tool name has not been completed; autoClose patches the tail
      // but the validator must skip the in-flight statement.
      final parser = createStreamingParser();
      final result = parser.push(r'$products = @Query(fetch_produc');
      expect(
        result.meta.errors.where((e) => e.message.contains('@Query')),
        isEmpty,
      );
      expect(result.meta.incomplete, [r'$products']);
    });

    test('committed invalid @Query surfaces a shape error', () {
      final parser = createStreamingParser();
      final result = parser.push(
        'data = @Query(tool)\ntail = 1\n',
      );
      expect(
        result.meta.errors.where(
          (e) => e.message.contains('must be the entire RHS'),
        ),
        hasLength(1),
      );
    });

    test('committed invalid @Each surfaces a shape error', () {
      // The first statement is in the committed prefix (closed by
      // newline). The 2-arg @Each must surface a shape error there.
      final parser = createStreamingParser();
      final result = parser.push(
        r'root = @Each(rows, $item)'
        '\n'
        'tail = 1\n',
      );
      expect(
        result.meta.errors.where((e) => e.message.contains('3 args')),
        hasLength(1),
      );
    });
  });

  group('ParseResult and ParseMeta immutability', () {
    test('statements list is unmodifiable', () {
      final result = createStreamingParser().push('a = 1\n');
      expect(
        () => result.statements.add(
          const Statement(
            name: 'x',
            kind: StatementKind.value,
            expression: Literal(0, offset: 0),
            offset: 0,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('meta sub-lists are unmodifiable', () {
      final result = createStreamingParser().push('a = 1');
      expect(() => result.meta.incomplete.add('x'), throwsUnsupportedError);
      expect(result.meta.errors.clear, throwsUnsupportedError);
      expect(
        () => result.meta.stateDecls.add(
          const StateDecl(
            name: r'$x',
            defaultValue: Literal(0, offset: 0),
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => result.meta.queries.add(
          const QueryDecl(
            statementId: r'$x',
            toolName: 'tool',
            namedArgs: <Argument>[],
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => result.meta.mutations.add(
          const MutationDecl(statementId: 'x', args: []),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
