import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

class _TestTool extends Tool {
  _TestTool({
    required super.name,
    required super.description,
    super.input,
    super.output,
  });

  @override
  Future<ToolResult> callTool(Map<String, Object?> args) async =>
      ToolResult(args);
}

// Stub render — prompt tests never invoke the render callback.
String _noRender(dynamic a, dynamic b, dynamic c, dynamic d) => '';

Component<String> _comp(
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
  return Component<String>(
    name: name,
    description: description,
    internal: internal,
    schema: Schema.fromMap(schemaMap),
    render: _noRender,
  );
}

void main() {
  group('generatePrompt', () {
    test('empty components returns a string containing the grammar primer', () {
      final result = generatePrompt<String>(
        const Library<String>(components: [], tools: []),
      );
      expect(result, contains('GRAMMAR (essential):'));
      expect(result, contains('Programs are a sequence of statements'));
    });

    test('grammar primer explains x-action requires array of builtins', () {
      final result = generatePrompt<String>(
        const Library<String>(components: [], tools: []),
      );
      expect(result, contains('x-action: true'));
      expect(result, contains('[@Set('));
      expect(result, contains('Do not use a bare `@Step(...)`'));
      expect(result, contains('do not wrap'));
      expect(result, contains('Action(...)'));
    });

    test('grammar primer is explicit about valid built-in action calls', () {
      final result = generatePrompt<String>(
        const Library<String>(components: [], tools: []),
      );
      expect(result, contains('All `@Name(...)` calls are built-ins'));
      expect(
        result,
        contains(r'`$varName` is a store variable'),
      );
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
      // `@Query` shape and the canonical loading idiom must be pinned
      // in the primer so the LLM learns the new syntax.
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
        Library<String>(components: [c], tools: const []),
      );
      expect(result, contains('Card(children: array) — primary container'));
    });

    test(
      'component without description renders Name(props) with no suffix',
      () {
        final c = _comp(
          'Separator',
        );
        final result = generatePrompt(
          Library<String>(components: [c], tools: const []),
        );
        expect(result, contains('Separator()'));
        expect(result, isNot(contains('Separator() —')));
      },
    );

    test('component with no props renders Name() with no trailing content', () {
      final c = _comp('Separator');
      final result = generatePrompt(
        Library<String>(components: [c], tools: const []),
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
        Library<String>(components: [c], tools: const []),
      );
      expect(result, contains('label: string'));
      expect(result, isNot(contains('label?: string')));
      expect(result, contains('variant?: string'));
    });

    test('typeless prop ({}) renders as any', () {
      final c = _comp(
        'Button',
        properties: {'onClick': const {}},
      );
      final result = generatePrompt(
        Library<String>(components: [c], tools: const []),
      );
      expect(result, contains('onClick?: any'));
    });

    test('prop with type object renders as object', () {
      final c = _comp(
        'Form',
        properties: {
          'config': const {'type': 'object'},
        },
      );
      final result = generatePrompt(
        Library<String>(components: [c], tools: const []),
      );
      expect(result, contains('config?: object'));
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
        Library<String>(components: [c], tools: const []),
      );
      expect(result, contains('value: string'));
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
          Library<String>(components: [c], tools: const []),
        );
        expect(result, contains('label: string /* button text */'));
      },
    );

    test('non-empty tools list produces a TOOLS: section', () {
      final tool = _TestTool(
        name: 'search',
        description: 'full-text search',
        input: Schema.object(
          properties: {'query': Schema.string()},
          required: ['query'],
        ),
      );
      final result = generatePrompt<String>(
        Library<String>(components: const [], tools: [tool]),
      );
      expect(result, contains('TOOLS:'));
      expect(result, contains('search('));
      expect(result, contains('full-text search'));
    });

    test('empty tools list omits the TOOLS: section', () {
      final result = generatePrompt<String>(
        const Library<String>(components: [], tools: []),
      );
      expect(result, isNot(contains('TOOLS:')));
    });

    test('ToolSpec with object outputSchema renders output signature', () {
      final tool = _TestTool(
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
      final result = generatePrompt<String>(
        Library<String>(components: const [], tools: [tool]),
      );
      expect(result, contains('lookup('));
      expect(result, contains('→ {'));
      expect(result, contains('name?: string'));
      expect(result, contains('count?: integer'));
    });

    test('ToolSpec with scalar outputSchema renders output type', () {
      final tool = _TestTool(
        name: 'count',
        description: 'count items',
        input: Schema.object(properties: {}),
        output: Schema.integer(),
      );
      final result = generatePrompt<String>(
        Library<String>(components: const [], tools: [tool]),
      );
      expect(result, contains('→ integer'));
    });

    test(
      'ToolSpec with number outputSchema embeds JSON in the prompt line',
      () {
        final tool = _TestTool(
          name: 'measure',
          description: 'read a sensor',
          input: Schema.object(properties: {}),
          output: Schema.number(),
        );
        final result = generatePrompt<String>(
          Library<String>(components: const [], tools: [tool]),
        );
        expect(result, contains('measure('));
        expect(result, contains('"type":"number"'));
      },
    );

    test(
      'component schema that is not an object uses JSON in the signature',
      () {
        final c = Component<String>(
          name: 'Scalar',
          schema: Schema.number(),
          render: _noRender,
        );
        final result = generatePrompt(
          Library<String>(components: [c], tools: const []),
        );
        expect(result, contains('Scalar('));
        expect(result, contains('"type":"number"'));
      },
    );

    test('non-empty examples list produces an EXAMPLES: section', () {
      final result = generatePrompt<String>(
        const Library<String>(components: [], tools: []),
        examples: ['Example 1 — hello world', 'Example 2 — counter'],
      );
      expect(result, contains('EXAMPLES:'));
      expect(result, contains('Example 1 — hello world'));
      expect(result, contains('Example 2 — counter'));
    });

    test('empty examples list omits the EXAMPLES: section', () {
      final result = generatePrompt<String>(
        const Library<String>(components: [], tools: []),
      );
      expect(result, isNot(contains('EXAMPLES:')));
    });

    test('additionalRules are appended after default rules', () {
      final result = generatePrompt<String>(
        const Library<String>(components: [], tools: []),
        additionalRules: ['Never use inline styles.'],
      );
      expect(result, contains('RULES:'));
      expect(result, contains('- Never use inline styles.'));
      // Default rules still present.
      expect(result, contains('Always declare'));
    });

    test('caller-supplied preamble replaces the default preamble', () {
      final result = generatePrompt<String>(
        const Library<String>(components: [], tools: []),
        preamble: 'Custom preamble.',
      );
      expect(result, startsWith('Custom preamble.'));
      expect(result, isNot(contains('UI generator')));
    });

    test(
      'LibraryPromptExtension.prompt output contains every non-internal name',
      () {
        final lib = Library<String>(
          components: [
            _comp('Card', description: 'card'),
            _comp('Button', description: 'button'),
            _comp('Col', internal: true),
          ],
          tools: const [],
        );
        final result = lib.prompt();
        expect(result, contains('Card('));
        expect(result, contains('Button('));
        expect(result, isNot(contains('Col(')));
      },
    );

    test(
      'LibraryPromptExtension.prompt excludes internal: true components',
      () {
        final lib = Library<String>(
          components: [
            _comp('TabItem', internal: true),
            _comp('Tabs', description: 'tabs'),
          ],
          tools: const [],
        );
        final result = lib.prompt();
        expect(result, isNot(contains('TabItem(')));
        expect(result, contains('Tabs('));
      },
    );

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
          'onClick': const {},
        },
        required: ['label'],
        description: 'tappable button with action',
      );

      final result = generatePrompt(
        Library<String>(components: [stubCard, stubButton], tools: const []),
      );

      expect(
        result,
        contains('Card(children: array) — elevated surface container'),
      );
      expect(
        result,
        contains(
          'Button(label: string, variant?: string, onClick?: any)'
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
