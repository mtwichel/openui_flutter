import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

ComponentDefinition _comp(
  String name, {
  Map<String, Object?> properties = const {},
  List<String>? required,
  String? description,
  bool internal = false,
}) {
  final schemaMap = <String, Object?>{
    'type': 'object',
    'properties': properties,
    if (required != null && required.isNotEmpty) 'required': required,
  };
  return ComponentDefinition(
    name: name,
    description: description,
    internal: internal,
    schema: Schema.fromMap(schemaMap),
  );
}

ToolDefinition _tool({
  required String name,
  required String description,
  Schema? input,
  Schema? output,
}) => ToolDefinition(
  name: name,
  description: description,
  input: input,
  output: output,
);

void main() {
  group('ComponentDefinition', () {
    test('description sets the field', () {
      final c = _comp('X', description: 'a test component');
      expect(c.description, 'a test component');
    });

    test('internal defaults to false', () {
      final c = _comp('X');
      expect(c.internal, isFalse);
    });

    test('internal: true sets the field', () {
      final c = _comp('X', internal: true);
      expect(c.internal, isTrue);
    });
  });

  group('LibraryDefinition', () {
    ComponentDefinition comp(String name) => _comp(name);

    test('lookup returns the registered component', () {
      final lib = LibraryDefinition(
        components: [comp('Stack'), comp('Card')],
      );
      expect(lib.component('Stack'), isNotNull);
      expect(lib.component('Stack')!.name, 'Stack');
      expect(lib.component('Card')!.name, 'Card');
    });

    test('lookup returns null for unknown names', () {
      final lib = LibraryDefinition(components: [comp('Stack')]);
      expect(lib.component('Missing'), isNull);
    });

    test('components preserves insertion order', () {
      final lib = LibraryDefinition(
        components: [comp('Stack'), comp('Card'), comp('Button')],
      );
      expect(lib.components.map((c) => c.name).toList(), [
        'Stack',
        'Card',
        'Button',
      ]);
    });

    test('duplicate names collapse to last-write-wins', () {
      final first = _comp('Stack', description: 'first');
      final second = _comp('Stack', description: 'second');
      final lib = LibraryDefinition(components: [first, second]);
      expect(lib.components.map((c) => c.name).toSet(), {'Stack'});
      expect(lib.component('Stack')!.description, 'second');
    });

    test('extend layers extra components on top of the base', () {
      final base = LibraryDefinition(components: [comp('Stack')]);
      final extended = base.extend(components: [comp('Card')]);
      expect(
        extended.components.map((c) => c.name).toSet(),
        {'Stack', 'Card'},
      );
      expect(base.component('Card'), isNull);
    });

    test('extend supports overriding a base component', () {
      final base = LibraryDefinition(components: [comp('Stack')]);
      final replacement = _comp('Stack', description: 'overridden');
      final extended = base.extend(components: [replacement]);
      expect(extended.component('Stack')!.description, 'overridden');
    });

    test('duplicate tool names collapse to last-write-wins', () {
      final first = _tool(name: 'search', description: 'first');
      final second = _tool(name: 'search', description: 'second');
      final lib = LibraryDefinition(tools: [first, second]);
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
        final schema = Schema.object(properties: {'value': Schema.string()});
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
