// mergeStatements contract tests.
//
// Each test feeds (existing, patch) strings, then asserts the merged
// program by reparsing and inspecting `program.statements` rather
// than string-matching — the function preserves whitespace per
// statement, but consumers care about the resulting AST graph, not
// the exact string layout.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

Map<String, AstNode> _bodiesOf(String source) {
  final program = parseProgram(source);
  return {for (final s in program.statements) s.name: s.expression};
}

List<String> _idsInOrder(String source) {
  return parseProgram(source).statements.map((s) => s.name).toList();
}

void main() {
  group('mergeStatements', () {
    test('empty existing returns the patch', () {
      final merged = mergeStatements('', 'root = "hi"\n');
      expect(_idsInOrder(merged), ['root']);
      expect((_bodiesOf(merged)['root']! as Literal).value, 'hi');
    });

    test('empty patch returns the existing program unchanged', () {
      final merged = mergeStatements('root = "hi"', '');
      expect(_idsInOrder(merged), ['root']);
      expect((_bodiesOf(merged)['root']! as Literal).value, 'hi');
    });

    test('upsert replaces an existing statement in place (last-write)', () {
      final merged = mergeStatements(
        'root = "v1"\n',
        'root = "v2"\n',
      );
      expect(_idsInOrder(merged), ['root']);
      expect((_bodiesOf(merged)['root']! as Literal).value, 'v2');
    });

    test('appends new statements after existing ones', () {
      final merged = mergeStatements(
        'root = Stack([chart])\nchart = "old"\n',
        'root = Stack([chart, extra])\nextra = "added"\n',
      );
      // The patch updates `root` to also reference `extra`, then
      // appends `extra`. All three are reachable from root, so the
      // GC keeps them.
      expect(_idsInOrder(merged).toSet(), {'root', 'chart', 'extra'});
    });

    test('NullLiteral RHS deletes the statement from the program', () {
      final merged = mergeStatements(
        'root = "hi"\nthrowaway = "delete me"\n',
        'throwaway = null\n',
      );
      expect(_idsInOrder(merged), ['root']);
    });

    test('NullLiteral on a non-existent id is a safe no-op', () {
      final merged = mergeStatements(
        'root = "hi"\n',
        'never = null\n',
      );
      expect(_idsInOrder(merged), ['root']);
    });

    test('orphans (value-kind, unreachable from root) are dropped', () {
      // After the patch, `chart` is no longer referenced — it becomes
      // an orphan and the GC step drops it.
      final merged = mergeStatements(
        'root = Stack([chart])\nchart = "old"\n',
        'root = "rewritten"\n',
      );
      expect(_idsInOrder(merged), ['root']);
    });

    test("state, query, mutation declarations are not GC'd as orphans", () {
      // The state and query don't appear in root's reachable graph,
      // but they should survive the GC.
      final merged = mergeStatements(
        'root = "hi"\n'
            r'$count = 0'
            '\n'
            'users = Query(name: "list")\n',
        '',
      );
      expect(_idsInOrder(merged).toSet(), {'root', r'$count', 'users'});
    });

    test('reachable transitive references are preserved through the merge', () {
      final merged = mergeStatements(
        'root = Stack([a])\na = b\nb = "leaf"\n',
        'b = "patched"\n',
      );
      expect(_idsInOrder(merged).toSet(), {'root', 'a', 'b'});
      expect((_bodiesOf(merged)['b']! as Literal).value, 'patched');
    });

    test('preserves the existing order, appending new ids at the end', () {
      final merged = mergeStatements(
        'root = Stack([first, second])\nfirst = "f"\nsecond = "s"\n',
        'second = "S"\nthird = "t"\n',
      );
      // The patch updates `second` in place (no reordering) and
      // appends `third`. The existing ids appear in their original
      // order; `third` is last.
      // (third is unreachable from root — orphan-GC drops it.)
      expect(_idsInOrder(merged), ['root', 'first', 'second']);
    });

    test('a state ref is preserved through the merge', () {
      // `$count` is not a value-kind statement, so the orphan GC
      // leaves it in even when nothing in the value graph references
      // its identifier.
      final merged = mergeStatements(
        'root = "hi"\n'
            r'$count = 0'
            '\n',
        r'$count = 99'
            '\n',
      );
      expect(_idsInOrder(merged).toSet(), {'root', r'$count'});
      // Value updated.
      expect(
        (_bodiesOf(merged)[r'$count']! as Literal).value,
        99,
      );
    });

    test('strips a leading code fence and language tag', () {
      final merged = mergeStatements(
        'root = "v1"\n',
        '```dart\nroot = "patched"\n```\n',
      );
      expect((_bodiesOf(merged)['root']! as Literal).value, 'patched');
    });

    test('strips a fence with no language tag', () {
      final merged = mergeStatements(
        'root = "v1"\n',
        '```\nroot = "patched"\n```\n',
      );
      expect((_bodiesOf(merged)['root']! as Literal).value, 'patched');
    });

    test('a single-line fence with no newline is dropped to empty', () {
      // "```" with nothing after — sanity-check the no-newline path.
      final merged = mergeStatements('root = "keep"', '```');
      expect(_idsInOrder(merged), ['root']);
      expect((_bodiesOf(merged)['root']! as Literal).value, 'keep');
    });

    test('custom rootId controls which statements survive GC', () {
      // GC only runs when a non-empty patch is applied — an empty
      // patch is a "return existing unchanged" short-circuit. Pass an
      // identity-ish patch so the merge runs through the maps.
      final merged = mergeStatements(
        'main = Stack([widget])\nwidget = "hello"\nfloat = "alone"\n',
        'main = Stack([widget])\n',
        rootId: 'main',
      );
      expect(_idsInOrder(merged).toSet(), {'main', 'widget'});
    });

    test(
      'duplicate ids inside existing collapse to last-write under a patch',
      () {
        // Empty patch is a short-circuit ("return existing unchanged"),
        // so we pass a non-empty one. The patch deletes a non-existent
        // id (no-op), forcing the full merge path which collapses
        // duplicates via the per-id map.
        final merged = mergeStatements(
          'root = "first"\nroot = "second"\n',
          'extra = null\n',
        );
        expect(_idsInOrder(merged), ['root']);
        expect((_bodiesOf(merged)['root']! as Literal).value, 'second');
      },
    );

    test('multi-line statement bodies survive the slice', () {
      final merged = mergeStatements(
        'root = Stack(\n  [a]\n)\na = "leaf"\n',
        'b = "added"\nroot = Stack([a, b])\n',
      );
      expect(_idsInOrder(merged).toSet(), {'root', 'a', 'b'});
    });
  });
}
