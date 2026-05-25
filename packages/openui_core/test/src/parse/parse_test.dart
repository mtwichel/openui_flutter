// Contract suite ported from thesysdev/openui's
// `packages/lang-core/src/parser/__tests__/parser.test.ts`.
//
// Each Dart test mirrors a `describe`/`it` block from the JS suite,
// converted to use this port's:
//   - `parse(source, paramMap)` integration entry,
//   - `ResolvedElement` (typeName + props + statementId) shape,
//   - `CompiledMeta` (errors, unresolved, orphaned, ...) shape.
//
// Validation errors flow through the [OpenUIError] hierarchy.
// `UnknownComponentError.component` carries the offending name;
// `EvaluationError.message` carries the human-readable text for
// excess-args / missing-required / null-required cases (the JS
// reference distinguishes them via a `code` discriminator we read off
// the message string here).

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

final ParamMap _schema = <String, List<ParamSpec>>{
  'Stack': [const ParamSpec(name: 'children', required: true)],
  'Title': [const ParamSpec(name: 'text', required: true)],
  'Table': [
    const ParamSpec(name: 'columns', required: true),
    const ParamSpec(name: 'rows', required: true),
  ],
};

CompiledProgram _parse(String input) => parse(input, _schema);
List<OpenUIError> _errors(String input) => _parse(input).meta.errors;

void main() {
  group('unknown-component', () {
    test('reports when component name is not in schema', () {
      final result = _parse('root = DataTable("col")');
      expect(result.meta.errors, hasLength(1));
      expect(result.meta.errors.single, isA<UnknownComponentError>());
      expect(
        (result.meta.errors.single as UnknownComponentError).component,
        'DataTable',
      );
    });

    test('drops the unknown component from the tree (root is null)', () {
      expect(_parse('root = DataTable("col")').root, isNull);
    });

    test('reports all unknown components in a tree', () {
      final result = _parse('root = Stack([Ghost("a")])');
      final unknowns = result.meta.errors.whereType<UnknownComponentError>();
      expect(unknowns.map((e) => e.component), contains('Ghost'));
    });

    test('no unknown-component error for a known component', () {
      final result = _parse('root = Stack(["hello"])');
      expect(
        result.meta.errors.whereType<UnknownComponentError>(),
        isEmpty,
      );
    });
  });

  group('excess-args', () {
    test('ignores extra positionals and still renders with valid args', () {
      final result = _parse('root = Title("hello", "extra")');
      expect(
        _errors('root = Title("hello", "extra")')
            .whereType<EvaluationError>()
            .where((e) => e.message?.contains('excess dropped') ?? false),
        isEmpty,
      );
      expect(result.root, isNotNull);
      expect(result.root!.props['text'], 'hello');
    });

    test('does not report excess when many extra positionals are passed', () {
      final errs = _errors('root = Title("hello", "extra", "more")');
      expect(
        errs.where(
          (e) =>
              e is EvaluationError &&
              (e.message?.contains('excess dropped') ?? false),
        ),
        isEmpty,
      );
    });

    test('does not report when arg count matches param count', () {
      final errs = _errors('root = Title("hello")');
      expect(
        errs.where(
          (e) =>
              e is EvaluationError &&
              (e.message?.contains('excess dropped') ?? false),
        ),
        isEmpty,
      );
    });

    test('does not report when fewer args than params', () {
      final errs = _errors('root = Table([], [])');
      expect(
        errs.where(
          (e) =>
              e is EvaluationError &&
              (e.message?.contains('excess dropped') ?? false),
        ),
        isEmpty,
      );
    });
  });

  group('unresolved references', () {
    test('tracks unresolved refs in meta.unresolved', () {
      final result = _parse('root = Stack([tbl])');
      expect(result.meta.unresolved, contains('tbl'));
    });

    test('clears unresolved when the ref is defined', () {
      final result = _parse(
        'root = Stack([tbl])\ntbl = Title("hello")\n',
      );
      expect(result.meta.unresolved, isEmpty);
    });
  });

  group('required-prop validation', () {
    test('missing-required carries the component name', () {
      final result = _parse('root = Stack()');
      expect(result.meta.errors, hasLength(1));
      final err = result.meta.errors.single as EvaluationError;
      expect(err.message, contains('missing required field "children"'));
      expect(err.statementId, 'root');
    });

    test('null-required is distinct from missing-required', () {
      final result = _parse('root = Stack(null)');
      expect(result.meta.errors, hasLength(1));
      final err = result.meta.errors.single as EvaluationError;
      expect(err.message, contains('cannot be null'));
    });
  });

  group('array null-dropping', () {
    test('drops unresolved refs from children arrays', () {
      final result = _parse(
        'root = Stack([missing, t1])\nt1 = Title("ok")\n',
      );
      final children = result.root!.props['children']! as List<Object?>;
      expect(children, hasLength(1));
      expect((children.single! as ResolvedElement).typeName, 'Title');
    });

    test('drops invalid components (missing required) from arrays', () {
      final result = _parse(
        'root = Stack([bad, good])\nbad = Title()\ngood = Title("ok")\n',
      );
      final children = result.root!.props['children']! as List<Object?>;
      expect(children, hasLength(1));
      expect(
        (children.single! as ResolvedElement).props['text'],
        'ok',
      );
    });

    test('drops unknown components from arrays', () {
      final result = _parse(
        'root = Stack([u, t1])\nu = Ghost("x")\nt1 = Title("ok")\n',
      );
      final children = result.root!.props['children']! as List<Object?>;
      expect(children, hasLength(1));
      expect((children.single! as ResolvedElement).typeName, 'Title');
    });

    test('preserves null literals in arrays', () {
      final result = _parse('root = Stack([null, null])');
      final children = result.root!.props['children']! as List<Object?>;
      expect(children, [null, null]);
    });
  });

  group('orphaned statements', () {
    test('reports value statements unreachable from root', () {
      final result = _parse(
        'root = Stack([t1])\nt1 = Title("used")\norphan = Title("unused")\n',
      );
      expect(result.meta.orphaned, contains('orphan'));
    });

    test('state, query, mutation declarations are not orphaned', () {
      // None of these are reachable from `root` via Reference, but
      // they should still be excluded from `orphaned`.
      final result = _parse(
        'root = Title("hi")\n'
        r'$count = 0'
        '\n'
        'users = Query(name: "list")\n'
        'del = Mutation(name: "delete")\n',
      );
      expect(result.meta.orphaned, isEmpty);
    });
  });

  group('integration shape', () {
    test('preserves the statementId on the root element', () {
      final result = _parse('root = Title("hi")');
      expect(result.root!.statementId, 'root');
    });

    test('positional → named arg mapping uses the schema order', () {
      final result = _parse('root = Table([1, 2], [3, 4])');
      expect(result.root!.props['columns'], [1, 2]);
      expect(result.root!.props['rows'], [3, 4]);
    });

    test('an empty source returns root: null, meta.incomplete: true', () {
      final result = parse('', _schema);
      expect(result.root, isNull);
      expect(result.meta.incomplete, isTrue);
    });

    test('strips a Markdown fence around the program', () {
      final result = parse('```dart\nroot = Title("hi")\n```\n', _schema);
      expect(result.root, isNotNull);
      expect(result.root!.props['text'], 'hi');
    });

    test('reports nested @Query as a parse violation', () {
      final program = parseProgram('root = Stack([@Query(x)])');
      expect(
        program.errors.any(
          (e) => e.message.contains(r'@Query must be the entire RHS of a $var'),
        ),
        isTrue,
      );
    });

    test('cycle in references resolves without infinite recursion', () {
      // `a = b\nb = a` — when resolving `a` we visit `b` which tries
      // to visit `a` (in-progress). The cycle short-circuits to null
      // and adds the name to `unresolved`.
      final result = parse('root = Title(a)\na = b\nb = a', _schema);
      expect(result.meta.unresolved, isNotEmpty);
    });

    test('falls back to the first value statement when root is missing', () {
      final result = parse('main = Title("alt")', _schema);
      expect(result.root, isNotNull);
      expect(result.root!.statementId, 'main');
    });

    test(
      r'auto-declares referenced $-vars in stateDeclarations',
      () {
        final result = parse(
          'root = Title("hi")\n'
          r'main = Stack([$auto])'
          '\n',
          _schema,
        );
        expect(result.stateDeclarations.containsKey(r'$auto'), isTrue);
        expect(result.stateDeclarations[r'$auto'], isNull);
      },
    );

    test('explicit state declaration overrides the auto-declared null', () {
      final result = parse(
        'root = Title("hi")\n'
        r'$count = 7'
        '\n',
        _schema,
      );
      expect(result.stateDeclarations[r'$count'], 7);
    });
  });

  group('coverage edge cases', () {
    test('non-empty source that parses to zero statements returns empty', () {
      // `=` with no LHS — the parser's recovery skips the broken
      // statement and produces nothing.
      final result = parse('= 1', _schema);
      expect(result.root, isNull);
      expect(result.meta.statementCount, 0);
    });

    test('an inline Mutation in expression position emits an error', () {
      final result = _parse('root = Stack([Mutation(name: "x")])');
      expect(
        result.meta.errors.whereType<EvaluationError>().any(
          (e) => e.message?.contains('Mutation()') ?? false,
        ),
        isTrue,
      );
    });

    test('an object literal materializes to a Map', () {
      final result = _parse('root = Title({k: 1, label: "v"})');
      expect(result.root!.props['text'], {'k': 1, 'label': 'v'});
    });

    test('a required prop with a defaultValue is filled when missing', () {
      final schema = <String, List<ParamSpec>>{
        'Btn': [
          const ParamSpec(name: 'label', required: true, defaultValue: 'OK'),
        ],
      };
      final result = parse('root = Btn()', schema);
      expect(result.root, isNotNull);
      expect(result.root!.props['label'], 'OK');
    });

    test(
      'when rootName is missing and only state statements exist, '
      'picks the first by insertion order',
      () {
        // Only state decls; no value statements. `_pickEntryId` skips
        // the loop and returns `stmtMap.keys.first`.
        final result = parse(r'$count = 0', _schema, rootName: 'missing');
        // The state default materializes to its primitive value (0).
        // We don't make a ResolvedElement because the AST isn't a Comp.
        expect(result.root, isNull);
        expect(result.stateDeclarations[r'$count'], 0);
      },
    );

    test('state-decl ASTs walked for auto-declare cover every AST shape', () {
      // The auto-declare scan calls `_collectStateRefs` on each
      // statement's expression. Compose a single program whose
      // statements contain every AST shape so each switch arm is
      // exercised exactly once.
      const source =
          'root = Title("anchor")\n'
          r'$assign = ($other = 1)' // StateAssign
          '\n'
          r'$bin = $a + 1' // BinaryOp + StateRef
          '\n'
          r'$un = !$b' // UnaryOp
          '\n'
          r'$tern = 1 == 1 ? $c : $d' // Ternary
          '\n'
          r'$mem = $obj.field' // MemberAccess
          '\n'
          r'$idx = $arr[$i]' // IndexAccess
          '\n'
          r'$arr2 = [$x, 1]' // ArrayLit + StateRef element
          '\n'
          r'$obj2 = {k: $y}' // ObjectLit
          '\n';
      final result = parse(source, _schema);
      // Auto-declares should include each referenced state var.
      expect(
        result.stateDeclarations.keys.toSet(),
        containsAll([
          r'$assign',
          r'$other',
          r'$bin',
          r'$a',
          r'$un',
          r'$b',
          r'$tern',
          r'$c',
          r'$d',
          r'$mem',
          r'$obj',
          r'$idx',
          r'$arr',
          r'$i',
          r'$arr2',
          r'$x',
          r'$obj2',
          r'$y',
        ]),
      );
    });

    test(
      'state-decl with a CompCall arg covers the call-args fall-through',
      () {
        final result = parse(
          'root = Title("anchor")\n'
          r'$x = Title($needed)'
          '\n',
          _schema,
        );
        expect(result.stateDeclarations.containsKey(r'$needed'), isTrue);
      },
    );

    test(
      'state-decl with a Query/Mutation arg covers those switch arms',
      () {
        final result = parse(
          'root = Title("anchor")\n'
          r'$q = @Query(list, name: $name)'
          '\n'
          r'$m = Mutation(name: $other)'
          '\n',
          _schema,
        );
        expect(result.stateDeclarations.containsKey(r'$name'), isTrue);
        expect(result.stateDeclarations.containsKey(r'$other'), isTrue);
      },
    );

    test(
      r'query-backed $var passes through Title as a StateRef at parse time',
      () {
        final result = _parse(
          r'$q = @Query(x)'
          '\n'
          r'root = Title($q)'
          '\n',
        );
        expect(result.root, isNotNull);
        final text = result.root!.props['text'];
        expect(text, isA<StateRef>());
        expect((text! as StateRef).name, 'q');
      },
    );
  });

  group('ResolvedElement', () {
    test('equality is structural over typeName, props, and statementId', () {
      const literalProps = <String, Object?>{'text': 'hi'};
      final a = ResolvedElement(
        typeName: 'Title',
        props: literalProps,
        statementId: 'root',
      );
      final b = ResolvedElement(
        typeName: 'Title',
        props: literalProps,
        statementId: 'root',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == a, isTrue);
      expect(
        a,
        isNot(
          equals(
            ResolvedElement(
              typeName: 'Other',
              props: literalProps,
              statementId: 'root',
            ),
          ),
        ),
      );
      expect(
        a,
        isNot(
          equals(
            ResolvedElement(
              typeName: 'Title',
              props: const {'text': 'bye'},
              statementId: 'root',
            ),
          ),
        ),
      );
      expect(
        a,
        isNot(
          equals(
            ResolvedElement(
              typeName: 'Title',
              props: literalProps,
              statementId: 'other',
            ),
          ),
        ),
      );
    });

    test('toString includes the typeName, props, and statementId', () {
      final r = ResolvedElement(
        typeName: 'Title',
        props: const {'text': 'hi'},
        statementId: 'root',
      );
      expect(r.toString(), contains('Title'));
      expect(r.toString(), contains('text'));
      expect(r.toString(), contains('root'));
    });

    test('props map is unmodifiable', () {
      final r = ResolvedElement(typeName: 'X', props: const {'a': 1});
      expect(() => r.props['a'] = 2, throwsUnsupportedError);
    });
  });

  group('paramMapFromLibrary', () {
    ComponentDefinition _component(
      String name, {
      Map<String, Object?> properties = const {},
      List<String>? required,
      Object? propertiesOverride,
    }) {
      final schemaMap = <String, Object?>{
        'type': 'object',
        if (propertiesOverride != null)
          'properties': propertiesOverride
        else
          'properties': properties,
        if (required != null && required.isNotEmpty) 'required': required,
      };
      return ComponentDefinition(
        name: name,
        schema: Schema.fromMap(schemaMap),
      );
    }

    test('maps property order and required flags from schemas', () {
      final lib = LibraryDefinition(
        components: [
          _component(
            'Button',
            properties: {
              'label': {'type': 'string'},
              'count': {'type': 'integer'},
            },
            required: ['label'],
          ),
        ],
      );

      final map = paramMapFromLibrary(lib);

      expect(map.keys, ['Button']);
      final specs = map['Button']!;
      expect(specs, hasLength(2));
      expect(specs[0].name, 'label');
      expect(specs[0].required, isTrue);
      expect(specs[1].name, 'count');
      expect(specs[1].required, isFalse);
    });

    test('skips components whose properties value is not a map', () {
      final lib = LibraryDefinition(
        components: [
          _component('Bad', propertiesOverride: 'not-a-map'),
          _component(
            'Good',
            properties: {
              'text': {'type': 'string'},
            },
          ),
        ],
      );

      final map = paramMapFromLibrary(lib);

      expect(map.containsKey('Bad'), isFalse);
      final specs = map['Good']!;
      expect(specs, hasLength(1));
      expect(specs.single.name, 'text');
      expect(specs.single.required, isFalse);
    });
  });
}
