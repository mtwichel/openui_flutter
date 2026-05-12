import 'package:openui_core/openui_core.dart';
import 'package:test/test.dart';

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
  return defineComponent<String>(
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
      final result = generatePrompt<String>([]);
      expect(result, contains('GRAMMAR (essential):'));
      expect(result, contains('Programs are a sequence of statements'));
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
      final result = generatePrompt([c]);
      expect(result, contains('Card(children: array) — primary container'));
    });

    test(
      'component without description renders Name(props) with no suffix',
      () {
        final c = _comp(
          'Separator',
        );
        final result = generatePrompt([c]);
        expect(result, contains('Separator()'));
        expect(result, isNot(contains('Separator() —')));
      },
    );

    test('component with no props renders Name() with no trailing content', () {
      final c = _comp('Separator');
      final result = generatePrompt([c]);
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
      final result = generatePrompt([c]);
      expect(result, contains('label: string'));
      expect(result, isNot(contains('label?: string')));
      expect(result, contains('variant?: string'));
    });

    test('typeless prop ({}) renders as any', () {
      final c = _comp(
        'Button',
        properties: {'onClick': const {}},
      );
      final result = generatePrompt([c]);
      expect(result, contains('onClick?: any'));
    });

    test('reactive prop (x-reactive: true) renders its base type', () {
      final c = _comp(
        'Input',
        properties: {
          'value': const {'type': 'string', 'x-reactive': true},
        },
        required: ['value'],
      );
      final result = generatePrompt([c]);
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
        final result = generatePrompt([c]);
        expect(result, contains('label: string /* button text */'));
      },
    );

    test('non-empty tools list produces a TOOLS: section', () {
      const tool = ToolSpec(
        name: 'search',
        description: 'full-text search',
        inputSchema: {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
          },
          'required': ['query'],
        },
      );
      final result = generatePrompt<String>(
        [],
        options: const PromptOptions(tools: [tool]),
      );
      expect(result, contains('TOOLS:'));
      expect(result, contains('search('));
      expect(result, contains('full-text search'));
    });

    test('empty tools list omits the TOOLS: section', () {
      final result = generatePrompt<String>([]);
      expect(result, isNot(contains('TOOLS:')));
    });

    test('ToolSpec with object outputSchema renders output signature', () {
      const tool = ToolSpec(
        name: 'lookup',
        description: 'look up a record',
        inputSchema: {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
          },
          'required': ['id'],
        },
        outputSchema: {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'count': {'type': 'integer'},
          },
        },
      );
      final result = generatePrompt<String>(
        [],
        options: const PromptOptions(tools: [tool]),
      );
      expect(result, contains('lookup('));
      expect(result, contains('→ {'));
      expect(result, contains('name?: string'));
      expect(result, contains('count?: integer'));
    });

    test('ToolSpec with scalar outputSchema renders output type', () {
      const tool = ToolSpec(
        name: 'count',
        description: 'count items',
        inputSchema: {'type': 'object', 'properties': {}},
        outputSchema: {'type': 'integer'},
      );
      final result = generatePrompt<String>(
        [],
        options: const PromptOptions(tools: [tool]),
      );
      expect(result, contains('→ integer'));
    });

    test('non-empty examples list produces an EXAMPLES: section', () {
      final result = generatePrompt<String>(
        [],
        options: const PromptOptions(
          examples: ['Example 1 — hello world', 'Example 2 — counter'],
        ),
      );
      expect(result, contains('EXAMPLES:'));
      expect(result, contains('Example 1 — hello world'));
      expect(result, contains('Example 2 — counter'));
    });

    test('empty examples list omits the EXAMPLES: section', () {
      final result = generatePrompt<String>([]);
      expect(result, isNot(contains('EXAMPLES:')));
    });

    test('additionalRules are appended after default rules', () {
      final result = generatePrompt<String>(
        [],
        options: const PromptOptions(
          additionalRules: ['Never use inline styles.'],
        ),
      );
      expect(result, contains('RULES:'));
      expect(result, contains('- Never use inline styles.'));
      // Default rules still present.
      expect(result, contains('Always declare'));
    });

    test('caller-supplied preamble replaces the default preamble', () {
      final result = generatePrompt<String>(
        [],
        options: const PromptOptions(preamble: 'Custom preamble.'),
      );
      expect(result, startsWith('Custom preamble.'));
      expect(result, isNot(contains('UI generator')));
    });

    test(
      'LibraryPromptExtension.prompt output contains every non-internal name',
      () {
        final lib = Library<String>([
          _comp('Card', description: 'card'),
          _comp('Button', description: 'button'),
          _comp('Col', internal: true),
        ]);
        final result = lib.prompt(const PromptOptions());
        expect(result, contains('Card('));
        expect(result, contains('Button('));
        expect(result, isNot(contains('Col(')));
      },
    );

    test(
      'LibraryPromptExtension.prompt excludes internal: true components',
      () {
        final lib = Library<String>([
          _comp('TabItem', internal: true),
          _comp('Tabs', description: 'tabs'),
        ]);
        final result = lib.prompt(const PromptOptions());
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
        [stubCard, stubButton],
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
