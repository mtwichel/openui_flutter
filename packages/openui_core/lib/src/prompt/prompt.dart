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
    r'- `$varName` is a reactive state variable. '
    r'Declare it: `$count = 0`. Read it: `$count + 1`. Mutate it via actions.'
    '\n'
    '- Component calls use `Type(named: value, ...)`. '
    'Type names are capitalized.'
    '\n'
    '- Builtin calls use `@Name(...)`. Builtin names are '
    'capitalized after the `@`.'
    '\n'
    '- Strings are double-quoted; numbers are bare; '
    'arrays are `[...]`; objects are `{key: value}`.'
    '\n'
    '- Operators: `+`, `-`, `*`, `/`, `==`, `!=`, `<`, `>`, `<=`,'
    ' `>=`, `&&`, `||`, `!`, ternary `a ? b : c`.'
    '\n'
    '- Actions (only valid inside `onClick:`): '
    r'`@Set($var, expr)` assigns a new value; '
    r'`@Reset($var1, ...)` resets to defaults.';

const List<String> _kDefaultRules = [
  'Respond with OpenUI Lang source only. No prose, no Markdown, no fences.',
  'Always declare a `root = ...` statement.',
  'Use only components from the list above. Do not invent new component names.',
  r'Use `$variables` for any state the user interacts with.',
  'Keep responses focused — render only the UI the user asked for.',
];

/// Caller-constructed tool metadata for generated prompts.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class ToolSpec {
  /// Creates a [ToolSpec].
  const ToolSpec({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.outputSchema,
  });

  /// Tool name as it appears in the prompt.
  final String name;

  /// Human-facing description.
  final String description;

  /// JSON schema describing the tool's input.
  final Map<String, Object?> inputSchema;

  /// JSON schema describing the tool's output, or `null` if not applicable.
  final Map<String, Object?>? outputSchema;
}

/// Options controlling the shape of a generated system prompt.
///
/// Marked `@experimental` per D12.
@experimental
@immutable
class PromptOptions {
  /// Creates a [PromptOptions].
  const PromptOptions({
    this.tools = const [],
    this.preamble,
    this.examples = const [],
    this.additionalRules = const [],
  });

  /// Tool definitions appended under a `TOOLS:` heading. Omitted when empty.
  final List<ToolSpec> tools;

  /// Overrides the default preamble sentence when set.
  final String? preamble;

  /// Few-shot examples appended under an `EXAMPLES:` heading. Omitted when
  /// empty.
  final List<String> examples;

  /// Extra rules appended after the default rule set.
  final List<String> additionalRules;
}

/// Builds a complete system prompt from [components] and [options].
///
/// The output structure:
/// ```text
/// <preamble>
///
/// GRAMMAR (essential):
/// <grammar primer>
///
/// COMPONENTS (use only these):
/// ComponentName(prop: type, optionalProp?: type) — description
///
/// TOOLS:               ← omitted when options.tools is empty
/// ToolName(...) → ... — description
///
/// EXAMPLES:            ← omitted when options.examples is empty
/// ...
///
/// RULES:
/// - rule
/// ```
///
/// Marked `@experimental` per D12.
@experimental
String generatePrompt<W>(
  List<Component<W>> components, {
  PromptOptions options = const PromptOptions(),
}) {
  final buf = StringBuffer()
    ..writeln(options.preamble ?? _kDefaultPreamble)
    ..writeln()
    ..writeln('GRAMMAR (essential):')
    ..writeln(_kGrammarPrimer)
    ..writeln()
    ..writeln('COMPONENTS (use only these):');
  for (final component in components) {
    final schemaValue = component.schema.value;
    final properties = schemaValue['properties'];
    final required = schemaValue['required'];
    final propMap = properties is Map<String, Object?>
        ? properties
        : const <String, Object?>{};
    final innerSig = _schemaToSignature(
      propMap,
      required: _toStringList(required),
    );
    final sig = '${component.name}($innerSig)';
    final desc = component.description;
    buf.writeln(desc != null ? '$sig — $desc' : sig);
  }
  buf.writeln();

  if (options.tools.isNotEmpty) {
    buf.writeln('TOOLS:');
    for (final tool in options.tools) {
      final inputProps = tool.inputSchema['properties'];
      final inputRequired = tool.inputSchema['required'];
      final inputPropMap = inputProps is Map<String, Object?>
          ? inputProps
          : const <String, Object?>{};
      final inputSig = _schemaToSignature(
        inputPropMap,
        required: _toStringList(inputRequired),
      );

      final outSchema = tool.outputSchema;
      final String outputSig;
      if (outSchema == null) {
        outputSig = '';
      } else {
        final outProps = outSchema['properties'];
        if (outProps is Map<String, Object?>) {
          final outRequired = outSchema['required'];
          final outSig = _schemaToSignature(
            outProps,
            required: _toStringList(outRequired),
          );
          outputSig = ' → {$outSig}';
        } else {
          outputSig = ' → ${outSchema['type'] as String? ?? 'any'}';
        }
      }

      buf.writeln('${tool.name}($inputSig)$outputSig — ${tool.description}');
    }
    buf.writeln();
  }

  if (options.examples.isNotEmpty) {
    buf.writeln('EXAMPLES:');
    options.examples.forEach(buf.writeln);
    buf.writeln();
  }

  buf.writeln('RULES:');
  for (final rule in [..._kDefaultRules, ...options.additionalRules]) {
    buf.writeln('- $rule');
  }

  return buf.toString();
}

/// Maps a component's `properties` map to a parameter signature string.
///
/// Props in [required] render without `?`; all others render with `?`.
/// Typeless props (`{}`) render as `any`.
/// Reactive props (`x-reactive: true`) render their base `type`.
/// Props with a JSON schema `description` render `/* description */` inline.
String _schemaToSignature(
  Map<String, Object?> properties, {
  List<String> required = const [],
}) {
  if (properties.isEmpty) return '';
  final parts = <String>[];
  for (final entry in properties.entries) {
    final propName = entry.key;
    final propSchema = entry.value;

    String type;
    String? propDescription;

    if (propSchema is Map<String, Object?>) {
      type = switch (propSchema['type']) {
        'string' => 'string',
        'number' => 'number',
        'integer' => 'integer',
        'boolean' => 'boolean',
        'array' => 'array',
        'object' => 'object',
        _ => 'any',
      };
      propDescription = propSchema['description'] as String?;
    } else {
      type = 'any';
    }

    final qualifier = required.contains(propName) ? '' : '?';
    if (propDescription != null) {
      parts.add('$propName$qualifier: $type /* $propDescription */');
    } else {
      parts.add('$propName$qualifier: $type');
    }
  }
  return parts.join(', ');
}

List<String> _toStringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String) item,
  ];
}

/// Adds `.prompt(PromptOptions)` to [Library].
///
/// Filters components where [Component.internal] is `true` before
/// delegating to [generatePrompt].
///
/// Marked `@experimental` per D12.
@experimental
extension LibraryPromptExtension<W> on Library<W> {
  /// Generates a system prompt from all non-internal registered components.
  String prompt(PromptOptions options) {
    final filtered = components.where((c) => !c.internal).toList();
    return generatePrompt(filtered, options: options);
  }
}
