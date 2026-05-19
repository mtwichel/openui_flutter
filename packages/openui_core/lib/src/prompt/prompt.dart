import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:meta/meta.dart';
import 'package:openui_core/src/library/library.dart';

const String _kDefaultPreamble =
    'You are a UI generator that outputs OpenUI Lang only. '
    'OpenUI Lang is a small declarative language that streams as a response '
    'and renders as native Flutter widgets. '
    'Respond with valid OpenUI Lang source code only — no Markdown, no code '
    'fences, no commentary, no explanations.';

// Mirrors the grammar section of docs/lang-reference.md.
const String _kGrammarPrimer =
    '- Programs are a sequence of statements separated by newlines.'
    '\n'
    '- Each statement is `identifier = expression`.'
    '\n'
    '- A statement named `root` is the top-level UI; the runtime renders it.'
    '\n'
    r'- `$varName` is a store variable. Declare at top-level (for example '
    r'`$count = 0`) and read it in expressions (for example `$count + 1`).'
    '\n'
    '- Component calls use `Type(named: value, ...)`. '
    'Type names are capitalized.'
    '\n'
    '- All `@Name(...)` calls are built-ins.'
    '\n'
    '- Iterate with `@Each(list, "name", template)` — the second arg '
    'is a string literal naming the loop variable, used bare inside '
    'the template (e.g. `@Each(items, "row", Card(title: row.name))`). '
    r'`$index` is also in scope.'
    '\n'
    '- Strings are double-quoted; numbers are bare; '
    'arrays are `[...]`; objects are `{key: value}`.'
    '\n'
    '- Operators: `+`, `-`, `*`, `/`, `==`, `!=`, `<`, `>`, `<=`,'
    ' `>=`, `&&`, `||`, `!`, ternary `a ? b : c`.'
    '\n'
    '- If a prop has `x-action: true` (for example `onClick`), pass a '
    'literal array of action steps only, for example '
    r'`onClick: [@Set($count, $count + 1)]` or '
    r'`onClick: [@Run(refresh), @Set($flag, 1)]`.'
    '\n'
    '- Do not use a bare `@Step(...)` for `x-action` props; do not wrap '
    'steps in `Action(...)`. A single-step handler is still a '
    'one-element array: `[@ToAssistant("hello")]`.'
    '\n'
    '- Only these action calls are valid: `@Set`, `@Reset`, `@Run`, '
    '`@ToAssistant`. No other action calls are valid.'
    '\n'
    r'- `@Set($var, expr)` and `@Reset($var1, ...)` modify declared store '
    'variables.'
    '\n'
    '- `@Run(toolName, argName: value, ...)` triggers a declared tool. First '
    'argument is the tool name, then pass named arguments. Example: '
    '`@Run(snackbar, message: "Hello")`. To re-fire a query, pass the '
    r'state-var: `@Run($products)`.'
    '\n'
    r'- `$var = @Query(toolName, namedArg: value, ...)` is a top-level '
    'assignment only (not inside `?:`, arrays, or props). The tool result is '
    'stored as a '
    r'map/list/primitive (`$catalog.products`, etc.). The slot is `null` until '
    r'the fetch completes — use `$var == null ? loading : content`. Query args '
    r'that reference other `$vars` re-fetch when those vars change via `@Set`. '
    r'Re-fire manually with `@Run($var)`.'
    '\n'
    '- `@ToAssistant("message", "context?")` emits a continue-conversation '
    'action event.';

const List<String> _kDefaultRules = [
  'Respond with OpenUI Lang source only. No prose, no Markdown, no fences.',
  'Always declare a `root = ...` statement.',
  'Use only components from the list above. Do not invent new component names.',
  r'Use `$variables` for any state the user interacts with.',
  'Keep responses focused — render only the UI the user asked for.',
  r'''For every `x-action` prop (for example `onClick`), use a non-empty array of builtins only, for example `[@Set($x, 1)]` — never a bare `@Set(...)` or `Action(...)`.''',
];

String _formatSchema(Schema schema) {
  // Extract enum if present
  final enumValues = schema.enumValues;
  if (enumValues != null && enumValues.isNotEmpty) {
    return enumValues.map((e) => e is String ? '"$e"' : '$e').join(' | ');
  }

  final type = schema.type;

  if (type == 'string') return 'string';
  if (type == 'integer') return 'integer';
  if (type == 'number') return 'number';
  if (type == 'boolean') return 'boolean';
  if (type == 'null') return 'null';

  if (type == 'array') {
    final listSchema = ListSchema.fromMap(schema.value);
    final items = listSchema.items;
    if (items != null) {
      final inner = _formatSchema(items);
      if (inner.contains('|') || inner.startsWith('{')) {
        return '($inner)[]';
      }
      return '$inner[]';
    }
    return 'array';
  }

  if (type == 'object') {
    final objectSchema = ObjectSchema.fromMap(schema.value);
    final properties = objectSchema.properties;
    if (properties != null && properties.isNotEmpty) {
      final required = objectSchema.required ?? const <String>[];
      final segments = <String>[];
      for (final entry in properties.entries) {
        final name = entry.key;
        final propVal = entry.value;
        final opt = !required.contains(name);

        final typeName = _formatSchema(propVal);
        final desc = propVal.description;
        var piece = '$name${opt ? '?' : ''}: $typeName';
        if (desc is String && desc.isNotEmpty) {
          piece = '$piece /* $desc */';
        }
        segments.add(piece);
      }
      return '{${segments.join(', ')}}';
    }
    return 'object';
  }

  if (type is List) {
    return type
        .map((t) {
          if (t is Map<String, Object?>) {
            return _formatSchema(Schema.fromMap(t));
          }
          if (t is Schema) {
            return _formatSchema(t);
          }
          return t.toString();
        })
        .join(' | ');
  }

  return 'any';
}

/// Renders [schema]'s top-level `properties` as `name: type` segments for
/// LLM-facing prompts (not raw `toJson()`).
String _formatObjectPropertyList(Schema schema) {
  final objectSchema = ObjectSchema.fromMap(schema.value);
  final properties = objectSchema.properties;
  if (properties == null || properties.isEmpty) return '';

  final required = objectSchema.required ?? const <String>[];
  final segments = <String>[];
  for (final entry in properties.entries) {
    final name = entry.key;
    final propVal = entry.value;
    final opt = !required.contains(name);

    final typeName = _formatSchema(propVal);
    final desc = propVal.description;
    var piece = '$name${opt ? '?' : ''}: $typeName';
    if (desc is String && desc.isNotEmpty) {
      piece = '$piece /* $desc */';
    }
    segments.add(piece);
  }
  return segments.join(', ');
}

String _formatComponentSignature(Component component) {
  final schema = component.schema;
  if (schema.type != 'object') {
    return '${component.name}(${_formatSchema(schema)})';
  }
  final objectSchema = ObjectSchema.fromMap(schema.value);
  final properties = objectSchema.properties;
  if (properties == null || properties.isEmpty) {
    return '${component.name}()';
  }
  final inner = _formatObjectPropertyList(schema);
  return inner.isEmpty ? '${component.name}()' : '${component.name}($inner)';
}

String? _formatToolOutput(Schema? output) {
  if (output == null) return 'null';
  return '→ ${_formatSchema(output)}';
}

/// Builds a complete system prompt from a [Library] and other options.
///
/// The output structure:
/// ```text
/// <preamble>
///
/// GRAMMAR (essential):
/// <grammar primer>
///
/// [libraryPrompt]
///
/// COMPONENTS (use only these):
/// ComponentName(prop: type, optionalProp?: type) — description
///
/// TOOLS:               ← omitted when [tools] is empty
/// ToolName(...) → ... — description
///
/// EXAMPLES:            ← omitted when [examples] is empty
/// ...
///
/// RULES:
/// - rule
/// ```
///
/// Marked `@experimental` per D12.
@experimental
String generatePrompt(
  Library library, {
  String? preamble,
  List<String> examples = const [],
  List<String> additionalRules = const [],
}) {
  final buf = StringBuffer()
    ..writeln(preamble ?? _kDefaultPreamble)
    ..writeln()
    ..writeln('GRAMMAR (essential):')
    ..writeln(_kGrammarPrimer)
    ..writeln()
    ..writeln(library.libraryPrompt != null ? 'HOW TO USE THE COMPONENTS' : '')
    ..writeln(library.libraryPrompt ?? '')
    ..writeln('COMPONENTS (use only these):');
  for (final component in library.components) {
    final sig = _formatComponentSignature(component);
    final desc = component.description;
    buf.writeln(desc != null ? '$sig — $desc' : sig);
  }
  buf.writeln();

  if (library.tools.isNotEmpty) {
    buf.writeln('TOOLS:');
    for (final tool in library.tools) {
      final inputSig = tool.input != null ? _formatSchema(tool.input!) : 'null';
      buf.writeln(
        '${tool.name}(input: $inputSig, '
        'output: ${_formatToolOutput(tool.output)}) — ${tool.description}',
      );
    }
    buf.writeln();
  }

  if (examples.isNotEmpty) {
    buf.writeln('EXAMPLES:');
    examples.forEach(buf.writeln);
    buf.writeln();
  }

  buf.writeln('RULES:');
  for (final rule in [..._kDefaultRules, ...additionalRules]) {
    buf.writeln('- $rule');
  }

  return buf.toString();
}
