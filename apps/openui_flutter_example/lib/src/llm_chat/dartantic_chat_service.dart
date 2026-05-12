import 'package:dartantic_ai/dartantic_ai.dart';

import 'package:openui_flutter_example/src/llm_chat/llm_chat_service.dart';

/// dartantic provider name registered by `main.dart` and consumed by
/// the default agent string below. Sharing the constant keeps the
/// registration and consumption in lockstep — change one and you change
/// both.
const String kFirebaseVertexProvider = 'firebase-vertex';

/// Default agent string used by the production service.
const String _kDefaultAgent = '$kFirebaseVertexProvider:gemini-2.5-flash';

/// Live-LLM implementation of [LlmChatService] backed by a dartantic
/// [Chat] against Gemini via Firebase AI Logic (Vertex AI). The
/// `firebase-vertex` provider factory must be registered in `main.dart`
/// before instantiation.
class DartanticChatService implements LlmChatService {
  /// Creates a [DartanticChatService]. [agentString] is the dartantic
  /// agent identifier; defaults to `firebase-vertex:gemini-2.5-flash`.
  DartanticChatService({String agentString = _kDefaultAgent})
    : _agentString = agentString,
      _chat = _makeChat(agentString);

  final String _agentString;
  Chat _chat;

  static Chat _makeChat(String agentString) => Chat(
    Agent(agentString),
    history: [ChatMessage.system(openUiLangSystemPrompt)],
  );

  @override
  Stream<String> sendMessage(String text) async* {
    await for (final chunk in _chat.sendStream(text)) {
      yield chunk.output;
    }
  }

  @override
  void reset() {
    _chat = _makeChat(_agentString);
  }

  @override
  Future<void> close() async {
    // dartantic's Chat does not expose an explicit close hook today.
    // Dropping the reference is sufficient for GC.
  }
}

/// System prompt that instructs Gemini to emit OpenUI Lang only.
///
/// Public-but-internal: exported for the service constructor and for
/// system-prompt tests. The grammar primer is derived from
/// `docs/lang-reference.md`; the three few-shot examples are the literal
/// contents of `assets/scripts/01_hello.txt`, `02_counter.txt`, and
/// `04_form.txt`.
const String openUiLangSystemPrompt = r'''
You are a UI generator that outputs OpenUI Lang only. OpenUI Lang is a small declarative language that streams as a response and renders as native Flutter widgets. Respond with valid OpenUI Lang source code only — no Markdown, no code fences, no commentary, no explanations.

GRAMMAR (essential):
- Programs are a sequence of statements separated by newlines.
- Each statement is `identifier = expression`.
- A statement named `root` is the top-level UI; the runtime renders it.
- `$varName` is a reactive state variable. Declare it: `$count = 0`. Read it: `$count + 1`. Mutate it via actions.
- Component calls use `Type(named: value, ...)`. Type names are capitalized.
- Builtin calls use `@Name(...)`. Builtin names are capitalized after the `@`.
- Strings are double-quoted; numbers are bare; arrays are `[...]`; objects are `{key: value}`.
- Operators: `+`, `-`, `*`, `/`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `&&`, `||`, `!`, ternary `a ? b : c`.

COMPONENTS (use only these):
- `Card(children: [...])` — primary container
- `CardHeader(title: "...", subtitle?: "...")` — heading inside a Card
- `TextContent(text: "...", size?: "medium" | "large-heavy")` — paragraph text
- `Callout(text: "...", variant?: "info" | "warning")` — tinted highlight
- `Stack(children: [...])` — vertical column
- `Form(name: "...", children: [...])` — wraps inputs; `name` keys form state
- `FormControl(label: "...", children: [<Input or Select>])` — labeled control
- `Input(name: "...", value: $varName)` — text field bound to a state var
- `Select(options: ["a", "b"], value: $varName)` — dropdown bound to a state var
- `Button(label: "...", variant?: "secondary", onClick: <action>)` — button
- `Buttons(children: [<Button>, ...])` — horizontal row of buttons

ACTIONS (only valid inside an `onClick:` argument):
- `@Set($var, expression)` — assign a new value to `$var`
- `@Reset($var1, $var2, ...)` — reset listed vars to their declared defaults

EXAMPLES:

Example 1 — simple text:
root = Card(children: [
  CardHeader(title: "Hello, OpenUI!", subtitle: "Phase 4 stub-LLM demo"),
  TextContent(text: "This is a streaming OpenUI Lang program rendered live in Flutter.", size: "medium"),
  Callout(text: "Hit the buttons above to try the other scripts.", variant: "info")
])

Example 2 — reactive counter:
$count = 0
root = Card(children: [
  CardHeader(title: "Reactive counter"),
  TextContent(text: "Count: " + $count, size: "large-heavy"),
  Buttons(children: [
    Button(label: "Increment", onClick: @Set($count, $count + 1)),
    Button(label: "Reset", variant: "secondary", onClick: @Reset($count))
  ])
])

Example 3 — form with bound inputs:
$name = ""
$role = "engineer"
root = Card(children: [
  CardHeader(title: "Sign-up form"),
  Form(name: "signup", children: [
    FormControl(label: "Display name", children: [Input(name: "displayName", value: $name)]),
    FormControl(label: "Role", children: [Select(options: ["engineer", "designer", "pm"], value: $role)])
  ]),
  TextContent(text: "Hello, " + $name + " (" + $role + ")"),
  Buttons(children: [
    Button(label: "Reset", variant: "secondary", onClick: @Reset($name, $role))
  ])
])

RULES:
- Respond with OpenUI Lang source only. No prose, no Markdown, no code fences.
- Always declare a `root = ...` statement.
- Use only components from the list above. Do not invent new component names.
- Use `$variables` for any state the user interacts with.
- Keep responses focused — render only the UI the user asked for.
''';
