// Library, Component, defineComponent, reactive, ReactiveAssign,
// and isReactiveAssign contract tests.
//
// `Component` and `Library` are generic over the rendered widget
// type `W`; tests pin W to `String` so we can exercise the
// `ComponentRender` callback in pure Dart without a Flutter Widget.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('reactive(Schema)', () {
    test('adds the x-reactive: true extension keyword', () {
      final inner = Schema.string();
      final wrapped = reactive(inner);
      expect(wrapped.value['x-reactive'], isTrue);
    });

    test('preserves the inner schema fields', () {
      final inner = Schema.string(minLength: 3);
      final wrapped = reactive(inner);
      expect(wrapped.value['type'], inner.value['type']);
      expect(wrapped.value['minLength'], 3);
    });

    test('does not mutate the inner schema', () {
      final inner = Schema.string();
      reactive(inner);
      expect(inner.value.containsKey('x-reactive'), isFalse);
    });

    test('round-trips through toJson()', () {
      final wrapped = reactive(Schema.string());
      // Spike S0.1 verified extension keywords survive `toJson()`; we
      // re-confirm here as a regression guard against an upstream
      // bump that strips them.
      expect(wrapped.toJson(), contains('"x-reactive":true'));
    });
  });

  group('Component and defineComponent', () {
    test('exposes name, schema, and render', () {
      final c = defineComponent<String>(
        name: 'Stack',
        schema: Schema.object(),
        render: (context, props, renderNode, statementId) => 'rendered',
      );
      expect(c.name, 'Stack');
      expect(c.schema.value['type'], 'object');
      expect(c.render, isA<ComponentRender<String>>());
    });

    test('the render callback can be invoked', () {
      var capturedId = '';
      final c = defineComponent<String>(
        name: 'X',
        schema: Schema.object(),
        render: (context, props, renderNode, statementId) {
          capturedId = statementId;
          return 'hello-${props['n']}';
        },
      );
      // Invoke through a stub renderNode that we don't actually use.
      String stubRender(AstNode node, EvalContext ctx) => 'stub';
      final out = c.render(
        EvalContext(statements: const [], store: Store()),
        const {'n': 'world'},
        stubRender,
        'root',
      );
      expect(out, 'hello-world');
      expect(capturedId, 'root');
    });
  });

  group('Library', () {
    Component<String> comp(String name) => defineComponent<String>(
      name: name,
      schema: Schema.object(),
      render: (c, p, r, id) => name,
    );

    test('lookup returns the registered component', () {
      final lib = Library<String>([comp('Stack'), comp('Card')]);
      expect(lib['Stack'], isNotNull);
      expect(lib['Stack']!.name, 'Stack');
      expect(lib['Card']!.name, 'Card');
    });

    test('lookup returns null for unknown names', () {
      final lib = Library<String>([comp('Stack')]);
      expect(lib['Missing'], isNull);
    });

    test('names enumerates registrations in insertion order', () {
      final lib = Library<String>([
        comp('Stack'),
        comp('Card'),
        comp('Button'),
      ]);
      expect(lib.names.toList(), ['Stack', 'Card', 'Button']);
    });

    test('duplicate names collapse to last-write-wins', () {
      final first = defineComponent<String>(
        name: 'Stack',
        schema: Schema.object(),
        render: (c, p, r, id) => 'first',
      );
      final second = defineComponent<String>(
        name: 'Stack',
        schema: Schema.object(),
        render: (c, p, r, id) => 'second',
      );
      final lib = Library<String>([first, second]);
      expect(lib.names, ['Stack']);
      // The second registration wins.
      expect(
        lib['Stack']!.render(
          EvalContext(statements: const [], store: Store()),
          const {},
          (n, c) => 'stub',
          'r',
        ),
        'second',
      );
    });

    test('extend layers extra components on top of the base', () {
      final base = Library<String>([comp('Stack')]);
      final extended = base.extend([comp('Card')]);
      expect(extended.names.toSet(), {'Stack', 'Card'});
      // Original library is untouched.
      expect(base['Card'], isNull);
    });

    test('extend supports overriding a base component', () {
      final base = Library<String>([comp('Stack')]);
      final replacement = defineComponent<String>(
        name: 'Stack',
        schema: Schema.object(),
        render: (c, p, r, id) => 'overridden',
      );
      final extended = base.extend([replacement]);
      expect(
        extended['Stack']!.render(
          EvalContext(statements: const [], store: Store()),
          const {},
          (n, c) => 'stub',
          'r',
        ),
        'overridden',
      );
    });
  });

  group('ReactiveAssign', () {
    test('exposes target and value', () {
      const m = ReactiveAssign(target: r'$count', value: 7);
      expect(m.target, r'$count');
      expect(m.value, 7);
    });

    test('equality is structural', () {
      const a = ReactiveAssign(target: r'$count', value: 7);
      const b = ReactiveAssign(target: r'$count', value: 7);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == a, isTrue);
      expect(
        a,
        isNot(equals(const ReactiveAssign(target: r'$other', value: 7))),
      );
      expect(
        a,
        isNot(equals(const ReactiveAssign(target: r'$count', value: 8))),
      );
    });

    test('toString shows the target and the bound value', () {
      const m = ReactiveAssign(target: r'$name', value: 'alice');
      expect(m.toString(), contains(r'$name'));
      expect(m.toString(), contains('alice'));
    });
  });

  group('isReactiveAssign', () {
    test('returns true for a ReactiveAssign instance', () {
      expect(
        isReactiveAssign(const ReactiveAssign(target: r'$x', value: 1)),
        isTrue,
      );
    });

    test('returns false for non-marker values', () {
      expect(isReactiveAssign(null), isFalse);
      expect(isReactiveAssign(0), isFalse);
      expect(isReactiveAssign('hi'), isFalse);
      expect(isReactiveAssign({'x': 1}), isFalse);
    });
  });
}
