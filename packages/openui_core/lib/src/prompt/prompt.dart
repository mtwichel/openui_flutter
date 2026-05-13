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
    '- Strings are double-quoted; numbers are bare; '
    'arrays are `[...]`; objects are `{key: value}`.'
    '\n'
    '- Operators: `+`, `-`, `*`, `/`, `==`, `!=`, `<`, `>`, `<=`,'
    ' `>=`, `&&`, `||`, `!`, ternary `a ? b : c`.'
    '\n'
    '- Actions are declared as `Action([step1, step2, ...])` (typically in '
    '`onClick`).'
    '\n'
    '- If a prop has `x-action: true` (for example `onClick`), pass '
    '`Action([...])`, not a bare `@Step(...)`.'
    '\n'
    '- Only these action calls are valid: `@Set`, `@Reset`, `@Run`, '
    '`@ToAssistant`. No other action calls are valid.'
    '\n'
    r'- `@Set($var, expr)` and `@Reset($var1, ...)` modify declared store '
    'variables.'
    '\n'
    '- `@Run(toolName, argName: value, ...)` triggers a declared tool. First '
    'argument is the tool name, then pass named arguments. Example: '
    '`@Run(snackbar, message: "Hello")`.'
    '\n'
    '- `@ToAssistant("message", "context?")` emits a continue-conversation '
    'action event.';

const List<String> _kDefaultRules = [
  'Respond with OpenUI Lang source only. No prose, no Markdown, no fences.',
  'Always declare a `root = ...` statement.',
  'Use only components from the list above. Do not invent new component names.',
  r'Use `$variables` for any state the user interacts with.',
  'Keep responses focused — render only the UI the user asked for.',
];

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
String generatePrompt<W>(
  Library<W> library, {
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
    final sig = '${component.name}(${component.schema.toJson()})';
    final desc = component.description;
    buf.writeln(desc != null ? '$sig — $desc' : sig);
  }
  buf.writeln();

  if (library.tools.isNotEmpty) {
    buf.writeln('TOOLS:');
    for (final tool in library.tools) {
      buf.writeln(
        '''${tool.name}(input: ${tool.input?.toJson()}, output: ${tool.output?.toJson()}) — ${tool.description}''',
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
