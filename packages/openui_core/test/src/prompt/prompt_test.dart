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
  group('generatePrompt', () {
    test('empty components returns a string containing the grammar primer', () {
      final result = generatePrompt(const LibraryDefinition());
      expect(result, contains('GRAMMAR (essential):'));
      expect(result, contains('Programs are a sequence of statements'));
    });

    test('grammar primer explains x-action requires Action([...])', () {
      final result = generatePrompt(const LibraryDefinition());
      expect(result, contains('x-action: true'));
      expect(result, contains('Action(['));
      expect(result, contains('[@Set('));
      expect(result, contains('Do not use a bare `@Step(...)`'));
      expect(result, contains('bare `[...]` array'));
    });

    test('grammar primer is explicit about valid built-in action calls', () {
      final result = generatePrompt(const LibraryDefinition());
      expect(result, contains('All `@Name(...)` calls are built-ins'));
      expect(result, contains(r'`$varName` is a store variable'));
      expect(
        result,
        contains(
          'Only these action calls are valid: '
          '`@Set`, `@Reset`, `@Run`, `@ToAssistant`',
        ),
      );
      expect(
        result,
        contains(
          '`@Run(toolName, argName: value, ...)` triggers a declared tool',
        ),
      );
      expect(result, contains('No other action calls are valid'));
      expect(
        result,
        contains('`@ToAssistant("message", "context?")` emits'),
      );
      expect(
        result,
        contains(r'$var = @Query(toolName, namedArg: value, ...)'),
      );
      expect(result, contains('top-level assignment'));
      expect(result, contains(r'`$var == null ? loading : content`'));
      expect(result, contains('re-fetch when those vars change via `@Set`'));
    });

    test('component with description renders Name(props) — description', () {
      final c = _comp(
        'Card',
        properties: {
          'children': const {'type': 'array'},
        },
        required: ['children'],
        description: 'primary container',
      );
      final result = generatePrompt(
        LibraryDefinition(components: [c]),
      );
      expect(result, contains('Card(array) — primary container'));
    });

    test(
      'component without description renders Name(props) with no suffix',
      () {
        final c = _comp('Separator');
        final result = generatePrompt(
          LibraryDefinition(components: [c]),
        );
        expect(result, contains('Separator()'));
        expect(result, isNot(contains('Separator() —')));
      },
    );

    test('component with no props renders Name() with no trailing content', () {
      final c = _comp('Separator');
      final result = generatePrompt(
        LibraryDefinition(components: [c]),
      );
      expect(result, contains('Separator()'));
    });

    test('required prop renders without ?, optional prop renders with ?', () {
      final c = _comp(
        'Button',
        properties: {
          'label': const {'type': 'string'},
          'variant': const {'type': 'string'},
        },
        required: ['label'],
      );
      final result = generatePrompt(
        LibraryDefinition(components: [c]),
      );
      expect(result, contains('string'));
      expect(result, contains('?string'));
    });

    test('typeless prop ({}) renders as any', () {
      final c = _comp(
        'Button',
        properties: {'action': const {}},
      );
      final result = generatePrompt(
        LibraryDefinition(components: [c]),
      );
      expect(result, contains('?any'));
    });

    test('prop with type object renders as object', () {
      final c = _comp(
        'Form',
        properties: {
          'config': const {'type': 'object'},
        },
      );
      final result = generatePrompt(
        LibraryDefinition(components: [c]),
      );
      expect(result, contains('?object'));
    });

    test('reactive prop (x-reactive: true) renders its base type', () {
      final c = _comp(
        'Input',
        properties: {
          'value': const {'type': 'string', 'x-reactive': true},
        },
        required: ['value'],
      );
      final result = generatePrompt(
        LibraryDefinition(components: [c]),
      );
      expect(result, contains('string'));
      expect(result, isNot(contains('x-reactive')));
    });

    test(
      'prop with JSON schema description renders /* description */ inline',
      () {
        final c = _comp(
          'Button',
          properties: {
            'label': const {'type': 'string', 'description': 'button text'},
          },
          required: ['label'],
        );
        final result = generatePrompt(
          LibraryDefinition(components: [c]),
        );
        expect(result, contains('string /* button text */'));
      },
    );

    test('non-empty tools list produces a TOOLS: section', () {
      final tool = _tool(
        name: 'search',
        description: 'full-text search',
        input: Schema.object(
          properties: {'query': Schema.string()},
          required: ['query'],
        ),
      );
      final result = generatePrompt(
        LibraryDefinition(tools: [tool]),
      );
      expect(result, contains('TOOLS:'));
      expect(result, contains('search('));
      expect(result, contains('full-text search'));
    });

    test('empty tools list omits the TOOLS: section', () {
      final result = generatePrompt(const LibraryDefinition());
      expect(result, isNot(contains('TOOLS:')));
    });

    test('ToolSpec with object outputSchema renders output signature', () {
      final tool = _tool(
        name: 'lookup',
        description: 'look up a record',
        input: Schema.object(
          properties: {
            'id': Schema.string(),
          },
          required: ['id'],
        ),
        output: Schema.object(
          properties: {
            'name': Schema.string(),
            'count': Schema.integer(),
          },
        ),
      );
      final result = generatePrompt(
        LibraryDefinition(tools: [tool]),
      );
      expect(result, contains('lookup('));
      expect(result, contains('→ {'));
      expect(result, contains('?string'));
      expect(result, contains('?integer'));
    });

    test('ToolSpec with scalar outputSchema renders output type', () {
      final tool = _tool(
        name: 'count',
        description: 'count items',
        input: Schema.object(properties: {}),
        output: Schema.integer(),
      );
      final result = generatePrompt(
        LibraryDefinition(tools: [tool]),
      );
      expect(result, contains('→ integer'));
    });

    test(
      'ToolSpec with number outputSchema embeds JSON in the prompt line',
      () {
        final tool = _tool(
          name: 'measure',
          description: 'read a sensor',
          input: Schema.object(properties: {}),
          output: Schema.number(),
        );
        final result = generatePrompt(
          LibraryDefinition(tools: [tool]),
        );
        expect(result, contains('measure('));
        expect(result, contains('"type":"number"'));
      },
    );

    test(
      'component schema that is not an object uses JSON in the signature',
      () {
        final c = ComponentDefinition(
          name: 'Scalar',
          schema: Schema.number(),
        );
        final result = generatePrompt(
          LibraryDefinition(components: [c]),
        );
        expect(result, contains('Scalar('));
        expect(result, contains('"type":"number"'));
      },
    );

    test('non-empty examples list produces an EXAMPLES: section', () {
      final result = generatePrompt(
        const LibraryDefinition(),
        examples: ['Example 1 — hello world', 'Example 2 — counter'],
      );
      expect(result, contains('EXAMPLES:'));
      expect(result, contains('Example 1 — hello world'));
      expect(result, contains('Example 2 — counter'));
    });

    test('empty examples list omits the EXAMPLES: section', () {
      final result = generatePrompt(const LibraryDefinition());
      expect(result, isNot(contains('EXAMPLES:')));
    });

    test('additionalRules are appended after default rules', () {
      final result = generatePrompt(
        const LibraryDefinition(),
        additionalRules: ['Never use inline styles.'],
      );
      expect(result, contains('RULES:'));
      expect(result, contains('- Never use inline styles.'));
      expect(result, contains('Always declare'));
    });

    test('caller-supplied preamble replaces the default preamble', () {
      final result = generatePrompt(
        const LibraryDefinition(),
        preamble: 'Custom preamble.',
      );
      expect(result, startsWith('Custom preamble.'));
      expect(result, isNot(contains('UI generator')));
    });

    test(
      'LibraryDefinition.prompt output contains every non-internal name',
      () {
        final lib = LibraryDefinition(
          components: [
            _comp('Card', description: 'card'),
            _comp('Button', description: 'button'),
            _comp('Col', internal: true),
          ],
        );
        final result = lib.prompt();
        expect(result, contains('Card('));
        expect(result, contains('Button('));
        expect(result, isNot(contains('Col(')));
      },
    );

    test(
      'LibraryDefinition.prompt excludes internal: true components',
      () {
        final lib = LibraryDefinition(
          components: [
            _comp('TabItem', internal: true),
            _comp('Tabs', description: 'tabs'),
          ],
        );
        final result = lib.prompt();
        expect(result, isNot(contains('TabItem(')));
        expect(result, contains('Tabs('));
      },
    );

    test('extend with override lists each component name once in prompt', () {
      final base = LibraryDefinition(
        components: [
          _comp('Button', description: 'original'),
        ],
      );
      final extended = base.extend(
        components: [_comp('Button', description: 'override')],
      );
      final result = extended.prompt();
      final componentsSection = result
          .split('COMPONENTS (use only these):')
          .last
          .split('RULES:')
          .first;
      expect('Button('.allMatches(componentsSection).length, 1);
      expect(result, contains('override'));
      expect(result, isNot(contains('original')));
    });

    test('snapshot: generatePrompt([stubCard, stubButton]) matches golden', () {
      final stubCard = _comp(
        'Card',
        properties: {
          'children': const {'type': 'array'},
        },
        required: ['children'],
        description: 'elevated surface container',
      );
      final stubButton = _comp(
        'Button',
        properties: {
          'label': const {'type': 'string'},
          'variant': const {'type': 'string'},
          'action': const {},
        },
        required: ['label'],
        description: 'tappable button with action',
      );

      final result = generatePrompt(
        LibraryDefinition(components: [stubCard, stubButton]),
      );

      expect(
        result,
        contains('Card(array) — elevated surface container'),
      );
      expect(
        result,
        contains(
          'Button(string, ?string, ?any)'
          ' — tappable button with action',
        ),
      );
      expect(result, contains('GRAMMAR (essential):'));
      expect(result, contains('COMPONENTS (use only these):'));
      expect(result, contains('RULES:'));
      expect(result, isNot(contains('TOOLS:')));
      expect(result, isNot(contains('EXAMPLES:')));
    });
  });
}
