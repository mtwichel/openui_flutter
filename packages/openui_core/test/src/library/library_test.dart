// Library, Component, RenderComponent, reactive, ReactiveAssign,
// and isReactiveAssign contract tests.

import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

void main() {
  group('Component', () {
    test('defineComponent with description sets the field', () {
      final c = Component(
        name: 'X',
        description: 'a test component',
        schema: Schema.object(),
      );
      expect(c.description, 'a test component');
    });

    test('internal defaults to false', () {
      final c = Component(
        name: 'X',
        schema: Schema.object(),
      );
      expect(c.internal, isFalse);
    });

    test('defineComponent with internal: true sets the field', () {
      final c = Component(
        name: 'X',
        internal: true,
        schema: Schema.object(),
      );
      expect(c.internal, isTrue);
    });

    test('the render callback of RenderComponent can be invoked', () {
      var capturedId = '';
      final renderComp = RenderComponent<String>(
        spec: Component(
          name: 'X',
          schema: Schema.object(),
        ),
        render: (context, props, renderNode, statementId) {
          capturedId = statementId;
          return 'hello-${props['n']}';
        },
      );
      // Invoke through a stub renderNode that we don't actually use.
      String stubRender(AstNode node, EvalContext ctx) => 'stub';
      final out = renderComp.render(
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
    Component comp(String name) => Component(
      name: name,
      schema: Schema.object(),
    );

    test('lookup returns the registered component', () {
      final lib = Library(
        components: [comp('Stack'), comp('Card')],
        tools: const [],
      );
      expect(lib.component('Stack'), isNotNull);
      expect(lib.component('Stack')!.name, 'Stack');
      expect(lib.component('Card')!.name, 'Card');
    });

    test('lookup returns null for unknown names', () {
      final lib = Library(
        components: [comp('Stack')],
        tools: const [],
      );
      expect(lib.component('Missing'), isNull);
    });

    test('names enumerates registrations in insertion order', () {
      final lib = Library(
        components: [
          comp('Stack'),
          comp('Card'),
          comp('Button'),
        ],
        tools: const [],
      );
      expect(lib.components.map((c) => c.name).toList(), [
        'Stack',
        'Card',
        'Button',
      ]);
    });

    test('duplicate names collapse to last-write-wins', () {
      final first = Component(
        name: 'Stack',
        schema: Schema.object(),
      );
      final second = Component(
        name: 'Stack',
        schema: Schema.object(),
      );
      final lib = Library(
        components: [first, second],
        tools: const [],
      );
      expect(lib.components.map((c) => c.name).toSet(), {'Stack'});
      // The second registration wins.
      expect(lib.component('Stack'), second);
    });

    test('extend layers extra components on top of the base', () {
      final base = Library(
        components: [comp('Stack')],
        tools: const [],
      );
      final extended = base.extend(components: [comp('Card')]);
      expect(extended.components.map((c) => c.name).toSet(), {'Stack', 'Card'});
      // Original library is untouched.
      expect(base.component('Card'), isNull);
    });

    test('extend supports overriding a base component', () {
      final base = Library(
        components: [comp('Stack')],
        tools: const [],
      );
      final replacement = Component(
        name: 'Stack',
        schema: Schema.object(),
      );
      final extended = base.extend(components: [replacement]);
      expect(extended.component('Stack'), replacement);
    });

    test('duplicate tool names collapse to last-write-wins', () {
      const first = Tool(name: 'search', description: 'first');
      const second = Tool(name: 'search', description: 'second');
      const lib = Library(
        components: [],
        tools: [first, second],
      );
      expect(lib.tool('search')!.description, 'second');
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
      final schema = Schema.fromMap(const {
        'type': 'object',
        'properties': {
          'value': {'type': 'string', 'x-reactive': true},
        },
      });
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
          properties: {'value': Schema.string()},
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
      final schema = Schema.fromMap(const {
        'type': 'object',
        'properties': {
          'value': {'type': 'string', 'x-reactive': true},
        },
      });
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
