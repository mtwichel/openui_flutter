import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:meta/meta.dart';
import 'package:openui_core/src/library/definitions.dart';

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
    '- Component calls use positional arguments only: `Type(arg1, arg2, ...)`. '
    'Args map to each component schema property in order. '
    'Type names are capitalized.'
    '\n'
    '- All `@Name(...)` calls are built-ins.'
    '\n'
    '- Iterate with `@Each(list, "name", template)` — the second arg '
    'is a string literal naming the loop variable, used bare inside '
    'the template (e.g. `@Each(items, "row", Card(row.name))`). '
    r'`$index` is also in scope.'
    '\n'
    '- Strings are double-quoted; numbers are bare; '
    'arrays are `[...]`; objects are `{key: value}`.'
    '\n'
    '- Operators: `+`, `-`, `*`, `/`, `==`, `!=`, `<`, `>`, `<=`,'
    ' `>=`, `&&`, `||`, `!`, ternary `a ? b : c`.'
    '\n'
    '- If a prop has `x-action: true` (for example `action` on `Button`), '
    'pass `Action([...])` in that positional slot, for example '
    r'`Button("OK", Action([@Set($count, $count + 1)]), "primary")` or '
    r'`Button("Run", Action([@Run(refresh), @Set($flag, 1)]), "secondary")`.'
    '\n'
    '- Do not use a bare `@Step(...)` or a bare `[...]` array on `x-action` '
    'props. A single-step handler is still wrapped: '
    '`Action([@ToAssistant("hello")])`.'
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
    'query id: `@Run(data)`.'
    '\n'
    '- `name = Query("tool", {args}, {defaults}, refreshSec?)` is a top-level '
    'assignment only (not inside `?:`, arrays, or props). Use a regular '
    r'identifier (not a `$`-prefixed name) for the query binding. The third '
    'argument is the '
    'default value shown while loading and until the fetch completes. Query '
    r'args that reference `$vars` re-fetch when those vars change. Re-fire '
    'manually with `@Run(name)`.'
    '\n'
    '- `@ToAssistant("message", "context?")` emits a continue-conversation '
    'action event.';

const _kXActionRule =
    'For every `x-action` prop (for example `action` on `Button`), use '
    '`Action([@steps...])` with at least one builtin step — never a bare '
    '`@Set(...)` or bare `[@Set(...)]` array.';

const List<String> _kDefaultRules = [
  'Respond with OpenUI Lang source only. No prose, no Markdown, no fences.',
  'Always declare a `root = ...` statement.',
  'Use only components from the list above. Do not invent new component names.',
  r'Use `$variables` for any state the user interacts with.',
  'Keep responses focused — render only the UI the user asked for.',
  _kXActionRule,
];

String _jsonTypeKeyword(Map<String, Object?> propSchema) {
  final stripped = Map<String, Object?>.from(propSchema)
    ..remove('x-reactive')
    ..remove('description');
  if (stripped.isEmpty) return 'any';
  final t = stripped['type'];
  if (t == 'string') return 'string';
  if (t == 'integer') return 'integer';
  if (t == 'array') return 'array';
  if (t == 'object') return 'object';
  return 'any';
}

/// Renders [schema]'s top-level `properties` as `name: type` segments for
/// LLM-facing prompts (not raw `toJson()`).
String _formatObjectPropertyList(Schema schema) {
  final root = schema.value;
  final propsRaw = root['properties'];
  if (propsRaw is! Map) return '';
  final props = <String, Object?>{
    for (final e in propsRaw.entries) '${e.key}': e.value,
  };
  final requiredRaw = root['required'];
  final required = <String>{};
  if (requiredRaw is List) {
    for (final e in requiredRaw) {
      required.add(e.toString());
    }
  }
  final segments = <String>[];
  for (final name in props.keys) {
    final raw = props[name];
    if (raw is! Map<String, Object?>) {
      final opt = !required.contains(name);
      segments.add('${opt ? '?' : ''}any');
      continue;
    }
    final opt = !required.contains(name);
    final typeName = _jsonTypeKeyword(raw);
    final desc = raw['description'];
    var piece = '${opt ? '?' : ''}$typeName';
    if (desc is String && desc.isNotEmpty) {
      piece = '$piece /* $desc */';
    }
    segments.add(piece);
  }
  return segments.join(', ');
}

String _formatComponentSignature(ComponentDefinition component) {
  final root = component.schema.value;
  if (root['type'] != 'object') {
    return '${component.name}(${component.schema.toJson()})';
  }
  final propsAny = root['properties'];
  if (propsAny is! Map || propsAny.isEmpty) {
    return '${component.name}()';
  }
  final inner = _formatObjectPropertyList(component.schema);
  return inner.isEmpty ? '${component.name}()' : '${component.name}($inner)';
}

String? _formatToolOutput(Schema? output) {
  if (output == null) return 'null';
  final root = output.value;
  final t = root['type'];
  if (t == 'integer') return '→ integer';
  if (t == 'string') return '→ string';
  if (t == 'boolean') return '→ boolean';
  if (t == 'array') return '→ array';
  if (t == 'object') {
    final inner = _formatObjectPropertyList(output);
    if (inner.isEmpty) return '→ {}';
    return '→ {$inner}';
  }
  return output.toJson();
}

/// Builds a complete system prompt from a [LibraryDefinition] and options.
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
  LibraryDefinition library, {
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
  for (final component in _effectiveByName(library.components, (c) => c.name)) {
    final sig = _formatComponentSignature(component);
    final desc = component.description;
    buf.writeln(desc != null ? '$sig — $desc' : sig);
  }
  buf.writeln();

  if (library.tools.isNotEmpty) {
    buf.writeln('TOOLS:');
    for (final tool in _effectiveByName(library.tools, (t) => t.name)) {
      buf.writeln(
        '${tool.name}(input: ${tool.input?.toJson()}, '
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

/// Last-write-wins deduplication by [nameOf] for prompt generation.
List<T> _effectiveByName<T>(List<T> items, String Function(T) nameOf) {
  final byName = <String, T>{};
  for (final item in items) {
    byName[nameOf(item)] = item;
  }
  return byName.values.toList();
}
