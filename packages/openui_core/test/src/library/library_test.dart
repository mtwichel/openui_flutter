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

    test('description defaults to null', () {
      final c = defineComponent<String>(
        name: 'X',
        schema: Schema.object(),
        render: (c, p, r, id) => '',
      );
      expect(c.description, isNull);
    });

    test('defineComponent with description sets the field', () {
      final c = defineComponent<String>(
        name: 'X',
        description: 'a test component',
        schema: Schema.object(),
        render: (c, p, r, id) => '',
      );
      expect(c.description, 'a test component');
    });

    test('internal defaults to false', () {
      final c = defineComponent<String>(
        name: 'X',
        schema: Schema.object(),
        render: (c, p, r, id) => '',
      );
      expect(c.internal, isFalse);
    });

    test('defineComponent with internal: true sets the field', () {
      final c = defineComponent<String>(
        name: 'X',
        internal: true,
        schema: Schema.object(),
        render: (c, p, r, id) => '',
      );
      expect(c.internal, isTrue);
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

  group('evaluateElementProps', () {
    CompCall callFor(String source) {
      final program = parseProgram(source);
      return program.statements.single.expression as CompCall;
    }

    test('evaluates every named arg through the evaluator', () {
      final schema = Schema.object(
        properties: {'label': Schema.string(), 'count': Schema.integer()},
      );
      final ctx = EvalContext(statements: const [], store: Store());
      final props = evaluateElementProps(
        call: callFor('a = Button(label: "Click", count: 1 + 2)'),
        schema: schema,
        context: ctx,
      );
      expect(props, {'label': 'Click', 'count': 3});
    });

    test('a reactive prop bound to a StateRef emits a ReactiveAssign', () {
      final schema = Schema.object(
        properties: {'value': reactive(Schema.string())},
      );
      final store = Store()..set(r'$name', 'alice');
      final ctx = EvalContext(statements: const [], store: store);
      final props = evaluateElementProps(
        call: callFor(r'a = Input(value: $name)'),
        schema: schema,
        context: ctx,
      );
      final v = props['value'];
      expect(isReactiveAssign(v), isTrue);
      expect(v, isA<ReactiveAssign>());
      expect((v! as ReactiveAssign).target, r'$name');
      expect((v as ReactiveAssign).value, 'alice');
    });

    test(
      'a reactive prop bound to a non-StateRef expression evaluates normally',
      () {
        // The lang says reactive(...) is only "live" when the bound
        // expression is a bare $state ref. A literal or computed
        // expression resolves to a value (one-way).
        final schema = Schema.object(
          properties: {'value': reactive(Schema.string())},
        );
        final ctx = EvalContext(statements: const [], store: Store());
        final props = evaluateElementProps(
          call: callFor('a = Input(value: "static")'),
          schema: schema,
          context: ctx,
        );
        expect(props['value'], 'static');
        expect(isReactiveAssign(props['value']), isFalse);
      },
    );

    test(
      'a non-reactive prop bound to a StateRef just resolves the value',
      () {
        final schema = Schema.object(properties: {'value': Schema.string()});
        final store = Store()..set(r'$msg', 'hi');
        final ctx = EvalContext(statements: const [], store: store);
        final props = evaluateElementProps(
          call: callFor(r'a = Display(value: $msg)'),
          schema: schema,
          context: ctx,
        );
        expect(props['value'], 'hi');
        expect(isReactiveAssign(props['value']), isFalse);
      },
    );

    test('positional args are dropped', () {
      final schema = Schema.object();
      final ctx = EvalContext(statements: const [], store: Store());
      final props = evaluateElementProps(
        call: callFor('a = Stack("positional", named: 1)'),
        schema: schema,
        context: ctx,
      );
      expect(props.keys, ['named']);
    });

    test('args matching no schema prop are still included', () {
      final schema = Schema.object(properties: {'a': Schema.string()});
      final ctx = EvalContext(statements: const [], store: Store());
      final props = evaluateElementProps(
        call: callFor('x = Comp(a: "hi", extra: 42)'),
        schema: schema,
        context: ctx,
      );
      expect(props, {'a': 'hi', 'extra': 42});
    });

    test('a schema with no properties key evaluates every arg normally', () {
      // Construct directly so we have a Schema without `properties`.
      final schema = Schema.fromMap(const {'type': 'object'});
      final ctx = EvalContext(statements: const [], store: Store());
      final props = evaluateElementProps(
        call: callFor('a = X(label: "hi")'),
        schema: schema,
        context: ctx,
      );
      expect(props, {'label': 'hi'});
    });

    test('a properties entry that is not a map is treated as non-reactive', () {
      // Hand-build a deliberately malformed schema so the entry isn't a
      // Map. The helper should fall back to the regular evaluation
      // path without throwing.
      final schema = Schema.fromMap(const {
        'type': 'object',
        'properties': {'value': 'malformed'},
      });
      final store = Store()..set(r'$x', 'live');
      final ctx = EvalContext(statements: const [], store: store);
      final props = evaluateElementProps(
        call: callFor(r'a = X(value: $x)'),
        schema: schema,
        context: ctx,
      );
      expect(props['value'], 'live');
      expect(isReactiveAssign(props['value']), isFalse);
    });

    test('ReactiveAssign carries the live store value at call time', () {
      final schema = Schema.object(
        properties: {'value': reactive(Schema.string())},
      );
      final store = Store()..set(r'$name', 'before');
      final ctx = EvalContext(statements: const [], store: store);
      final first = evaluateElementProps(
        call: callFor(r'a = Input(value: $name)'),
        schema: schema,
        context: ctx,
      );
      expect((first['value']! as ReactiveAssign).value, 'before');
      store.set(r'$name', 'after');
      final second = evaluateElementProps(
        call: callFor(r'a = Input(value: $name)'),
        schema: schema,
        context: ctx,
      );
      expect((second['value']! as ReactiveAssign).value, 'after');
    });
  });
}
